#$Id: track.pm,v 1.2 2006/06/27 14:32:36 byngmeister Exp $

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

our $VERSION = sprintf '%d.%03d', q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

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

            },
            'album_id' => {
	        type => "int",
		tag  => "Album",
		title => "Album",
		lookup => {
		    table => "Album",
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
		    table => "Artist",
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
		    table => "Genre",
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
	        type => "smallint",
		tag  => "Track_num",
		title => "Track_num",

            },
            'length_seconds' => {
	        type => "int",
		tag  => "Length_seconds",
		title => "Length_seconds",

            },
            'ctime' => {
	        type => "timestamp",
		tag  => "Ctime",
		title => "Ctime",

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

