#$Id: Selector.pm,v 1.1 2006/06/07 16:01:46 byngmeister Exp $

package CMMS::Database::UI::Selector;

use Carp;
use DBI;
use strict;
use TAER::MysqlConnection;
use TAER::UI::Selector;
use vars qw( @ISA $AUTOLOAD );

@ISA = qw( Exporter TAER::UI::Selector );

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
