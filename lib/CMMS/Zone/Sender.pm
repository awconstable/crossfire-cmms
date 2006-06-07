package CMMS::Zone::Sender;

use strict;
use CMMS::Zone::NowPlaying;
use CMMS::Zone::Library;
use CMMS::Zone::Player;

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1
};
our($AUTOLOAD);

#############################################################
# Constructor
#
sub new {
	my $class = shift;
	my (%params) = @_;

	die('No database connection') unless $params{mc};
	die('No config') unless $params{conf};
	die('No handle') unless $params{handle};
	die('No zone') unless $params{zone};

	my $self = {};
	$self->{conf} = $params{conf};
	$self->{handle} = $params{handle};
	$self->{zone} = $params{zone};

	$self->{lib} = new CMMS::Zone::Library(handle => $self->{handle}, zone => $self->{zone}, conf => $self->{conf});
	$self->{now} = new CMMS::Zone::NowPlaying(handle => $self->{handle}, zone => $self->{zone}, conf => $self->{conf});

	bless $self, $class;
	$self->mysqlConnection($params{mc});

	return $self;
}

#############################################################
# AUTOLOAD restrict method aliases
#
sub AUTOLOAD {
	my $self = shift;
	die("$self is not an object") unless my $type = ref($self);
	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	die("Can't access '$name' field in object of class $type") unless( exists $permitted->{$name} );

	return (@_?$self->{$name} = shift:$self->{$name});
}

#############################################################
# DESTROY
#
sub DESTROY {
	my $self = shift;
}

sub loop { 
	my $self = shift;

	my $line;
	my %cmd;

	while(defined ($line = <STDIN>)) {
		chomp $line;
		last if $line eq 'quit';
		next if $line eq ''; # empty line - there won't be command
		%cmd = cmd2hash $line;
		next unless %cmd;  # empty hash - there won't be command either
		next unless &check_cmd(\%cmd, $zone); # do further checking (eg. zone)
		my $cmd = $self->process(\%cmd);
		send2player($handle, $cmd) if $cmd;
	}
}

sub process {
	my($self,$c) = @_;

	if ($self->{lc $c->{screen}}) {  # Call function
		return $self->{lc $c->{screen}}->($c);
	} else {
		print STDERR "Unknown screen: $c->{screen}\n"
	}

	return 0;
}

1;
