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
