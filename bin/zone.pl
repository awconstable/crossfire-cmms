#!/usr/bin/perl -w

use strict;
use IO::Socket;
use Getopt::Long;
use Config::General;
use CMMS::Zone::Sender;
use CMMS::Zone::Status;
use CMMS::Database::MysqlConnectionEscape;
use Quantor::Log;

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
    die;
};

my $parentpid = $$;
my ($kidpid, $handle, $line);

qlog INFO,"[$$] Connecting to cmms_player $zone->{host}:$zone->{port}";

# create a tcp connection to the specified host and port
unless( $handle = IO::Socket::INET->new(Proto     => "tcp",
					PeerAddr  => $zone->{host},
					PeerPort  => $zone->{port})
	) {
    qlog "Can't connect to port $zone->{port} on $zone->{host}: $!";
    die;
}
     
qlog INFO,"[$$] Connected to irmp3d.";

# split the program into two processes, identical twins
unless ( defined($kidpid = fork()) ) {
    qlog CRITICAL, "Can't fork: $!";
    die;
}



if ($kidpid) {

    $SIG{__DIE__} = sub { 
        kill("TERM" => $kidpid);        # send SIGTERM to child
        };

    STDOUT->autoflush(1); # important, otherwise output will be buffered!!!
    
    qlog INFO, "[$$] Status process.";

    my $obj = new CMMS::Zone::Status(mc => $mc, handle => $handle, zone => $zone, conf => \%conf);
    $obj->loop;

    qlog INFO, "[$$] Connection closed by cmms_player...";
    
} else {
    $SIG{__DIE__} = \&terminate_all;
    
    $handle->autoflush(1); # so output gets there right away
    STDOUT->autoflush(1); # important, otherwise output will be buffered!!!
    # child copies standard input to the socket

    qlog INFO,"[$$] Sender/Command process.";

    my $obj = new CMMS::Zone::Sender(mc => $mc, handle => $handle, zone => $zone, conf => \%conf);
    $obj->loop;

    qlog INFO, "[$$] Program ended by cmmsd/STDIN...";    
    
}

sub terminate_all {
	# try to clean up
	$handle->close;
	kill("TERM" => $parentpid); # tell parent we've died :(
}

exit;
