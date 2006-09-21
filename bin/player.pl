#!/usr/bin/perl -w

use strict;
use IO::Socket;
use IO::Select;
use IPC::Open2;
use Config::General;
use POSIX qw(ceil);
use Time::HiRes qw(sleep);

$SIG{TERM} = $SIG{INT} = $SIG{QUIT} = $SIG{HUP} = $SIG{__DIE__} = \&unload;

my($oup, $odown) = (0, 0);

close(STDERR);
open(STDERR,'>> /usr/local/cmms/logs/player.log');

STDERR->autoflush(1);
STDOUT->autoflush(1);

# load config
my %conf = ParseConfig('/etc/cmms.conf');
my $conf = $conf{player};

# Create a listening socket
my $listen = new IO::Socket::INET(
	Proto => 'tcp',
	LocalHost => $conf->{bind},
	LocalPort => $conf->{port},
	Listen => 1,
	ReuseAddr => 1,
	MultiHomed => 1
) or die "Unable to start player server: ".$!;
print STDERR "Server started [",$listen->sockhost, ":", $listen->sockport, "]\n";

my $pid = open2(\*RDR,\*MPG,'/usr/local/bin/flac123 -R 2>&1');

my $select = new IO::Select($listen,\*RDR);

while(1) {
	foreach my $sock ($select->can_read(0)) {
		if($sock == $listen) {
			my $new = $listen->accept;
			$new->autoflush(1);
			$select->add($new);
			print STDERR 'Client '.$sock->fileno." connected\n";
			next;
		} else {
			my $buff = '';
			unless($sock->sysread($buff,5*1024)) {
				print STDERR 'Client '.$sock->fileno." disconnected\n";
				$select->remove($sock);
				$sock->close();
			}
			if($buff =~ /^play|pause|stop|seek/) {
				my $command = $buff;
				$buff = "210: $buff";
				$command =~ s/seek/jump/;
				$command =~ s/play/load/;
				print MPG $command."\n";
			} elsif($buff =~ /^\@/) {
				if($buff =~ /\@F [0-9]+ [0-9]+ ([0-9\.]+) ([0-9\.]+)/) {
					my ($up, $down) = map{ceil($_)} ($1, $2);
					next if $up eq $oup && $down eq $odown;
					$oup = $up;
					$odown = $down;
					$buff = "230: time $up $down";
					$buff .= "\r\n230: endofsong\r\n200: endofsong" if $down == 0;
				} elsif($buff =~ /\@P 1/) {
					$buff = "230: pause\r\n200: pause";
				} elsif($buff =~ /\@P 2/) {
					$buff = "230: pause\r\n200: unpause";
				} elsif($buff =~ /\@I (\/.+)/) {
					my $file = $1;
					$file .= '.flac' unless $file =~ /\.flac$/;
					$buff = "240: songtype $file\r\n220: canplay mod_flac123 $file\r\n230: play mod_flac123 $file\r\n230: playing\r\n200: play mod_flac123 $file";
				} elsif($buff =~ /\@P 0/) {
					$buff = "230: stop\r\n200: stop";
				} else {
					next;
				}
			} else {
				next;
			}

			foreach my $hndl ($select->handles) {
				next unless $hndl->fileno;
				next if $hndl == $listen;
				next if $hndl == \*RDR;

				print $hndl "$buff\r\n";
			}
		}
	}

	sleep(.3);
}

sub unload {
	my $pid = join(' ',split("\n",`ps -efww | grep flac123 | awk {'print $2'}`));
	`kill -9 $pid` if $pid;
	exit(0);
}
