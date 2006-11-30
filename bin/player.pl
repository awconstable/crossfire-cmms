#!/usr/bin/perl -w

use strict;
use IO::Socket;
use IO::Select;
use IPC::Open2;
use Config::General;
use POSIX qw(:sys_wait_h ceil);
use Time::HiRes qw(sleep);

$SIG{TERM} = $SIG{INT} = $SIG{QUIT} = $SIG{HUP} = $SIG{__DIE__} = \&interrupt;

my($oup, $odown) = (0, 1000000);

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

$listen->autoflush(1);

my $select = new IO::Select($listen);

my($rdr,$mpg);
my($pid,$type) = player('flac');
my($oldcommand,$last) = ('','');

while(1) {
	foreach my $sock ($select->can_read(0)) {
		if($sock == $listen) {
			my $new = $listen->accept;
			$new->autoflush(1);
			$select->add($new);
			print STDERR 'Client ('.$new->fileno.') ['.$new->peerhost.':'.$new->peerport."] connected\n";
			next;
		} else {
			next unless $sock->fileno;

			my $buff = '';
			unless($sock->sysread($buff,5*1024)) {
				print STDERR 'Client ('.$sock->fileno.') ['.$sock->peerhost.':'.$sock->peerport."] disconnected\n";
				$select->remove($sock);
				$sock->close();
				next;
			}

			$buff =~ s/\r+//g;
			$buff =~ s/\n+$//g;

			foreach $buff (split("\n",$buff)) {
				if($buff =~ /^(play|pause|stop|seek)/) {
					$oldcommand = $1;
					if($buff =~ /\.(flac|mp3)$/) {
						($pid,$type) = player($1) if $type ne $1;
					}

					$last = $1 if $buff =~ /play (.+)/;
					my $command = $buff;
					$buff = "210: $buff";
					$command =~ s/seek/jump/;
					$command =~ s/play/load/;
					print $mpg $command."\n";
				} elsif($buff =~ /^\@/) {
					if($buff =~ /\@F [0-9]+ [0-9]+ ([0-9\.]+) ([0-9\.]+)/) {
						my ($up, $down) = map{ceil($_)} ($1, $2);
						$up    = $oup   if $up   < $oup;
						$down  = $odown if $down > $odown;
						next   if $up eq $oup && $down eq $odown;
						$oup   = $up;
						$odown = $down;
						$buff  = "230: time $up $down";
						$buff .= "\r\n230: endofsong\r\n200: endofsong" if $down == 0;
					} elsif($buff =~ /\@P 1/) {
						$buff = "230: pause\r\n200: pause";
					} elsif($buff =~ /\@P 2/) {
						$buff = "230: pause\r\n200: unpause";
					} elsif($buff =~ /\@I (\/?.+)/) {
						my $file = $last;
						$file = $1 unless $last;
						$file .= ".$type" unless $file =~ /\.$type$/;
						($oup, $odown) = (0, 1000000);
						$buff = "240: songtype $file\r\n220: canplay mod_${type}123 $file\r\n230: play mod_${type}123 $file\r\n230: playing\r\n200: play mod_${type}123 $file";
					} elsif($buff =~ /\@P 0/) {
						$buff = ($oldcommand ne 'stop'?"230: endofsong\r\n200: endofsong\r\n":'') . "230: stop\r\n200: stop";
					} else {
						next;
					}
				} else {
					next;
				}
	
				foreach my $hndl ($select->handles) {
					next if $hndl == $listen;
					next unless $hndl->fileno;
					next if $hndl == $rdr;
	
					print $hndl "$buff\r\n";
				}
			}
		}
	}

	sleep(.1);
}

sub interrupt {
	unload();
	exit 0;
}

sub unload {
	if($pid) {
		print $mpg "quit\n";
		$select->remove($rdr);
		print STDERR "Closing $type player ($pid)\n";
		$rdr->close;
		$mpg->close;
		kill 'HUP' => $pid;
		waitpid $pid, 0;
	}
}

sub player {
	my $t = shift;

	unload();

	my $p;
	$p = open2($rdr,$mpg,'nice -n -10 /usr/local/bin/flac123 -R 2>&1') if $t eq 'flac';
	$p = open2($rdr,$mpg,'nice -n -10 /usr/bin/mpg123 -R 2>&1') if $t eq 'mp3';
	print STDERR "Opening $t player ($p)\n";
	$select->add($rdr);

	return ($p,$t);
}
