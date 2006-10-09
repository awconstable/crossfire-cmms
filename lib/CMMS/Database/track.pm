#$Id: track.pm,v 1.24 2006/10/09 08:45:14 byngmeister Exp $

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
use MP3::Tag;

our $VERSION = sprintf '%d.%03d', q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/;

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
    title => "Track",
    title_field => "title",
    display => [ "id", "track_num", "artist_id", "composer_id", "conductor_id", "album_id", "title", "genre_id", "length_seconds", "comment", "year", "ctime"  ],
    list_display => [ "artist_id", "album_id", "composer_id", "conductor_id", "title", "genre_id", ],
    tagorder => [ "id", "album_id", "artist_id", "composer_id", "conductor_id", "genre_id", "title", "track_num", "length_seconds", "ctime", "comment", "year"  ],
    tagrelationorder => [ ],
    relationshiporder => [ "track_data" ],
    no_broadcast => 1,
    no_clone => 1,
    no_create => 1,
    order_by => 'title',
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
		mandatory => 1,
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
            'composer_id' => {
	        type => "int",
		tag  => "Composer",
		title => "Composer",
		lookup => {
		    table => "composer",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		}
            },
            'conductor_id' => {
	        type => "int",
		tag  => "Conductor",
		title => "Conductor",
		lookup => {
		    table => "conductor",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		}
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
		size => 80,
		maxsize => 255,
		mandatory => 1,
            },
            'track_num' => {
	        type => "int",
		tag  => "Track_num",
		title => "Track number",
		displaytype => "readonly",
		no_search => 1,
            },
            'length_seconds' => {
	        type => "int",
		tag  => "Length_seconds",
		title => "Track length",
		displaytype => "readonly",
		suffix => "seconds",
		no_search => 1
            },
            'ctime' => {
	        type => "datetime",
		tag  => "Ctime",
		title => "Created time",
		displaytype => "hidden",
		no_search => 1,
            },
            'comment' => {
	        type => "text",
		tag  => "Comment",
		title => "Comment",
		width => 80,
		height => 4,
		no_search => 1,
            },
            'year' => {
	        type => "varchar",
		tag  => "Year",
		title => "Year",
		size => 4,
		maxsize => 4,
            }

    },
    relationships => {
	'track_data' => {
	    type => "one2many",
	    localkey => "id",
	    foreignkey => "track_id",
	    title => "Track data",
	    tag => "track_data",
	    order_by => 'file_name',
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

    $extras and $extras = "and $extras";

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
composer,
conductor,
genre
EndTables
    ;

    my $where = <<EndWhere
album.id = track.album_id
and artist.id = track.artist_id
and composer.id = track.composer_id
and conductor.id = track.conductor_id
and genre.id = track.genre_id
$extras
EndWhere
    ;

    $where .= ' order by track.album_id, track.track_num' unless $extras =~ /order by/i;

    return $self->get_list( "track", $page, $size, { tables=>$tables, select => $selects, where => $where, dump_sql=>1 } );
}

sub get_track_list {
    my ($self,$page,$size) = @_;

    my $id = $self->get('id');

    my $selects = <<EndSelects
track_data.*,
track.title as track_id
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
order by track_data.file_location, track_data.file_name
EndWhere
    ;

    return $self->get_list( "track_data", $page, $size, { tables=>$tables, select => $selects, where => $where } );
}

sub push {
	my $self = shift;
	my $mc = $self->mysqlConnection();

	my $id = $self->SUPER::push(@_);

	my $tl = $self->get_track_list;
	foreach my $track (@{$tl->{elements}}) {
		next unless $track->{file_name} =~ /\.mp3$/i;

		my $mp3 = MP3::Tag->new("$track->{file_location}$track->{file_name}");
		my $id3v2 = $mp3->new_tag('ID3v2');

		$id3v2->add_frame('TALB',$mc->enum_lookup('album','id','name',$self->get('album_id'))) if $mc->enum_lookup('album','id','name',$self->get('album_id'));
		$id3v2->add_frame('TPE1',$mc->enum_lookup('artist','id','name',$self->get('artist_id'))) if $mc->enum_lookup('artist','id','name',$self->get('artist_id'));
		$id3v2->add_frame('TIT2',$self->get('title')) if $self->get('title');
		$id3v2->add_frame('TRCK',$self->get('track_num')) if $self->get('track_num');
		$id3v2->add_frame('TYER',$self->get('year')) if $self->get('year');
		$id3v2->add_frame('TCOM',$mc->enum_lookup('composer','id','name',$self->get('composer_id'))) if $mc->enum_lookup('composer','id','name',$self->get('composer_id'));
		$id3v2->add_frame('TPE3',$mc->enum_lookup('conductor','id','name',$self->get('conductor_id'))) if $mc->enum_lookup('conductor','id','name',$self->get('conductor_id'));
		$id3v2->add_frame('TCON',$mc->enum_lookup('genre','id','name',$self->get('genre_id'))) if $mc->enum_lookup('genre','id','name',$self->get('genre_id'));
		$id3v2->write_tag;
	}

	return $id;
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

