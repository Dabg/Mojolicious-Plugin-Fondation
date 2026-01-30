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

    # Charger Fondation d'abord
    $app->plugin('Fondation' => $fondation_config);

    # Puis ajouter le chemin de surcharge (priorité haute)
    if ($app_templates_dir && -d $app_templates_dir) {
        unshift @{$app->renderer->paths}, $app_templates_dir;
    }

    # Log final pour vérifier l'ordre
    $app->log->debug("Chemins renderer finaux (app en premier ?) :");
    $app->log->debug("  $_") for @{$app->renderer->paths};

    return $app;
}

# Helper pour créer un template temporaire
sub create_temp_template {
    my ($dir, $rel_path, $content) = @_;
    my $file = path($dir)->child($rel_path);
    $file->parent->mkpath;
    $file->spew_utf8($content);
    return $file->stringify;
}

subtest 'Fondation::TemplateTest - Résolution des templates' => sub {
    my $app = create_test_app({ plugins => ['Fondation::TemplateTest'] });

    my $t = Test::Mojo->new($app);

    $t->get_ok('/template_test')
        ->status_is(200, '200 OK - Template rendu')
        ->content_like(qr{Welcome from Plugin Template}, 'Titre du template plugin')
        ->content_like(qr{Message: Plugin Template}, 'Message par défaut')
        ->content_like(qr{This template is provided by the plugin}, 'Texte spécifique plugin');

};


    # Test 2 : La configuration est bien passée au template
subtest 'Configuration passée au template du plugin' => sub {
    my $app = create_test_app({
        plugins => [{ 'Fondation::TemplateTest' => { message => 'Custom Message' } }]
    });
    my $t = Test::Mojo->new($app);

    $t->get_ok('/template_test', 'Accès à la route')
      ->status_is(200, '200 OK')
      ->content_like(qr{Message: Custom Message}, 'Message personnalisé transmis');
};

# Test 3 : L'application surcharge le template du plugin
subtest 'Surcharge par l\'application (priorité haute)' => sub {
    my $app_templates_dir = tempdir(CLEANUP => 1);

    # Créer le template de surcharge dans le dossier de l'app
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

    # Debug : vérifier les chemins (priorité app > plugin)
    $app->log->debug("Chemins renderer avec surcharge app :");
    $app->log->debug("  $_") for @{$app->renderer->paths};

    $t->get_ok('/template_test')
      ->status_is(200, '200 OK avec surcharge')
      ->content_like(qr{Welcome from Application Template}, 'Template application utilisé')
      ->content_like(qr{This template is provided by the application}, 'Texte de surcharge visible');
};


    # Test 4 : Surcharge + configuration personnalisée
    subtest 'Surcharge avec message configuré' => sub {
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
          ->content_like(qr{Application Template Override}, 'Titre de surcharge')
          ->content_like(qr{Message: Configured Message}, 'Message configuré transmis');
    };

    # Test 5 : Vérification que Fondation ajoute bien le chemin share/templates
    subtest 'Ajout automatique du chemin share/templates par Fondation' => sub {
        my $app = Mojolicious->new;
        $app->plugin('Fondation' => {
            plugins => ['Fondation::TemplateTest']
        });

        my $paths = $app->renderer->paths;
        ok(scalar @$paths >= 1, 'Au moins un chemin de template existe');

        my $found = grep {
            m{TemplateTest.*share.*templates}i
        } @$paths;

        ok($found, 'Chemin share/templates du plugin TemplateTest ajouté par Fondation');
    };

done_testing;

1
