package CMMS::Ripper;

use strict;
use warnings;
use Config::General;
use URI::Escape;
use LWP;
use CMMS::File;
use CMMS::Database::MysqlConnection;
use FileHandle;

our $permitted = {
	mysqlConnection => 1,
	verbose         => 1,
	logfile         => 1,
        loghandle       => 1,
};
our $VERSION = '1.1.0';
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
	@_ = split(',',$conf{ripper}->{encoder});
	$conf{ripper}->{encoder} = \@_;
	$conf{ripper}->{mediadir} =~ s/\/$//;
	$conf{ripper}->{mediadir} .= '/';
	$conf{ripper}->{tmpdir} =~ s/\/$//;
	$conf{ripper}->{tmpdir} .= '/';

	$self->{conf} = \%conf;

	my $db = $self->{conf}->{mysql};
	my $mc = new CMMS::Database::MysqlConnection;
	$mc and $db->{host} and $mc->host( $db->{host} );
	$mc and $db->{database} and $mc->database( $db->{database} );
	$mc and $db->{user} and $mc->user( $db->{user} );
	$mc and $db->{password} and $mc->password( $db->{password} );
	$mc and $mc->connect || die("Can't connect to database '".$mc->database."' on '".$mc->host."' with user '".$mc->user."'");

	$self->{logfile} = $conf{ripper}->{log};

	if( $self->{logfile} ) {
	    my $fh = new FileHandle( ">>".$self->{logfile} );
	    if( $fh ) {
		$self->{loghandle} = $fh;
	    }
	    else {
		warn "Could not open ripper log file";
	    }
	}

	my $metadata = $self->{conf}->{ripper}->{metadata};
	eval "use CMMS::Ripper::DiscID::$metadata;\n\$self->{metadata} = new CMMS::Ripper::DiscID::$metadata(mc => \$mc, conf => \$self->{conf}, loghandle=>\$self->{loghandle})";
	die("Problem loading metadata $metadata: $@") if $@;

	my $ripper = $self->{conf}->{ripper}->{ripper};
	eval "use CMMS::Ripper::Extractor::$ripper;\n\$self->{ripper} = new CMMS::Ripper::Extractor::$ripper(mc => \$mc, metadata => \$self->{metadata}, conf => \$self->{conf}, loghandle=>\$self->{loghandle})";
	die("Problem loading ripper $ripper: $@") if $@;

	$self->{encoder} = [];
	foreach my $encoder (@{$self->{conf}->{ripper}->{encoder}}) {
		eval "use CMMS::Ripper::Encoder::$encoder;\n push(\@{\$self->{encoder}},new CMMS::Ripper::Encoder::$encoder(mc => \$mc, metadata => \$self->{metadata}, conf => \$self->{conf}, loghandle => \$self->{loghandle}))";
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

sub add_to_log {
    my( $self, $level, $module, $message ) = @_;

    my $lh = $self->{loghandle};
    $lh or return undef;
    $module = "[$module]";
    $level = "[$level]";
    chomp($message);

    print $lh sprintf("%-16s %-24s %-80s\n", $level, $module, $message);
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

	$self->add_to_log( "INFO", "amazon_cover", "Retrieving cover art" );

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
	my $comment = safe_chars($meta->{COMMENT});
	my $folder = $self->{conf}->{ripper}->{mediadir}."$artist/$album/";
	$folder .= "$comment/" if $comment;
	`mkdir -p $folder` unless -d $folder;

	open(IMG,"> ${folder}cover.$ext");
	binmode IMG;
	print IMG $img;
	close(IMG);

	return 1;
}

##############################################################################
# Finds an genre_id from name or creates a new entry if it doesn't exist

sub genre_find_or_create {
    my( $self, $genre ) = @_;
    my $mc = $self->mysqlConnection;
    my $genre_id = 0;

    my $q_genre = $mc->quote($genre);
    ($_) = @{$mc->query_and_get('SELECT id FROM genre WHERE name = '.$q_genre)||[]};
	
    # Artist not in database, add an entry
    unless($genre_id = $_->{id}) {
	my $q = $mc->query('INSERT INTO genre (name) VALUES('.$q_genre.')');
	$genre_id = $mc->last_id;
	$q->finish();
    }
	
    return $genre_id
}

##############################################################################
# Finds an artist_id from name or creates a new entry if it doesn't exist

sub artist_find_or_create {
    my( $self, $artist ) = @_;
    my $mc = $self->mysqlConnection;
    my $artist_id = 0;

    my $q_artist = $mc->quote($artist);
    ($_) = @{$mc->query_and_get('SELECT id FROM artist WHERE name = '.$q_artist)||[]};
	
    # Artist not in database, add an entry
    unless($artist_id = $_->{id}) {
	my $q = $mc->query('INSERT INTO artist (name) VALUES('.$q_artist.')');
	$artist_id = $mc->last_id;
	$q->finish();
    }       

    return $artist_id;
}

##############################################################################
# Store the album and track information into the database

sub store {
	my($self,$meta) = @_;

	$self->add_to_log( "INFO", "store", "Storing album to database" );

	my $aartist = safe_chars($meta->{ARTIST});
	my $agenre = safe_chars($meta->{GENRE});
	my $album = safe_chars($meta->{ALBUM});
	my $comment = substr(safe_chars($meta->{COMMENT}),0,32);
	my $folder = $self->{conf}->{ripper}->{mediadir}."$aartist/$album/";
	$folder .= "$comment/" if $comment;
	$folder =~ s/\/$//;
	my @files = grep{/\.(mp3|flac|ogg|wav)$/}<$folder/*>;

	# Find the albums artist/genre IDs or create if it is not in database
	my $aartist_id = $self->artist_find_or_create($aartist);
	my $agenre_id  = $self->genre_find_or_create($agenre);

	# If no tracks exist, bug out
	die("No tracks for this album") unless scalar @files; # Don't store album if no tracks

	my $mc = $self->mysqlConnection;

	my($sql,$artist_id,$album_id,$genre_id);

	my $cover = 'NULL';
	my @imgs = <${folder}/cover.*>;
	my $img = join('',@imgs) || '';
	
	# Hack to remove the /usr/local/cmms/htdocs/ element from the page
	$img =~ s^/usr/local/cmms/htdocs/^^sig;

	$cover = $mc->quote($img) if $img;

	my $acomment = $meta->{COMMENT};
	$acomment =~ s/[\r\n]+$//g;

	$mc->query('INSERT INTO album (name,discid,year,comment,cover,artist_id,genre_id) VALUES('.$mc->quote($meta->{ALBUM}).','.$mc->quote($meta->{discid}).','.$mc->quote($meta->{YEAR}).','.$mc->quote($acomment).",$cover,$aartist_id,$agenre_id)");
	$album_id = $mc->last_id;


	$self->add_to_log( "INFO", "store", "Adding genre of ".$meta->{GENTRE} );
	$sql = 'SELECT id FROM genre WHERE name = '.$mc->quote($meta->{GENRE});
	($_) = @{$mc->query_and_get($sql)||[]};
	$genre_id = $_->{id} || -1;

	@files = ();
	foreach my $track (@{$meta->{TRACKS}}) {
		my $track_num = sprintf('%02d',$track->number);
		my $artist = $track->artist;
		$artist = 'Unknown' if $artist =~ /^unknown/i;
		my $title = $track->title;
		$title = safe_chars("$track_num $artist $title");
		@files = <$folder/$title.*>;
		next unless scalar @files;

		$self->add_to_log( "INFO", "store", "Adding track '$title' to database" );

		my $ttitle = $track->title;
		$ttitle =~ s/[\r\n]+//g;

		$artist = $mc->quote($artist);
		($_) = @{$mc->query_and_get('SELECT id FROM artist WHERE name = '.$artist)||[]};
		$artist_id = 0;
		unless($artist_id = $_->{id}) {
			$mc->query('INSERT INTO artist (name) VALUES('.$artist.')');
			$artist_id = $mc->last_id;
		}
		$sql = 'INSERT INTO track (album_id,artist_id,genre_id,title,track_num,length_seconds,ctime) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($album_id,$artist_id,$genre_id,$ttitle,$track->number,$track->length)).',NOW())';
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

sub store_xml {
	my($self,$meta) = @_;

	my $aartist = safe_chars($meta->{ARTIST});
	my $album = safe_chars($meta->{ALBUM});
	my $comment = substr(safe_chars($meta->{COMMENT}),0,32);
	my $folder = $self->{conf}->{ripper}->{mediadir}."$aartist/$album/";
	$folder .= "$comment/" if $comment;
	$folder =~ s/\/$//;
	my @files = grep{/\.(mp3|flac|ogg|wav)$/}<$folder/*>;

	$self->add_to_log( "INFO", "store", "Storing album to XML" );
	print STDERR "$folder\n";

	die("No tracks for this album") unless scalar @files; # Don't store album if no tracks

	my($artist_id,$album_id,$genre_id);

	my $cover = '';
	my @imgs = <${folder}/cover.*>;
	my $img = join('',@imgs) || '';
	$cover = $img if $img;

	my $acomment = $meta->{COMMENT};
	$acomment =~ s/[\r\n]+$//g;

	my $xml = qq(
		<?xml version="1.0" encoding="ISO-8859-1"?>
		  <import>
		    <album>
		      <name>$meta->{ALBUM}</name>
		      <discid>$meta->{discid}</discid>
		      <year>$meta->{YEAR}</year>
		      <comment>$acomment</comment>
		      <cover>$cover</cover>
		      <genre>$meta->{GENRE}</genre>
		      <folder>$folder</folder>
		    </album>
		    <tracks>
	);

	@files = ();
	foreach my $track (@{$meta->{TRACKS}}) {
		my $track_num = sprintf('%02d',$track->number);
		my $artist = $track->artist;
		$artist = 'Unknown' if $artist =~ /^unknown/i;
		my $title = $track->title;
		$title = safe_chars("$track_num $artist $title");
		@files = <$folder/$title.*>;
		next unless scalar @files;

		my $ttitle = $track->title;
		$ttitle =~ s/[\r\n]+//g;

		$xml .= qq(
			      <track>
			        <artist>$artist</artist>
			        <title>$ttitle</title>
			        <track_num>).$track->number.qq(</track_num>
			        <length_seconds>).$track->length.qq(</length_seconds>
		);

		foreach(@files) {
			print STDERR "$_\n";
			my($file_location,$file_name,$file_type) = (/^(.+\/)([^\/]+\.(.+))$/);
			my $filesize = -s $_;
			my $bitrate = (/\.mp3$/?160:'');

			$xml .= qq(
				        <data>
				          <file_location>$file_location</file_location>
				          <file_name>$file_name</file_name>
				          <file_type>$file_type</file_type>
				          <bitrate>$bitrate</bitrate>
				          <filesize>$filesize</filesize>
				          <info_source>$self->{conf}->{ripper}->{metadata}</info_source>
				        </data>
			);
		}

		$xml .= qq(
			      </track>
		);
	}

	$xml .= qq(
		    </tracks>
		  </import>
	);

	open(XML,"> $folder/export.xml");
	print XML $xml;
	close(XML);
}

sub check {
	my($self,$meta) = @_;

	my $mc = $self->mysqlConnection;

	$self->add_to_log( "INFO", "check", "Checking if album is in the database (".$meta->{discid}.")" );


	($_) = @{$mc->query_and_get('SELECT id FROM album WHERE discid = '.$mc->quote($meta->{discid}))||[]};
	if($_->{id}) {
		warn('Album already ripped');
		$self->add_to_log( "INFO", "check", "Album is in database, skipping" );
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
