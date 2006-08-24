#!/bin/bash

if [ ! -f /etc/cmms.conf ]; then
  echo "Installing new CMS config"
  /bin/cp /usr/local/cmms/cmms.conf /etc/
fi
