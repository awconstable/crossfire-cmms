%define perl_vendorlib %(eval "`perl -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`perl -V:installvendorarch`"; echo $installvendorarch)
%define perlname cmms
Summary: Perl cmms::ripper module
Name: perl-%{perlname}
Version: 1.1.2
Release: 53
License: Artistic, GPL
Group: System Environment/Libraries
Source: cmms-%{version}.tar.gz
Patch999: perl-cmms-shbang.patch

Packager: perl2rpm [root root@localdomain]
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
Requires: lcdproc normalize irmp3 cdde cdparanoia lame flac flac123 cd-discid rexima alsa-utils framework-theme-crossfire samba perl-Filesys-Df perl-Net-IP perl-Net-Interface webmin nagios nagios-nrpe nagios-plugins nagios-plugins-nrpe framework-javascript framework-scripts perl-coreware-server-monitor tw_cli check_3ware perl-Net-FreeDB = 0.08-1 perl-CDDB-File = 1.05-1 taglib-devel taglib perl-Audio-TagLib
URL: http://www.cpan.org/
Vendor: coreware
BuildPrereq: perl coreware-mysql coreware-installer perl-DBD-mysql

%description
Perl cmms::ripper module

%prep
%setup -n %{perlname}-%{version}
%patch999 -p1 -b .shbang

%build
%{__perl} Makefile.PL </dev/null
%{__sed} -e 's:^\(INSTALL[A-Z0-9_]*\(BIN\|ARCH\|SCRIPT\|LIB\|MAN[1-9]DIR\)\) = :\1 = '"$RPM_BUILD_ROOT"':' Makefile >Makefile2
%{__cat} Makefile2 >Makefile
%{__make}

%install
[ "$RPM_BUILD_ROOT" != "/" ] && %{__rm} -rf $RPM_BUILD_ROOT
%{__make} install INSTALLDIRS=vendor
%{__rm} -f $RPM_BUILD_ROOT%{perl_vendorlib}/config.pl
%{__rm} -f $RPM_BUILD_ROOT%{perl_archlib}/perllocal.pod
%{__rm} -f $RPM_BUILD_ROOT%{perl_vendorarch}/auto/cmms/.packlist
mkdir -p $RPM_BUILD_ROOT/usr/local/cmms/logs
mkdir -p $RPM_BUILD_ROOT/usr/local/cmms/logs/archive
mkdir -p $RPM_BUILD_ROOT/usr/local/cmms/sql
%{__cp} sql/schema.sql $RPM_BUILD_ROOT/usr/local/cmms/sql/
mkdir -p $RPM_BUILD_ROOT/usr/bin
install -c -m 755 bin/ripper.pl $RPM_BUILD_ROOT/usr/bin/cmms_ripper.pl
install -c -m 755 bin/import.pl $RPM_BUILD_ROOT/usr/bin/cmms_import.pl
install -c -m 755 bin/crestron.pl $RPM_BUILD_ROOT/usr/bin/cmms_crestron.pl
install -c -m 755 bin/zone.pl $RPM_BUILD_ROOT/usr/bin/cmms_zone.pl
install -c -m 755 bin/cmmsd.pl $RPM_BUILD_ROOT/usr/bin/
install -c -m 755 bin/player.pl $RPM_BUILD_ROOT/usr/bin/cmms_player.pl
install -c -m 755 bin/poll.pl $RPM_BUILD_ROOT/usr/bin/cmms_poll.pl
install -c -m 755 bin/file_import_daemon.pl $RPM_BUILD_ROOT/usr/bin/cmms_file_import_daemon.pl
mkdir -p $RPM_BUILD_ROOT/etc/rc.d/init.d
install -c -m 755 init/cmmsd $RPM_BUILD_ROOT/etc/rc.d/init.d/
install -c -m 755 init/cdde $RPM_BUILD_ROOT/etc/rc.d/init.d/
install -c -m 755 init/cmms_player $RPM_BUILD_ROOT/etc/rc.d/init.d/
install -c -m 755 init/LCDd $RPM_BUILD_ROOT/etc/rc.d/init.d/
install -c -m 755 init/LCDd $RPM_BUILD_ROOT/etc/rc.d/init.d/
install -c -m 755 init/cmmsfiled $RPM_BUILD_ROOT/etc/rc.d/init.d/

