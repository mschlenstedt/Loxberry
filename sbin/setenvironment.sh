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
awk -v s="LBSTMPFSLOG=$LBHOME/log/system_tmpfs" '/^LBSTMPFSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
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

#Environment Variablen laden
source /etc/environment

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
awk -v s="export LBSTMPFSLOG=$LBSTMPFSLOG" '/^export LBSTMPFSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS
awk -v s="export LBSCONFIG=$LBSCONFIG" '/^export LBSCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS

awk -v s="export PERL5LIB=$PERL5LIB" '/^export PERL5LIB=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $ENVVARS


if /usr/sbin/service apache2 status; then
	/usr/sbin/service apache2 force-reload
fi

# LoxBerry global environment variables in Lighttpd
ENVVARS=$LBHOME/system/lighttpd/envars.conf

echo '## LoxBerry global environment variables' > $ENVVARS
echo 'setenv.add-environment = (' >> $ENVVARS
echo '' >> $ENVVARS
echo \"PERL5LIB\" \=\> \"$LBHOMEDIR/libs/perllib\", >> $ENVVARS
echo \"LBHOMEDIR\" \=\> \"$LBHOMEDIR\", >> $ENVVARS
echo \"LBPHTMLAUTH\" \=\> \"$LBPHTMLAUTH\", >> $ENVVARS
echo \"LBPHTML\" \=\> \"$LBPHTML\", >> $ENVVARS
echo \"LBPTEMPL\" \=\> \"$LBPTEMPL\", >> $ENVVARS
echo \"LBPDATA\" \=\> \"$LBPDATA\", >> $ENVVARS
echo \"LBPLOG\" \=\> \"$LBPLOG\", >> $ENVVARS
echo \"LBPCONFIG\" \=\> \"$LBPCONFIG\", >> $ENVVARS
echo '' >> $ENVVARS
echo \"LBSHTMLAUTH\" \=\> \"$LBSHTMLAUTH\", >> $ENVVARS
echo \"LBSHTML\" \=\> \"$LBSHTML\", >> $ENVVARS
echo \"LBSTEMPL\" \=\> \"$LBSTEMPL\", >> $ENVVARS
echo \"LBSDATA\" \=\> \"$LBSDATA\", >> $ENVVARS
echo \"LBSLOG\" \=\> \"$LBSLOG\", >> $ENVVARS
echo \"LBSTMPFSLOG\" \=\> \"$LBSTMPFSLOG\", >> $ENVVARS
echo \"LBSCONFIG\" \=\> \"$LBSCONFIG\", >> $ENVVARS
echo '' >> $ENVVARS
echo ')' >> $ENVVARS

# LoxBerry Home Directory in Lighttpd FASTCGI PHP Environment
awk -v s="\t\t\t\"LBHOMEDIR\" => \"$LBHOMEDIR\"," '/^\t\t\t"LBHOMEDIR" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"PERL5LIB\" => \"$LBHOMEDIR/libs/perllib\"," '/^\t\t\t"PERL5LIB" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBPHTMLAUTH\" => \"$LBPHTMLAUTH\"," '/^\t\t\t"LBPHTMLAUTH" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBPHTML\" => \"$LBPHTML\"," '/^\t\t\t"LBPHTML" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBPTEMPL\" => \"$LBPTEMPL\"," '/^\t\t\t"LBPTEMPL" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBPDATA\" => \"$LBPDATA\"," '/^\t\t\t"LBPDATA" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBPLOG\" => \"$LBPLOG\"," '/^\t\t\t"LBPLOG" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBPCONFIG\" => \"$LBPCONFIG\"," '/^\t\t\t"LBPCONFIG" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBSHTMLAUTH\" => \"$LBSHTMLAUTH\"," '/^\t\t\t"LBSHTMLAUTH" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBSHTML\" => \"$LBSHTML\"," '/^\t\t\t"LBSHTML" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBSTEMPL\" => \"$LBSTEMPL\"," '/^\t\t\t"LBSTEMPL" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBSDATA\" => \"$LBSDATA\"," '/^\t\t\t"LBSDATA" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBSLOG\" => \"$LBSLOG\"," '/^\t\t\t"LBSLOG" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBSTMPFSLOG\" => \"$LBSTMPFSLOG\"," '/^\t\t\t"LBSTMPFSLOG" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf
awk -v s="\t\t\t\"LBSCONFIG\" => \"$LBSCONFIG\"," '/^\t\t\t"LBSCONFIG" => /{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' $LBHOME/system/lighttpd/conf-available/15-fastcgi-php.conf

if /usr/sbin/service lighttpd status; then
	/usr/sbin/service lighttpd force-reload
fi

# sudoers.d/lbdefault
if [ -L /etc/sudoers.d/lbdefaults ]; then
    rm /etc/sudoers.d/lbdefaults
fi
ln -s $LBHOME/system/sudoers/lbdefaults /etc/sudoers.d/lbdefaults

# profile.d/loxberry.sh
if [ -L /etc/profile.d/loxberry.sh ]; then
    rm /etc/profile.d/loxberry.sh
fi
ln -s $LBHOME/system/profile/loxberry.sh /etc/profile.d/loxberry.sh

# /etc/creds for autofs and smb
if [ -e /etc/creds ]; then
	rm /etc/creds
fi
ln -s $LBHOME/system/samba/credentials /etc/creds

# Obsolete Apache2 logrotate config (we this by our own)
if [ -e /etc/logrotate.d/apache2 ]; then
    rm /etc/logrotate.d/apache2
fi

# Init Script
if [ -L /etc/init.d/loxberry ]; then  
   rm /etc/init.d/loxberry
