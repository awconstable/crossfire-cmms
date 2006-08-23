#!/usr/bin/perl
# index.cgi
# Display a menu of cms

require './cmms-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("cmmsd", "man"));

foreach $i ('general', 'zone') {
	push(@links, "list_${i}.cgi");
	push(@titles, $text{"${i}_title"});
	push(@icons, "images/${i}.gif");
}
&icons_table(\@links, \@titles, \@icons);

&ui_print_footer("/", $text{'servers_index'});

