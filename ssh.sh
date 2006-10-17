#!/bin/bash

if [ ! -f /etc/ssh/ssh_known_hosts ]; then
  echo "Creating /etc/ssh/ssh_known_hosts"
  touch /etc/ssh/ssh_known_hosts
  chmod 600 /etc/ssh/ssh_known_hosts
fi

SSH=`grep -c 'control.crossfire-media.com' /etc/ssh/ssh_known_hosts`

if [ "$SSH" = "0" ]; then
  echo "Adding control.crossfire-media.com host entry to /etc/ssh/ssh_known_hosts"
  echo "control.crossfire-media.com,195.238.240.79 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA358norwwTuBye/dAH4CrGYJvbCrlEWTs49gIk28NxjV7adLOsOg1UVka7pendNrvsXxOrLn4ykrEowi2M7Wq97KvY9sfgcBt3AXyx3L2H1t3sQolbyV6otx0p7SB0kQcO54esHjzTFoTxNuYX75DukN7AFR1BC5ZZ2pTW60R9ns=" >> /etc/ssh/ssh_known_hosts
fi
