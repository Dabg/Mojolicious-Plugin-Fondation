#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Mojo;
use File::Temp qw(tempdir);
use Mojo::File;
use Path::Tiny qw(path);

use lib 't/lib';
use Mojolicious qw(-signatures);

# Test migration copying feature
plan tests => 14;

# Test 1: Verify MigrationTest plugin has migrations
ok(-d "t/lib/Mojolicious/Plugin/Fondation/MigrationTest/share/migrations",
   "MigrationTest plugin has migrations directory");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationTest/share/migrations/001_create_test.sql",
   "MigrationTest plugin has first migration file");
ok(-f "t/lib/Mojolicious/Plugin/Fondation/MigrationTest/share/migrations/002_add_timestamp.sql",
   "MigrationTest plugin has second migration file");

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

# Test 2: Test migration copying with MigrationTest plugin
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with MigrationTest plugin
    $app->plugin('Fondation' => {
        plugins => [
            'Fondation::MigrationTest'
        ]
    });

    my $t = Test::Mojo->new($app);

    # Verify that the application's share/migrations directory was created
    my $app_migrations_dir = $app->home->child('share', 'migrations');
    ok(-d $app_migrations_dir, "Application migrations directory created");

    # Verify both migration files were copied
    my $file1 = $app_migrations_dir->child('001_create_test.sql');
    my $file2 = $app_migrations_dir->child('002_add_timestamp.sql');
    ok(-f $file1, "First migration file was copied to application");
    ok(-f $file2, "Second migration file was copied to application");

    # Verify the content matches
    my $original1 = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationTest/share/migrations/001_create_test.sql")->slurp;
    my $copied1 = $file1->slurp;
    is($copied1, $original1, "First copied migration content matches original");

    my $original2 = Mojo::File->new("t/lib/Mojolicious/Plugin/Fondation/MigrationTest/share/migrations/002_add_timestamp.sql")->slurp;
    my $copied2 = $file2->slurp;
    is($copied2, $original2, "Second copied migration content matches original");

    # Test plugin route works
    $t->get_ok('/migration-test')
      ->status_is(200)
      ->content_like(qr/Migration Test Plugin Loaded/, 'MigrationTest plugin route works');
}

# Test 3: Verify existing files are not overwritten
{
    my $temp_dir = tempdir(CLEANUP => 1);
    my $app = create_test_app($temp_dir);

    # Create share/migrations directory
    my $app_migrations_dir = $app->home->child('share', 'migrations');
    $app_migrations_dir->make_path;

    # Create a file with the same name but different content
    my $existing_file = $app_migrations_dir->child('003_existing.sql');
    my $existing_content = "-- Existing file content\nCREATE TABLE existing (id INTEGER);\n";
    $existing_file->spew($existing_content);

    # Create a plugin migration with the same name
    my $plugin_migration = "t/lib/Mojolicious/Plugin/Fondation/MigrationTest/share/migrations/003_existing.sql";
    my $plugin_content = "-- Plugin migration that should not overwrite\nCREATE TABLE plugin (id INTEGER);\n";
    Mojo::File->new($plugin_migration)->spew($plugin_content);

    # Clear any previous tree data
    no warnings 'once';
    $Mojolicious::Plugin::Fondation::TREE = {};

    # Load Fondation with the plugin
    $app->plugin('Fondation' => {
        plugins => [
            'Fondation::MigrationTest'
        ]
    });

    # Verify the file was NOT overwritten (should still have original content)
    my $final_content = $existing_file->slurp;
    is($final_content, $existing_content,
       "Existing migration file was not overwritten");

    # Clean up the test file we created in the plugin
    unlink $plugin_migration;
}

# Test 4: Test with Blog plugin (already has migrations)
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
