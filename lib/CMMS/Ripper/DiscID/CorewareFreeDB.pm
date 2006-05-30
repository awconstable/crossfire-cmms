package CMMS::Ripper::DiscID::CorewareFreeDB;

use strict;
use warnings;
use base qw(Net::FreeDB);

sub read {
    my $self = shift;
    my ($cat, $id);

    if (scalar(@_) == 2) {
	($cat, $id) = @_;
    } else {
	if ((scalar(@_) % 2) == 0) {
	    if ($_[0] =~ /^CATEGORY$/i || $_[0] =~ /^ID$/i) {
		my %input = @_;
		($cat, $id) = ($input{CATEGORY}, $input{ID});
	    } else {
		print "Error: Unknown input!\n";
		return undef;
	    }
	} else {
	    print "Error: Unknown input!\n";
	    return undef;
	}
    }
    my $cddb_file = new CDDB::File('/dev/null');
    $cddb_file->{_data} =
	$self->_READ($cat, $id) ? $self->_read : undef;
    return $cddb_file;
}

1;
