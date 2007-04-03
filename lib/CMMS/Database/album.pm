#$Id: album.pm,v 1.19 2007/04/03 15:03:15 toby Exp $

package CMMS::Database::album;

=head1 NAME

CMMS::Database::album

=head1 SYNOPSIS

  use CMMS::Database::album;

=head1 DESCRIPTION

  None!

=cut

use strict;
use warnings;
use CMMS::Database::playlist;
use base qw( CMMS::Database::Object );

our $VERSION = sprintf '%d.%03d', q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/;

#==============================================================================
# CLASS METHODS
#==============================================================================
sub new {
  my $that = shift;
  my $class = ref( $that ) || $that;
  my $dbInterface = shift;
  my $id = shift;
  
  # Create the object
  #
  my $self = new CMMS::Database::Object( $dbInterface, "album", $id );
 
  # Bless the object
  #
  bless $self, $class;

  # Process the input parameters
  #

  # Setup object definitions
  #
  $self->definition({
    name => "album",
    tag => "album",
    title => "Album",
    title_field => "name",
    display => [ "id", "name", "discid", "year", "comment", "cover", "artist_id", "inherit_artist", "composer_id", "conductor_id", "genre_id", "last_edited", "created"  ],
    list_display => [ "name", "cover",  ],
    tagorder => [ "id", "discid", "name", "year", "comment", "cover", "last_edited", "created"  ],
    tagrelationorder => [ ],
    relationshiporder => [ ],
    no_broadcast => 1,
    no_clone => 1,
    no_create => 1,
    event_post_save => "event_post_save",
    event_force_save => "event_force_save",
    order_by => 'name',
    multiview => {
	order => [ qw( Overview Edit ) ],
	views => {
	    'Overview' => {
		include => "album-overview.ehtm",
		display => [ "id" ],
	    },
	    'Edit' => {
		display => [ "id", "name", "discid", "year", "comment", "cover", "artist_id", "inherit_artist", "composer_id", "conductor_id", "genre_id", "last_edited", "created"  ],

	    },
	},
    },
    default_view => "Overview",
    create_view => "Edit",
    elements => {
            'id' => {
	        type => "int",
		tag  => "Id",
		title => "Id",
		primkey => 1,
		displaytype => "hidden",
            },
            'artist_id' => {
	        type => "int",
		tag  => "Artist",
		title => "Artist",
		lookup => {
		    table => "artist",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		},
		mandatory => 1,
		event_change => "inherit_artist",
            },
            'inherit_artist' => {
                type => "int",
		tag  => "Inherit_artist",
		title => "Inherit artist",
		displaytype => "checkbox",
		help => "Tick this box if you want the album tracks to inherit artist",
		event_change => "inherit_artist",
		no_search => 1,
            },
            'composer_id' => {
	        type => "int",
		tag  => "Composer",
		title => "Composer",
		lookup => {
		    table => "composer",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		}
            },
            'conductor_id' => {
	        type => "int",
		tag  => "Conductor",
		title => "Conductor",
		lookup => {
		    table => "conductor",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		}
            },
            'genre_id' => {
	        type => "int",
		tag  => "Genre",
		title => "Genre",
		lookup => {
		    table => "genre",
		    keycol => "id",
		    valcol => "name",
		    none => "NULL",
		    read_only => 1,
		},

            },
            'discid' => {
	        type => "varchar",
		tag  => "Discid",
		title => "Disc-ID",
		displaytype => "readonly",
		no_search => 1,
            },
            'name' => {
	        type => "varchar",
		tag  => "Name",
		title => "Name",
		size => 80,
		maxsize => 255,
		mandatory => 1,
            },
            'year' => {
	        type => "varchar",
		tag  => "Year",
		title => "Year",
            },
            'comment' => {
	        type => "text",
		tag  => "Comment",
		title => "Comment",
		width => 80,
		height => 16,
		no_search => 1,
            },
            'cover' => {
	        type => "varchar",
	        size => 64,
	        maxsize => 255,
		tag  => "Cover",
		title => "Cover image",
		upload => 1,
		upload_fn => "upload_resizer", 
		upload_parameters => {
		    sizes => [
			{ field=>"cover", widest=>"160", suffix=>"fs_" },
#			{ field=>"minisize_url", wfield=>"minisize_x", hfield=>"minisize_y", suffix => "tn_", widest=>"220", },
#			{ field=>"microsize_url", wfield=>"microsize_x", hfield=>"microsize_y", suffix=>"ms_", widest=>"100" },     
		    ]
		},
		help => "Click on the browse button to pick a picture from your local disk or enter an image URL into the space provided.",
		displaytype => "image",
		no_search => 1,
            },
            'last_edited' => {
	        type => "datetime",
		tag  => "last_edited",
		title => "Last edited",
		displaytype => "readonly",
		no_search => 1,
            },
            'created' => {
	        type => "datetime",
		tag  => "Created",
		title => "Created",
		displaytype => "readonly",
		no_search => 1,
            },

    },
    relationships => {
	'track' => {
	    type => "one2many",
	    localkey => "id",
	    foreignkey => "album_id",
	    title => "Track(s)",
	    tag => "track",
	    order_by => 'track_num',
	    display => [
	    		{ col => "artist_id", title => "Artist" },
	    		{ col => "composer_id", title => "Composer" },
	    		{ col => "conductor_id", title => "Conductor" },
	    		{ col => "genre_id", title => "Genre" },
	    		{ col => "title", title => "Title" },
	    		{ col => "track_num", title => "Track No." },
	    		{ col => "length_seconds", title => "Length" },
			],
	    list_method => 'get_track_list',
	    no_clone => 1,
	}
    },
  });

  # Return object
  #
  return $self;
}

