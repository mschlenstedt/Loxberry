#!/bin/bash

if test $UID -ne 0; then
  echo "This script has to be run as root. Exiting."
  exit 1
fi

LBHOME="/opt/loxberry"

# LoxBerry Home Directory in Environment
awk -v s="LBHOMEDIR=$LBHOME" '/^LBHOMEDIR=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment

# Main directories for plugins
awk -v s="LBPHTMLAUTH=$LBHOME/webfrontend/htmlauth/plugins" '/^LBPHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPHTML=$LBHOME/webfrontend/html/plugins" '/^LBPHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPTEMPL=$LBHOME/templates/plugins" '/^LBPTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPDATA=$LBHOME/data/plugins" '/^LBPDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPLOG=$LBHOME/log/plugins" '/^LBPLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPCONFIG=$LBHOME/config/plugins" '/^LBPCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment

#echo LBPHTMLAUTH=$LBHOME/webfrontend/htmlauth/plugins >> /etc/environment
#echo LBPHTML=$LBHOME/webfrontend/html/plugins >> /etc/environment
#echo LBPTEMPL=$LBHOME/templates/plugins >> /etc/environment
#echo LBPDATA=$LBHOME/data/plugins >> /etc/environment
#echo LBPLOG=$LBHOME/log/plugins >> /etc/environment
#echo LBPCONFIG=$LBHOME/config/plugins >> /etc/environment

# Main directories for system
awk -v s="LBSHTMLAUTH=$LBHOME/webfrontend/htmlauth/system" '/^LBSHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSHTML=$LBHOME/webfrontend/html/system" '/^LBSHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSTEMPL=$LBHOME/templates/system" '/^LBSTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSDATA=$LBHOME/data/system" '/^LBSDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSLOG=$LBHOME/log/system" '/^LBSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSCONFIG=$LBHOME/config/system" '/^LBSCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment

# echo LBSHTMLAUTH=$LBHOME/webfrontend/htmlauth/system >> /etc/environment
# echo LBSHTML=$LBHOME/webfrontend/html/system >> /etc/environment
# echo LBSTEMPL=$LBHOME/templates/system >> /etc/environment
# echo LBSDATA=$LBHOME/data/system >> /etc/environment
# echo LBSLOG=$LBHOME/log/system >> /etc/environment
# echo LBSCONFIG=$LBHOME/config/system >> /etc/environment

# Set Perl library path for LoxBerry Modules
awk -v s="PERL5LIB=$LBHOME/libs/perllib" '/^PERL5LIB=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
# echo PERL5LIB=$LBHOME/libs/perllib  >> /etc/environment

# LoxBerry global environment variables in Apache
ENVVARS=$LBHOME/system/apache2/envvars

# echo '' >> $ENVVARS
# echo '## LoxBerry global environment variables' >> $ENVVARS
# echo export LBHOMEDIR=$LBHOMEDIR >> $ENVVARS

# echo export LBPHTMLAUTH=$LBPHTMLAUTH >> $ENVVARS
# echo export LBPHTML=$LBPHTML >> $ENVVARS
# echo export LBPTEMPL=$LBPTEMPL >> $ENVVARS
# echo export LBPDATA=$LBPDATA >> $ENVVARS
# echo export LBPLOG=$LBPLOG >> $ENVVARS
# echo export LBPCONFIG=$LBPCONFIG >> $ENVVARS
# echo '' >> $ENVVARS
# echo export LBSHTMLAUTH=$LBSHTMLAUTH >> $ENVVARS
# echo export LBSHTML=$LBSHTML >> $ENVVARS
# echo export LBSTEMPL=$LBSTEMPL >> $ENVVARS
# echo export LBSDATA=$LBSDATA >> $ENVVARS
# echo export LBSLOG=$LBSLOG >> $ENVVARS
# echo export LBSCONFIG=$LBSCONFIG >> $ENVVARS

awk -v s="## LoxBerry global environment variables" '/^## LoxBerry global environment variables/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBHOMEDIR=$LBHOMEDIR" '/^export LBHOMEDIR=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS

