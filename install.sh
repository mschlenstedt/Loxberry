#!/bin/bash

########################################################################
# Adjust this to the latest release image

TARGET_VERSION_ID="11"
TARGET_PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
LBHOME="/opt/loxberry"
NODEJS_VERSION="18"

#
########################################################################

# Run as root
if (( $EUID != 0 )); then
    echo "This script has to be run as root."
    exit 1
fi

if [ -e /boot/rootfsresized ]; then
	echo "This script was already executed on this LoxBerry. You cannot reinstall LoxBerry."
	echo "If you are sure what you are doing, rm /boot/rootfsresized and restart again."
	exit 1
fi

echo -e "\n\nNote! If you were logged in as user 'loxberry' and used 'su' to switch to the root account, your connection may be lost now...\n\n"
killall -u loxberry
sleep 3

# Commandline options
while getopts "t:b:" o; do
    case "${o}" in
        t)
            TAG=${OPTARG}
            ;;
        b)
            BRANCH=${OPTARG}
            ;;
        *)
            ;;
    esac
done
shift $((OPTIND-1))

# install needed packages
apt-get -y install jq git

# Stop loxberry Service
if /bin/systemctl --no-pager status apache2.service; then
	/bin/systemctl stop apache2.service
fi
if /bin/systemctl --no-pager status loxberry.service; then
	/bin/systemctl disable loxberry.service
	/bin/systemctl stop loxberry.service
fi
if /bin/systemctl --no-pager status ssdpd.service; then
        /bin/systemctl disable ssdpd.service
        /bin/systemctl stop ssdpd.service
fi
if /bin/systemctl --no-pager status mosquitto.service; then
        /bin/systemctl disable mosquitto.service
        /bin/systemctl stop mosquitto.service
fi
if /bin/systemctl --no-pager status createtmpfs.service; then
	/bin/systemctl disable createtmpfs.service
	/bin/systemctl stop createtmpfs.service
	echo -e "\nThere are some old mounts of tmpfs filesystems. Please reboot and start installation again.\n"
	exit 1
fi

# Clear screen
tput clear

# Formating - to be used in echo's
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`
BOLD=`tput bold`
ULINE=`tput smul`
RESET=`tput sgr0`

########################################################################
# Functions

# Horizontal Rule
HR () {
	echo -en "${!1}"
	printf '%.s─' $(seq 1 $(tput cols))
	echo -e "${RESET}"
}

# Section
TITLE () {
	echo -e ""
	HR "WHITE"
	echo -e "${BOLD}$1${RESET}"
	HR "WHITE"
	echo -e ""
}

# Messages
OK () {
	echo -e "\n${GREEN}[  OK  ]${RESET} .... $1"
}
FAIL () {
	echo -e "\n${RED}[FAILED]${RESET} .... $1"
}

#
########################################################################


# Main Script
HR "GREEN"
echo -e "${BOLD}LoxBerry - BEYOND THE LIMITS${RESET}"
HR "GREEN"

# Read Distro infos
if [ -e /etc/os-release ]; then
	. /etc/os-release
	#PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
	#NAME="Debian GNU/Linux"
	#VERSION_ID="11"
	#VERSION="11 (bullseye)"
	#VERSION_CODENAME=bullseye
	#ID=debian
	#HOME_URL="https://www.debian.org/"
	#SUPPORT_URL="https://www.debian.org/support"
	#BUG_REPORT_URL="https://bugs.debian.org/"
fi
if [ -e /boot/dietpi/.hw_model ]; then
	. /boot/dietpi/.hw_model
	#G_HW_MODEL=20
	#G_HW_MODEL_NAME='Virtual Machine (x86_64)'
	#G_HW_ARCH=10
	#G_HW_ARCH_NAME='x86_64'
	#G_HW_CPUID=0
	#G_HW_CPU_CORES=2
	#G_DISTRO=6
	#G_DISTRO_NAME='bullseye'
	#G_ROOTFS_DEV='/dev/sda1'
	#G_HW_UUID='0f26dd2a-8ed6-40ee-86e9-c3b204dba1e0'
fi
if [ -e /boot/dietpi/.version ]; then
	. /boot/dietpi/.version
	#G_DIETPI_VERSION_CORE=8
	#G_DIETPI_VERSION_SUB=13
	#G_DIETPI_VERSION_RC=2
	#G_GITBRANCH='master'
	#G_GITOWNER='MichaIng'
	#G_LIVE_PATCH_STATUS[0]='applied'
	#G_LIVE_PATCH_STATUS[1]='not applicable'
fi

# Check correct distribution
if [ ! -e /boot/dietpi/.version ]; then
	echo -e "\n${RED}This seems not to be a DietPi Image. LoxBerry can only be installed on DietPi.\n"
	echo -e "We expect $TARGET_PRETTY_NAME as distribution."
        echo -e "Please download the correct image from ${ULINE}https://dietpi.com\n${RESET}"
	exit 1
fi

if [ $VERSION_ID -ne $TARGET_VERSION_ID ]; then
	echo -e "\n${RED}You are running $PRETTY_NAME. This distribution"
        echo -e "is not supported by LoxBerry.\n"
	echo -e "We expect $TARGET_PRETTY_NAME as distribution."
        echo -e "Please download the correct image from ${ULINE}https://dietpi.com\n${RESET}"
	exit 1
fi

# Get latest release
if [ -z $TAG ]; then
	TARGETRELEASE="latest"
else
	TARGETRELEASE="tags/$TAG"
fi

if [ ! -z $BRANCH ]; then
	LBVERSION="Branch $BRANCH (latest)"
else
	RELEASEJSON=`curl -s \
		-H "Accept: application/vnd.github+json" \
		https://api.github.com/repos/mschlenstedt/Loxberry/releases/$TARGETRELEASE`

	LBVERSION=$(echo $RELEASEJSON | jq -r ".tag_name")
	LBNAME=$(echo $RELEASEJSON | jq -r ".name")
	LBTARBALL=$(echo $RELEASEJSON | jq -r ".tarball_url")

	if [ -z $LBVERSION ] || [ $LBVERSION = "null" ]; then
		FAIL "Cannot download latest release information from GitHub.\n"
		exit 1
	fi
