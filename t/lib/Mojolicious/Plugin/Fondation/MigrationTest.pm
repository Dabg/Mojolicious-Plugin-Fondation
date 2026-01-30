package Mojolicious::Plugin::Fondation::MigrationTest;

use Mojo::Base 'Mojolicious::Plugin::Fondation';

sub register {
    my ($self, $app, $conf) = @_;

    # Simple plugin that doesn't do much except exist
    # The migrations will be copied by Fondation automatically

    $app->routes->get('/migration-test' => sub {
        my $c = shift;
        $c->render(text => 'Migration Test Plugin Loaded');
    });
}

1;