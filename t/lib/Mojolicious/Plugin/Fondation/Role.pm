package Mojolicious::Plugin::Fondation::Role;
use Mojo::Base 'Mojolicious::Plugin::Fondation::Base';

use Role::Tiny::With;
with 'Mojolicious::Plugin::Fondation::Role::ConfigMerge';

our $VERSION = '0.01';

has conf => sub { { key_test => 'role_default' } };

sub register {
    my ($self, $app, $conf) = @_;


    return $self;
}

1;
