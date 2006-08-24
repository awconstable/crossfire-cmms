#!/usr/bin/perl

# List Zones from /etc/cmms.conf

use Config::General;
use CGI;
use CMMS::Database::MysqlConnection;

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

&ui_print_header(undef, $text{'zone_title'}, "");

my $mc = new CMMS::Database::MysqlConnection;
$mc->user('cmms');
$mc->password('cmms');
$mc->connect;

my $host = $ENV{HTTP_HOST};
$host =~ s/:[0-9]+//;

my $cgi = new CGI;

%conf  = ParseConfig('/etc/cmms.conf');
$zones = $conf{zones}->{zone} || [];
$save_zones = [];

$restart = '';

if($cgi->param('save')) {
	foreach my $num (1..scalar @{$zones}) {
		if($cgi->param($num.'_host') ne '' && $cgi->param($num.'_port') ne '') {
		$title = $cgi->param($num.'_location');
		$title =~ s/zone([\s-_]+)?[0-9]+([\s-_]+)?//i;
		push @{$save_zones}, {
			number => $num,
			host => $cgi->param($num.'_host'),
			port => $cgi->param($num.'_port'),
			location => $cgi->param($num.'_location'),
			datapath => $cgi->param($num.'_datapath'),
			time => $cgi->param($num.'_time'),
			timeformat => $cgi->param($num.'_timeformat')
		};
		$mc->query("replace into zone (id,name) values ($num,'$title')");
		}
	}

	push @{$save_zones}, {};
	$conf{zones}->{zone} = $save_zones;
	$zones = $save_zones;
	SaveConfig('/etc/cmms.conf',\%conf);

	$restart = `/sbin/service cmmsd restart 2>&1`;
	$restart =~ s/FAILED/<font color="red">FAILED<\/font>/g;
	$restart =~ s/OK/<font color="green">OK<\/font>/g;
}

$zones->[(scalar @{$zones} - 1)]->{number} = (scalar @{$zones});
unshift @{$zones}, pop @{$zones};

print ($restart?"<h3>cmmsd Restart</h3><pre>$restart</pre>":'');

print qq(

<table>
<form>
<input type="hidden" name="save" value="1">
<input type="hidden" name="v" value="configuration">

);

foreach my $zone (@{$zones}) {
print qq(

<tr>
<th colspan="2" align="centre"><br><h2>).($zone->{number}==scalar @{$zones}?'New zone':"Zone $zone->{number}").qq(</h2></th>
</tr>
<tr>
<td>Host:</td>
<td><input type="text" name="$zone->{number}_host" value="$zone->{host}"></td>
</tr>
<tr>
<td>Port:</td>
<td><input type="text" name="$zone->{number}_port" value="$zone->{port}"></td>
</tr>
<tr>
<td>Location:</td>
<td><input type="text" name="$zone->{number}_location" value="$zone->{location}"></td>
</tr>
<tr>
<td>Data path:</td>
<td><input type="text" name="$zone->{number}_datapath" value="$zone->{datapath}"></td>
</tr>
<tr>
<td>Time display:</td>
<td>
On <input type="radio" value="1" name="$zone->{number}_time").($zone->{time}eq 1?' checked':'').qq(>
Off <input type="radio" value="" name="$zone->{number}_time").($zone->{time}ne 1?' checked':'').qq(>
</td>
</tr>
<tr>
<td>Time format:</td>
<td><input type="text" name="$zone->{number}_timeformat" value="$zone->{timeformat}"></td>
</tr>
<tr>
<td colspan="2" align="right"><input type="button" onclick="this.form.submit();" value="Save"></td>
</tr>
);
}

print qq(
</form>
</table>

);

&ui_print_footer("", $text{'index_return'});

