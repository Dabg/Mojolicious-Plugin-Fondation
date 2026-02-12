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

# Use test helper for creating apps with temporary home
use TestHelper qw(create_test_app);

# Load the Fondation plugin
use_ok 'Mojolicious::Plugin::Fondation';

# Create a temporary directory for config file
my $tempdir = tempdir(CLEANUP => 1);
my $conf_file = File::Spec->catfile($tempdir, 'test.conf');

# Write test configuration with dependencies
write_config($conf_file);

# Create a test Mojolicious app with temporary home directory
my $app = create_test_app($tempdir);
my $t = Test::Mojo->new($app);

# Load Config plugin with our config file
$t->app->plugin('Config' => {file => $conf_file});

# Load Fondation plugin (should use config from file)
$t->app->plugin('Fondation');

# Get Fondation instance via helper
my $fondation = $t->app->fondation;
ok($fondation, 'Fondation plugin loaded and accessible via helper');
isa_ok($fondation, 'Mojolicious::Plugin::Fondation', 'Fondation plugin');

# Check that plugin_registry exists
ok($fondation->can('plugin_registry'), 'Fondation has plugin_registry method');
my $registry = $fondation->plugin_registry;
is(ref $registry, 'HASH', 'plugin_registry is a hashref');

# Check that Fondation itself is registered
ok(exists $registry->{'Mojolicious::Plugin::Fondation'}, 'Fondation registered in registry');
my $fondation_entry = $registry->{'Mojolicious::Plugin::Fondation'};
is(ref $fondation_entry, 'HASH', 'Fondation entry is a hashref');

# Check Fondation dependencies
my $fondation_deps = $fondation_entry->{requires};
is(ref $fondation_deps, 'ARRAY', 'Fondation dependencies is arrayref');
is(scalar @$fondation_deps, 2, 'Fondation has 2 dependencies');
is($fondation_deps->[0], 'Mojolicious::Plugin::Fondation::User', 'First dependency is User plugin');
is($fondation_deps->[1], 'Mojolicious::Plugin::Fondation::Authorization', 'Second dependency is Authorization plugin');

# Check that User plugin is registered
ok(exists $registry->{'Mojolicious::Plugin::Fondation::User'}, 'User plugin registered');
my $user_entry = $registry->{'Mojolicious::Plugin::Fondation::User'};
is(ref $user_entry, 'HASH', 'User entry is hashref');
my $user_deps = $user_entry->{requires};
is(ref $user_deps, 'ARRAY', 'User dependencies is arrayref');
is(scalar @$user_deps, 0, 'User has no dependencies (from config)');

# Check that Authorization plugin is registered
ok(exists $registry->{'Mojolicious::Plugin::Fondation::Authorization'}, 'Authorization plugin registered');
my $auth_entry = $registry->{'Mojolicious::Plugin::Fondation::Authorization'};
is(ref $auth_entry, 'HASH', 'Authorization entry is hashref');
my $auth_deps = $auth_entry->{requires};
is(ref $auth_deps, 'ARRAY', 'Authorization dependencies is arrayref');
is(scalar @$auth_deps, 2, 'Authorization has 2 dependencies (from config)');
is($auth_deps->[0], 'Mojolicious::Plugin::Fondation::Role', 'First Auth dependency is Role plugin');
is($auth_deps->[1], 'Mojolicious::Plugin::Fondation::Permission', 'Second Auth dependency is Permission plugin');

# Check that Role plugin is registered (dependency of Authorization)
ok(exists $registry->{'Mojolicious::Plugin::Fondation::Role'}, 'Role plugin registered');
my $role_entry = $registry->{'Mojolicious::Plugin::Fondation::Role'};
is(ref $role_entry, 'HASH', 'Role entry is hashref');
my $role_deps = $role_entry->{requires};
is(ref $role_deps, 'ARRAY', 'Role dependencies is arrayref');
is(scalar @$role_deps, 0, 'Role has no dependencies');

# Check that Permission plugin is registered (dependency of Authorization)
ok(exists $registry->{'Mojolicious::Plugin::Fondation::Permission'}, 'Permission plugin registered');
my $perm_entry = $registry->{'Mojolicious::Plugin::Fondation::Permission'};
is(ref $perm_entry, 'HASH', 'Permission entry is hashref');
my $perm_deps = $perm_entry->{requires};
is(ref $perm_deps, 'ARRAY', 'Permission dependencies is arrayref');
is(scalar @$perm_deps, 0, 'Permission has no dependencies');

# Note: We cannot reliably check $app->plugins as it may not return all loaded plugins
# Instead we rely on our plugin_registry for verification.

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