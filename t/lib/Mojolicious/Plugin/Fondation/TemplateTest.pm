package Mojolicious::Plugin::Fondation::TemplateTest;

use Mojo::Base 'Mojolicious::Plugin::Fondation';

sub register {
    my ($self, $app, $conf) = @_;

    # Configuration: default message
    my $message = $conf->{message} // "Plugin Template";

    $app->log->debug("TemplateTest::register appelé – short_name = " . $self->short_name);

    # Add a route that renders a template


    $app->routes->get('/template_test')->to(cb => sub {
        my $c = shift;
        $c->stash(message => $message, template_source => 'plugin');
        $c->render(template => 'welcome');
    });

    $app->log->debug("TemplateTest::register exécuté !");

    return $self;
}

1;
