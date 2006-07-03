#$Id: track.pm,v 1.7 2006/07/03 14:15:14 byngmeister Exp $

package CMMS::Database::track;

=head1 NAME

CMMS::Database::track

=head1 SYNOPSIS

  use CMMS::Database::track;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use base qw( CMMS::Database::Object );

our $VERSION = sprintf '%d.%03d', q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/;

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
  my $self = new CMMS::Database::Object( $dbInterface, "track", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "track",
    tag => "track",
    title => "track",
    display => [ "id", "album_id", "artist_id", "genre_id", "title", "track_num", "length_seconds", "ctime", "comment", "year", "composer",  ],
    list_display => [ "id", "album_id", "artist_id", "genre_id", "title", "track_num", "length_seconds", "ctime", "comment", "year", "composer",  ],
    tagorder => [ "id", "album_id", "artist_id", "genre_id", "title", "track_num", "length_seconds", "ctime", "comment", "year", "composer",  ],
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
            'album_id' => {
	        type => "int",
		tag  => "Album",
		title => "Album",
		lookup => {
		    table => "album",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		},

            },
            'artist_id' => {
	        type => "int",
		tag  => "Artist",
		title => "Artist",
		lookup => {
		    table => "artist",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		},

            },
            'genre_id' => {
	        type => "int",
		tag  => "Genre",
		title => "Genre",
		lookup => {
		    table => "genre",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		},

            },
            'title' => {
	        type => "varchar",
		tag  => "Title",
		title => "Title",

            },
            'track_num' => {
	        type => "int",
		tag  => "Track_num",
		title => "Track_num",

            },
            'length_seconds' => {
	        type => "int",
		tag  => "Length_seconds",
		title => "Track length",

            },
            'ctime' => {
	        type => "datetime",
		tag  => "Ctime",
		title => "Created time",

            },
            'comment' => {
	        type => "text",
		tag  => "Comment",
		title => "Comment",

            },
            'year' => {
	        type => "varchar",
		tag  => "Year",
		title => "Year",

            },
            'composer' => {
	        type => "varchar",
		tag  => "Composer",
		title => "Composer",

            },

    },
    relationships => {
	'track_data' => {
	    type => "one2many",
	    localkey => "id",
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
track.*,
album.name as album_id,
arist.name as aritst_id,
genre.name as genre_id
EndSelects
    ;

    my $tables = <<EndTables
track,
album,
arist,
genre
EndTables
    ;

    my $where = <<EndWhere
$extras
and album.id = track.album_id
and arist.id = track.arist_id
and genre.id = track.genre_id
EndWhere
    ;

    my $res = $self->get_list( "zone_mem", $page, $size, { tables=>$tables, select => $selects, where => $where } );

    return $res;

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

