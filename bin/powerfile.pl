#!/usr/bin/perl -w

use strict;

# Link SCSI devices and sym-link mtx keyword
print STDERR `cd /dev && MAKEDEV sg && ln -s sg2 changer`;

my $mtx = `mtx status`;

my ($drive1) = ($mtx =~ /Data Transfer Element 0:(Empty|Full)/);
my ($drive2) = ($mtx =~ /Data Transfer Element 1:(Empty|Full)/);

die("Can't fork: $!") unless defined(my $kidpid = fork());

sleep(30) if $kidpid;

my $ripper = '/usr/bin/cmms_ripper.pl'.($kidpid?' -m':'');
my $drive = ($kidpid?1:0);

foreach(($mtx =~ /Storage Element ([0-9]+):Full/g)) {
	next if !$kidpid && $_%2 == 0;
	next if $kidpid && $_%2 != 0;

	print STDERR "\t=== " . scalar localtime() . ' ' . ($kidpid?'even':'odd') . " mtx load $_ $drive ===\n";
	print STDERR `mtx load $_ $drive`."\n";
	print STDERR "\t[" . ($kidpid?'even':'odd') . " $ripper]\n";
	`$ripper`;
	print STDERR "\t--- " . scalar localtime() . ' ' . ($kidpid?'even':'odd') . " mtx unload $_ $drive ---\n";
	print STDERR `mtx unload $_ $drive`."\n";
}
