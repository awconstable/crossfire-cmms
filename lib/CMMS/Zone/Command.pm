package CMMS::Zone::Command;

use Quantor::Log;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
$VERSION = 1.00;
@ISA = qw(Exporter);
@EXPORT  = qw(&cmd2hash &hash2cmd &printcmdhash &check_cmd &send2player);

my $send_sep = '||';
my $recv_sep_regex = '\|';
my $value_sep = ':';

# create command from source hash
sub hash2cmd {
  my (%hash) = @_;
  if (defined($hash{zone}) && defined($hash{cmd})) {
    my @arr;
    my $line;
    my ($k, $v);
    my $i = 0;
    # make sure that zone is 1st and cmd 2nd!
    $arr[$i++] = "zone" . $value_sep . $hash{zone};
    $arr[$i++] = "cmd"  . $value_sep . $hash{cmd};
    delete($hash{zone});
    delete($hash{cmd});
    
    while ( ($k,$v) = each %hash ) {
        $arr[$i++] = $k . $value_sep . $v;
    }
    $line = join ($send_sep, @arr);
    return $line."\r\n";
  } else {
#     print STDERR "Incorrect command definition\n";
#     return 0;
  }
}

sub printcmdhash {
  my (%hash) = @_;
  print map { "$_ => $hash{$_}\n" } keys %hash;
}

# create hash from received line
sub cmd2hash {
	$_ = shift;
	s/\?/\\\\?/g;
	s/\*/\\\\*/g;
  @_ = split($recv_sep_regex, $_);
  my %myhash;
  foreach (<@_>) {
    # print "$_\n";
    next unless /$value_sep/; # skip incorrect records (without ':')
    my ($key, $value) = split($value_sep, $_, 2); # ___:______________
    $myhash{$key} = $value;
  }
  return %myhash;
}

sub check_cmd {
  my ($cmd, $zone) = @_;
  return 0 unless exists $cmd->{zone};   # zone must be defined
  return 0 unless $cmd->{zone} == $zone; # are that data for us?
  return 0 unless exists $cmd->{screen}; # we need to recognize screen
  return 0 unless exists $cmd->{cmd};    # and command would be nice, pls.
  1;
}

sub send2player {
  my ($handle, $command) = @_;
  qlog INFO, "Sending to player '$command'";
  print $handle $command, "\n";
}

1;