%{__cp} conf/cdde.xml $RPM_BUILD_ROOT/etc/
%{__cp} conf/LCDd.conf $RPM_BUILD_ROOT/etc/
%{__cp} conf/smb.conf $RPM_BUILD_ROOT/usr/local/cmms/
mkdir -p $RPM_BUILD_ROOT/usr/local/apache/conf/
%{__cp} conf/httpd.conf $RPM_BUILD_ROOT/usr/local/apache/conf/httpd.conf.cmms

mkdir -p $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
mkdir -p $RPM_BUILD_ROOT/usr/local/cw-server-monitor/report.d/
%{__cp} conf/monitor/disk.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/load.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/proc.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/raid.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/users.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/zombie.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/inn-report.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/report.d/

mkdir -p $RPM_BUILD_ROOT/etc/logrotate.d/
install -D -m 644 conf/logrotate $RPM_BUILD_ROOT/etc/logrotate.d/cmms

mkdir -m 777 -p $RPM_BUILD_ROOT/usr/local/cmms/htdocs/media
mkdir -m 777 -p $RPM_BUILD_ROOT/usr/local/cmms/htdocs/import
mkdir -m 777 -p $RPM_BUILD_ROOT/usr/local/cmms/htdocs/import/failed

mkdir -p $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/
mkdir -p $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/images/
mkdir -p $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/lang/

%{__cp} webmin/cmms/images/*.gif $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/images/
%{__cp} webmin/cmms/module.info $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/
%{__cp} webmin/cmms/lang/en $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/lang/
install -c -m 755 webmin/cmms/*.cgi $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/

# cdde fstab patch
install -c -m 755 cdrom.sh $RPM_BUILD_ROOT/usr/local/cmms/

# webmin user patch
install -c -m 755 webmin.sh $RPM_BUILD_ROOT/usr/local/cmms/

# ssh conf
install -c -m 755 ssh.sh $RPM_BUILD_ROOT/usr/local/cmms/

# cmms conf
install -c -m 755 conf.sh $RPM_BUILD_ROOT/usr/local/cmms/

# nagios conf
install -c -m 755 nagios.sh $RPM_BUILD_ROOT/usr/local/cmms/

# nagios conf
install -c -m 755 cron.sh $RPM_BUILD_ROOT/usr/local/cmms/

# copy rpm conf
%{__cp} conf/cmms.conf $RPM_BUILD_ROOT/usr/local/cmms/

# Framework
%{__perl} -Mblib /usr/bin/framework_builder --config=conf/framework.conf
mkdir -p $RPM_BUILD_ROOT/usr/local/cmms/htdocs/scripts
%{__cp} -r htdocs/* $RPM_BUILD_ROOT/usr/local/cmms/htdocs/

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && %{__rm} -rf $RPM_BUILD_ROOT

%post
install_mysql_db --schema /usr/local/cmms/sql/schema.sql --username cmms --password cmms --perm_user root cmms
/bin/bash /usr/local/cmms/webmin.sh
/bin/bash /usr/local/cmms/cdrom.sh

# Set DNS search path
/bin/cat /etc/resolv.conf | /bin/sed "s/search .*/search crossfire-media.com/" >/tmp/resolv.conf
/bin/mv /tmp/resolv.conf /etc/resolv.conf

/bin/bash /usr/local/cmms/ssh.sh

# install cmms config
/bin/bash /usr/local/cmms/conf.sh

/bin/mv /usr/local/apache/conf/httpd.conf /usr/local/apache/conf/httpd.orig
/bin/cp /usr/local/apache/conf/httpd.conf.cmms /usr/local/apache/conf/httpd.conf

