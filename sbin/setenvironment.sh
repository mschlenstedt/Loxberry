#!/bin/bash
LBHOME="/opt/loxberry"

echo LBHOMEDIR=$LBHOME >> /etc/environment

# Main directories for plugins
echo LBPCGI=$LBHOME/webfrontend/cgi/plugins >> /etc/environment
echo LBPHTML=$LBHOME/webfrontend/html/plugins >> /etc/environment
echo LBPTEMPL=$LBHOME/templates/plugins >> /etc/environment
echo LBPDATA=$LBHOME/data/plugins >> /etc/environment
echo LBPLOG=$LBHOME/log/plugins >> /etc/environment
echo LBPCONFIG=$LBHOME/config/plugins >> /etc/environment

# Main directories for system
echo LBSCGI=$LBHOME/webfrontend/cgi/system >> /etc/environment
echo LBSHTML=$LBHOME/webfrontend/html/system >> /etc/environment
echo LBSTEMPL=$LBHOME/templates/system >> /etc/environment
echo LBSDATA=$LBHOME/data/system >> /etc/environment
echo LBSLOG=$LBHOME/log/system >> /etc/environment
echo LBSCONFIG=$LBHOME/config/system >> /etc/environment

# LoxBerry global environment variables in Apache
ENVVARS=$LBHOME/system/apache2/envvars
echo '' >> $ENVVARS
echo '## LoxBerry global environment variables' >> $ENVVARS
echo export LBHOMEDIR=$LBHOMEDIR >> $ENVVARS
echo export LBPCGI=$LBPCGI >> $ENVVARS
echo export LBPHTML=$LBPHTML >> $ENVVARS
echo export LBPTEMPL=$LBPTEMPL >> $ENVVARS
echo export LBPDATA=$LBPDATA >> $ENVVARS
echo export LBPLOG=$LBPLOG >> $ENVVARS
echo export LBPCONFIG=$LBPCONFIG >> $ENVVARS
echo '' >> $ENVVARS
echo export LBSCGI=$LBSCGI >> $ENVVARS
echo export LBSHTML=$LBSHTML >> $ENVVARS
echo export LBSTEMPL=$LBSTEMPL >> $ENVVARS
echo export LBSDATA=$LBSDATA >> $ENVVARS
echo export LBSLOG=$LBSLOG >> $ENVVARS
echo export LBSCONFIG=$LBSCONFIG >> $ENVVARS

# Set Perl library path for LoxBerry Modules

echo PERL5LIB=$LBHOME/libs/perllib  >> /etc/environment

# Set PHP include_path directive

echo include_path=\".:$LBHOME/libs/phplib\" > /etc/php5/apache2/conf.d/20-loxberry.ini
echo include_path=\".:$LBHOME/libs/phplib\" > /etc/php5/cli/conf.d/20-loxberry.ini
