#!/usr/bin/perl

# List General config from /etc/cmms.conf

use Config::General;
use CGI;

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

&ui_print_header(undef, $text{'general_title'}, "");

my $cgi = new CGI;

my %conf        = ParseConfig('/etc/cmms.conf');
my $serial      = $conf{serial};
my $controlhost = $conf{controlhost};

if($cgi->param('serial') && $cgi->param('controlhost')) {
	$serial = $cgi->param('serial');
        $controlhost = $cgi->param('controlhost');
	$conf{serial} = $cgi->param('serial');
	$conf{controlhost} = $cgi->param('controlhost');
	SaveConfig('/etc/cmms.conf',\%conf);
}

print qq(

<form>
  <table>
    <tr>
      <td>Serial:</td>
      <td><input type="text" name="serial" value="$serial"></td>
    </tr>
    <tr>
      <td>Control host:</td>
      <td><input type="text" name="controlhost" value="$controlhost"></td>
    </tr>
    <tr colspan="2" align="right">
      <td><input type="submit" value="Save"></td>
    </tr>
  </table>
</form>

);

&ui_print_footer("", $text{'index_return'});

