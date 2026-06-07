package Mojolicious::Plugin::Fondation::TestHelper;

# ABSTRACT: Test helpers for Fondation and its plugins

use strict;
use warnings;
use Mojolicious;
use Mojo::Home;
use File::Temp 'tempdir';
use File::Spec;
use File::Path 'make_path';

our @EXPORT_OK = qw(
    create_test_app
    create_fondation_app
    capture_command
);

use base 'Exporter';

# Create a bare Mojolicious app with a temporary home directory.
# The app's share/ directory is created to avoid permission errors.
sub create_test_app {
    my ($temp_dir) = @_;

    if (!$temp_dir) {
        $temp_dir = tempdir(CLEANUP => 1);
    }

    my $app = Mojolicious->new;

    my $app_home = File::Spec->catdir($temp_dir, 'app_home');
    mkdir $app_home or die "Cannot create app_home: $!";
    $app->home(Mojo::Home->new($app_home));

    my $share_dir = $app->home->child('share');
    make_path($share_dir) unless -d $share_dir;

    return $app;
}

# Create a Fondation app with the given config loaded.
# Equivalent to: create_test_app + $app->plugin('Fondation' => $config)
sub create_fondation_app {
    my ($temp_dir, $config) = @_;
    $config //= {};

    my $app = create_test_app($temp_dir);
    $app->plugin('Fondation' => $config);
    return $app;
}

# Run a command on the app and capture STDOUT + STDERR.
# Returns the combined output as a string.
sub capture_command {
    my ($app, @args) = @_;

    my $buf;
    open my $fh, '>', \$buf;
    local *STDOUT = $fh;
    local *STDERR = $fh;
    $app->commands->run(@args);
    close $fh;

    return $buf;
}

1;
