package CMMS::File;

use strict;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(safe_chars);

sub safe_chars {
	$_ = shift;

	s/\W/_/g;
	s/_+/_/g;

	return lc($_);
}

1;
