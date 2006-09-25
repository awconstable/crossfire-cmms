#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Text::CSV_XS;
use CDDB::File;
use CMMS::Ripper;

my $tables = {
	album => {albums=>{}},
	artist => {artists=>{}},
	genre => {genres=>{}},
	track => {}
};

my($sql,$media,$help);

GetOptions(
	'sql=s' => \$sql,
	'media=s' => \$media,
	help => \$help
);

&usage if $help || !$sql || !$media;

my $base = $sql;
$base =~ s/[^\/]+$//;

open(SQL,'< '.$sql);
while(<SQL>) {
	s/\r+//;

	my $tabl = join '|', keys %{$tables};
	if(my($table,undef,$file) = (/copy ($tabl).+from(\s)?['"]([^'"]+)['"]/i)) {
		$table = lc $table;
		$file =~ s/.+\///;
		$file = "$base$file";
		print STDERR "Table [$table] from '$file'\n";
		$tables->{$table}->{file} = $file;
	}
}
close(SQL);

my $null = '\\\\N';

my $csv = new Text::CSV_XS({sep_char=>"\t"});

open(ALBUM,'< '.$tables->{album}->{file});
while(<ALBUM>) {
	s/[\r\n]+//;
	s/$null//g;

	next unless $_;
	$csv->parse($_);
	@_ = $csv->fields;
	$tables->{album}->{albums}->{$_[0]} = {
		discid => $_[1] || '',
		name => $_[2] || '',
		year => $_[3] || '',
		comment => $_[4] || '',
		tracks => []
	};
}
close(ALBUM);

open(ARTIST,'< '.$tables->{artist}->{file});
while(<ARTIST>) {
	s/[\r\n]+//;
	s/$null//g;

	next unless $_;
	$csv->parse($_);
	@_ = $csv->fields;
	next unless $_[1];
	$tables->{artist}->{artists}->{$_[0]} = {name => $_[1]};
}
close(ARTIST);

open(GENRE,'< '.$tables->{genre}->{file});
while(<GENRE>) {
	s/[\r\n]+//;
	s/$null//g;

	next unless $_;
	$csv->parse($_);
	@_ = $csv->fields;
	next unless $_[1];
	$tables->{genre}->{genres}->{$_[0]} = {name => $_[1]};
}
close(GENRE);

open(TRACK,'< '.$tables->{track}->{file});
while(<TRACK>) {
	s/[\r\n]+//;
	s/$null//g;

	next unless $_;
	$csv->parse($_);
	@_ = $csv->fields;
	push @{$tables->{album}->{albums}->{$_[1]}->{tracks}}, {
		artist => $tables->{artist}->{artists}->{$_[2]}->{name},
		genre => $tables->{genre}->{genres}->{$_[3]}->{name},
		title => $_[4] || '',
		track_num => $_[5] || '',
		file_location => $_[6] || '',
		file_name => $_[7] || '',
		file_type => $_[8] || '',
		bitrate => $_[9] || '',
		filesize => $_[10] || '',
		length_seconds => $_[11] || '',
		info_source => $_[12] || '',
		ctime => $_[13] || '',
		comment => $_[14] || '',
		year => $_[15] || '',
		composer => $_[16] || ''
	};
}
close(TRACK);

my $ripper = new CMMS::Ripper(conf => '/etc/cmms.conf');

foreach my $album (values %{$tables->{album}->{albums}}) {
	my $total = 0;
	my $offsets = [];
	foreach my $track (@{$album->{tracks}}) {
		push @{$offsets}, ($total*75);
		$total += $track->{length_seconds};
		`mkdir -p /usr/local/cmms/htdocs/media/$track->{file_location}` unless -d "/usr/local/cmms/htdocs/media/$track->{file_location}";
		my $newname = $track->{file_name};
		$newname =~ s/\-/_/g;
		`cp $media/$track->{file_location}/$track->{file_name} /usr/local/cmms/htdocs/media/$track->{file_location}$newname`;
	}

	open(CDDB,'> /tmp/album.cddb');
	print CDDB "# xmcd
#
# Track frame offsets:
".join("
",map{"#       $_"}@{$offsets})."
#
# Disc length: $total seconds
#
# Revision: 1
# Processed by: CMMSRipper
# Submitted via: CMMSRipper
# Normalized: r4:DSETVAR1
#
DISCID=$album->{discid}
DTITLE=$album->{tracks}->[0]->{artist} / $album->{name}
".join("
",map{'TTITLE'.($_->{track_num}-1)."=$_->{title}"}@{$album->{tracks}})."
EXTD=".($album->{comment}?$album->{comment}:'')."
".join("
",map{'EXTT'.($_->{track_num}-1).'='.($_->{comment}?$_->{comment}:'')}@{$album->{tracks}})."
PLAYORDER=
";
	close(CDDB);
	my $albumdata = new CDDB::File('/tmp/album.cddb');

	my @tracks = $albumdata->tracks;

	my $metadata = {
		GENRE => $album->{tracks}->[0]->{genre},
		DISCID => $album->{discid},
		discid => $album->{discid},
		ARTIST => $album->{tracks}->[0]->{artist},
		ALBUM => $album->{name},
		COMMENT => $album->{comment},
		YEAR => $album->{year},
		TRACKS => \@tracks
	};

	if($ripper->check($metadata)) {
		$ripper->cover($metadata);
		$ripper->store($metadata);
	} else {
		warn "Album $album->{name} already ripped";
	}

	use Data::Dumper;
	#print Dumper($album);
	#print Dumper($albumdata);
	print Dumper(\@tracks);
	#print Dumper($metadata);
	die("Test");
}

sub usage {
	my $script = $0;
	$script =~ s^.+/^^;
	$script =~ s/.+\\//;

	print STDERR "Usage:\n\t$script -sql [import.sql] -media [/home/media]\n\n";
	exit 0;
}
