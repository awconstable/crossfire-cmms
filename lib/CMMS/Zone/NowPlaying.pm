package CMMS::Zone::NowPlaying;

use strict;
use CMMS::Zone::Player;
use CMMS::Zone::Command;

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1
};
our($AUTOLOAD);

our $commands = {
    play    => 'play',
    stop    => 'stop',
    pause   => 'pause',
    rev     => 'rev',
    fwd     => 'fwd',
    previous=> 'prev',
    next    => 'next',
    repeat  => 'repeat',
    random  => 'random'
};

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

	$self->{player} = new CMMS::Zone::Player(mc => $params{mc}, handle => $self->{handle}, zone => $self->{zone}, conf => $self->{conf});

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

sub play {
	my $self = shift;

	my $mc = $self->mysqlConnection;
	my $state = '';
	my $rows = $mc->query_and_get("select value from zone_mem where zone = $self->{zone}->{number}")||[];
	my $row = $rows->[0];
	$state = $row->{value} if $row;
	return $self->pause if $state eq 'pause';
	return 0 if $state eq 'play';

	my ($track_id, $track_order) = $self->{player}->current_track;
	$self->{player}->track_mark_played($track_id, $track_order);
	# not necessary, cause we are playing already marked one

	return $self->{player}->playtrack($track_id) if (defined $track_id) && (defined $track_order);
}

sub stop {return 'stop';}
sub pause {return 'pause';}
sub rev {return 'seek -10';}
sub fwd {return 'seek +10';}

sub prev {
	my $self = shift;

	my ($track_id, $track_order) = $self->{player}->get_current_track;

	if(defined $track_id && defined $track_order) {
		$self->{player}->track_unmark_played($track_id, $track_order);
		my ($track_id2, $track_order2) = $self->{player}->current_track;
		if(defined $track_id2 && defined $track_order2) {
			$self->{player}->track_mark_played($track_id2, $track_order2);
			return $self->play_stop_by_state($track_id2);
		}
	}
	# else we don't have anything else to play
	# let's tell it this usefull information to the user

	0;
}

sub next {
	my $self = shift;

	my ($track_id, $track_order) = $self->{player}->get_next_track;

	if(defined $track_id && defined $track_order) {
		$self->{player}->track_mark_played($track_id, $track_order);
		return $self->play_stop_by_state($track_id);
	}
	# else we don't have anything else to play
	# let's tell it this usefull information to the user

	0;
}


sub play_stop_by_state {
	my ($self, $track_id) = @_;

	my $mc = $self->mysqlConnection;

	my $row = $mc->query_and_get("SELECT value from zone_mem where zone = '$self->{zone}->{number}' AND `key` = 'state'")||[];
	$row = $row->[0];
	my $state = $row->{value};

	if($state eq 'play') {
		return $self->{player}->playtrack($track_id);
	} elsif($state eq 'stop') {
		my %trackinfo = $self->{player}->get_fulltrack_info($track_id);
		print &hash2cmd(%trackinfo);
	} elsif($state eq 'pause') {
		my %trackinfo = $self->{player}->get_fulltrack_info($track_id);
		print &hash2cmd(%trackinfo);
		return 'stop';
	}

	0;
}

sub random {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my $row = $mc->query_and_get("SELECT value from zone_mem where zone = '$self->{zone}->{number}' AND `key` = 'random'")||[];
	$row = $row->[0];
	my $random = $row->{value};

	if($random) {
		$mc->query_and_get("DELETE from zone_mem where zone = '$self->{zone}->{number}' AND `key` = 'random'");
		$random = undef;
	} else {
		$mc->query_and_get("REPLACE INTO zone_mem values('$self->{zone}->{number}', 'random', 1)");
		$random = 1;
	}

	my %cmd = (
		zone => $self->{zone}->{number},
		cmd  => 'transport',
		random => $random
	);

	print &hash2cmd(%cmd);

	0;
}

sub repeat {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my $row = $mc->query_and_get("SELECT value from zone_mem where zone = '$self->{zone}->{number}' AND `key` = 'repeat'")||[];
	$row = $row->[0];
	my $repeat = $row->{value};

	if($repeat) {
		$mc->query_and_get("DELETE from zone_mem where zone = '$self->{zone}->{number}' AND `key` = 'repeat'");
		$repeat = undef;
	} else {
		$mc->query_and_get("REPLACE INTO zone_mem values('$self->{zone}->{number}', 'repeat', 1)");
		$repeat = 1;
	}

	my %cmd = (
		zone => $self->{zone}->{number},
		cmd  => 'transport',
		repeat => $repeat
	);

	print &hash2cmd(%cmd);

	0;
}

sub process {
	my ($self, $c) = @_;
	
	if($commands->{lc $c->{cmd}}) {  # Call function
		my $method = $commands->{lc $c->{cmd}};
		return eval "\$self->$method";
	} else {
		print STDERR "Unknown command: $c->{cmd}\n"
	}

	return 0;  
}

1;