fi

# Welcome screen with overview
echo -e "\nThis script will install ${BOLD}${ULINE}LoxBerry $LBVERSION${RESET} on your system.\n"
echo -e "${RED}${BOLD}WARNING!${RESET}${RED} You cannot undo the installation! Your system will be converted"
echo -e "into a LoxBerry with no return! Nothing will be like it was before ;-)${RESET}"
echo -e "\n${ULINE}Your system seems to be:${RESET}\n"
echo -e "Distribution:       $PRETTY_NAME"
echo -e "DietPi Version:     $G_DIETPI_VERSION_CORE.$G_DIETPI_VERSION_SUB"
echo -e "Hardware Model:     $G_HW_MODEL_NAME"
echo -e "Architecture:       $G_HW_ARCH_NAME"
echo -e "\n\nHit ${BOLD}<CTRL>+C${RESET} now to stop, any other input will continue.\n"
read -n 1 -s -r -p "Press any key to continue"
tput clear

# Download Release
TITLE "Downloading LoxBerry sources from GitHub..."

rm -rf $LBHOME
mkdir -p $LBHOME
cd $LBHOME

if [ ! -z $BRANCH ]; then
	git clone https://github.com/mschlenstedt/Loxberry.git -b $BRANCH
	if [ ! -d $LBHOME/Loxberry ]; then
		FAIL "Could not download LoxBerry sources.\n"
		exit 1
	else
		OK "Successfully downloaded LoxBerry sources."
		mv $LBHOME/Loxberry/* $LBHOME
		rm -r $LBHOME/Loxberry
	fi
else
	curl -L -o $LBHOME/src.tar.gz $LBTARBALL
	if [ ! -e $LBHOME/src.tar.gz ]; then
		FAIL "Could not download LoxBerry sources.\n"
		exit 1
	else
		OK "Successfully downloaded LoxBerry sources."
	fi
	# Extracting sources
	TITLE "Extracting LoxBerry sources..."

	tar xvfz src.tar.gz --strip-components=1 > /dev/null
	if [ $? != 0 ]; then
		FAIL "Could not extract LoxBerry sources.\n"
		exit 1
	else
		OK "Successfully downloaded LoxBerry sources."
		rm $LBHOME/src.tar.gz
	fi
fi

# Adding User loxberry
TITLE "Adding user 'loxberry', setting default passwd, removing user 'dietpi'..."

killall -u loxberry
sleep 3

deluser --quiet loxberry > /dev/null 2>&1
adduser --no-create-home --home $LBHOME --disabled-password --gecos "" loxberry
if [ $? != 0 ]; then
	FAIL "Could not create user 'loxberry'.\n"
	exit 1
else
	OK "Successfully created user 'loxberry'."
fi

echo 'loxberry:loxberry' | /usr/sbin/chpasswd -c SHA512
if [ $? != 0 ]; then
	FAIL "Could not set password for user 'loxberry'.\n"
	exit 1
else
	OK "Successfully set default password for user 'loxberry'."
fi

echo 'root:loxberry' | /usr/sbin/chpasswd -c SHA512
if [ $? != 0 ]; then
	FAIL "Could not set password for user 'root'.\n"
	exit 1
else
	OK "Successfully set default password for user 'root'."
fi
deluser --quiet dietpi > /dev/null 2>&1

# Configuring hardware architecture
TITLE "Configuring your hardware architecture $G_HW_ARCH_NAM..."

HWMODELFILENAME=$(cat /boot/dietpi/func/dietpi-obtain_hw_model | grep "G_HW_MODEL $G_HW_MODEL " | awk '/.*G_HW_MODEL .*/ {for(i=4; i<=NF; ++i) printf "%s_", $i; print ""}' | sed 's/\//_/g' | sed 's/[()]//g' | sed 's/_$//' | tr '[:upper:]' '[:lower:]')
echo $HWMODELFILENAME > $LBHOME/config/system/is_hwmodel_$HWMODELFILENAME.cfg
echo $G_HW_ARCH_NAME > $LBHOME/config/system/is_arch_$G_HW_ARCH_NAME.cfg

