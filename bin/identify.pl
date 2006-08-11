#!/usr/bin/perl -w

use strict;
use CMMS::Ripper;
use Data::Dumper;

my $discid = shift @ARGV;

my $ripper = new CMMS::Ripper(conf => '/etc/cmms.conf');

# Lock CD
#`cdctl -o1`;

my $album = $ripper->metadata($discid);

print STDERR Dumper($album);
