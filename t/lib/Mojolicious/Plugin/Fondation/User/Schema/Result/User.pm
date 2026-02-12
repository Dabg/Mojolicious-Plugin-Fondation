package Mojolicious::Plugin::Fondation::User::Schema::Result::User;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table('users');
__PACKAGE__->add_columns(
    id => { data_type => 'integer', is_auto_increment => 1, is_nullable => 0 },
    username => { data_type => 'varchar', size => 100, is_nullable => 0 },
    email => { data_type => 'varchar', size => 255, is_nullable => 0 },
    password => { data_type => 'varchar', size => 60, is_nullable => 0 },
    created_at => { data_type => 'datetime', is_nullable => 0 },
    updated_at => { data_type => 'datetime', is_nullable => 0 },
    active => {
        data_type     => 'integer',
        default_value => 1,
        is_nullable   => 0,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint([qw(username email)]);

1;
