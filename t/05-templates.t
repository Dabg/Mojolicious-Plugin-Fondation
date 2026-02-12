#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Mojo;
use Mojolicious::Lite;
use File::Temp 'tempdir';
use File::Spec;
use FindBin;
use Mojo::File;
use File::Path 'make_path';
use Data::Dumper;
use feature 'signatures';

# Add lib directories to @INC so plugins can be found
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

# Load the Fondation plugin
use_ok 'Mojolicious::Plugin::Fondation';

# Set HARNESS_ACTIVE to simulate test environment
local $ENV{HARNESS_ACTIVE} = 1;

subtest 'Plugin with share/templates directory' => sub {
    # Create a fresh app for this subtest
    my $app = Mojolicious::Lite->new;

    # Load Fondation with User plugin
    my $fondation = $app->plugin('Fondation' => {
        dependencies => [
            'Fondation::User'
        ]
    });

    isa_ok($fondation, 'Mojolicious::Plugin::Fondation', 'Fondation object');

    # Get User plugin instance from registry
    my $registry = $fondation->plugin_registry;
    ok(exists $registry->{'Mojolicious::Plugin::Fondation::User'}, 'User plugin registered');

    my $user_entry = $registry->{'Mojolicious::Plugin::Fondation::User'};
    my $user_instance = $user_entry->{instance};
    my $share_dir = $user_instance->share_dir;
    my $template_dir = $share_dir->child('templates');

    # Check that templates subdirectory exists
    ok(-d $template_dir, "Template directory exists at $template_dir");
    is(
        substr($template_dir, -length('t/share/fondation/user/templates')),
        't/share/fondation/user/templates',
        "template_dir ends with t/share/fondation/user/templates"
        );

    # Get template paths from renderer
    my $paths = $app->renderer->paths;

    # Debug output
    # diag "Template paths:";
    # foreach my $path (@$paths) {
    #     diag "  - $path";
    # }

    # Check that plugin's template directory was added to renderer paths
    my $found_template_path = 0;
    foreach my $path (@$paths) {
        if ($path eq $template_dir->to_string) {
            $found_template_path = 1;
            last;
        }
    }
    ok($found_template_path, 'Template directory was added to renderer paths');

    # Check that the template file exists
    my $template_file = $template_dir->child('hello.html.ep');
    ok(-e $template_file, "Template file exists at $template_file");
    #diag "Template file content: " . $template_file->slurp if -e $template_file;
};


subtest 'Template rendering from plugin' => sub {

    # Create a mini test application
    my $t = Test::Mojo->new;
    my $app = $t->app;

    $app->plugin('Fondation' => {
        dependencies => [
            'Fondation::User'
        ]
    });

    # Add a test route that renders the 'hello' template
    $app->routes->get('/test-plugin-template' => sub ($c) {
                             $c->render('hello');
    });

    # Check if the template file is discoverable in any of the paths
    my $found = 0;
    foreach my $path (@{ $app->renderer->paths }) {
        my $file = Mojo::File->new($path, 'hello.html.ep');
        if (-e $file) {
            ok(1, "Template file exists at: $file");
            $found = 1;
            last;
        }
    }

    # Optional: fail explicitly if template not found (helps debugging)
    ok($found, 'hello.html.ep template was found in renderer paths')
        or diag "→ Make sure t/share/fondation/user/templates is correctly added by the plugin";

    $t->get_ok('/test-plugin-template')
      ->status_is(200, 'Statut 200 OK')
      ->content_type_is('text/html;charset=UTF-8', 'Type HTML attendu')
      ->content_like(qr/Hello from User dev share/i, 'Le template contient du texte attendu')
      ;

};


done_testing();
