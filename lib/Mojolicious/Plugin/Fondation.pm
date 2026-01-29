package Mojolicious::Plugin::Fondation;
use Mojo::Base 'Mojolicious::Plugin';

# ABSTRACT: Hierarchical plugin loader with configuration priority

our $VERSION = '0.01';


# Tree to record plugins and their dependencies
our $TREE = {};

sub register {
    my ($self, $app, $conf) = @_;

    $TREE->{Fondation} ||= [];  # Initialize the root of the Fondation plugin (normalized name)

    # Load plugins declared in the configuration
    $self->load_plugins($app, $conf->{plugins});
}

# Normalize a plugin name: remove the Mojolicious::Plugin:: prefix
sub _normalize_name {
    my $name = shift;
    $name =~ s/^Mojolicious::Plugin:://;
    return $name;
}

# Recursive function to load plugins
sub load_plugins {
    my ($self, $app, $plugins) = @_;
    my $parent = _normalize_name(ref $self);

    for my $plugin (@$plugins) {
        my ($name, $args);
        if (ref($plugin) eq 'HASH') {
            # Hash with a single entry: key = plugin name, value = config (may be undef)
            ($name) = keys %$plugin;
            $args = $plugin->{$name};
            # If $args is undef, it means no direct configuration is provided
            # (ex: { 'Fondation::Blog' })
        } else {
            $name = $plugin;
            $args = undef;  # No direct configuration
        }

        # Normalize the name for searching in the application config
        my $normalized_name = _normalize_name($name);

        # Configuration priority:
        # 1. Direct configuration ($args defined and is a hashref) -> highest priority
        # 2. Otherwise, look in the application config under the key $normalized_name
        # 3. Otherwise, no configuration (undef)
        my $final_args = $args;
        if (!defined $args || ref $args ne 'HASH') {
            my $app_config = $app->config($normalized_name);
            if (defined $app_config && ref $app_config eq 'HASH') {
                $final_args = $app_config;
            } else {
                $final_args = {};
            }
        }

        # Record the parent-child relationship
        $TREE->{$parent} ||= [];
        push @{$TREE->{$parent}}, $normalized_name unless grep { $_ eq $normalized_name } @{$TREE->{$parent}};
        # Initialize the child entry (even if it has no dependencies)
        $TREE->{$normalized_name} ||= [];

        $name = 'Mojolicious::Plugin::' . $name;
        # Load the plugin and its arguments, which will itself load any other plugins.
        $app->plugin($name => $final_args);
    }
}

# Generate an ASCII representation of the plugin tree
sub graph {
    my $root = 'Fondation';
    my $tree = $TREE;
    my @lines = ($root);
    push @lines, _render_tree($root, $tree, '');
    return "<pre>". join("\n", @lines) .'</pre>';
}

sub _render_tree {
    my ($node, $tree, $prefix) = @_;
    my @out;
    my $children = $tree->{$node} || [];
    my $last_idx = $#{$children};
    for my $i (0..$last_idx) {
        my $child = $children->[$i];
        #my $short = $child;
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
