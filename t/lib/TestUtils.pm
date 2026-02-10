package TestUtils;
use Mojo::Base -strict;
use Mojo::File qw(curfile);
use Exporter 'import';

our @EXPORT_OK = qw(test_share_for);


sub test_share_for {
  my $class = shift;


  my $sub_path = $class;
  $sub_path =~ s/Mojolicious::Plugin:://i;
  $sub_path = lc($sub_path);
  $sub_path =~ s/::/\//g;

  return curfile->dirname->sibling('share')->child($sub_path);
}

1;