sub inherit_artist {
	my($self, $change) = @_;
	return undef unless $self->get('inherit_artist') && $self->get('id');
	my $mc = $self->mysqlConnection;
	my $id = $self->get('id');
	my $artist_id = $self->get('artist_id');
	$mc->query(qq(
UPDATE
track
SET
artist_id = $artist_id
WHERE
album_id = $id
	));
}

sub get_track_list {
    my ($self,$page,$size) = @_;

    my $id = $self->get('id');

    my $selects = <<EndSelects
track.*,
album.name as album_id,
artist.name as artist_id,
composer.name as composer_id,
conductor.name as conductor_id,
genre.name as genre_id
EndSelects
    ;

    my $tables = <<EndTables
track,
album,
artist,
genre
LEFT JOIN composer ON track.composer_id = composer.id
LEFT JOIN conductor ON track.conductor_id = conductor.id
EndTables
    ;

    my $where = <<EndWhere
track.album_id = $id
and album.id = track.album_id
and artist.id = track.artist_id
and genre.id = track.genre_id
order by track.track_num
EndWhere
    ;

    return $self->get_list( "track", $page, $size, { tables=>$tables, select => $selects, where => $where } );
}

sub event_post_save {
    my( $self, $ui ) = @_;
    my $cgi = $ui->cgi();
    my $view = $ui->view();

    my $mc = $self->mysqlConnection();

    if( $view eq "Overview" ) {
	my $playlist_id = $cgi->param("playlist_id");	
	my $new_playlist_name = $cgi->param("playlist_name");

	if( $cgi->param("button_addalbum.x") ) {
            my $album_id = $self->get("id");
	    my $plobj = new CMMS::Database::playlist($mc,$playlist_id);

	    if( $playlist_id ) {
		$plobj->pull or $plobj=undef;
	    }
	    elsif ($new_playlist_name) {
		$plobj->set("name",$new_playlist_name);
		$playlist_id = $plobj->push();
	    }
	    else {
		$plobj = undef;
	    }

	    if( $plobj ) {
	      $album_id and $plobj->add_album($album_id);
	  }
	}
	elsif( $cgi->param("button_add_tracks.x") ) {
	    my @params = $cgi->param();

	    my $plobj = new CMMS::Database::playlist($mc,$playlist_id);

	    if( $playlist_id ) {
		$plobj->pull or $plobj=undef;
	    }
	    elsif ($new_playlist_name) {
		$plobj->set("name",$new_playlist_name);
		$playlist_id = $plobj->push();
	    }
	    else {
		$plobj = undef;
	    }

	    if( $plobj ) {

		foreach my $p ( @params ) {
		    
		    if( $p =~ /^tag\.(.*)/ ) {
			my $track_id = $1;
			$track_id and $plobj->add_track($track_id);
		    }
		}

		$ui->redirect_url("playlist.ehtml?id=".$playlist_id.";session_id=".$cgi->param("session_id"));
	    }
	}
	elsif( $cgi->param("button_deletetagged.x") ) {
	    my @params = $cgi->param();

	    foreach my $p ( @params ) {

		if( $p =~ /^tag\.(.*)/ ) {
		    my $id = $1;
		    my $q = $mc->query("DELETE FROM playlist_track WHERE id=".$mc->quote($id));
		    $q->finish();
		    
		}
	    }
	}       
    }
}

sub event_force_save {
  my( $self,$ui ) = @_;
  my $cgi = $ui->cgi();
  
  if( $cgi->param("button_addalbum.x") ) {
      return 1;
  }
      
  if( $cgi->param("button_add_tracks.x") ) {
      return 1;
  }
      
  return 0;
}

1;

__END__

=head1 SEE ALSO

L<TAER::Object(3pm)>

=head1 AUTHOR

Generated from TAER::Object::Template version 1.007 by taer_build_objects.

=head1 COPYRIGHT

Copyright (c) 2006 Coreware Limited. England.  All rights reserved.

You must obtain a written license to use this software.

=cut
