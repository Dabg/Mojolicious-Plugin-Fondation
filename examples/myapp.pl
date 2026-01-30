use FindBin;
use lib "$FindBin::Bin/../t/lib";
use Mojolicious::Lite;

plugin 'Fondation' => {
    plugins => [
        { 'Fondation::Blog' => { title => 'My Blog'} },
    ]
};

get '/plugins' => sub {
    no warnings 'once';
    my $c = shift;
    my $graph = Mojolicious::Plugin::Fondation->graph();

    # Extract all unique plugins from the TREE
    my $tree = $Mojolicious::Plugin::Fondation::TREE;
    my %all_plugins;
    foreach my $parent (keys %$tree) {
        $all_plugins{$parent} = 1;
        foreach my $child (@{$tree->{$parent}}) {
            $all_plugins{$child} = 1;
        }
    }
    my @plugin_names = sort keys %all_plugins;
    my $plugins_list = "Plugins loaded (via TREE): " . join(", ", @plugin_names);

    $c->render(text => $graph . "\n\n" . $plugins_list);
};

app->start;
