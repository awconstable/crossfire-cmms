#!/usr/bin/perl -w

use strict;
use Getopt::Long;

my $mode;
GetOptions(mode => \$mode);

my $drive = '0';
$drive = 1 if $mode;

my $ripper = '/usr/bin/cmms_ripper.pl'.($mode?' -m':'');
my $mtx = `mtx status`;

my ($drive1) = ($mtx =~ /Data Transfer Element 0:(Empty|Full)/);
my ($drive2) = ($mtx =~ /Data Transfer Element 1:(Empty|Full)/);

foreach(($mtx =~ /Storage Element ([0-9]+):Full/g)) {
	next if !$mode && $_%2 == 0;
	next if $mode && $_%2 != 0;

	print STDERR "\t=== " . scalar localtime() . " mtx load $_ $drive ===\n";
	`mtx load $_ $drive`;
	`$ripper`;
	print STDERR "\t--- " . scalar localtime() . " mtx unload $_ $drive ---\n";
	`mtx unload $_ $drive`;
}
