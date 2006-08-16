#!/usr/bin/perl -w

use strict;
use IO::Select;
use IO::Handle;
use IPC::Open2;
use Time::localtime;
use POSIX qw(strftime);
use Config::General;
use CMMS::Zone::Command;
use Quantor::Log;

close(STDERR);
open(STDERR,'>> /usr/local/cmms/logs/cmmsd.log');

STDOUT->autoflush(1);
STDERR->autoflush(1);

$Quantor::Log::log_level = INFO; 

# load config & configure multiplexer
qlog INFO, "L oading and parsing the CMMS configuration file";
my %conf = ParseConfig('/etc/cmms.conf');

# we'll use variable instead constant, so we can change to debug
# in the running program. 
my $DEBUG = $conf{multiplexer}->{debug}; # for now, load default from config 

my $zones  = $conf{zones}->{zone}; # copy zones ref

my $servers =  $conf{multiplexer}->{process}; # copy servers only

my $select = IO::Select->new();

my @ready; # handlers that are ready for reading
my $handle; # current handle

my @buffer; # array of buffers, 
my $buf;    # tmp variable

use constant CLIENT => 1;
use constant SERVER => 2;

my @processlist;

foreach my $item (@$servers) {
  next unless $item->{command};
  qlog INFO,"Configuring server $item->{command}.";
  # prepare command like "./server.pl 2>>server.log",
  my $command = "$item->{command} 2>>$item->{log}";

  push @processlist, { 
        type => SERVER,
        hIN  => IO::Handle->new, # prepare *Read  handle
        hOUT => IO::Handle->new, # prepare *Write handle
        pid  => undef,
        cmd  => $command
        };
}

foreach my $zone_config (@$zones) {
  my $zone = $zone_config->{number};
  next unless $zone;
  qlog INFO,"Configuring zone $zone.";
  my $log;
  if (defined $zone_config->{log}) {
      $log = $zone_config->{log} 
  } else {
      $log = "/usr/local/cmms/logs/zone$zone.log";
  }
  # prepare command like "/usr/bin/cmms_zone.pl --zone 1 2>>zone1.log",,
  my $command = "/usr/bin/cmms_zone.pl --zone $zone 2>>$log";

  push @processlist, { 
        type => CLIENT,
        hIN  => IO::Handle->new,
        hOUT => IO::Handle->new,
        pid  => undef,
        cmd  => $command,
        zone => $zone,
        };
}

# open clients/servers - "prefork" processes
qlog INFO,"Preforking processes.";
foreach (@processlist) {
    next unless $_->{cmd};
    qlog INFO,"Starting $_->{cmd}";
    $_->{pid} = open2($_->{hIN}, $_->{hOUT}, $_->{cmd}); # open process
    $select->add($_->{hIN}); # monitor program's output that is our input
}

qlog INFO,"CMMSd ready.";
while (@ready = $select->can_read) {
    for $handle (@ready) { 
    my $read = sysread($handle, $buf, 1);
    my $id = $handle->fileno;
    next if ($buf eq "\r"); # normalize to unix format
    if (!$read) {
        # someone hangup, remove him
        $select->remove($handle); # remove from list of handles from which we can read
        reap($handle, \@processlist); # reap process identified by read handle        
    }
    if ($buf eq "\n") {
	next unless defined $buffer[$id];
	my $data = $buffer[$id];
        undef $buffer[$id];
        
        # find process that owns our read handle
        my $process;
        foreach (@processlist) {
          if ($_->{hIN} == $handle) { 
            $process = $_; 
            last; 
          } 
        }
        my $mid = sprintf("%2s", $id); # just formated ID for $DEBUG messages

        if ($process->{type} == SERVER) {
            # data from an server, send data to particular client process
            qlog DEBUG,"[SERVER".$mid."]<<<".$data."<<<";

            my %cmd = cmd2hash($data);
            
            if (defined $cmd{zone}) { # data are for an zone 
                # send them to relevant client process
                foreach (@processlist) {                    # find relevant process
                    next unless ($_->{type} == CLIENT);     # must be client
                    next unless ($_->{zone} == $cmd{zone}); # must have right zone ID
                    my $handleOUT = $_->{hOUT}; # just copy ref, $_->{} as handle doesn't work
                    if ($handleOUT->opened) { 
                        # handle openned we can send data
                        qlog DEBUG,"Sent [CLIENT $_->{pid}] >>>$data>>>";
                        print $handleOUT $data, "\n";
                    } else {
                        # handle closed, so we must reopen handle first and then send data
                        qlog INFO,"Re-starting zone ".$_->{zone};
                        $_->{pid} = open2($_->{hIN}, $_->{hOUT}, $_->{cmd});
                        $select->add($_->{hIN});
                        print $handleOUT $data, "\n"; # send data
                    }                
                }
            } elsif (defined $cmd{cmmsd}) {
                if ($cmd{cmmsd} eq "status") {
                    # what will we do with status? will we broadcast it or send it to
                    # the process that just asked about this data??
                    &cmmsd_status(\@processlist);
                } elsif ($cmd{cmmsd} eq "set") {
                    $DEBUG = $cmd{debug} if (defined $cmd{debug});
                }
            }
        } elsif ($process->{type} == CLIENT) {
            # data from an client, broadcast to all servers
            qlog DEBUG,"[CLIENT".$mid."]>>>".$data.">>>";

            foreach (@processlist) {                    
                next unless ($_->{type} == SERVER);     # skip clients
                my $handleOUT = $_->{hOUT}; # just copy ref, $_->{} as handle doesn't work
                if ($handleOUT->opened) { 
                    # handle openned we can send data
                    print $handleOUT $data, "\n";
                } else {
                    # handle closed, so we must reopen handle first and then send data
                    qlog INFO,"Re-starting server ".$_->{cmd};
                    $_->{pid} = open2($_->{hIN}, $_->{hOUT}, $_->{cmd});
                    $select->add($_->{hIN});
                    print $handleOUT $data, "\n"; # send data
                }                
            }
            

        } else {
            warn "Unknown process type!\n";
        }

    } else {
        $buffer[$id] .= $buf; 
    }

    }
}

# show XML process-list
# input: reference to @process
sub cmmsd_status {
  my $p = shift;
  print STDERR "<status>\n";
  foreach (@$p) {   
      print STDERR "  <process>\n";
      my $val;
      foreach my $key (sort keys %$_) {
        if ($key eq "type") { 
            $val = ($$_{$key} == SERVER) ? "server" : "client";
        } elsif (($key eq "hIN") || ($key eq "hOUT")) { 
            $val = $$_{$key}->opened ? "opened" : "closed"; 
            $key = ($key eq "hIN") ? "handleIN" : "handleOUT";
        } elsif ($key eq "pid") {
            $val = (defined $$_{$key}) ? $$_{$key} : "undefined";
        } else {
          $val = $$_{$key};
        }
        print STDERR "      <$key>$val</$key>\n";
      }
      print STDERR "  </process>\n";
  }
  print STDERR "</status>\n";
} # end of cmmsd_status

# reap the freshly dead child
# input: handle ref, ref to @processlist
sub reap {
  my ($h, $p) = @_;      
  # find process for current handle, close both handles
  # and reap kid so we won't have zombies...
  foreach (@$p) {
    next unless ($_->{hIN} == $h);
    qlog INFO,"Closing process($_->{pid})";
    close $_->{hIN};   
    close $_->{hOUT};
    waitpid($_->{pid}, 0) or warn "Unable to close process($_->{pid}).\n";
    undef $_->{pid};
  }
}

1;
