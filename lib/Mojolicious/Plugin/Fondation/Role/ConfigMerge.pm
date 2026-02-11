package Mojolicious::Plugin::Fondation::Role::ConfigMerge;
# ABSTRACT: Role for merging configuration in Fondation plugins

use Mojo::Base -role, -signatures;

around register => sub {
  my ($orig, $self, $app, $merged_conf) = @_;

  my $plugin_name = ref $self || $self;

  my $conf = {};
  if ( $self->can('conf') ){ $conf = $self->conf }

  my $final_config = {
    %{$conf},
    %{$merged_conf},
  };

  my $result = $orig->($self, $app, $final_config);

  return $result;
};

1;
