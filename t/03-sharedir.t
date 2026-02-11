#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use File::Temp 'tempdir';
use File::Spec;
use FindBin;
use Mojo::File;
use File::Path 'make_path';

# Add lib directories to @INC so plugins can be found
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

# Load the Fondation plugin
use_ok 'Mojolicious::Plugin::Fondation';

# Set HARNESS_ACTIVE to simulate test environment
local $ENV{HARNESS_ACTIVE} = 1;

# Create a temporary directory for config file
my $tempdir = tempdir(CLEANUP => 1);
my $conf_file = File::Spec->catfile($tempdir, 'test.conf');

# Write minimal configuration
write_config($conf_file);

# Create a test Mojolicious app
my $t = Test::Mojo->new('Mojolicious');

# Create template directory for User plugin to test share_dir functionality
my $user_template_dir = Mojo::File->new('t', 'share', 'fondation', 'user', 'templates');
make_path($user_template_dir) unless -d $user_template_dir;

# Create a simple template file to verify
my $template_file = $user_template_dir->child('test.ep');
$template_file->spew('<%= $msg %>');

# Load Config plugin with our config file
$t->app->plugin('Config' => {file => $conf_file});

# Load Fondation plugin (should load User plugin via config)
$t->app->plugin('Fondation');

# Get Fondation instance via helper
my $fondation = $t->app->fondation;
ok($fondation, 'Fondation plugin loaded and accessible via helper');

# Get User plugin from registry
my $registry = $fondation->plugin_registry;
ok(exists $registry->{'Mojolicious::Plugin::Fondation::User'}, 'User plugin registered');

# We need to get the actual User plugin instance. Fondation stores plugin instances
# in plugin_registry->{plugin_name}->{instance}
my $user_entry = $registry->{'Mojolicious::Plugin::Fondation::User'};
ok($user_entry, 'User entry exists in registry');
my $user_instance = $user_entry->{instance};
ok($user_instance, 'User plugin instance exists');
isa_ok($user_instance, 'Mojolicious::Plugin::Fondation::User', 'User plugin instance');
isa_ok($user_instance, 'Mojolicious::Plugin::Fondation::Base', 'User plugin inherits from Fondation::Base');

# Test that share_dir method exists
can_ok($user_instance, 'share_dir');

# Get the share_dir path
my $share_dir = $user_instance->share_dir;
ok($share_dir, 'share_dir returns a value');

# Check that it's a Mojo::File (or at least something with stringification)
isa_ok($share_dir, 'Mojo::File', 'share_dir returns a Mojo::File');

# Verify the path is under t/share/fondation/user
my $expected_base = Mojo::File->new('t', 'share', 'fondation', 'user');
my $share_path = $share_dir->to_string;
my $expected_path = $expected_base->to_string;
like($share_path, qr/\Q$expected_path\E/, "share_dir points to t/share/fondation/user (got: $share_path)");

# Verify that the directory exists (it should, from our test structure)
ok(-d $share_dir, "share_dir directory exists");

# Check that templates subdirectory exists and was added to renderer paths
my $template_dir = $share_dir->child('templates');
ok(-d $template_dir, "Template directory exists at $template_dir");
my @renderer_paths = @{$t->app->renderer->paths};
my $found_template_path = 0;
foreach my $path (@renderer_paths) {
    if ($path eq $template_dir->to_string) {
        $found_template_path = 1;
        last;
    }
}
ok($found_template_path, 'Template directory was added to renderer paths');

# Test 2: Plugin without Fondation::Base inheritance
{
    # Create a simple plugin class that does NOT inherit from Fondation::Base
    package Mojolicious::Plugin::Fondation::Simple;
    use Mojo::Base 'Mojolicious::Plugin';

    sub register {
        my ($self, $app, $conf) = @_;
        return $self;
    }

    package main;

    my $simple_plugin = Mojolicious::Plugin::Fondation::Simple->new;

    # Should NOT have share_dir method
    ok(!$simple_plugin->can('share_dir'), 'Plugin without Fondation::Base inheritance does NOT have share_dir method');

    # Should not have 'home' attribute either
    ok(!$simple_plugin->can('home'), 'Plugin without Fondation::Base inheritance does NOT have home attribute');
}

# Test 3: Verify share_dir logic with HARNESS_ACTIVE environment variable
{
    # Temporarily unset HARNESS_ACTIVE
    local $ENV{HARNESS_ACTIVE} = 0;

    # Create another app to test fallback behavior
    my $t2 = Test::Mojo->new('Mojolicious');
    $t2->app->plugin('Config' => {file => $conf_file});
    $t2->app->plugin('Fondation');

    my $fondation2 = $t2->app->fondation;
    my $registry2 = $fondation2->plugin_registry;
    my $user_entry2 = $registry2->{'Mojolicious::Plugin::Fondation::User'};
    my $user_instance2 = $user_entry2->{instance};

    # With HARNESS_ACTIVE off, share_dir should fall back to local share directory
    # (which doesn't exist in our test environment, so it will return the local path)
    my $share_dir2 = $user_instance2->share_dir;
    ok($share_dir2, 'share_dir returns a value even without HARNESS_ACTIVE');

    # The path should NOT be under t/share/... (since HARNESS_ACTIVE is off)
    unlike($share_dir2->to_string, qr/t\/share/, 'share_dir does not point to t/share when HARNESS_ACTIVE is off');
}

# Test 4: Verify share_dir respects plugin-specific share subdirectories
{
    # Create a test directory structure for a fictional plugin
    my $test_plugin_dir = Mojo::File->new('t', 'share', 'fondation', 'fictional');
    $test_plugin_dir->make_path;

    # Create a plugin class that inherits from Fondation::Base
    package Mojolicious::Plugin::Fondation::Fictional;
    use Mojo::Base 'Mojolicious::Plugin::Fondation::Base';

    sub register {
        my ($self, $app, $conf) = @_;
        return $self;
    }

    package main;

    # Create an instance and test share_dir
    my $fictional_plugin = Mojolicious::Plugin::Fondation::Fictional->new;
    $fictional_plugin->home(Mojo::Home->new->detect);  # Set home to current dir

    my $fictional_share = $fictional_plugin->share_dir;

    # Should point to t/share/fondation/fictional
    my $expected_fictional_path = Mojo::File->new('t', 'share', 'fondation', 'fictional')->to_string;
    like($fictional_share->to_string, qr/\Q$expected_fictional_path\E/,
         'Fictional plugin share_dir points to correct test location');

    # Clean up
    $test_plugin_dir->remove_tree if -d $test_plugin_dir;
}

# Clean up created template file
if ($template_file && -e $template_file) {
    unlink $template_file or warn "Could not unlink $template_file: $!";
}

if ($user_template_dir && -d $user_template_dir ){
#    rmdir $user_template_dir or warn "Could not remove $user_template_dir: $!";
}

done_testing();

sub write_config {
    my ($file) = @_;
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh <<'CONFIG';
{
 'Mojolicious::Plugin::Fondation' => {
     dependencies => [
         'Mojolicious::Plugin::Fondation::User'
     ]
  }
}
CONFIG
    close $fh;
}
