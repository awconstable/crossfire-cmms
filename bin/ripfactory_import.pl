#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use XML::Simple;
use CMMS::Track::Enhanced;
use CMMS::Ripper;
use CMMS::File;
use Digest::MD5 qw(md5_hex);

my($media,$help);
GetOptions(
	'media=s' => \$media,
	help => \$help
);

&usage if $help || !$media;

my $xmls = {};
my $cnt = 0;
recurse($media);
my $ripper = new CMMS::Ripper(
	nocache => 1,
	conf => '/etc/cmms.conf'
);

foreach my $xml (values %{$xmls}) {
	import($xml);
}

sub recurse {
	my $folder = shift;
	$folder =~ s|/$||;
	$folder =~ s/(\W)/\\$1/g;
	$folder =~ s|\\/|/|g;
	print STDERR "\tFolder [$folder]\n";

	foreach my $file (grep{!m|/\.+$|}<$folder/*>) {
		recurse($file) if -d $file;
		$file =~ s/(\W)/\\$1/g;
		$file =~ s|\\/|/|g;
		copy_files($file,$cnt++) if $file =~ /\.xml/i;
	}
}

sub copy_files {
	my($file,$cnt) = @_;
	print STDERR "\tXML [$file]\n";
	my $folder = $file;
	$folder =~ s|/[^/]+$||;
	my $ext = scalar <$folder/*.flac>?'flac':'mp3';
	$file =~ s/\\(\W)/$1/g;
	my $buff = '';
	open(FH,'< '.$file);
	while(<FH>) {
		$buff .= $_;
	}
	close FH;
	$buff =~ s/<\?(.+?)\?>/<?xml version="1.0" encoding="ISO-8859-1"?>/;
	$buff =~ s/&/&amp;/g;
	my $xml = eval "XMLin(\$buff)";
	if($@) {
		my $err = $@;
		$err =~ s/[\r\n]/\\n/g;
		print STDERR "\tCan't parse XML doc [$file] ($err)\n";
		undef $buff;
		return undef;
	}
	undef $buff;

	unless($xml->{Album}->{Name}) {
		print STDERR "Empty album\n";
		$xml->{Album}->{Name} = 'Unknown'.$cnt;
	}

	if(ref($xml->{Album}->{Name}) eq 'HASH') {
		print STDERR "Empty album\n";
		$xml->{Album}->{Name} = 'Unknown'.$cnt;
	}

	unless($xml->{Album}->{Artist}->{Name}) {
		print STDERR "album [$xml->{Album}->{Name}] Empty artist\n";
		$xml->{Album}->{Artist}->{Name} = 'Unknown';
	}

	if(ref($xml->{Album}->{Artist}->{Name}) eq 'HASH') {
		print STDERR "album [$xml->{Album}->{Name}] Empty artist\n";
		$xml->{Album}->{Artist}->{Name} = 'Unknown';
	}

	my $newlocation = safe_chars($xml->{Album}->{Artist}->{Name}).'/'.safe_chars($xml->{Album}->{Name});
	`mkdir -p /usr/local/cmms/htdocs/media/$newlocation/` unless -d "/usr/local/cmms/htdocs/media/$newlocation/";

	my $trck_num = 1;
	foreach my $track (@{$xml->{Album}->{Track}}) {
		$track->{Index} = $track->{Index}?$track->{Index}:$trck_num;
		$trck_num++;
		$track->{Performer} = $track->{Performer}->[0] if $track->{Performer} && ref($track->{Performer}) eq 'ARRAY';
		$track->{Artist}->{Name} = 'Unknown' if ref($track->{Artist}->{Name}) eq 'HASH';
		$track->{Performer}->{Name} = '' if ref($track->{Performer}->{Name}) eq 'HASH';
		my $number = sprintf('%02d',$track->{Index});
		my($old) = <$folder/$number*.$ext>;
		next unless $old;
		$old =~ s/(\W)/\\$1/g;
		$old =~ s|\\/|/|g;
		my $newname = substr(safe_chars($number.' '.($track->{Name}?$track->{Name}:'Unknown')),0,35).".$ext";
		#print STDERR "cp $old /usr/local/cmms/htdocs/media/$newlocation/$newname\n";
		`cp $old /usr/local/cmms/htdocs/media/$newlocation/$newname` unless -f "/usr/local/cmms/htdocs/media/$newlocation/$newname";
	}

	my $discid = md5_hex($xml->{Album}->{Name});
	$xmls->{$discid} = $xml unless $xmls->{$discid};

	return 1;
}

sub import {
	my $xml = shift;

	unless($xml->{Album}->{Genre}->{Name}) {
		print STDERR "album [$xml->{Album}->{Name}] Empty genre\n";
		$xml->{Album}->{Genre}->{Name} = 'Unknown';
	}

	if(ref($xml->{Album}->{Genre}->{Name}) eq 'HASH') {
		print STDERR "album [$xml->{Album}->{Name}] Empty genre\n";
		$xml->{Album}->{Genre}->{Name} = 'Unknown';
	}

	my $discid = md5_hex($xml->{Album}->{Name});

	my $tracks = [];
	foreach my $track (@{$xml->{Album}->{Track}}) {
		my $new = new CMMS::Track::Enhanced;
		$new->number($track->{Index});
		$new->artist($track->{Performer}->{Name}?$track->{Performer}->{Name}:($track->{Artist}->{Name}?$track->{Artist}->{Name}:'Unknown'));
		$new->length($track->{Length}?($track->{Length}/75):1);
		$new->title($track->{Name});
		push @{$tracks}, $new;
	}

	unless(scalar @{$tracks}) {
		print STDERR "album [$xml->{Album}->{Name}] has no tracks\n";
		next;
	}

	my $metadata = {
		GENRE => $xml->{Album}->{Genre}->{Name},
		DISCID => $discid,
		discid => $discid,
		ARTIST => $xml->{Album}->{Artist}->{Name},
		ALBUM => $xml->{Album}->{Name},
		COMMENT => '',
		COMPOSER => '',
		CONDUCTOR => '',
		YEAR => $xml->{Album}->{Date}?$xml->{Album}->{Date}:'',
		TRACKS => $tracks
	};

	if($ripper->check($metadata)) {
		$ripper->cover($metadata);
		$ripper->store($metadata);
		#$ripper->store_xml($metadata);
	} else {
		warn "Album [$discid] [$xml->{Album}->{Name}] already ripped";
	}

	return 1;
}

sub usage {
	my $script = $0;
	$script =~ s^.+/^^;
	$script =~ s/.+\\//;

	print STDERR "Usage:\n\t$script -media [/media/usbdisk/root/]\n\n";
	exit 0;
}
