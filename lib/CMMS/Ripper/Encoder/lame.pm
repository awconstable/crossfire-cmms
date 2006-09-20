package CMMS::Ripper::Encoder::lame;

use strict;
use warnings;
use base qw(CMMS::Ripper::Encoder::Generic);
use CMMS::Psudo;
use CMMS::File;
use MP3::Tag;
use POSIX qw(:sys_wait_h);

sub _encode {
	my($self,$number,$track,$artist,$album,$comment,$year,$genre,$aartist) = @_;
	($number,$track,$artist,$album,$comment,$year,$genre,$aartist) = map{s/[\r\n+]//g;$_}($number,$track,$artist,$album,$comment,$year,$genre,$aartist);

	$artist = 'Unknown' if $artist =~ /^unknown/i;

	$self->{status}->set(data => 'MP3 Encoding '.sprintf('%02d',$number));
	print STDERR 'MP3 Encoding track '.sprintf('%02d',$number)."\n";

	my $file = safe_chars(sprintf('%02d',$number)." $artist $track");
	my $tmp = $self->{conf}->{ripper}->{tmpdir};

	print STDERR "$tmp$file.mp3\n";

	my($LAME,$pid) = psudo_tty("lame -b 160 $tmp$file.wav $tmp$file.mp3 2>&1");

	my($oprog,$orate) = ('','44.1 kHz 160 kbps');
	$self->{setings}->set(data => $orate);

	while(1) {
		sysread $LAME,$_,100;

		if(/
      \d+\/\d+\s+     # 300 6288   
	\(\s*(\d+)%\)	# ( 5%)           $1
	\|\s*\d+\:\d+	# CPU time
	\/\s*\d+\:\d+	# CPU time estim
	\|\s*\d+\:\d+	# REAL time
	\/\s*\d+\:\d+	# REAL time estim
	\|\s*(\d+\.\d+x)# play CPU        $2
	\|\s*(\d+:\d+)	# ETA             $3
      /x) {
        		my $prog = sprintf("%3s%%  %s  %s", $1, $2, $3);
			if($oprog ne $prog) {
				$self->{detail}->set(data => $prog);
				$oprog = $prog;
			}
		}

		if(/([0-9\.]+ kHz [0-9]+ kbps)/ || /([0-9\.]+ kHz VBR\(q=[0-9]+\))/) {
			my $rate = $1;
			if($orate ne $rate) {
				$self->{setings}->set(data => $rate);
				print STDERR "$rate\n";
				$orate = $rate;
			}
		}

		if(/\.done/) {
			$self->{status}->set(data => 'Encoding done');
			print STDERR "Encoding done\n";
			last;
		}

		if(/Could not find/) {
			$self->{status}->set(data => 'Encoding error');
			print STDERR "Encoding error: $_\n";
			last;
		}
	}

	kill 9, $pid;
	close($LAME);
	waitpid $pid, 0;

	my($artist1,$album1,$track1,$comment1) = map{s/"/\\"/g;$_}($artist,$album,$track,$comment);

	my $mp3 = MP3::Tag->new("$tmp$file.mp3");
	my $id3v2 = $mp3->new_tag('ID3v2');

	$id3v2->add_frame('TALB',$album1) if $album;
	$id3v2->add_frame('TPE1',$artist1) if $artist;
	$id3v2->add_frame('TIT2',$track1) if $track;
	$id3v2->add_frame('COMM',$comment1) if $comment;
	$id3v2->add_frame('TRCK',$number) if $number;
	$id3v2->add_frame('TPRO',"$year ") if $year;
	$id3v2->add_frame('TCON',$genre) if $genre;
	$id3v2->write_tag;

	$aartist = safe_chars($aartist);
	$album = safe_chars($album);
	$comment = substr(safe_chars($comment),0,32);

	my $folder = $self->{conf}->{ripper}->{mediadir}."$aartist/$album/";
	$folder .= "$comment/" if $comment;

	`mkdir -p $folder` unless -d $folder;
	`mv $tmp$file.mp3 $folder` if -f "$tmp$file.mp3";
	print STDERR "mv $tmp$file.mp3 $folder\n";

	return 1;
}

1;