awk -v s="export LBPHTMLAUTH=$LBPHTMLAUTH" '/^export LBPHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPHTML=$LBPHTML" '/^export LBPHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPTEMPL=$LBPTEMPL" '/^export LBPTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPDATA=$LBPDATA" '/^export LBPDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPLOG=$LBPLOG" '/^export LBPLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBPCONFIG=$LBPCONFIG" '/^export LBPCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS

awk -v s="export LBSHTMLAUTH=$LBSHTMLAUTH" '/^export LBSHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSHTML=$LBSHTML" '/^export LBSHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSTEMPL=$LBSTEMPL" '/^export LBSTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSDATA=$LBSDATA" '/^export LBSDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSLOG=$LBSLOG" '/^export LBSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSCONFIG=$LBSCONFIG" '/^export LBSCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS

# sudoers.d/lbdefault
rm /etc/sudoers.d/lbdefaults
ln -s $LBHOME/system/sudoers/lbdefaults /etc/sudoers.d/lbdefaults

# profile.d/loxberry.sh
rm /etc/profile.d/loxberry.sh
ln -s $LBHOME/system/profile/loxberry.sh /etc/profile.d/loxberry.sh

# Init Script
rm /etc/init.d/loxberry
ln -s $LBHOME/sbin/loxberryinit.sh /etc/init.d/loxberry
update-rc.d loxberry defaults

# Apache Config
if [ ! -L /etc/apache2 ]; then
	mv /etc/apache2 /etc/apache2.old
fi
rm /etc/apache2
ln -s $LBHOME/system/apache2 /etc/apache2

# Lighttpd Config
if [ ! -L /etc/lighttpd ]; then
	mv /etc/lighttpd /etc/lighttpd.old
fi
rm /etc/lighttpd
ln -s $LBHOME/system/lighttpd /etc/lighttpd

# Network config
if [ ! -L /etc/network/interfaces ]; then
	mv /etc/network/interfaces /etc/network/interfaces.old
fi
rm /etc/network/interfaces
ln -s $LBHOME/system/network/interfaces /etc/network/interfaces

# Logrotate
rm /etc/logrotate.d/loxberry
ln -s $LBHOME/system/logrotate/logrotate /etc/logrotate.d/loxberry

# Samba Config
if [ ! -L /etc/samba ]; then
	mv /etc/samba /etc/samba.old
fi
rm /etc/samba
ln -s $LBHOME/system/samba /etc/samba

# VSFTPd Config
if [ ! -L /etc/vsftpd.conf ]; then
	mv /etc/vsftpd.conf /etc/vsftpd.conf.old
fi
rm /etc/vsftpd.conf
ln -s $LBHOME/system/vsftpd/vsftpd.conf /etc/vsftpd.conf

# SSMTP Config
if [ ! -L /etc/ssmtp ]; then
	mv /etc/ssmtp /etc/ssmtp.old
fi
rm /etc/ssmtp
ln -s $LBHOME/system/ssmtp /etc/ssmtp

# PHP
if [ ! -L /etc/php ]; then
	mv /etc/php /etc/php.old
fi
rm /etc/php
ln -s $LBHOME/system/php /etc/php
# Set PHP include_path directive
awk -v s="include_path=\".:$LBHOME/libs/phplib\"" '/^include_path=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/php/7.0/apache2/conf.d/20-loxberry.ini
awk -v s="include_path=\".:$LBHOME/libs/phplib\"" '/^include_path=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/php/7.0/cli/conf.d/20-loxberry.ini
# echo include_path=\".:$LBHOME/libs/phplib\" > /etc/php/7.0/apache2/conf.d/20-loxberry.ini
# echo include_path=\".:$LBHOME/libs/phplib\" > /etc/php/7.0/cli/conf.d/20-loxberry.ini

# Cron.d
if [ ! -L /etc/cron.d ]; then
	mv /etc/cron.d /etc/cron.d.old
fi
rm /etc/cron.d
ln -s $LBHOME/system/cron/cron.d /etc/cron.d
