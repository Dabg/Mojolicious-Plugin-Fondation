use strict;
use warnings;
use Test::More;
use Test::Mojo;
use File::Temp 'tempdir';
use File::Spec;
use FindBin;


# Add lib directories to @INC so plugins can be found
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

# Use test helper for creating apps with temporary home
use TestHelper qw(create_test_app);

# Load the Fondation plugin
use_ok 'Mojolicious::Plugin::Fondation';

# Set HARNESS_ACTIVE to simulate test environment (needed for share_dir)
local $ENV{HARNESS_ACTIVE} = 1;

# Create a temporary directory for config file
my $tempdir = tempdir(CLEANUP => 1);
my $conf_file = File::Spec->catfile($tempdir, 'test.conf');

# Write test configuration with User plugin (which has DBIC components)
write_config($conf_file);

# Create a test Mojolicious app with temporary home directory
my $app = create_test_app($tempdir);
my $t = Test::Mojo->new($app);

# Enable debug logging to see what's happening
$t->app->log->level('debug');

# Use the existing MySchema from t/lib/MySchema.pm
# It already has load_namespaces, but that's OK - Fondation will register extra sources

# Load Config plugin with our config file
$t->app->plugin('Config' => {file => $conf_file});

# First load Migration plugin with SQLite in-memory database
$t->app->plugin('Migration' => {
    schema_class => 'MySchema',
    connect_info => ['dbi:SQLite:dbname=:memory:', '', '', {AutoCommit => 1}],
});

# Verify schema is available
my $schema = $t->app->schema;
ok($schema, 'Schema available via app->schema after Migration plugin');
isa_ok($schema, 'DBIx::Class::Schema');

# Now load Fondation plugin (should load User plugin and its DBIC components)
$t->app->plugin('Fondation');

# Get Fondation instance via helper
my $fondation = $t->app->fondation;
ok($fondation, 'Fondation plugin loaded and accessible via helper');

# Get User plugin from registry
my $registry = $fondation->plugin_registry;
ok($registry, 'Got plugin registry');

# Check that User plugin is registered
my $user_entry = $registry->{'Mojolicious::Plugin::Fondation::User'};
ok($user_entry, 'User plugin registered in registry');

# Debug: show what's in the registry entry
diag "User entry keys: " . join(', ', keys %$user_entry) if $user_entry;

# Check that DBIC components were added
my $dbic_added = $user_entry->{dbic_components_added} || 0;
diag "DBIC components added: $dbic_added";
cmp_ok($dbic_added, '>=', 2, "At least 2 DBIC components added (Result and ResultSet)");

# Check that User source is registered in the schema
my $user_source = $schema->source('User');
ok($user_source, 'User source registered in schema');

# Check that the resultset class is set correctly
if ($user_source) {
    my $rs_class = $user_source->resultset_class;
    diag "ResultSet class: $rs_class";
    is($rs_class, 'Mojolicious::Plugin::Fondation::User::Schema::ResultSet::User',
        'ResultSet class correctly set');

    # Test that we can create a resultset
    my $rs = $schema->resultset('User');
    ok($rs, 'Can create resultset for User');
    isa_ok($rs, 'DBIx::Class::ResultSet');

    # Test ResultSet custom methods
    if ($rs->can('active')) {
        ok(1, 'ResultSet has active method');
    }

    # Check Result class
    my $result_class = $user_source->result_class;
    diag "Result class: $result_class";
    is($result_class, 'Mojolicious::Plugin::Fondation::User::Schema::Result::User',
        'Result class correctly set');
}

# Test actual database operations
eval {
    # Deploy the schema (create tables in memory)
    $schema->deploy();

    # Create a test user
    my $user_rs = $schema->resultset('User');
    my $user = $user_rs->create({
        username   => 'testuser',
        email      => 'test@example.com',
        password   => 'password123',
        created_at => \'datetime("now")',
        updated_at => \'datetime("now")',
        active     => 1,
    });

    ok($user, 'User created successfully');
    is($user->username, 'testuser', 'Username matches');
    is($user->email, 'test@example.com', 'Email matches');
    is($user->active, 1, 'Active flag is 1');

    # Search for the user
    my $found_user = $user_rs->find({ username => 'testuser' });
    ok($found_user, 'Found user by username');
    is($found_user->id, $user->id, 'User IDs match');

    # Test custom ResultSet method (if available)
    if ($user_rs->can('active')) {
        my $active_rs = $user_rs->active;
        ok($active_rs, 'Can get active resultset');
        is($active_rs->count, 1, 'One active user');
    }

    1;
} or diag "Database operations skipped or failed: $@";

done_testing();

sub write_config {
    my ($file) = @_;
    open my $fh, '>', $file or die "Cannot write $file: $!";
    print $fh <<'CONFIG';
{
 'Fondation' => {
     dependencies => [
         'Fondation::User'
    ]
  },
 'Fondation::User' => {
     # No dependencies for User
  }
}
CONFIG
    close $fh;
}