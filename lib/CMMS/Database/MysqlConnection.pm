#$Id: MysqlConnection.pm,v 1.4 2006/06/26 15:56:53 byngmeister Exp $

package CMMS::Database::MysqlConnection;

=head1 NAME

CMMS::Database::MysqlConnection - 

=head1 SYNOPSIS

  use CMMS::Database::MysqlConnection;
  $mc = CMMS::Database::MysqlConnection->new(%params);
  $mc->connect;

=head1 SUPERCLASSES

TAER::MysqlConnection

=head1 DESCRIPTION

=cut

use strict;
use base qw(TAER::MysqlConnection);
use Carp;
use DBI;

#------------------------------------------------------------------------------
# CLASS METHODS
#------------------------------------------------------------------------------

=head1 CLASS METHODS

=head2 new(%params)

Returns a new I<CMMS::Database::MysqlConnection> object.  Valid keys in
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

sub new {
  my $class  = shift;
  my %params = @_;

  my $self = bless $class->SUPER::new, $class;

  $self->host( $params{host} || 'localhost' );
  $self->database( $params{database} || 'cmms' );
  $self->user( $params{user} || 'cmms' );
  $self->password( $params{password} || 'cmms' );

  return $self;
}

# auto reconnect
sub query {
	my ($self, $sql) = @_;

	unless($self->{dbh}->ping) {
		$self->connect or die("MySQL server went away, connection couldn't be restablished :(");
		print STDERR "MySQL server went away, connection restablished :)\n";
	}

	return $self->SUPER::query($sql);
}

# auto reconnect
sub query_and_get {
	my ($self, $sql) = @_;

	unless($self->{dbh}->ping) {
		$self->connect or die("MySQL server went away, connection couldn't be restablished :(");
		print STDERR "MySQL server went away, connection restablished :)\n";
	}

	return $self->SUPER::query_and_get($sql);
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
