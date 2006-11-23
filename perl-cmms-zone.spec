%define perl_vendorlib %(eval "`perl -V:installvendorlib`"; echo $installvendorlib)
%define perl_vendorarch %(eval "`perl -V:installvendorarch`"; echo $installvendorarch)
%define perlname cmms-zone
Summary: Perl cmms::ripper module
Name: perl-%{perlname}
Version: 1.1.2
Release: 26
License: Artistic, GPL
Group: System Environment/Libraries
Source: cmms-%{version}.tar.gz
Patch999: perl-cmms-shbang.patch

Packager: perl2rpm [root root@localdomain]
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
Requires: lcdproc irmp3 flac123 rexima alsa-utils samba-client perl-coreware-server-monitor webmin tw_cli check_3ware
URL: http://www.cpan.org/
Vendor: coreware
BuildPrereq: perl coreware-mysql coreware-installer perl-DBD-mysql

%description
Perl cmms::ripper module

%prep
%setup -n cmms-%{version}

%build

%install
[ "$RPM_BUILD_ROOT" != "/" ] && %{__rm} -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/local/cmms/logs
mkdir -p $RPM_BUILD_ROOT/usr/local/cmms/logs/archive
mkdir -p $RPM_BUILD_ROOT/usr/bin
install -c -m 755 bin/player.pl $RPM_BUILD_ROOT/usr/bin/cmms_player.pl
install -c -m 755 bin/poll.pl $RPM_BUILD_ROOT/usr/bin/cmms_poll.pl
mkdir -p $RPM_BUILD_ROOT/etc/rc.d/init.d
install -c -m 755 init/cmms_player $RPM_BUILD_ROOT/etc/rc.d/init.d/
install -c -m 755 init/LCDd $RPM_BUILD_ROOT/etc/rc.d/init.d/
install -c -m 755 conf/LCDd.conf $RPM_BUILD_ROOT/etc/

mkdir -p $RPM_BUILD_ROOT/etc/logrotate.d/
install -D -m 644 conf/logrotate $RPM_BUILD_ROOT/etc/logrotate.d/cmms

mkdir -p $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
mkdir -p $RPM_BUILD_ROOT/usr/local/cw-server-monitor/report.d/
%{__cp} conf/monitor/disk.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/load.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/proc.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/raid.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/users.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/zombie.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/agent.d/
%{__cp} conf/monitor/inn-report.conf $RPM_BUILD_ROOT/usr/local/cw-server-monitor/report.d/

mkdir -p $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/
mkdir -p $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/images/
mkdir -p $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/lang/

%{__cp} webmin/cmms/images/*.gif $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/images/
%{__cp} webmin/cmms/module.info $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/
%{__cp} webmin/cmms/lang/en $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/lang/
install -c -m 755 webmin/cmms/*.cgi $RPM_BUILD_ROOT/usr/libexec/webmin/cmms/

# copy rpm conf
%{__cp} conf/cmms.conf $RPM_BUILD_ROOT/usr/local/cmms/

# ssh conf
install -c -m 755 ssh.sh $RPM_BUILD_ROOT/usr/local/cmms/

# cmms conf
install -c -m 755 conf.sh $RPM_BUILD_ROOT/usr/local/cmms/

# webmin user patch
install -c -m 755 webmin.sh $RPM_BUILD_ROOT/usr/local/cmms/

# nagios conf
install -c -m 755 nagios.sh $RPM_BUILD_ROOT/usr/local/cmms/

# cron conf
install -c -m 755 cron.sh $RPM_BUILD_ROOT/usr/local/cmms/

# samba fstab patch
%{__cp} samba.sh $RPM_BUILD_ROOT/usr/local/cmms/

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && %{__rm} -rf $RPM_BUILD_ROOT

%post

# Set DNS search path
/bin/cat /etc/resolv.conf | /bin/sed "s/search .*/search crossfire-media.com/" >/tmp/resolv.conf
/bin/mv /tmp/resolv.conf /etc/resolv.conf

/bin/bash /usr/local/cmms/ssh.sh

# install cmms config
/bin/bash /usr/local/cmms/conf.sh

/bin/bash /usr/local/cmms/samba.sh
/bin/bash /usr/local/cmms/webmin.sh
/bin/bash /usr/local/cmms/nagios.sh
/bin/bash /usr/local/cmms/cron.sh

mkdir -p /usr/local/cmms/htdocs/media

/bin/cat /etc/nagios/nrpe.cfg | /bin/sed "s/hda1/sda1/" >/tmp/nrpe.cfg
/bin/mv /tmp/nrpe.cfg /etc/nagios/nrpe.cfg
/bin/cat /etc/nagios/nrpe.cfg | /bin/sed "s/hdb1/sda2/" >/tmp/nrpe.cfg
/bin/mv /tmp/nrpe.cfg /etc/nagios/nrpe.cfg

mount /usr/local/cmms/htdocs/media

/sbin/chkconfig --add LCDd
/sbin/chkconfig --add cmms_player
/sbin/service LCDd restart
/sbin/service cmms_player restart

%files
%defattr(-,root,root)

/usr/bin
/usr/bin/cmms_player.pl
/etc/rc.d/init.d
/etc/rc.d/init.d/cmms_player
/etc/rc.d/init.d/LCDd
/etc/
/etc/LCDd.conf
/usr/local/cmms/logs
/usr/local/cmms/logs/archive
/usr/local/cmms/ssh.sh
/usr/local/cmms/cron.sh
/usr/local/cmms/cmms.conf
/usr/local/cmms/conf.sh
/usr/local/cmms/samba.sh
/usr/local/cmms/webmin.sh
/usr/local/cmms/nagios.sh
/usr/local/cw-server-monitor/agent.d/
/usr/local/cw-server-monitor/report.d/
/etc/logrotate.d/
/usr/libexec/webmin/cmms/
/usr/libexec/webmin/cmms/images
/usr/libexec/webmin/cmms/lang
%doc 
