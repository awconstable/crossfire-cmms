package CMMS::Ripper::DiscID::freedb;

use strict;
use warnings;
use base qw(CMMS::Ripper::DiscID::Generic);
use CMMS::Ripper::DiscID::CorewareFreeDB;

sub new {
	my $class = shift;
	my $self = bless $class->SUPER::new(@_), $class;
	$self->{FreeDB} = new CMMS::Ripper::DiscID::CorewareFreeDB;

	return $self;
}

sub metadata {
	my $self = shift;

	my $mc = $self->mysqlConnection;

	my($metadata) = $self->{FreeDB}->query($self->discid);
	my $albumdata = {};

	if($metadata->{ALBUM}) {
		$albumdata = $self->{FreeDB}->read($metadata->{GENRE},$metadata->{DISCID});
	} else {
		($metadata,$albumdata) = $self->default;
	}

	$self->{GENRE}    = $metadata->{GENRE};
	$self->{DISCID}   = $metadata->{DISCID};
	$self->{ARTIST}   = $metadata->{ARTIST};
	$self->{ALBUM}    = $metadata->{ALBUM};
	$self->{COMMENTS} = $albumdata->extd;
	$self->{YEAR}     = $albumdata->year;
	my @tracks        = $albumdata->tracks;
	$self->{TRACKS}   = \@tracks;

	return $self;
}

1;
