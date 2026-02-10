package Mojolicious::Plugin::Fondation::Permission;

use Mojo::Base 'Mojolicious::Plugin::Fondation::Base';

use Role::Tiny::With;
with 'Mojolicious::Plugin::Fondation::Role::ConfigMerge';

our $VERSION = '0.01';


sub register {
    my ($self, $app, $conf) = @_;

    return $self;
}

1;
