#!/usr/bin/perl -w

use strict;
use IO::Socket;
use IO::Select;
use IPC::Open2;
use Config::General;
use POSIX qw(:sys_wait_h ceil);
use Quantor::Log;
use Time::HiRes qw(sleep);
use Data::Dumper;
use Data::HexDump;

#$SIG{TERM} = $SIG{INT} = $SIG{QUIT} = $SIG{HUP} = $SIG{__DIE__} = \&interrupt;

my($oup, $odown) = (0, 1000000);

# load configuration
my %conf = ParseConfig('/etc/cmms.conf');
my $confa = $conf{players}->{player};
my $conf;
our $zonenum = shift @ARGV || 1;

if( ref($confa) eq "HASH" ) {
    if( $zonenum==1 ) {
	$conf = $confa;
    }
    else {
	print STDERR "Undefined zone specified in startup";
	die;
    }
}
elsif( $$confa[$zonenum-1] ) {
    $conf = $$confa[$zonenum-1];

    unless( $conf ) {
	print STDERR "Undefined zone specified in startup";
	die;
    }
}

my $alsadevice = $conf->{device} || "zone".$zonenum;

#open a log file
close(STDERR);
open(STDERR,'>> /usr/local/cmms/logs/player-zone-'.$zonenum.'.log');

STDERR->autoflush(1);
STDOUT->autoflush(1);

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
my $playing = 0;
my $pause = 0;

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
	    unless($sock->sysread($buff,1024)) {
		print STDERR 'Client ('.$sock->fileno.') ['.$sock->peerhost.':'.$sock->peerport."] disconnected\n";
		$select->remove($sock);
		$sock->close();
		next;
	    }
	    
	    $buff =~ s/\r+//g;
	    
	    print STDERR sprintf("\r%02d: %.80s",$playing,$buff);
	    
	    if( $buff=~ /Starting playback/ ) {
		$playing = 1;
	    }
	    elsif( $buff =~ /\d\%.*?\[J\x0a/ and $playing ) {
		$buff = "230: endofsong\r\n";
		$playing = 0;

		foreach my $hndl ($select->handles) {
		    next if $hndl == $listen;
		    next unless $hndl->fileno;
		    next if $hndl == $rdr;
		    
		    print $hndl "$buff\r\n";
		}		
	    }
	    else {
		foreach $buff (split("\n",$buff)) {
		    if($buff =~ /^(play|pause|stop|seek)/) {
			$oldcommand = $1;

			if($buff =~ /\.(flac|mp3)$/) {
			    ($pid,$type) = player($1) if $type ne $1;
			}
			
			if ($buff =~ /play (.+)/) {
			    $playing = 0;
			    $last = $1;
			}

			my $command = $buff;
			$command =~ s/play/load/;
			
			if( $oldcommand eq "stop" ) {
			    print $mpg "seek 0 2\n";
			    print $mpg "pause\n";
			}
			else {
			    print $mpg $command."\n";
			}

			# Send response back to crestron
			if( $oldcommand eq "pause" ) {
			    $pause = 1 - $pause;

			    if( $pause ) {
				$buff = "200: pause";
			    }
			    else {
				$buff = "200: unpause";
			    }
			}
			elsif( $oldcommand eq "stop" ) {
			    $buff = "230: stop";
			}
			elsif( $oldcommand eq "play" ) {
			    $buff = "230: playing\r\n230: play $last";
			}

		    } elsif($buff =~ /^\@/) {
			if($buff =~ /\@F [0-9]+ [0-9]+ ([0-9\.]+) ([0-9\.]+)/) {
			    my ($up, $down) = map{ceil($_)} ($1, $2);
			    $up    = $oup   if $up   < $oup;
			    $down  = $odown if $down > $odown;
			    next   if $up eq $oup && $down eq $odown;
			    $oup   = $up;
			    $odown = $down;
			    $buff  = "230: time $up $down";
			} elsif($buff =~ /\=\=\= PAUSE \=\=\=/) {
			    $buff = "200: pause";
			} elsif($buff =~ /\@P 2/) {
			    $buff = "200: unpause";
			} elsif($buff =~ /\@I (\/?.+)/) {
			    my $file = $last;
			    $file = $1 unless $last;
			    ($oup, $odown) = (0, 1000000);
			    $buff = "230: playing\r\n230: play $file";
			} elsif($buff =~ /\@P 0/) {
			    $buff = ($oldcommand ne 'stop'?"230: endofsong\r\n":'') . "230: stop";
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

			print STDERR ">>> $buff\r\n";
			print $hndl "$buff\r\n";
		    }
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
#	$p = open2($rdr,$mpg,'nice -n -10 /usr/local/bin/flac123 -R 2>&1') if $t eq 'flac';
#	$p = open2($rdr,$mpg,'nice -n -10 /usr/bin/mpg123 -R 2>&1') if $t eq 'mp3';
	$p = open2($rdr,$mpg,'nice -n -10 /usr/bin/mplayer -ao alsa:device='.$alsadevice.' -idle -slave -nojoystick -nomouseinput -nolirc 2>&1');
	print STDERR "Opening mplayer player ($p)\n";
	$select->add($rdr);

	return ($p,$t);
}
