#$Id: album.pm,v 1.1 2006/06/07 16:01:05 byngmeister Exp $

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
    title => "album",
    display => [ "id", "discid", "name", "year", "comment",  ],
    list_display => [ "id", "discid", "name", "year", "comment",  ],
    tagorder => [ "id", "discid", "name", "year", "comment",  ],
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

            },
            'discid' => {
	        type => "varchar",
		tag  => "Discid",
		title => "Discid",

            },
            'name' => {
	        type => "varchar",
		tag  => "Name",
		title => "Name",

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

