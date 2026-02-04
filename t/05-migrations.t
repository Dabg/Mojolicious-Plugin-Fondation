use strict;
use warnings;

use Test::More;
use Test::Mojo;
use File::Temp qw(tempdir);
use Mojo::File;
use Path::Tiny qw(path);


use Mojolicious qw(-signatures);

use lib 't/lib';

# Test asset copying feature (migrations and fixtures)
# plan will be calculated with done_testing() at the end

# Test 1: Verify MigrationExample plugin has migrations
ok(-d "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations",
   "MigrationExample plugin has migrations directory");
ok(-d "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/_source",
   "MigrationExample plugin has _source migration directory");
ok(-d "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/SQLite",
   "MigrationExample plugin has SQLite migration directory");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/_source/deploy/1/001-auto.yml",
   "MigrationExample plugin has YAML source migration");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/SQLite/deploy/1/001-auto.sql",
   "MigrationExample plugin has SQL migration");

# Test 2: Verify MigrationExample plugin has fixtures
ok(-d "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures",
   "MigrationExample plugin has fixtures directory");
ok(-d "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/1",
   "MigrationExample plugin has fixtures set directory");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/1/conf/all_tables.json",
   "MigrationExample plugin has fixtures config file");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/1/all_tables/example_data/1.fix",
   "MigrationExample plugin has fixture data file");

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

# Test 3: Test migration and fixture copying with MigrationExample plugin
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with MigrationExample plugin
    $app->plugin('Fondation' => {
        plugins => [
            { 'DBSimple' => { 'schema_class' => 'Mojolicious::Plugin::Fondation::MigrationExample::Schema',
                              'connect_info' => [ 'dbi:SQLite:memory:']
                            }
            },
            'Fondation::MigrationExample'
        ]
    });

    my $t = Test::Mojo->new($app);

    # Verify that the application's share/migrations directory was created
    my $app_migrations_dir = $app->home->child('share', 'migrations');

    ok(-d $app_migrations_dir, "Application migrations directory created");

    # Verify migration directories were copied
    my $app_source_dir = $app_migrations_dir->child('_source', 'deploy', '1');
    my $app_sqlite_dir = $app_migrations_dir->child('SQLite', 'deploy', '1');
    ok(-d $app_source_dir, "Source migration directory was copied to application");
    ok(-d $app_sqlite_dir, "SQLite migration directory was copied to application");

    # Verify key migration files were copied
    my $yaml_migration = $app_source_dir->child('001-auto.yml');
    my $sql_migration = $app_sqlite_dir->child('001-auto.sql');
    ok(-f $yaml_migration, "YAML migration file was copied to application");
    ok(-f $sql_migration, "SQL migration file was copied to application");

    # Verify the content matches
    my $original_yaml = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/_source/deploy/1/001-auto.yml")->slurp;
    my $copied_yaml = $yaml_migration->slurp;
    is($copied_yaml, $original_yaml, "Copied YAML migration content matches original");

    my $original_sql = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/SQLite/deploy/1/001-auto.sql")->slurp;
    my $copied_sql = $sql_migration->slurp;
    is($copied_sql, $original_sql, "Copied SQL migration content matches original");

    # Verify that the application's share/fixtures directory was created
    my $app_fixtures_dir = $app->home->child('share', 'fixtures');
    ok(-d $app_fixtures_dir, "Application fixtures directory created");

    # Verify the fixture set directory was copied
    my $app_fixture_set_dir = $app_fixtures_dir->child('1');
    ok(-d $app_fixture_set_dir, "Fixture set directory was copied");

    # Verify fixture config file was copied
    my $fixture_config = $app_fixture_set_dir->child('conf', 'all_tables.json');
    ok(-f $fixture_config, "Fixture config file was copied to application");

    # Verify fixture data file was copied
    my $fixture_data = $app_fixture_set_dir->child('all_tables', 'example_data', '1.fix');
    ok(-f $fixture_data, "Fixture data file was copied to application");

    # Verify the content matches
    my $original_config = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/1/conf/all_tables.json")->slurp;
    my $copied_config = $fixture_config->slurp;
    is($copied_config, $original_config, "Copied fixture config content matches original");

    my $original_data = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/1/all_tables/example_data/1.fix")->slurp;
    my $copied_data = $fixture_data->slurp;
    is($copied_data, $original_data, "Copied fixture data content matches original");

    # Test plugin route works
    $t->get_ok('/migration-example')
      ->status_is(200)
      ->content_like(qr/MigrationExample plugin/, 'MigrationExample plugin route works');
}

# Test 4: Verify existing files are not overwritten (migrations)
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Create share/migrations directory
    my $app_migrations_dir = $app->home->child('share', 'migrations');
    $app_migrations_dir->make_path;

    # Load Fondation with MigrationExample plugin
    $app->plugin('Fondation' => {
        plugins => [
            { 'DBSimple' => { 'schema_class' => 'Mojolicious::Plugin::Fondation::MigrationExample::Schema',
                              'connect_info' => [ 'dbi:SQLite:memory:']
                            }
            },
            'Fondation::MigrationExample'
        ]
    });


    # Create a migration file with the same name but different content
    my $existing_migration = $app_migrations_dir->child('003_existing.sql');
    my $existing_content = "-- Existing migration content\nCREATE TABLE existing (id INTEGER);\n";
    $existing_migration->spew($existing_content);

    # Create a plugin migration with the same name
    my $plugin_migration = "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/003_existing.sql";
    my $plugin_content = "-- Plugin migration that should not overwrite\nCREATE TABLE plugin (id INTEGER);\n";
    Mojo::File->new($plugin_migration)->spew($plugin_content);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with MigrationExample plugin
    $app->plugin('Fondation' => {
        plugins => [
            { 'DBSimple' => { 'schema_class' => 'Mojolicious::Plugin::Fondation::MigrationExample::Schema',
                              'connect_info' => [ 'dbi:SQLite:memory:']
                            }
            },
            'Fondation::MigrationExample'
        ]
    });

    # Verify the file was NOT overwritten (should still have original content)
    my $final_content = $existing_migration->slurp;
    is($final_content, $existing_content,
       "Existing migration file was not overwritten");

    # Clean up the test file we created in the plugin
    unlink $plugin_migration;
}

