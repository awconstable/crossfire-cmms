package CMMS::Ripper::DiscID::Generic;

use strict;
use warnings;
use CDDB::File;
use Digest::MD5 qw(md5_hex);

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1
};
our($AUTOLOAD);

#############################################################
# Constructor
#
sub new {
	my $class = shift;
	my (%params) = @_;

	die('No config') unless $params{conf};
	die('No mysql connection') unless $params{mc};

	my $self = {};
	$self->{conf} = $params{conf};

	bless $self, $class;
	$self->mysqlConnection($params{mc});
	$self->{discid} = $self->discid; # cache discid

	return $self;
}

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

sub default {
	my $self = shift;

	my $tmp = $self->{conf}->{tmpdir};

	my $discid = md5_hex($self->{discid});
	my $metadata = {
		GENRE => 'Misc',
		DISCID => $discid,
		ARTIST => 'Unknown',
		ALBUM => 'Unknown '.$discid
	};

	my $query = '';
	open(QUERY,'cdparanoia -Q -e 2>&1 |');
	while(<QUERY>) {
		$query .= $_;
	}
	close(QUERY);

	my @tracks = ($query =~ /([0-9]+)\.\s+/g);

	open(CDDB,"> ${tmp}album.cddb");
	print CDDB "# xmcd\n\n#\n\n# Track frame offsets:\n\n".join("\n",map{"#       $_"}@tracks)."\n\n#\n\n# Disc length: ".(scalar @tracks)."\n\n#\n\n# Revision: 1\n\n# Processed by: cddbd v1.5.1PL2 Copyright (c) Steve Scherf et al.\n\n# Submitted via: CMMSRipper\n\n# Normalized: r4:DSETVAR1\n\n#\n\nDISCID=$discid\n\nDTITLE=Unknown $discid\n\n".join("\n",map{'TTITLE'.($_-1)."=Track $_"}@tracks)."\n\nEXTD=CMMSRipper\n\n".join("\n",map{'EXTT'.($_-1).'='}@tracks)."\n\nPLAYORDER=\n";
	close(CDDB);
	my $albumdata = new CDDB::File("${tmp}album.cddb");

	return ($metadata,$albumdata);
}

sub discid {
	my $self = shift;
	my $mc = $self->mysqlConnection;
	my $discid = `cd-discid /dev/cdrom 2> /dev/null` or die("Can't obtain CD ID");
	chomp($discid);

	return $discid;
}

1;
