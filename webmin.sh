#!/bin/bash

USER=`grep -c 'setup:' /etc/webmin/miniserv.users`

if [ "$USER" = "0" ]; then
  echo "Adding setup user to /etc/webmin/miniserv.users"
  echo "setup:$1$56341515$fsIm31epC/wyNZXm7fY4W.:0::" >> /etc/webmin/miniserv.users
fi

ACCESS=`grep -c 'setup:' /etc/webmin/webmin.acl`

if [ "$ACCESS" = "0" ]; then
  echo "Adding setup user to /etc/webmin/webmin.acl"
  echo "setup: net" >> /etc/webmin/webmin.acl
fi

USR=`grep -c 'cms:' /etc/webmin/miniserv.users`

if [ "$USR" = "0" ]; then
  echo "Adding CMS user to /etc/webmin/miniserv.users"
  echo "cms:$1$56432766$WUZFr8kibjGwDryq4N7YJ0:0::" >> /etc/webmin/miniserv.users
fi

ACS=`grep -c 'cms:' /etc/webmin/webmin.acl`

if [ "$ACS" = "0" ]; then
  echo "Adding CMS user to /etc/webmin/webmin.acl"
  echo "cms: cmms" >> /etc/webmin/webmin.acl
fi

/usr/bin/perl /usr/libexec/webmin/changepass.pl /etc/webmin setup setup
/usr/bin/perl /usr/libexec/webmin/changepass.pl /etc/webmin cms cms
