#!/usr/bin/perl

# List Players from /etc/cmms.conf

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

&ui_print_header(undef, $text{'player_title'}, "");

my $cgi = new CGI;

%conf  = ParseConfig('/etc/cmms.conf');
$players = $conf{players}->{player} || [];
$save_players = [];

$restart = '';

if($cgi->param('save')) {
	foreach my $num (1..scalar @{$players}) {
		if($cgi->param($num.'_bind') ne '' && $cgi->param($num.'_port') ne '') {
		$title = $cgi->param($num.'_number');
		push @{$save_players}, {
			number => $num,
			bind => $cgi->param($num.'_bind'),
			port => $cgi->param($num.'_port'),
			device => $cgi->param($num.'_device'),
			debug => $cgi->param($num.'_debug'),
		};
		}
	}

	push @{$save_players}, {};
	$conf{players}->{player} = $save_players;
	$players = $save_players;
	SaveConfig('/etc/cmms.conf',\%conf);

	$restart = `/sbin/service cmms_player restart 2>&1`;
	$restart =~ s/FAILED/<font color="red">FAILED<\/font>/g;
	$restart =~ s/OK/<font color="green">OK<\/font>/g;
}

$players->[(scalar @{$players} - 1)]->{number} = (scalar @{$players});
unshift @{$players}, pop @{$players};

print ($restart?"<h3>cmms_player Restart</h3><pre>$restart</pre>":'');

print qq(

<table>
<form>
<input type="hidden" name="save" value="1">
<input type="hidden" name="v" value="configuration">

);

foreach my $player (@{$players}) {
print qq(

<tr>
<th colspan="2" align="centre"><br><h2>).($player->{number}==scalar @{$players}?'New player':"Player $player->{number}").qq(</h2></th>
</tr>
<tr>
<td>Bind to:</td>
<td><input type="text" name="$player->{number}_bind" value="$player->{bind}"></td>
</tr>
<tr>
<td>Port:</td>
<td><input type="text" name="$player->{number}_port" value="$player->{port}"></td>
</tr>
<tr>
<td>Device:</td>
<td><input type="text" name="$player->{number}_device" value="$player->{device}"></td>
</tr>
<tr>
<td>Debug:</td>
<td>
On <input type="radio" value="1" name="$player->{number}_debug").($player->{debug}eq 1?' checked':'').qq(>
Off <input type="radio" value="" name="$player->{number}_debug").($player->{debug}ne 1?' checked':'').qq(>
</td>
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

