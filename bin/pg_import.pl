#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Text::CSV_XS;
use CDDB::File;
use CMMS::Track;
use CMMS::Ripper;
use CMMS::File;
use Digest::MD5 qw(md5_hex);
use POSIX qw(floor);

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

$media =~ s|/$||;

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

my $null = quotemeta '\\N';

my $csv = new Text::CSV_XS({
	sep_char => "\t",
	binary => 1
});

open(ALBUM,'< '.$tables->{album}->{file});
my $num = 0;
while(<ALBUM>) {
	s/[\r\n]+//;
	s/$null//g;

	next unless $_;
	next unless /^[0-9]/;

        s/"/""/g;
        s/\t/"\t"/g;
        s/^/"/;
        s/$/"/;
        s/[Ãºú©¶³]/?/g;

	$csv->parse($_);
	@_ = $csv->fields;
	$_[0] = $num unless $_[0];

	$tables->{album}->{albums}->{$_[0]} = {
		discid => $_[1]?$_[1]:'',
		name => $_[2]?$_[2]:'Unknown'.$num,
		year => $_[3]?$_[3]:'',
		comment => $_[4]?$_[4]:'',
		tracks => []
	};

	$num++;
}
close(ALBUM);

open(ARTIST,'< '.$tables->{artist}->{file});
while(<ARTIST>) {
	s/[\r\n]+//;
	s/$null//g;

	next unless $_;

        s/"/""/g;
        s/\t/"\t"/g;
        s/^/"/;
        s/$/"/;
        s/[Ãºú©¶³]/?/g;

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

        s/"/""/g;
        s/\t/"\t"/g;
        s/^/"/;
        s/$/"/;
        s/[Ãºú©¶³]/?/g;

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
	next unless /^[0-9]/;

        s/"/""/g;
        s/\t/"\t"/g;
        s/^/"/;
        s/$/"/;
        s/[Ãºú©¶³]/?/g;

	$csv->parse($_);
	@_ = $csv->fields;
	$_[1] = -1 unless $_[1];
	$_[2] = -1 unless $_[2];
	$_[3] = -1 unless $_[3];
	next unless $_[6];

	push @{$tables->{album}->{albums}->{$_[1]}->{tracks}}, {
		artist => $tables->{artist}->{artists}->{$_[2]}->{name},
		genre => $tables->{genre}->{genres}->{$_[3]}->{name},
		title => $_[4]?$_[4]:'',
		track_num => $_[5]?$_[5]:'',
		file_location => $_[6]?$_[6]:'',
		file_name => $_[7]?$_[7]:'',
		file_type => $_[8]?$_[8]:'',
		bitrate => $_[9]?$_[9]:'',
		filesize => $_[10]?$_[10]:'',
		length_seconds => $_[11]?$_[11]:1,
		info_source => $_[12]?$_[12]:'',
		ctime => $_[13]?$_[13]:'',
		comment => $_[14]?$_[14]:'',
		year => $_[15]?$_[15]:'',
		composer => $_[16]?$_[16]:''
	};
}
close(TRACK);

my $ripper = new CMMS::Ripper(
	nocache => 1,
	conf => '/etc/cmms.conf'
);

