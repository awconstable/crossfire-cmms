package CMMS::Zone::NowPlaying;

use strict;
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

  my ($track_id, $track_order);
  ($track_id, $track_order) = &current_track($dbh, $zone);
  &track_mark_played($dbh, $zone, $track_id, $track_order);
  # not necessary, cause we are playing already marked one
  if ((defined $track_id) &&
      (defined $track_order)) {
      return &playtrack($dbh, $track_id);
  };

}

sub stop {
  return "stop";
}

sub pause {
  return "pause";
}

sub rev {
  return "seek -10";
}

sub fwd {
  return "seek +10";
}

sub prev {
  my ($track_id, $track_order) = &get_current_track($dbh, $zone);
  if (defined $track_id && defined $track_order) {
      if ($track_order == 0) {
          return &play_stop_by_state($track_id);
      } else {
          &track_unmark_played($dbh, $zone, $track_id, $track_order);
          my ($track_id2, $track_order2) = &current_track($dbh, $zone);
          if (defined $track_id2 && defined $track_order2) {
              return &play_stop_by_state($track_id2);
          } else {
              my %cmd = (
                 zone => $zone,
                 cmd  => "transport",
                 playlist => "_________ START _________"
              );
              print &hash2cmd(%cmd);
          }
      }
  } else {
    # else we don't have anything else to play
    
    # let's tell it this usefull information to the user
    my %cmd = (
       zone => $zone,
       cmd  => "transport",
       playlist => '_________ START _________'
    );
    print &hash2cmd(%cmd);
  }


  0;
}

sub next {
  my ($track_id, $track_order) = &get_next_track($dbh, $zone);
  if (defined $track_id && defined $track_order) {
    &track_mark_played($dbh, $zone, $track_id, $track_order);
    return &play_stop_by_state($track_id);
  } else {
    # else we don't have anything else to play

    # let's tell it this usefull information to the user
  }

  0;
}


sub play_stop_by_state {
  my ($track_id) = @_;
  my $state = zone_mem_get($dbh, $zone, 'state');
  if ($state eq "play") {
      return &playtrack($dbh, $track_id);
  } elsif ($state eq "stop") {
      my %trackinfo = &zone::player::get_fulltrack_info($dbh, $zone, $track_id);
      print &hash2cmd(%trackinfo);
  } elsif ($state eq "pause") {
      my %trackinfo = &zone::player::get_fulltrack_info($dbh, $zone, $track_id);
      print &hash2cmd(%trackinfo); 
      return "stop";
  }
  0;
}



sub random {
  &zone_mem_bool_neg($dbh, $zone, 'random');
  my %cmd = (
     zone => $zone,
     cmd  => "transport",
     random => &zone_mem_bool_get($dbh, $zone, 'random')
  );
  print &hash2cmd(%cmd);
  0;
}

sub repeat {
  &zone_mem_bool_neg($dbh, $zone, 'repeat');
  my %cmd = (
     zone => $zone,
     cmd  => "transport",
     repeat => &zone_mem_bool_get($dbh, $zone, 'repeat')
  );
  print &hash2cmd(%cmd);
  0;
}


my %commands = (
    play    => \&play,
    stop    => \&stop,
    pause   => \&pause,
    rev     => \&rev,
    fwd     => \&fwd,
    previous=> \&prev,
    next    => \&next,
    repeat  => \&repeat,
    random  => \&random
);
  
sub process {
  my ($c) = @_;
  if ($commands{lc $c->{cmd}}) {  # Call function 
      return $commands{lc $c->{cmd}}->() 
  } else { print STDERR "Unknown command: $c->{cmd}\n" }
  return 0;  
}

1;
