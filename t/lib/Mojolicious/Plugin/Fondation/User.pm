package Mojolicious::Plugin::Fondation::User;
use Mojo::Base 'Mojolicious::Plugin::Fondation::Base';

use Role::Tiny::With;
with 'Mojolicious::Plugin::Fondation::Role::ConfigMerge';

has conf => sub { { key_test => 'plugin_default' } };

sub register {
    my ($self, $app, $conf) = @_;

    my $share = $self->share_dir;

    # to test share_dir
    my $template_dir = $share->child('templates');
    if (-d $template_dir) {
        push @{$app->renderer->paths}, $template_dir->to_string;
    }


    $app->config->{fondation_user_config} = $conf->{key_test};

    return $self;
}

1;
