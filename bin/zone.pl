#!/usr/bin/perl -w

use strict;
use IO::Socket;
use IO::Select;
use Getopt::Long;
use Config::General qw(ParseConfig);
use CMMS::Zone::Sender;
use CMMS::Zone::Status;
use CMMS::Zone::Command;
use CMMS::Database::MysqlConnectionEscape;
use Quantor::Log;
use Time::HiRes qw(sleep);

$Quantor::Log::log_level = INFO; 

# load config & configure multiplexer
qlog INFO, "Reading CMMS Configuration";
my %conf = ParseConfig('/etc/cmms.conf');

my $zone;
GetOptions('zone=s' => \$zone);

foreach(@{$conf{zones}->{zone}}) {
	next unless $_->{number};
	if($_->{number} eq $zone) {
		$zone = $_;
		last;
	}
}

my $db = $conf{mysql};
my $mc = new CMMS::Database::MysqlConnectionEscape;
$mc and $db->{host} and $mc->host( $db->{host} );
$mc and $db->{database} and $mc->database( $db->{database} );
$mc and $db->{user} and $mc->user( $db->{user} );
$mc and $db->{password} and $mc->password( $db->{password} );

unless( $mc and $mc->connect ) {
    qlog CRITICAL, "Can't connect to database '".$mc->database."' on '".$mc->host."' with user '".$mc->user."'";
    exit 0;
};

qlog INFO,"[$$] Connecting to cmms_player $zone->{host}:$zone->{port}";

my $player;

# create a tcp connection to the specified host and port
unless( $player = IO::Socket::INET->new(Proto     => "tcp",
					PeerAddr  => $zone->{host},
					PeerPort  => $zone->{port})
	) {
    qlog CRITICAL, "Can't connect to port $zone->{port} on $zone->{host}: $!";
    exit 0;
}

$player->autoflush(1);
STDOUT->autoflush(1);

qlog INFO,"[$$] Connected to irmp3d.";

my $status = new CMMS::Zone::Status(mc => $mc, handle => $player, zone => $zone, conf => \%conf);
my $sender = new CMMS::Zone::Sender(mc => $mc, handle => $player, zone => $zone, conf => \%conf);

my $select = new IO::Select($player,\*STDIN);

while(1) {
	foreach my $hndl ($select->can_read(0)) {
		if($hndl == $player) {
			my $line;
			unless(sysread($hndl,$line,1024)) {
				qlog CRITICAL, "Can't read from Player";
				exit 0;
			}

			$line =~ s/\r+//g;
			foreach my $command (split "\n", $line) {
				# status, command, data
				my ($stt, $cmd, $data);
				if($command =~ /^(\d\d\d): (\w*) (.*)$/) {
					$stt  = $1;
					$cmd  = $2;
					$data = $3;
				} elsif($command =~ /^(\d\d\d): (\w*)$/) {
					$stt  = $1;
					$cmd  = $2;
					$data = undef;
				} else {
					next;
				}

				if($CMMS::Zone::Status::commands->{lc $stt}{lc $cmd}) {
					my $method = $CMMS::Zone::Status::commands->{lc $stt}{lc $cmd};
					my %ret = eval "\$status->$method(\$data)";
					if($ret{cmd}) {
						$ret{zone} = $zone->{number};
						print STDOUT hash2cmd(%ret);
					}
				} else {
					qlog INFO, "cmms_player: ".$command."\n";
				}
			}
		} elsif($hndl == \*STDIN) {
			my($line,%cmd);
			unless(sysread($hndl,$line,1024)) {
				qlog CRITICAL, "Can't read from STDIN";
				exit 0;
			}

			$line =~ s/\r+//g;
			foreach my $command (split "\n", $line) {
				qlog INFO, "Received command: $command\n";
				%cmd = cmd2hash $command;
				next unless %cmd;  # empty hash - there won't be command either
				next unless &check_cmd(\%cmd, $sender->{zone}->{number}); # do further checking (eg. zone)
				my $cmd = $sender->process(\%cmd);
				if($cmd) {
					qlog INFO, "Sending to player '$cmd'";
					print $player "$cmd\r\n";
				}
			}
		}
	}

	sleep 0.1;
}
