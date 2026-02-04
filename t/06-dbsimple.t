use strict;
use warnings;

use Test::More;
use Test::Mojo;
use File::Temp qw(tempdir);
use Mojo::File;
use Path::Tiny qw(path);

use lib 't/lib';
use Mojolicious qw(-signatures);

# Check if required modules are available
BEGIN {
    plan skip_all => 'Mojolicious::Plugin::DBSimple not installed'
        unless eval { require Mojolicious::Plugin::DBSimple; 1 };
    plan skip_all => 'DBIx::Migrate::Simple not installed'
        unless eval { require DBIx::Migrate::Simple; 1 };
    plan skip_all => 'DBIx::Class not installed'
        unless eval { require DBIx::Class; 1 };
    plan skip_all => 'DBIx::Class::Migration not installed'
        unless eval { require DBIx::Class::Migration; 1 };
    plan skip_all => 'DBD::SQLite not installed'
        unless eval { require DBD::SQLite; 1 };
}

# Define a simple test schema for DBIx::Class
{
    package TestSchemaDB::Result::TestTable;
    use base 'DBIx::Class::Core';

    __PACKAGE__->load_components('InflateColumn::DateTime');
    __PACKAGE__->table('test_table');
    __PACKAGE__->add_columns(
        id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
        },
        name => {
            data_type => 'varchar',
            size => 255,
            is_nullable => 1,
        },
        created_at => {
            data_type => 'datetime',
            is_nullable => 1,
        },
    );
    __PACKAGE__->set_primary_key('id');
}

{
    package TestSchemaDB;
    use base 'DBIx::Class::Schema';

    our $VERSION = '1';

    __PACKAGE__->load_namespaces(
        default_resultset_class => 'ResultSet',
    );
}

# Make the schema loadable via require
$INC{'TestSchemaDB.pm'} = __FILE__;

# Test DBSimple integration with Fondation
# plan will be calculated at the end with done_testing

# Helper function to create a test app with a temporary home
sub create_test_app {
    my ($temp_dir) = @_;

    my $app = Mojolicious->new;
    $app->home(Mojo::Home->new($temp_dir));

    # Create share directory
    my $share_dir = $app->home->child('share');
    $share_dir->make_path unless -d $share_dir;

    return $app;
}

# Test 1: Load DBSimple plugin via Fondation and verify migrator helper
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with DBSimple plugin configuration
    # Use SQLite in-memory database for testing
    $app->plugin('Fondation' => {
        plugins => [
            { 'DBSimple' => {
                schema_class => 'TestSchemaDB',
                connect_info => [ 'dbi:SQLite:dbname=:memory:' ],
            } }
        ]
    });

    # Verify that the migrator helper is available
    my $migrator = $app->migrator;
    ok($migrator, 'migrator helper is available');
    isa_ok($migrator, 'DBIx::Migrate::Simple', 'migrator returns DBIx::Migrate::Simple instance');

    # Verify that migrator->schema returns a DBIx::Class schema
    my $schema = $migrator->schema;
    isa_ok($schema, 'DBIx::Class::Schema', 'migrator->schema returns a DBIx::Class::Schema');
    isa_ok($schema, 'TestSchemaDB', 'schema is TestSchemaDB');

    my $schema2 = $app->schema;
    isa_ok($schema2, 'DBIx::Class::Schema', 'app->schema returns a DBIx::Class::Schema');
    isa_ok($schema2, 'TestSchemaDB', 'schema is TestSchemaDB');



    # Verify that schema is connected and can execute simple query
    my $result = eval { $schema->storage->dbh->do('SELECT 1') };
    ok(defined $result && !$@, 'schema is connected and can execute SQL');

    # Verify that the plugin is registered in Fondation tree
    my $tree = $Mojolicious::Plugin::Fondation::TREE;
    ok(exists $tree->{'DBSimple'}, 'DBSimple plugin registered in Fondation tree');

    # Verify that the plugin added db command namespace
    my @namespaces = @{$app->commands->namespaces};
    ok(grep { $_ eq 'Mojolicious::Plugin::DBSimple::Command' } @namespaces,
       'DBSimple command namespace added');

    # Test that the migrator can perform migrations (no-op for empty schema)
    # This ensures the integration works end-to-end
    # Suppress output during migration test
    local *STDOUT;
    local *STDERR;
    open STDOUT, '>', \my $stdout_migrate or die "Cannot open STDOUT: $!";
    open STDERR, '>', \my $stderr_migrate or die "Cannot open STDERR: $!";
    eval { $migrator->migrate(quiet => 1) };
    close STDOUT;
    close STDERR;
    is($@, '', 'migrator->migrate runs without error');

    # Check migration status
    # Suppress output during status test
    local *STDOUT;
    local *STDERR;
    open STDOUT, '>', \my $stdout_status or die "Cannot open STDOUT: $!";
    open STDERR, '>', \my $stderr_status or die "Cannot open STDERR: $!";
    my $status = eval { $migrator->status(quiet => 1) };
    close STDOUT;
    close STDERR;
    isa_ok($status, 'HASH', 'status returns a hash reference');
}

# Test 2: Configuration priority (direct config vs app config)
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Clear tree
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Set configuration in application config (lower priority)
    $app->config(
        DBSimple => {
            schema_class => 'TestSchemaDB',
            connect_info => [ 'dbi:SQLite:dbname=:memory:' ],
        }
    );

    # Load Fondation with DBSimple as string (should pick up app config)
    $app->plugin('Fondation' => {
        plugins => [
            'DBSimple'  # string form, should use app config
        ]
    });

    my $migrator = $app->migrator;
    ok($migrator, 'migrator helper available with app config');
    isa_ok($migrator, 'DBIx::Migrate::Simple', 'migrator from app config');
}

# Test 3: Direct configuration (higher priority) overrides app config
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Clear tree
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Set different configuration in application config
    $app->config(
        DBSimple => {
            schema_class => 'TestSchemaDB',
            connect_info => [ 'dbi:SQLite:dbname=:memory:' ],
        }
    );

    # Load Fondation with explicit empty config (highest priority)
    # Even empty hash {} means explicit empty config, which should cause
    # the plugin to fail because schema_class is missing
    # DBSimple validates configuration when migrator is accessed
    eval {
        $app->plugin('Fondation' => {
            plugins => [
                { 'DBSimple' => {} }  # explicit empty config
            ]
        });
    };
    
    # The plugin may not fail immediately (lazy validation)
    my $error = $@;
    if (!$error) {
        # Try to trigger validation by accessing migrator
        eval { $app->migrator; };
        $error = $@;
    }
    
    # Should fail because schema_class is missing (empty config overrides app config)
    like($error, qr/Missing 'schema_class' configuration|schema_class manquant/,
         'explicit empty config overrides app config and fails as expected');
}

done_testing;

1;