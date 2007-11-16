#!/usr/bin/perl -w

use strict;
use Quantor::Log;
use Config::General qw(ParseConfig);
use Data::Dumper;

# load configuration
my %conf = ParseConfig('/etc/cmms.conf');
my $confa = $conf{players}->{player};

my $player_binary = "/usr/bin/cmms_player.pl";

my $conf;

# Read players configuration
if( ref($confa) eq "HASH" ) {
    $conf = [ $confa ];
}
else {
    $conf = $confa;
}

my $num_zones = $#{$conf} + 1;

qlog INFO, "Found $num_zones zones to start.";

my $zone = 1;
foreach my $p ( @{$conf} ) {
    my $device = $p->{device};
    my $port = $p->{port};
    qlog INFO, "Starting zone $zone (device $device, port $port)";

    system("$player_binary $zone 1>/dev/null 2>&1 &");

    $zone++;
}
