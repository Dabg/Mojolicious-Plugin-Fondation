#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Mojo;

# Include the test plugins directory
use lib 't/lib';

# Helper to create a new Mojolicious application with the Fondation plugin
sub create_test_app {
    my ($fondation_config, $app_config) = @_;

    # Create a new Mojolicious application
    require Mojolicious;
    my $app = Mojolicious->new;

    # Configure the application if needed
    if ($app_config && ref $app_config eq 'HASH') {
        while (my ($key, $value) = each %$app_config) {
            $app->config($key => $value);
        }
    }

    # Load the Fondation plugin
    $app->plugin('Fondation' => $fondation_config);

    return $app;
}

# Test 1: Direct configuration (highest priority)
{
    my $app = create_test_app({
        plugins => [
            { 'Fondation::Blog' => { title => 'Direct Config Title' } }
        ]
    });
    my $t = Test::Mojo->new($app);

    $t->get_ok('/blog')
      ->status_is(200)
      ->content_like(qr/Welcome to Direct Config Title/, 'Direct configuration works');
}

# Test 2: Configuration via application config
{
    my $app = create_test_app(
        {
            plugins => [
                'Fondation::Blog'  # No direct config, uses app config
            ]
        },
        {
            'Fondation::Blog' => { title => 'App Config Title' }
        }
    );
    my $t = Test::Mojo->new($app);

    $t->get_ok('/blog')
      ->status_is(200)
      ->content_like(qr/Welcome to App Config Title/, 'Application configuration works');
}

# Test 3: Default configuration (no config)
{
    my $app = create_test_app({
        plugins => [
            'Fondation::Blog'  # No config, uses default values
        ]
    });
    my $t = Test::Mojo->new($app);

    $t->get_ok('/blog')
      ->status_is(200)
      ->content_like(qr/Welcome to my Blog/, 'Default configuration works');
}

# Test 4: Priority: direct config > app config
{
    my $app = create_test_app(
        {
            plugins => [
                { 'Fondation::Blog' => { title => 'Direct Config' } }
            ]
        },
        {
            'Fondation::Blog' => { title => 'App Config' }
        }
    );
    my $t = Test::Mojo->new($app);

    $t->get_ok('/blog')
      ->status_is(200)
      ->content_like(qr/Welcome to Direct Config/, 'Direct config overrides app config');
}

# Test 5: Multiple plugins configuration
{
    my $app = create_test_app({
        plugins => [
            { 'Fondation::Blog' => { title => 'Blog Title' } },
            { 'Fondation::Security' => { some_option => 'value' } }  # Configuration ignored
        ]
    });
    my $t = Test::Mojo->new($app);

    # Verify helpers are configured correctly
    $t->get_ok('/blog')
      ->status_is(200)
      ->content_like(qr/Welcome to Blog Title/, 'Multiple plugins config works');

    # Verify Security loaded CSRFProtect
    no warnings 'once';
    my $tree = $Mojolicious::Plugin::Fondation::TREE;
    if (exists $tree->{'Fondation::Security'}) {
        my @children = @{$tree->{'Fondation::Security'} || []};
        ok(grep { $_ eq 'CSRFProtect' } @children, 'CSRFProtect loaded by Security');
    }
}

# Test 6: Configuration with empty hash (treated as direct empty config)
{
    my $app = create_test_app(
        {
            plugins => [
                { 'Fondation::Blog' => {} }  # Empty hash = direct empty config
            ]
        },
        {
            'Fondation::Blog' => { title => 'App Config Should Not Be Used' }
        }
    );
    my $t = Test::Mojo->new($app);

    $t->get_ok('/blog')
      ->status_is(200)
      ->content_like(qr/Welcome to my Blog/, 'Empty hash uses default (not app config)');
}

done_testing();
