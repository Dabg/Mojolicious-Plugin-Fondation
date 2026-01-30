#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use Mojolicious::Lite;

# Demonstration application for Mojolicious::Plugin::Fondation
# This application shows how to use Fondation with configuration files
# and the Fondation::Blog test plugin.
# 
# Configuration is loaded from myapp.conf in the same directory.
# 
# Usage:
#   perl t/myapp.pl daemon   # Start development server
#   perl t/myapp.pl get /    # Test home page
#   perl t/myapp.pl get /blog # Test blog page
#   perl t/myapp.pl get /info # Show plugin information
# 
# The configuration file (myapp.conf) sets the blog title.

# Load configuration from myapp.conf
plugin 'Config';

# Load Fondation with plugins configured in the config file
plugin 'Fondation' => {
    plugins => [
        'Fondation::Blog'
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
<li><a href="/info">Plugin Info</a></li>
</ul>

</body>
</html>
END_INFO

    $c->render(text => $response);
};

# Home page
get '/' => sub {
    my $c = shift;
    $c->render(text => 'Welcome to Fondation Test Application. Visit /blog or /info');
};

app->start;
