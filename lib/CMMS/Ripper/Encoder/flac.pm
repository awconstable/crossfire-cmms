package CMMS::Ripper::Encoder::flac;

use strict;
use warnings;
use base qw(CMMS::Ripper::Encoder::Generic);
use CMMS::Psudo;
use CMMS::File;
use Audio::TagLib;
use POSIX qw(:sys_wait_h);

sub _encode {
	my($self,$number,$track,$artist,$album,$comment,$year,$genre,$aartist) = @_;
	($number,$track,$artist,$album,$comment,$year,$genre,$aartist) = map{s/[\r\n+]//g;$_}($number,$track,$artist,$album,$comment,$year,$genre,$aartist);

	$artist = 'Unknown' if $artist =~ /^unknown/i;

	$self->{status}->set(data => 'Flac Encoding '.sprintf('%02d',$number));
	print STDERR 'Flac Encoding track '.sprintf('%02d',$number)."\n";

	my $file = substr(safe_chars(sprintf('%02d',$number)." $track"),0,35);
	my $tmp = $self->{conf}->{ripper}->{tmpdir};

	print STDERR "$tmp$file.flac\n";

	my($FLAC,$pid) = psudo_tty("nice -n 10 flac $tmp$file.wav -o $tmp$file.flac 2>&1");

	my $oprog = '';
	$self->{setings}->set(data => (length($track)>20?substr($track,0,20):$track));

	while(sysread $FLAC,$_,250) {
		if(/.+: ([0-9]+)% complete, ratio=([0-9\.]+)/) {
        		my $prog = sprintf("%3s%%  %s", $1, $2);
			if($oprog ne $prog) {
				$self->{detail}->set(data => $prog);
				$oprog = $prog;
			}
		}

		if(/wrote/) {
			$self->{status}->set(data => 'Encoding done');
			print STDERR "Encoding done\n";
			last;
		}

		if(/can't open input file/ || /ERROR/ || /unexpected EOF/) {
			$self->{status}->set(data => 'Encoding error');
			print STDERR "Encoding error: $_\n";
			`rm -f $tmp$file.flac` if -f "$tmp$file.flac";
			last;
		}
	}

	kill 9, $pid;
	close($FLAC);
	waitpid $pid, 0;

	if(-f "$tmp$file.flac") {
		my($artist1,$album1,$track1) = map{s/"/\\"/g;$_}($artist,$album,$track);
		$aartist = safe_chars($aartist);
		$album = safe_chars($album);

		my $flac = new Audio::TagLib::FLAC::File("$tmp$file.flac");
		my $xiph = $flac->xiphComment(1);

		$xiph->setAlbum(new Audio::TagLib::String($album1))   if $album;
		$xiph->setArtist(new Audio::TagLib::String($artist1)) if $artist;
		$xiph->setTitle(new Audio::TagLib::String($track1))   if $track;
		$xiph->setTrack($number)                              if $number;
		$xiph->setYear(new Audio::TagLib::String($year))      if $year;
		$xiph->setGenre(new Audio::TagLib::String($genre))    if $genre;

		$flac->save;

		$aartist = safe_chars($aartist);
		$album = safe_chars($album);

		my $folder = $self->{conf}->{ripper}->{mediadir}."$aartist/$album/";

		`mkdir -p $folder` unless -d $folder;
		`mv $tmp$file.flac $folder`;
		`chown nobody:nobody $folder$file.flac` if -f "$folder$file.flac";
		print STDERR "mv $tmp$file.flac $folder\n";
	}

	return 1;
}

1;
