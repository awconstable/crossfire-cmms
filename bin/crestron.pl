#!/usr/bin/perl -w

use strict;
use IO::Socket;
use IO::Select;
use Config::General;
use Time::HiRes qw(sleep);

# load config & configure multiplexer
my %conf = ParseConfig('/etc/cmms.conf');
my $conf = $conf{crestron};

STDOUT->autoflush(1);

print STDERR localtime(time)." Starting crestron server [",$conf->{bind}, ":", $conf->{port}, "]\n";
# create a socket to listen to a port
my $listen = IO::Socket::INET->new(Proto => 'tcp',
                                   LocalHost => $conf->{bind},
				   LocalPort => $conf->{port},
				   Listen => 1,
				   ReuseAddr => 1,
				   MultiHomed => 1
) or die "Unable to start crestron server: ".$!;
print STDERR localtime(time)." Server started [",$listen->sockhost, ":", $listen->sockport, "]\n";

my $select = IO::Select->new($listen,\*STDIN);

while(1) {
	foreach my $sock ($select->can_read(0)) {
		if($sock == $listen) {
			my $new = $listen->accept;
			$select->add($new);
			print STDERR localtime(time)." Client(",$new->fileno,") [",$new->peerhost,":",$new->peerport, "] connected.\n";
		} elsif($sock == \*STDIN) {
			my $line = <$sock>;
			$line =~ s/[\r\n]+//g;

			foreach my $hndl ($select->handles) {
				next if $hndl==$listen || $hndl==$sock || !$hndl->connected || !$hndl->fileno;
				print $hndl "$line\r\n";
			}
		} else {
			my $line='';
			unless($sock->sysread($line,1024)) {
				print STDERR localtime(time)." Client(",$sock->fileno,") disconnected.\n";
				$select->remove($sock);
				$sock->close;
				next;
			}

			$line =~ s/\r+//g;
			foreach my $command (split "\n", $line) {
				print STDOUT "$command\r\n";
			}
		}
	}

	sleep 0.1;
}
