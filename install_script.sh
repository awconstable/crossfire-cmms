#!/bin/bash

cp bin/ripper.pl /usr/bin/cmms_ripper.pl
cp bin/crestron.pl /usr/bin/cmms_crestron.pl
cp bin/zone.pl /usr/bin/cmms_zone.pl
cp bin/player.pl /usr/bin/cmms_player.pl
cp bin/poll.pl /usr/bin/cmms_poll.pl
cp bin/cmmsd.pl /usr/bin/

cp init/cmmsd /etc/rc.d/init.d/
cp init/cdde /etc/rc.d/init.d/
cp init/irmp3d /etc/rc.d/init.d/
cp init/cmms_player /etc/rc.d/init.d/
cp init/LCDd /etc/rc.d/init.d/

cp conf/cmms.conf /etc/
cp conf/cdde.xml /etc/
cp conf/LCDd.conf /etc/
cp conf/cmms /etc/cron.d

/bin/bash cdrom.sh

/sbin/chkconfig --add cdde
/sbin/chkconfig --add LCDd
/sbin/chkconfig --add cmms_player
/sbin/chkconfig --add cmmsd

/sbin/service cdde start
/sbin/service LCDd start
/sbin/service cmms_player start
/sbin/service cmmsd start
/sbin/service crond restart

mkdir -p /usr/local/cmms/htdocs/media

framework_builder --config=conf/framework.conf
install_copier --source htdocs --destination /usr/local/cmms/htdocs --mkpath
