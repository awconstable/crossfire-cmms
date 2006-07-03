#!/usr/bin/perl -w

use strict;

my $IMG = $ENV{PATH_INFO} || '';

if($IMG) {
	open(IMG,'< '.$IMG);
	binmode IMG;
	local $/;
	$IMG = <IMG>;
	close(IMG);
}

binmode STDOUT;
print "Content-type: image\n\n".$IMG;
