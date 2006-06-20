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

	my $tmp = $self->{conf}->{ripper}->{tmpdir};

	my $discid = md5_hex($self->{discid});
	my $metadata = {
		GENRE => 'Misc',
		DISCID => $self->{discid},
		ARTIST => 'Unknown',
		ALBUM => 'Unknown '.$discid
	};

	my $query = '';
	open(QUERY,'cdparanoia -Q -e 2>&1 |');
	while(<QUERY>) {
		$query .= $_;
	}
	close(QUERY);

	#track        length               begin        copy pre ch
	#===========================================================
	#  1.    22557 [05:00.57]        0 [00:00.00]    no   no  2
	#  2.    14365 [03:11.40]    22557 [05:00.57]    no   no  2
	my @tracks = ($query =~ /\s+([0-9]+)\.\s+/g);
	my @offsets = ($query =~ /\]\s+([0-9]+)\s+\[/g);
	#my($total) = ($query =~ /TOTAL\s+([0-9]+)/);
	#$total = $total / 60;

	my($mins,$secs) = ($query =~ /TOTAL\s+[0-9]+\s+\[([0-9]+):([0-9\.]+)\]/);
	my $total = ($mins * 60) + $secs;

	open(CDDB,"> ${tmp}album.cddb");
	print CDDB "# xmcd\n#\n# Track frame offsets:\n".join("\n",map{"#       $_"}@offsets)."\n#\n# Disc length: $total seconds\n#\n# Revision: 1\n# Processed by: CMMSRipper\n# Submitted via: CMMSRipper\n# Normalized: r4:DSETVAR1\n#\nDISCID=$discid\nDTITLE=Unknown $discid\n".join("\n",map{'TTITLE'.($_-1)."=Track $_"}@tracks)."\nEXTD=CMMSRipper\n".join("\n",map{'EXTT'.($_-1).'='}@tracks)."\nPLAYORDER=\n";
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
