#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use File::Temp 'tempdir';
use File::Spec;
use FindBin;

# Add lib directories to @INC so plugins can be found
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

# Load the Fondation plugin
use_ok 'Mojolicious::Plugin::Fondation';

# Create a temporary directory for config file
my $tempdir = tempdir(CLEANUP => 1);
my $conf_file = File::Spec->catfile($tempdir, 'test.conf');

# Write test configuration with some dependencies
write_config($conf_file);

# Create a test Mojolicious app
my $t = Test::Mojo->new('Mojolicious');

# Load Config plugin with our config file (global config)
$t->app->plugin('Config' => {file => $conf_file});

# Load Fondation plugin with DIRECT configuration (should override global)
$t->app->plugin('Fondation' => {
    dependencies => [
        'Mojolicious::Plugin::Fondation::User',  # Only User in direct config
        # Authorization is NOT in direct config, should not be loaded
    ]
});

# Get the Fondation plugin instance via helper
my $fondation = $t->app->fondation;
ok($fondation, 'Fondation plugin loaded and accessible via helper');
isa_ok($fondation, 'Mojolicious::Plugin::Fondation', 'Fondation plugin');


# Check plugin registry
my $registry = $fondation->plugin_registry;
is(ref $registry, 'HASH', 'plugin_registry is a hashref');

# Check that Fondation itself is registered
ok(exists $registry->{'Mojolicious::Plugin::Fondation'}, 'Fondation registered');

# Check Fondation dependencies - should be from DIRECT config (only User)
my $fondation_entry = $registry->{'Mojolicious::Plugin::Fondation'};
my $fondation_deps = $fondation_entry->{requires};
is(ref $fondation_deps, 'ARRAY', 'Fondation dependencies is arrayref');
is(scalar @$fondation_deps, 1, 'Fondation has 1 dependency (from direct config, not global)');
is($fondation_deps->[0], 'Mojolicious::Plugin::Fondation::User', 'Only dependency is User plugin');

# User plugin should be registered
ok(exists $registry->{'Mojolicious::Plugin::Fondation::User'}, 'User plugin registered');

# Authorization plugin should NOT be registered (not in direct config)
ok(!exists $registry->{'Mojolicious::Plugin::Fondation::Authorization'},
   'Authorization plugin NOT registered (not in direct config)');

# Role and Permission plugins should NOT be registered (they depend on Authorization)
ok(!exists $registry->{'Mojolicious::Plugin::Fondation::Role'},
   'Role plugin NOT registered (Authorization not loaded)');
ok(!exists $registry->{'Mojolicious::Plugin::Fondation::Permission'},
   'Permission plugin NOT registered (Authorization not loaded)');

# Test 2: Plugin-specific configuration priority
# Create another app to test plugin-specific config merging
my $t2 = Test::Mojo->new('Mojolicious');

# Load Config plugin with config that has plugin-specific settings
$t2->app->plugin('Config' => {file => $conf_file});

# Load Fondation with direct config that includes plugin-specific config for User
$t2->app->plugin('Fondation' => {
    dependencies => [
        {
            'Mojolicious::Plugin::Fondation::User' => { custom_setting => 'from_direct_config' }
        },
        'Mojolicious::Plugin::Fondation::Authorization',
    ]
});

my $fondation2 = $t2->app->fondation;
ok($fondation2, 'Fondation plugin loaded and accessible via helper in test 2');
my $registry2 = $fondation2->plugin_registry;

# Check that User plugin is registered
ok(exists $registry2->{'Mojolicious::Plugin::Fondation::User'}, 'User plugin registered in second test');

# Note: We cannot easily check the config passed to User plugin without modifying the plugin.
# For now, we trust that the direct config was passed.

# Test 3: Direct config for dependency plugin (Authorization) should override global
# Create another app
my $t3 = Test::Mojo->new('Mojolicious');

# Load Config plugin
$t3->app->plugin('Config' => {file => $conf_file});

# Load Fondation with direct config for Authorization dependencies
$t3->app->plugin('Fondation' => {
    dependencies => [
        'Mojolicious::Plugin::Fondation::User',
        {
            'Mojolicious::Plugin::Fondation::Authorization' => {
                dependencies => [
                    'Mojolicious::Plugin::Fondation::Role',
                    # Permission is NOT in direct config, should not be loaded
                ]
            }
        },
    ]
});

