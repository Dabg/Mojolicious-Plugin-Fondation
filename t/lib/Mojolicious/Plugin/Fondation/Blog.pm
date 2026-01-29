package Mojolicious::Plugin::Fondation::Blog;

use Mojo::Base 'Mojolicious::Plugin::Fondation';

sub register {
    my ($self, $app, $conf) = @_;

    # Configuration: default title "my Blog", can be overridden by $conf
    my $title = $conf->{title} // "my Blog";

    # Declaration of sub-plugins (Security is a plugin dependent on Blog)
    $self->load_plugins($app, [
                            'Fondation::Security',
                            'Fondation::Session',
                 ]);

    $app->routes->get('/blog')->to(cb => sub {
        shift->render(text => "Welcome to $title");
    });
}

1;