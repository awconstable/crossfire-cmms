#!/usr/bin/perl -w

use strict;
use IO::Socket;
use Getopt::Long;
use Config::General;
use CMMS::Zone::Sender;
use CMMS::Zone::Status;
use CMMS::Database::MysqlConnection;

# load config & configure multiplexer
my %conf = ParseConfig('/etc/cmms_server.conf');

my $zone;
GetOptions('zone' => \$zone);

foreach(@{$conf{zones}->{zone}}) {
	next unless $_->{number};
	$zone = $_ if $_->{number} == $zone;
}

my $db = $conf{mysql};
my $mc = new CMMS::Database::MysqlConnection;
$mc and $db->{host} and $mc->host( $db->{host} );
$mc and $db->{database} and $mc->database( $db->{database} );
$mc and $db->{user} and $mc->user( $db->{user} );
$mc and $db->{password} and $mc->password( $db->{password} );
$mc and $mc->connect || die("Can't connect to database '".$mc->database."' on '".$mc->host."' with user '".$mc->user."'");

my $parentpid = $$;
my ($kidpid, $handle, $line);

print STDERR "[$$] Connecting to irmp3d $zone->{host}:$zone->{port} \n";

# create a tcp connection to the specified host and port
$handle = IO::Socket::INET->new(Proto     => "tcp",
                                PeerAddr  => $zone->{host},
                                PeerPort  => $zone->{port})
     or die "can't connect to port $zone->{port} on $zone->{host}: $!";
     
print STDERR "[$$] Connected to irmp3d.\n";


# split the program into two processes, identical twins
die "can't fork: $!" unless defined($kidpid = fork());

if ($kidpid) {

    $SIG{__DIE__} = sub { 
        kill("TERM" => $kidpid);        # send SIGTERM to child
        };

    STDOUT->autoflush(1); # important, otherwise output will be buffered!!!
    
    print STDERR "[$$] Status process.\n";

    my $obj = new CMMS::Zone::Status(mc => $mc, handle => $handle, zone => $zone, conf => \%conf);
    $obj->loop;

    die("[$$] Connection closed by irmp3d...");
    
} else {
    $SIG{__DIE__} = \&terminate_all;
    
    $handle->autoflush(1); # so output gets there right away
    STDOUT->autoflush(1); # important, otherwise output will be buffered!!!
    # child copies standard input to the socket

    print STDERR "[$$] Sender/Command process.\n";

    my $obj = new CMMS::Zone::Sender(mc => $mc, handle => $handle, zone => $zone, conf => \%conf);
    $obj->loop;

    die("[$$] Program ended by cmmsd/STDIN...");    
    
}

sub terminate_all {
	# try to clean up
	$handle->close;
	kill("TERM" => $parentpid); # tell parent we've died :(
}

exit;
