package CMMS::Zone::Player;

use strict;
use CMMS::Database::zone_mem;

use vars qw($VERSION);
$VERSION = 0.01;

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

	$self->{zone_obj} = new CMMS::Database::zone_mem(mc => $params{mc}, id => $self->{zone});

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

#
# commands 
#

sub playtrack {
	my ($self, $track_id) = @_;

	my $filename = $self->trackid2filename($track_id);
	return 0 unless $filename;

	my $path = $self->{zone}->{datapath};

	return 'play '.$path.$filename;
}

sub get_prev_track {
  print STDERR "prev track request\n"; # LEVEL 1
  my ($dbh, $zone) = @_;
  my $q = qq{
      SELECT track_id, track_order
      FROM playlist_current 
      WHERE zone = %d AND track_played IS NOT NULL
      ORDER BY track_order DESC
      LIMIT 1;
  };
  $q = sprintf($q, $zone);
  my $sth = db_select($dbh, $q);
  if (my @row = $sth->fetchrow_array) {
      print STDERR "prev track is ($row[0]:$row[1])\n"; # LEVEL 2
      return ($row[0], $row[1]);
  }
  return (undef, undef);      
}

sub track_mark_played {
	my ($self, $track_id, $track_order) = @_;
	my $mark = 'playlist_current_played($self->{zone})';
	return $self->set_track_mark($track_id, $track_order, $mark);
}

sub track_unmark_played {
	my ($self, $track_id, $track_order) = @_;
	return $self->set_track_mark($track_id, $track_order, 'NULL');
}

sub set_track_mark {
	my ($self, $track_id, $track_order, $mark) = @_;
	return 0 unless defined $track_id;
	return 0 unless defined $track_order;

	my $mc = $self->mysqlConnection;

	print STDERR "marking track ($track_id:$track_order) as ".($mark eq "NULL" ? "unplayed" : "played")."\n"; # LEVEL 1

	my $sql = qq{
		UPDATE playlist_current 
		SET track_played = %s 
		WHERE zone = %d 
		AND track_id = %d 
		AND track_order = %d
	};

	$sql = sprintf($sql, $mark, $self->{zone}, $track_id, $track_order);

	return db_query($sql);
}

