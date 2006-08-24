#!/bin/bash

USER=`grep -c 'setup:' /etc/webmin/miniserv.users`

if [ "$USER" = "0" ]; then
  echo "Adding setup user to /etc/webmin/miniserv.users"
  echo "setup:$1$56341515$fsIm31epC/wyNZXm7fY4W.:0::" >> /etc/webmin/miniserv.users
fi

ACCESS=`grep -c 'setup:' /etc/webmin/webmin.acl`

if [ "$ACCESS" = "0" ]; then
  echo "Adding setup user to /etc/webmin/webmin.acl"
  echo "setup: cmms net" >> /etc/webmin/webmin.acl
fi
