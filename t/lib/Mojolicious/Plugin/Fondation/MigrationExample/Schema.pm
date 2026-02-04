package Mojolicious::Plugin::Fondation::MigrationExample::Schema;

use base 'DBIx::Class::Schema';

our $VERSION = '1';

__PACKAGE__->load_namespaces(
    default_resultset_class => 'ResultSet',
);

1;