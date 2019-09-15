#!/bin/bash

if test $UID -ne 0; then
  echo "This script has to be run as root. Exiting."
  exit 1
fi

LBHOME="/opt/loxberry"

# Group membership
/usr/sbin/usermod -a -G sudo,dialout,audio,gpio,tty,www-data loxberry

# LoxBerry Home Directory in Environment
awk -v s="LBHOMEDIR=$LBHOME" '/^LBHOMEDIR=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment

# Main directories for plugins
awk -v s="LBPHTMLAUTH=$LBHOME/webfrontend/htmlauth/plugins" '/^LBPHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPHTML=$LBHOME/webfrontend/html/plugins" '/^LBPHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPTEMPL=$LBHOME/templates/plugins" '/^LBPTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPDATA=$LBHOME/data/plugins" '/^LBPDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPLOG=$LBHOME/log/plugins" '/^LBPLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPCONFIG=$LBHOME/config/plugins" '/^LBPCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPBIN=$LBHOME/bin/plugins" '/^LBPBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment

# Main directories for system
awk -v s="LBSHTMLAUTH=$LBHOME/webfrontend/htmlauth/system" '/^LBSHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSHTML=$LBHOME/webfrontend/html/system" '/^LBSHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSTEMPL=$LBHOME/templates/system" '/^LBSTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSDATA=$LBHOME/data/system" '/^LBSDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSLOG=$LBHOME/log/system" '/^LBSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSTMPFSLOG=$LBHOME/log/system_tmpfs" '/^LBSTMPFSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSCONFIG=$LBHOME/config/system" '/^LBSCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSBIN=$LBHOME/bin" '/^LBSBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSSBIN=$LBHOME/sbin" '/^LBSSBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment

# Set Perl library path for LoxBerry Modules
awk -v s="PERL5LIB=$LBHOME/libs/perllib" '/^PERL5LIB=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
# echo PERL5LIB=$LBHOME/libs/perllib  >> /etc/environment

#Environment Variablen laden
source /etc/environment

# LoxBerry global environment variables in Apache
ENVVARS=$LBHOME/system/apache2/envvars

awk -v s="## LoxBerry global environment variables" '/^## LoxBerry global environment variables/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBHOMEDIR=$LBHOMEDIR" '/^export LBHOMEDIR=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS

awk -v s="export LBPHTMLAUTH=$LBPHTMLAUTH" '/^export LBPHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPHTML=$LBPHTML" '/^export LBPHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPTEMPL=$LBPTEMPL" '/^export LBPTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPDATA=$LBPDATA" '/^export LBPDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPLOG=$LBPLOG" '/^export LBPLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPCONFIG=$LBPCONFIG" '/^export LBPCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPBIN=$LBPBIN" '/^export LBPBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS

awk -v s="export LBSHTMLAUTH=$LBSHTMLAUTH" '/^export LBSHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSHTML=$LBSHTML" '/^export LBSHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSTEMPL=$LBSTEMPL" '/^export LBSTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSDATA=$LBSDATA" '/^export LBSDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSLOG=$LBSLOG" '/^export LBSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSTMPFSLOG=$LBSTMPFSLOG" '/^export LBSTMPFSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSCONFIG=$LBSCONFIG" '/^export LBSCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSBIN=$LBSBIN" '/^export LBSBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSSBIN=$LBSSBIN" '/^export LBSSBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS

awk -v s="export PERL5LIB=$PERL5LIB" '/^export PERL5LIB=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS


if systemctl --no-pager status apache2; then
	systemctl force-reload apache2 
fi

# Remove 127.0.1.1 from /etc/hosts
sed -i '/127\.0\.1\.1.*$/d' /etc/hosts

# sudoers.d
if [ -d /etc/suddoers.d ]; then
	mv /etc/sudoers.d /etc/sudoers.d.orig
fi
if [ -L /etc/sudoers.d ]; then
    rm /etc/sudoers.d
fi
ln -s $LBHOME/system/sudoers /etc/sudoers.d
# sudoers: Replace /opt/loxberry with current home path
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/sudoers/lbdefaults

# profile.d/loxberry.sh
if [ -L /etc/profile.d/loxberry.sh ]; then
    rm /etc/profile.d/loxberry.sh
fi
ln -s $LBHOME/system/profile/loxberry.sh /etc/profile.d/loxberry.sh

# Obsolete Apache2 logrotate config (we this by our own)
if [ -e /etc/logrotate.d/apache2 ]; then
    rm /etc/logrotate.d/apache2
fi

# LoxBerry Init Script
if [ -L /etc/init.d/loxberry ]; then  
   rm /etc/init.d/loxberry
