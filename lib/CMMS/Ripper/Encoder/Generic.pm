package CMMS::Ripper::Encoder::Generic;

use strict;
use warnings;
use IO::LCDproc;
use CMMS::File;

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1
};
our($AUTOLOAD);

#############################################################
# Constructor
#
sub new {
	my $class = shift;
	my (%params) = @_;

	die('No config') unless $params{conf};
	die('No mysql connection') unless $params{mc};
	die('No metadata') unless $params{metadata};

	my $self = {};
	$self->{conf} = $params{conf};
	$self->{metadata} = $params{metadata};

	bless $self, $class;
	$self->mysqlConnection($params{mc});

	return $self;
}

sub initialise {
	my $self = shift;

	$self->{client}  = IO::LCDproc::Client->new(name => 'lamer', host => $self->{conf}->{ripper}->{lcdhost}, port => $self->{conf}->{ripper}->{lcdport});
	$self->{screen}  = IO::LCDproc::Screen->new(name => 'lamer', client => $self->{client});
	$self->{title}   = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'title', type => 'title');
	$self->{status}  = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'track',  xPos => 1,  yPos => 2);
	$self->{setings} = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'setings', xPos => 1,  yPos => 3);
	$self->{detail}  = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'detail', xPos => 1,  yPos => 4);
	$self->{client}->add($self->{screen});
	$self->{screen}->add($self->{title}, $self->{setings}, $self->{status}, $self->{detail});
	$self->{client}->connect or die("Can't connect to LCD: $!");
	$self->{client}->initialize;

	$self->{title}->set(data => 'CMMS - encoding');
	print STDERR "CMMS - encoding\n";

	return $self;
}

#############################################################
# AUTOLOAD restrict method aliases
#
sub AUTOLOAD {
	my $self = shift;
	die("$self is not an object") unless my $type = ref($self);
	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	die("Can't access '$name' field in object of class $type") unless( exists $permitted->{$name} );

	return (@_?$self->{$name} = shift:$self->{$name});
}

#############################################################
# DESTROY
#
sub DESTROY {
	my $self = shift;
}

sub encode {
	my($self,$metadata) = @_;

	$self->initialise;

	$self->{title}->set(data => ($metadata->{ALBUM}=~/^unknown/i?'Unknown Album':$metadata->{ALBUM}));
	print STDERR $metadata->{ALBUM}."\n";

	my $tmp = $self->{conf}->{ripper}->{tmpdir};

	foreach my $track (@{$metadata->{TRACKS}}) {
		my $artist = $track->artist;
		$artist = 'Unknown' if $artist =~ /^unknown/i;
		my $file = safe_chars(sprintf('%02d',$track->number).' '.$artist.' '.$track->title);
		if(-f "$tmp$file.wav") {
			print STDERR "$tmp$file.wav\n";
			$self->_encode($track->number,$track->title,$track->artist,$metadata->{ALBUM},$metadata->{COMMENT},$metadata->{YEAR},$metadata->{GENRE},$metadata->{ARTIST});
		}
	}

	$self->{status}->set(data => '');
	$self->{setings}->set(data => '');
	$self->{detail}->set(data => 'All tracks encoded');
	print STDERR "All tracks encoded\n";

	sleep 2;

	# IO::LCDproc don't provide disconnect method!
	undef $self->{client}->{lcd};
	$self->{client}->{lcd} = undef;
	undef $self->{client};
	$self->{client} = undef;

	return 1;
}

1;
