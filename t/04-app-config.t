#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Mojo;

# Include the test plugins directory
use lib 't/lib';

# Helper to create test application with config
sub create_test_app_with_config {
    my ($config_hash) = @_;

    require Mojolicious;
    my $app = Mojolicious->new;

    # Set configuration
    while (my ($key, $value) = each %$config_hash) {
        $app->config($key => $value);
    }

    # Load Fondation with Blog plugin
    $app->plugin('Fondation' => {
        plugins => [
            'Fondation::Blog'
        ]
    });

    # Add info route to display config
    $app->routes->get('/info' => sub {
        my $c = shift;
        my $blog_config = $c->config('Fondation::Blog') || {};
        my $blog_title = $blog_config->{title} || 'default';
        $c->render(text => "Blog title from config: $blog_title");
    });

    # Add home route
    $app->routes->get('/' => sub {
        my $c = shift;
        $c->render(text => 'Home page');
    });

    return $app;
}

# Test 1: Application with configuration from app config
{
    my $app = create_test_app_with_config({
        'Fondation::Blog' => {
            title => 'My Configured Blog Title'
        }
    });

    my $t = Test::Mojo->new($app);

    $t->get_ok('/blog')
      ->status_is(200)
      ->content_like(qr/Welcome to My Configured Blog Title/, 'Blog uses app config title');

    $t->get_ok('/info')
      ->status_is(200)
      ->content_like(qr/Blog title from config: My Configured Blog Title/, 'Info shows config title');
}

# Test 2: Application without configuration (uses default)
{
    my $app = create_test_app_with_config({});

    my $t = Test::Mojo->new($app);

    $t->get_ok('/blog')
      ->status_is(200)
      ->content_like(qr/Welcome to my Blog/, 'Blog uses default title without config');

    $t->get_ok('/info')
      ->status_is(200)
      ->content_like(qr/Blog title from config: default/, 'Info shows default without config');
}

# Test 3: Verify plugin tree is built
{
    my $app = create_test_app_with_config({
        'Fondation::Blog' => { title => 'Test' }
    });

    no warnings 'once';
    my $tree = $Mojolicious::Plugin::Fondation::TREE;

    ok(exists $tree->{Fondation}, 'Fondation in TREE');
    ok(exists $tree->{'Fondation::Blog'}, 'Blog in TREE');
    ok(exists $tree->{'Fondation::Security'}, 'Security in TREE');
    ok(exists $tree->{'Fondation::Session'}, 'Session in TREE');

    # Check parent-child relationships
    is_deeply(
        $tree->{Fondation},
        ['Fondation::Blog'],
        'Fondation has Blog as child'
    );

    is_deeply(
        $tree->{'Fondation::Blog'},
        ['Fondation::Security', 'Fondation::Session'],
        'Blog has Security and Session as children'
    );
}

done_testing();
