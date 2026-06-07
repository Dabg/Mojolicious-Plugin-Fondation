package Mojolicious::Plugin::Fondation::Action::Static;

# ABSTRACT: Registers public asset directories from plugin share directories

use Mojo::Base 'Mojolicious::Plugin::Fondation::Action::Base', -signatures;

use Mojolicious::Plugin::Fondation::Utils qw(share_relative);

sub after_load ($self, $long, $conf, $share_dir) {
    return unless $share_dir && -d $share_dir;

    my $public_dir = $share_dir->child('public');
    return unless -d $public_dir;

    my $manager = $self->manager;
    my $app     = $manager->app;

    # Add public directory to static file paths
    push @{$app->static->paths}, $public_dir->to_string;
    $self->log->debug("Added public path: " . share_relative($public_dir));

    # Store in registry for other consumers (e.g. Asset plugin)
    my $entry = $manager->registry->{$long};
    $entry->{public_dir} = $public_dir;
}

1;
