package Mojolicious::Plugin::Fondation::Authorization;
use Mojo::Base 'Mojolicious::Plugin::Fondation::Base';

use Role::Tiny::With;
with 'Mojolicious::Plugin::Fondation::Role::ConfigMerge';

our $VERSION = '0.01';

has conf => sub { { dependencies => [ 'Mojolicious::Plugin::Fondation::Role', 'Mojolicious::Plugin::Fondation::Permission' ] } };

sub register {
    my ($self, $app, $conf) = @_;

    return $self;
}

1;
