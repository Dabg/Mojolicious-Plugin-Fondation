package Mojolicious::Plugin::Fondation::Action::Base;

# ABSTRACT: Base class for Fondation post-load actions

use Mojo::Base -base, -signatures;

has 'manager';
has 'log';

sub after_load ($self, $long_name, $conf, $share_dir) {
    # to be overridden
}

1;
