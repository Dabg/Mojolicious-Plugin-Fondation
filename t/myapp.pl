#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use File::Basename;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use Mojolicious::Lite;

# Demonstration application for Mojolicious::Plugin::Fondation
# This application shows how to use Fondation with configuration files,
# template inheritance, migration copying, and the Fondation plugins.
#
# Configuration is loaded from myapp.conf in the same directory.
#
# Usage:
#   perl t/myapp.pl daemon   # Start development server
#   perl t/myapp.pl get /    # Test home page
#   perl t/myapp.pl get /blog # Test blog page
#   perl t/myapp.pl get /template-test # Test plugin template
#   perl t/myapp.pl get /template-override # Test application template override
#   perl t/myapp.pl get /template-info # Show template inheritance info
#   perl t/myapp.pl get /template-subdir-info # Show subdirectory template inheritance
#   perl t/myapp.pl get /migration-info # Show migration copying demonstration
#   perl t/myapp.pl get /migration-example # Test MigrationExample plugin route
#   perl t/myapp.pl get /migration-example-template # Test MigrationExample plugin template
#   perl t/myapp.pl get /info # Show plugin information
#   perl t/myapp.pl get /template_test # Direct route from TemplateTest plugin
#
# The configuration file (myapp.conf) sets configuration for all plugins.
#
# This application demonstrates:
# 1. Template inheritance:
#    - Plugin TemplateTest provides: t/lib/Mojolicious/Plugin/Fondation/TemplateTest/share/templates/welcome.html.ep
#    - Application overrides with: t/templates/welcome.html.ep
#    - Application templates have priority over plugin templates.
# 2. Migration copying:
#    - Plugins can provide migration files in share/migrations/
#    - Fondation automatically copies them to the application's share/migrations/
#    - Existing files are not overwritten
# 3. Plugin dependency tree:
#    - Fondation tracks plugin dependencies and provides a visualization

# Load configuration from myapp.conf
plugin 'Config';

# Load Fondation with plugins configured in the config file
plugin 'Fondation' => {
    plugins => [
        'Fondation::Blog',
        'Fondation::TemplateTest',
        'Fondation::TemplateSubdirTest',
        'Fondation::MigrationExample'
    ]
};

# Add a route to display plugin information
get '/info' => sub {
    my $c = shift;

    # Get configuration for Blog plugin
    my $blog_config = $c->config('Fondation::Blog') || {};
    my $blog_title = $blog_config->{title} || 'default (not configured)';

    # Display plugin tree
    no warnings 'once';
    my $tree = $Mojolicious::Plugin::Fondation::TREE;

    my $response = <<"END_INFO";
<!DOCTYPE html>
<html>
<head><title>Fondation Test App</title></head>
<body>
<h1>Fondation Test Application</h1>

<h2>Blog Plugin Configuration</h2>
<p>Title: $blog_title</p>

<h2>Plugin Dependency Tree</h2>
<pre>
END_INFO

    $response .= Mojolicious::Plugin::Fondation->graph();

    $response .= <<"END_INFO";
</pre>

<h2>Available Routes</h2>
<ul>
<li><a href="/">Home</a></li>
<li><a href="/blog">Blog</a></li>
<li><a href="/template-test">Template Test (Plugin)</a></li>
<li><a href="/template-override">Template Override (Application)</a></li>
<li><a href="/template-info">Template Information</a></li>
<li><a href="/template-subdir-test">Subdirectory Template Test</a></li>
<li><a href="/template-subdir-override">Subdirectory Template Override</a></li>
<li><a href="/template-subdir-info">Subdirectory Template Information</a></li>
<li><a href="/migration-info">Migration Information</a></li>
<li><a href="/migration-example">Migration Example Plugin</a></li>
<li><a href="/migration-example-template">Migration Example Template</a></li>
<li><a href="/info">Plugin Info</a></li>
</ul>

</body>
</html>
END_INFO

    $c->render(text => $response);
};

# Route 1: Test plugin template (demonstrates application override)
get '/template-test' => sub {
    my $c = shift;
    $c->stash(
        message => 'Testing plugin template (but using application override)',
        template_source => 'application (overrides plugin)'
    );
    $c->render(template => 'welcome');
};

# Route 2: Test template override with custom message (uses application template)
get '/template-override' => sub {
    my $c = shift;
    $c->stash(
        message => 'Testing application template override',
        template_source => 'application (explicit override)'
    );
    $c->render(template => 'welcome');
};

# Route 3: Direct route from TemplateTest plugin
# This route is defined by the TemplateTest plugin itself
# It will use either plugin or application template based on availability

