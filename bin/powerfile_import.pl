#!/usr/bin/perl -w

use strict;
use XML::Simple;
use CMMS::Ripper;

my $ripper = new CMMS::Ripper(conf => '/etc/cmms.conf');
my $mc = $ripper->mysqlConnection;

my $xml = XMLin('./export.xml');

die('Album already imported') unless $ripper->check($xml->{album});

my $genre_id = $ripper->genre_find_or_create($xml->{album}->{genre});
my $folder = $xml->{album}->{folder};

my $artist_id = $ripper->artist_find_or_create($xml->{album}->{artist});

my $cover = $xml->{album}->{cover};
$cover = '' if ref($cover) eq 'HASH';
$cover =~ s^/usr/local/cmms/htdocs/^^sig;

my $year = $xml->{album}->{year};
$year = '' if ref($year) eq 'HASH';
my $comment = $xml->{album}->{comment};
$comment = '' if ref($comment) eq 'HASH';

my $sql = 'INSERT INTO album (name,discid,year,comment,cover,artist_id,genre_id) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($xml->{album}->{name},$xml->{album}->{discid},$year,$comment,$cover,$artist_id,$genre_id)).')';
$mc->query($sql);
my $album_id = $mc->last_id;

`mkdir -p $folder` unless -d $folder;

$cover =~ s^.+/^^;
`cp $cover $folder/` if $cover;

$xml->{tracks}->{track} = [$xml->{tracks}->{track}] unless ref($xml->{tracks}->{track}) eq 'ARRAY';

foreach my $track (@{$xml->{tracks}->{track}}) {
	my $artist_id = $ripper->artist_find_or_create($track->{artist});

	$sql = 'insert into track (album_id,artist_id,genre_id,title,track_num,length_seconds,ctime) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($album_id,$artist_id,$genre_id,$track->{title},$track->{track_num},$track->{length_seconds})).',NOW())';
	$mc->query($sql);
	my $track_id = $mc->last_id;

	$track->{data} = [$track->{data}] unless ref($track->{data}) eq 'ARRAY';
	foreach my $data (@{$track->{data}}) {
		my $bitrate = $data->{bitrate};
		$bitrate = '' if ref($bitrate) eq 'HASH';
		$sql = 'INSERT INTO track_data (track_id,file_location,file_name,file_type,bitrate,filesize,info_source) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($track_id,$data->{file_location},$data->{file_name},$data->{file_type},$bitrate,$data->{filesize},$data->{info_source})).')';
		$mc->query($sql);

		`cp $data->{file_name} $folder/`;
	}
}
