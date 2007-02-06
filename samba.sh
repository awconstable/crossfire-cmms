#!/bin/bash

SAMBA=`grep -c '/usr/local/cmms/htdocs/media' /etc/fstab`

if [ "$SAMBA" = "0" ]; then
  echo "Adding master samba share to /etc/fstab"
  echo "//10.111.111.1/media     /usr/local/cmms/htdocs/media          cifs    guest,iocharset=utf8 0 0" >> /etc/fstab
  /sbin/service smb restart
fi
