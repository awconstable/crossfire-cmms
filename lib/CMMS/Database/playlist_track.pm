#$Id: playlist_track.pm,v 1.9 2006/07/03 14:50:54 byngmeister Exp $

package CMMS::Database::playlist_track;

=head1 NAME

CMMS::Database::playlist_track

=head1 SYNOPSIS

  use CMMS::Database::playlist_track;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use base qw( CMMS::Database::Object );

our $VERSION = sprintf '%d.%03d', q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/;

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
  my $self = new CMMS::Database::Object( $dbInterface, "playlist_track", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "playlist_track",
    tag => "playlist_track",
    title => "playlist_track",
    display => [ "id", "playlist_id", "track_id", "track_order",  ],
    list_display => [ "id", "playlist_id", "track_id", "track_order",  ],
    tagorder => [ "id", "playlist_id", "track_id", "track_order",  ],
    tagrelationorder => [ ],
    relationshiporder => [ "track_data" ],
    no_broadcast => 1,
    no_clone => 1,
    elements => {
            'id' => {
	        type => "int",
		tag  => "Id",
		title => "Id",
		primkey => 1,
		displaytype => "hidden",

            },
            'playlist_id' => {
	        type => "int",
		tag  => "Playlist",
		title => "Playlist",
		primkey => 1,
		lookup => {
		    table => "playlist",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		},

            },
            'track_id' => {
	        type => "int",
		tag  => "Track",
		title => "Track",
		lookup => {
		    table => "track",
		    keycol => "id",
		    valcol => "title",
		    none => "NULL",
		    read_only => 1,
		},

            },
            'track_order' => {
	        type => "int",
		tag  => "Track_order",
		title => "Track_order",
		primkey => 1,

            },

    },
    relationships => {
	'track_data' => {
	    type => "one2many",
	    localkey => "track_id",
	    foreignkey => "track_id",
	    title => "Track data",
	    tag => "track_data",
	    display => [
	    		{ col => "file_location", title => "File location" },
	    		{ col => "file_name", title => "Filename" },
	    		{ col => "file_type", title => "Type" },
	    		{ col => "bitrate", title => "Bitrate" },
	    		{ col => "filesize", title => "Size" },
	    		{ col => "info_source", title => "Meta Source" },
			],
	    list_method => 'get_track_list'
	}
    },
  });

  # Return object
  #
  return $self;
}

sub get_self {
    my $self = shift;
    my $page = shift;
    my $size = shift;
    my $extras = shift;

    $extras = "1=1" unless $extras;

    my $selects = <<EndSelects
playlist_track.*,
playlist.name as playlist_id,
track.name as track_id
EndSelects
    ;

    my $tables = <<EndTables
playlist_track,
playlist,
track
EndTables
    ;

    my $where = <<EndWhere
$extras
and playlist.id = playlist_track.playlist_id
and track.id = playlist_track.track_id
EndWhere
    ;

    return $self->get_list( "playlist_track", $page, $size, { tables=>$tables, select => $selects, where => $where } );
}

sub get_track_list {
    my ($self,$page,$size) = @_;

    my $id = $self->get('track_id');

    my $selects = <<EndSelects
track_data.*,
track.name as track_id
EndSelects
    ;

    my $tables = <<EndTables
track_data,
track
EndTables
    ;

    my $where = <<EndWhere
track.id = $id
and track.id = track_data.track_id
EndWhere
    ;

    return $self->get_list( "track_data", $page, $size, { tables=>$tables, select => $selects, where => $where } );
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