# Compatibility - this was standard until LB3.0.0.0
if echo $HWMODELFILENAME | grep -q "x86_64"; then
	echo "x64" > $LBHOME/config/system/is_x64.cfg
fi
if echo $HWMODELFILENAME | grep -q "raspberry"; then
	echo "raspberry" > $LBHOME/config/system/is_raspberry.cfg
fi

if [ ! -e $LBHOME/config/system/is_arch_$G_HW_ARCH_NAME.cfg ]; then
	FAIL "Could not set your architecture.\n"
	exit 1
else
	OK "Successfully set architecture of your system."
fi

# Installing OpenSSH Server
TITLE "Installing OpenSSH server..."
/boot/dietpi/dietpi-software install 105

# Configuring hardware architecture
TITLE "Installing additional software packages from apt repository..."

echo 'Acquire::GzipIndexes "false";' > /etc/apt/apt.conf.d/98dietpi-uncompressed
/boot/dietpi/func/dietpi-set_software apt-cache clean
apt update

if [ -e $LBHOME/packages.txt ]; then
	PACKAGES=""
	while read entry
	do
		if echo $entry | grep -Eq "^ii "; then
			VAR=$(echo $entry | sed "s/  / /g" | cut -d " " -f 2 | sed "s/:.*\$//")
			PINFO=$(apt-cache show $VAR 2>&1)
			if echo $PINFO | grep -Eq "N: Unable to locate"; then
				continue
			fi
			PACKAGE=$(echo $PINFO | grep "Package: " | cut -d " " -f 2)
			if dpkg -s $PACKAGE > /dev/null 2>&1; then
				continue
			fi
			apt-get -y install $PACKAGE
			if [ $? != 0 ]; then
				FAIL "Could not install $PACKAGE.\n"
			else
				OK "Successfully installed $PACKAGE.\n"
			fi
		fi
	done < $LBHOME/packages.txt
else
	FAIL "Could not find packages list: $LBHOME/packages.txt.\n"
	exit 1
fi

rm /etc/apt/apt.conf.d/98dietpi-uncompressed
/boot/dietpi/func/dietpi-set_software apt-cache clean
apt update

# Adding user loxberry to different additional groups
TITLE "Adding user LoxBerry to some additional groups..."

# Group membership
/usr/sbin/usermod -a -G dialout loxberry
/usr/sbin/usermod -a -G audio loxberry
/usr/sbin/usermod -a -G gpio loxberry
/usr/sbin/usermod -a -G tty loxberry
/usr/sbin/usermod -a -G www-data loxberry
/usr/sbin/usermod -a -G video loxberry
/usr/sbin/usermod -a -G i2c loxberry

OK "Successfully configured additional groups."

# Setting up systemwide environments
TITLE "Settings up systemwide environments..."

