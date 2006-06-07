#$Id: playlist_track.pm,v 1.1 2006/06/07 16:01:05 byngmeister Exp $

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

our $VERSION = sprintf '%d.%03d', q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

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
    display => [ "playlist_id", "track_id", "track_order",  ],
    list_display => [ "playlist_id", "track_id", "track_order",  ],
    tagorder => [ "playlist_id", "track_id", "track_order",  ],
    tagrelationorder => [ ],
    relationshiporder => [ ],
    no_broadcast => 1,
    no_clone => 1,
    elements => {
            'playlist_id' => {
	        type => "int",
		tag  => "Playlist",
		title => "Playlist",
		primkey => 1,
		lookup => {
		    table => "Playlist",
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
		    table => "Track",
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

