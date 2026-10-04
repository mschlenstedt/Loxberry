#!/bin/bash
#
# settimeserver.sh - hand LoxBerry's time settings to DietPi (#1581)
#
# DietPi keeps the system time in sync itself (systemd-timesyncd, configured by
# CONFIG_NTP_MODE and CONFIG_NTP_MIRROR in /boot/dietpi.txt). This helper writes
# the settings from general.json (Timeserver.Ntpserver, Timeserver.Timezone)
# with DietPi's own functions - the same calls dietpi-config uses - and forces
# one sync.
#
# The server is checked with ntpdig before it is written: run_ntpd alone proves
# nothing, because timesyncd also uses the NTP servers handed out by DHCP and
# reports a sync as soon as any of them answers.
#
# Usage (as root, e.g. "sudo settimeserver.sh"):
#   settimeserver.sh [syncmode]
#     syncmode  CONFIG_NTP_MODE: 1 = at boot, 2 = boot + daily,
#               3 = boot + hourly, 4 = daemon. Without it the mode is kept.
#
# Exit codes:
#   0  settings applied and time synced
#   1  error (invalid setting, DietPi functions missing, ...)
#   2  the new server does not answer - the previous server is kept
#      (a failed sync without a previous server to restore returns 1)

set -f	# no globbing - server names come from general.json

LBHOMEDIR=${LBHOMEDIR:-/opt/loxberry}
LBSTMPFSLOG=${LBSTMPFSLOG:-$LBHOMEDIR/log/system_tmpfs}
GENERALJSON=$LBHOMEDIR/config/system/general.json
DIETPI_TXT=/boot/dietpi.txt
DIETPI_FUNC=/boot/dietpi/func

. $LBHOMEDIR/libs/bashlib/loxberry_log.sh
NAME=settimeserver
PACKAGE=core
FILENAME=$LBSTMPFSLOG/settimeserver.log
ADDTIME=1
LOGLEVEL=7
LOGSTART "Apply time settings"

fail() {
	LOGCRIT "$1"
	LOGEND "Time settings not applied"
	exit ${2:-1}
}

# Run a command, log its output without DietPi's colour codes, return its exit code
run() {
	local output rc
	LOGINF "Running: $*"
	output=$("$@" 2>&1)
	rc=$?
	[ -n "$output" ] && LOGDEB "$(echo "$output" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')"
	return $rc
}

dietpi_value() {
	sed -n "/^[[:blank:]]*$1=/{s/^[^=]*=//p;q}" $DIETPI_TXT
}

[ "$(id -u)" -eq 0 ] || fail "This script must run as root"
[ -f $DIETPI_TXT ] && [ -x $DIETPI_FUNC/dietpi-set_software ] && [ -x $DIETPI_FUNC/run_ntpd ] || fail "DietPi time sync functions not found"

MODE=$1
if [ -n "$MODE" ] && [[ ! $MODE =~ ^[1-4]$ ]]; then
	fail "Invalid sync mode '$MODE' (allowed: 1-4)"
fi

SERVER=$(jq -r '.Timeserver.Ntpserver // empty' $GENERALJSON)
TIMEZONE=$(jq -r '.Timeserver.Timezone // empty' $GENERALJSON)
SERVER=$(echo $SERVER)	# collapse whitespace
# Nothing in general.json: keep what DietPi has
[ -n "$SERVER" ] || SERVER=$(dietpi_value CONFIG_NTP_MIRROR)
[ -n "$SERVER" ] || SERVER=default

# Host names, IP addresses or the DietPi keywords "default" and "gateway",
# separated by spaces. The value ends up in a sed expression in G_CONFIG_INJECT,
# so nothing else is allowed.
for host in $SERVER; do
	[[ $host =~ ^[A-Za-z0-9]([A-Za-z0-9.:-]*[A-Za-z0-9])?$ ]] || fail "Invalid NTP server '$host'"
done

# DietPi turns every entry ending in pool.ntp.org into the servers 0-3 of that
# pool. A leading number ("0.pool.ntp.org", the old LoxBerry default) would end
# up as "0.0.pool.ntp.org", so it is removed (duplicates as well).
NORMALIZED=" "
for host in $SERVER; do
	[[ $host =~ ^[0-9]+\.(.*pool\.ntp\.org)$ ]] && host=${BASH_REMATCH[1]}
	[[ $NORMALIZED == *" $host "* ]] || NORMALIZED+="$host "
