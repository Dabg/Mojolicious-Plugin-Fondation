package Mojolicious::Plugin::Fondation;

# ABSTRACT: Hierarchical plugin loader with configuration priority

use Mojo::Base 'Mojolicious::Plugin::Fondation::Base', -signatures;
use File::Copy;
use File::Path 'make_path';

# Registry of loaded plugins: plugin_name => { requires => [], instance => $plugin_obj }
has plugin_registry => sub { {} };
has fixture_sets => sub { [] };

sub register ($self, $app, $conf = {}) {
    $self->app($app);


    # Detect if we're running a database migration command
    # When running 'myapp.pl db prepare' or 'myapp.pl db populate', etc.
    # we should NOT copy plugin assets (migrations/fixtures) because
    # DBIx::Class::Migration will handle them
    $app->log->debug("Fondation: Checking main::ARGV: " . (defined $main::ARGV[0] ? $main::ARGV[0] : 'undef'));
    if (defined $main::ARGV[0] && $main::ARGV[0] eq 'db') {
        $self->is_db_migration(1);
        $app->log->debug("Fondation: Database migration command detected, skipping asset copy");
    } else {
        $app->log->debug("Fondation: Not a database migration command, is_db_migration will be false");
    }

    # Add helper to access Fondation instance from application
    $app->helper(fondation => sub { $self });

    # Add helper to directly get dependency tree
    $app->helper(fondation_tree => sub { $self->dependency_tree });

    # Load Fondation plugin itself with its dependencies
    # Dependencies will be determined inside _load_plugin based on config
    $self->_load_plugin($app, __PACKAGE__, $conf);

    return $self;
}

sub is_db_migration {
    my ($self, $value) = @_;
    if (@_ == 2) {
        $self->{is_db_migration} = $value;
    }
    return $self->{is_db_migration};
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
    my $short_name = $self->_shorten_plugin_name($plugin_name);

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
    #my @instance;

    if ($normalized_name eq __PACKAGE__) {
        # Fondation plugin itself
        $instance = $self;
    } else {
        # Load other plugin via Mojolicious (using normalized name)
        $instance = $app->plugin($normalized_name => $merged_conf);
    }

    # Il ne s'agit pas d'un plugin Fondation car leur register retourne le plugin lui-meme
    if ( $instance !~ /Mojolicious::Plugin/ ) {
        $app->log->debug("$short_name loaded");
        return;
    }

    $app->log->debug($self->_shorten_plugin_name(ref($instance)) . " loaded");

    my $template_dir;
    my $nb_dbic = 0;
    my $nb_migrations = 0;
    my $nb_fixtures = 0;
    if ( $instance->can('share_dir') && $instance->share_dir ){


        my $share_dir = $instance->share_dir;

        $app->log->debug("Plugin share_dir: " . $share_dir->to_string);
        # Add plugin's template directory to renderer paths
        $template_dir = $self->_add_plugin_templates_path($app, $instance);

        $self->_detect_plugin_fixture_sets($app, $instance);

        if ( ! $self->is_db_migration) {

            # Copy migration files from plugin to application
            $nb_migrations = $self->_copy_plugin_migrations($app, $instance);

            # Copy fixture files from plugin to application
            $nb_fixtures = $self->_copy_plugin_fixtures($app, $instance);
        }

        # load DBIC components
        $nb_dbic = $self->_add_plugin_dbic_components($app, $instance);
        if ($nb_dbic) {
            #$app->log->info("Plugin $short_name : $nb_dbic DBIC components integrated");
        }
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
        template_dir => $template_dir,
        dbic_components_added => $nb_dbic,
        migrations_copied => $nb_migrations,
        fixtures_copied => $nb_fixtures,
    };

    return $instance;
}

# Add plugin's template directory to renderer paths if it exists
sub _add_plugin_templates_path ($self, $app, $instance) {
    # Only plugins that inherit from Fondation::Base have share_dir method
    return unless $instance->can('share_dir');

    my $share_dir = $instance->share_dir;
    return unless $share_dir;

    return if ! -d $share_dir;

    my $template_dir = $share_dir->child('templates');
    return unless -d $template_dir;

    push @{$app->renderer->paths}, $template_dir->to_string;
    my ($short_template) = $template_dir =~ m{ share/ (.*) }x;
    $app->log->debug($self->_shorten_plugin_name(ref($instance)) . " : add template_dir : " . $short_template);
    return $template_dir->to_string;
}

