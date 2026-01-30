package Mojolicious::Plugin::Fondation;

# ABSTRACT: Hierarchical plugin loader with configuration priority

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::File 'path';

our $VERSION = '0.01';


# Tree to record plugins and their dependencies
our $TREE = {};

sub register {
    my ($self, $app, $conf) = @_;

    $TREE->{Fondation} ||= [];  # Initialize the root of the Fondation plugin (short name)

    # Load plugins declared in the configuration
    $self->load_plugins($app, $conf->{plugins});
}


# Unique method to get the short name
# - $self->short_name           → short name of current plugin
# - $self->short_name($name)    → normalize any plugin name
sub short_name {
    my ($self, $name) = @_;
    $name //= ref($self) || $self;           # if no arg, use current class/object
    $name =~ s/^Mojolicious::Plugin:://;
    return $name;
}




# Recursive function to load plugins
sub load_plugins {
    my ($self, $app, $plugins) = @_;
    my $parent = $self->short_name;

    for my $plugin (@$plugins) {
        my ($name, $args);
        if (ref $plugin eq 'HASH') {
            ($name) = keys %$plugin;
            $args   = $plugin->{$name};
        } else {
            $name = $plugin;
            $args = undef;
        }

        my $child_short_name = $self->short_name($name);

        # Configuration priority
        my $final_args = (defined $args && ref $args eq 'HASH')
            ? $args
            : ($app->config($child_short_name) // {});

        # Record the parent-child relationship
        $TREE->{$parent} ||= [];
        push @{$TREE->{$parent}}, $child_short_name
            unless grep { $_ eq $child_short_name } @{$TREE->{$parent}};
        $TREE->{$child_short_name} ||= [];

        # Load plugin
        my $full_plugin_name = 'Mojolicious::Plugin::' . $name;
        $app->plugin($full_plugin_name => $final_args);

        my $share_dir = $self->share_dir($app, $full_plugin_name, $child_short_name);

        # Automatically add its share/templates if exists
        $self->_add_plugin_templates_path($app, $share_dir, $child_short_name);
    }
}


sub share_dir {
    my $self = shift;
    my $app = shift;
    my $full_plugin_name = shift;
    my $child_short_name = shift;

    (my $module_path = $full_plugin_name) =~ s!::!/!g;
    $module_path .= '.pm';

    my $plugin_file = $INC{$module_path};

    return unless defined $plugin_file && -f $plugin_file;

    my $plugin_lib_dir = File::Basename::dirname($plugin_file);

    # Le short_name est 'Fondation::TemplateTest', mais le dossier est 'TemplateTest'
    my $child_folder = $child_short_name;
    $child_folder =~ s/^.*:://;

    my $plugin_dir = File::Spec->catdir($plugin_lib_dir, $child_folder);
    my $share_dir = File::Spec->catdir($plugin_dir, 'share');

    return $share_dir;
}


sub _add_plugin_templates_path {
    my ($self, $app, $share_dir, $child_short_name) = @_;

    my $templates_dir = File::Spec->catdir($share_dir, 'templates');

    return unless -d $templates_dir;

    my $paths = $app->renderer->paths;
    return if grep { $_ eq $templates_dir } @$paths;

    push @$paths, $templates_dir;

    $app->log->debug("Fondation: Added share/templates from plugin '$child_short_name': $templates_dir");
}

# Generate an ASCII representation of the plugin tree
sub graph {
    my $root = 'Fondation';
    my @lines = ($root);
    push @lines, _render_tree($root, $TREE, '');
    return "<pre>" . join("\n", @lines) . "</pre>";
}

sub _render_tree {
    my ($node, $tree, $prefix) = @_;
    my @out;
    my $children = $tree->{$node} || [];
    my $last_idx = $#{$children};
    for my $i (0 .. $last_idx) {
        my $child     = $children->[$i];
        my $connector = ($i == $last_idx) ? '`- ' : '+- ';
        push @out, $prefix . $connector . $child;
        my $new_prefix = $prefix . ($i == $last_idx ? '   ' : '|  ');
        push @out, _render_tree($child, $tree, $new_prefix);
    }
    return @out;
}

1;

__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Fondation - Hierarchical plugin loader with configuration priority

=head1 SYNOPSIS

  use Mojolicious::Lite;

  # Load Fondation with direct configuration
  plugin 'Fondation' => {
    plugins => [
      { 'MyPlugin' => { option => 'value' } },
      'AnotherPlugin',
    ]
  };

  # Or with application configuration
  app->config('MyPlugin' => { option => 'app_value' });
  plugin 'Fondation' => {
    plugins => [
      'MyPlugin'  # Uses app config
    ]
  };

  # Display plugin dependency tree
  get '/plugins' => sub {
    my $c = shift;
    my $graph = Mojolicious::Plugin::Fondation->graph();
    $c->render(text => $graph);
  };

  app->start;

=head1 DESCRIPTION

Mojolicious::Plugin::Fondation provides a hierarchical plugin loading system
that allows plugins to load other plugins recursively. It includes a sophisticated
configuration management system with three levels of priority:

=over 4

=item 1. Direct configuration (highest priority)

=item 2. Application configuration (medium priority)

=item 3. Default plugin configuration (lowest priority)

=back

Plugins that inherit from C<Mojolicious::Plugin::Fondation> can use the
C<load_plugins> method to load their own dependencies, creating a tree
structure of plugins.

=head1 METHODS

=head2 register

  $plugin->register($app, $conf);

Called by Mojolicious when the plugin is loaded. Initializes the plugin tree
and loads the plugins specified in C<$conf-E<gt>{plugins}>.

=head2 load_plugins

  $self->load_plugins($app, \@plugins);

Recursively loads plugins. Each element in C<@plugins> can be:

=over 4

=item * A string: C<'PluginName'> (no direct configuration)

=item * A hash reference with configuration: C<{ 'PluginName' => { config => 'value' } }>

=item * A hash reference with explicit no configuration: C<{ 'PluginName' => undef }> or C<{ 'PluginName' => {} }>

=back

For plugins without direct configuration, the string form is recommended.
An empty hash reference C<{}> is treated as explicit empty configuration
(highest priority), while C<undef> or omitting the configuration causes
the plugin to look for application configuration.

The configuration priority is:

=over 4

=item 1. Direct configuration (hash reference, even empty C<{}>) - highest priority

=item 2. If no direct configuration is provided (string form or C<undef>), the plugin
looks for configuration in C<$app-E<gt>config('PluginName')>.

=item 3. If neither direct nor application configuration exists, an empty hash
reference is passed to the plugin (default values).

=back

Note that an empty hash reference C<{}> is treated as explicit empty
configuration (direct configuration), while C<undef> or the string form
triggers the search for application configuration.

=head2 graph

  my $ascii_tree = Mojolicious::Plugin::Fondation->graph();

Returns an ASCII representation of the plugin dependency tree wrapped in
C<E<lt>preE<gt>> tags. Useful for debugging and visualization.

=head2 _normalize_name

  my $normalized = _normalize_name($name);

Internal method that removes the C<Mojolicious::Plugin::> prefix from plugin
names for consistency in the tree structure.

=head1 CREATING PLUGINS

To create a plugin that works with Fondation, inherit from
C<Mojolicious::Plugin::Fondation>:

  package Mojolicious::Plugin::MyPlugin;
  use Mojo::Base 'Mojolicious::Plugin::Fondation';

  sub register {
    my ($self, $app, $conf) = @_;

    # Access configuration with defaults
    my $title = $conf->{title} // 'Default Title';

    # Load sub-plugins
    $self->load_plugins($app, [
      'SubPlugin1',
      { 'SubPlugin2' => { option => 'value' } }
    ]);

    # Your plugin logic
    $app->routes->get('/myroute')->to(cb => sub {
      shift->render(text => "Title: $title");
    });
  }

  1;

=head1 CONFIGURATION PRIORITY

=over 4

=item B<Direct Configuration>

  plugin 'Fondation' => {
    plugins => [
      { 'MyPlugin' => { title => 'Direct Title' } }
    ]
  };

The configuration hash is passed directly to the plugin. Highest priority.

=item B<Application Configuration>

  app->config('MyPlugin' => { title => 'App Title' });
  plugin 'Fondation' => {
    plugins => [
      'MyPlugin'  # No direct config, uses app config if available
    ]
  };

The plugin looks for configuration in the application config under its
normalized name. Medium priority.

=item B<Default Configuration>

  plugin 'Fondation' => {
    plugins => [
      'MyPlugin'  # No config anywhere, uses plugin defaults
    ]
  };

The plugin uses its own default values (defined with C<//> operator).
Lowest priority.

=back

=head1 EXAMPLES

See the C<t/> directory for comprehensive test examples and C<examples/>
directory for working applications.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugins>, L<Mojolicious::Plugin>

=head1 AUTHOR

Daniel Brosseau, E<lt>dab@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2026 by Daniel Brosseau

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
