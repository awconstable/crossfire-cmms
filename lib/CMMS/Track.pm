package CMMS::Track;

use strict;
use CDDB::File;
use base qw(CDDB::File::Track);

sub new {
	my($class,$obj) = @_;
	return bless $obj, $class;
}

sub composer {
	my($self,$str) = @_;
	return $str?$self->{composer}=$str:$self->{composer};
}

sub conductor {
	my($self,$str) = @_;
	return $str?$self->{conductor}=$str:$self->{conductor};
}

1;