done
SERVER=$(echo $NORMALIZED)

LOGINF "NTP server: $SERVER"
LOGINF "Timezone:   ${TIMEZONE:-(not set)}"
LOGINF "Sync mode:  ${MODE:-(unchanged: $(dietpi_value CONFIG_NTP_MODE))}"

# The new server must answer before anything is changed. One answering entry
# is enough; the keywords default and gateway are resolved by DietPi itself.
OLDSERVER=$(dietpi_value CONFIG_NTP_MIRROR)
if [ "$SERVER" != "$OLDSERVER" ]; then
	if ! command -v ntpdig > /dev/null; then
		LOGWARN "ntpdig not found (package ntpsec-ntpdig) - NTP server not checked"
	else
		ANSWERED=
		for host in $SERVER; do
			if [ "$host" = "default" ] || [ "$host" = "gateway" ]; then
				ANSWERED=1
			elif ntpdig -t 2 "$host" > /dev/null 2>&1; then
				LOGOK "NTP server $host answers"
				ANSWERED=1
			else
				LOGWARN "NTP server $host does not answer"
			fi
		done
		[ -n "$ANSWERED" ] || fail "No answer from NTP server $SERVER - previous server ${OLDSERVER:-(none)} kept" 2
	fi
fi

# G_CONFIG_INJECT and the DietPi notifications
. $DIETPI_FUNC/dietpi-globals
G_PROGRAM_NAME='LoxBerry-SetTimeServer'
export G_INTERACTIVE=0

# Timezone - DietPi only offers the interactive dpkg-reconfigure tzdata, so set
# it like dietpi-config does afterwards: system timezone plus dietpi.txt
if [ -n "$TIMEZONE" ]; then
	timedatectl list-timezones | grep -qxF -- "$TIMEZONE" || fail "Unknown timezone '$TIMEZONE'"
	run timedatectl set-timezone "$TIMEZONE" || fail "Could not set timezone '$TIMEZONE'"
	run G_CONFIG_INJECT 'AUTO_SETUP_TIMEZONE=' "AUTO_SETUP_TIMEZONE=$TIMEZONE" $DIETPI_TXT
	LOGOK "Timezone set to $TIMEZONE"
fi

# NTP server and sync mode. "ntpd-mode" applies the server from dietpi.txt as well.
run G_CONFIG_INJECT 'CONFIG_NTP_MIRROR=' "CONFIG_NTP_MIRROR=$SERVER" $DIETPI_TXT || fail "Could not write CONFIG_NTP_MIRROR to $DIETPI_TXT"
if [ -n "$MODE" ]; then
	run $DIETPI_FUNC/dietpi-set_software ntpd-mode $MODE || fail "Could not set sync mode $MODE"
else
	run $DIETPI_FUNC/dietpi-set_software timesync-mirror || fail "Could not apply NTP server"
fi

# Mode 0 means another time sync system is in charge - do not start timesyncd
if [ "$(dietpi_value CONFIG_NTP_MODE)" = "0" ]; then
	LOGWARN "DietPi time sync is disabled (CONFIG_NTP_MODE=0) - server stored, no sync started"
	LOGEND "Time settings applied"
	exit 0
fi

# Force one sync, like dietpi-config does after changing the server. Wait for a
# run_ntpd that is already running (e.g. at boot) instead of interrupting it.
for i in $(seq 1 60); do
	pgrep -f "$DIETPI_FUNC/run_ntpd" > /dev/null || break
	sleep 1
done
if run env G_INTERACTIVE=0 MAX_LOOPS_CHECK=10 $DIETPI_FUNC/run_ntpd 1; then
	LOGOK "Time synced with $SERVER: $(date)"
	LOGEND "Time settings applied"
	exit 0
fi

# No sync - restore the previous server, as dietpi-config does
if [ -n "$OLDSERVER" ] && [ "$OLDSERVER" != "$SERVER" ]; then
	LOGERR "No time sync with $SERVER - restoring previous server $OLDSERVER"
	run G_CONFIG_INJECT 'CONFIG_NTP_MIRROR=' "CONFIG_NTP_MIRROR=$OLDSERVER" $DIETPI_TXT
	run $DIETPI_FUNC/dietpi-set_software timesync-mirror
	fail "Time sync failed - previous server $OLDSERVER restored" 2
fi
fail "Time sync with $SERVER failed"
