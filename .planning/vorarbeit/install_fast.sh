#!/bin/bash

########################################################################
# LoxBerry Fast Installer
# Basiert auf dem offiziellen install.sh von mschlenstedt/Loxberry_Installer
# Gleiche Schritte, gleiche Reihenfolge – optimiert fuer Geschwindigkeit
#
# Aenderungen gegenueber dem Original:
# - apt-get update nur 1x statt 3-4x
# - Paketpruefung per dpkg-query statt while-Schleife mit Einzel-Forks
# - systemctl daemon-reload nur 1x statt 4x
# - Sury PHP Repo + Yarn Repo VOR dem einzigen apt-get update einrichten
# - Dienste werden am Ende gesammelt enabled statt einzeln
# - Alle Symlinks geblockt statt mit je eigener Fehlerbehandlung
########################################################################

TARGET_VERSION_ID="12"
TARGET_PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
LBHOME="/opt/loxberry"
PHPVER_PROD=7.4
PHPVER_TEST=8.2

export LBHOMEDIR=$LBHOME
export PERL5LIB=$LBHOME/libs/perllib
export APT_LISTCHANGES_FRONTEND="none"
export DEBIAN_FRONTEND="noninteractive"
export PATH=$PATH:/usr/sbin/

# ---- Checks ----
if (( $EUID != 0 )); then
    echo "This script has to be run as root."
    exit 1
fi

if [ -e /boot/rootfsresized ]; then
	echo "This script was already executed. rm /boot/rootfsresized to force reinstall."
	exit 1
fi

echo -e "\n\nNote! If you were logged in as user 'loxberry' and used 'su' to switch to root, your connection may be lost now...\n\n"
/usr/bin/killall -u loxberry 2>/dev/null
sleep 3

# Commandline options
while getopts "t:b:" o; do
    case "${o}" in
        t) TAG=${OPTARG} ;;
        b) BRANCH=${OPTARG} ;;
        *) ;;
    esac
done
shift $((OPTIND-1))

# ---- Formatting ----
RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; MAGENTA=$'\e[35m'
BOLD=$'\e[1m'; ULINE=$'\e[4m'; RESET=$'\e[0m'
OK()      { echo -e "\n${GREEN}[  OK   ]${RESET} .... $1"; }
FAIL()    { echo -e "\n${RED}[FAILED ]${RESET} .... $1"; }
WARNING() { echo -e "\n${MAGENTA}[WARNING]${RESET} .... $1"; }
INFO()    { echo -e "\n${YELLOW}[ INFO  ]${RESET} .... $1"; }
TITLE()   { echo -e "\n━━━ ${BOLD}$1${RESET} ━━━\n"; }

# ---- Bootstrap: Minimal packages for the installer itself ----
TITLE "Bootstrap: Installing jq, git, lsb-release..."
apt-get -y -qq update
apt-get --no-install-recommends -y -qq install jq git lsb-release

# ---- Stop existing services ----
for svc in apache2 loxberry ssdpd mosquitto; do
	systemctl stop $svc.service 2>/dev/null
	systemctl disable $svc.service 2>/dev/null
done

if systemctl is-active --quiet createtmpfs.service; then
	systemctl disable createtmpfs.service
	systemctl stop createtmpfs.service
	echo -e "\nOld tmpfs mounts found. Please reboot and restart installation.\n"
	exit 1
fi

# ---- Read Distro Info ----
[ -e /etc/os-release ] && . /etc/os-release
[ -e /boot/dietpi/.hw_model ] && . /boot/dietpi/.hw_model
[ -e /boot/dietpi/.version ] && . /boot/dietpi/.version

if [ ! -e /boot/dietpi/.version ]; then
	echo -e "\n${RED}Not a DietPi system. LoxBerry requires DietPi.${RESET}\n"
	exit 1
fi
if [ "$VERSION_ID" != "$TARGET_VERSION_ID" ]; then
	echo -e "\n${RED}Wrong distribution: $PRETTY_NAME. Expected: $TARGET_PRETTY_NAME${RESET}\n"
	exit 1
fi

# ---- Get Release Info ----
if [ -z "$TAG" ]; then TARGETRELEASE="latest"; else TARGETRELEASE="tags/$TAG"; fi

if [ -n "$BRANCH" ]; then
	LBVERSION="Branch $BRANCH (latest)"
