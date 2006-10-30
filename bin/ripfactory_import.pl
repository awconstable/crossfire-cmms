#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use XML::Simple;
use CDDB::File;
use CMMS::Ripper;
use CMMS::File;
use Digest::MD5 qw(md5_hex);

my($base,$help);
GetOptions(
	'base=s' => \$base,
	help => \$help
);

&usage if $help || !$base;

my $xmls = {};
recurse($base);

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
		copy_files($file) if $file =~ /\.xml/i;
	}
}

sub copy_files {
	my $file = shift;
	print STDERR "\tFiles [$file]\n";
	$file =~ s/\\(\W)/$1/g;
	my $xml = eval "XMLin(\$file)";
	return undef if $@;

	my $discid = md5_hex($xml->{Album}->{Name});
	$xmls->{$discid} = $file unless $xmls->{$discid};

	my $folder = $file;
	$folder =~ s|/[^/]+$||;
	$folder =~ s/(\W)/\\$1/g;
	$folder =~ s|\\/|/|g;
	my $ext = scalar <$folder/*.flac>?'flac':'mp3';

	my $newlocation = safe_chars($xml->{Album}->{Artist}->{Name}).'/'.safe_chars($xml->{Album}->{Name});
	`mkdir -p /usr/local/cmms/htdocs/media/$newlocation/` unless -d "/usr/local/cmms/htdocs/media/$newlocation/";

	foreach my $track (@{$xml->{Album}->{Track}}) {
		my $number = sprintf('%02d',$track->{Index});
		my($old) = <$folder/$number*.$ext>;
		$old =~ s/(\W)/\\$1/g;
		$old =~ s|\\/|/|g;
		my $newname = substr(safe_chars($number.' '.$track->{Name}),0,35).".$ext";
		print STDERR "cp $old /usr/local/cmms/htdocs/media/$newlocation/$newname\n";
		`cp $old /usr/local/cmms/htdocs/media/$newlocation/$newname` unless -f "/usr/local/cmms/htdocs/media/$newlocation/$newname";
	}

	return 1;
}

sub import {
	my $file = shift;
	print STDERR "\tXML [$file]\n";
	my $xml = eval "XMLin(\$file)";
	return undef if $@;

	my $discid = md5_hex($xml->{Album}->{Name});

	my $total = 0;
	my $tracks = [];
	my $offsets = [];

	foreach my $track (@{$xml->{Album}->{Track}}) {
		push @{$offsets}, ($total*75);
		$total += ($track->{Length}/75);
		push @{$tracks}, {
			track_num => $track->{Index},
			artist    => $track->{Artist}->{Name},
			title     => $track->{Name}
		};
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

	print STDERR "Usage:\n\t$script -base [/media/usbdisk/root/]\n\n";
	exit 0;
}