/bin/cp /usr/local/cmms/smb.conf /etc/samba/

/bin/echo -e 'cmms\ncmms' | /usr/bin/smbpasswd -s -a root

/bin/bash /usr/local/cmms/nagios.sh

/bin/cat /etc/nagios/nrpe.cfg | /bin/sed "s/hda1/sda1/" >/tmp/nrpe.cfg
/bin/mv /tmp/nrpe.cfg /etc/nagios/nrpe.cfg
/bin/cat /etc/nagios/nrpe.cfg | /bin/sed "s/hdb1/sda2/" >/tmp/nrpe.cfg
/bin/mv /tmp/nrpe.cfg /etc/nagios/nrpe.cfg

/bin/bash /usr/local/cmms/cron.sh

# Service setup

/sbin/chkconfig --add cdde
/sbin/chkconfig --add LCDd
/sbin/chkconfig --add cmms_player
/sbin/chkconfig --add cmmsd

/sbin/chkconfig --level 2345 apache on
/sbin/chkconfig --level 2345 mysqld on
/sbin/chkconfig --level 2345 smb on

/sbin/service cdde restart
/sbin/service LCDd restart
/sbin/service cmms_player restart
/sbin/service cmmsd restart
/sbin/service cmmsfiled restart

/usr/bin/cn_passwd --user admin --password cmms

# Apache config
SLOT=$(ifconfig | perl -nle 'print $1 if /inet addr:\d+.\d+.\d+.(\d+)\s/' | head -n 1)

/usr/bin/webnode_admin --create --id cmms --documentroot /usr/local/cmms/htdocs \
        --shortname cmms --servername cmms.$HOSTNAME --slot $SLOT --template default \
                && /usr/bin/webnode_admin --rebuild && service apache condrestart || true

/sbin/service apache restart

%files
%defattr(-,root,root)