# LoxBerry Home Directory in Environment
awk -v s="LBHOMEDIR=$LBHOME" '/^LBHOMEDIR=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPHTMLAUTH=$LBHOME/webfrontend/htmlauth/plugins" '/^LBPHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPHTML=$LBHOME/webfrontend/html/plugins" '/^LBPHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPTEMPL=$LBHOME/templates/plugins" '/^LBPTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPDATA=$LBHOME/data/plugins" '/^LBPDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPLOG=$LBHOME/log/plugins" '/^LBPLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPCONFIG=$LBHOME/config/plugins" '/^LBPCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBPBIN=$LBHOME/bin/plugins" '/^LBPBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSHTMLAUTH=$LBHOME/webfrontend/htmlauth/system" '/^LBSHTMLAUTH=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSHTML=$LBHOME/webfrontend/html/system" '/^LBSHTML=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSTEMPL=$LBHOME/templates/system" '/^LBSTEMPL=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSDATA=$LBHOME/data/system" '/^LBSDATA=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSLOG=$LBHOME/log/system" '/^LBSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSTMPFSLOG=$LBHOME/log/system_tmpfs" '/^LBSTMPFSLOG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSCONFIG=$LBHOME/config/system" '/^LBSCONFIG=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSBIN=$LBHOME/bin" '/^LBSBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="LBSSBIN=$LBHOME/sbin" '/^LBSSBIN=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment
awk -v s="PERL5LIB=$LBHOME/libs/perllib" '/^PERL5LIB=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/environment

# Set environments for Apache
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/apache2/envvars 

# Environment Variablen laden
source /etc/environment

# LoxBerry global environment variables in Apache

if [ ! -Z $LBSSBIN ]; then
	FAIL "Could not set systemwide environments.\n"
	exit 1
else
	OK "Successfully set systemwide environments."
fi

# Configuring sudoers
TITLE "Setting up sudoers..."

# sudoers.d
if [ -d /etc/sudoers.d ]; then
	mv /etc/sudoers.d /etc/sudoers.d.orig
fi
if [ -L /etc/sudoers.d ]; then
	rm /etc/sudoers.d
fi
ln -s $LBHOME/system/sudoers/ /etc/sudoers.d

# sudoers: Replace /opt/loxberry with current home path
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/sudoers/lbdefaults

if [ ! -L /etc/sudoers.d ]; then
	FAIL "Could not set up sudoers.\n"
	exit 1
else
	OK "Successfully set up sudoers."
fi

# Configuring profile
TITLE "Setting up profile for user 'loxberry'sudoers..."

# profile.d/loxberry.sh
if [ -L /etc/profile.d/loxberry.sh ]; then
	rm /etc/profile.d/loxberry.sh
fi
ln -s $LBHOME/system/profile/loxberry.sh /etc/profile.d/loxberry.sh

if [ ! -L /etc/profile.d/loxberry.sh ]; then
	FAIL "Could not set up profile for user 'loxberry'.\n"
	exit 1
else
	OK "Successfully set up profile for user 'loxberry'."
fi

# Setting up Initskript for LoxBerry
TITLE "Setting up Service files for LoxBerry..."

# LoxBerry Init Script
if [ -e /etc/systemd/system/loxberry.service ]; then
	rm /etc/systemd/system/loxberry.service
fi
ln -s $LBHOME/system/systemd/loxberry.service /etc/systemd/system/loxberry.service
/bin/systemctl daemon-reload
/bin/systemctl enable loxberry.service

if ! /bin/systemctl is-enabled loxberry.service; then
	FAIL "Could not set up Service for LoxBerry.\n"
	exit 1
else
	OK "Successfully set up service for LoxBerry."
fi

# Createtmpfs Init Script
if [ -e /etc/systemd/system/createtmpfs.service ]; then
	rm /etc/systemd/system/createtmpfs.service
fi
ln -s $LBHOME/system/systemd/createtmpfs.service /etc/systemd/system/createtmpfs.service
/bin/systemctl daemon-reload
/bin/systemctl enable createtmpfs.service

if ! /bin/systemctl is-enabled createtmpfs.service; then
	FAIL "Could not set up Service for Createtmpfs.\n"
	exit 1
else
	OK "Successfully set up service for Createtmpfs."
fi

# LoxBerry SSDPD Service
if [ -e /etc/systemd/system/ssdpd.service ]; then
	rm /etc/systemd/system/ssdpd.service
fi
ln -s $LBHOME/system/systemd/ssdpd.service /etc/systemd/system/ssdpd.service
/bin/systemctl daemon-reload
/bin/systemctl enable ssdpd.service

if ! /bin/systemctl is-enabled ssdpd.service; then
	FAIL "Could not set up Service for SSDPD.\n"
	exit 1
else
	OK "Successfully set up service for SSDPD."
fi

# LoxBerry Mosquitto Service
if [ -e /etc/systemd/system/mosquitto.service ]; then
	rm /etc/systemd/system/mosquitto.service
fi
ln -s $LBHOME/system/systemd/mosquitto.service /etc/systemd/system/mosquitto.service
/bin/systemctl daemon-reload
/bin/systemctl enable mosquitto.service

