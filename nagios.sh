#!/bin/bash

NAGIOS=`grep -c 'check_3ware' /etc/nagios/nrpe.cfg`

if [ "$NAGIOS" = "0" ]; then
  echo "Adding check_3ware command to /etc/nagios/nrpe.cfg"
  echo "command[check_3ware]=/usr/lib/nagios/plugins/check_3ware" >> /etc/nagios/nrpe.cfg
  /sbin/service servermonitor restart
fi
