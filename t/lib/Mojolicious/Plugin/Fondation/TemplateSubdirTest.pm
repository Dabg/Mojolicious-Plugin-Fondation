package Mojolicious::Plugin::Fondation::TemplateSubdirTest;

use Mojo::Base 'Mojolicious::Plugin::Fondation';

sub register {
    my ($self, $app, $conf) = @_;

    # Configuration
    my $message = $conf->{message} // "Plugin Subdirectory Template";

    $app->log->debug("TemplateSubdirTest::register called");

    # Add a route that renders a template from subdirectory
    $app->routes->get('/template_subdir_test')->to(cb => sub {
        my $c = shift;
        $c->stash(
            message => $message,
            template_source => 'plugin',
            template_path => 'Blog/test/other'
        );
        $c->render(template => 'Blog/test/other');
    });

    return $self;
}

1;