# Test 5: Verify existing files are not overwritten (fixtures)
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Create share/fixtures directory with the same structure as plugin
    my $app_fixtures_dir = $app->home->child('share', 'fixtures');
    $app_fixtures_dir->make_path;

    $app->plugin('Fondation' => {
        plugins => [
            { 'DBSimple' => { 'schema_class' => 'Mojolicious::Plugin::Fondation::MigrationExample::Schema',
                              'connect_info' => [ 'dbi:SQLite:memory:']
                            }
            },
            'Fondation::MigrationExample'
        ]
    });

    # Create the same directory structure as the plugin's fixtures
    my $app_fixture_set_dir = $app_fixtures_dir->child('1');
    $app_fixture_set_dir->make_path;
    my $app_conf_dir = $app_fixture_set_dir->child('conf');
    $app_conf_dir->make_path;
    my $app_all_tables_dir = $app_fixture_set_dir->child('all_tables');
    $app_all_tables_dir->make_path;
    my $app_example_data_dir = $app_all_tables_dir->child('example_data');
    $app_example_data_dir->make_path;

    # Create an existing fixture file with different content
    my $existing_fixture = $app_example_data_dir->child('1.fix');
    my $existing_content = '$HASH1 = {
           name => "existing",
           value => 999,
           description => "Existing data that should not be overwritten",
           id => 1
         };';
    $existing_fixture->spew($existing_content);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with the plugin
    $app->plugin('Fondation' => {
        plugins => [
            { 'DBSimple' => { 'schema_class' => 'Mojolicious::Plugin::Fondation::MigrationExample::Schema',
                              'connect_info' => [ 'dbi:SQLite:memory:']
                            }
            },
            'Fondation::MigrationExample'
        ]
    });

    # Verify the file was NOT overwritten (should still have original content)
    my $final_content = $existing_fixture->slurp;
    is($final_content, $existing_content,
       "Existing fixture file was not overwritten");
}

# Test 6: Test with Blog plugin (already has migrations, should work for fixtures too if added)
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with Blog plugin
    $app->plugin('Fondation' => {
        plugins => [
            { 'Fondation::Blog' => { title => 'Migration Test' } }
        ]
    });

    # Verify that the Blog plugin's migration was copied
    my $app_migrations_dir = $app->home->child('share', 'migrations');
    my $blog_migration = $app_migrations_dir->child('001_create_posts.sql');
    ok(-f $blog_migration, "Blog plugin migration was copied");

    # Verify the tree structure still works
    my $tree = $Mojolicious::Plugin::Fondation::TREE;
    ok(exists $tree->{'Fondation::Blog'}, "Blog plugin properly registered in tree");
}

# Test 7: Verify fixtures can be applied (seeded) with DBSimple
SKIP: {
    # Skip if required modules are not available
    my $has_dbsimple = eval { require Mojolicious::Plugin::DBSimple; 1 };
    my $has_migrate  = eval { require DBIx::Migrate::Simple; 1 };
    my $has_dbic     = eval { require DBIx::Class; 1 };
    my $has_dbd_sqlite = eval { require DBD::SQLite; 1 };

    my @missing;
    push @missing, 'Mojolicious::Plugin::DBSimple' unless $has_dbsimple;
    push @missing, 'DBIx::Migrate::Simple' unless $has_migrate;
    push @missing, 'DBIx::Class' unless $has_dbic;
    push @missing, 'DBD::SQLite' unless $has_dbd_sqlite;

    if (@missing) {
        skip "Missing required module(s): " . join(', ', @missing), 7;
    }

    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with MigrationExample and DBSimple plugins
    $app->plugin('Fondation' => {
        plugins => [
            { 'DBSimple' => {
                schema_class => 'Mojolicious::Plugin::Fondation::MigrationExample::Schema',
                connect_info => [ 'dbi:SQLite:dbname=:memory:' ],
                target_dir   => $app->home->child('share')->to_string,
            } },
            'Fondation::MigrationExample'
        ]
    });

    # Get migrator and run migrations
    my $migrator = $app->migrator;
    ok($migrator, 'migrator helper available for fixture test');

    # Run migrations (should create tables)
    eval { $migrator->migrate(quiet => 1) };
    is($@, '', 'migrations run successfully');

    # Seed fixtures from MigrationExample plugin
    # The fixtures should have been copied to app's share/fixtures
    # and DBIx::Migrate::Simple should find them
    eval { $migrator->seed(quiet => 1) };
    is($@, '', 'fixtures seeded successfully');

    # Verify data was inserted
    my $schema = $migrator->schema;
    my $rs = $schema->resultset('ExampleData');
    my @rows = $rs->search({}, { order_by => 'id' })->all;

    is(scalar @rows, 3, 'three fixture records were inserted');
    if (@rows >= 3) {
        is($rows[0]->name, 'test', 'first record name matches');
        is($rows[0]->value, 42, 'first record value matches');
        is($rows[1]->name, 'demo', 'second record name matches');
        # Additional checks could be added
    }
}

done_testing();

1;
