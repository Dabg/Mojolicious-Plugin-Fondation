package Mojolicious::Plugin::Fondation::Security;

use Mojo::Base 'Mojolicious::Plugin::Fondation';

sub register {
    my ($self, $app, $conf) = @_;

    # Load CSRFProtect as a dependency
    $self->load_plugins($app, ['CSRFProtect']);
}

1;