my $fondation3 = $t3->app->fondation;
ok($fondation3, 'Fondation plugin loaded and accessible via helper in test 3');
my $registry3 = $fondation3->plugin_registry;

# Check Authorization dependencies - should be from direct config (only Role)
my $auth_entry = $registry3->{'Mojolicious::Plugin::Fondation::Authorization'};
my $auth_deps = $auth_entry->{requires};
is(ref $auth_deps, 'ARRAY', 'Authorization dependencies is arrayref');
is(scalar @$auth_deps, 1, 'Authorization has 1 dependency (from direct config, not global)');
is($auth_deps->[0], 'Mojolicious::Plugin::Fondation::Role', 'Only dependency is Role plugin');

# Role should be registered
ok(exists $registry3->{'Mojolicious::Plugin::Fondation::Role'}, 'Role plugin registered');

# Permission should NOT be registered (not in direct config for Authorization)
ok(!exists $registry3->{'Mojolicious::Plugin::Fondation::Permission'},
   'Permission plugin NOT registered (not in direct config for Authorization)');

# Test 4: Configuration hierarchy (direct > global > plugin default)
{
    # Helper to write a config file
    my $write_config = sub {
        my ($file, $content) = @_;
        open my $fh, '>', $file or die "Cannot write $file: $!";
        print $fh $content;
        close $fh;
    };

    # Scenario A: Direct config should override everything
    {
        my $tempdir = tempdir(CLEANUP => 1);
        my $conf_file = File::Spec->catfile($tempdir, 'test_hierarchy.conf');
        $write_config->($conf_file, '{}');  # empty config

        my $tA = Test::Mojo->new('Mojolicious');
        $tA->app->plugin('Config' => {file => $conf_file});
        $tA->app->plugin('Fondation' => {
            dependencies => [
                { 'Mojolicious::Plugin::Fondation::User' => { key_test => 'direct_config' } }
            ]
        });
        is($tA->app->config->{fondation_user_config}, 'direct_config',
           'Direct config should be used when provided');
    }

    # Scenario B: Global config should override plugin default
    {
        my $tempdir = tempdir(CLEANUP => 1);
        my $conf_file = File::Spec->catfile($tempdir, 'test_hierarchy.conf');
        $write_config->($conf_file, <<'CONFIG');
{
 'Fondation' => {
     dependencies => [
         'Fondation::User'
     ]
  },
 'Fondation::User' => {
     key_test => 'global_config'
  }
}
CONFIG

        my $tB = Test::Mojo->new('Mojolicious');
        $tB->app->plugin('Config' => {file => $conf_file});
        $tB->app->plugin('Fondation');  # no direct config
        is($tB->app->config->{fondation_user_config}, 'global_config',
           'Global config should be used when no direct config');
    }

    # Scenario C: Plugin default should be used when no direct or global config
    {
        my $tempdir = tempdir(CLEANUP => 1);
        my $conf_file = File::Spec->catfile($tempdir, 'test_hierarchy.conf');
        $write_config->($conf_file, <<'CONFIG');
{
 'Fondation' => {
     dependencies => [
         'Fondation::User'
     ]
  }
}
CONFIG

        my $tC = Test::Mojo->new('Mojolicious');
        $tC->app->plugin('Config' => {file => $conf_file});
        $tC->app->plugin('Fondation');  # no direct config
        is($tC->app->config->{fondation_user_config}, 'plugin_default',
           'Plugin default config should be used when no direct or global config');
    }
}

done_testing();

sub write_config {
    my ($file) = @_;
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh <<'CONFIG';
{
 'Fondation' => {
     dependencies => [
         'Fondation::User',
         'Fondation::Authorization',
    ]
  },
 'Fondation::Authorization' => {
     dependencies => [
         'Fondation::Role',
         'Fondation::Permission',
    ]
  },
 'Fondation::User' => {
     # No dependencies for User
  },
 'Fondation::Role' => {
     # No dependencies for Role
  },
 'Fondation::Permission' => {
     # No dependencies for Permission
  }
}
CONFIG
    close $fh;
}