fi
ln -s $LBHOME/sbin/loxberryinit.sh /etc/init.d/loxberry
update-rc.d loxberry defaults

if [ -L /etc/init.d/createtmpfsfoldersinit ]; then  
   rm /etc/init.d/createtmpfsfoldersinit
fi
ln -s $LBHOME/sbin/createtmpfsfoldersinit.sh /etc/init.d/createtmpfsfoldersinit
update-rc.d createtmpfsfoldersinit defaults

# Apache Config
if [ ! -L /etc/apache2 ]; then
	mv /etc/apache2 /etc/apache2.old
fi
if [ -L /etc/apache2 ]; then  
    rm /etc/apache2
fi
ln -s $LBHOME/system/apache2 /etc/apache2

# Lighttpd Config
if [ ! -L /etc/lighttpd ]; then
	mv /etc/lighttpd /etc/lighttpd.old
fi
if [ -L /etc/lighttpd ]; then  
	rm /etc/lighttpd
fi
ln -s $LBHOME/system/lighttpd /etc/lighttpd

# Network config
if [ ! -L /etc/network/interfaces ]; then
	mv /etc/network/interfaces /etc/network/interfaces.old
fi
if [ -L /etc/network/interfaces ]; then  
    rm /etc/network/interfaces
fi
ln -s $LBHOME/system/network/interfaces /etc/network/interfaces

# Logrotate
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

# SSMTP Config
if [ ! -L /etc/ssmtp ]; then
	mv /etc/ssmtp /etc/ssmtp.old
fi
if [ -L /etc/ssmtp ]; then
    rm /etc/ssmtp
fi
ln -s $LBHOME/system/ssmtp /etc/ssmtp

# PHP
#if [ ! -L /etc/php ]; then
#	mv /etc/php /etc/php.old
#fi
#rm /etc/php
#ln -s $LBHOME/system/php /etc/php
# Set PHP include_path directive
if [ ! -e /etc/php/7.0/apache2/conf.d/20-loxberry.ini ]; then
        touch /etc/php/7.0/apache2/conf.d/20-loxberry.ini
fi
awk -v s="include_path=\".:$LBHOME/libs/phplib\"" '/^include_path=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/php/7.0/apache2/conf.d/20-loxberry.ini
if [ ! -e /etc/php/7.0/apache2/cli/20-loxberry.ini ]; then
        touch /etc/php/7.0/cli/conf.d/20-loxberry.ini
fi
awk -v s="include_path=\".:$LBHOME/libs/phplib\"" '/^include_path=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/php/7.0/cli/conf.d/20-loxberry.ini
if [ ! -e /etc/php/7.0/apache2/cgi/20-loxberry.ini ]; then
        touch /etc/php/7.0/cgi/conf.d/20-loxberry.ini
fi
awk -v s="include_path=\".:$LBHOME/libs/phplib\"" '/^include_path=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/php/7.0/cgi/conf.d/20-loxberry.ini
# echo include_path=\".:$LBHOME/libs/phplib\" > /etc/php/7.0/apache2/conf.d/20-loxberry.ini
# echo include_path=\".:$LBHOME/libs/phplib\" > /etc/php/7.0/cli/conf.d/20-loxberry.ini

# Cron.d
if [ ! -L /etc/cron.d ]; then
	mv /etc/cron.d /etc/cron.d.old
fi
if [ -L /etc/cron.d ]; then
    rm /etc/cron.d
fi
ln -s $LBHOME/system/cron/cron.d /etc/cron.d

# Group mebership
/usr/sbin/usermod -a -G sudo,dialout,audio,gpio,tty,www-data loxberry

# Skel for system logs, LB system logs and LB plugin logs
if [ -d $LBHOME/log/skel_system/ ]; then
    find $LBHOME/log/skel_system/ -type f -exec rm {} \;
fi
if [ -d $LBHOME/log/skel_syslog/ ]; then
    find $LBHOME/log/skel_syslog/ -type f -exec rm {} \;
fi
if [ -d $LBHOME/log/skel_plugins/ ]; then
    find $LBHOME/log/skel_plugins/ -type f -exec rm {} \;
fi

# Clean apt cache
rm -rf /var/cache/apt/archives/*

# Disable PrivateTmp for Apache2 on systemd
# (also included in 1.0.2 Update script)
if [ ! -e /etc/systemd/system/apache2.service.d/privatetmp.conf ]; then
	mkdir -p /etc/systemd/system/apache2.service.d
	echo -e "[Service]\nPrivateTmp=no" > /etc/systemd/system/apache2.service.d/privatetmp.conf 
fi

# Systemd service for usb automount
# (also included in 1.0.4 Update script)
if [ ! -e /etc/systemd/system/usb-mount@.service ]; then
(cat <<END
[Unit]
Description=Mount USB Drive on %i
[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=$LBHOME/sbin/usb-mount.sh add %i
ExecStop=$LBHOME/sbin/usb-mount.sh remove %i
END
) > /etc/systemd/system/usb-mount@.service
fi

# Create udev rules for usbautomount
# (also included in 1.0.4 Update script)
if [ ! -e /etc/udev/rules.d/99-usbmount.rules ]; then
(cat <<END
KERNEL=="sd[a-z]*[0-9]", SUBSYSTEMS=="usb", ACTION=="add", RUN+="/bin/systemctl start usb-mount@%k.service"
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

# creds for AutoFS (SMB)
if [ -L /etc/creds ]; then
    rm /etc/creds
fi
ln -s $LBHOME/system/samba/credentials /etc/creds

# Activating i2c
# (also included in 1.0.3 Update script)
$LBHOME/sbin/activate_i2c.sh