# Dynamically load DBIC components (Result + custom ResultSet)
# from plugin namespaces, and register them immediately if the schema is available
sub _add_plugin_dbic_components ($self, $app, $instance) {

    return unless $instance->can('share_dir');

    my $share_dir = $instance->share_dir;
    return unless $share_dir && -d $share_dir;

    # Full plugin name (ex: Mojolicious::Plugin::Fondation::User)
    my $full_plugin_name = ref $instance;

    # Short name for logs (User, Auth, etc.)
    my $short_name = $self->_shorten_plugin_name($full_plugin_name);

    my $plugin_schema_ns = "${full_plugin_name}::Schema";

    # Automatic module discovery
    my @result_modules   = Mojo::Loader::find_modules("${plugin_schema_ns}::Result");
    my @resultset_modules = Mojo::Loader::find_modules("${plugin_schema_ns}::ResultSet");

    my @all_modules = (@result_modules, @resultset_modules);

    return 0 unless @all_modules;

    #$app->log->debug("$short_name : DBIC modules detected: " . join(', ', @all_modules));

    # Retrieve schema (with clear error message if absent)
    my $schema;
    eval { $schema = $app->schema };
    if ($@ || !$schema) {
        $app->log->warn(
            "$short_name : Cannot access schema via \$app->schema. " .
            "DBIC components will not be registered now. " .
            "Check that the schema helper exists and the schema is connected."
        );
        # We could store for later, but here we choose not to block
        return 0;
    }

    my $count_added = 0;

    # ────────────────────────────────────────────────
    # 1. Registration of Results
    # ────────────────────────────────────────────────
    for my $module (@result_modules) {
        eval "require $module" or do {
            $app->log->error("$short_name : require Result $module failed : $@");
            next;
        };

        # Extract source name: ...::Result::Article → Article
        my ($source_name) = $module =~ m{::Result::([^:]+)$};
        next unless $source_name;

        # Retrieve source without unnecessary instantiation
        my $source = $module->result_source_instance;

        # Registration
        $schema->register_extra_source($source_name, $source);
        $app->log->debug("$short_name : Result added " . $self->_shorten_plugin_name($module));

        $count_added++;
    }

    # ────────────────────────────────────────────────
    # 2. Registration of custom ResultSets
    # ────────────────────────────────────────────────
    for my $module (@resultset_modules) {
        eval "require $module" or do {
            $app->log->error("$short_name : require ResultSet $module failed : $@");
            next;
        };

        # Extract: ...::ResultSet::Article → Article
        my ($rs_name) = $module =~ m{::ResultSet::([^:]+)$};
        next unless $rs_name;

        # Check that source already exists (normally yes, because Result loaded before)
        if (my $source = $schema->source($rs_name)) {
            $source->resultset_class($module);
            $app->log->debug("$short_name : ResultSet added " . $self->_shorten_plugin_name($module));
            $count_added++;
        } else {
            $app->log->warn("$short_name : Cannot attach ResultSet $module → source $rs_name not found");
        }
    }

    # Stockage dans le registry (utile pour debug ou futur usage)
    $self->plugin_registry->{$full_plugin_name}{dbic_components_added} = $count_added;

    return $count_added;
}

# Copy plugin assets (migrations or fixtures) to application share directory
# Recursively copies files from plugin's share/$type to app's share/$type
sub _copy_plugin_assets ($self, $app, $instance, $type) {
    # Only plugins that inherit from Fondation::Base have share_dir method
    return unless $instance->can('share_dir');

    my $share_dir = $instance->share_dir;
    return unless $share_dir && -d $share_dir;

    # Get short plugin name for logging
    my $short_name = $self->_shorten_plugin_name(ref $instance);

    my $plugin_assets_dir = $share_dir->child($type);
    $app->log->debug("$short_name : checking $type directory: " . $plugin_assets_dir->to_string);
    return unless -d $plugin_assets_dir;

    $app->log->debug("$short_name : found $type directory: " . $plugin_assets_dir->to_string);

    # Ensure application share directory exists
    my $app_share_dir = $app->home->child('share');
    $app_share_dir->make_path unless -d $app_share_dir;

    # Target directory in application
    my $target_dir = $app_share_dir->child($type);
    $target_dir->make_path unless -d $target_dir;

    # Copy files recursively using Mojo::File's list_tree
    my $files_copied = 0;
    my $src_root = Mojo::File->new($plugin_assets_dir);

    for my $file ($src_root->list_tree({ hidden => 1 })->each) {
        next unless -f $file;

        # Calculate relative path from plugin assets directory using to_rel
        my $rel_path = $file->to_rel($src_root);

        # Target file path
        my $target_file = $target_dir->child($rel_path);

        # Create parent directory if needed
        $target_file->dirname->make_path unless -d $target_file->dirname;

        # Copy file if it doesn't exist or is newer
        if (!-e $target_file || (-M $file < -M $target_file)) {
            eval {
                $file->copy_to($target_file);
                $files_copied++;
                $app->log->debug("$short_name : $type file copied: $rel_path");
            };
            if ($@) {
                $app->log->error("$short_name : Failed to copy $type file $rel_path: $@");
                next;
            }
        } else {
            $app->log->debug("$short_name : $type file already exists: $rel_path");
        }
    }

    if ($files_copied) {
        $app->log->debug("$short_name : $files_copied $type files copied to application");
    }

    return $files_copied;
}

