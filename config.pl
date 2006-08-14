#!/usr/bin/perl -w
#$Id: config.pl,v 1.1 2006/08/14 07:58:32 toby Exp $

# Configure Cmms installation

use strict;
use ExtUtils::MakeMaker;
use Install::Base;
use Install::Locate;
use Install::MySQL;
use Install::WebNode;

use vars qw( $LOCAL_INSTALL_ROOT $LOCAL_HTTP_ROOT);

my $project = 'cmms';
my %conf;
$LOCAL_INSTALL_ROOT = '/usr/local/cmms';
$LOCAL_HTTP_ROOT    = "$LOCAL_INSTALL_ROOT/htdocs";

my $databases = {
    'cmms' => {
        schema => 'sql/schema.sql',
        user   => 'cmms',
	password => "cmms",
    }
};

# check dependencies

my $dependencies = [
		    {
		      name     => 'Mysql',
		      check_fn => \&Install::Base::bad_mysql
		    },
                    {
                      name     => 'Apache',
                      check_fn => \&Install::Base::bad_apache
                    },
		   ];


print "1. Checking dependancies:\n";
print "   ----------------------\n\n";
my $failures = Install::Base::check_dependencies($dependencies);
die("$failures dependencies failed!") if $failures > 0;

# request installation locations

print <<EndText

2. Establishing installation locations:
   ------------------------------------

Please answer the following questions. To select the default value, simply 
press return at each prompt.

If you are unsure of the correct value, use the default.

EndText
    ;

$LOCAL_INSTALL_ROOT = Install::Base->prompt_and_read("$project installation root",$LOCAL_INSTALL_ROOT);
$LOCAL_HTTP_ROOT = Install::Base->prompt_and_read('HTML installation directory:',$LOCAL_HTTP_ROOT);

print <<EndText

3. Finding MySQL details:
   ----------------------

$project uses a MySQL database to store the community information and
user responses.

EndText
    ;

my($m_user,$m_pass) = Install::MySQL->get_admin_auth();
my $im = new Install::MySQL(username=>$m_user, password=>$m_pass);
$im->set_install_config($databases,\%conf);

# HTML installation command
$conf{html} = "install_copier --source htdocs --destination $LOCAL_HTTP_ROOT --mkpath";

# Apache setup

print <<EndText

4. Setup of Apache Server
   ----------------------

$project needs an Apache web server running EmbPerl for both collection
of user responses and administration of users.

EndText
;

my $webnode = Install::WebNode->new($project);
$webnode->set_install_config(\%conf,$LOCAL_HTTP_ROOT);

# overwrite existing config?
my $show = `webnode_show --id cmms`;
if( $show ) {
  my $overwrite = Install::Base->prompt_and_read("Apache config for $project already exists, overwrite?",'no');
  if ($overwrite eq 'no' or $overwrite eq 'n') {
    delete($conf{wn});
  } else {
    $conf{wn} =~ s/--create/--update/;
  }
}

# HTML installation command
$conf{html} = "install_copier --source htdocs --destination $LOCAL_HTTP_ROOT --mkpath";
$conf{bin} = "install_copier --source bin --destination $LOCAL_INSTALL_ROOT/bin --mkpath";
$conf{framework} = "framework_builder --config=conf/framework.conf";

Install::Base->write_conf(\%conf);  # write config
