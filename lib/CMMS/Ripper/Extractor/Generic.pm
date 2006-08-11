package CMMS::Ripper::Extractor::Generic;

use strict;
use warnings;
use IO::LCDproc;

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
	$self->{loghandle} = $params{loghandle};
	$self->{timeout} = 0;

	bless $self, $class;
	$self->mysqlConnection($params{mc});

	return $self;
}

sub add_to_log {
    my( $self, $level, $module, $message ) = @_;

    my $lh = $self->{loghandle};
    $lh or return undef;

    $module = "[$module]";
    $level = "[$level]";
    chomp($message);

    print $lh sprintf("%-16s %-24s %-80s\n", $level, $module, $message);
}

sub initialise {
	my $self = shift;

	$self->add_to_log( "INFO", "ripper/generic", "Initisalising LCD screen" );

	$self->{client} = IO::LCDproc::Client->new(name => 'ripper', host => $self->{conf}->{ripper}->{lcdhost}, port => $self->{conf}->{ripper}->{lcdport});
	$self->{screen} = IO::LCDproc::Screen->new(name => 'screen', client => $self->{client});
	$self->{title}  = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'title', type => 'title');
	$self->{track}  = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'track',  xPos => 1,  yPos => 2);
	$self->{status} = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'status', xPos => 11, yPos => 2);
	$self->{detail} = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'detail', xPos => 1,  yPos => 3);
	$self->{pg_bar} = IO::LCDproc::Widget->new(screen => $self->{screen}, name => 'pg_bar', xPos => 1,  yPos => 4);
	$self->{client}->add($self->{screen});
	$self->{screen}->add($self->{title}, $self->{status}, $self->{pg_bar}, $self->{track}, $self->{detail});

	unless( $self->{client}->connect ) {
	    $self->add_to_log( "INFO", "ripper/generic", "Failed to connect to the LCD screen" );	    
	    die ("Can't connect to LCD: $!");
	}
	$self->{client}->initialize;

	$self->{title}->set(data => 'CMMS - Jack The Ripper!');
	print STDERR "CMMS - Jack The Ripper!\n";

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

sub rip {
	my($self,$metadata) = @_;

	$self->initialise;

	$self->{title}->set(data => $metadata->{ALBUM});
	$self->add_to_log( "INFO", "ripper/generic", "Starting RIP of ".$metadata->{ALBUM} );	    
	print STDERR $metadata->{ALBUM}."\n";

	foreach my $track (@{$metadata->{TRACKS}}) {
	    $self->add_to_log( "INFO", "ripper/generic", "Ripping ".$track->title );	    
	    eval "\$self->_rip(\$track->number,\$track->title,\$track->artist)";
	    $self->{timeout} = 1 if $@ && $@ =~ /Ripping timed out/;
	}

	$self->{track}->set(data => '');
	$self->{status}->set(data => '');
	$self->{pg_bar}->set(data => '');
	$self->{detail}->set(data => 'Normalizing tracks');
	print STDERR "Normalizing tracks\n";
	$self->add_to_log( "INFO", "ripper/generic", "Normalizing tracks for ".$metadata->{ALBUM} );	    

	# Normalize wav volume
	`normalize -b $self->{conf}->{ripper}->{tmpdir}*.wav`;

	$self->{detail}->set(data => 'All tracks ripped');
	print STDERR "All tracks ripped\n";
	$self->add_to_log( "INFO", "ripper/generic", "Rip complete" );	    

	sleep 2;

	# IO::LCDproc don't provide disconnect method!
	undef $self->{client}->{lcd};
	$self->{client}->{lcd} = undef;
	undef $self->{client};
	$self->{client} = undef;

	return undef if $self->{timeout};
	return 1;
}

1;
