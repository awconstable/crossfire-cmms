#!/usr/bin/perl -w

use strict;
use IO::Socket;
use DBI;
use Getopt::Long;
use Config::General;

# load config & configure multiplexer
my %conf = ParseConfig('/etc/cmms_server.conf');

my $zone;
GetOptions('zone' => \$zone);

foreach(@{$conf{zones}->{zone}}) {
	next unless $_->{number};
	$zone = $_ if $_->{number} == $zone;
}

my $parentpid = $$;
my ($kidpid, $handle, $line);

sub connect {
  
  my ($host, $port) = ($zone->{host}, $zone->{port});

  print STDERR "[$$] Connecting to irmp3d $host:$port \n";
  
  # create a tcp connection to the specified host and port
  $handle = IO::Socket::INET->new(Proto     => "tcp",
                                  PeerAddr  => $host,
                                  PeerPort  => $port)
       or die "can't connect to port $port on $host: $!";
       
  print STDERR "[$$] Connected to irmp3d.\n";

  return $handle;
}
$handle = &connect;

# split the program into two processes, identical twins
die "can't fork: $!" unless defined($kidpid = fork());

if ($kidpid) {

    $SIG{__DIE__} = sub { 
        kill("TERM" => $kidpid);        # send SIGTERM to child
        };

    STDOUT->autoflush(1); # important, otherwise output will be buffered!!!
    
    print STDERR "[$$] Status process.\n";

    my $db = &db_connect;
    &zone::status::dbh(\$db);
    &zone::status::handle($handle);
    &zone::status::zone($zone);
    &zone::status::loop;

    die("[$$] Connection closed by irmp3d...");
    
} else {
  
    sub terminate_all {
        # try to clean up
        $handle->close();
        kill("TERM" => $parentpid); # tell parent we've died :(
    }

    $SIG{__DIE__} = \&terminate_all;
    
    $handle->autoflush(1); # so output gets there right away
    STDOUT->autoflush(1); # important, otherwise output will be buffered!!!
    # child copies standard input to the socket
    
    print STDERR "[$$] Sender/Command process.\n";
   

    my $db = &db_connect;
    # configure module
    &zone::sender::dbh(\$db); #(&db_connect);
    &zone::sender::handle($handle);
    &zone::sender::zone($zone);
    &zone::sender::loop;

    die("[$$] Program ended by cmmsd/STDIN...");    
    
}

exit;
