package CMMS::Zone::Status;

use strict;
use CMMS::Zone::Player;

my $time = -1; # used for keeping old time, so we'll send only time changes

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
  my ($track_id, $track_order) = &get_next_track($dbh, $zone);
  if (defined $track_id && defined $track_order) {
      my $command = &playtrack($dbh, $track_id);
      send2player($handle, $command);
      # mark it after music starts playing 
      &track_mark_played($dbh, $zone, $track_id, $track_order);
  } # else we don't have anything else to play
  return ();
}

sub pause {
  &zone_mem_set($dbh, $zone, 'state', 'pause');
  return (
    cmd   => "transport",
    state => "pause"
  )
}

sub playing {
  &zone_mem_set($dbh, $zone, 'state', 'play');
  return (
    cmd   => "transport",
    state => "play"
  )
}

sub stop {
  &zone_mem_set($dbh, $zone, 'state', 'stop');
  return (
    cmd   => "transport",
    state => "stop"
  )
}

sub get_track_info {    
  my ($dir, $file) = @_;
  my $track_id = filename2trackid($dbh, $dir, $file);
  return get_fulltrack_info($dbh, $zone, $track_id);    
}

sub status_play {
  my ($data) = @_;
  # PLAYER.... MP3 UNIQUE LOCATION
  # mod_mpg123 /home/chrala/cmms_mp3/rolling_stones/flashpoint/17-sex_drive.mp3
  $data =~ /^(\w*) (.*)$/;

  my ($host, $port, $location, $path) = &config_zone;

  # PREXIF...............|DIRECTORY................|FILENAME
  # /storedir/media/audio/rolling_stones/flashpoint/06-ruby_tuesday.mp3
  # /home/chrala/cmms_mp3/rolling_stones/flashpoint/17-sex_drive.mp3
  $data = $2;
  $data =~ s/$path//;
  $data =~ /^(.*)\/(.*)$/;

  return get_track_info($1."/", $2);
}

sub time {
  my ($data) = @_;

  my ($enabled, $format) = &config_zone_time;
  return () unless $enabled;

  $data =~ /^(\d*) (\d*)$/;

  if ($time != $1) {  # show time every second
      $time = sprintf("%d", $1);
      my $complex_time = sprintf($format,
            ($time / 60),     ($time % 60),
            (($1+$2+0) / 60), (($1+$2+0) % 60),
            (($2+0) / 60), (($2+0) % 60)
      );
      return (
         cmd   => "transport",
         feedback => $complex_time
       );
  }
  return ();
}

my %commands = (
  200 => {
      pause  => \&pause,
      unpause=> \&playing,  # call playing function instead
      idle   => sub {},
      update => sub {},
      stop   => sub {},
  },
  210 => {
      seek   => sub {},
      pause  => sub {},
      stop   => sub {},
  },
  220 => {
      knowntype => sub {}, # cointains type of song, might be usefull
  },
  230 => {
      playing  => \&playing,
      play     => \&status_play,
      time     => \&time,
      stop     => \&stop,
      endofsong=> \&endofsong,
      seek     => sub {},
      pause    => sub {},
  },
  240 => {
      songtype => sub {},
      songtypeguess => sub {},
  }

);

sub loop { 
  my $line;
  my %cmd;
  while (defined ($line = <$handle>)) {
    chomp $line;
    $line =~ s/\r//;
    next if $line eq ""; # empty line - there won't be command
    #print STDERR "received: ", $line, "\r\n";
    
    # status, command, data
    my ($status, $cmd, $data);
    if ($line =~ /^(\d\d\d): (\w*) (.*)$/) {  
       $status = $1;
       $cmd    = $2;
       $data   = $3;
    } elsif ($line =~ /^(\d\d\d): (\w*)$/) {
       $status = $1;
       $cmd    = $2;
       $data   = undef;
    } else {
      next;
    }

    if ($commands{lc $status}{lc $cmd}) { 
        my %ret = $commands{lc $status}{lc $cmd}->($data);
        $ret{zone} = $zone;
        print hash2cmd(%ret);
    } else { 
        print STDERR "irmp3d: ".$line."\n"; 
    }

  }
}

1;
