# cmms-lib.pl
# Common CMS functions

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

1;
