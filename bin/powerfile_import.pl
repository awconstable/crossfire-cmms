#!/usr/bin/perl -w

use strict;
use XML::Simple;
use CMMS::Ripper;

my $ripper = new CMMS::Ripper(conf => '/etc/cmms.conf');
my $mc = $ripper->mysqlConnection;

my $xml = XMLin('./export.xml');

my $genre_id = $ripper->genre_find_or_create($xml->{album}->{genre});
my $folder = $xml->{album}->{folder};

my $sql = 'INSERT INTO album (name,discid,year,comment,cover,artist_id,genre_id) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($xml->{album}->{name},$xml->{album}->{discid},$xml->{album}->{year},$xml->{album}->{comment},$xml->{album}->{cover},$xml->{album}->{artist},$genre_id)).')';
$mc->query($sql);
my $album_id = $mc->last_id;

`cp $xml->{album}->{cover} $folder`;

$xml->{tracks}->{track} = [$xml->{tracks}->{track}] unless ref($xml->{tracks}->{track}) eq 'ARRAY';

foreach my $track (@{$xml->{tracks}->{track}}) {
	my $artist_id = $ripper->artist_find_or_create($track->{artist});

	$sql = 'insert into track (album_id,artist_id,genre_id,title,track_num,length_seconds,ctime) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($track)}($album_id,$artist_id,$genre_id,$track->{title},$track->{track_num},$track->{length_seconds})).',NOW())';
	$mc->query($sql);
	my $track_id = $mc->last_id;

	$track->{data} = [$track->{data}] unless ref($track->{data}) eq 'ARRAY';
	foreach my $data (@{$track->{data}}) {
		$sql = 'INSERT INTO track_data (track_id,file_location,file_name,file_type,bitrate,filesize,info_source) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($data)}($track_id,$data->{file_location},$data->{file_name},$data->{file_type},$data->{bitrate},$data->{filesize},$data->{info_source})).')';
		$mc->query($sql);

		`cp $data->{file_name} $folder`;
	}
}
