# Mojolicious::Plugin::Fondation

A Mojolicious plugin that enables hierarchical plugin loading with configuration priority management.

## Description

`Mojolicious::Plugin::Fondation` is a plugin system that allows plugins to load other plugins recursively, creating a hierarchical dependency tree. It provides advanced configuration management with three levels of priority:

1. **Direct configuration** (highest priority) - Configuration passed directly when loading a plugin
2. **Application configuration** (medium priority) - Configuration stored in the application config
3. **Default configuration** (lowest priority) - Default values defined in the plugin itself

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

### Configuration Priority Examples

#### 1. Direct Configuration (Highest Priority)
```perl
plugin 'Fondation' => {
    plugins => [
        { 'MyPlugin' => { title => 'Custom Title' } }
    ]
};
```

#### 2. Application Configuration (Medium Priority)
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

#### 3. Default Configuration (Lowest Priority)
```perl
# No configuration provided anywhere
plugin 'Fondation' => {
    plugins => [
        'MyPlugin'  # Will use plugin defaults (no app config)
    ]
};
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

### Plugin Tree Visualization

You can visualize the plugin dependency tree:

```perl
get '/plugins' => sub {
    my $c = shift;
    my $graph = Mojolicious::Plugin::Fondation->graph();
    $c->render(text => $graph);
};
```

This will display an ASCII tree showing all loaded plugins and their dependencies.

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
2. **Application Configuration**: If no direct configuration is provided (string form or `undef`), the plugin looks for configuration in `$app->config('PluginName')`.
3. **Plugin Defaults**: If neither direct nor application configuration is found, the plugin uses its own default values (defined with `//` operator).

**Note**: An empty hash reference `{}` is treated as explicit empty configuration (direct configuration), while the string form or `undef` triggers the search for application configuration.

## Examples

See the `t/` directory for comprehensive examples:
- `t/00-load.t` - Basic loading tests
- `t/01-recursive-loading.t` - Recursive plugin loading tests
- `t/02-config-priority.t` - Configuration priority tests

## Development

### Running Tests

```bash
prove -l t/
```

Or with verbose output:

```bash
prove -lv t/
```

### Test Structure

The test suite includes example plugins in `t/lib/Mojolicious/Plugin/Fondation/`:
- `Blog.pm` - Example blog plugin with title configuration
- `Security.pm` - Security plugin with CSRF protection
- `Session.pm` - Session management plugin

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