if ! /bin/systemctl is-enabled mosquitto.service; then
	FAIL "Could not set up Service for Mosquitto.\n"
	exit 1
else
	OK "Successfully set up service for Mosquitto."
fi

# PHP
PHPVER=$(apt-cache show php | grep "Depends: " | sed "s/Depends: php//")
TITLE "Configuring PHP $PHPVER..."

if [ -e /etc/php/$PHPVER ] && [ ! -e /etc/php/$PHPVER/apache2/conf.d/20-loxberry.ini ]; then
	mkdir -p /etc/php/$PHPVER/apache2/conf.d
	mkdir -p /etc/php/$PHPVER/cgi/conf.d
	mkdir -p /etc/php/$PHPVER/cli/conf.d
	rm /etc/php/$PHPVER/apache2/conf.d/20-loxberry.ini
	rm /etc/php/$PHPVER/cgi/conf.d/20-loxberry.ini
	rm /etc/php/$PHPVER/cli/conf.d/20-loxberry.ini
	ln -s $LBHOME/system/php/loxberry-apache.ini /etc/php/$PHPVER/apache2/conf.d/20-loxberry-apache.ini
	ln -s $LBHOME/system/php/loxberry-apache.ini /etc/php/$PHPVER/cgi/conf.d/20-loxberry-apache.ini
	ln -s $LBHOME/system/php/20-loxberry-cli.ini /etc/php/$PHPVER/cli/conf.d/20-loxberry-cli.ini
fi

if [ ! -L  /etc/php/$PHPVER/apache2/conf.d/20-loxberry-apache.ini ]; then
	FAIL "Could not set up PHP $PHPVER.\n"
	exit 1
else
	OK "Successfully set up PHP $PHPVER."
fi

# Configuring Apache2
TITLE "Configuring Apache2..."

# Apache Config
if [ ! -L /etc/apache2 ]; then
	mv /etc/apache2 /etc/apache2.orig
fi
if [ -L /etc/apache2 ]; then  
    rm /etc/apache2
fi
ln -s $LBHOME/system/apache2 /etc/apache2
if [ ! -L /etc/apache2 ]; then
	FAIL "Could not set up Apache2 Config.\n"
	exit 1
else
	OK "Successfully set up Apache2 Config."
fi

a2dismod php*
a2dissite 001-default-ssl
rm $LBHOME/system/apache2/mods-available/php*
rm $LBHOME/system/apache2/mods-enabled/php*
cp /etc/apache2.orig/mods-available/php* /etc/apache2/mods-available
a2enmod php*

# Disable PrivateTmp for Apache2 on systemd
if [ ! -e /etc/systemd/system/apache2.service.d/privatetmp.conf ]; then
	mkdir -p /etc/systemd/system/apache2.service.d
	ln -s $LBHOME/system/systemd/apache-privatetmp.conf /etc/systemd/system/apache2.service.d/privatetmp.conf
fi

if [ ! -L  /etc/systemd/system/apache2.service.d/privatetmp.conf]; then
	FAIL "Could not set up Apache2 Private Temp Config.\n"
	exit 1
else
	OK "Successfully set up Apache2 Private Temp Config."
fi

# Configuring Network Interfaces
TITLE "Configuring Network..."

# Network config
if [ ! -L /etc/network/interfaces ]; then
	mv /etc/network/interfaces /etc/network/interfaces.old
fi
if [ -L /etc/network/interfaces ]; then  
    rm /etc/network/interfaces
fi
ln -s $LBHOME/system/network/interfaces /etc/network/interfaces

if [ ! -L /etc/network/interfaces ]; then
	FAIL "Could not configure Network Interfaces.\n"
	exit 1
else
	OK "Successfully configured Network Interfaces."
fi

# Configuring Apache2
TITLE "Configuring Samba..."

if [ ! -L /etc/samba ]; then
	mv /etc/samba /etc/samba.old
fi
if [ -L /etc/samba ]; then
    rm /etc/samba
fi
ln -s $LBHOME/system/samba /etc/samba
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/samba/smb.conf

if [ ! -L /etc/samba ]; then
	FAIL "Could not set up Samba Config.\n"
	exit 1
fi

if ! testparm -s --debuglevel=1 $LBHOME/system/samba/smb.conf; then
	FAIL "Could not set up Samba Config.\n"
	exit 1
else
	OK "Successfully set up Samba Config."
fi

if systemctl --no-pager status smbd; then
	/bin/systemctl restart smbd
fi
if systemctl --no-pager status nmbd; then
	/bin/systemctl restart nmbd
