#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Mojo;
use File::Temp qw(tempdir);
use File::Spec;
use Path::Tiny qw(path);

use lib 't/lib';
use Mojolicious qw(-signatures);

sub create_test_app {
    my ($fondation_config, $app_config, $app_templates_dir) = @_;

    my $app = Mojolicious->new;

    if ($app_templates_dir && -d $app_templates_dir) {
        unshift @{$app->renderer->paths}, $app_templates_dir;
    }

    # Configuration seulement si c'est un hash valide
    if (defined $app_config && ref $app_config eq 'HASH') {
        $app->config($_ => $app_config->{$_}) for keys %$app_config;
    }

    $app->plugin('Fondation' => $fondation_config);

    return $app;
}
# Helper to create a temporary template
sub create_temp_template {
    my ($dir, $rel_path, $content) = @_;
    my $file = path($dir)->child($rel_path);
    $file->parent->mkpath;
    $file->spew_utf8($content);
    return $file->stringify;
}

subtest 'Fondation::TemplateTest - Template resolution' => sub {
    my $app = create_test_app({ plugins => ['Fondation::TemplateTest'] });

    my $t = Test::Mojo->new($app);

    $t->get_ok('/template_test')
        ->status_is(200, '200 OK - Template rendered')
        ->content_like(qr{Welcome from Plugin Template}, 'Plugin template title')
        ->content_like(qr{Message: Plugin Template}, 'Default message')
        ->content_like(qr{This template is provided by the plugin}, 'Plugin-specific text');

};


    # Test 2 : Configuration is properly passed to the template
subtest 'Configuration passed to plugin template' => sub {
    my $app = create_test_app({
        plugins => [{ 'Fondation::TemplateTest' => { message => 'Custom Message' } }]
    });
    my $t = Test::Mojo->new($app);

    $t->get_ok('/template_test', 'Route access')
      ->status_is(200, '200 OK')
      ->content_like(qr{Message: Custom Message}, 'Custom message passed');
};

# Test 3 : Application overrides plugin template
subtest 'Application override (higher priority)' => sub {
    my $app_templates_dir = tempdir(CLEANUP => 1);

    # Create override template in app directory
    create_temp_template(
        $app_templates_dir,
        'welcome.html.ep',
        <<'EOF'
<h1>Welcome from Application Template</h1>
<p>Message: <%= $message %></p>
<p>This template is provided by the application (overrides plugin).</p>
EOF
    );

    my $app = create_test_app(
        { plugins => ['Fondation::TemplateTest'] },
        undef,
        $app_templates_dir
    );

    my $t = Test::Mojo->new($app);

    # Debug : check paths (app priority > plugin)
    $app->log->debug("Renderer paths with app override:");
    $app->log->debug("  $_") for @{$app->renderer->paths};

    $t->get_ok('/template_test')
      ->status_is(200, '200 OK with override')
      ->content_like(qr{Welcome from Application Template}, 'Application template used')
      ->content_like(qr{This template is provided by the application}, 'Override text visible');
};


    # Test 4 : Override + custom configuration
    subtest 'Override with configured message' => sub {
        my $app_templates_dir = tempdir(CLEANUP => 1);

        create_temp_template(
            $app_templates_dir,
            'welcome.html.ep',
            <<'EOF'
<h1>Application Template Override</h1>
<p>Message: <%= $message %></p>
EOF
        );

        my $app = create_test_app(
            { plugins => [{ 'Fondation::TemplateTest' => { message => 'Configured Message' } }] },
            undef,
            $app_templates_dir
        );
        my $t = Test::Mojo->new($app);

        $t->get_ok('/template_test')
          ->status_is(200)
          ->content_like(qr{Application Template Override}, 'Override title')
          ->content_like(qr{Message: Configured Message}, 'Configured message passed');
    };

    # Test 5 : Verification that Fondation adds the share/templates path
    subtest 'Automatic addition of share/templates path by Fondation' => sub {
        my $app = Mojolicious->new;
        $app->plugin('Fondation' => {
            plugins => ['Fondation::TemplateTest']
        });

        my $paths = $app->renderer->paths;
        ok(scalar @$paths >= 1, 'At least one template path exists');

        my $found = grep {
            m{TemplateTest.*share.*templates}i
        } @$paths;

        ok($found, 'share/templates path of TemplateTest plugin added by Fondation');
    };

done_testing;

1
