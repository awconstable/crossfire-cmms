use strict;
use Test::More tests => int(`find ./lib/ -name "*.pm" -print | wc -l`);

BEGIN {
  my $find = `find ./lib/ -name "*.pm" -print`;
  $find =~ s/\.pm$//mg;
  $find =~ s/.\/lib\///g;
  $find =~ s/\//::/g;
  my @modules = split("\n",$find);

  for my $module ( @modules ) {
    use_ok($module);
  }
}
