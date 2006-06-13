package CMMS::Ripper::Extractor::cdparanoia;

use strict;
use warnings;
use base qw(CMMS::Ripper::Extractor::Generic);
use CMMS::Psudo;
use CMMS::File;

our %smilies = (
#             12345678901234567890
    '8-X' => 'finished & skipped  ',
    ':^D' => 'finished / no jitter',
    ':-)' => 'normal / low jitter ',
    ':-|' => 'normal, overlap > 1 ',
    ':-/' => 'drift               ',
    ':-P' => 'un.loss of streaming',
    '8-|' => 'dropped/duped bytes ',
    ':-0' => 'scsi error          ',
    ':-(' => 'scratch             ',
    ';-(' => 'skip                '
);

our($CDPARANOIA,$pid);
$SIG{ALRM} = \&_grim_reaper;

sub _rip {
	my($self,$number,$track,$artist) = @_;
	$number =~ s/[\r\n+]//g;
	$track =~ s/[\r\n+]//g;
	$artist =~ s/[\r\n+]//g;
	$artist = 'Unknown' if $artist =~ /^unknown/i;

	$self->{detail}->set(data => (length($track)>20?substr($track,0,17).'...':$track));
	print STDERR (length($track)>20?substr($track,0,17).'...':$track)."\n";
	$self->{track}->set(data => 'track: '.sprintf('%02d',$number));
	print STDERR 'track: '.sprintf('%02d',$number)."\n";

	my $file = safe_chars(sprintf('%02d',$number)." $artist $track");
	my $tmp = $self->{conf}->{tmpdir};

	($CDPARANOIA,$pid) = psudo_tty("cdparanoia -w -e $number $tmp$file.wav");

	my $rawsize = 2352;
	my($from_sec,$to_sec,$range);
	my($oper,$oprog,$osmilie,$hb) = ('','','','.');
	my $smilies = join('|',map{s/([\/\^\)\(\|])/\\$1/;$_}keys %smilies);

	alarm 5;

	while(<$CDPARANOIA>) {
		# trap error
		if (/^004:\s(.*)$/) {
			$self->{detail}->set(data => 'Unable to read CD.');
			close($CDPARANOIA);
			sleep 1; # wait for display.. there is no rush..
			warn($1);
			return undef;
		}

		if(/^Ripping from sector\s+([0-9]+)\s/) {
			$from_sec = $1;
			$_ = <$CDPARANOIA>;
			($to_sec) = /to sector\s+([0-9]+)\s/;
			$range = $to_sec - $from_sec;
		}

		$hb = $1 if /(.)\|/;

		if(/\[wrote\] \@ ([0-9]+)/) {
			my $sector = ((1+$1) / ($rawsize/2)) - 1;
			my $per = (100*($sector-$from_sec)/$range);

			my $prog = ($per>1?(($per/20)*4)-1:0);
			$prog = join('',map{'='}(1..$prog)).'>';

			$per = sprintf('rip:%3d%% %s',$per,$hb);

			if($oper ne $per) {
				$self->{status}->set(data => $per);
				$oper = $per;
			}

			if($oprog ne $prog) {
				$self->{pg_bar}->set(data => $prog);
				$oprog = $prog;
			}
		}

		if(/($smilies)/ && $smilies{$1} && $osmilie ne $1) {
			$self->{detail}->set(data => $smilies{$1});
			print STDERR $smilies{$1}."\n";
			$osmilie = $1;

			if($1 =~ /^:-0|;-\(|8-X|8-\|:-P$/) {
				$self->{detail}->set(data => 'Read Error-skipping');
				kill(9,$pid); # we must drastically kill cdparanoia :(
				close($CDPARANOIA);
				warn('Unable to rip track');
				return undef;
				last;
			}

		}

		if(/\[(.+)?(e|V)(.+)?\|/) {
			$self->{detail}->set(data => 'Read Error-skipping');
			kill(9,$pid); # we must drastically kill cdparanoia :(
			close($CDPARANOIA);
			warn('Unable to rip track');
			return undef;
			last;
		}

		if(/non audio track/) {
			$self->{status}->set(data => 'rip: 0%');
			$self->{detail}->set(data => 'Non audio track');
			print STDERR "Track $number non audio\n";
			last;
		}

		if(/Done./) {
			$self->{status}->set(data => 'rip: done');
			print STDERR "rip: done\n";
			last;
		}
	}

	close($CDPARANOIA);

	alarm 0;

	return 1;
}

# Must kill off old processes if they have fallen over
sub _grim_reaper {
	if($_ = `ps -efww | grep perl | grep ripper | awk {'print \$2'}`) {
		foreach(split("\n",$_)) {
			kill(9,$_) if $_ ne $$;
		}
	}

	alarm 5;

	return undef;
}

1;
