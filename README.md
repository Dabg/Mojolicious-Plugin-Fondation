# Mojolicious::Plugin::Fondation

A Mojolicious plugin that enables hierarchical plugin loading with configuration priority management.

## Description

`Mojolicious::Plugin::Fondation` is a plugin system that allows plugins to load other plugins recursively, creating a hierarchical dependency tree.
## Installation

```bash
cpanm Mojolicious::Plugin::Fondation
```

Or from source:

```bash
perl Makefile.PL
make
make test
make install
```

## Usage

### Basic Usage

```perl
use Mojolicious::Lite;

# Load the Fondation plugin with its configuration
plugin 'Fondation' => {
    plugins => [
        { 'MyPlugin' => { option => 'value' } },
        'AnotherPlugin',
    ]
};

app->start;
```

### Creating Plugins

Your plugins should inherit from `Mojolicious::Plugin::Fondation`:

```perl
package Mojolicious::Plugin::MyPlugin;
use Mojo::Base 'Mojolicious::Plugin::Fondation';

sub register {
    my ($self, $app, $conf) = @_;

    # Access configuration with defaults
    my $title = $conf->{title} // 'Default Title';
    my $count = $conf->{count} // 42;

    # Load sub-plugins
    $self->load_plugins($app, [
        'SubPlugin1',
        { 'SubPlugin2' => { option => 'value' } }
    ]);

    # Your plugin logic here
    $app->routes->get('/myroute')->to(cb => sub {
        shift->render(text => "Title: $title, Count: $count");
    });
}

1;
```

## Methods

### load_plugins
```perl
$self->load_plugins($app, \@plugins);
```

Recursively loads plugins. Each plugin in the array can be:
- A string: `'PluginName'` (no direct configuration, will use app config or defaults)
- A hash reference with configuration: `{ 'PluginName' => { config => 'value' } }` (direct configuration)
- A hash reference with explicit empty configuration: `{ 'PluginName' => {} }` (explicit empty config, highest priority)

### graph
```perl
my $ascii_tree = Mojolicious::Plugin::Fondation->graph();
```

Returns an ASCII representation of the plugin dependency tree wrapped in `<pre>` tags.

## Configuration Priority Algorithm

When a plugin is loaded, the configuration is resolved in this order:

1. **Direct Configuration**: If a hash reference is provided directly to the plugin (even empty `{}`), it's used with highest priority.

```perl
plugin 'Fondation' => {
    plugins => [
        { 'MyPlugin' => { title => 'Custom Title' } }
    ]
};
```

2. **Application Configuration**: If no direct configuration is provided (string form or `undef`), the plugin looks for configuration in `$app->config('PluginName')`.

```perl
# Set configuration in application config
app->config('MyPlugin' => { title => 'App Title' });

# Load plugin without direct config (string form)
plugin 'Fondation' => {
    plugins => [
        'MyPlugin'  # Will use app config if available, otherwise plugin defaults
    ]
};
```

3. **Plugin Defaults**: If neither direct nor application configuration is found, the plugin uses its own default values (defined with `//` operator).

```perl
# No configuration provided anywhere
plugin 'Fondation' => {
    plugins => [
        'MyPlugin'  # Will use plugin defaults (no app config)
    ]
};
```

**Note**: An empty hash reference `{}` is treated as explicit empty configuration (direct configuration), while the string form or `undef` triggers the search for application configuration.

## Examples

See the `t/` directory for comprehensive examples:
- `t/00-load.t` - Basic loading tests
- `t/01-recursive-loading.t` - Recursive plugin loading tests
- `t/02-config-priority.t` - Configuration priority tests
- `t/03-template-resolution.t` - Template resolution tests
- `t/04-app-config.t` - Application configuration tests
- `t/05-migrations.t` - Database migration copying tests

### Example Application

A complete example application is available in `t/myapp.pl`. This application demonstrates:

1. Loading configuration from a file (`myapp.conf`)
2. Using Fondation with multiple plugins (`Fondation::Blog`, `Fondation::TemplateTest`, `Fondation::TemplateSubdirTest`, `Fondation::MigrationExample`)
3. Displaying the plugin dependency tree
4. Configuration priority in action
5. Template inheritance and override
6. Database migration copying

To run the example:

```bash
cd /path/to/Mojolicious-Plugin-Fondation
perl -Ilib -It/lib t/myapp.pl daemon   # Start development server
perl -Ilib -It/lib t/myapp.pl get /    # Test home page
perl -Ilib -It/lib t/myapp.pl get /blog # Test blog page with config
perl -Ilib -It/lib t/myapp.pl get /template-test # Test plugin template
perl -Ilib -It/lib t/myapp.pl get /template-override # Test application template override
perl -Ilib -It/lib t/myapp.pl get /template-info # Show template inheritance info
perl -Ilib -It/lib t/myapp.pl get /template-subdir-info # Show subdirectory template inheritance
perl -Ilib -It/lib t/myapp.pl get /migration-info # Show migration copying demonstration
perl -Ilib -It/lib t/myapp.pl get /migration-example # Test MigrationExample plugin route
perl -Ilib -It/lib t/myapp.pl get /migration-example-template # Test MigrationExample plugin template
perl -Ilib -It/lib t/myapp.pl get /template_test # Direct route from TemplateTest plugin
perl -Ilib -It/lib t/myapp.pl get /info # Show plugin information
```

The configuration file (`t/myapp.conf`) sets:
- Blog title for `Fondation::Blog`
- Message for `Fondation::TemplateTest`
- Message for `Fondation::TemplateSubdirTest`
- Name for `Fondation::MigrationExample`

