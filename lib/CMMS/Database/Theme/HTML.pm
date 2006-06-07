#$Id: HTML.pm,v 1.1 2006/06/07 16:01:46 byngmeister Exp $

package CMMS::Database::Theme::HTML;

use Carp;
use CGI;
use CMMS::Database::Theme::Theme;
use TAER::Theme::HTML;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);

require Exporter;

@ISA = qw(Exporter TAER::Theme::HTML);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);

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
