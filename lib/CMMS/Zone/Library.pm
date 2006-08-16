package CMMS::Zone::Library;

use strict;
use Storable qw(freeze thaw);
use CMMS::Zone::Player;
use CMMS::Zone::NowPlaying;
use CMMS::Zone::Command;
use POSIX qw(ceil);
use Quantor::Log;

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1
};
our($AUTOLOAD);

#
# definitions
#

use constant SEP_LINES => ";";
use constant EMPTY_ROW => "~"; # empty row in library menu listing, eg. "----"

my @history;
my $limit = 8; # number of rows to select for touch screen

my %mem = ( # current variables
        category => undef,

        playlist_id => undef,
        genre_id    => undef,
        artist_id   => undef, 
        album_id    => undef,
        search      => undef,
        
        offset   => 0,
); 

#
# command references
#

our $commands = {
    list        => 'list',
    page_prev   => 'page_prev',
    page_next   => 'page_next',
    menu_select => 'menu_select',
    back	=> 'back',
    selectall   => 'selectall',
    queueall	=> 'queueall',
    playall	=> 'playall',
    search_add	=> 'search_add',
    search_back => 'search_back',
    search_clear=> 'search_clear',
};

our $menu_commands = {
    change      => 'menu_change',
    play        => 'menu_play',
    playplaylist=> 'menu_playplaylist',
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

	$self->{now_play} = new CMMS::Zone::NowPlaying(mc => $params{mc}, handle => $self->{handle}, zone => $self->{zone}, conf => $self->{conf});
	$self->{player} = new CMMS::Zone::Player(mc => $params{mc}, handle => $self->{handle}, zone => $self->{zone}, conf => $self->{conf});

	bless $self, $class;
	$self->mysqlConnection($params{mc});

	$self->mem_reset;

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
# initialisation & defaults
#

sub mem_reset {
	$mem{category} = undef;
	$mem{offset} = 0;

	$mem{playlist_id} = undef;
	$mem{genre_id}    = undef;
	$mem{artist_id}   = undef;
	$mem{album_id}    = undef;
	$mem{search}      = undef,

	@history = ();
}

#
# HISTORY
#

sub history_empty {
	qlog INFO, "HISTORY: Empty";
	@history = ();
}

sub history_back {
	if (@history > 1) {
		qlog INFO, "HISTORY: back";
		my $hsize = @history;
		pop @history;
		my $serialized = $history[@history-1]; #last record
		%mem = %{ thaw($serialized) };
		return 1; 
	} else {
		return 0;
	}
}

sub history_add {
	qlog INFO, "HISTORY: add";
	return push @history, &freeze(\%mem);
}

sub history_update {
	my $self = shift;

	qlog INFO, "HISTORY: update";
	pop @history; # if (@history > 1); # we can add another step to go at beginning of list
	$self->history_add;
}
  
#
# support functions
#

sub get_lines {
	my @namelist;
	my $i;
	for($i = 0; $i<$limit; $i++) {
		if( exists $mem{lines}{$i}{text} ) {
			$namelist[$i] = $mem{lines}{$i}{text};
		} else {
			$namelist[$i] = EMPTY_ROW; # "--"
		}
	}

	return join SEP_LINES, @namelist;
}

sub get_response {
	my $self = shift;

	return (
		cmd  => 'library',
		category => $mem{category},
		lines => $self->get_lines
	);
}

sub make_select {
	my ($self, $query) = @_;

	my $mc = $self->mysqlConnection;

	$query =~ s/(([^\|])\?)/$2%d/g;
	$query =~ s/\|\?/?/g;
	$query = sprintf($query, $limit, $mem{offset});

	my $rows = $mc->query_and_get($query)||[];

	$mem{lines} = ();
	my $i = 0;
	foreach( @{$rows} ) {
		$mem{lines}{$i}{id}   = $_->{id};
		$mem{lines}{$i}{text} = $_->{text};
		$i++;
	}

	return $i;
}

sub make_select_no_limit {
	my ($self, $query) = @_;

	my $mc = $self->mysqlConnection;

	$query =~ s/LIMIT \? OFFSET \?//ig;

	my $rows = $mc->query_and_get($query)||[];

	$mem{lines} = ();
	my $i = 0;
	foreach( @{$rows} ) {
		$mem{lines}{$i}{id}   = $_->{id};
		$mem{lines}{$i}{text} = $_->{text};
		$i++;
	}

	return $i;
}

sub sql_prepare_where {
	my $self = shift;

	my @where;
	my $i = 0;
	push(@where, sprintf("genre_id=%d",  $mem{genre_id} )) if ($mem{genre_id});
	push(@where, sprintf("artist_id=%d", $mem{artist_id})) if ($mem{artist_id});
	push(@where, sprintf("album_id=%d",  $mem{album_id} )) if ($mem{album_id});
	push(@where, sprintf("playlist_id=%d",  $mem{playlist_id} )) if ($mem{playlist_id});

	if($mem{search}) {
		my $search_column = 'name';
		$search_column = 'title' if ($mem{category} eq 'tracks');
		push(@where, "$search_column like '$mem{search}%%'");
	}

	if(@where) {
		return 'WHERE ' . join(' AND ', @where);
	}

	return 0;
}

#
# individual selects & package commands
#

sub sql_genre {
	my ($self, $where) = @_;
	$where = '' unless $where;

  return qq{
	SELECT g.id, g.name as text 
	FROM genre g 
	RIGHT JOIN track t ON g.id=t.genre_id
	$where
	GROUP BY g.id, g.name
	ORDER BY g.name
	LIMIT ? OFFSET ?
  };
}

sub select_genres {
	my $self = shift;

  my $q = $self->sql_genre($self->sql_prepare_where);
  my $rows = $self->make_select($q);
  if ($rows > 0) {
      for (my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{genre_id} = $id;
          $mem{lines}{$i}{cmd} = 'change';
          $mem{lines}{$i}{category} = 'artists';
      }
      return 1;
  } else {
      return 0;
  }
}

sub sql_artist_plain {
  return qq{SELECT id, name as text FROM artist ORDER BY name LIMIT ? OFFSET ?};
}

sub sql_artist_where {
	my ($self, $where) = @_;

  return qq{
         SELECT artist_id, a.name as text 
         FROM track t
         LEFT JOIN artist a ON t.artist_id = a.id
         $where
         GROUP BY artist_id, a.name
         ORDER by a.name
         LIMIT ? OFFSET ? 
  };
}

sub sql_album_plain {
  return qq{
     SELECT id, name as text 
     FROM album 
     ORDER BY name 
     LIMIT ? OFFSET ?};
}

sub sql_album_where {
	my ($self, $where) = @_;

  return qq{
         SELECT a.id, a.name as text 
         FROM track t 
         LEFT JOIN album a ON t.album_id = a.id
         $where
         GROUP BY a.id, a.name
         ORDER by a.name
         LIMIT ? OFFSET ? 
  };
}

sub sql_track_where_by_id {
	my ($self, $where) = @_;

  return qq{
         SELECT id, track_num || '. ' || title as text 
         FROM track 
         $where
         ORDER BY track_num
         LIMIT ? OFFSET ?
  };
}   

sub sql_track_where_num {
	my ($self, $where) = @_;

  return qq{
         SELECT track.id, track.title as text
         FROM track 
         $where
         ORDER BY track_num
         LIMIT ? OFFSET ? 
  };
}

sub sql_track_where_order {
        my ($self, $where) = @_;

  return qq{
         SELECT track.id, track.title as text
         FROM track
         $where
         ORDER BY track_order
         LIMIT ? OFFSET ?
  };
}

sub sql_track_where {
	my ($self, $where) = @_;

  return qq{
         SELECT id, title as text
         FROM track 
         $where
         ORDER BY title
         LIMIT ? OFFSET ? 
  };
}

sub select_artists {
	my $self = shift;

	my $q = '';
  if (my $tmp = $self->sql_prepare_where) {
      $q = $self->sql_artist_where($tmp);
  } else {
      $q = $self->sql_artist_plain;
  }

  my $rows = $self->make_select($q);
  if ($rows > 0) {
      for (my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{artist_id} = $id;
          $mem{lines}{$i}{cmd} = 'change';
          $mem{lines}{$i}{category} = 'albums';
      }
      return 1;
  } else {
      return 0;
  }
}

sub select_albums {
	my $self = shift;

	my $q = '';
  if(my $tmp = $self->sql_prepare_where) {
      $q = $self->sql_album_where($tmp);
  } else {
      $q = $self->sql_album_plain;
  }

  my $rows = $self->make_select($q);
  if($rows > 0) {
      for(my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{album_id} = $id;
          $mem{lines}{$i}{cmd} = 'change';
          $mem{lines}{$i}{category} = 'tracks';
      }
      return 1;
  } else {
      return 0;
  }
}

sub select_tracks {
	my $self = shift;

	my $q = '';
  if(my $tmp = $self->sql_prepare_where) {
      if($mem{album}) { 
          $q = $self->sql_track_where_by_id($tmp);
      } else {
          $q = $self->sql_track_where_num($tmp);
      }
  } else {
      $q = $self->sql_track_where('');
  }

  my $rows = $self->make_select($q);
  if($rows > 0) {
      for(my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{track_id} = $id;
          $mem{lines}{$i}{cmd} = 'play';
      }
      return 1;
  } else {
      return 0;
  }
}

sub select_playlist_tracks {
	my $self = shift;

	my $sql = $self->sql_track_where_order(", playlist_track where playlist_track.track_id = track.id and playlist_track.playlist_id = $mem{playlist_id}");
	$sql = $self->sql_track_where_order(", playlist_current where playlist_current.track_id = track.id and playlist_current.zone = '$self->{zone}->{number}'") if $mem{playlist_id} == -1;

  my $rows = $self->make_select($sql);
  if($rows > 0) {
      for(my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{track_id} = $id;
          $mem{lines}{$i}{cmd} = 'play';
      }
      return 1;
  } else {
      return 0;
  }
}

sub sql_playlist {
	my ($self, $where) = @_;
	$where = '' unless $where;

  return qq{
	SELECT id, name as text 
	FROM playlist 
	$where 
	ORDER BY name 
	LIMIT ? OFFSET ?
  };
}

sub select_playlists {
	my $self = shift;

	my $q = $self->sql_playlist($self->sql_prepare_where);

  my $rows = $self->make_select($q);
  if ($rows > 0) {
      for (my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{playlist_id} = $id;
          $mem{lines}{$i}{cmd} = 'playplaylist';
          $mem{lines}{$i}{category} = 'tracks';
      }
  }

	my %hash = ();
	my $i = 1;
	my $tmp = $mem{lines};
	foreach(values %{$tmp}) {
		$hash{$i++} = $_;
	}
	$hash{0} = {
		playlist_id => -1,
		text => 'Now Playing',
		cmd => 'playplaylist',
		category => 'tracks'
  	};
  	$mem{lines} = \%hash;

	return 1;
}


#
# commands implementation
#

# new list request
sub list {
	my ($self, $data) = @_;

	$self->mem_reset;
	$mem{category} = $data->{category};
	$self->history_empty;
	$self->history_add;

	return $self->prepare_memory;
}

sub selectall {
	my ($self, $data) = @_;
  
	# check whetever we know where we are
	return 0 unless $mem{category};
	my $category = $mem{category};

	my %conv_table = (
		genres => 'artists',
		artists  => 'albums',
		albums  => 'tracks',
		playlists => 'tracks'
	);  

	# find next category in conversion hash
	if($conv_table{lc $category}) { 
		$mem{category} = $conv_table{lc $category};
		$self->history_add;
		return $self->prepare_memory;
	} elsif($category eq "tracks") { 
		return $self->queueall; # or we can call playall as well
	}

	# else return nothing..
	return 0;
}

sub empty_queue {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my $sql = qq{
		DELETE FROM playlist_current 
		WHERE zone = $self->{zone}->{number};
	};

	return $mc->query($sql);
}

#
# search
#

sub search_add {
	my ($self, $data) = @_;

	#zone:1|screen:library|cmd:search_add|char:[a-z0-9\?\*]

	$data->{char} =~s/\?/|?/;

	$mem{search} .= $data->{char};
	$mem{offset} = 0; # we are changing query completely, so go to the begining
	$self->history_update;
	return $self->prepare_memory;
}

sub search_back {
	my $self = shift;

	return 0 unless defined $mem{search}; # there is no search string..
	# trim
	if($mem{search} =~ /^(.+).$/) {
		$mem{search} = $1;
	} else {
		# last occurance;
		$mem{search} = undef;
	}
	$mem{offset} = 0; # and show the list from begining
	$self->history_update;

	return $self->prepare_memory;
}

sub search_clear {
	my $self = shift;

	$mem{search} = undef;
	$mem{offset} = 0; # and show the list from begining
	$self->history_update;
	return $self->prepare_memory;
}

sub sql_track2playlist {
	my ($self, $pos, $where) = @_;

	return qq {
		REPLACE INTO playlist_current 
		(zone,track_id,track_order) SELECT '$self->{zone}->{number}', id, ($pos+track_num) from track 
		$where 
		ORDER BY album_id, track_num
	};
}

sub sql_playlist2playlist {
	my ($self, $playlist_id) = @_;

	return qq {
		REPLACE INTO playlist_current 
		(zone,track_id,track_order) SELECT '$self->{zone}->{number}', track_id, track_order FROM playlist_track 
		WHERE playlist_id = $playlist_id 
		ORDER BY track_order
	};
}

sub queueall {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my $pos = 0;
	my $rows = $mc->query_and_get("select count(track_id) as total from playlist_current where zone = '$self->{zone}->{number}'")||[];
	my $row = $rows->[0];
	$pos = $row->{total} if $row;

	my $sql = '';
	if(my $tmp = $self->sql_prepare_where) {
		$sql = $self->sql_track2playlist($pos,$tmp);
	} else {
		$sql = $self->sql_track2playlist($pos);
	}

	my $ret = $mc->query($sql);

	# we are playing current playlist
	$mc->query("DELETE FROM zone_mem WHERE zone='$self->{zone}->{number}' AND param='playlist'");

	$pos = 1;
	$rows = $mc->query_and_get("select track_order as pos from playlist_current where zone = '$self->{zone}->{number}' and track_played is not null order by track_order desc limit 1")||[];
	$row = $rows->[0];
	$pos = $row->{pos} if $row;
	my $total = 1;
	$rows = $mc->query_and_get("select count(track_id) as total from playlist_current where zone = '$self->{zone}->{number}'")||[];
	$row = $rows->[0];
	$total = $row->{total} if $row;
	print hash2cmd(
		zone => $self->{zone}->{number},
		cmd => 'transport',
		playlist => $pos.'/'.$total.' - Now Playing'
	);

	return 0;
	# it might be good idea to return anything that show a popup
}

sub playall {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	$self->empty_queue;
	$self->queueall;
	$mc->query("REPLACE INTO zone_mem (zone,param,value) values('$self->{zone}->{number}','state','stop')");

	my $command = $self->{now_play}->play;
	send2player($self->{handle}, $command);

	# play first..
	0;
}        

sub page_next {
	my $self = shift;

	my $c = $mem{category};

	my $total = 0;
	if($c eq 'genres') {
		$total = $self->make_select_no_limit($self->sql_genre($self->sql_prepare_where||''));
	} elsif($c eq 'artists') {
		$total = $self->make_select_no_limit($self->sql_artist_where($self->sql_prepare_where||''));
	} elsif($c eq 'albums') {
		$total = $self->make_select_no_limit($self->sql_album_where($self->sql_prepare_where||''));
        } elsif($c eq 'tracks' && $mem{playlist_id}) {
                $total = $self->make_select_no_limit($self->sql_track_where_num(", playlist_track where playlist_track.track_id = track.id and playlist_track.playlist_id = $mem{playlist_id}"));
                $total = $self->make_select_no_limit($self->sql_track_where_num(", playlist_current where playlist_current.track_id = track.id and playlist_current.zone = '$self->{zone}->{number}'")) if $mem{playlist_id} == -1;
	} elsif($c eq 'tracks') {
		$total = $self->make_select_no_limit($self->sql_track_where($self->sql_prepare_where||''));
	} elsif($c eq 'playlists') {
		$total = $self->make_select_no_limit($self->sql_playlist($self->sql_prepare_where||''));
	}
	$total = (ceil($total / $limit)-1) * $limit;

	if($mem{offset} eq $total) {
		# we are at end, so return without screen redrawing
		$mem{offset} += $limit;
		return $self->page_prev;
	}

	$mem{offset} += $limit;
	if($self->prepare_memory) {
		$self->history_update;
		return 1;
	} else {
		$mem{offset} = $total;   # something went wrong, set to zero ;-)
		return 0;
	} 
}

sub page_prev {
	my $self = shift;

	if($mem{offset} == 0) {
		# we are at begining, so return without screen redrawing
		return 0;
	}
	$mem{offset} -= $limit;
	if($mem{offset} < 0) {
		$mem{offset} = 0;
	}
	if($self->prepare_memory) {
		$self->history_update;
		return 1;
	} else {
		$mem{offset} = 0;   # something went wrong, set to zero ;-)
		return 0;
	}  
}

#
# PLAY functions
#

#
# MENU
#

sub menu_play {
	my ($self, $data) = @_;

	my $mc = $self->mysqlConnection;

	my $line = $data->{line_number};

	my $track = $mem{lines}{$line}{track_id};

	my %trk = $self->{player}->get_fulltrack_info($track);

	# Delete current playlist
	$self->empty_queue;
	# Add all tracks for this album
	my $sql = $self->sql_track2playlist(0,"WHERE album_id in (select album_id from track where id = $track)");
	$mc->query($sql);
	# Set track position in playlist
	$self->{player}->track_mark_played($track,$trk{number});

	$mc->query("update playlist_current set track_played = 1 where zone='$self->{zone}->{number}' and track_order < $trk{number}");

	$mc->query("DELETE FROM zone_mem WHERE zone='$self->{zone}->{number}' AND param='playlist'");

	my $command = $self->{player}->playtrack($track);
	send2player($self->{handle}, $command);

	my %cmd = (
		zone => $self->{zone}->{number},
		cmd  => 'transport',
		playlist => 'Single Song',
		artist => $trk{artist},
		track => $trk{track},
		genre => $trk{genre},
		album => $trk{album}
	);
	print &hash2cmd(%cmd);

	return 0;
}

sub menu_playplaylist {
	my ($self, $data) = @_;

	my $mc = $self->mysqlConnection;

	my $line = $data->{line_number};
	return 0 unless exists $mem{lines}{$line}{playlist_id};

	$mem{playlist_id} = $mem{lines}{$line}{playlist_id};

	my $sql = "REPLACE INTO zone_mem (zone,param,value) VALUES ('$self->{zone}->{number}', 'playlist', '$mem{playlist_id}')";
	$mc->query($sql);

	# check, whether we'd like to change or do any other command!
	$mem{offset} = 0;
	$mem{search} = undef;
	$mem{category}  = 'tracks';

	unless($mem{playlist_id} == -1) {
		$self->empty_queue;
		$sql = $self->sql_playlist2playlist($mem{playlist_id});
		my $ret = $mc->query($sql);
		my $command = $self->{now_play}->play;
		send2player($self->{handle}, $command);
	}

	$self->history_add;

	# instead calling:  return &prepare_memory();
	# we'll trick the program, so it''ll draw empty screen when there are no records
	$self->prepare_memory;

	return 1;
}

sub menu_select {
	my ($self, $data) = @_;

	# we must meet all these conditions:
	return 0 unless (exists $data->{line_number});  # have we received line number?
	my $line = $data->{line_number};
	return 0 unless (exists $mem{lines}{$line}{cmd});  # does this line contain any data?
	my $cmd = $mem{lines}{$line}{cmd};

	if($menu_commands->{lc $cmd}) {
		my $method = $menu_commands->{lc $cmd};
		return eval "\$self->$method(\$data)";
	} else {
		warn "Unknown library/menu command: $cmd\n"
	}

	return 0;
}

sub menu_change {
	my ($self, $data) = @_;

	my $line = $data->{line_number};
	# check, whether we'd like to change or do any other command!
	$mem{offset} = 0;
	$mem{search} = undef;
	$mem{category}  = $mem{lines}{$line}{category};
	$mem{genre_id}  = $mem{lines}{$line}{genre_id}  if (exists $mem{lines}{$line}{genre_id});
	$mem{artist_id} = $mem{lines}{$line}{artist_id} if (exists $mem{lines}{$line}{artist_id});
	$mem{album_id}  = $mem{lines}{$line}{album_id}  if (exists $mem{lines}{$line}{album_id});

	$self->history_add;

	# instead calling:  return &prepare_memory();
	# we'll trick the program, so it''ll draw empty screen when there are no records
	$self->prepare_memory;

	return 1;  
}

sub back {
	my $self = shift;

	if($self->history_back) {
		return $self->prepare_memory;
	} else {
		return 0;
	}
}
 
#
# main program
#

sub prepare_memory {
	my $self = shift;

	return 0 unless $mem{category};

	my $c = $mem{category};

	if($c eq 'genres') {
		return $self->select_genres;
	} elsif($c eq 'artists') {
		return $self->select_artists;
	} elsif($c eq 'albums') {
		return $self->select_albums;
	} elsif($c eq 'tracks' && $mem{playlist_id}) {
		return $self->select_playlist_tracks;
		return 0;
	} elsif($c eq 'tracks') {
		return $self->select_tracks;
		return 0;
	} elsif($c eq 'playlists') {
		return $self->select_playlists;
	}

	return 0;
}

sub process {
	my ($self, $data) = @_;

###################################################################################
  # we are computers so we start at 0 instead at 1 like humans.
  # FIX IN CRESTRON INSTEAD
  $data->{line_number}--  if $data->{line_number};
###################################################################################  

	if($commands->{lc $data->{cmd}}) {  # Call function
		my $method = $commands->{lc $data->{cmd}};
		if(eval "\$self->$method(\$data)") {
			my %data_out = $self->get_response;
			$data_out{zone} = $self->{zone}->{number};
			print &hash2cmd(%data_out);  # print response
		}
	} else {
		qlog WARNING, "Unknown library command: $data->{cmd}";
	}

	return ();
}
           
1;
