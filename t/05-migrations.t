use strict;
use warnings;

use Test::More;
use Test::Mojo;
use File::Temp qw(tempdir);
use Mojo::File;
use Path::Tiny qw(path);

use lib 't/lib';
use Mojolicious qw(-signatures);

# Test asset copying feature (migrations and fixtures)
plan tests => 23;

# Test 1: Verify MigrationExample plugin has migrations
ok(-d "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations",
   "MigrationExample plugin has migrations directory");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/001_create_example.sql",
   "MigrationExample plugin has first migration file");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/002_add_description.sql",
   "MigrationExample plugin has second migration file");

# Test 2: Verify MigrationExample plugin has fixtures
ok(-d "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures",
   "MigrationExample plugin has fixtures directory");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/initial_data.sql",
   "MigrationExample plugin has SQL fixtures file");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/config.json",
   "MigrationExample plugin has JSON fixtures file");

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
            'Fondation::MigrationExample'
        ]
    });

    my $t = Test::Mojo->new($app);

    # Verify that the application's share/migrations directory was created
    my $app_migrations_dir = $app->home->child('share', 'migrations');
    ok(-d $app_migrations_dir, "Application migrations directory created");

    # Verify both migration files were copied
    my $migration1 = $app_migrations_dir->child('001_create_example.sql');
    my $migration2 = $app_migrations_dir->child('002_add_description.sql');
    ok(-f $migration1, "First migration file was copied to application");
    ok(-f $migration2, "Second migration file was copied to application");

    # Verify the content matches
    my $original_migration1 = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/001_create_example.sql")->slurp;
    my $copied_migration1 = $migration1->slurp;
    is($copied_migration1, $original_migration1, "First copied migration content matches original");

    my $original_migration2 = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations/002_add_description.sql")->slurp;
    my $copied_migration2 = $migration2->slurp;
    is($copied_migration2, $original_migration2, "Second copied migration content matches original");

    # Verify that the application's share/fixtures directory was created
    my $app_fixtures_dir = $app->home->child('share', 'fixtures');
    ok(-d $app_fixtures_dir, "Application fixtures directory created");

    # Verify both fixture files were copied
    my $fixture1 = $app_fixtures_dir->child('initial_data.sql');
    my $fixture2 = $app_fixtures_dir->child('config.json');
    ok(-f $fixture1, "First fixture file was copied to application");
    ok(-f $fixture2, "Second fixture file was copied to application");

    # Verify the content matches
    my $original_fixture1 = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/initial_data.sql")->slurp;
    my $copied_fixture1 = $fixture1->slurp;
    is($copied_fixture1, $original_fixture1, "First copied fixture content matches original");

    my $original_fixture2 = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/config.json")->slurp;
    my $copied_fixture2 = $fixture2->slurp;
    is($copied_fixture2, $original_fixture2, "Second copied fixture content matches original");

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

    # Load Fondation with the plugin
    $app->plugin('Fondation' => {
        plugins => [
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

    # Create share/fixtures directory
    my $app_fixtures_dir = $app->home->child('share', 'fixtures');
    $app_fixtures_dir->make_path;

    # Create a fixture file with the same name but different content
    my $existing_fixture = $app_fixtures_dir->child('existing.json');
    my $existing_content = '{"existing": "data"}';
    $existing_fixture->spew($existing_content);

    # Create a plugin fixture with the same name
    my $plugin_fixture = "t/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/fixtures/existing.json";
    my $plugin_content = '{"plugin": "should not overwrite"}';
    Mojo::File->new($plugin_fixture)->spew($plugin_content);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with the plugin
    $app->plugin('Fondation' => {
        plugins => [
            'Fondation::MigrationExample'
        ]
    });

    # Verify the file was NOT overwritten (should still have original content)
    my $final_content = $existing_fixture->slurp;
    is($final_content, $existing_content,
       "Existing fixture file was not overwritten");

    # Clean up the test file we created in the plugin
    unlink $plugin_fixture;
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