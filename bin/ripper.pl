#!/usr/bin/perl -w

use strict;
use CMMS::Ripper;

my $ripper = new CMMS::Ripper(conf => '/etc/cmms_ripper.conf');

# Lock CD
#`cdctl -o1`;

my $tracks = $ripper->metadata;
$ripper->check($tracks) or &error; # Must unlock draw before dying!
$ripper->rip($tracks);

# Unlock CD
#`cdctl -o0`;

$ripper->encode($tracks);
$ripper->cover($tracks);
$ripper->store($tracks);
$ripper->purge;

# Try to eject CD
`eject`;

sub error {
	#`cdctl -o0`;
	die('Album already ripped');
}
