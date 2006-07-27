#!/bin/bash

CDROM=`grep -c '/dev/cdrom' /etc/fstab`

if [ "$CDROM" = "0" ]; then
  echo "Adding /dev/cdrom listing to /etc/fstab"
  echo "/dev/cdrom              /media/cdrom            auto    pamconsole,exec,noauto,fscontext=system_u:object_r:removable_t 0 0" >> /etc/fstab
fi