#### Template Inheritance Demonstration

The application includes a template override demonstration:
- Plugin `Fondation::TemplateTest` provides: `t/lib/Mojolicious/Plugin/Fondation/TemplateTest/share/templates/welcome.html.ep`
- Application overrides with: `t/templates/welcome.html.ep`
- Application templates have priority over plugin templates

Visit `/template-info` to see detailed explanation of template resolution order and priority.

#### Migration Copying Demonstration

The application includes a migration copying demonstration:
- Plugin `Fondation::MigrationExample` provides migration files in `share/migrations/`
- Fondation automatically copies them to the application's `share/migrations/` directory
- Existing migration files are not overwritten

Visit `/migration-info` to see which migration files were copied and their status.

## Template Support

Fondation automatically discovers and adds template directories from plugins that follow the Mojolicious convention of placing templates in a `share/templates/` directory relative to the plugin's `.pm` file.

### How It Works

When a plugin is loaded through Fondation, it automatically scans for a `share/templates/` directory in the plugin's distribution path. If found, this directory is added to the application's renderer paths.

### Plugin Template Structure

Plugins can provide templates by organizing them as follows:

```
MyPlugin/
├── lib/
│   └── Mojolicious/
│       └── Plugin/
│           └── MyPlugin.pm
└── share/
    └── templates/
        ├── myplugin/
        │   └── index.html.ep
        └── welcome.html.ep
```

The plugin can then render these templates using standard Mojolicious template rendering:

```perl
# Inside your plugin's register method
$app->routes->get('/welcome')->to(
    template => 'welcome',
    message => $conf->{message} // 'Hello'
);
```

### Template Resolution Priority

Fondation respects Mojolicious's template resolution system, where templates are searched in the order they appear in the renderer paths. Application templates have priority over plugin templates when placed earlier in the path list.

1. **Application Templates**: Templates in the application's template directories are checked first
2. **Plugin Templates**: Templates from plugins are checked if not found in application directories

This means applications can easily override plugin templates by providing their own version with the same filename in their template directories.

### Example: Overriding a Plugin Template

If a plugin provides `share/templates/welcome.html.ep`, your application can override it by creating its own `welcome.html.ep` in the application's template directory.

```perl
# In your application
$app->renderer->paths(['/path/to/app/templates']);

# Create /path/to/app/templates/welcome.html.ep
# This file will be used instead of the plugin's version
```

## Database Migration Support

Fondation automatically discovers and copies database migration files from plugins that follow the convention of placing migrations in a `share/migrations/` directory relative to the plugin's `.pm` file.

### How It Works

When a plugin is loaded through Fondation, it automatically scans for a `share/migrations/` directory in the plugin's distribution path. If found, Fondation copies all migration files (`.sql` files) to the application's `share/migrations/` directory. Existing migration files with the same name are **not overwritten**, allowing applications to customize migrations while still getting defaults from plugins.

### Plugin Migration Structure

Plugins can provide database migrations by organizing them as follows:

```
MyPlugin/
├── lib/
│   └── Mojolicious/
│       └── Plugin/
│           └── MyPlugin.pm
└── share/
    └── migrations/
        ├── 001_create_users.sql
        ├── 002_add_email_column.sql
        └── 003_create_posts.sql
```

### Migration File Naming

Migration files should be named with a numeric prefix to ensure proper ordering (e.g., `001_`, `002_`, etc.). Fondation copies files in the order they appear in the directory (alphabetically).

### Usage in Applications

Once migrations are copied to the application's `share/migrations/` directory, they can be applied using any database migration tool. For example, with `DBIx::Migrate::Simple`:

```perl
use DBIx::Migrate::Simple;

my $migrator = DBIx::Migrate::Simple->new(
    schema_class => 'MyApp::Schema',
    schema_args  => ['dbi:SQLite:dbname=myapp.db'],
);

# Migrate to latest version (applies all migrations)
$migrator->migrate;
```

### Example Application with Migrations

The example application in `t/myapp.pl` demonstrates migration copying with the `Fondation::MigrationExample` plugin:

```bash
cd /path/to/Mojolicious-Plugin-Fondation
perl -Ilib -It/lib t/myapp.pl get /migration-info  # Show migration status
perl -Ilib -It/lib t/myapp.pl get /migration-example  # Test MigrationExample plugin
```

The application will automatically copy migration files from plugins to `t/share/migrations/`.

### Error Handling

If the application's home directory is not writable, Fondation logs a debug message and continues without error. This ensures that applications running in read-only environments (like some deployment scenarios) continue to function normally.

## Author

Daniel Brosseau <dab@cpan.org>

## License

This module is licensed under the same terms as Perl itself.

## See Also

- [Mojolicious](https://mojolicious.org) - The web framework
- [Mojolicious::Plugins](https://docs.mojolicious.org/Mojolicious/Plugins) - Plugin system documentation
- [Mojolicious::Plugin](https://docs.mojolicious.org/Mojolicious/Plugin) - Base class for plugins

## Support

Bug reports and feature requests can be submitted through:
- GitHub Issues: [https://github.com/dab/Mojolicious-Plugin-Fondation/issues](https://github.com/dab/Mojolicious-Plugin-Fondation/issues)
- CPAN RT: [https://rt.cpan.org/Public/Dist/Display.html?Name=Mojolicious-Plugin-Fondation](https://rt.cpan.org/Public/Dist/Display.html?Name=Mojolicious-Plugin-Fondation)
