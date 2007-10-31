#!/usr/bin/perl

# Display a menu of cms

#==== INIT =====
do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
%access = &get_module_acl();

if (-r "$module_root_directory/$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl") {
	do "$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}
#==== /INIT =====

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("cmmsd", "man"));

foreach $i ('general', 'zone', 'player') {
	push(@links, "list_${i}.cgi");
	push(@titles, $text{"${i}_title"});
	push(@icons, "images/${i}.gif");
}
&icons_table(\@links, \@titles, \@icons);

&ui_print_footer("/", $text{'servers_index'});

