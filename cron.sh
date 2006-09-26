#!/bin/bash

CRON=`grep -c '/usr/bin/cmms_poll.pl' /etc/crontab`

if [ "$CRON" = "0" ]; then
  echo "Adding polling entry to /etc/crontab"
  echo "# CMS ssh connection" >> /etc/crontab
  echo "10 * * * * root /usr/bin/cmms_poll.pl 1>/dev/null 2>&1" >> /etc/crontab
  /sbin/service crond restart
fi
