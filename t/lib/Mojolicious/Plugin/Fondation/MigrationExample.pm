package Mojolicious::Plugin::Fondation::MigrationExample;

use Mojo::Base 'Mojolicious::Plugin::Fondation';

sub register {
    my ($self, $app, $conf) = @_;

    my $name = $conf->{name} // 'Guest';

    # This is a simple example plugin that demonstrates:
    # 1. A route
    # 2. Templates (in share/templates/)
    # 3. Database migrations (in share/migrations/)
    #
    # When loaded by Fondation, the migrations will be automatically
    # copied to the application's share/migrations/ directory.

    $app->routes->get('/migration-example')->to(cb => sub {
        my $c = shift;

        # Check if migrations were copied
        my $app_migrations_dir = $c->app->home->child('share', 'migrations');
        my $has_migrations = -d $app_migrations_dir && -f $app_migrations_dir->child('001_create_example.sql');

        $c->render(
            text => "Hello $name! This is the MigrationExample plugin.\n" .
                   "Migrations copied: " . ($has_migrations ? 'Yes' : 'No') . "\n" .
                   "Visit /migration-example-template for a template example."
        );
    });

    $app->routes->get('/migration-example-template')->to(cb => sub {
        my $c = shift;
        $c->stash(
            name => $name,
            plugin_name => 'MigrationExample'
        );
        $c->render(template => 'migration_example/welcome');
    });
}

1;