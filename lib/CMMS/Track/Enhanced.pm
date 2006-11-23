package CMMS::Track::Enhanced;

use strict;

our $permitted = {
	title     => undef,
	genre     => undef,
	artist    => undef,
	length    => undef,
	number    => undef,
	composer  => undef,
	conductor => undef,
	type      => undef
};
our($AUTOLOAD);

#############################################################
# AUTOLOAD restrict method aliases
#
sub AUTOLOAD {
	my $self = shift;
	die("$self is not an object") unless my $type = ref($self);
	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	die("Can't access '$name' field in object of class $type") unless( exists $permitted->{$name} );

	return (@_?$self->{$name} = shift:$self->{$name});
}

#############################################################
# DESTROY
#
sub DESTROY {
	my $self = shift;
}

sub new {
	my $class = shift;
	return bless {}, $class;
}

1;
