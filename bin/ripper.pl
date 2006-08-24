#!/usr/bin/perl -w

use strict;
use CMMS::Ripper;
use Getopt::Long;

my $mode;
GetOptions(mode => \$mode);

my $ripper = new CMMS::Ripper(conf => ($mode?'/etc/cmms2.conf':'/etc/cmms.conf'));

#Commented out for now as evals and externally spawned processes are 
#currently calling the grim reaper. Need to find a check to make sure
#only main process dies call the reaper.
#$SIG{__DIE__} = \&grim_reaper;

# Lock CD
#`cdctl -o1`;

my $album = $ripper->metadata;

$ripper->check($album) or &error; # Must unlock draw before dying!
$ripper->rip($album) or die("Album: $album->{ALBUM} timed out");

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
	# Try to eject CD
	`eject`;
	die('Album already ripped');
}

sub grim_reaper {
    my $message = shift;

    `eject`;

    return CORE::die($message);
}
