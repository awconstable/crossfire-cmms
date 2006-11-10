#$Id: MysqlConnectionEscape.pm,v 1.2 2006/11/10 15:53:17 byngmeister Exp $

package CMMS::Database::MysqlConnectionEscape;

=head1 NAME

CMMS::Database::MysqlConnectionEscape - 

=head1 SYNOPSIS

  use CMMS::Database::MysqlConnectionEscape;
  $mc = CMMS::Database::MysqlConnectionEscape->new(%params);
  $mc->connect;

=head1 SUPERCLASSES

TAER::MysqlConnection

=head1 DESCRIPTION

=cut

use strict;
use base qw(CMMS::Database::MysqlConnection);
use Carp;
use DBI;

#------------------------------------------------------------------------------
# CLASS METHODS
#------------------------------------------------------------------------------

=head1 CLASS METHODS

=head2 new(%params)

Returns a new I<CMMS::Database::MysqlConnectionEscape> object.  Valid keys in
I<%params> are:

=over 4

=item host

Defaults to 'localhost'.

=item database

Defaults to 'CMMS::Database'.

=item user

=item password

=back

=cut

sub query_and_get {
	my ($self, $sql) = @_;

	my $query = $self->SUPER::query_and_get($sql);
	if($query && scalar @{$query}) {
		my @query = map{$self->escape_hashref($_)} @{$query};
		$query = \@query;
	}

	return $query;
}

sub escape_hashref {
	my ($self, $hashref) = @_;

	my $chars = quotemeta ';:|';
	foreach(keys %{$hashref}) {
		$hashref->{$_} =~ s/[$chars]/ /g;
	}

	return $hashref;
}

1;

__END__

=head1 SEE ALSO

L<TAER::MysqlConnection>

=head1 AUTHOR

Tobias Russell E<lt>toby@russellsharpe.comE<gt>

Paul Sharpe E<lt>paul@russellsharpe.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2006 Russell Sharpe Limited. England.  All rights
reserved.

You must obtain a written license to use this software.

=cut
