package Mojolicious::Plugin::Fondation::User;
use Mojo::Base 'Mojolicious::Plugin::Fondation::Base', -signatures;

use Role::Tiny::With;
with 'Mojolicious::Plugin::Fondation::Role::ConfigMerge';

has conf => sub { { key_test => 'plugin_default' } };

sub register {
    my ($self, $app, $conf) = @_;

    # Note: template directories are automatically added by Fondation
    # via _add_plugin_templates_path

    $app->routes->get('/test' => sub ($c) {
                          $c->render('hello');
                      });

    $app->config->{fondation_user_config} = $conf->{key_test};

    return $self;
}

1;