fi
if [ -e /etc/systemd/system/loxberry.service ]; then
	rm /etc/systemd/system/loxberry.service
fi
ln -s $LBHOME/system/systemd/loxberry.service /etc/systemd/system/loxberry.service
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/systemd/loxberry.service
/bin/systemctl daemon-reload
/bin/systemctl enable loxberry.service

# Createtmpfs Init Script
if [ -L /etc/init.d/createtmpfsfoldersinit ]; then  
   rm /etc/init.d/createtmpfsfoldersinit
fi
if [ -e /etc/systemd/system/createtmpfs.service ]; then
	rm /etc/systemd/system/createtmpfs.service
fi
ln -s $LBHOME/system/systemd/createtmpfs.service /etc/systemd/system/createtmpfs.service
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/systemd/createtmpfs.service
/bin/systemctl daemon-reload
/bin/systemctl enable createtmpfs.service

# Apache Config
if [ ! -L /etc/apache2 ]; then
	mv /etc/apache2 /etc/apache2.old
fi
if [ -L /etc/apache2 ]; then  
    rm /etc/apache2
fi
ln -s $LBHOME/system/apache2 /etc/apache2

# Disable PrivateTmp for Apache2 on systemd
# (also included in 1.0.2 Update script)
if [ ! -e /etc/systemd/system/apache2.service.d/privatetmp.conf ]; then
	mkdir -p /etc/systemd/system/apache2.service.d
	echo -e "[Service]\nPrivateTmp=no" > /etc/systemd/system/apache2.service.d/privatetmp.conf 
fi

# Network config
if [ ! -L /etc/network/interfaces ]; then
	mv /etc/network/interfaces /etc/network/interfaces.old
fi
if [ -L /etc/network/interfaces ]; then  
    rm /etc/network/interfaces
fi
ln -s $LBHOME/system/network/interfaces /etc/network/interfaces

# Logrotate job - move to hourly
if [ -e /etc/cron.daily/logrotate ] ; then mv -f /etc/cron.daily/logrotate /etc/cron.hourly/ ; fi 
# Logrotate config
if [ -L /etc/logrotate.d/loxberry ]; then
    rm /etc/logrotate.d/loxberry
fi
ln -s $LBHOME/system/logrotate/logrotate /etc/logrotate.d/loxberry

# Samba Config
if [ ! -L /etc/samba ]; then
	mv /etc/samba /etc/samba.old
fi
if [ -L /etc/samba ]; then
    rm /etc/samba
fi
ln -s $LBHOME/system/samba /etc/samba

# VSFTPd Config
if [ ! -L /etc/vsftpd.conf ]; then
	mv /etc/vsftpd.conf /etc/vsftpd.conf.old
fi
if [ -L /etc/vsftpd.conf ]; then
    rm /etc/vsftpd.conf
fi
ln -s $LBHOME/system/vsftpd/vsftpd.conf /etc/vsftpd.conf

# MSMTP Config
rm $LBHOME/.msmtprc
if [ -e $LBHOME/system/msmtp/msmtprc ]; then
	ln -s $LBHOME/system/msmtp/msmtprc $LBHOME/.msmtprc
	chmod 0600 $LBHOME/system/msmtp/msmtprc
	chown loxberry:loxberry $LBHOME/system/msmtp/msmtprc
fi
chmod 0600 $LBHOME/system/msmtp/aliases
chown loxberry:loxberry $LBHOME/system/msmtp/aliases

# PHP
# Set PHP include_path directive
if [ -e /etc/php/7.0 ] && [ ! -e /etc/php/7.0/apache2/conf.d/20-loxberry.ini ]; then
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.0/apache2/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.0/cgi/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.0/cli/conf.d/20-loxberry.ini
fi
if [ -e /etc/php/7.1 ] && [ ! -e /etc/php/7.1/apache2/conf.d/20-loxberry.ini ]; then
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.1/apache2/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.1/cgi/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.1/cli/conf.d/20-loxberry.ini
fi
if [ -e /etc/php/7.2 ] && [ ! -e /etc/php/7.2/apache2/conf.d/20-loxberry.ini ]; then
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.2/apache2/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.2/cgi/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.2/cli/conf.d/20-loxberry.ini
fi
if [ -e /etc/php/7.3 ] && [ ! -e /etc/php/7.3/apache2/conf.d/20-loxberry.ini ]; then
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.3/apache2/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.3/cgi/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/20-loxberry.ini /etc/php/7.3/cli/conf.d/20-loxberry.ini
fi

# Cron.d
if [ ! -L /etc/cron.d ]; then
	mv /etc/cron.d /etc/cron.d.old
