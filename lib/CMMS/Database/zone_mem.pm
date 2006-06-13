#$Id: zone_mem.pm,v 1.4 2006/06/13 11:15:33 byngmeister Exp $

package CMMS::Database::zone_mem;

=head1 NAME

CMMS::Database::zone_mem

=head1 SYNOPSIS

  use CMMS::Database::zone_mem;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use base qw( CMMS::Database::Object );

our $VERSION = sprintf '%d.%03d', q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/;

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
  my $self = new CMMS::Database::Object( $dbInterface, "zone_mem", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "zone_mem",
    tag => "zone_mem",
    title => "zone_mem",
    display => [ "zone", "key", "value",  ],
    list_display => [ "zone", "key", "value",  ],
    tagorder => [ "zone", "key", "value",  ],
    tagrelationorder => [ ],
    relationshiporder => [ ],
    no_broadcast => 1,
    no_clone => 1,
    elements => {
            'zone' => {
	        type => "int",
		tag  => "Zone",
		title => "Zone",
		primkey => 1,

            },
            'key' => {
	        type => "varchar",
		tag  => "Key",
		title => "Key",
		primkey => 1,

            },
            'value' => {
	        type => "varchar",
		tag  => "Value",
		title => "Value",

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

Copyright (c) 2005 Coreware Limited. England.  All rights reserved.

You must obtain a written license to use this software.

=cut

