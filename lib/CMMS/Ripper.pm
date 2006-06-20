package CMMS::Ripper;

use strict;
use warnings;
use Config::General;
use URI::Escape;
use LWP;
use CMMS::File;
use CMMS::Database::MysqlConnection;

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1
};
our $VERSION = '1.00';
our($AUTOLOAD);

#############################################################
# Constructor
#
sub new {
	my $class = shift;
	my (%params) = @_;

	die('No config') unless $params{conf};

	my $self = {};

	my %conf = ParseConfig($params{conf});
	@_ = split(',',$conf{encoder});
	$conf{encoder} = \@_;
	$conf{mediadir} =~ s/\/$//;
	$conf{mediadir} .= '/';
	$conf{tmpdir} =~ s/\/$//;
	$conf{tmpdir} .= '/';

	$self->{conf} = \%conf;

	my $db = $self->{conf}->{mysql};
	my $mc = new CMMS::Database::MysqlConnection;
	$mc and $db->{host} and $mc->host( $db->{host} );
	$mc and $db->{database} and $mc->database( $db->{database} );
	$mc and $db->{user} and $mc->user( $db->{user} );
	$mc and $db->{password} and $mc->password( $db->{password} );
	$mc and $mc->connect || die("Can't connect to database '".$mc->database."' on '".$mc->host."' with user '".$mc->user."'");

	my $metadata = $self->{conf}->{ripper}->{metadata};
	eval "use CMMS::Ripper::DiscID::$metadata;\n\$self->{metadata} = new CMMS::Ripper::DiscID::$metadata(mc => \$mc, conf => \$self->{conf}->{ripper})";
	die("Problem loading metadata $metadata: $@") if $@;

	my $ripper = $self->{conf}->{ripper}->{ripper};
	eval "use CMMS::Ripper::Extractor::$ripper;\n\$self->{ripper} = new CMMS::Ripper::Extractor::$ripper(mc => \$mc, metadata => \$self->{metadata}, conf => \$self->{conf}->{ripper})";
	die("Problem loading ripper $ripper: $@") if $@;

	$self->{encoder} = [];
	foreach my $encoder (@{$self->{conf}->{ripper}->{encoder}}) {
		eval "use CMMS::Ripper::Encoder::$encoder;\n push(\@{\$self->{encoder}},new CMMS::Ripper::Encoder::$encoder(mc => \$mc, metadata => \$self->{metadata}, conf => \$self->{conf}->{ripper}))";
		die("Problem loading encoder $encoder: $@") if $@;
	}

	bless $self, $class;
	$self->mysqlConnection($mc);

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

	return $self->amazon_cover(@_) if $name eq 'cover';

	my $str = join('|',keys %{$permitted});

	unless($name =~ /^$str$/) {
		my $ret = undef;
		$_ = 0;
		foreach my $encoder (@{$self->{encoder}}) {
			eval "\$encoder->$name(\@_)";
			$_ = 1 unless $@;
			die($@) if $@ && !($@ =~ /field in object of class/);
		}
		return 1 if $_;

		eval "\$ret = \$self->{metadata}->$name(\@_)";
		return $ret unless $@;
		die($@) if $@ && !($@ =~ /field in object of class/);

		eval "\$ret = \$self->{ripper}->$name(\@_)";
		return $ret unless $@;
		die($@) if $@ && !($@ =~ /field in object of class/);
	}

	die("Can't access '$name' field in object of class $type") unless( exists $permitted->{$name} );

	return (@_?$self->{$name} = shift:$self->{$name});
}

#############################################################
# DESTROY
#
sub DESTROY {
	my $self = shift;
	my $mc = $self->mysqlConnection;
	$mc->{dbh} and $mc->{dbh}->disconnect;
}

