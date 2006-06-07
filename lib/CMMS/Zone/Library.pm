package CMMS::Zone::Library;

use strict;
use Storable qw(freeze thaw);
use CMMS::Zone::Player;
use CMMS::Zone::NowPlaying;

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

my %commands = (
    list        => \&list,
    page_prev   => \&page_prev,
    page_next   => \&page_next,
    menu_select => \&menu_select,
    back	=> \&back,
    selectall   => \&selectall,
    queueall	=> \&queueall,
    playall	=> \&playall,
    search_add	=> \&search_add,
    search_back => \&search_back,
    search_clear=> \&search_clear,
);

my %menu_commands = (
    change      => \&menu_change,
    play        => \&menu_play,
    playplaylist=> \&menu_playplaylist,
);

#
# initialisation & defaults
#

sub init {
  $dbh = shift;
  &mem_reset;
}

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
  print STDERR "HISTORY: Empty\n";
  @history = ();
}

sub history_back {
  if (@history > 1) {
  print STDERR "HISTORY: back\n";
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
  print STDERR "HISTORY: add\n";
  return push @history, &freeze(\%mem);
}

sub history_update {
  print STDERR "HISTORY: update\n";
  pop @history; # if (@history > 1); # we can add another step to go at beginning of list
  &history_add();
}
  

#
# support functions
#

sub get_lines {
  my @namelist;
  my $i;
  for ($i = 0; $i<$limit; $i++) {
    if ( exists $mem{lines}{$i}{text} ) {
      $namelist[$i] = $mem{lines}{$i}{text};
    } else {
      $namelist[$i] = EMPTY_ROW; # "--"
    }
  }
 return join SEP_LINES, @namelist;
}

sub get_response {
  my %cmd = (
     cmd  => "library",
     category => $mem{category},
     lines => &get_lines
  );
  return %cmd;
}

sub make_select {
  my ($query) = @_;

  $query =~ s/\?/%d/g;
  $query = sprintf($query, $limit, $mem{offset});
  my $sth;
  $sth = db_select($dbh, $query);

  my @row;
  $mem{lines} = ();
  my $i = 0;
  while ( @row = $sth->fetchrow_array ) {
      $mem{lines}{$i}{id}   = $row[0];
      $mem{lines}{$i}{text} = $row[1];
      $i++;
  }
  return $i;
}

sub sql_prepare_where {
  my @where;
  my $i = 0;
  push (@where, sprintf("genre_id=%d",  $mem{genre_id} )) if ($mem{genre_id} );
  push (@where, sprintf("artist_id=%d", $mem{artist_id})) if ($mem{artist_id});
  push (@where, sprintf("album_id=%d",  $mem{album_id} )) if ($mem{album_id} );
  
  # to make it SQL compliant LIKE comman can also be used, however 
  # regualar expressions are more powerfull, so i'll use them instead.
  if ($mem{search}) {
    my $search_column = "name";
       $search_column = "title" if ($mem{category} eq "tracks");
    my $search_regexp = $mem{search};
    push (@where, sprintf("%s ~* '^%s'", $search_column, $search_regexp));
  }
  
  #    = $mem{lines}{$line}{genre}  if (exists $mem{lines}{$line}{genre});
  if (@where) {
    return "WHERE " . join(" AND ", @where);
  }
  return 0;
}

#
# individual selects & package commands
#

sub sql_genre {
  my ($where) = @_;
  $where = "" unless $where;
  return qq{
	SELECT g.id, g.name 
	FROM genre g 
	RIGHT JOIN track t ON g.id=t.genre_id
	$where
	GROUP BY g.id, g.name
	ORDER BY g.name
	LIMIT ? OFFSET ?
  };
}

sub select_genres {
  my $q = &sql_genre(&sql_prepare_where());
  my $rows = &make_select($q);
  if ($rows > 0) {
      for (my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{genre_id} = $id;
          $mem{lines}{$i}{cmd} = "change";
          $mem{lines}{$i}{category} = "artists";
      }
      return 1;
  } else {
      return 0;
  }
}

sub sql_artist_plain {
  return qq{SELECT id, name FROM artist ORDER BY name LIMIT ? OFFSET ?};
}

sub sql_artist_where {
  my ($where) = @_;
  return qq{
         SELECT artist_id, a.name
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
     SELECT id, name 
     FROM album 
     ORDER BY name 
     LIMIT ? OFFSET ?};
}

sub sql_album_where {
  my ($where) = @_;
  return qq{
         SELECT album_id, a.name
         FROM track t
         LEFT JOIN album a ON t.album_id = a.id
         $where
         GROUP BY album_id, a.name
         ORDER by a.name
         LIMIT ? OFFSET ? 
  };
}

sub sql_track_where_by_id {
  my ($where) = @_;                                  
  return qq{
         SELECT id, track_num || '. ' || title
         FROM track 
         $where
         ORDER BY track_num
         LIMIT ? OFFSET ?
  };
}   
                                                   
sub sql_track_where {
  my ($where) = @_;
  return qq{
         SELECT id, title
         FROM track 
         $where
         ORDER BY title
         LIMIT ? OFFSET ? 
  };
}
sub select_artists {
  my $q = "";
  if (my $tmp = &sql_prepare_where) {
      $q = &sql_artist_where ($tmp);
  } else {
      $q = &sql_artist_plain;
  }
  
  my $rows = &make_select($q);
  if ($rows > 0) {
      for (my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{artist_id} = $id;
          $mem{lines}{$i}{cmd} = "change";
          $mem{lines}{$i}{category} = "albums";
      }
      return 1;
  } else {
      return 0;
  }
}

sub select_albums {
  my $q = "";
  if (my $tmp = &sql_prepare_where) {
      $q = &sql_album_where ($tmp);
  } else {
      $q = &sql_album_plain;
  }
  
  my $rows = &make_select($q);
  if ($rows > 0) {
      for (my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{album_id} = $id;
          $mem{lines}{$i}{cmd} = "change";
          $mem{lines}{$i}{category} = "tracks";
      }
      return 1;
  } else {
      return 0;
  }
}

sub select_tracks {
  my $q = "";
  if (my $tmp = &sql_prepare_where) {
      if ($mem{album}) { 
          $q = &sql_track_where_by_id($tmp);
      } else {
          $q = &sql_track_where ($tmp);
      }
  } else {
      $q = &sql_track_where ("");
  }
  
  my $rows = &make_select($q);
  if ($rows > 0) {
      for (my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{track_id} = $id;
          $mem{lines}{$i}{cmd} = "play";
      }
      return 1;
  } else {
      return 0;
  }
}

sub sql_playlist {
  my ($where) = @_;
  $where = "" unless $where;
  return qq{
	SELECT id, name 
	FROM playlist 
	$where
	ORDER BY name
	LIMIT ? OFFSET ?
  };
}

sub select_playlists {
  my $q = &sql_playlist(&sql_prepare_where());
  
  my $rows = &make_select($q);
  if ($rows > 0) {
      for (my $i = 0; $i<$rows; $i++) {
          my $id = $mem{lines}{$i}{id};
          $mem{lines}{$i}{playlist_id} = $id;
          $mem{lines}{$i}{cmd} = "playplaylist";
          $mem{lines}{$i}{category} = "playlists";
      }
      return 1;
  } else {
      return 0;
  }
}


#
# commands implementation
#

# new list request
sub list {
  my ($data) = @_;
  &mem_reset();
  $mem{category} = $data->{category};
  &history_empty();
  &history_add();
  return &prepare_memory();
}

sub selectall {
  my ($data) = @_;
  
  # check whetever we know where we are
  return 0 unless $mem{category};
  my $category = $mem{category};

  # &mem_reset(); # we just changing category with same constraints
  my %conv_table = (
    genres => "artists",
               artists  => "albums",
                            albums  => "tracks",
    playlists => "tracks"
  );  
  
  # find next category in conversion hash
  if ($conv_table{lc $category}) { 
     $mem{category} = $conv_table{lc $category};
     #&history_empty();
     &history_add();
     return &prepare_memory();
  } elsif ($category eq "tracks") { 
     return &queueall; # or we can call playall as well
  }

  # else return nothing..
  return 0;
}

sub empty_queue {
    my $q = qq{
      DELETE FROM playlist_current
      WHERE zone = $zone;
  };
  
  my $ret = db_query($dbh, $q);
  return $ret;
}

#
# search
#

sub search_add {
  my ($data) = @_;
  #zone:1|screen:library|cmd:search_add|char:[a-z0-9\?\*]
  $mem{search} .= $data->{char};
  $mem{offset} = 0; # we are changing query completely, so go to the begining
  &history_update();
  return &prepare_memory();
}

sub search_back {
  return 0 unless defined $mem{search}; # there is no search string..
  # trim
  if ($mem{search} =~ /^(.+).$/) {
     $mem{search} = $1;
  } else {
     # last occurance;
     $mem{search} = undef;
  }
  $mem{offset} = 0; # and show the list from begining
  &history_update();
  return &prepare_memory();
}

sub search_clear {
  $mem{search} = undef;
  $mem{offset} = 0; # and show the list from begining
  &history_update();
  return &prepare_memory();
}

sub sql_track2playlist {
  my ($where) = @_;
  return qq {
    INSERT INTO playlist_current 
    SELECT $zone, id from track
    $where
    ORDER BY album_id, track_num;
  };
}

sub sql_playlist2playlist {
  my ($zone, $playlist_id) = @_;
  return qq {
    INSERT INTO playlist_current 
    SELECT $zone, track_id FROM playlist_track
    WHERE playlist_id = $playlist_id
    ORDER BY track_order
  };
}

sub queueall {
  my $q = "";
  if (my $tmp = &sql_prepare_where) {
     $q = &sql_track2playlist($tmp);
  } else {
     $q = &sql_track2playlist("");
  }    
  
  my $ret = db_query($dbh, $q);
  
  # we are playing current playlist
  zone_mem_del($dbh, $zone, 'playlist');
    
  return 0;
  # it might be good idea to return anything that show
  # an popup
}

sub playall {
 &empty_queue;
 &queueall;

 my $command = zone::now_playing::play();
 send2player($handle, $command);
 
 # play first..
 0;
}        

sub page_next {
  my $last_offset = $mem{offset};
  $mem{offset} += $limit;
  if (&prepare_memory) {
      &history_update();
      return 1;
  } else {
      $mem{offset} = $last_offset;
      return 0;
  }
}

sub page_prev {
  if ($mem{offset} == 0) { return 0; } # we are at begining, so return without screen redrawing
  $mem{offset} -= $limit;
  if ($mem{offset} < 0) { $mem{offset} = 0; }
  if (&prepare_memory) {
      &history_update();
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
  my ($data) = @_;
  my $line = $data->{line_number};
  
  my $track = $mem{lines}{$line}{track_id};
  my $command = zone::player::playtrack($dbh, $track);
  send2player($handle, $command);
  my %cmd = (
     zone => $zone,
     cmd  => "transport",
     playlist => "Single Song"
  );
  print &hash2cmd(%cmd);
}

sub menu_playplaylist {
  my ($data) = @_;
  my $line = $data->{line_number};
  return 0 unless exists $mem{lines}{$line}{playlist_id};

  &empty_queue;

  $mem{playlist_id} = $mem{lines}{$line}{playlist_id};
  
  my $q = sql_playlist2playlist( $zone, $mem{playlist_id} ); 
  my $ret = db_query($dbh, $q);

  # it would be better to put it in status command, when we start playing.
  # however for that we have to share memory..
  #&show_playlist($mem{playlist});
  # ........... so i did.
  # and we must do it before playing, so we will se playlist on screen ;)
  &zone_mem_set($dbh, $zone, 'playlist', $mem{playlist_id});

  my $command = zone::now_playing::play();
  send2player($handle, $command);
  
  return 0;
}

sub menu_select {
  my ($data) = @_;
  # we must meet all these conditions:
  return 0 unless (exists $data->{line_number});  # have we received line number?
               my $line = $data->{line_number};
  return 0 unless (exists $mem{lines}{$line}{cmd});  # does this line contain any data?
                my $cmd = $mem{lines}{$line}{cmd};
  if ($menu_commands{lc $cmd}) { 
      return $menu_commands{lc $cmd}->($data) 
  } else { warn "Unknown library/menu command: $cmd\n" }
  return 0;
}

sub menu_change {
  my ($data) = @_;
  my $line = $data->{line_number};
  # check, whether we'd like to change or do any other command!
  $mem{offset} = 0;
  $mem{search} = undef;
  $mem{category}  = $mem{lines}{$line}{category};
  $mem{genre_id}  = $mem{lines}{$line}{genre_id}  if (exists $mem{lines}{$line}{genre_id});
  $mem{artist_id} = $mem{lines}{$line}{artist_id} if (exists $mem{lines}{$line}{artist_id});
  $mem{album_id}  = $mem{lines}{$line}{album_id}  if (exists $mem{lines}{$line}{album_id});
 
  &history_add();
 
  # instead calling:  return &prepare_memory();
  # we'll trick the program, so it''ll draw empty screen when there are no records
  &prepare_memory();
  return 1;  
}



sub back {
  if (&history_back()) {
      return &prepare_memory();
  } else {
      return 0;
  }
}
 
#
# main program
#

sub prepare_memory {
 return 0 unless $mem{category};

 my $c = $mem{category};
 if ($c eq "genres") {
   return &select_genres();
 } elsif ($c eq "artists") {
   return &select_artists();
 } elsif ($c eq "albums") {
   return &select_albums();
 } elsif ($c eq "tracks") {
   return &select_tracks();
   return 0;
 } elsif ($c eq "playlists") {
   return &select_playlists();
 }
 return 0;
}

sub process {
  my ($data) = @_;
  
###################################################################################
  # we are computers so we start at 0 instead at 1 like humans.
  # FIX IN CRESTRON INSTEAD
  $data->{line_number}--  if $data->{line_number};
###################################################################################  

  if ($commands{lc $data->{cmd}}) {  # Call function 
      if ($commands{lc $data->{cmd}}->($data)) {
         my %data_out = &get_response();
         $data_out{zone} = $zone;
         print &hash2cmd(%data_out);  # print response
      }      
  } else { print STDERR "Unknown library command: $data->{cmd}\n" }

  return ();
}
           
1;