while(my($album_id,$album) = each %{$tables->{album}->{albums}}) {
	my $total = 0;
	my $offsets = [];

	my @tracks = sort{$a->{track_num} <=> $b->{track_num}}@{$album->{tracks}};

	unless($album->{name}) {
		print STDERR "Empty album [$album_id]\n";
		$album->{name} = 'Unknown';
	}

	unless($tracks[0]->{artist}) {
		print STDERR "album [$album_id] [$album->{name}] Empty artist\n";
		$tracks[0]->{artist} = 'Unknown';
	}

	unless($tracks[0]->{genre}) {
		print STDERR "album [$album_id] [$album->{name}] Empty genre\n";
		$tracks[0]->{genre} = 'Unknown';
	}

	$album->{name} =~ s/#/No./g;

	$album->{discid} = md5_hex($tracks[0]->{artist}.' '.$album->{name}) if $album->{discid} eq '';

	my $newlocation = safe_chars($tracks[0]->{artist}).'/'.safe_chars($album->{name});
	`mkdir -m 777 -p /usr/local/cmms/htdocs/media/$newlocation` unless -d "/usr/local/cmms/htdocs/media/$newlocation";

	my $trck_num = 1;
	foreach my $track (@tracks) {
		$track->{track_num} = $track->{track_num}?$track->{track_num}:$trck_num;
		$trck_num++;
		next unless $track->{file_name};
		$track->{title} =~ s/#/No./g;
		my $number = sprintf('%02d',$track->{track_num});
		my($ext) = ($track->{file_name} =~ /(mp3|flac|wav)$/i);
		my $newname = substr(safe_chars($number.' '.$track->{title}),0,35).".$ext";
		#print STDERR "cp '$media/$track->{file_location}$track->{file_name}' /usr/local/cmms/htdocs/media/$newlocation/$newname\n";
		`cp "$media/$track->{file_location}$track->{file_name}" /usr/local/cmms/htdocs/media/$newlocation/$newname` unless -f "/usr/local/cmms/htdocs/media/$newlocation/$newname";
		`chown nobody:nobody /usr/local/cmms/htdocs/media/$newlocation/$newname`;

		my $bitrate = 320*1024;
		my $filesize = -s "/usr/local/cmms/htdocs/media/$newlocation/$newname";
		my $size = $filesize*8;
		$track->{length_seconds} = floor($size/$bitrate);
		push @{$offsets}, ($total*75);
		$total += $track->{length_seconds};
	}

	my $fname = md5_hex($tracks[0]->{artist}.' '.$album->{name});

	unless(scalar @{$offsets}) {
		print STDERR "album [$album_id] [$album->{name}] has no tracks\n";
		next;
	}

	unless(scalar @{$offsets} > 1) {
		print STDERR "album [$fname] [$album_id] [$album->{name}] only has 1 track [$tracks[0]->{track_num}] which breaks CDDB :(\n";
		$tracks[0]->{track_num} = 1;
		push @{$offsets}, ($tracks[0]->{length_seconds}*75);
		#next;
	}

	open(CDDB,'> /tmp/album.cddb');
	#open(CDDB,"> /tmp/$fname.cddb");
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
DTITLE=$tracks[0]->{artist} / $album->{name}
".join("\n",map{'TTITLE'.($_->{track_num}-1)."=$_->{title}"}@tracks)."
EXTD=".($album->{comment}?$album->{comment}:'')."
".join("\n",map{'EXTT'.($_->{track_num}-1).'='.($_->{comment}?$_->{comment}:'')}@tracks)."
PLAYORDER=
";
	close(CDDB);
	my $albumdata = new CDDB::File('/tmp/album.cddb');
	#my $albumdata = new CDDB::File("/tmp/$fname.cddb");

	my @meta_tracks = map{
		$_ = new CMMS::Track($_);
		$_->composer(
			$tracks[($_->number-1)]->{composer}
			?
			$tracks[($_->number-1)]->{composer}
			:
			''
		);
		$_->conductor('');
		$_
	} $albumdata->tracks;

	my $metadata = {
		GENRE => $tracks[0]->{genre},
		DISCID => $album->{discid},
		discid => $album->{discid},
		ARTIST => $tracks[0]->{artist},
		ALBUM => $album->{name},
		COMMENT => $album->{comment},
		COMPOSER => '',
		CONDUCTOR => '',
		YEAR => $album->{year},
		TRACKS => \@meta_tracks
	};

	if($ripper->check($metadata)) {
		$ripper->cover($metadata);
		$ripper->store($metadata);
		#$ripper->store_xml($metadata);
	} else {
		warn "Album [$album->{discid}] [$album->{name}] already ripped";
	}
}

sub usage {
	my $script = $0;
	$script =~ s^.+/^^;
	$script =~ s/.+\\//;

	print STDERR "Usage:\n\t$script -sql [import.sql] -media [/home/media]\n\n";
	exit 0;
}