%doc %{_mandir}/man3/CMMS::Database::UI::Edit.3pm*
%doc %{_mandir}/man3/CMMS::Database::artist.3pm*
%doc %{_mandir}/man3/CMMS::Database::composer.3pm*
%doc %{_mandir}/man3/CMMS::Database::conductor.3pm*
%doc %{_mandir}/man3/CMMS::Database::Theme::HTML.3pm*
%doc %{_mandir}/man3/CMMS::Database::playlist.3pm*
%doc %{_mandir}/man3/CMMS::Database::track.3pm*
%doc %{_mandir}/man3/CMMS::Database::UI::Attacher.3pm*
%doc %{_mandir}/man3/CMMS::Database::Object.3pm*
%doc %{_mandir}/man3/CMMS::Database::album.3pm*
%doc %{_mandir}/man3/CMMS::Database::MysqlConnection.3pm*
%doc %{_mandir}/man3/CMMS::Database::MysqlConnectionEscape.3pm*
%doc %{_mandir}/man3/CMMS::Database::genre.3pm*
%doc %{_mandir}/man3/CMMS::Database::UI::Selector.3pm*
%doc %{_mandir}/man3/CMMS::Database::track_data.3pm*
%doc %{_mandir}/man3/CMMS::Database::playlist_current.3pm*
%doc %{_mandir}/man3/CMMS::Database::UI::Report.3pm*
%doc %{_mandir}/man3/CMMS::Database::zone_mem.3pm*
%doc %{_mandir}/man3/CMMS::Database::zone.3pm*
%doc %{_mandir}/man3/CMMS::Database::playlist_track.3pm*
%doc %{_mandir}/man3/CMMS::Database::Theme::Theme.3pm*
%dir %{_libdir}/perl5/5.8.5
%{perl_vendorlib}/CMMS/Psudo.pm
%{perl_vendorlib}/CMMS/Ripper.pm
%{perl_vendorlib}/CMMS/File.pm
%{perl_vendorlib}/CMMS/Track.pm
%{perl_vendorlib}/CMMS/Ripper/Extractor/Generic.pm
%{perl_vendorlib}/CMMS/Ripper/Extractor/cdparanoia.pm
%dir %{perl_vendorlib}/CMMS/Ripper/Extractor
%{perl_vendorlib}/CMMS/Ripper/DiscID/Generic.pm
%{perl_vendorlib}/CMMS/Ripper/DiscID/freedb.pm
%dir %{perl_vendorlib}/CMMS/Ripper/DiscID
%{perl_vendorlib}/CMMS/Ripper/Encoder/lame.pm
%{perl_vendorlib}/CMMS/Ripper/Encoder/Generic.pm
%{perl_vendorlib}/CMMS/Ripper/Encoder/flac.pm
%dir %{perl_vendorlib}/CMMS/Ripper/Encoder
%dir %{perl_vendorlib}/CMMS/Ripper
%dir %{perl_vendorlib}/CMMS/Track
%{perl_vendorlib}/CMMS/Track/Enhanced.pm
%{perl_vendorlib}/CMMS/Zone/Player.pm
%{perl_vendorlib}/CMMS/Zone/Status.pm
%{perl_vendorlib}/CMMS/Zone/Command.pm
%{perl_vendorlib}/CMMS/Zone/Library.pm
%{perl_vendorlib}/CMMS/Zone/Sender.pm
%{perl_vendorlib}/CMMS/Zone/NowPlaying.pm
%dir %{perl_vendorlib}/CMMS/Zone
%{perl_vendorlib}/CMMS/Database/track.pm
%{perl_vendorlib}/CMMS/Database/playlist_current.pm
%{perl_vendorlib}/CMMS/Database/track_data.pm
%{perl_vendorlib}/CMMS/Database/genre.pm
%{perl_vendorlib}/CMMS/Database/zone_mem.pm
%{perl_vendorlib}/CMMS/Database/zone.pm
%{perl_vendorlib}/CMMS/Database/MysqlConnection.pm
%{perl_vendorlib}/CMMS/Database/MysqlConnectionEscape.pm
%{perl_vendorlib}/CMMS/Database/Object.pm
%{perl_vendorlib}/CMMS/Database/playlist.pm
%{perl_vendorlib}/CMMS/Database/playlist_track.pm
%{perl_vendorlib}/CMMS/Database/artist.pm
%{perl_vendorlib}/CMMS/Database/composer.pm
%{perl_vendorlib}/CMMS/Database/conductor.pm
%{perl_vendorlib}/CMMS/Database/album.pm
%{perl_vendorlib}/CMMS/Database/UI/Attacher.pm
%{perl_vendorlib}/CMMS/Database/UI/Selector.pm
%{perl_vendorlib}/CMMS/Database/UI/Edit.pm
%{perl_vendorlib}/CMMS/Database/UI/Report.pm
%dir %{perl_vendorlib}/CMMS/Database/UI
%{perl_vendorlib}/CMMS/Database/Theme/Theme.pm
%{perl_vendorlib}/CMMS/Database/Theme/HTML.pm
%dir %{perl_vendorlib}/CMMS/Database/Theme
%dir %{perl_vendorlib}/CMMS/Database
%dir %{perl_vendorlib}/CMMS
/usr/bin
/etc/
/usr/local/cmms/ssh.sh
/usr/local/cmms/cron.sh
/usr/local/cmms/cmms.conf
/usr/local/cmms/conf.sh
/usr/local/cmms/cdrom.sh
/usr/local/cmms/webmin.sh
/usr/local/cmms/nagios.sh
/usr/local/cmms/smb.conf
/usr/local/cmms/sql
/usr/local/cmms/logs
/usr/local/cmms/logs/archive
/usr/local/cmms/htdocs
/usr/local/apache/conf/httpd.conf.cmms
/usr/local/cw-server-monitor/agent.d/
/usr/local/cw-server-monitor/report.d/
/etc/logrotate.d/
/usr/libexec/webmin/cmms/
/usr/libexec/webmin/cmms/images
/usr/libexec/webmin/cmms/lang
%doc 
