#!/bin/bash
# LoxBerry update check, linked into cron.daily, cron.weekly or cron.monthly
# (setting in the WebUI). Those start every job at the same minute (04:23,
# 04:33, 04:43). A random delay of up to 15 minutes spreads the requests of all
# LoxBerrys to GitHub and keeps the check ahead of the Debian/PHP updates
# (cron.daily/05-osupdate starts 30-60 minutes after 04:23). If an update
# or installation is still running, loxberryupdatecheck.pl waits for it.
sleep $((RANDOM % 900))
sudo -n $LBHOMEDIR/sbin/loxberryupdatecheck.pl cron=1