sub unmark_all_tracks {
  print STDERR "unmarking all tracks\n"; # LEVEL 1
  my ($dbh, $zone) = @_;
  my $q = sprintf("
        UPDATE playlist_current 
        SET track_played = NULL 
        WHERE zone = %d", $zone); 
  my $ret = db_query($dbh, $q);
  return $ret;
}

#
# support functions (queries, ...)
#

sub trackid2filename {
	my ($self, $trackid) = @_;

	my $mc = $self->mysqlConnection;

	my $sql = qq{
		SELECT file_location, file_name 
		FROM track_data 
		WHERE track_id = %d
	};

	$sql = sprintf($sql, $trackid);
	my $row = $mc->query_and_get($sql)||[];
	$row = $row->[0];

	return $row->{file_location}.$row->{file_name} if $row;

	return undef;
}

sub filename2trackid {
	my ($self, $dir, $file) = @_;

	my $mc = $self->mysqlConnection;

	my $sql = qq{
		SELECT track_id FROM track_data 
		WHERE file_location = '%s' AND 
		file_name = '%s'
	};

	$sql = sprintf($sql, $dir, $file);
	my $row = $mc->query_and_get($sql)||[];
	$row = $row->[0];

	return $row->{track_id} if $row;

	return undef;
}

sub current_track {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my $sql = qq{
		SELECT Count(*) 
		FROM playlist_current 
		WHERE zone = %d AND 
		track_played IS NOT NULL;
	};

	$sql = sprintf($sql, $self->{zone});
	my $row = $mc->query_and_get($sql)||[];
	$row = $row->[0];

	if ($row->{'Count(*)'} > 0) {
	    	# we are somewhere in the playlist, so we can get current track
	    	return $self->get_current_track;
	} else {
	    	# we haven't played anything yet, so we need get the first track
	    	# first track can be first track from current playlist, or any track for random play.
	    	# therefore we call next track function that implements this logic.
	    	return $self->get_next_track;
	}
}

sub get_current_track {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my $sql = qq{
		SELECT track_id, track_order 
		FROM playlist_current 
		WHERE zone = %d AND track_played IS NOT NULL 
		ORDER BY track_order DESC 
		LIMIT 1;
	};

	$sql = sprintf($sql, $self->{zone});
	my $row = $mc->query_and_get($sql)||[];
	$row = $row->[0];

	return ($row->{track_id}, $row->{track_order}) if $row;

	return (undef, undef);      
}

sub get_next_track {
	my $self = shift;

	my ($tr, $to, $random);
	$random = $self->{zone_obj}->get('random');
	if($random) {
		($tr, $to) = $self->get_next_track_randomly;
	} else {
		($tr, $to) = $self->get_next_track_in_order;
	}

	if(defined $tr && defined $to) {
		return ($tr, $to);
	} else {
		# this is the last track, check repeat
		if($self->{zone_obj}->get('repeat')) {
			# clear playlist and start again
			$self->unmark_all_tracks;
			# get next track again. (it might be recursion, however
			# this avoids infinite loops
			if($random) {
				return $self->get_next_track_randomly;
			} else {
				return $self->get_next_track_in_order;
			}
		}
	}

	print STDERR "LAST TRACK\n"; # LEVEL 1
	return (undef, undef);      
}

sub get_next_track_in_order {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	print STDERR "getting next track in order\n"; # level 1

	my $sql = qq{
		SELECT track_id, track_order 
		FROM playlist_current 
		WHERE zone = %d AND track_played IS NULL 
		ORDER BY track_order 
		LIMIT 1;
	};

	$sql = sprintf($sql, $self->{zone});
	my $row = $mc->query_and_get($sql)||[];
	$row = $row->[0];

	if($row) {
		print STDERR "next track is ($row->{track_id}:$row->{track_order})\n"; # level 2
		return ($row->{track_id}, $row->{track_order});
	} else {
		return (undef, undef);
	}
}

sub get_next_track_randomly {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	print STDERR "getting next track randomly\n"; # level 1

	# list all unplayed track, and make select somewhere in it
	# this generates next random track

	my $total_tracks  = $self->get_playlist_num_tracks;
	my $played_tracks = $self->get_playlist_num_played;
	my $random = rand($total_tracks-$played_tracks);

	my $sql = qq{
		SELECT track_id, track_order 
		FROM playlist_current 
		WHERE zone = %d AND track_played IS NULL 
		ORDER BY track_order 
		LIMIT 1 OFFSET %d;
	};

	$sql = sprintf($sql, $self->{zone}, $random);
	my $row = $mc->query_and_get($sql)||[];
	$row = $row->[0];

	if($row) {
		print STDERR "next track is ($row->{track_id}:$row->{track_order})\n"; # level 2
		return ($row->{track_id}, $row->{track_order});
	} else {
		return (undef, undef);
	}
}

sub get_playlist_num_played {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my $sql = qq{
		SELECT Count(*) 
		FROM playlist_current 
		WHERE zone = %d AND 
		track_played IS NOT NULL
	};

	$sql = sprintf($sql, $self->{zone});
	my $row = $mc->query_and_get($sql)||[];
	$row = $row->[0];

	return $row->{'Count(*)'} if $row;

	return undef;
}

sub get_playlist_num_tracks {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my $sql = qq{
		SELECT Count(*) 
		FROM playlist_current 
		WHERE zone = %d
	};

	$sql = sprintf($sql, $self->{zone});
	my $row = $mc->query_and_get($sql)||[];
	$row = $row->[0];

	return $row->{'Count(*)'} if $row;

	return undef;
}

sub get_fulltrack_info { 
  my ($dbh, $zone, $track_id) = @_;
  my $q = qq{
      SELECT t.track_num as track_num, t.title AS track, 
             artist.name as artist,
             album.name as album,
             genre.name as genre,
             t.length_seconds as length 
      FROM track t, album, artist, genre
      WHERE t.id = '%d' 
            AND t.artist_id = artist.id
            AND t.album_id = album.id
            AND t.genre_id = genre.id
  };
  $q = sprintf($q, $track_id);
#  print $q;
  my $sth = db_select($dbh, $q);

#  my $playlist = "";
#  my ($tid, $torder) = get_current_track($dbh, $zone);
#  if (defined $torder) { $playlist .= ++$torder . ". "; }
  my $playlist = &get_playlist_num_played($dbh, $zone)."/".&get_playlist_num_tracks($dbh, $zone);
  my $playlist_id = &zone_mem_get($dbh, $zone, 'playlist');
  if (defined $playlist_id) {
      $playlist .= " - ". get_playlist_name($dbh, $playlist_id);  
  } else {
      $playlist .= "__ made-to-order __";
  }
      
  if (my @row = $sth->fetchrow_array) {
      my %hash = (
          cmd    => "transport",
          zone   => $zone,
          track  => $row[0]. '. ' . $row[1],
          artist => $row[2],
          album  => $row[3],
          genre  => $row[4],
          playlist => $playlist
      );

      my ($timeenabled, $timeformat) = &config_zone_time;
      if ($timeenabled) {
          my $time = $row[5];
          $hash{feedback} = sprintf($timeformat,
                0,0, ($time / 60), ($time % 60), ($time / 60), ($time % 60));
      } else {
          $hash{feedback} = "";
      }
      
      my $play_state = &zone_mem_get($dbh, $zone, 'state');      
      if (defined $play_state) {
          $hash{state} = $play_state;
      }

      return %hash;
  }
  return undef;
}

sub get_playlist_name {
  my ($dbh, $playlist_id) = @_;
  my $q = sprintf("SELECT name FROM playlist WHERE id=%d", $playlist_id);
  my $sth = db_select($dbh, $q);
  if (my @row = $sth->fetchrow_array) {
    return $row[0];
  } else {
    return "unknown...";
  }
}

1;
