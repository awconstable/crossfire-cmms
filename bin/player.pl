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

# open a log file
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
my($pid,$type) = player();
my($oldcommand,$last) = ('','');
my $pstate = 0;
my $new_track = 1;

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
	    
	    foreach $buff (split("\n",$buff)) {
		
		if($buff =~ /^(play|pause|stop|seek)/) {
		    $oldcommand = $1;
		    
		    $last = $1 if $buff =~ /play (.+)/;
		    my $command = $buff;
		    
		    # Convert commands
		    $command =~ s/play/load/;
		    print STDERR ">>>".$command."\n";
		    print $mpg $command."\n";
		    next;
		} elsif($buff =~ /PAUSE/) {
		    print STDERR "STATE=pause";
		    $buff = "200: pause";
		    $pstate = 1;
		} elsif($buff =~ /^A:/) {
		    if($buff =~ /^A\:\s+(.*?)\s\((.*?)\)\sof\s(.*?)\s\((.*?)\)/) {
			my ($up,$ptime,$total,$time) = ($1,$2,$3,$4);
			print STDERR "Time $up/$total ($time)\n";

			if( $new_track and $total - $up > 0.2 ) {
			    $new_track = 0;
			}
			
			if( $total - $up < 0.2 ) {
			    # The new track flag is a hack to allow any time data that is received
			    # after the track is deemed to have finished doesn't fool the player into
			    # thinking the new track has ended.
			    $new_track = 1;
			    $buff = "230: endofsong\r\n";
			}
			else {
			    my $down = $total - $up;
			    $up    = $oup   if $up   < $oup;
			    $down  = $odown if $down > $odown;
			    next   if $up eq $oup && $down eq $odown;
			    $oup   = $up;
			    $odown = $down;
			    
			    if( $pstate ) {
				$pstate = 0;
				$buff = "200: unpause\r\n230: time $up $down";
				print STDERR "STATE=unpause";
			    }
			    else {
				$buff  = "230: time $up $down";
			    }
			}
		    } elsif($buff =~ /\@I (\/?.+)/) {
			my $file = $last;
			$file = $1 unless $last;
			($oup, $odown) = (0, 1000000);
			$buff = "230: playing\r\n230: play $file";
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

	my $p = open2($rdr,$mpg,'nice -n -10 /usr/bin/mplayer -ao alsa:device='.$alsadevice.' -idle -slave 2>&1');
	print STDERR "Opening mplayer player ($p)\n";
	$select->add($rdr);

	return ($p,$t);
}
