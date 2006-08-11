#$Id: album.pm,v 1.12 2006/08/11 20:46:46 toby Exp $

package CMMS::Database::album;

=head1 NAME

CMMS::Database::album

=head1 SYNOPSIS

  use CMMS::Database::album;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use base qw( CMMS::Database::Object );

our $VERSION = sprintf '%d.%03d', q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/;

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
  my $self = new CMMS::Database::Object( $dbInterface, "album", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "album",
    tag => "album",
    title => "Album",
    title_field => "name",
    display => [ "id", "name", "discid", "year", "comment", "cover", "artist_id", "genre_id"  ],
    list_display => [ "name", "cover",  ],
    tagorder => [ "id", "discid", "name", "year", "comment", "cover",  ],
    tagrelationorder => [ ],
    relationshiporder => [ "track" ],
    no_broadcast => 1,
    no_clone => 1,
    no_create => 1,
    elements => {
            'id' => {
	        type => "int",
		tag  => "Id",
		title => "Id",
		primkey => 1,
		displaytype => "hidden",
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
		mandatory => 1,
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
            'discid' => {
	        type => "varchar",
		tag  => "Discid",
		title => "Disc-ID",
		displaytype => "readonly",
		no_search => 1,
            },
            'name' => {
	        type => "varchar",
		tag  => "Name",
		title => "Name",
		size => 80,
		maxsize => 255,
		mandatory => 1,
            },
            'year' => {
	        type => "varchar",
		tag  => "Year",
		title => "Year",
            },
            'comment' => {
	        type => "text",
		tag  => "Comment",
		title => "Comment",
		width => 80,
		height => 16,
		no_search => 1,
            },
            'cover' => {
	        type => "varchar",
	        size => 64,
	        maxsize => 255,
		tag  => "Cover",
		title => "Cover image",
		upload => 1,
		upload_fn => "upload_resizer", 
		upload_parameters => {
		    sizes => [
			{ field=>"cover", widest=>"160", suffix=>"fs_" },
#			{ field=>"minisize_url", wfield=>"minisize_x", hfield=>"minisize_y", suffix => "tn_", widest=>"220", },
#			{ field=>"microsize_url", wfield=>"microsize_x", hfield=>"microsize_y", suffix=>"ms_", widest=>"100" },     
		    ]
		},
		help => "Click on the browse button to pick a picture from your local disk or enter an image URL into the space provided.",
		displaytype => "image",
		no_search => 1,
            },

    },
    relationships => {
	'track' => {
	    type => "one2many",
	    localkey => "id",
	    foreignkey => "album_id",
	    title => "Track(s)",
	    tag => "track",
	    display => [
	    		{ col => "artist_id", title => "Artist" },
	    		{ col => "genre_id", title => "Genre" },
	    		{ col => "title", title => "Title" },
	    		{ col => "track_num", title => "Track No." },
	    		{ col => "length_seconds", title => "Length" },
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
track.*,
album.name as album_id,
artist.name as artist_id,
genre.name as genre_id
EndSelects
    ;

    my $tables = <<EndTables
track,
album,
artist,
genre
EndTables
    ;

    my $where = <<EndWhere
track.album_id = $id
and album.id = track.album_id
and artist.id = track.artist_id
and genre.id = track.genre_id
order by track.track_num
EndWhere
    ;

    return $self->get_list( "track", $page, $size, { tables=>$tables, select => $selects, where => $where } );
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

