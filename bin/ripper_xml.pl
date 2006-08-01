#!/usr/bin/perl -w

use strict;
use CMMS::Ripper;
use Getopt::Long;

my $mode;
GetOptions(mode => \$mode);

my $ripper = new CMMS::Ripper(conf => ($mode?'/etc/cmms2.conf':'/etc/cmms.conf'));

# Lock CD
#`cdctl -o1`;

my $album = $ripper->metadata;

$ripper->check($album) or &error; # Must unlock draw before dying!
$ripper->rip($album) or die("Album: $album->{ALBUM} timed out");

# Unlock CD
#`cdctl -o0`;

$ripper->encode($album);
$ripper->cover($album);
$ripper->store_xml($album);
$ripper->purge;

# Try to eject CD
`eject`;

sub error {
	#`cdctl -o0`;
	die('Album already ripped');
}