# Route 4: Template information page
get '/template-info' => sub {
    my $c = shift;

    # Get renderer paths to show template resolution order
    my @paths = @{app->renderer->paths};

    # Check if template exists in application directory
    my $app_template_exists = -f "$FindBin::Bin/templates/welcome.html.ep";
    my $plugin_template_path = "$FindBin::Bin/lib/Mojolicious/Plugin/Fondation/TemplateTest/share/templates/welcome.html.ep";
    my $plugin_template_exists = -f $plugin_template_path;

    my $response = <<"END_INFO";
<!DOCTYPE html>
<html>
<head><title>Template Inheritance Information</title>
<style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
    .info-box { background-color: #f0f8ff; border: 1px solid #4a90e2; padding: 15px; border-radius: 5px; margin: 10px 0; }
    .path-list { background-color: #f9f9f9; padding: 10px; border-left: 3px solid #ccc; }
</style>
</head>
<body>
<h1>Template Inheritance Demonstration</h1>

<div class="info-box">
<h2>How Template Resolution Works in Fondation</h2>
<p>When Fondation loads a plugin, it automatically adds the plugin's <code>share/templates/</code> directory to the renderer paths.</p>
<p>Application templates (in <code>t/templates/</code>) are checked first, then plugin templates.</p>
<p>This means: if the application provides a template with the same name as a plugin template, the application version will be used.</p>
</div>

<h2>Template Resolution Order</h2>
<p>Templates are searched in this order (first match wins):</p>
<div class="path-list">
<ol>
END_INFO

    foreach my $i (0..$#paths) {
        $response .= "<li>$paths[$i]</li>\n";
    }

    $response .= <<"END_INFO";
</ol>
</div>

<h2>Template Availability</h2>
<ul>
<li>Plugin Template: <code>$plugin_template_path</code> - <strong>@{[$plugin_template_exists ? 'EXISTS' : 'NOT FOUND']}</strong></li>
<li>Application Template: <code>$FindBin::Bin/templates/welcome.html.ep</code> - <strong>@{[$app_template_exists ? 'EXISTS (OVERRIDE)' : 'NOT FOUND']}</strong></li>
</ul>

<h2>Test Routes</h2>
<ul>
<li><a href="/template-test">Template Test</a> - Renders welcome template with plugin message</li>
<li><a href="/template-override">Template Override</a> - Renders welcome template with application message</li>
<li><a href="/template_test">Direct Plugin Route</a> - Route defined by TemplateTest plugin itself</li>
</ul>

<p><strong>Note:</strong> Both test routes render the same template name (<code>welcome</code>), but the application template will be used because it exists in the application directory.</p>

</body>
</html>
END_INFO

    $c->render(text => $response);
};

# Route 5: Template subdirectory information page
get '/template-subdir-info' => sub {
    my $c = shift;

    # Check if templates exist
    my $plugin_template_path = "$FindBin::Bin/lib/Mojolicious/Plugin/Fondation/TemplateSubdirTest/share/templates/Blog/test/other.html.ep";
    my $app_template_path = "$FindBin::Bin/templates/Blog/test/other.html.ep";
    my $plugin_template_exists = -f $plugin_template_path;
    my $app_template_exists = -f $app_template_path;

    my $response = <<"END_INFO";
<!DOCTYPE html>
<html>
<head><title>Subdirectory Template Inheritance</title>
<style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
    .info-box { background-color: #f0f8ff; border: 1px solid #4a90e2; padding: 15px; border-radius: 5px; margin: 10px 0; }
    .path-list { background-color: #f9f9f9; padding: 10px; border-left: 3px solid #ccc; }
</style>
</head>
<body>
<h1>Subdirectory Template Inheritance Demonstration</h1>

<div class="info-box">
<h2>How Subdirectory Template Resolution Works</h2>
<p>Fondation's template resolution works the same way for subdirectories as for root templates.</p>
<p>When a plugin provides templates in subdirectories like <code>Blog/test/other.html.ep</code>,</p>
<p>the application can override them by placing a template at the same relative path.</p>
</div>

<h2>Template Availability</h2>
<ul>
<li>Plugin Template: <code>$plugin_template_path</code> - <strong>@{[$plugin_template_exists ? 'EXISTS' : 'NOT FOUND']}</strong></li>
<li>Application Template: <code>$app_template_path</code> - <strong>@{[$app_template_exists ? 'EXISTS (OVERRIDE)' : 'NOT FOUND']}</strong></li>
</ul>

<h2>Test Routes</h2>
<ul>
<li><a href="/template-subdir-test">Subdirectory Template Test</a> - Tests plugin subdirectory template (application override)</li>
<li><a href="/template-subdir-override">Subdirectory Template Override</a> - Tests application override in subdirectory</li>
<li><a href="/template_subdir_test">Direct Plugin Route</a> - Route defined by TemplateSubdirTest plugin</li>
</ul>

<p><strong>Note:</strong> All routes render the same template <code>Blog/test/other</code>, but the application template will be used because it exists in the application directory.</p>

</body>
</html>
END_INFO

    $c->render(text => $response);
};

# Route 6: Migration information page (demonstrates migration copying)
get '/migration-info' => sub {
    my $c = shift;

    # Check if migrations directory exists and list migrations
    my $app_migrations_dir = $c->app->home->child('share', 'migrations');
    my $migrations_exist = -d $app_migrations_dir;

    my @migration_files = ();
    if ($migrations_exist) {
        @migration_files = sort glob("$app_migrations_dir/*.sql");
    }

    # Get plugin migration source directory
    my $plugin_migrations_dir = "$FindBin::Bin/lib/Mojolicious/Plugin/Fondation/MigrationExample/share/migrations";
    my @plugin_migration_files = sort glob("$plugin_migrations_dir/*.sql");

    my $response = <<"END_INFO";
<!DOCTYPE html>
<html>
<head><title>Migration Copying Demonstration</title>
<style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
    .info-box { background-color: #f0f8ff; border: 1px solid #4a90e2; padding: 15px; border-radius: 5px; margin: 10px 0; }
    .success { color: green; }
    .warning { color: orange; }
    .code { font-family: monospace; background-color: #f5f5f5; padding: 2px 4px; border-radius: 3px; }
</style>
</head>
<body>
<h1>Migration Copying Demonstration</h1>

<div class="info-box">
<h2>How Migration Copying Works in Fondation</h2>
<p>When Fondation loads a plugin, it automatically copies migration files from the plugin's <code>share/migrations/</code> directory to the application's <code>share/migrations/</code> directory.</p>
<p>Existing migration files with the same name are <strong>not overwritten</strong> - this allows applications to customize migrations while still getting defaults from plugins.</p>
<p>If the application's home directory is not writable, Fondation logs a debug message but continues without error.</p>
</div>

<h2>Migration Status</h2>
<p>Application migrations directory: <code>$app_migrations_dir</code></p>
<p>Directory exists: <strong>@{[$migrations_exist ? 'YES' : 'NO']}</strong></p>

<h2>Plugin Migration Files (Source)</h2>
<p>From <code>Mojolicious::Plugin::Fondation::MigrationExample</code>:</p>
<ul>
END_INFO

    if (@plugin_migration_files) {
        foreach my $file (@plugin_migration_files) {
            my $basename = File::Basename::basename($file);
            $response .= "<li><span class=\"code\">$basename</span></li>\n";
        }
    } else {
        $response .= "<li><em>No migration files found in plugin</em></li>\n";
    }

    $response .= <<"END_INFO";
</ul>

<h2>Application Migration Files (Copied)</h2>
<ul>
END_INFO

    if (@migration_files) {
        foreach my $file (@migration_files) {
            my $basename = File::Basename::basename($file);
            $response .= "<li><span class=\"code\">$basename</span></li>\n";
        }
        $response .= "<li><em>Total: " . scalar(@migration_files) . " migration(s)</em></li>\n";
    } else {
        $response .= "<li><em>No migration files copied yet</em></li>\n";
    }

    $response .= <<"END_INFO";
</ul>

<h2>Test Routes</h2>
<ul>
<li><a href="/migration-example">Migration Example Plugin Route</a> - Direct route from MigrationExample plugin</li>
<li><a href="/migration-example-template">Migration Example Template</a> - Template provided by MigrationExample plugin</li>
<li><a href="/info">Plugin Information</a> - Shows plugin dependency tree</li>
</ul>

<h2>Next Steps</h2>
<p>Once migrations are copied to your application's <code>share/migrations/</code> directory, you can apply them using a database migration tool like <code>DBIx::Migrate::Simple</code>.</p>

</body>
</html>
END_INFO

    $c->render(text => $response);
};

# Route 7: Test subdirectory template (demonstrates application override in subdirectory)
get '/template-subdir-test' => sub {
    my $c = shift;
    $c->stash(
        message => 'Testing plugin subdirectory template (but using application override)',
        template_source => 'application (overrides plugin in subdirectory)',
        template_path => 'Blog/test/other'
    );
    $c->render(template => 'Blog/test/other');
};

# Route 6: Test subdirectory template override with custom message
get '/template-subdir-override' => sub {
    my $c = shift;
    $c->stash(
        message => 'Testing application template override in subdirectory',
        template_source => 'application (explicit override in subdirectory)',
        template_path => 'Blog/test/other'
    );
    $c->render(template => 'Blog/test/other');
};

# Route 7: Direct route from TemplateSubdirTest plugin
# This route is defined by the TemplateSubdirTest plugin itself
# It will use either plugin or application template based on availability

# Home page
get '/' => sub {
    my $c = shift;
    $c->render(text => 'Welcome to Fondation Test Application. Visit /blog, /template-info, /template-subdir-info, /migration-info or /info');
};

app->start;
