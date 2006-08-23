#!/bin/bash

WEBMIN=`grep -c '/etc/webmin/miniserv.users' setup`

if [ "$WEBMIN" = "0" ]; then
  echo "Adding setup user to /etc/webmin/miniserv.users"
  echo "setup:$1$56341515$fsIm31epC/wyNZXm7fY4W.:0::" >> /etc/webmin/miniserv.users
fi
