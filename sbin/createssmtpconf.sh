#!/bin/bash

##
## THIS SCRIPT IS OBSOLETE STARTING FROM LOXBERRY 1.4
## Config is set from within mailserver.cgi
##




# What to do
case "$1" in

start)

  if [ -f /tmp/tempssmtpconf.dat ] && [ -f /opt/loxberry/system/ssmtp/ssmtp.conf ]; then
    # Backup old file
    mv /opt/loxberry/system/ssmtp/ssmtp.conf /opt/loxberry/system/ssmtp/ssmtp.conf.bkp
    chmod 600 /opt/loxberry/system/ssmtp/ssmtp.conf.bkp

    # Copy new file
    chmod 600 /tmp/tempssmtpconf.dat
    cp /tmp/tempssmtpconf.dat /opt/loxberry/system/ssmtp/ssmtp.conf
    chmod 600 /opt/loxberry/system/ssmtp/ssmtp.conf
    rm  /tmp/tempssmtpconf.dat
  fi
  ;;

stop)

  if [ -f /opt/loxberry/system/ssmtp/ssmtp.conf.bkp ] && [ -f /opt/loxberry/system/ssmtp/ssmtp.conf ]; then
    # Re-Create old file
    mv /opt/loxberry/system/ssmtp/ssmtp.conf.bkp /opt/loxberry/system/ssmtp/ssmtp.conf
    chmod 600 /opt/loxberry/system/ssmtp/ssmtp.conf
  fi
  ;;

*)
  echo "Use start/stop as parameter"
  ;;

esac
