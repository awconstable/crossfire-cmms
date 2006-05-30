package CMMS::Psudo;

use strict;
use IO::Pty;
use POSIX 'setsid';
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(psudo_tty);

sub psudo_tty {
	my $cmd = shift;
	my $pty = IO::Pty->new or die "can't make Pty: $!";
	defined (my $child = fork) or die "Can't fork: $!";
	return ($pty,$child) if $child;
	setsid();
	my $tty = $pty->slave;
	close $pty;
	STDIN->fdopen($tty,'r') or die "STDIN: $!";
	STDOUT->fdopen($tty,'w') or die "STDOUT: $!";
	STDERR->fdopen($tty,'w') or die "STDERR: $!";
	close $tty;
	$| = 1;
	exec $cmd;
	die "Couldn't exec: $!";
}

1;
