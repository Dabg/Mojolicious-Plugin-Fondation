package TestHelper;

use strict;
use warnings;
use Mojolicious;
use Mojo::Home;
use File::Temp 'tempdir';
use File::Spec;

our @EXPORT_OK = qw(create_test_app);

use base 'Exporter';

# Helper function to create a test app with a temporary home
sub create_test_app {
    my ($temp_dir) = @_;

    # If no temp_dir provided, create one
    if (!$temp_dir) {
        $temp_dir = tempdir(CLEANUP => 1);
    }

    my $app = Mojolicious->new;

    # Set home to temporary directory
    my $app_home = File::Spec->catdir($temp_dir, 'app_home');
    mkdir $app_home or die "Cannot create app_home: $!";
    $app->home(Mojo::Home->new($app_home));

    # Create share directory to avoid permission errors
    my $share_dir = $app->home->child('share');
    $share_dir->make_path unless -d $share_dir;

    return $app;
}


1;
