#$Id: playlist_current.pm,v 1.15 2006/09/26 11:45:57 byngmeister Exp $

package CMMS::Database::playlist_current;

=head1 NAME

CMMS::Database::playlist_current

=head1 SYNOPSIS

  use CMMS::Database::playlist_current;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use base qw( CMMS::Database::Object );

our $VERSION = sprintf '%d.%03d', q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/;

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
  my $self = new CMMS::Database::Object( $dbInterface, "playlist_current", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "playlist_current",
    tag => "playlist_current",
    title => "Currently Playing",
    display => [ "id", "zone", "track_id", "track_order", "track_played",  ],
    list_display => [ "id", "zone", "track_id", "track_order", "track_played",  ],
    tagorder => [ "id", "zone", "track_id", "track_order", "track_played",  ],
    tagrelationorder => [ ],
    relationshiporder => [ ],
    no_broadcast => 1,
    no_clone => 1,
    order_by => 'track_order',
    elements => {
            'id' => {
	        type => "int",
		tag  => "Id",
		title => "Id",
		primkey => 1,
		displaytype => "hidden",
            },
            'zone' => {
	        type => "int",
		tag  => "Zone",
		title => "Zone",
		lookup => {
		    table => "zone",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    none_text => "[please select a zone]",
		    read_only => 1,
		},
		mandatory => 1,
            },
            'track_id' => {
	        type => "int",
		tag  => "Track",
		title => "Track",
		displaytype => "doublelookup",
		prelookup => {
		    nonetext => "[please pick an album]",
		    table => "album",
		    keycol => "id",
		    valcol => "name",
		    lookup_restriction => "track.album_id=",
		    reverse_method => "rlookup_album",
		},
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
		title => "Track order",
		primkey => 1,
		displaytype => "readonly",
            },
            'track_played' => {
	        type => "int",
		tag  => "Track_played",
		title => "Track played?",
		displaytype => "checkbox",
            },

    },
    relationships => {
	'track_data' => {
	    type => "one2many",
	    localkey => "track_id",
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

    $extras and $extras = "AND ".$extras;

    my $selects = <<EndSelects
playlist_current.*,
zone.name as zone,
track.title as track_id
EndSelects
    ;

    my $tables = <<EndTables
playlist_current,
zone,
track
EndTables
    ;

    my $where = <<EndWhere
zone.id = playlist_current.zone
and track.id = playlist_current.track_id
$extras
EndWhere
    ;

    $where .= ' order by playlist_current.track_order' unless $extras =~ /order by/i;

    return $self->get_list( "playlist_current", $page, $size, { tables=>$tables, select => $selects, where => $where } );
}

sub get_track_list {
    my ($self,$page,$size) = @_;

    my $id = $self->get('track_id');

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

#------------------------------------------------------------------------------

=head2 rlookup_manufacturer

=cut


sub rlookup_album {
    my( $self, $track_id ) = @_;
    my $mc = $self->mysqlConnection();

    my $id = $mc->enum_lookup("track","id","album_id",$track_id);
    
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

