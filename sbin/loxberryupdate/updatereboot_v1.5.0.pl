#grep -rl stretch /etc/apt/ | xargs sed -i 's/stretch/buster/g'
echo "Executing stretch to buster"
find /etc/apt -name "*.list" | xargs sed -i '/^deb/s/stretch/buster/g'
read -p "Press [Enter] to continue..."

echo "Clean up apt databases"
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y --fix-broken install
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y autoremove
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y clean
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/dpkg --configure -a
rm -r /var/cache/apt/archives/*
read -p "Press [Enter] to continue..."

echo "Remove listchanges"
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends -y --fix-broken --reinstall remove apt-listchanges
read -p "Press [Enter] to continue..."

echo "Executing update"
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y update

echo "Executing upgrade"
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --fix-broken -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" upgrade
read -p "Press [Enter] to continue..."

echo "Executing dist-upgrade"
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --fix-broken -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" dist-upgrade
read -p "Press [Enter] to continue..."

echo "Activate PHP7.3"
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends -y --fix-broken --reinstall remove php7.0-common
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends -y --fix-broken --reinstall install php7.3-bz2 php7.3-curl php7.3-json php7.3-mbstring php7.3-mysql php7.3-opcache php7.3-readline php7.3-soap php7.3-sqlite3 php7.3-xml php7.3-zip php7.3-cgi
a2enmod php7.3
read -p "Press [Enter] to continue..."

echo "Configure PHP7.3"
LBHOME="/opt/loxberry"
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
read -p "Press [Enter] to continue..."

echo "Clean up apt databases"
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y --fix-broken install
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y autoremove
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y clean
APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive /usr/bin/dpkg --configure -a
rm -r /var/cache/apt/archives/*
read -p "Press [Enter] to continue..."

echo "Configure logrotate"
mv /etc/logrotate.conf.dpkg-dist /etc/logrotate.conf
sed -i 's/^#compress/compress/g' /etc/logrotate.conf
read -p "Press [Enter] to continue..."
