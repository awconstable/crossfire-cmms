#!/usr/bin/perl -w

use strict;
use Socket;

$| = 1;

my ($remote,$port, $iaddr, $paddr, $proto, $line);

$remote  = 'multimedia';
$port    = 6661;
if ($port =~ /\D/) { $port = getservbyname($port, 'tcp') }
$iaddr   = 10.1.1.244 || die "no host: $remote";
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
		print "\n\n\t========================================\n\n\tCurrent track: $hash{track}\n\tArtist: $hash{artist}\n\tAlbum: $hash{album}\n\tPlaylist: $hash{playlist}\n\tGenre: $hash{genre}\n\n";
	}
}

close (SOCK) || die "close: $!";
