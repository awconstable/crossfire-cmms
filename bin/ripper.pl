#!/usr/bin/perl -w

use strict;
use CMMS::Ripper;

my $ripper = new CMMS::Ripper(conf => '/etc/cmms.conf');

# Lock CD
#`cdctl -o1`;

my $album = $ripper->metadata;

$ripper->check($album) or &error; # Must unlock draw before dying!
$ripper->rip($album);

# Unlock CD
#`cdctl -o0`;

$ripper->encode($album);
$ripper->cover($album);
$ripper->store($album);
$ripper->purge;

# Try to eject CD
`eject`;

sub error {
	#`cdctl -o0`;
	die('Album already ripped');
}
