#$Id: track_data.pm,v 1.8 2006/07/03 15:11:13 byngmeister Exp $

package CMMS::Database::track_data;

=head1 NAME

CMMS::Database::track_data

=head1 SYNOPSIS

  use CMMS::Database::track_data;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use base qw( CMMS::Database::Object );

our $VERSION = sprintf '%d.%03d', q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/;

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
  my $self = new CMMS::Database::Object( $dbInterface, "track_data", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "track_data",
    tag => "track_data",
    title => "track_data",
    display => [ "id", "track_id", "file_location", "file_name", "file_type", "bitrate", "filesize", "info_source",  ],
    list_display => [ "id", "track_id", "file_location", "file_name", "file_type", "bitrate", "filesize", "info_source",  ],
    tagorder => [ "id", "track_id", "file_location", "file_name", "file_type", "bitrate", "filesize", "info_source",  ],
    tagrelationorder => [ ],
    relationshiporder => [ ],
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
            'file_location' => {
	        type => "text",
		tag  => "File_location",
		title => "File_location",

            },
            'file_name' => {
	        type => "varchar",
		tag  => "File_name",
		title => "File_name",

            },
            'file_type' => {
	        type => "varchar",
		tag  => "File_type",
		title => "File_type",

            },
            'bitrate' => {
	        type => "int",
		tag  => "Bitrate",
		title => "Bitrate",

            },
            'filesize' => {
	        type => "int",
		tag  => "Filesize",
		title => "Filesize",

            },
            'info_source' => {
	        type => "varchar",
		tag  => "Info_source",
		title => "Info_source",

            },

    },
    relationships => {
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
$extras
and track.id = track_data.track_id
order by track_data.track_id, track_data.file_location, track_data.file_name
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

