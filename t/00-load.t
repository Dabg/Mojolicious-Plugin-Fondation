#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 4;
use Test::Mojo;

# Include the test plugins directory
use lib 't/lib';

# Test 1: Basic Fondation plugin loading
use Mojolicious::Lite;
my $t = Test::Mojo->new;
plugin 'Fondation' => {
    plugins => []
};

# Verify the TREE is initialized
no warnings 'once';
ok($Mojolicious::Plugin::Fondation::TREE, 'TREE is initialized');
ok(exists $Mojolicious::Plugin::Fondation::TREE->{Fondation}, 'Fondation plugin loaded and registered in TREE');

# Verify graph function
my $graph = Mojolicious::Plugin::Fondation->graph;
like($graph, qr/Fondation/, 'Graph contains Fondation');
like($graph, qr/<pre>/, 'Graph is wrapped in pre tags');