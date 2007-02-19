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
our $VERSION = '1.1.9';
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

	my $nocache = ($params{nocache}?1:0);

	my $metadata = $self->{conf}->{ripper}->{metadata};
	eval "use CMMS::Ripper::DiscID::$metadata;\n\$self->{metadata} = new CMMS::Ripper::DiscID::$metadata(mc => \$mc, conf => \$self->{conf}, loghandle=>\$self->{loghandle}, nocache=>$nocache)";
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

    my $ctime = ctime(time);
    print $lh sprintf("%-23s, %-16s %-12s %-80s\n", $ctime, $level, $module, $message);
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
	my $folder = $self->{conf}->{ripper}->{mediadir}."$artist/$album/";
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
    $genre =~ s/[\r\n]+//g;
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
    $artist =~ s/[\r\n]+//g;
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
# Finds an conductor_id from name or creates a new entry if it doesn't exist

sub conductor_find_or_create {
    my( $self, $conductor ) = @_;
    $conductor =~ s/[\r\n]+//g;
    my $mc = $self->mysqlConnection;
    my $conductor_id = 0;

    my $q_conductor = $mc->quote($conductor);
    ($_) = @{$mc->query_and_get('SELECT id FROM conductor WHERE name = '.$q_conductor)||[]};
	
    # conductor not in database, add an entry
    unless($conductor_id = $_->{id}) {
	my $q = $mc->query('INSERT INTO conductor (name) VALUES('.$q_conductor.')');
	$conductor_id = $mc->last_id;
	$q->finish();
    }       

    return $conductor_id;
}

##############################################################################
# Finds an composer_id from name or creates a new entry if it doesn't exist

sub composer_find_or_create {
    my( $self, $composer ) = @_;
    $composer =~ s/[\r\n]+//g;
    my $mc = $self->mysqlConnection;
    my $composer_id = 0;

    my $q_composer = $mc->quote($composer);
    ($_) = @{$mc->query_and_get('SELECT id FROM composer WHERE name = '.$q_composer)||[]};
	
    # composer not in database, add an entry
    unless($composer_id = $_->{id}) {
	my $q = $mc->query('INSERT INTO composer (name) VALUES('.$q_composer.')');
	$composer_id = $mc->last_id;
	$q->finish();
    }       

    return $composer_id;
}

##############################################################################
# Store the album and track information into the database

