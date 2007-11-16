#!/usr/bin/perl -w

use strict;
use LWP;
use Config::General qw(ParseConfig);
use URI::Escape;

my $ua = new LWP::UserAgent;

# load config
my %conf   = ParseConfig('/etc/cmms.conf');
my $serial = $conf{serial};
my $host   = $conf{controlhost};
my $pubkey = `cat /usr/local/cmms/cms_key.pub`;
my $url    = 'http://'.$host.'/scripts/control.cgi?SERIAL='.uri_escape($serial).'&PUBKEY='.uri_escape($pubkey);
my $res    = $ua->get($url);

print STDERR "Query [$url]\n";

my ($command, $port) = ($res->content =~ /command=([^;]+);.+port=([0-9]+)/);

print STDERR "Command = $command ; Port = $port\n";

if($command && $command eq 'openssh') {
	print STDERR "Opening SSH connection on port $port\n";
	`rm -f ~/.ssh/known_hosts && ssh -i /usr/local/cmms/cms_key -4Nnfgq -R $port:127.0.0.1:22 -lcms $host -o keepalive=yes 1>/dev/null 2>&1 &`;
}

if($command && $command eq 'http') {
	print STDERR "Opening HTTP proxy on port $port\n";
	`rm -f ~/.ssh/known_hosts && ssh -i /usr/local/cmms/cms_key -4Nnfgq -R $port:127.0.0.1:80 -lcms $host -o keepalive=yes 1>/dev/null 2>&1 &`;
}