fi
if [ -L /etc/cron.d ]; then
    rm /etc/cron.d
fi
ln -s $LBHOME/system/cron/cron.d /etc/cron.d

# Skel for system logs, LB system logs and LB plugin logs
if [ -d $LBHOME/log/skel_system/ ]; then
    find $LBHOME/log/skel_system/ -type f -exec rm {} \;
fi
if [ -d $LBHOME/log/skel_syslog/ ]; then
    find $LBHOME/log/skel_syslog/ -type f -exec rm {} \;
fi

# Clean apt cache
rm -rf /var/cache/apt/archives/*

# Systemd service for usb automount
# (also included in 1.0.4 Update script)
if [ -e /etc/systemd/system/usb-mount@.service ]; then
	rm /etc/systemd/system/usb-mount@.service
fi
ln -s $LBHOME/system/systemd/usb-mount@.service /etc/systemd/system/usb-mount@.service
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/systemd/usb-mount@.service
/bin/systemctl daemon-reload

# Create udev rules for usbautomount
# (also included in 1.0.4 Update script)
if [ ! -e /etc/udev/rules.d/99-usbmount.rules ]; then
(cat <<END
KERNEL=="sd[a-z]*[0-9]", SUBSYSTEMS=="usb", ACTION=="add", RUN+="$LBHOME/sbin/usb-mount.sh chkadd %k"
KERNEL=="sd[a-z]*[0-9]", SUBSYSTEMS=="usb", ACTION=="remove", RUN+="/bin/systemctl stop usb-mount@%k.service"
END
) > /etc/udev/rules.d/99-usbmount.rules
fi

# Configure autofs
if [ ! -e /etc/auto.master ]; then
	awk -v s='/media/smb /etc/auto.smb --timeout=300 --ghost' '/^\/media\/smb/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/auto.master
fi
mkdir -p /media/smb
mkdir -p /media/usb
if [ ! -L /etc/auto.smb ]; then
	mv -f /etc/auto.smb /etc/auto.smb.backup
fi
if [ -L /etc/auto.smb ]; then
	rm /etc/auto.smb
fi
ln -s $LBHOME/system/autofs/auto.smb /etc/auto.smb
chmod 0755 $LBHOME/system/autofs/auto.smb
systemctl restart autofs

# creds for AutoFS (SMB)
if [ -L /etc/creds ]; then
    rm /etc/creds
fi
ln -s $LBHOME/system/samba/credentials /etc/creds

# Config for watchdog
systemctl disable watchdog.service
systemctl stop watchdog.service

if [ ! -L /etc/watchdog.conf ]; then
	mv /etc/watchdog.conf /etc/watchdog.bkp
fi
if [ -L /etc/watchdog.conf ]; then
    rm /etc/watchdog.conf
fi
if ! cat /etc/default/watchdog | grep -q -e "watchdog_options.*-v"; then
	/bin/sed -i 's#watchdog_options="\(.*\)"#"watchdog_options="\1 -v"#g' /etc/default/watchdog
fi
/bin/sed -i "s#REPLACELBHOMEDIR#"$LBHOME"#g" $LBHOME/system/watchdog/rsyslog.conf
ln -f -s $LBHOME/system/watchdog/watchdog.conf /etc/watchdog.conf
ln -f -s $LBHOME/system/watchdog/rsyslog.conf /etc/rsyslog.d/10-watchdog.conf
systemctl restart rsyslog.service

# Activating i2c
# (also included in 1.0.3 Update script)
$LBHOME/sbin/activate_i2c.sh

# Mount all from /etc/fstab
if ! grep -q -e "^mount -a" /etc/rc.local; then
	sed -i 's/^exit 0/mount -a\n\nexit 0/g' /etc/rc.local
fi

# Set hosts environment
rm /etc/network/if-up.d/001hosts
rm /etc/dhcp/dhclient-exit-hooks.d/sethosts
ln -f -s $LBHOME/sbin/sethosts.sh /etc/network/if-up.d/001host
ln -f -s $LBHOME/sbin/sethosts.sh /etc/dhcp/dhclient-exit-hooks.d/sethosts 

# Configure swap
service dphys-swapfile stop
swapoff -a
rm -r /var/swap

# Configuring node.js for Christian :-)
rm /etc/apt/sources.list.d/nodesource.list
rm /etc/apt/sources.list.d/yarn.list
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo 'deb https://deb.nodesource.com/node_12.x buster main' > /etc/apt/sources.list.d/nodesource.list
echo 'deb-src https://deb.nodesource.com/node_12.x buster main' >> /etc/apt/sources.list.d/nodesource.list
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get install nodejs yarn

