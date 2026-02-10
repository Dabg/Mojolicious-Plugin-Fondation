package Mojolicious::Plugin::Fondation;

use Mojo::Base 'Mojolicious::Plugin::Fondation::Base', -signatures;

# Registry of loaded plugins: plugin_name => { requires => [], instance => $plugin_obj }
has plugin_registry => sub { {} };

sub register ($self, $app, $conf = {}) {

    # Add helper to access Fondation instance from application
    $app->helper(fondation => sub { $self });

    # Add helper to directly get dependency tree
    $app->helper(fondation_tree => sub { $self->dependency_tree });

    # Load Fondation plugin itself with its dependencies
    # Dependencies will be determined inside _load_plugin based on config
    $self->_load_plugin($app, __PACKAGE__, $conf);

    return $self;
}



# Get dependencies for a plugin from direct config or global config
sub _get_dependencies ($self, $app, $conf, $instance = undef) {

    # If direct config has dependencies, use them (highest priority)
    if ($conf && ref $conf eq 'HASH' && exists $conf->{dependencies}) {
        return $conf->{dependencies};
    }

    # Otherwise, check global config (returns undef if Config plugin not loaded)
    my $global_conf = $app->config(($instance && ref($instance)) || __PACKAGE__);
    if ($global_conf && ref $global_conf eq 'HASH' && exists $global_conf->{dependencies}) {
        return $global_conf->{dependencies};
    }

    if ( $instance->can('conf') && defined $instance->conf->{dependencies}){
        return $instance->conf->{dependencies};
    }

    # No dependencies found
    return [];
}

# Load a plugin and its dependencies recursively (depth-first)
sub _load_plugin ($self, $app, $plugin_name, $plugin_conf = {}) {
    # Return already loaded plugin instance
    if (my $entry = $self->plugin_registry->{$plugin_name}) {
        return $entry->{instance};
    }

    # Get configuration for this specific plugin from global config
    my $global_plugin_conf = $app->config($plugin_name) || {};

    # Merge configs: direct config (plugin_conf) takes priority over global config
    my $merged_conf = { %$global_plugin_conf, %$plugin_conf };

    # Load the plugin itself (parent)
    my $instance;
    if ($plugin_name eq __PACKAGE__) {
        # Fondation plugin itself
        $instance = $self;
    } else {
        # Load other plugin via Mojolicious
        $instance = $app->plugin($plugin_name => $merged_conf);
    }


    # Get dependencies for this plugin
    my $dependencies = $self->_get_dependencies($app, $merged_conf, $instance);

    # First, load all dependencies (children)
    my @dependency_instances;
    foreach my $dep (@$dependencies) {
        # Dependency can be a string (plugin name) or hash { plugin_name => config }
        my ($dep_name, $dep_conf);
        if (ref $dep eq 'HASH') {
            # Format: { 'Plugin::Name' => { config_hash } }
            ($dep_name, $dep_conf) = each %$dep;
            $dep_conf ||= {};
        } else {
            $dep_name = $dep;
            $dep_conf = {};
        }

        my $dep_instance = $self->_load_plugin($app, $dep_name, $dep_conf);
        push @dependency_instances, $dep_instance;
    }


    # Register the plugin in our registry
    $self->plugin_registry->{ref($instance)} = {
        requires  => $dependencies,
        instance  => $instance,
    };

    return $instance;
}

# Generate a text representation of the plugin dependency tree
sub dependency_tree ($self) {
    my $tree = "● " . __PACKAGE__ . "\n";
    $tree .= $self->_build_tree(__PACKAGE__, 0, {});
    return $tree;
}