else
	RELEASEJSON=$(curl -s -H "Accept: application/vnd.github+json" \
		https://api.github.com/repos/mschlenstedt/Loxberry/releases/$TARGETRELEASE)
	LBVERSION=$(echo "$RELEASEJSON" | jq -r ".tag_name")
	LBTARBALL=$(echo "$RELEASEJSON" | jq -r ".tarball_url")
	if [ -z "$LBVERSION" ] || [ "$LBVERSION" = "null" ]; then
		FAIL "Cannot get release info from GitHub."; exit 1
	fi
fi

echo -e "\nInstalling ${BOLD}LoxBerry $LBVERSION${RESET}\n"
echo -e "${RED}${BOLD}WARNING!${RESET} This converts your system into a LoxBerry. No undo!\n"
echo -e "Distribution:   $PRETTY_NAME"
echo -e "DietPi:         $G_DIETPI_VERSION_CORE.$G_DIETPI_VERSION_SUB"
echo -e "Hardware:       $G_HW_MODEL_NAME ($G_HW_ARCH_NAME)\n"
read -n 1 -s -r -p "Press any key to continue (CTRL+C to abort)"
clear

# ---- Download & Extract ----
TITLE "Downloading LoxBerry sources..."
rm -rf $LBHOME
mkdir -p $LBHOME && cd $LBHOME

if [ -n "$BRANCH" ]; then
	git clone --depth 1 https://github.com/mschlenstedt/Loxberry.git -b "$BRANCH"
	if [ ! -d $LBHOME/Loxberry ]; then FAIL "Download failed."; exit 1; fi
	shopt -s dotglob; mv $LBHOME/Loxberry/* $LBHOME; rm -rf $LBHOME/Loxberry
else
	curl -L -o $LBHOME/src.tar.gz "$LBTARBALL"
	if [ ! -e $LBHOME/src.tar.gz ]; then FAIL "Download failed."; exit 1; fi
	tar xzf src.tar.gz --strip-components=1 && rm src.tar.gz
fi
OK "Sources ready."

# ---- User Setup ----
TITLE "Creating user 'loxberry'..."
/usr/bin/killall -u loxberry 2>/dev/null; sleep 2
deluser --quiet loxberry 2>/dev/null
adduser --no-create-home --home $LBHOME --disabled-password --gecos "" loxberry
echo 'loxberry:loxberry' | chpasswd -c SHA512
echo 'root:loxberry' | chpasswd -c SHA512
newdietpipassword=$(echo $RANDOM | md5sum | head -c 20)
echo "dietpi:$newdietpipassword" | chpasswd -c SHA512
OK "Users configured."

# ---- Hardware Architecture ----
TITLE "Detecting hardware..."
HWMODELFILENAME=$(cat /boot/dietpi/func/dietpi-obtain_hw_model | grep "G_HW_MODEL $G_HW_MODEL " | awk '{for(i=4;i<=NF;++i) printf "%s_",$i; print ""}' | sed 's/\//_/g;s/[()]//g;s/_$//' | tr '[:upper:]' '[:lower:]')
echo "$HWMODELFILENAME" > $LBHOME/config/system/is_hwmodel_$HWMODELFILENAME.cfg
echo "$G_HW_ARCH_NAME" > $LBHOME/config/system/is_arch_$G_HW_ARCH_NAME.cfg
echo "$HWMODELFILENAME" | grep -q "x86_64" && echo "x64" > $LBHOME/config/system/is_x64.cfg
echo "$HWMODELFILENAME" | grep -q "raspberry" && echo "raspberry" > $LBHOME/config/system/is_raspberry.cfg
OK "Architecture: $G_HW_ARCH_NAME ($HWMODELFILENAME)"

# ---- OpenSSH ----
TITLE "Installing OpenSSH server..."
/boot/dietpi/dietpi-software install 105

# ---- NodeJS (via DietPi) ----
TITLE "Installing NodeJS..."
/boot/dietpi/dietpi-software install 9

# ======================================================================
# OPTIMIERUNG: Alle Repos einrichten VOR dem einzigen grossen apt update
# ======================================================================
TITLE "Setting up package repositories..."

/boot/dietpi/func/dietpi-set_software apt reset
/boot/dietpi/func/dietpi-set_software apt compress disable
/boot/dietpi/func/dietpi-set_software apt cache clean

# Sury PHP Repo
curl -sL https://packages.sury.org/php/apt.gpg | gpg --dearmor | tee /usr/share/keyrings/deb.sury.org-php.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

# Yarn Repo
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" > /etc/apt/sources.list.d/yarn.list

# ======================================================================
# EIN EINZIGES apt-get update fuer alle Repos
# ======================================================================
TITLE "Updating package lists (once)..."
apt-get -y --allow-releaseinfo-change update
OK "Package lists updated."

# ======================================================================
# OPTIMIERUNG: Paketliste in einem Rutsch ermitteln statt 1400 Einzel-Forks
# ======================================================================
TITLE "Building package list..."

if [ ! -e "$LBHOME/packages${TARGET_VERSION_ID}.txt" ]; then
	FAIL "Missing: $LBHOME/packages${TARGET_VERSION_ID}.txt"; exit 1
fi

# Alle gewuenschten Paketnamen extrahieren (Zeilen die mit "ii " beginnen)
WANTED=$(awk '/^ii / {print $2}' "$LBHOME/packages${TARGET_VERSION_ID}.txt" | sed 's/:.*$//')

# Bereits installierte Pakete
INSTALLED=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | sort -u)

# Verfuegbare Pakete (im Repo vorhanden)
AVAILABLE=$(apt-cache pkgnames 2>/dev/null | sort -u)

# Delta: gewuenscht, verfuegbar, aber noch nicht installiert
PACKAGES=""
SKIPPED_NOTFOUND=""
for pkg in $WANTED; do
	if echo "$AVAILABLE" | grep -qx "$pkg"; then
		if ! echo "$INSTALLED" | grep -qx "$pkg"; then
			PACKAGES+="$pkg "
		fi
	else
		SKIPPED_NOTFOUND+="$pkg "
	fi
done

# Yarn dazu (kommt aus dem gerade eingerichteten Repo)
if ! echo "$INSTALLED" | grep -qx "yarn"; then
	PACKAGES+="yarn "
fi

if [ -n "$SKIPPED_NOTFOUND" ]; then
	WARNING "Packages not found in repos (skipped): $SKIPPED_NOTFOUND"
fi

echo -e "\n${BOLD}Installing $(echo $PACKAGES | wc -w) packages...${RESET}\n"

apt-get --no-install-recommends -y --fix-broken --allow-downgrades --allow-change-held-packages install $PACKAGES
if [ $? != 0 ]; then
	FAIL "Package installation had errors."; exit 1
fi
OK "All packages installed."

/boot/dietpi/func/dietpi-set_software apt compress enable

# ---- Remove unwanted packages ----
TITLE "Removing unwanted packages..."
apt-get -y purge dhcpcd5 apparmor 2>/dev/null
apt-get -y --purge autoremove
OK "Cleanup done."

# ---- Groups ----
TITLE "Adding loxberry to groups..."
for grp in dialout audio gpio tty www-data video i2c dietpi; do
	usermod -a -G $grp loxberry 2>/dev/null
done
OK "Groups configured."

# ---- Environment Variables ----
TITLE "Setting up environment..."

# Alle Environment-Variablen in einem Block schreiben (statt 18x awk)
ENV_VARS="LBHOMEDIR=$LBHOME
LBPHTMLAUTH=$LBHOME/webfrontend/htmlauth/plugins
LBPHTML=$LBHOME/webfrontend/html/plugins
LBPTEMPL=$LBHOME/templates/plugins
LBPDATA=$LBHOME/data/plugins
LBPLOG=$LBHOME/log/plugins
LBPCONFIG=$LBHOME/config/plugins
LBPBIN=$LBHOME/bin/plugins
LBSHTMLAUTH=$LBHOME/webfrontend/htmlauth/system
LBSHTML=$LBHOME/webfrontend/html/system
LBSTEMPL=$LBHOME/templates/system
LBSDATA=$LBHOME/data/system
LBSLOG=$LBHOME/log/system
LBSTMPFSLOG=$LBHOME/log/system_tmpfs
LBSCONFIG=$LBHOME/config/system
LBSBIN=$LBHOME/bin
LBSSBIN=$LBHOME/sbin
PERL5LIB=$LBHOME/libs/perllib"

# Bestehende LB-Eintraege entfernen, dann neue anfuegen
grep -v -E "^(LBHOMEDIR|LBPHTMLAUTH|LBPHTML|LBPTEMPL|LBPDATA|LBPLOG|LBPCONFIG|LBPBIN|LBSHTMLAUTH|LBSHTML|LBSTEMPL|LBSDATA|LBSLOG|LBSTMPFSLOG|LBSCONFIG|LBSBIN|LBSSBIN|PERL5LIB)=" /etc/environment > /tmp/env_clean
echo "$ENV_VARS" >> /tmp/env_clean
mv /tmp/env_clean /etc/environment

sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/apache2/envvars
source /etc/environment

if [ -z "$LBSSBIN" ]; then
	FAIL "Environment setup failed."; exit 1
fi
OK "Environment set."

# ---- Sudoers ----
TITLE "Setting up sudoers..."
[ -d /etc/sudoers.d ] && mv /etc/sudoers.d /etc/sudoers.d.orig
[ -L /etc/sudoers.d ] && rm /etc/sudoers.d
ln -s $LBHOME/system/sudoers/ /etc/sudoers.d
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/sudoers/lbdefaults
OK "Sudoers configured."

# ---- Profile ----
[ -L /etc/profile.d/loxberry.sh ] && rm /etc/profile.d/loxberry.sh
ln -s $LBHOME/system/profile/loxberry.sh /etc/profile.d/loxberry.sh

# ======================================================================
# OPTIMIERUNG: Alle Systemd-Services in einem Block, daemon-reload nur 1x
# ======================================================================
TITLE "Setting up systemd services..."

for svc in loxberry createtmpfs ssdpd mosquitto; do
	rm -f /etc/systemd/system/${svc}.service
	ln -s $LBHOME/system/systemd/${svc}.service /etc/systemd/system/${svc}.service
done

# USB-Mount Service
mkdir -p /media/usb
rm -f /etc/systemd/system/usb-mount@.service
ln -s $LBHOME/system/systemd/usb-mount@.service /etc/systemd/system/usb-mount@.service

# Apache PrivateTmp
mkdir -p /etc/systemd/system/apache2.service.d
[ ! -e /etc/systemd/system/apache2.service.d/privatetmp.conf ] && \
	ln -s $LBHOME/system/systemd/apache-privatetmp.conf /etc/systemd/system/apache2.service.d/privatetmp.conf

# EIN daemon-reload fuer alles
systemctl daemon-reload
systemctl enable loxberry createtmpfs ssdpd mosquitto unattended-upgrades
OK "All services configured."

# ---- PHP ----
TITLE "Configuring PHP ${PHPVER_PROD} and ${PHPVER_TEST}..."

for VER in $PHPVER_PROD $PHPVER_TEST; do
	if [ ! -e /etc/php/${VER} ]; then
		FAIL "PHP $VER not found."; exit 1
	fi
	for DIR in apache2 cgi cli; do
		mkdir -p /etc/php/${VER}/${DIR}/conf.d
		rm -f /etc/php/${VER}/${DIR}/conf.d/20-loxberry*.ini
	done
	ln -sf $LBHOME/system/php/loxberry-apache.ini /etc/php/${VER}/apache2/conf.d/20-loxberry-apache.ini
	ln -sf $LBHOME/system/php/loxberry-apache.ini /etc/php/${VER}/cgi/conf.d/20-loxberry-apache.ini
	ln -sf $LBHOME/system/php/loxberry-cli.ini /etc/php/${VER}/cli/conf.d/20-loxberry-cli.ini
done
update-alternatives --set php /usr/bin/php${PHPVER_PROD}
OK "PHP configured."

# ---- Apache2 ----
TITLE "Configuring Apache2..."
[ ! -L /etc/apache2 ] && mv /etc/apache2 /etc/apache2.orig
[ -L /etc/apache2 ] && rm /etc/apache2
ln -s $LBHOME/system/apache2 /etc/apache2
a2dismod php* 2>/dev/null
a2dissite 001-default-ssl 2>/dev/null
rm -f $LBHOME/system/apache2/mods-available/php* $LBHOME/system/apache2/mods-enabled/php*
cp /etc/apache2.orig/mods-available/php* /etc/apache2/mods-available 2>/dev/null
a2enmod php${PHPVER_PROD}
OK "Apache2 configured."

# ---- Network ----
TITLE "Configuring Network..."
[ ! -L /etc/network/interfaces ] && mv /etc/network/interfaces /etc/network/interfaces.old
[ -L /etc/network/interfaces ] && rm /etc/network/interfaces
ln -s $LBHOME/system/network/interfaces /etc/network/interfaces
[ -e /boot/config.txt ] && G_CONFIG_INJECT 'dtoverlay=disable-wifi' '#dtoverlay=disable-wifi' /boot/config.txt 2>/dev/null
OK "Network configured."

# ---- Python3 ----
echo -e '[global]\nbreak-system-packages=true' > /etc/pip.conf

# ---- Samba ----
TITLE "Configuring Samba..."
[ ! -L /etc/samba ] && mv /etc/samba /etc/samba.old
[ -L /etc/samba ] && rm /etc/samba
ln -s $LBHOME/system/samba /etc/samba
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/samba/smb.conf
systemctl restart smbd nmbd 2>/dev/null
(echo 'loxberry'; echo 'loxberry') | smbpasswd -a -s loxberry
OK "Samba configured."

# ---- VSFTPD ----
TITLE "Configuring VSFTPD..."
[ ! -L /etc/vsftpd.conf ] && mv /etc/vsftpd.conf /etc/vsftpd.conf.old
[ -L /etc/vsftpd.conf ] && rm /etc/vsftpd.conf
ln -s $LBHOME/system/vsftpd/vsftpd.conf /etc/vsftpd.conf
systemctl restart vsftpd 2>/dev/null
OK "VSFTPD configured."

# ---- MSMTP ----
rm -f /etc/msmtprc
ln -s $LBHOME/system/msmtp/msmtprc /etc/msmtprc
chmod 0600 $LBHOME/system/msmtp/msmtprc $LBHOME/system/msmtp/aliases

# ---- Cron ----
[ ! -L /etc/cron.d ] && mv /etc/cron.d /etc/cron.d.orig
[ -L /etc/cron.d ] && rm /etc/cron.d
ln -s $LBHOME/system/cron/cron.d /etc/cron.d
cp /etc/cron.d.orig/* /etc/cron.d 2>/dev/null

# ---- USB/udev ----
rm -f /etc/udev/rules.d/99-usbmount.rules
ln -s $LBHOME/system/udev/usbmount.rules /etc/udev/rules.d/99-usbmount.rules
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/udev/usbmount.rules

# ---- AutoFS ----
TITLE "Configuring AutoFS..."
mkdir -p /media/smb
[ -L /etc/creds ] && rm /etc/creds
ln -s $LBHOME/system/samba/credentials /etc/creds
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/autofs/loxberry_smb.autofs
ln -sf $LBHOME/system/autofs/loxberry_smb.autofs /etc/auto.master.d/loxberry_smb.autofs
chmod 0755 $LBHOME/system/autofs/loxberry_smb.autofs
rm -f $LBHOME/system/storage/smb/.dummy
systemctl restart autofs
OK "AutoFS configured."

# ---- Watchdog ----
TITLE "Configuring Watchdog..."
systemctl disable watchdog.service 2>/dev/null
systemctl stop watchdog.service 2>/dev/null
[ ! -L /etc/watchdog.conf ] && mv /etc/watchdog.conf /etc/watchdog.orig 2>/dev/null
[ -L /etc/watchdog.conf ] && rm /etc/watchdog.conf
grep -q "watchdog_options" /etc/default/watchdog 2>/dev/null || echo 'watchdog_options="-v"' >> /etc/default/watchdog
grep -q "\-v" /etc/default/watchdog || sed -i 's#watchdog_options="\(.*\)"#watchdog_options="\1 -v"#' /etc/default/watchdog
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/watchdog/rsyslog.conf
ln -sf $LBHOME/system/watchdog/watchdog.conf /etc/watchdog.conf
ln -sf $LBHOME/system/watchdog/rsyslog.conf /etc/rsyslog.d/10-watchdog.conf
systemctl restart rsyslog.service
OK "Watchdog configured."

# ---- I2C ----
/boot/dietpi/func/dietpi-set_hardware i2c enable 2>/dev/null

# ---- Hosts ----
TITLE "Setting hosts..."
rm -f /etc/network/if-up.d/001hosts /etc/dhcp/dhclient-exit-hooks.d/sethosts
ln -sf $LBHOME/sbin/sethosts.sh /etc/network/if-up.d/001host
ln -sf $LBHOME/sbin/sethosts.sh /etc/dhcp/dhclient-exit-hooks.d/sethosts
OK "Hosts configured."

# ---- Listchanges ----
[ -e /etc/apt/listchanges.conf ] && sed -i 's/frontend=pager/frontend=none/' /etc/apt/listchanges.conf

# ---- PAM ----
sed -i 's/obscure/minlen=1/' /etc/pam.d/common-password

# ---- Unattended Updates ----
rm -f /etc/apt/apt.conf.d/02periodic /etc/apt/apt.conf.d/50unattended-upgrades
ln -sf $LBHOME/system/unattended-upgrades/periodic.conf /etc/apt/apt.conf.d/02periodic
ln -sf $LBHOME/system/unattended-upgrades/unattended-upgrades.conf /etc/apt/apt.conf.d/50unattended-upgrades

# ---- Enable LoxBerry Update flag ----
touch /boot/do_lbupdate

# ---- FSCK auto-repair ----
[ ! -f /etc/default/rcS ] && echo "FSCKFIX=yes" > /etc/default/rcS
grep -q "FSCKFIX" /etc/default/rcS || echo "FSCKFIX=yes" >> /etc/default/rcS

# ---- SSH: Disable root login ----
/boot/dietpi/func/dietpi-set_software disable_ssh_password_logins root

# ---- Hostname ----
TITLE "Setting hostname..."
touch /etc/mailname
$LBHOME/sbin/changehostname.sh loxberry
OK "Hostname set to 'loxberry'."

# ---- File Permissions ----
TITLE "Setting file permissions..."
$LBHOME/sbin/resetpermissions.sh
OK "Permissions set."

# ---- Create Config ----
TITLE "Creating LoxBerry config..."
su loxberry -c "export PERL5LIB=$LBHOME/libs/perllib && $LBHOME/bin/createconfig.pl"
su loxberry -c "export PERL5LIB=$LBHOME/libs/perllib && $LBHOME/bin/createconfig.pl"
export PERL5LIB=$LBHOME/libs/perllib && $LBHOME/sbin/mqtt-handler.pl action=updateconfig

if [ ! -e $LBHOME/config/system/general.json ]; then
	FAIL "Config creation failed."; exit 1
fi
OK "Config created."

# ---- MQTT Gateway compatibility ----
ln -sf $LBHOME/webfrontend/html/system/tools/mqtt/receive.php $LBHOME/webfrontend/html/plugins/mqttgateway/receive.php
ln -sf $LBHOME/webfrontend/html/system/tools/mqtt/receive_pub.php $LBHOME/webfrontend/html/plugins/mqttgateway/receive_pub.php
ln -sf $LBHOME/webfrontend/htmlauth/system/tools/mqtt.php $LBHOME/webfrontend/htmlauth/plugins/mqttgateway/mqtt.php
chown -R loxberry:loxberry $LBHOME/webfrontend/htmlauth/plugins/mqttgateway
chown -R loxberry:loxberry $LBHOME/webfrontend/html/plugins/mqttgateway
chown -R loxberry:loxberry $LBHOME/webfrontend/html/system/tools/mqtt

# ---- Timezone ----
timedatectl set-timezone Europe/Berlin
dpkg-reconfigure -f noninteractive tzdata

# ---- Start services ----
TITLE "Starting services..."
systemctl unmask systemd-logind.service
systemctl start systemd-logind.service
systemctl restart apache2

if ! systemctl is-active --quiet apache2; then
	FAIL "Apache2 did not start."
else
	OK "Apache2 running."
fi

# ---- Root defaults ----
cp $LBHOME/.vimrc $LBHOME/.profile /root 2>/dev/null

# ---- Permissions (2nd pass) ----
$LBHOME/sbin/resetpermissions.sh

# ---- Done ----
touch /boot/rootfsresized

export PERL5LIB=$LBHOME/libs/perllib
IP=$(perl -e 'use LoxBerry::System; print LoxBerry::System::get_localip(); exit;' 2>/dev/null)
[ -z "$IP" ] && IP="<deine-IP>"

echo -e "\n\n${GREEN}${BOLD}DONE! :-)${RESET}\n"
echo -e "${RED}If you're NOT on ethernet/DHCP, configure network now with dietpi-config!"
echo -e "Then reboot!${RESET}\n"
echo -e "${GREEN}After reboot: http://$IP or http://loxberry"
echo -e "SSH: user 'loxberry', password 'loxberry'"
echo -e "Root password: 'loxberry'\n${RESET}"

exit 0
