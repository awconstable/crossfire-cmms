package CMMS::File;

use strict;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(safe_chars);

sub safe_chars {
	$_ = shift;

	s/[\r\n]+//g;
	s/\s+/_/g;
	s/\\\\n/_/g;
	s/\\n/_/g;
	s/\W//g;
	s/_+/_/g;

	return lc($_);
}

1;