# Recursively build the dependency tree for a plugin
sub _build_tree ($self, $plugin_name, $depth, $visited) {
    # Avoid cycles
    return "" if $visited->{$plugin_name}++;

    my $output = "";

    my $entry = $self->plugin_registry->{$plugin_name};
    return "" unless $entry;

    my @deps = @{$entry->{requires} || []};

    foreach my $dep (@deps) {
        my $dep_name;
        if (ref $dep eq 'HASH') {
            # Extract plugin name from hash { plugin_name => config }
            # There should be exactly one key
            my @keys = keys %$dep;
            $dep_name = $keys[0] if @keys;
        } else {
            $dep_name = $dep;
        }

        # Calculate indent for child: 4 spaces between levels, starting with 1 space for level 1
        my $child_depth = $depth + 1;
        my $indent = $child_depth == 0 ? "" : " " x (($child_depth - 1) * 4 + 1);

        $output .= $indent . "└─ " . $dep_name . "\n";
        $output .= $self->_build_tree($dep_name, $child_depth, $visited);
    }

    return $output;
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::Fondation - Recursive plugin dependency loader for Mojolicious

=head1 SYNOPSIS

  # In your Mojolicious application
  plugin 'Fondation' => {
    dependencies => [
      'Mojolicious::Plugin::Fondation::User',
      'Mojolicious::Plugin::Fondation::Authorization',
    ]
  };

  # Or with Config plugin loaded, define dependencies in config file:
  # {
  #   'Mojolicious::Plugin::Fondation' => {
  #     dependencies => [
  #       'Mojolicious::Plugin::Fondation::User',
  #       'Mojolicious::Plugin::Fondation::Authorization',
  #     ]
  #   }
  # }

=head1 DESCRIPTION

Mojolicious::Plugin::Fondation provides recursive plugin dependency loading for
Mojolicious applications. It can load plugins and their dependencies recursively,
with direct configuration taking priority over global configuration.

=head1 METHODS

=head2 register

  $plugin->register($app, $conf);

Registers the plugin in the Mojolicious application. The C<$conf> hash can contain
a C<dependencies> array reference with plugin names to load.

=head2 dependency_tree

  my $tree = $plugin->dependency_tree;
  # Returns a text representation of the plugin dependency tree
  # Example:
  # ● Mojolicious::Plugin::Fondation
  #  └─ Mojolicious::Plugin::Fondation::User
  #  └─ Mojolicious::Plugin::Fondation::Authorization
  #     └─ Mojolicious::Plugin::Fondation::Role
  #     └─ Mojolicious::Plugin::Fondation::Permission

=head1 HELPERS

The plugin adds two helpers to your Mojolicious application:

=head2 fondation

  my $fondation = $app->fondation;
  # Returns the Fondation plugin instance

=head2 fondation_tree

  my $tree = $app->fondation_tree;
  # Returns the dependency tree as a string
  # Same as $app->fondation->dependency_tree

=head1 CONFIGURATION

Dependencies can be specified in two ways:

=over 4

=item 1. Direct configuration (highest priority):

  plugin 'Fondation' => {
    dependencies => [
      'Mojolicious::Plugin::Fondation::User',
      { 'Mojolicious::Plugin::Fondation::Authorization' => { setting => 'value' } }
    ]
  };

=item 2. Global configuration (when Config plugin is loaded):

  # In your config file
  {
    'Mojolicious::Plugin::Fondation' => {
      dependencies => [
        { 'Mojolicious::Plugin::Fondation::User' => { title => 'User' } },
        'Mojolicious::Plugin::Fondation::Authorization'
      ]
    }
  }

=back

Plugin-specific configuration can also be provided in the global config:

  {
    'Mojolicious::Plugin::Fondation::User' => {
      some_setting => 'value',
      dependencies => ['Plugin::C']  # This plugin can have its own dependencies
    }
  }

Each dependency in the C<dependencies> array can be either a plugin name (string)
or a hash reference with the plugin name as key and its configuration as value.
This allows passing specific configuration to child plugins.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugins>, L<Mojolicious::Plugin::Config>

=head1 AUTHOR

Daniel Brosseau <dab@cpan.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
