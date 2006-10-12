#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Text::CSV_XS;
use CDDB::File;
use CMMS::Ripper;
use CMMS::File;

my $tables = {
	album => {},
	artist => {},
	genre => {},
	track => {},
	discitem => 1,
	identity => {},
	cddb_genres => 1,
	cddb_sub_genres => 1,
	album_cddb => 1,
	album_lookup => 1,
	staticplaylist => 1
};

my($sql,$media,$help);

GetOptions(
	'sql=s' => \$sql,
	'media=s' => \$media,
	help => \$help
);

&usage if $help || !$sql || !$media;

$media =~ s|/$||;

my $csv = new Text::CSV_XS({sep_char=>"\t"});

my $null = '\\\\N';
my $tabl = join '|', keys %{$tables};
my $table = undef;

open(SQL,'< '.$sql);
while(<SQL>) {
	s/\r+//;
	s/$null//g;

	next unless $_;

	if(/copy "($tabl)" from/i) {
		$table = $1;
		print STDERR "Table [$table]\n";
	} elsif($table && /\\\./) {
		$table = undef;
	} elsif($table) {
		$csv->parse($_);
		@_ = $csv->fields;

		if($table eq 'identity') {
			$tables->{$table}->{$_[0]} = {name=>$_[1]} if defined $_[1];
		}

		if($table eq 'album') {
			$tables->{$table}->{$_[0]} = {tracks=>[]} unless $tables->{$table}->{$_[0]};
		}

		if($table eq 'album_cddb') {
			$tables->{album}->{$_[0]} = {tracks=>[]} unless $tables->{album}->{$_[0]};
			$tables->{album}->{$_[0]}->{genre} = $_[1] if $_[1];
			$tables->{album}->{$_[0]}->{genre} = $_[2] if $_[2];
		}

		if($table eq 'album_lookup') {
			$tables->{album}->{$_[0]} = {tracks=>[]} unless $tables->{album}->{$_[0]};
			$tables->{album}->{$_[0]}->{discid} = $_[1];
		}

		if($table eq 'artist') {
			$tables->{$table}->{$_[0]} = {};
		}

		if($table eq 'track') {
			$tables->{$table}->{$_[0]} = {} unless $tables->{$table}->{$_[0]};
			$tables->{$table}->{$_[0]}->{length_seconds} = $_[2];
			$tables->{$table}->{$_[0]}->{artist} = $_[3];
			$tables->{$table}->{$_[0]}->{album} = $_[4];
		}

		if($table eq 'discitem') {
			$tables->{track}->{$_[0]} = {} unless $tables->{track}->{$_[0]};
			my $file = $_[4];
			$file =~ s|/media/||i;
			$tables->{track}->{$_[0]}->{file} = $file;
		}

		if($table eq 'staticplaylist') {
			$tables->{track}->{$_[2]} = {} unless $tables->{track}->{$_[2]};
			$tables->{track}->{$_[2]}->{track_num} = ($_[1]+1);
		}

		if($table eq 'cddb_genres' || $table eq 'cddb_sub_genres') {
			$tables->{genre}->{$_[0]} = {name=>$_[1]};
		}
	}
}
close(SQL);

foreach my $id (keys %{$tables->{album}}) {
	$tables->{album}->{$id}->{name} = $tables->{identity}->{$id}->{name};
	my $genre_id = $tables->{album}->{$id}->{genre};
	$tables->{album}->{$id}->{genre} = $tables->{genre}->{$genre_id}->{name};
}

foreach my $id (keys %{$tables->{artist}}) {
	$tables->{artist}->{$id}->{name} = $tables->{identity}->{$id}->{name};
}

foreach my $id (keys %{$tables->{track}}) {
	$tables->{track}->{$id}->{title} = $tables->{identity}->{$id}->{name};
	my $album_id = $tables->{track}->{$id}->{album};
	$tables->{track}->{$id}->{artist} = $tables->{artist}->{$tables->{track}->{$id}->{artist}}->{name};
	$tables->{track}->{$id}->{album} = $tables->{album}->{$album_id}->{name};

	push @{$tables->{album}->{$album_id}->{tracks}}, $tables->{track}->{$id};
}

my $ripper = new CMMS::Ripper(
	nocache => 1,
	conf => '/etc/cmms.conf'
);

foreach my $album (values %{$tables->{album}}) {
	my $total = 0;
	my $offsets = [];
	my @tracks = sort{$a->{track_num}<=>$b->{track_num}} @{$album->{tracks}};
	foreach my $track (@tracks) {
		push @{$offsets}, ($total*75);
		$total += $track->{length_seconds};
		my $newname = substr(safe_chars(sprintf('%02d',$track->{track_num}).' '.$track->{title}),0,35);
		`cp $media/$track->{file} /tmp/$newname.wav`;
	}

	# Normalize wav volume
	`nice -n 10 normalize -b /tmp/*.wav`;

	open(CDDB,'> /tmp/album.cddb');
	print CDDB "# xmcd
#
# Track frame offsets:
".join("\n",map{"#       $_"}@{$offsets})."
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
".join("\n",map{'TTITLE'.($_->{track_num}-1)."=$_->{title}"}@tracks)."
EXTD=
".join("\n",map{'EXTT'.($_->{track_num}-1).'='.($_->{comment}?$_->{comment}:'')}@tracks)."
PLAYORDER=
";
	close(CDDB);
	my $albumdata = new CDDB::File('/tmp/album.cddb');

	@tracks = $albumdata->tracks;

	my $metadata = {
		GENRE => $album->{genre},
		DISCID => $album->{discid},
		discid => $album->{discid},
		ARTIST => $album->{tracks}->[0]->{artist},
		ALBUM => $album->{name},
		TRACKS => \@tracks
	};

	if($ripper->check($metadata)) {
		$ripper->encode($metadata);
		$ripper->cover($metadata);
		#$ripper->store($metadata);
		$ripper->store_xml($metadata);
		$ripper->purge;
	} else {
		warn "Album $album->{name} already ripped";
	}
}

sub usage {
	my $script = $0;
	$script =~ s^.+/^^;
	$script =~ s/.+\\//;

	print STDERR "Usage:\n\t$script -sql [import.sql] -media [/home/media]\n\n";
	exit 0;
}