fi

if ! /bin/systemctl --no-pager status smbd; then
	FAIL "Could not reconfigure Samba.\n"
	exit 1
else
	OK "Successfully reconfigured Samba."
fi

# Add Samba default user
(echo 'loxberry'; echo 'loxberry') | smbpasswd -a -s loxberry

# Configuring VSFTP
TITLE "Configuring VSFTP..."

if [ ! -L /etc/vsftpd.conf ]; then
	mv /etc/vsftpd.conf /etc/vsftpd.conf.old
fi
if [ -L /etc/vsftpd.conf ]; then
    rm /etc/vsftpd.conf
fi
ln -s $LBHOME/system/vsftpd/vsftpd.conf /etc/vsftpd.conf

if [ ! -L /etc/vsftpd.conf ]; then
	FAIL "Could not set up VSFTPD Config.\n"
	exit 1
else
	OK "Successfully set up VSFTPD Config."
fi

if systemctl --no-pager status vsftpd; then
	/bin/systemctl restart vsftpd
fi

if ! /bin/systemctl --no-pager status vsftpd; then
	FAIL "Could not reconfigure VSFTPD.\n"
	exit 1
else
	OK "Successfully reconfigured VSFTPD."
fi

# Configuring MSMTP
TITLE "Configuring MSMTP..."

if [ -d $LBHOME/system/msmtp ]; then
	rm /etc/msmtprc
	ln -s $LBHOME/system/msmtp/msmtprc /etc/msmtprc
	chmod 0600 $LBHOME/system/msmtp/msmtprc
fi
chmod 0600 $LBHOME/system/msmtp/aliases

if [ ! -e /etc/msmtprc ]; then
	FAIL "Could not set up MSMTP Config.\n"
	exit 1
else
	OK "Successfully set up MSMTP Config."
fi

# Cron.d
TITLE "Configuring Cron.d..."

if [ ! -L /etc/cron.d ]; then
	mv /etc/cron.d /etc/cron.d.orig
fi
if [ -L /etc/cron.d ]; then
    rm /etc/cron.d
fi
ln -s $LBHOME/system/cron/cron.d /etc/cron.d

if [ ! -L /etc/cron.d ]; then
	FAIL "Could not set up Cron.d.\n"
	exit 1
else
	OK "Successfully set up Cron.d."
