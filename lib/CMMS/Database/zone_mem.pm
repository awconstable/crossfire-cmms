#$Id: zone_mem.pm,v 1.10 2006/07/03 13:23:43 byngmeister Exp $

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

our $VERSION = sprintf '%d.%03d', q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/;

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
    display => [ "id", "zone", "param", "value",  ],
    list_display => [ "id", "zone", "param", "value",  ],
    tagorder => [ "id", "zone", "param", "value",  ],
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
            'zone' => {
	        type => "int",
		tag  => "Zone",
		title => "Zone",
		lookup => {
		    table => "zone",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		},

            },
            'param' => {
	        type => "varchar",
		tag  => "Param",
		title => "Param",

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

sub get_self {
    my $self = shift;
    my $page = shift;
    my $size = shift;
    my $extras = shift;

    $extras = "1=1" unless $extras;

    my $selects = <<EndSelects
zone.name as zone
EndSelects
    ;

    my $tables = <<EndTables
zone_mem
zone
EndTables
    ;

    my $where = <<EndWhere
$extras
and zone.id = zone_mem.zone
EndWhere
    ;

    use Data::Dumper;
    my $res = $self->get_list( "zone_mem", $page, $size, { tables=>$tables, select => $selects, where => $where } );
    open(DMP,'> /tmp/dumper.out');
    print DMP Dumper($res);
    close(DMP);

    return $res;

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

