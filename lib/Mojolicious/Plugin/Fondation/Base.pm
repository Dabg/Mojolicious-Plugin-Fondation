package Mojolicious::Plugin::Fondation::Base;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Mojo::Home;
use File::ShareDir qw(dist_dir);

# On initialise le "Home" de Mojo
has home => sub { Mojo::Home->new };

has share_dir => sub {
    my $self = shift;
    my $class = ref $self;

    # Transformation : Mojolicious::Plugin::Fondation::User::Admin
    # -> fondation/user/admin
    my $sub_path = lc($class);
    $sub_path =~ s{^mojolicious::plugin::}{};
    $sub_path =~ s{::}{/}g;

    # --- 1. TEST (t/share/...) ---
    if ($ENV{HARNESS_ACTIVE}) {
        # mojo_home->child('t', 'share', ...)
        my $path = $self->home->child('t', 'share', $sub_path);
        return $path if -d $path;
    }

    # --- 2. LOCAL (share/...) ---
    my $local = $self->home->child('share', $sub_path);
    return $local if -d $local;

    # --- 3. INSTALLÉ (File::ShareDir) ---
    my @parts = split '::', $class;
    my $dist_name = join '-', @parts[0..2]; # Ex: Mojolicious-Plugin-Fondation

    my $dist_path = eval { Mojo::File->new(dist_dir($dist_name)) };
    if ($dist_path) {
        my $final = $dist_path->child($sub_path);
        return $final if -d $final;
    }

    return $local;
};

1;
