#!/usr/bin/perl -w

use strict;
use LWP;
use Config::General;

my $ua = new LWP::UserAgent;

# load config
my %conf   = ParseConfig('/etc/cmms.conf');
my $serial = $conf{serial};
my $host   = $conf{controlhost};
my $res    = $ua->get('http://'.$host.'/scripts/control.cgi?SERIAL='.$serial);

print STDERR "Query: http://$host/scripts/control.cgi?SERIAL=$serial\n";

my ($command, $port) = ($res->content =~ /command=([^;]+);.+port=([0-9]+)/);

print STDERR "Command = $command ; Port = $port\n";

if($command && $command eq 'openssh') {
	print STDERR "Opening SSH connection on port $port\n";
	`rm -f ~/.ssh/known_hosts && ssh -4Nnfgq -R $port:127.0.0.1:22 -lroot $host -o keepalive=yes 1>/dev/null 2>&1 &`;
}
