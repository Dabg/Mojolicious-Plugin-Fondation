#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use File::Basename;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";


use Mojolicious::Lite;
use Data::Dumper;

# Load configuration from myapp.conf
plugin 'Config';

# Load Fondation with plugins configured in the config file
plugin 'Fondation' => {
    # dependencies => [
    #     'Fondation::User',
    #     'Fondation::Authorization',
    #     ]
};

get '/tree' => sub {
    my $c = shift;

    my $tree = $c->app->fondation_tree;
    $c->render(text => "<pre>" . $tree . "</pre>");
};

app->start;
