#$Id: playlist.pm,v 1.7 2006/07/03 14:50:54 byngmeister Exp $

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
    title => "playlist",
    display => [ "id", "name",  ],
    list_display => [ "id", "name",  ],
    tagorder => [ "id", "name",  ],
    tagrelationorder => [ ],
    relationshiporder => [ "playlist_track" ],
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
            'name' => {
	        type => "varchar",
		tag  => "Name",
		title => "Name",

            },

    },
    relationships => {
	'playlist_track' => {
	    type => "one2many",
	    localkey => "id",
	    foreignkey => "playlist_id",
	    title => "Track(s)",
	    tag => "playlist_track",
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
playlist.id = $id
and playlist.id = playlist_track.playlist_id
and track.id = playlist_track.track_id
EndWhere
    ;

    return $self->get_list( "playlist_track", $page, $size, { tables=>$tables, select => $selects, where => $where } );
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

