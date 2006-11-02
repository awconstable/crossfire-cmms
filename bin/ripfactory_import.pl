#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use XML::Simple;
use CDDB::File;
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
	unless(`grep ISO-8859-1 $file`) {
		print STDERR "\tChanging XML charset [$file]\n";
		my $buff = '';
		open(FH,'< '.$file);
		while(<FH>) {
			$buff .= $_;
		}
		close FH;
		$buff =~ s/<\?(.+?)\?>/<?xml version="1.0" encoding="ISO-8859-1"?>/;
		open(FH,'> '.$file);
		print FH $buff;
		close FH;
		undef $buff;
	}
	$file =~ s/\\(\W)/$1/g;
	my $xml = eval "XMLin(\$file)";
	if($@) {
		my $err = $@;
		$err =~ s/[\r\n]/\\n/g;
		print STDERR "\tCan't parse XML doc [$file] ($err)\n";
		return undef;
	}

	unless($xml->{Album}->{Name}) {
		print STDERR "Empty album\n";
		$xml->{Album}->{Name} = 'Unknown'.$cnt;
	}

	unless($xml->{Album}->{Artist}->{Name}) {
		print STDERR "album [$xml->{Album}->{Name}] Empty artist\n";
		$xml->{Album}->{Artist}->{Name} = 'Unknown';
	}

	my $discid = md5_hex($xml->{Album}->{Name});
	$xmls->{$discid} = $xml unless $xmls->{$discid};
	#return 1;

	my $newlocation = safe_chars($xml->{Album}->{Artist}->{Name}).'/'.safe_chars($xml->{Album}->{Name});
	`mkdir -p /usr/local/cmms/htdocs/media/$newlocation/` unless -d "/usr/local/cmms/htdocs/media/$newlocation/";

	foreach my $track (@{$xml->{Album}->{Track}}) {
		my $number = sprintf('%02d',$track->{Index}?$track->{Index}:1);
		my($old) = <$folder/$number*.$ext>;
		next unless $old;
		$old =~ s/(\W)/\\$1/g;
		$old =~ s|\\/|/|g;
		my $newname = substr(safe_chars($number.' '.($track->{Name}?$track->{Name}:'Unknown')),0,35).".$ext";
		#print STDERR "cp $old /usr/local/cmms/htdocs/media/$newlocation/$newname\n";
		`cp $old /usr/local/cmms/htdocs/media/$newlocation/$newname` unless -f "/usr/local/cmms/htdocs/media/$newlocation/$newname";
	}

	return 1;
}

sub import {
	my $xml = shift;

	unless($xml->{Album}->{Genre}->{Name}) {
		print STDERR "album [$xml->{Album}->{Name}] Empty genre\n";
		$xml->{Album}->{Genre}->{Name} = 'Unknown';
	}

	my $discid = md5_hex($xml->{Album}->{Name});

	my $total = 0;
	my $tracks = [];
	my $offsets = [];

	foreach my $track (@{$xml->{Album}->{Track}}) {
		push @{$offsets}, ($total*75);
		$total += (($track->{Length}?$track->{Length}:1)/75);
		push @{$tracks}, {
			track_num => $track->{Index}?$track->{Index}:1,
			artist    => $track->{Artist}->{Name}?$track->{Artist}->{Name}:'Unknown',
			title     => $track->{Name}?$track->{Name}:'Unknown'
		};
	}

	unless(scalar @{$offsets}) {
		print STDERR "album [$xml->{Album}->{Name}] has no tracks\n";
		next;
	}

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
DISCID=$discid
DTITLE=$xml->{Album}->{Artist}->{Name} / $xml->{Album}->{Name}
".join("\n",map{'TTITLE'.($_->{track_num}-1)."=$_->{title}"}@{$tracks})."
EXTD=
".join("\n",map{'EXTT'.($_->{track_num}-1).'='.($_->{comment}?$_->{comment}:'')}@{$tracks})."
PLAYORDER=
";
	close(CDDB);

	my $albumdata = new CDDB::File('/tmp/album.cddb');

	my @tracks = $albumdata->tracks;

	my $metadata = {
		GENRE => $xml->{Album}->{Genre}->{Name},
		DISCID => $discid,
		discid => $discid,
		ARTIST => $xml->{Album}->{Artist}->{Name},
		ALBUM => $xml->{Album}->{Name},
		COMMENT => '',
		YEAR => '',
		TRACKS => \@tracks
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
