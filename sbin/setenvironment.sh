#!/bin/bash
HOME="/opt/loxberry"

echo LBHOMEDIR=$HOME >> /etc/environment

# Main directories for plugins
echo LBPCGI=$HOME/webfrontend/cgi/plugins >> /etc/environment
echo LBPHTML=$HOME/webfrontend/html/plugins >> /etc/environment
echo LBPTEMPL=$HOME/templates/plugins >> /etc/environment
echo LBPDATA=$HOME/data/plugins >> /etc/environment
echo LBPLOG=$HOME/log/plugins >> /etc/environment
echo LBPCONFIG=$HOME/config/plugins >> /etc/environment

# Main directories for system
echo LBSCGI=$HOME/webfrontend/cgi/system >> /etc/environment
echo LBSHTML=$HOME/webfrontend/html/system >> /etc/environment
echo LBSTEMPL=$HOME/templates/system >> /etc/environment
echo LBSDATA=$HOME/data/system >> /etc/environment
echo LBSLOG=$HOME/log/system >> /etc/environment
echo LBSCONFIG=$HOME/config/system >> /etc/environment

# Set Perl library path for LoxBerry Modules

echo PERL5LIB=$HOME/perllib  >> /etc/environment