# Copy migration files from plugin to application
sub _copy_plugin_migrations ($self, $app, $instance) {
    return $self->_copy_plugin_assets($app, $instance, 'migrations');
}

# Copy fixture files from plugin to application
sub _copy_plugin_fixtures ($self, $app, $instance) {
    return $self->_copy_plugin_assets($app, $instance, 'fixtures');
}

# Detect fixture sets provided by a plugin (from its original share_dir)
sub _detect_plugin_fixture_sets ($self, $app, $instance) {
    return unless $instance->can('share_dir');

    my $share_dir = $instance->share_dir;
    return unless $share_dir && -d $share_dir;

    my $fixtures_dir = $share_dir->child('fixtures');
    return unless -d $fixtures_dir;

    my $short_name = $self->_shorten_plugin_name(ref $instance);
    my @sets;

    # Browse version directories (e.g., 1, 2...)
    for my $ver_dir ($fixtures_dir->list({dir => 1})->each) {
        next unless -d $ver_dir && $ver_dir->basename =~ /^\d+$/;

        my $conf_dir = $ver_dir->child('conf');
        next unless -d $conf_dir;

        for my $json ($conf_dir->list({file => 1})->each) {
            next unless $json->basename =~ /\.json$/i;
            my ($set_name) = $json->basename =~ /^(.+)\.json$/i;
            next unless $set_name;
            push @sets, $set_name;
        }
    }

    if (@sets) {
        $app->log->debug("$short_name : fixture sets detected → " . join(', ', @sets));
        push @{ $self->fixture_sets }, @sets;
        $self->plugin_registry->{ref $instance}{fixture_sets} = \@sets;
    }

    return scalar @sets;
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

=head1 AUTOMATIC PLUGIN ASSET HANDLING

Plugins that inherit from L<Mojolicious::Plugin::Fondation::Base> automatically gain
several asset management features through the C<share_dir> method. Fondation
automatically handles these assets when loading plugins:

=head2 Templates

If a plugin has a C<share/templates/> directory, Fondation automatically adds it
to the application's template search paths. This allows plugins to provide default
templates that can be overridden by the application.

  # Plugin structure:
  #   share/templates/plugin_name/template.html.ep

  # In your plugin code (automatic, no action needed):
  # The template directory is automatically added to renderer paths

=head2 Database Components (DBIC)

If a plugin has DBIC components (C<::Schema::Result::*> and C<::Schema::ResultSet::*> classes),
Fondation automatically loads and registers them with the application's schema
(when available via C<$app-E<gt>schema>). This allows plugins to provide database
models that integrate seamlessly with the application.

  # Plugin structure:
  #   lib/Mojolicious/Plugin/PluginName/Schema/Result/User.pm
  #   lib/Mojolicious/Plugin/PluginName/Schema/ResultSet/User.pm

  # In your application:
  my $user = $app->schema->resultset('User')->find(1);

=head2 Migrations

If a plugin has a C<share/migrations/> directory, Fondation automatically copies
the migration files to the application's C<share/migrations/> directory. This
allows plugins to provide database schema migrations that applications can apply
using migration tools like L<DBIx::Migrate::Simple>.

  # Plugin structure:
  #   share/migrations/SQLite/deploy/1/001-auto.sql
  #   share/migrations/_source/deploy/1/001-auto.yml

  # Files are copied to application's share/migrations/ directory
  # Existing files are not overwritten (preserves application modifications)

=head2 Fixtures

If a plugin has a C<share/fixtures/> directory, Fondation automatically copies
the fixture files to the application's C<share/fixtures/> directory. This allows
plugins to provide initial data or test data that applications can load into
their databases.

  # Plugin structure:
  #   share/fixtures/1/conf/all_tables.json
  #   share/fixtures/1/all_tables/users/1.fix

  # Files are copied to application's share/fixtures/ directory
  # Existing files are not overwritten (preserves application data)

=head2 Requirements

For these automatic features to work:

=over 4

=item * The plugin must inherit from L<Mojolicious::Plugin::Fondation::Base>

=item * The application must have a writable C<share/> directory in its home directory

=item * For DBIC components, the application must have a schema available via C<$app-E<gt>schema>

=item * For testing, set C<USE_SHARE_DIR_TEST=1> to use test share directories under C<t/share/>

=back

All asset copying operations are idempotent: files are only copied if they don't
exist or if the plugin's version is newer (based on file modification time).

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugins>, L<Mojolicious::Plugin::Config>,
L<Mojolicious::Plugin::Fondation::Base>

=head1 AUTHOR

Daniel Brosseau <dab@cpan.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
