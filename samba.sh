#!/bin/bash

SAMBA=`grep -c '/usr/local/cmms/htdocs/media' /etc/fstab`

if [ "$SAMBA" = "0" ]; then
  echo "Adding master samba share to /etc/fstab"
  echo "//cmms-master/media     /usr/local/cmms/htdocs/media          smbfs    userid=root,passwd=cmms,rw 0 0" >> /etc/fstab
fi
