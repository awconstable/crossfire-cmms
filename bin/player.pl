#!/usr/bin/perl -w

use strict;
use IO::Socket;
use IO::Multiplex;
use IPC::Open2;
use Config::General;
use POSIX qw(ceil);

$SIG{TERM} = \&unload;
$SIG{INT} = \&unload;
$SIG{QUIT} = \&unload;
$SIG{HUP} = \&unload;
$SIG{__DIE__} = \&unload;

my ($oup, $odown) = (0, 0);

close(STDERR);
open(STDERR,'>> /usr/local/cmms/logs/player.log');

STDERR->autoflush(1);
STDOUT->autoflush(1);

# load config
my %conf = ParseConfig('/etc/cmms.conf');
my $conf = $conf{player};

my $pid = open2(\*RDR, \*MPG, '/usr/local/bin/flac123 -R 2>&1');

my $mux  = new IO::Multiplex;

# Create a listening socket
my $sock = new IO::Socket::INET(
	Proto => 'tcp',
	LocalHost => $conf->{bind},
	LocalPort => $conf->{port},
	Listen => 1,
	Reuse => 1
) or die "Unable to start player server: ".$!;
print STDERR "Server started [",$sock->sockhost, ":", $sock->sockport, "]\n";

$mux->add(\*RDR);
$mux->listen($sock);
$mux->set_callback_object(__PACKAGE__);
$mux->loop;

sub mux_input {
	my $self = shift;
	my $mux = shift;
	shift; # not needed
	my $input = shift;

	while ($$input =~ s/^(.*?)\n//) {
    		my $data = $1;
		if($data =~ /^play|pause|stop|seek/) {
			my $command = $data;
			$data = "210: $data";
			$command =~ s/seek/jump/;
			$command =~ s/play/load/;
			print MPG $command."\n";
		} elsif($data =~ /^\@/) {
			if($data =~ /\@F [0-9]+ [0-9]+ ([0-9\.]+) ([0-9\.]+)/) {
				my ($up, $down) = map{ceil($_)} ($1, $2);
				next if $up eq $oup && $down eq $odown;
				$oup = $up;
				$odown = $down;
				$data = "230: time $up $down";
				$data .= "\r\n230: endofsong\r\n200: endofsong\r\n" if $down == 0;
			}
			if($data =~ /\@P 1/) {
				$data = "230: pause\r\n200: pause";
			}
			if($data =~ /\@P 2/) {
				$data = "230: pause\r\n\r\n200: unpause";
			}
			if($data =~ /\@I (\/.+)/) {
				my $file = $1;
				$file .= '.flac' unless $file =~ /\.flac$/;
				$data = "240: songtype $file\r\n220: canplay mod_flac123 $file\r\n230: play mod_flac123 $file\r\n230: playing\r\n200: play mod_flac123 $file";
			}
			if($data =~ /\@P 0/) {
				$data = "230: stop\r\n200: stop";
			}
		} else {
			next;
		}
		foreach my $c ($mux->handles) {
			print $c $data."\r\n";
		}
	}
}

sub unload {
	my $pid = `ps -efww | grep flac123 -R | awk {'print $2'}`;
	$pid =~ s/[\r\n\s]+/ /g;
	`kill -9 $pid`;
	exit(0);
}
