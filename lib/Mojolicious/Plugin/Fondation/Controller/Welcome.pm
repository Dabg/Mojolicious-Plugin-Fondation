package Mojolicious::Plugin::Fondation::Controller::Welcome;

# ABSTRACT: Welcome page controller with language-aware template selection

use Mojo::Base 'Mojolicious::Plugin::Fondation::Controller::Base', -signatures;

sub index ($self) {
    $self->render_later;
    my $c    = $self;
    my $lang = $c->stash('i18n_lang');
    unless ($lang) {
        ($lang) = ($c->req->headers->accept_language // '') =~ /^([a-z]{2})/i;
        $lang //= 'en';
    }

    # Only 'en' and 'fr' exist; fall back to 'en' for anything else
    $lang = 'en' unless $lang eq 'fr';

    my $has_setup = exists $c->app->fondation->registry->{'Mojolicious::Plugin::Fondation::Setup'};

    $c->render(
        template  => "welcome_$lang",
        has_setup => $has_setup,
    );
}

1;