sub amazon_cover {
	my($self,$meta) = @_;
	my $url_cover = '';

	my $params = {
		SubscriptionId => $self->{conf}->{ripper}->{amazonid},
		Operation => 'ItemSearch',
		SearchIndex => 'Music',
		Artist => $meta->{ARTIST},
		Title => $meta->{ALBUM},
		ResponseGroup => 'Images'
	};

	my $url = $self->{conf}->{ripper}->{amazonurl}.join('&',map{"$_=".uri_escape($params->{$_})}keys %{$params});

	my $ua = new LWP::UserAgent;
	my $res = $ua->get($url);
	my $xml = $res->content;

	unless($res->is_success && $xml) {
		warn "Couldn't connect to Amazon's Web Services: $url";
		return undef;
	}

	$url_cover = $1 if $xml =~ /<LargeImage>.*<URL>(.+)<\/URL>.*<\/LargeImage>/;
	$url_cover = $1 if $xml =~ /<MediumImage>.*<URL>(.+)<\/URL>.*<\/MediumImage>/;

	unless($url_cover) {
		warn "Couldn't retrieve Amazon cover for: $meta->{ARTIST}, $meta->{ALBUM}";
		return undef;
	}

	my($ext) = ($url_cover =~ /\.([^\.]+)$/);
	$res = $ua->get($url_cover);
	my $img = $res->content;

	unless($res->is_success && $img) {
		warn "Couldn't connect to Amazon's cover: $url_cover";
		return undef;
	}

	warn "Amazon cover image url: $url_cover";

	my $artist = safe_chars($meta->{ARTIST});
	my $album = safe_chars($meta->{ALBUM});
	my $comments = safe_chars($meta->{COMMENTS});
	my $folder = $self->{conf}->{ripper}->{mediadir}."$artist/$album/";
	$folder .= "$comments/" if $comments;
	`mkdir -p $folder` unless -d $folder;

	open(IMG,"> ${folder}cover.$ext");
	binmode IMG;
	print IMG $img;
	close(IMG);

	return 1;
}

sub store {
	my($self,$meta) = @_;

	my $aartist = safe_chars($meta->{ARTIST});
	my $album = safe_chars($meta->{ALBUM});
	my $comments = substr(safe_chars($meta->{COMMENTS}),0,32);
	my $folder = $self->{conf}->{ripper}->{mediadir}."$aartist/$album/";
	$folder .= "$comments/" if $comments;
	$folder =~ s/\/$//;

	print STDERR "$folder\n";

	die("No tracks for this album") unless scalar grep{/\.(mp3|flac|ogg|wav)$/}<$folder/*> > 0; # Don't store album if no tracks

	my $mc = $self->mysqlConnection;

	my($sql,$artist_id,$album_id,$genre_id);

	$mc->query('INSERT INTO album (name,discid,year) VALUES('.$mc->quote($meta->{ALBUM}).','.$mc->quote($meta->{DISCID}).','.$mc->quote($meta->{YEAR}).')');
	$album_id = $mc->last_id;

	$sql = 'SELECT id FROM genre WHERE name = '.$mc->quote($meta->{GENRE});
	($_) = @{$mc->query_and_get($sql)||[]};
	$genre_id = $_->{id} || -1;

	foreach my $track (@{$meta->{TRACKS}}) {
		my $track_num = sprintf('%02d',$track->number);
		my @files = grep{/\.(mp3|flac|ogg|wav)$/}<$folder/${track_num}_*>;
		next unless scalar @files;

		my $artist = $mc->quote(($track->artist =~ /Unknown/?'Unknown':$track->artist));
		($_) = @{$mc->query_and_get('SELECT id FROM artist WHERE name = '.$artist)||[]};
		$artist_id = 0;
		unless($artist_id = $_->{id}) {
			$mc->query('INSERT INTO artist (name) VALUES('.$artist.')');
			$artist_id = $mc->last_id;
		}
		$sql = 'INSERT INTO track (album_id,artist_id,genre_id,title,track_num,length_seconds,ctime) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($album_id,$artist_id,$genre_id,$track->title,$track->number,$track->length)).',NOW())';
		$mc->query($sql);

		my $track_id = $mc->last_id;

		foreach(@files) {
			print STDERR "$_\n";
			my($file_location,$file_name,$file_type) = (/^(.+\/)([^\/]+\.(.+))$/);
			my $filesize = -s $_;
			my $bitrate = (/\.mp3$/?160:'');
			$sql = 'INSERT INTO track_data (track_id,file_location,file_name,file_type,bitrate,filesize,info_source) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($track_id,$file_location,$file_name,$file_type,$bitrate,$filesize,$self->{conf}->{ripper}->{metadata})).')';
			$mc->query($sql);
		}

	}
}

sub check {
	my($self,$meta) = @_;

	my $mc = $self->mysqlConnection;

	($_) = @{$mc->query_and_get('SELECT id FROM album WHERE discid = '.$mc->quote($meta->{DISCID}))||[]};
	if($_->{id}) {
		warn('Album already ripped');
		return 0;
	}

	return 1;
}

sub purge {
	my $self = shift;
	my $tmp = $self->{conf}->{ripper}->{tmpdir};

	`rm -f $tmp*.wav`;
}

1;
