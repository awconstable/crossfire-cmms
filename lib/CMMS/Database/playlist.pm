#$Id: playlist.pm,v 1.13 2007/02/06 16:53:41 byngmeister Exp $

package CMMS::Database::playlist;

=head1 NAME

CMMS::Database::playlist

=head1 SYNOPSIS

  use CMMS::Database::playlist;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use base qw( CMMS::Database::Object );
use CMMS::Database::playlist_track;

our $VERSION = sprintf '%d.%03d', q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/;

#==============================================================================
# CLASS METHODS
#==============================================================================
sub new {
  my $that = shift;
  my $class = ref( $that ) || $that;
  my $dbInterface = shift;
  my $id = shift;
  
  # Create the object
  #
  my $self = new CMMS::Database::Object( $dbInterface, "playlist", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "playlist",
    tag => "playlist",
    title => "Play list",
    title_field => "name",
    display => [ "id", "name",  ],
    list_display => [ "name", ],
    tagorder => [ "id", "name",  ],
    tagrelationorder => [ ],
    relationshiporder => [ ],
    no_broadcast => 1,
    no_clone => 1,
    event_post_save => "event_post_save",
    event_force_save => "event_force_save",
    multiview => {
        order => [ "TrackList" ],
        views => {
	    'TrackList' => {
		display => [ "id", "name",  ],
		include => "playlist-tracklist.ehtm",
		title => "Play List",
	    },
	},
    },
    default_view => "TrackList",
    order_by => 'name',
    elements => {
            'id' => {
	        type => "int",
		tag  => "Id",
		title => "Id",
		primkey => 1,
		displaytype => "hidden",

            },
            'name' => {
	        type => "varchar",
		tag  => "Name",
		title => "Name",
		size => 40,
		maxsize => 64,
		mandatory => 1,
		description => "Please enter a name for the playlist so that you can identify at a later date.",
		defaultvalue => "Untitled",
            },

    },
    relationships => {
	'playlist_track' => {
	    type => "one2many",
	    localkey => "id",
	    foreignkey => "playlist_id",
	    title => "Track(s)",
	    tag => "playlist_track",
	    position_field => "track_order",
	    position => 1,
	    no_clone => 1,
	    order_by => 'track_order',
	    display => [
	    		{ col => "track_id", title => "Track" },
	    		{ col => "track_order", title => "Order" },
			],
	    list_method => 'get_track_list'
	}
    },
  });

  # Return object
  #
  return $self;
}

sub get_track_list {
    my ($self,$page,$size) = @_;

    my $id = $self->get('id');

    my $selects = <<EndSelects
playlist_track.*,
playlist.name as playlist_id,
track.title as track_id
EndSelects
    ;

    my $tables = <<EndTables
playlist_track,
playlist,
track
EndTables
    ;

    my $where = <<EndWhere
playlist.id = $id
and playlist.id = playlist_track.playlist_id
and track.id = playlist_track.track_id
order by playlist_track.track_order
EndWhere
    ;

    return $self->get_list( "playlist_track", $page, $size, { tables=>$tables, select => $selects, where => $where } );
}

sub add_track {
    my( $self, $track_id ) = @_;
    my $mc = $self->mysqlConnection();
    my $id = $self->get("id");

    my $position = $mc->enum_lookup("playlist_track","playlist_id", "MAX(track_order)", $id ) || 1;

    my $plt = new CMMS::Database::playlist_track($mc);
    $plt->set("playlist_id",$id);
    $plt->set("track_id", $track_id);
    $plt->set("track_order", $position + 1);
    $plt->push();
}

sub add_album {
    my( $self, $album_id ) = @_;
    my $mc = $self->mysqlConnection();

    my $tracks = $mc->query_and_get("SELECT id FROM track WHERE album_id=".$mc->quote($album_id)." ORDER BY track_num");

    foreach my $t ( @{$tracks} ) {
	$self->add_track($t->{id});
    }
}

sub event_post_save {
    my( $self, $ui ) = @_;
    my $cgi = $ui->cgi();
    my $view = $ui->view();

    my $mc = $self->mysqlConnection();

    if( $view eq "TrackList" ) {
	my $playlist = $cgi->param("playlistv");

	if( $cgi->param("button_addalbum.x") ) {
            my $album_id = $cgi->param("plt_album_id");
	    $album_id and $self->add_album($album_id);

	    print STDERR "Adding album $album_id\n";

	}
	elsif( $cgi->param("button_addtrack.x") ) {
            my $track_id = $cgi->param("plt_track_id");	    
	    $track_id and $self->add_track($track_id);

	    print STDERR "Adding track $track_id\n";
	}

	
	if( $playlist ) {
	    my @elements = split('&',$playlist);
	    
	    my $p = 1;

	    foreach my $e ( @elements ) {
		my($dummy,$id) = split("=",$e);

		my $q_id = $mc->quote($id);
		my $q_p = $mc->quote($p);

		my $q = $mc->query("UPDATE playlist_track SET track_order=$q_p WHERE id=$q_id");

		print STDERR "UPDATE playlist_track SET track_order=$q_p WHERE id=$q_id\n";

		$q->finish;

		$p++;
	    }
	}

    }
}

sub event_force_save {
  my( $self,$ui ) = @_;
  my $cgi = $ui->cgi();
  
  if( $cgi->param("button_addalbum.x") ) {
      return 1;
  }
      
  if( $cgi->param("button_addtrack.x") ) {
      return 1;
  }
      
  return 0;
}

1;

__END__

=head1 SEE ALSO

L<TAER::Object(3pm)>

=head1 AUTHOR

Generated from TAER::Object::Template version 1.007 by taer_build_objects.

=head1 COPYRIGHT

Copyright (c) 2006 Coreware Limited. England.  All rights reserved.

You must obtain a written license to use this software.

=cut

