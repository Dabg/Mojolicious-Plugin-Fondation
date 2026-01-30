# CPANfile for Mojolicious::Plugin::Fondation
# This file is used by Dist::Zilla and carton to manage dependencies

requires 'perl' => '5.010001';

requires 'Mojolicious' => '7.00';

test_requires 'Test::More' => '0.88';

on 'test' => sub {
    recommends 'Mojolicious::Plugin::CSRFProtect' => '0';
};

feature 'examples' => sub {
    recommends 'Mojolicious::Plugin::CSRFProtect' => '0';
};