sub store {
	my($self,$meta) = @_;

	$self->add_to_log( "INFO", "store", "Storing album to database" );

	my $aartist = $meta->{ARTIST};
	my $s_aartist = safe_chars($meta->{ARTIST});
	my $agenre = safe_chars($meta->{GENRE});
	my $album = safe_chars($meta->{ALBUM});
	my $folder = $self->{conf}->{ripper}->{mediadir}."$s_aartist/$album/";
	$folder =~ s/\/$//;
	my @files = grep{/\.(mp3|flac)$/}<$folder/*>;

        # If no tracks exist, bug out
        unless(scalar @files) {
                warn 'No tracks for this album';
                return undef;
        }

	# Find the albums artist/genre IDs or create if it is not in database
	my $aartist_id = $self->artist_find_or_create($aartist);
	my $agenre_id  = $self->genre_find_or_create($meta->{GENRE});
	my $acomposer_id  = $meta->{COMPOSER}?$self->composer_find_or_create($meta->{COMPOSER}):'NULL';
	my $aconductor_id  = $meta->{CONDUCTOR}?$self->conductor_find_or_create($meta->{CONDUCTOR}):'NULL';

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

	my $qdisc = $mc->quote($meta->{DISCID});
	$sql = "SELECT id FROM album WHERE discid = $qdisc";
	($_) = @{$mc->query_and_get($sql)||[]};
	unless($album_id = $_->{id}) {
		$sql = 'INSERT INTO album (name,discid,year,comment,cover,artist_id,genre_id,composer_id,conductor_id) VALUES('.$mc->quote($meta->{ALBUM}).','.$mc->quote($meta->{discid}).','.$mc->quote($meta->{YEAR}).','.$mc->quote($acomment).",$cover,$aartist_id,$agenre_id,$acomposer_id,$aconductor_id)";
		$mc->query($sql);
		$album_id = $mc->last_id;
	}

	@files = ();
	my $empty_album = 1;
	foreach my $track (@{$meta->{TRACKS}}) {
		my $track_num = sprintf('%02d',$track->number);
		my $artist = $track->artist;
		$artist = 'Unknown' if $artist =~ /^unknown/i;
		my $title = $track->title;
		$title = substr(safe_chars("$track_num $title"),0,35);
		@files = <$folder/$title.*>;
		next unless scalar @files;

		$self->add_to_log( "INFO", "store", "Adding track '$title' to database" );

		my $ttitle = $track->title;
		$ttitle =~ s/[\r\n]+//g;

		my $artist_id = $self->artist_find_or_create($artist);

		my $tcomposer_id  = $track->composer?$self->composer_find_or_create($track->composer):'NULL';
		my $tconductor_id  = $track->conductor?$self->conductor_find_or_create($track->conductor):'NULL';

		my $track_id;
		my $qttitle = $mc->quote($ttitle);
		$sql = "SELECT id FROM track WHERE album_id = $album_id AND artist_id = $artist_id AND genre_id = $agenre_id AND title = $qttitle AND track_num = ".$track->number;
		($_) = @{$mc->query_and_get($sql)||[]};
		unless($track_id = $_->{id}) {
			$sql = 'INSERT INTO track (album_id,artist_id,genre_id,title,track_num,length_seconds,composer_id,conductor_id,created) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($album_id,$artist_id,$agenre_id,$ttitle,$track->number,$track->length,$tcomposer_id,$tconductor_id)).',NOW())';
			$mc->query($sql);
			$track_id = $mc->last_id;
		}

		next unless $track_id;

		foreach(@files) {
			print STDERR "$_\n";
			my($file_location,$file_name,$file_type) = (/^(.+\/)([^\/]+\.(.+))$/);
			my $filesize = -s $_;
			my $bitrate = (/\.mp3$/?160:'');
			$sql = "SELECT id FROM track_data WHERE track_id = $track_id AND file_type = '$file_type'";
			($_) = @{$mc->query_and_get($sql)||[]};
			unless($_->{id}) {
				$sql = 'INSERT INTO track_data (track_id,file_location,file_name,file_type,bitrate,filesize,info_source) VALUES('.join(',',map{s/[\r\n]+//g;$mc->quote($_)}($track_id,$file_location,$file_name,$file_type,$bitrate,$filesize,$self->{conf}->{ripper}->{metadata})).')';
				$mc->query($sql);
			}
			$empty_album = 0;
		}
	}
	$mc->query('DELETE FROM album WHERE id = '.$album_id) if $empty_album;
}

sub store_xml {
	my($self,$meta) = @_;

	my $sartist = safe_chars($meta->{ARTIST});
	my $album = safe_chars($meta->{ALBUM});
	my $folder = $self->{conf}->{ripper}->{mediadir}."$sartist/$album/";
	$folder =~ s/\/$//;
	my @files = grep{/\.(mp3|flac|ogg|wav)$/}<$folder/*>;

	$self->add_to_log( "INFO", "store", "Storing album to XML" );
	print STDERR "$folder\n";

        # If no tracks exist, bug out
        unless(scalar @files) {
                warn 'No tracks for this album';
                return undef;
        }

	my($album_id,$genre_id);

	my $cover = '';
	my @imgs = <${folder}/cover.*>;
	my $img = join('',@imgs) || '';
	$cover = $img if $img;

	my $atitle = $meta->{ALBUM};
	$atitle =~ s/[\r\n]+$//g;
	$atitle =~ s/&/&amp;/g;
	$atitle =~ s/</&lt;/g;
	$atitle =~ s/>/&gt;/g;

	my $aartist = $meta->{ARTIST};
	$aartist =~ s/[\r\n]+$//g;
	$aartist =~ s/&/&amp;/g;
	$aartist =~ s/</&lt;/g;
	$aartist =~ s/>/&gt;/g;

	my $agenre = $meta->{GENRE};
	$agenre =~ s/[\r\n]+$//g;
	$agenre =~ s/&/&amp;/g;
	$agenre =~ s/</&lt;/g;
	$agenre =~ s/>/&gt;/g;

	my $acomment = $meta->{COMMENT};
	$acomment =~ s/[\r\n]+$//g;
	$acomment =~ s/&/&amp;/g;
	$acomment =~ s/</&lt;/g;
	$acomment =~ s/>/&gt;/g;

	my $acomposer = $meta->{COMPOSER};
	$acomposer =~ s/[\r\n]+$//g;
	$acomposer =~ s/&/&amp;/g;
	$acomposer =~ s/</&lt;/g;
	$acomposer =~ s/>/&gt;/g;

	my $aconductor = $meta->{CONDUCTOR};
	$aconductor =~ s/[\r\n]+$//g;
	$aconductor =~ s/&/&amp;/g;
	$aconductor =~ s/</&lt;/g;
	$aconductor =~ s/>/&gt;/g;

	my $xml = qq(<?xml version="1.0" encoding="ISO-8859-1"?>
		  <import>
		    <album>
		      <name>$atitle</name>
		      <discid>$meta->{discid}</discid>
		      <year>$meta->{YEAR}</year>
		      <comment>$acomment</comment>
		      <composer>$acomposer</composer>
		      <conductor>$aconductor</conductor>
		      <cover>$cover</cover>
		      <artist>$aartist</artist>
		      <genre>$agenre</genre>
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
		$title = substr(safe_chars("$track_num $title"),0,35);
		@files = <$folder/$title.*>;
		next unless scalar @files;

		$artist =~ s/[\r\n]+//g;
		$artist =~ s/&/&amp;/g;
		$artist =~ s/</&lt;/g;
		$artist =~ s/>/&gt;/g;

		my $ttitle = $track->title;
		$ttitle =~ s/[\r\n]+//g;
		$ttitle =~ s/&/&amp;/g;
		$ttitle =~ s/</&lt;/g;
		$ttitle =~ s/>/&gt;/g;

		my $tcomposer = $track->composer;
		$tcomposer =~ s/[\r\n]+//g;
		$tcomposer =~ s/&/&amp;/g;
		$tcomposer =~ s/</&lt;/g;
		$tcomposer =~ s/>/&gt;/g;

		my $tconductor = $track->conductor;
		$tconductor =~ s/[\r\n]+//g;
		$tconductor =~ s/&/&amp;/g;
		$tconductor =~ s/</&lt;/g;
		$tconductor =~ s/>/&gt;/g;

		$xml .= qq(
			      <track>
			        <artist>$artist</artist>
			        <title>$ttitle</title>
			        <composer>$tcomposer</composer>
			        <conductor>$tconductor</conductor>
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

	if((($_) = @{$mc->query_and_get('SELECT id FROM album WHERE discid = '.$mc->quote($meta->{discid}))||[]}) && (my $aid = $_->{id})) {
		my %in = map{$_->title=>$_->number}@{$meta->{TRACKS}};
		my $i = 0;
		while(my($title,$number) = each %in) {
			my $trk = $meta->{TRACKS}->[$i++];
			my $ext = 'flac';
			$ext = 'mp3' if ref($trk) eq 'CMMS::Track::Enhanced' && $trk->type eq 'mp3';
			if((($_) = @{$mc->query_and_get("SELECT track.id FROM track,track_data WHERE track_data.track_id = track.id AND track_data.file_type = '$ext' AND track.album_id = $aid AND track.track_num = $number AND track.title = ".$mc->quote($title))||[]}) && (defined $_->{id})) {
				delete $in{$title};
				warn('Track ('.$number.') ['.$title.'] already in this album');
			}
			delete $in{$title} if $title eq 'Data Track';
		}
		if(scalar keys %in < 1) {
			warn('Album already ripped');
			$self->add_to_log( "INFO", "check", "Album is in database, skipping" );
			return 0;
		}
		@_ = ();
		foreach my $track (@{$meta->{TRACKS}}) {
			push @_, $track if exists $in{$track->title};
		}
		$meta->{TRACKS} = \@_;
	}

	return 1;
}

sub purge {
	my $self = shift;
	my $tmp = $self->{conf}->{ripper}->{tmpdir};

	`rm -f $tmp*.wav`;
}

1;