fi
cp /etc/cron.d.orig/* /etc/cron.d

# Skel for system logs, LB system logs and LB plugin logs
#if [ -d $LBHOME/log/skel_system/ ]; then
#    find $LBHOME/log/skel_system/ -type f -exec rm {} \;
#fi
#if [ -d $LBHOME/log/skel_syslog/ ]; then
#    find $LBHOME/log/skel_syslog/ -type f -exec rm {} \;
#fi

# USB MOunts
TITLE "Configuring automatic USB Mounts..."

# Systemd service for usb automount
mkdir -p /media/usb
if [ -e /etc/systemd/system/usb-mount@.service ]; then
	rm /etc/systemd/system/usb-mount@.service
fi
ln -s $LBHOME/system/systemd/usb-mount@.service /etc/systemd/system/usb-mount@.service

# Create udev rules for usbautomount
if [ -e /etc/udev/rules.d/99-usbmount.rules ]; then
	rm /etc/udev/rules.d/99-usbmount.rules
fi
ln -s $LBHOME/system/udev/usbmount.rules /etc/udev/rules.d/99-usbmount.rules
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/udev/usbmount.rules 

/bin/systemctl daemon-reload

if [ ! -L /etc/systemd/system/usb-mount@.service ]; then
	FAIL "Could not set up Service for USB-Mount.\n"
	exit 1
else
	OK "Successfully set up service for USB-Mount."
fi
if [ ! -L /etc/udev/rules.d/99-usbmount.rules ]; then
	FAIL "Could not set up udev Rules for USB-Mount.\n"
	exit 1
else
	OK "Successfully set up udev Rules for USB-Mount."
fi

# Configure autofs
TITLE "Configuring AutoFS for Samba Netshares..."

mkdir -p /media/smb
if [ -L /etc/creds ]; then
    rm /etc/creds
fi
ln -s $LBHOME/system/samba/credentials /etc/creds
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/autofs/loxberry_smb.autofs
ln -s $LBHOME/system/autofs/loxberry_smb.autofs /etc/auto.master.d/loxberry_smb.autofs
chmod 0755 $LBHOME/system/autofs/loxberry_smb.autofs
/bin/systemctl restart autofs

if ! /bin/systemctl --no-pager status autofs; then
	FAIL "Could not reconfigure AutoFS.\n"
	exit 1
else
	OK "Successfully reconfigured AutoFS."
fi

# Config for watchdog
TITLE "Configuring Watchdog..."

/bin/systemctl disable watchdog.service
/bin/systemctl stop watchdog.service

if [ ! -L /etc/watchdog.conf ]; then
	mv /etc/watchdog.conf /etc/watchdog.orig
fi
if [ -L /etc/watchdog.conf ]; then
    rm /etc/watchdog.conf
fi
if ! cat /etc/default/watchdog | grep -q -e "watchdog_options"; then
	echo 'watchdog_options="-v"' >> /etc/default/watchdog
fi
if ! cat /etc/default/watchdog | grep -q -e "watchdog_options.*-v"; then
	/bin/sed -i 's#watchdog_options="\(.*\)"#watchdog_options="\1 -v"#' /etc/default/watchdog
fi
sed -i -e "s#/opt/loxberry/#$LBHOME/#g" $LBHOME/system/watchdog/rsyslog.conf
ln -f -s $LBHOME/system/watchdog/watchdog.conf /etc/watchdog.conf
ln -f -s $LBHOME/system/watchdog/rsyslog.conf /etc/rsyslog.d/10-watchdog.conf
/bin/systemctl restart rsyslog.service

if [ ! -L /etc/watchdog.conf ]; then
	FAIL "Could not reconfigure Watchdog.\n"
	exit 1
else
	OK "Successfully reconfigured Watchdog."
fi

# Activating i2c
TITLE "Enabling I2C (if supported)..."

/boot/dietpi/func/dietpi-set_hardware i2c enable

# Mount all from /etc/fstab
TITLE "Enabling mount -a during boot time..."

#if ! grep -q -e "^mount -a" /etc/rc.local; then
#	sed -i 's/^exit 0/mount -a\n\nexit 0/g' /etc/rc.local
#fi

#if ! grep -q -e "^mount -a" /etc/rc.local; then
#	FAIL "Could not enabling mount -a during boottime.\n"
#	exit 1
#else
#	OK "Successfully enabled mount -a during boottime."
#fi

# Set hosts environment
TITLE "Setting hosts environment..."

rm /etc/network/if-up.d/001hosts
rm /etc/dhcp/dhclient-exit-hooks.d/sethosts
ln -f -s $LBHOME/sbin/sethosts.sh /etc/network/if-up.d/001host
ln -f -s $LBHOME/sbin/sethosts.sh /etc/dhcp/dhclient-exit-hooks.d/sethosts 

if [ ! -L /etc/network/if-up.d/001host ]; then
	FAIL "Could not set host environment.\n"
	exit 1
else
	OK "Successfully set host environment."
fi

# Configuring /etc/hosts
TITLE "Setting up /etc/hosts and /etc/hostname..."

# Remove 127.0.1.1 from /etc/hosts
#sed -i '/127\.0\.1\.1.*$/d' /etc/hosts
#echo "loxberry" > /etc/hostname
/boot/dietpi/func/change_hostname loxberry

OK "Successfully set up /etc/hosts."

# Configure swap
#service dphys-swapfile stop
#swapoff -a
#rm -r /var/swap

# Configuring node.js for Christian :-)


# Configure listchanges to have no output - for apt beeing non-interactive
TITLE "Configuring listchanges to be quit..."

if [ -e /etc/apt/listchanges.conf ]; then
	sed -i 's/frontend=pager/frontend=none/' /etc/apt/listchanges.conf
fi

OK "Successfully configured listchanges."

# Reconfigure PAM
TITLE "Reconfigure PAM to allow shorter (weaker) passwords..."

sed -i 's/obscure/minlen=1/' /etc/pam.d/common-password

if ! cat /etc/pam.d/common-password | grep -q "minlen="; then
	FAIL "Could not reconfigure PAM.\n"
	exit 1
else
	OK "Successfully reconfigured PAM."
fi

# Reconfigure Unattended Updates
TITLE "Reconfigure Unattended Updates for LoxBerry..."

if [ -e /etc/apt/apt.conf.d/02periodic ]; then
    rm /etc/apt/apt.conf.d/02periodic
fi
if [ -e /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    rm /etc/apt/apt.conf.d/50unattended-upgrades
fi
ln -f -s $LBHOME/system/unattended-upgrades/periodic.conf /etc/apt/apt.conf.d/02periodic
ln -f -s $LBHOME/system/unattended-upgrades/unattended-upgrades.conf /etc/apt/apt.conf.d/50unattended-upgrades

if [ ! -L /etc/apt/apt.conf.d/50unattended-upgrades ]; then
	FAIL "Could not reconfigure Unattended Updates.\n"
	exit 1
else
	OK "Successfully reconfigured Unattended Updates."
fi

/bin/systemctl enable unattended-upgrades

if ! /bin/systemctl is-enabled unattended-upgrades; then
	FAIL "Could not enable  Unattended Updates.\n"
	exit 1
else
	OK "Successfully enabled Unattended Updates."
fi

# Enable LoxBerry Update after next reboot
TITLE "Enable LoxBerry update after next reboot..."

touch /boot/do_lbupdate

if [ ! -e /boot/do_lbupdate ]; then
	FAIL "Could not enable LoxBerry Update.\n"
	exit 1
else
	OK "Successfully enabled LoxBerry Update."
fi

# Automatically repair filesystem errors on boot
TITLE "Automatically repair filesystem errors on boot..."

if [ ! -f /etc/default/rcS ]; then
	echo "FSCKFIX=yes" > /etc/default/rcS
else
	if ! cat /etc/default/rcS | grep -q "FSCKFIX"; then
		echo "FSCKFIX=yes" >> /etc/default/rcS
	fi
fi

if [ ! -f /etc/default/rcS ]; then
	FAIL "Could not configure FSCK / rcS.\n"
	exit 1
else
	OK "Successfully configured FSCK / rcS."
fi

# Disable SSH Root password access
TITLE "Disable root login via ssh and password..."

# Aktivating Root access via ssh with Key (password still forbidden)
#/bin/sed -i 's:^PermitRootLogin:#PermitRootLogin:g' /etc/ssh/sshd_config
#echo 'PermitRootLogin prohibit-password' >> /etc/ssh/sshd_config
#/bin/sed -i 's:^PubkeyAuthentication:#PubkeyAuthentication:g' /etc/ssh/sshd_config
#echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
#system ssh restart
/boot/dietpi/func/dietpi-set_software disable_ssh_password_logins root

# Installing NodeJS
TITLE "Installing NodeJS V$NODEJS_VERSION"
curl -fsSL https://deb.nodesource.com/setup_$NODEJS_VERSION.x | bash - && apt install -y nodejs

# Installing YARN
TITLE "Installing YARN"
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
apt update && apt install yarn

# Installing PIP2
TITLE "Installing PIP2"

curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output /tmp/get-pip.py
python2 /tmp/get-pip.py

# Installing raspi-config if we are on a raspberry
if echo $HWMODELFILENAME | grep -q "raspberry"; then
	TITLE "Installing raspi-config"
	rm /usr/bin/raspi-config
	curl -L https://raw.githubusercontent.com/RPi-Distro/raspi-config/master/raspi-config -o /usr/bin/raspi-config
	chmod +x /usr/bin/raspi-config
fi

# Create Config
TITLE "Create LoxBerry Config from Defaults..."

export PERL5LIB=$LBHOME/libs/perllib
$LBHOME/bin/createconfig.pl
$LBHOME/bin/createconfig.pl # Run twice

if [ ! -e $LBHOME/config/system/general.json ]; then
	FAIL "Could not create default config files.\n"
	exit 1
else
	OK "Successfully created default config files."
fi


# Set correct File Permissions
TITLE "Setting File Permissions..."

$LBHOME/sbin/resetpermissions.sh

if [ $? != 0 ]; then
	FAIL "Could not set File Permissions for LoxBerry.\n"
	exit 1
else
	OK "Successfully set File Permissions for LoxBerry."
fi

# Start Apache
/bin/systemctl restart apache2

TITLE "Start Apache2 Webserver..."
if ! /bin/systemctl --no-pager status apache2; then
       FAIL "Could not reconfigure Apache2.\n"
       exit 1
else
       OK "Successfully reconfigured Apache2."
fi

# The end
export PERL5LIB=$LBHOME/libs/perllib
IP=$(perl -e 'use LoxBerry::System; $ip = LoxBerry::System::get_localip(); print $ip; exit;')
echo -e "\n\n\n${GREEN}WE ARE DONE! :-)${RESET}"
echo -e "\n\n${RED}You have to reboot your LoxBerry now!"
echo -e "\nThen point your browser to http://$IP or http://loxberry"
echo -e "\nIf you would like to login via SSH, use user 'loxberry' and pass 'loxberry'."
echo -e "Root's password is 'loxberry', too (you cannot login directly via SSH)."
echo -e "\nGood Bye.\n\n${RESET}"

touch /boot/rootfsresized

exit 0
