#!/usr/bin/perl -w

use strict;
use IO::Socket;
use IO::Select;
use Config::General;

# load config & configure multiplexer
my %conf = ParseConfig('/etc/cmms.conf');
my $conf = $conf{crestron};

# flush flush output... don't keep necessary information to yourself!
STDOUT->autoflush(1);

print STDERR "Starting crestron server [",$conf->{bind}, ":", $conf->{port}, "]\n";
# create a socket to listen to a port
my $listen = IO::Socket::INET->new(Proto => 'tcp',
                                   LocalHost => $conf->{bind},
				   LocalPort => $conf->{port},
				   Listen => 1,
				   ReuseAddr => 1,
				   MultiHomed => 1
) or die "Unable to start crestron server: ".$!;
print STDERR "Server started [",$listen->sockhost, ":", $listen->sockport, "]\n";


# to start with, $select contains only the socket we're listening on
my $select = IO::Select->new($listen);

$select->add(\*STDIN);
my @ready;

# wait until there's something to do 
while(@ready = $select->can_read) {

    my $socket;

    # handle each socket that's ready
    for $socket (@ready) {

	# if the listening socket is ready, accept a new connection
	if($socket == $listen) {
	    my $new = $listen->accept;
	    $select->add($new);
            print STDERR "Client(",$new->fileno,") [",$new->peerhost,":",$new->peerport, "] connected.\n";
        } elsif($socket == \*STDIN) {
	    my $line="";
            my $read = sysread($socket, $line, 250);
	    &broadcast($select, $line, $socket);
	} else {
	    # read a line of text.
	    # close the connection if recv() fails.
	    my $line='';
	    $socket->recv($line,250);
	    if($line eq '') {
		print STDERR "Client(",$socket->fileno,") disconnected.\n";
		$select->remove($socket);
		$socket->close;
		next;
	    };

	    # there is no point to broadcast other's request, so we will
	    # print it only to STDOUT.
	    print STDOUT $line;
	}
    }
}

sub broadcast {
    my ($select, $line, $senderhandle) = @_;
    my $socket;
    # broadcast to everyone.  Close connections where send() fails.
    for $socket ($select->handles) {
        next if($socket==$listen);
        next if($socket==$senderhandle); # no echo
        if($socket==\*STDIN) { 
          print STDOUT $line;
          next;
        } else {
          $line =~ s/\n/\r\n/;
          $socket->send($line) or do {
              print STDERR "Client(",$socket->fileno,") disconnected.\n";
              $select->remove($socket);
              $socket->close;
          };
        }
    }
}

1;
