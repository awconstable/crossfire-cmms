#!/usr/bin/perl -w

use strict;
use IO::Select;
use Config::General qw(ParseConfig);
use Time::HiRes qw(sleep);
use Quantor::Log;
use IPC::Open2;
use CMMS::Zone::Command;
use Data::Dumper;

close(STDERR);
open(STDERR,'>> /usr/local/cmms/logs/cmmsd.log');
$Quantor::Log::log_level = INFO;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my %conf = ParseConfig('/etc/cmms.conf');
$conf{zones}->{zone} = [$conf{zones}->{zone}] unless ref($conf{zones}->{zone}) eq 'ARRAY';

my($crestin,$crestout);

my $crestpid = open2($crestin,$crestout,'/usr/bin/cmms_crestron.pl 2>>/usr/local/cmms/logs/crestron.log');
qlog INFO,"Starting crestron PID[$crestpid]";

$crestin->autoflush(1);

my $select = new IO::Select($crestin);

my $zones = {};

foreach my $zone (@{$conf{zones}->{zone}}) {
	next unless my $number = $zone->{number};
	my($zonein,$zoneout);
	my $zonepid = open2($zonein,$zoneout,"/usr/bin/cmms_zone.pl --zone $number 2>>/usr/local/cmms/logs/zone$number.log");
	qlog INFO,"Starting zone $number PID[$zonepid]";
	$select->add($zonein);
	$zones->{$number} = {
		in => $zonein,
		out => $zoneout,
		pid => $zonepid
	}
}

qlog INFO, "CMMSD ready";

while(1) {
	foreach my $hndl ($select->can_read(0)) {
		if($hndl == $crestin) {
			my $line = '';
			unless(sysread($hndl, $line, 1024)) {
				$select->remove($hndl);
				$hndl->close;
				waitpid($crestpid,0) or warn "Unable to close crestron PID[$crestpid]";
				$crestpid = open2($crestin,$crestout,'/usr/bin/cmms_crestron.pl 2>>/usr/local/cmms/logs/crestron.log');
				qlog INFO,"Re-starting crestron PID[$crestpid]";
				$select->add($crestin);

				next;
			}

			$line =~ s/\r+//g;

			foreach my $command (split "\n", $line) {
				my %cmd = cmd2hash($command);
				if(my $number = $cmd{zone}) {
					my $zone = $zones->{$number};
					my $hndl = $zone->{in};
					unless($hndl->opened) {
						my($zonein,$zoneout);
						my $zonepid = open2($zonein,$zoneout,"/usr/bin/cmms_zone.pl --zone $number 2>>/usr/local/cmms/logs/zone$number.log");
						qlog INFO,"Re-starting zone $number PID[$zonepid]";
						$select->add($zonein);
						$zone->{in} = $zonein;
						$zone->{out} = $zoneout;
						$zone->{pid} = $zonepid;
					}

					my $hndlout = $zone->{out};
					qlog DEBUG,"CRESTRON zone $number PID[$zone->{pid}] {$command}";
					print $hndlout "$command\r\n";
				}
			}

			next;
		}

		my($number,$zone);
		while(my($nm,$zn) = each %{$zones}) {
			if($zn->{in} == $hndl) {
				$number = $nm;
				$zone = $zn;
				last;
			}
		}

		next unless $number;

		my $line = '';
		unless(sysread($hndl, $line, 1024)) {
			$select->remove($hndl);
			$hndl->close;
			waitpid($zone->{pid},0) or warn "Unable to close zone $number PID[$zone->{pid}]";
			my($zonein,$zoneout);
			my $zonepid = open2($zonein,$zoneout,"/usr/bin/cmms_zone.pl --zone $number 2>>/usr/local/cmms/logs/zone$number.log");
			qlog INFO,"Re-starting zone $number PID[$zonepid]";
			$select->add($zonein);
			$zone->{in} = $zonein;
			$zone->{out} = $zoneout;
			$zone->{pid} = $zonepid;

			next;
		}

		$line =~ s/\r+//g;

		foreach my $command (split "\n", $line) {
			qlog DEBUG,"ZONE zone $number PID[$zone->{pid}] {$command}";
			print $crestout "$command\r\n";
		}
	}

	sleep 0.1;
}
