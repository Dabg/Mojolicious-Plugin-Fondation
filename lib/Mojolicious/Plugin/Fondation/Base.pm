package Mojolicious::Plugin::Fondation::Base;
# ABSTRACT: Base class for Fondation plugins providing shared directory support

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use File::ShareDir qw(dist_dir);

# Initialize Mojo's "Home"
has home => sub { Mojo::Home->new };
has app => sub { die "app not set" };

has share_dir => sub {
    my $self = shift;
    my $class = ref $self;


    # Transformation: Mojolicious::Plugin::Fondation::User::Admin
    # -> fondation/user/admin
    my $sub_path = lc($class);
    $sub_path =~ s{^mojolicious::plugin::}{};
    $sub_path =~ s{::}{/}g;

    # --- 1. TEST (t/share/...) ---
    # When running tests (HARNESS_ACTIVE) or when USE_SHARE_DIR_TEST=1 is set,
    # look for share directory under t/share/... first.
    # This is useful for development and testing with local share files.
    if ($ENV{HARNESS_ACTIVE} || $ENV{USE_SHARE_DIR_TEST}) {
        # mojo_home->child('t', 'share', ...)
        my $path = $self->home->child('t', 'share', $sub_path);
        return $path if -d $path;
    }

    # --- 2. LOCAL (share/...) ---
    my $local = $self->home->child('share', $sub_path);

    return $local if -d $local;


    # --- 3. INSTALLED (File::ShareDir) ---
    my @parts = split '::', $class;
    my $dist_name = 'Mojolicious-Plugin-Fondation-' . $parts[-1];
    my $dist_path = eval { Mojo::File->new(dist_dir($dist_name)) };

    if ($dist_path) {
        return $dist_path if -d $dist_path;
    }

    return $local;
};

1;
