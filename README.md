# Mojolicious::Plugin::Fondation

A recursive plugin dependency loader for Mojolicious applications.

## Overview

Fondation is a Mojolicious plugin that loads other plugins and their dependencies recursively. It supports three levels of configuration priority:

1. **Direct configuration** (highest priority) – passed directly when loading Fondation
2. **Global configuration** – via Mojolicious::Plugin::Config
3. **Plugin default configuration** – via the plugin's `conf` attribute

This allows for flexible dependency management where plugins can define their own default dependencies, which can be overridden by application configuration or direct configuration.

## Installation

Since this is a development project, installation is currently done by cloning the repository:

```bash
# Clone the repository
git clone https://github.com/yourusername/Mojolicious-Plugin-Fondation.git
cd Mojolicious-Plugin-Fondation

# Install dependencies (Mojolicious, Mojo::Base, Role::Tiny, etc.)
cpanm --installdeps .

# Run tests to verify everything works
prove -lv t/
```

# Test
cd t
perl t/myapp.pl



```perl
plugin 'Fondation' => { ... };
```

## Quick Start

### Basic Usage

```perl
# In your Mojolicious application
use Mojolicious::Lite;

# Load Fondation with direct dependencies (short names are recommended)
plugin 'Fondation' => {
    dependencies => [
        'Fondation::User',
        'Fondation::Authorization',
    ]
};

# Plugins are loaded recursively. The resulting dependency tree:
# ● Fondation
#  └─ Fondation::User
#  └─ Fondation::Authorization
#     └─ Fondation::Role
#     └─ Fondation::Permission
```

### With Configuration File

First, create a configuration file (`myapp.conf`) using short plugin names:

```perl
{
  'Fondation' => {
    dependencies => [
      { 'Fondation::User' => { title => 'User Management' } },
      'Fondation::Authorization',
    ]
  },
  'Fondation::Authorization' => {
    dependencies => [
      'Fondation::Role',
      'Fondation::Permission',
    ]
  }
}
```

Then in your application:

```perl
use Mojolicious::Lite;

# Load Config plugin first
plugin 'Config';

# Load Fondation (will use configuration from Config)
plugin 'Fondation';

# All plugins and their dependencies are now loaded
# You can display the dependency tree:
app->log->info(app->fondation_tree);
```

## Configuration Priority

Fondation supports three levels of configuration with clear priority:

### 1. Direct Configuration (Highest Priority)
Configuration passed directly when loading Fondation:

```perl
plugin 'Fondation' => {
    dependencies => [
        { 'Plugin::A' => { setting => 'value' } },
        'Plugin::B',
    ]
};
```

### 2. Global Configuration (via Config Plugin)
Configuration from your application's config file:

```perl
# In config file:
{
  'Mojolicious::Plugin::Fondation' => {
    dependencies => ['Plugin::A', 'Plugin::B']
  }
}
```

### 3. Plugin Default Configuration
Plugins can define default configuration and dependencies:

```perl
package My::Plugin;

use Mojo::Base 'Mojolicious::Plugin';

has conf => sub { {
    dependencies => ['Plugin::C', 'Plugin::D'],
    default_setting => 'value'
} };

# The ConfigMerge role will merge configurations properly
with 'Mojolicious::Plugin::Fondation::Role::ConfigMerge';
```

## Creating Plugins with Dependencies

To create plugins that work with Fondation:

1. **Use the ConfigMerge role** to enable configuration merging:

```perl
package My::Plugin;

use Mojo::Base 'Mojolicious::Plugin';
use Role::Tiny::With;

with 'Mojolicious::Plugin::Fondation::Role::ConfigMerge';

has conf => sub { {
    dependencies => ['Required::Plugin'],
    other_config => 'value'
} };

sub register {
    my ($self, $app, $conf) = @_;
    # $conf contains merged configuration
    # (direct config > global config > plugin default)
    return $self;
}

1;
```

2. **Define dependencies** in the `conf` attribute or in configuration files.

## Examples

### Complex Dependency Tree

```perl
# Application code
plugin 'Fondation' => {
    dependencies => [
        'Main::Plugin',
    ]
};

# Configuration file:
{
  'Main::Plugin' => {
    dependencies => [
      'Sub::Plugin::A',
      { 'Sub::Plugin::B' => { option => 'custom' } }
    ]
  },
  'Sub::Plugin::A' => {
    dependencies => ['Utility::Plugin']
  }
}

# Result: Main::Plugin → Sub::Plugin::A → Utility::Plugin
#                    → Sub::Plugin::B (with custom option)
```

### Overriding Plugin Defaults

```perl
# Plugin defines default dependencies
package My::Plugin;
has conf => sub { { dependencies => ['Default::Dep'] } };

# Application overrides them
plugin 'Fondation' => {
    dependencies => [
        { 'My::Plugin' => { dependencies => ['Custom::Dep'] } }
    ]
};
# Result: My::Plugin loads Custom::Dep instead of Default::Dep
```

## API

### Fondation Helper

```perl
# Access the Fondation instance
my $fondation = $app->fondation;

# Check loaded plugins
my $registry = $fondation->plugin_registry;
# $registry is { plugin_name => { requires => [...], instance => $obj } }
```

### Dependency Tree

Get a visual representation of the plugin dependency hierarchy:

```perl
# Via helper
my $tree = $app->fondation_tree;
print $tree;
# Output:
# ● Fondation
#  └─ Fondation::User
#  └─ Fondation::Authorization
#     └─ Fondation::Role
#     └─ Fondation::Permission

# Or directly from Fondation instance
my $tree = $app->fondation->dependency_tree;
```

### Plugin Registry

The plugin registry tracks all loaded plugins and their dependencies:

```perl
my $fondation = $app->fondation;
my $registry = $fondation->plugin_registry;

foreach my $plugin_name (keys %$registry) {
    my $entry = $registry->{$plugin_name};
    my @deps = @{$entry->{requires}};
    my $instance = $entry->{instance};
    # ...
}
```


## License

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

## Author

Daniel Brosseau <dab@cpan.org>

## See Also

- [Mojolicious](https://mojolicious.org)
- [Mojolicious::Plugins](https://docs.mojolicious.org/Mojolicious/Plugins)
- [Mojolicious::Plugin::Config](https://docs.mojolicious.org/Mojolicious/Plugin/Config)
