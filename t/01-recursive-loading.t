#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Mojo;

# Include the test plugins directory
use lib 't/lib';

# Test recursive plugin loading
use Mojolicious::Lite;
my $t = Test::Mojo->new;
plugin 'Fondation' => {
    plugins => [
        { 'Fondation::Blog' => { title => 'Test Blog' } }
    ]
};

# Verify all plugins are loaded
no warnings 'once';
my $tree = $Mojolicious::Plugin::Fondation::TREE;

# Verify tree structure
ok(exists $tree->{Fondation}, 'Fondation in TREE');
ok(exists $tree->{'Fondation::Blog'}, 'Blog in TREE');
ok(exists $tree->{'Fondation::Security'}, 'Security in TREE');
ok(exists $tree->{'Fondation::Session'}, 'Session in TREE');

# Verify parent-child relationships
is_deeply(
    $tree->{Fondation},
    ['Fondation::Blog'],
    'Fondation has Blog as child'
);

is_deeply(
    $tree->{'Fondation::Blog'},
    ['Fondation::Security', 'Fondation::Session'],
    'Blog has Security and Session as children'
);

# Verify Security has CSRFProtect as child
if (exists $tree->{'Fondation::Security'}) {
    like(
        join(', ', @{$tree->{'Fondation::Security'}}),
        qr/CSRFProtect/,
        'Security has CSRFProtect as child'
    );
}

# Verify graph function
my $graph = Mojolicious::Plugin::Fondation->graph;
like($graph, qr/Fondation/, 'Graph contains Fondation');
like($graph, qr/Fondation::Blog/, 'Graph contains Blog');
like($graph, qr/Fondation::Security/, 'Graph contains Security');
like($graph, qr/Fondation::Session/, 'Graph contains Session');
like($graph, qr/CSRFProtect/, 'Graph contains CSRFProtect');

# Verify /blog route is accessible
$t->get_ok('/blog')
  ->status_is(200)
  ->content_like(qr/Welcome to Test Blog/, 'Blog route works with configured title');

done_testing();