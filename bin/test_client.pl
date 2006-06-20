#!/usr/bin/perl -w

use strict;
use Socket;

$| = 1;

my ($remote, $port, $iaddr, $paddr, $proto, $line);

$remote  = 'localhost';
$port    = 6661;
if ($port =~ /\D/) { $port = getservbyname($port, 'tcp') }
$iaddr   = inet_aton($remote) || die "no host: $remote";
$paddr   = sockaddr_in($port, $iaddr);
$proto   = getprotobyname('tcp');
socket(SOCK, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";
connect(SOCK, $paddr) || die "connect: $!";
while (defined($line = <SOCK>)) {
	chomp $line;
	$line =~ s/[\r\n]+//g;
	my %hash = map{my($fu,$ba) = /^([^:]+):(.+)$/; $fu => $ba} split('\|\|',$line);
	if($hash{feedback} && !$hash{state}) {
		print "\t$hash{feedback}\r";
	} elsif($hash{track} && $hash{artist}) {
		print "

	===========================

	Current track: $hash{track}
	Artist: $hash{artist}
	Album: $hash{album}
	Playlist: $hash{playlist}
	Genre: $hash{genre}

";
	}
}

close (SOCK) || die "close: $!";
