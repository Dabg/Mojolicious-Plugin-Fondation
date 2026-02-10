#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
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

# Test 1: Direct configuration with short names
{
    my $tempdir = tempdir(CLEANUP => 1);
    my $conf_file = File::Spec->catfile($tempdir, 'test.conf');
    
    # Write config with short names
    write_config_short($conf_file);
    
    my $t = Test::Mojo->new('Mojolicious');
    $t->app->plugin('Config' => {file => $conf_file});
    
    # Load Fondation with short names in direct config
    $t->app->plugin('Fondation' => {
        dependencies => [
            'Fondation::User',
            { 'Fondation::Authorization' => { setting => 'auth_from_direct' } }
        ]
    });
    
    my $fondation = $t->app->fondation;
    ok($fondation, 'Fondation plugin loaded with short names');
    
    my $registry = $fondation->plugin_registry;
    
    # Check that plugins are registered with their full names
    ok(exists $registry->{'Mojolicious::Plugin::Fondation'}, 'Fondation registered (full name)');
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::User'}, 'User plugin registered (full name)');
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::Authorization'}, 'Authorization plugin registered (full name)');
    
    # Check that Authorization has its dependencies (Role and Permission)
    my $auth_entry = $registry->{'Mojolicious::Plugin::Fondation::Authorization'};
    my $auth_deps = $auth_entry->{requires};
    is(scalar @$auth_deps, 2, 'Authorization has 2 dependencies');
    
    # Check dependency tree uses short names
    my $tree = $fondation->dependency_tree;
    like($tree, qr/\x{25CF} Fondation/, 'Tree starts with short name Fondation');
    like($tree, qr/\x{2514}\x{2500} Fondation::User/, 'Tree contains short name Fondation::User');
    like($tree, qr/\x{2514}\x{2500} Fondation::Authorization/, 'Tree contains short name Fondation::Authorization');
}

# Test 2: Global configuration with short names
{
    my $tempdir = tempdir(CLEANUP => 1);
    my $conf_file = File::Spec->catfile($tempdir, 'test.conf');
    
    # Write config with short names in global config
    write_config_short_global($conf_file);
    
    my $t = Test::Mojo->new('Mojolicious');
    $t->app->plugin('Config' => {file => $conf_file});
    
    # Load Fondation without direct config (should use global)
    $t->app->plugin('Fondation');
    
    my $fondation = $t->app->fondation;
    ok($fondation, 'Fondation plugin loaded with short names in global config');
    
    my $registry = $fondation->plugin_registry;
    
    # Check that all plugins are loaded
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::User'}, 'User plugin loaded from global config');
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::Authorization'}, 'Authorization plugin loaded from global config');
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::Role'}, 'Role plugin loaded (dependency of Authorization)');
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::Permission'}, 'Permission plugin loaded (dependency of Authorization)');
}

# Test 3: Mixed short and long names (backward compatibility)
{
    my $tempdir = tempdir(CLEANUP => 1);
    my $conf_file = File::Spec->catfile($tempdir, 'test.conf');
    
    # Write config with mixed names
    write_config_mixed($conf_file);
    
    my $t = Test::Mojo->new('Mojolicious');
    $t->app->plugin('Config' => {file => $conf_file});
    
    # Load Fondation with mixed names
    $t->app->plugin('Fondation' => {
        dependencies => [
            'Fondation::User',  # short name
            'Mojolicious::Plugin::Fondation::Authorization',  # long name
        ]
    });
    
    my $fondation = $t->app->fondation;
    ok($fondation, 'Fondation plugin loaded with mixed names');
    
    my $registry = $fondation->plugin_registry;
    
    # Both plugins should be loaded
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::User'}, 'User plugin loaded (from short name)');
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::Authorization'}, 'Authorization plugin loaded (from long name)');
}

# Test 4: Non-Fondation plugin with short name (Config)
{
    my $tempdir = tempdir(CLEANUP => 1);
    my $conf_file = File::Spec->catfile($tempdir, 'test.conf');
    
    # Write config that references Config plugin
    write_config_with_config($conf_file);
    
    my $t = Test::Mojo->new('Mojolicious');
    $t->app->plugin('Config' => {file => $conf_file});
    
    # Load Fondation with Config as a dependency (short name)
    # Note: Config is already loaded above, but we test that Fondation can reference it
    # Actually, Fondation shouldn't load Config as a dependency, but we can test the name normalization
    
    # Instead, test that Config plugin name is normalized correctly
    my $fondation = Mojolicious::Plugin::Fondation->new;
    is($fondation->_normalize_plugin_name('Config'), 'Mojolicious::Plugin::Config',
       'Config short name normalized to Mojolicious::Plugin::Config');
    is($fondation->_shorten_plugin_name('Mojolicious::Plugin::Config'), 'Config',
       'Mojolicious::Plugin::Config shortened to Config');
}

# Test 5: Configuration lookup with short and long names
{
    my $tempdir = tempdir(CLEANUP => 1);
    my $conf_file = File::Spec->catfile($tempdir, 'test.conf');
    
    # Write config with both short and long names for same plugin
    write_config_both_names($conf_file);
    
    my $t = Test::Mojo->new('Mojolicious');
    $t->app->plugin('Config' => {file => $conf_file});
    
    # Load Fondation
    $t->app->plugin('Fondation' => {
        dependencies => ['Fondation::User']
    });
    
    my $fondation = $t->app->fondation;
    
    # Check that the config was merged correctly (only short names in configs)
    # User plugin sets fondation_user_config from config
    # In our config, short name has setting = 'from_short', long name has setting = 'from_long'
    # Only short name should be used (configs use only short names)
    is($t->app->config->{fondation_user_config}, 'from_short',
       'Configuration uses only short names (from_short expected)');
}

done_testing();

sub write_config_short {
    my ($file) = @_;
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh <<'CONFIG';
{
 'Mojolicious::Plugin::Fondation' => {
     dependencies => [
         'Fondation::User',
         'Fondation::Authorization'
     ]
  },
 'Fondation::Authorization' => {
     dependencies => [
         'Fondation::Role',
         'Fondation::Permission'
     ]
  }
}
CONFIG
    close $fh;
}

sub write_config_short_global {
    my ($file) = @_;
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh <<'CONFIG';
{
 'Fondation' => {
     dependencies => [
         'Fondation::User',
         'Fondation::Authorization'
     ]
  },
 'Fondation::Authorization' => {
     dependencies => [
         'Fondation::Role',
         'Fondation::Permission'
     ]
  }
}
CONFIG
    close $fh;
}

sub write_config_mixed {
    my ($file) = @_;
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh <<'CONFIG';
{
}
CONFIG
    close $fh;
}

sub write_config_with_config {
    my ($file) = @_;
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh <<'CONFIG';
{
 'Fondation' => {
     dependencies => [
         'Fondation::User'
     ]
  }
}
CONFIG
    close $fh;
}

sub write_config_both_names {
    my ($file) = @_;
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh <<'CONFIG';
{
 'Fondation' => {
     dependencies => [
         'Fondation::User'
     ]
  },
 'Fondation::User' => {
     key_test => 'from_short'
  },
 'Mojolicious::Plugin::Fondation::User' => {
     key_test => 'from_long'
  }
}
CONFIG
    close $fh;
}