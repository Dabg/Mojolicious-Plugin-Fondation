package Mojolicious::Plugin::Fondation::Session;

use Mojo::Base 'Mojolicious::Plugin::Fondation';

sub register {
    my ($self, $app, $conf) = @_;

    # Configuration: session timeout default 3600 seconds
    my $timeout = $conf->{timeout} // 3600;

    # Register a helper to access the timeout
    $app->helper('session.timeout' => sub { $timeout });

    # Display a log message for testing
    $app->log->debug("Session plugin loaded with timeout: $timeout seconds");
}

1;
