#!/bin/sh
# ifup hook script for resolvconf
# Written by Roy Marples <roy@marples.name> under the BSD-2 license

PATH=/sbin:/bin:/usr/sbin:/usr/bin

HN=$(hostname)
IF=$(route -n | awk '/UG/ {print $8}')
IP=$(ip -4 -o addr show dev $IF |awk '{split($4,a,"/") ;print a[1]}')

sed -i /$HN/d /etc/hosts
echo "$IP\t$HN" >> /etc/hosts
DM=$(pgrep dnsmasq)
if [ -n "$DM" ]
then
systemctl restart dnsmasq 2>&1 > /dev/null
fi
