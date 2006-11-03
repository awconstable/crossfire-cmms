#$Id: artist.pm,v 1.13 2006/11/03 15:10:57 byngmeister Exp $

package CMMS::Database::artist;

=head1 NAME

CMMS::Database::artist

=head1 SYNOPSIS

  use CMMS::Database::artist;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use base qw( CMMS::Database::Object );

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
  my $self = new CMMS::Database::Object( $dbInterface, "artist", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "artist",
    tag => "artist",
    title => "artist",
    display => [ "id", "name",  ],
    list_display => [ "name"  ],
    tagorder => [ "id", "name",  ],
    tagrelationorder => [ ],
    relationshiporder => [ "album", "track" ],
    no_broadcast => 1,
    no_clone => 1,
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

            },

    },
    relationships => {
	'album' => {
	    type => "one2many",
	    localkey => "id",
	    foreignkey => "artist_id",
	    title => "Album(s)",
	    tag => "album",
	    order_by => 'name',
	    display => [
	    		{ col => "artist_id", title => "Artist" },
	    		{ col => "composer_id", title => "Composer" },
	    		{ col => "conductor_id", title => "Conductor" },
	    		{ col => "genre_id", title => "Genre" },
	    		{ col => "name", title => "Name" },
			],
	    list_method => 'get_album_list'
	},
	'track' => {
	    type => "one2many",
	    localkey => "id",
	    foreignkey => "artist_id",
	    title => "Track(s)",
	    tag => "track",
	    order_by => 'title',
	    display => [
	    		{ col => "artist_id", title => "Artist" },
	    		{ col => "composer_id", title => "Composer" },
	    		{ col => "conductor_id", title => "Conductor" },
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

sub get_album_list {
    my ($self,$page,$size) = @_;

    my $id = $self->get('id');

    my $selects = <<EndSelects
album.*,
artist.name as artist_id,
composer.name as composer_id,
conductor.name as conductor_id,
genre.name as genre_id
EndSelects
    ;

    my $tables = <<EndTables
album,
artist,
genre
LEFT JOIN composer ON album.composer_id = composer.id
LEFT JOIN conductor ON album.conductor_id = conductor.id
EndTables
    ;

    my $where = <<EndWhere
album.artist_id = $id
and artist.id = album.artist_id
and genre.id = album.genre_id
order by album.name
EndWhere
    ;

    return $self->get_list( "track", $page, $size, { tables=>$tables, select => $selects, where => $where } );
}

sub get_track_list {
    my ($self,$page,$size) = @_;

    my $id = $self->get('id');

    my $selects = <<EndSelects
track.*,
album.name as album_id,
artist.name as artist_id,
composer.name as composer_id,
conductor.name as conductor_id,
genre.name as genre_id
EndSelects
    ;

    my $tables = <<EndTables
track,
album,
artist,
genre
LEFT JOIN composer ON track.composer_id = composer.id
LEFT JOIN conductor ON track.conductor_id = conductor.id
EndTables
    ;

    my $where = <<EndWhere
track.artist_id = $id
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

