package CMMS::Zone::Status;

use strict;
use CMMS::Zone::Player;
use CMMS::Zone::Command;

our $time = -1; # used for keeping old time, so we'll send only time changes

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1
};
our($AUTOLOAD);

our $commands = {
  200 => {
      pause  => 'pause',
      unpause=> 'playing',  # call playing function instead
      idle   => 'default',
      update => 'default',
      stop   => 'default',
  },
  210 => {
      seek   => 'default',
      pause  => 'default',
      stop   => 'default',
  },
  220 => {
      knowntype => 'default', # cointains type of song, might be usefull
  },
  230 => {
      playing  => 'playing',
      play     => 'status_play',
      time     => 'time',
      stop     => 'stop',
      endofsong=> 'endofsong',
      seek     => 'default',
      pause    => 'default',
  },
  240 => {
      songtype => 'default',
      songtypeguess => 'default',
  }

};

sub default {}

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

sub endofsong {
	my $self = shift;

	my ($track_id, $track_order) = $self->{player}->get_next_track;
	if (defined $track_id && defined $track_order) {
		my $command = $self->{player}->playtrack($track_id);
		send2player($self->{handle}, $command);
		# mark it after music starts playing
		$self->{player}->track_mark_played($track_id, $track_order);
	} # else we don't have anything else to play

	return ();
}

sub pause {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	$mc->query("REPLACE INTO zone_mem VALUES('$self->{zone}->{number}', 'state', 'pause')");

	return (
		cmd   => 'transport',
		state => 'pause'
	)
}

sub playing {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	$mc->query("REPLACE INTO zone_mem VALUES('$self->{zone}->{number}', 'state', 'play')");

	return (
		cmd   => 'transport',
		state => 'play'
	)
}

sub stop {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	$mc->query("REPLACE INTO zone_mem VALUES('$self->{zone}->{number}', 'state', 'stop')");

	return (
		cmd   => 'transport',
		state => 'stop'
	)
}

sub get_track_info {    
	my ($self, $dir, $file) = @_;

	my $track_id = $self->{player}->filename2trackid($dir, $file);
	return $self->{player}->get_fulltrack_info($track_id);
}

sub status_play {
	my ($self, $data) = @_;

	# PLAYER.... MP3 UNIQUE LOCATION
	# mod_mpg123 /home/chrala/cmms_mp3/rolling_stones/flashpoint/17-sex_drive.mp3
	$data =~ /^(\w*) (.*)$/;

	# PREXIF...............|DIRECTORY................|FILENAME
	# /storedir/media/audio/rolling_stones/flashpoint/06-ruby_tuesday.mp3
	# /home/chrala/cmms_mp3/rolling_stones/flashpoint/17-sex_drive.mp3
	$data = $2;
	$data =~ /^(.*)\/(.*)$/;

	return $self->get_track_info($1.'/', $2);
}

sub time {
	my ($self, $data) = @_;

	my $enabled = $self->{zone}->{time};
	my $format = $self->{zone}->{timeformat};
	return () unless $enabled;

	$data =~ /^(\d*) (\d*)$/;

	if($time != $1) {  # show time every second
		$time = sprintf('%d', $1);
		my $complex_time = sprintf($format,
		($time / 60),     ($time % 60),
		(($1+$2+0) / 60), (($1+$2+0) % 60),
		(($2+0) / 60), (($2+0) % 60));
		return (
			cmd   => 'transport',
			feedback => $complex_time
		);
	}

	return ();
}

sub loop {
	my $self = shift;

	my $handle = $self->{handle};

	my $line;
	my %cmd;
	while(defined ($line = <$handle>)) {
		chomp $line;
		$line =~ s/\r//;
		next if $line eq ''; # empty line - there won't be command

		# status, command, data
		my ($status, $cmd, $data);
		if($line =~ /^(\d\d\d): (\w*) (.*)$/) {
			$status = $1;
			$cmd    = $2;
			$data   = $3;
		} elsif($line =~ /^(\d\d\d): (\w*)$/) {
			$status = $1;
			$cmd    = $2;
			$data   = undef;
		} else {
			next;
		}

		if($commands->{lc $status}{lc $cmd}) {
			my $method = $commands->{lc $status}{lc $cmd};
			my %ret = eval "\$self->$method(\$data)";
			if($ret{cmd}) {
				$ret{zone} = $self->{zone}->{number};
				print hash2cmd(%ret);
			}
		} else {
			print STDERR "irmp3d: ".$line."\n";
		}
	}
}

1;
