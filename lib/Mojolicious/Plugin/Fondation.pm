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

# Convert short plugin name to full Mojolicious plugin name
sub _normalize_plugin_name ($self, $plugin_name) {
    # If it's already a full Mojolicious plugin name, keep it
    return $plugin_name if $plugin_name =~ /^Mojolicious::Plugin::/;

    # Otherwise, add Mojolicious::Plugin:: prefix
    return "Mojolicious::Plugin::$plugin_name";
}

# Convert full Mojolicious plugin name to short name for display
sub _shorten_plugin_name ($self, $plugin_name) {
    # Remove Mojolicious::Plugin:: prefix
    $plugin_name =~ s/^Mojolicious::Plugin:://;
    return $plugin_name;
}

# Get configuration for a plugin (only short names in config files)
sub _get_plugin_config ($self, $app, $plugin_name) {
    my $config = {};

    # Get normalized (long) name and short name
    my $long_name = $self->_normalize_plugin_name($plugin_name);
    my $short_name = $self->_shorten_plugin_name($long_name);
    
    # Only look for short name in configuration files
    # Users will use short names exclusively in their configs
    if (my $conf = $app->config($short_name)) {
        $config = $conf if ref $conf eq 'HASH';
    }

    return $config;
}

# Normalize a dependency (string or hash) to use full plugin names
sub _normalize_dependency ($self, $dep) {
    if (ref $dep eq 'HASH') {
        # Format: { 'Plugin::Name' => { config_hash } }
        my ($dep_name, $dep_conf) = each %$dep;
        my $normalized_name = $self->_normalize_plugin_name($dep_name);
        return { $normalized_name => $dep_conf };
    } else {
        # String format: 'Plugin::Name'
        my $normalized_name = $self->_normalize_plugin_name($dep);
        return $normalized_name;
    }
}



# Get dependencies for a plugin from direct config or global config
sub _get_dependencies ($self, $app, $conf, $instance = undef) {
    my $dependencies = [];

    # If direct config has dependencies, use them (highest priority)
    if ($conf && ref $conf eq 'HASH' && exists $conf->{dependencies}) {
        $dependencies = $conf->{dependencies};
    }
    # Otherwise, check global config (returns undef if Config plugin not loaded)
    elsif (my $global_conf = $app->config(($instance && ref($instance)) || __PACKAGE__)) {
        if (ref $global_conf eq 'HASH' && exists $global_conf->{dependencies}) {
            $dependencies = $global_conf->{dependencies};
        }
    }
    # Check plugin's default configuration
    elsif ($instance && $instance->can('conf') && defined $instance->conf->{dependencies}) {
        $dependencies = $instance->conf->{dependencies};
    }

    # Normalize all dependencies to use full plugin names
    my @normalized_deps;
    foreach my $dep (@$dependencies) {
        push @normalized_deps, $self->_normalize_dependency($dep);
    }

    return \@normalized_deps;
}

# Load a plugin and its dependencies recursively (depth-first)
sub _load_plugin ($self, $app, $plugin_name, $plugin_conf = {}) {
    # Normalize plugin name to full Mojolicious plugin name
    my $normalized_name = $self->_normalize_plugin_name($plugin_name);

    # Return already loaded plugin instance (check with normalized name)
    if (my $entry = $self->plugin_registry->{$normalized_name}) {
        return $entry->{instance};
    }

    # Get configuration for this plugin (trying both short and long names)
    my $global_plugin_conf = $self->_get_plugin_config($app, $plugin_name);

    # Merge configs: direct config (plugin_conf) takes priority over global config
    my $merged_conf = { %$global_plugin_conf, %$plugin_conf };

    # Load the plugin itself (parent)
    my $instance;
    if ($normalized_name eq __PACKAGE__) {
        # Fondation plugin itself
        $instance = $self;
    } else {
        # Load other plugin via Mojolicious (using normalized name)
        $instance = $app->plugin($normalized_name => $merged_conf);
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


    # Register the plugin in our registry using its actual class name (from ref)
    # This will be the full normalized name
    $self->plugin_registry->{ref($instance)} = {
        requires  => $dependencies,
        instance  => $instance,
    };

    return $instance;
}

# Generate a text representation of the plugin dependency tree
sub dependency_tree ($self) {
    my $short_name = $self->_shorten_plugin_name(__PACKAGE__);
    my $tree = "● " . $short_name . "\n";
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

        # Display short name
        my $short_name = $self->_shorten_plugin_name($dep_name);
        $output .= $indent . "└─ " . $short_name . "\n";
        $output .= $self->_build_tree($dep_name, $child_depth, $visited);
    }

    return $output;
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::Fondation - Recursive plugin dependency loader for Mojolicious

=head1 SYNOPSIS

  # In your Mojolicious application (short names are recommended)
  plugin 'Fondation' => {
    dependencies => [
      'Fondation::User',
      'Fondation::Authorization',
    ]
  };

  # Or with Config plugin loaded, define dependencies in config file:
  # {
  #   'Fondation' => {
  #     dependencies => [
  #       'Fondation::User',
  #       'Fondation::Authorization',
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
  # ● Fondation
  #  └─ Fondation::User
  #  └─ Fondation::Authorization
  #     └─ Fondation::Role
  #     └─ Fondation::Permission

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

Dependencies can be specified in two ways. Note that short plugin names (e.g., C<Fondation::User>) are recommended and will be automatically expanded to full Mojolicious plugin names (C<Mojolicious::Plugin::Fondation::User>).

=over 4

=item 1. Direct configuration (highest priority):

  plugin 'Fondation' => {
    dependencies => [
      'Fondation::User',
      { 'Fondation::Authorization' => { setting => 'value' } }
    ]
  };

=item 2. Global configuration (when Config plugin is loaded):

  # In your config file (use short names)
  {
    'Fondation' => {
      dependencies => [
        { 'Fondation::User' => { title => 'User' } },
        'Fondation::Authorization'
      ]
    }
  }

=back

Plugin-specific configuration can also be provided in the global config (use short names):

  {
    'Fondation::User' => {
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
