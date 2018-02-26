#!/bin/bash

awk -v s="" '/^[#]?dtparam=i2c1=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /boot/config.txt
awk -v s="dtparam=i2c1=on\ndtparam=i2c_arm=on" '/^[#]?dtparam=i2c_arm=/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /boot/config.txt
awk -v s="i2c-bcm2708" '/^[#]?i2c-bcm2708/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/modules
awk -v s="i2c-dev" '/^[#]?i2c-dev/{$0=s;f=1} {a[++n]=$0} END{if(!f)a[++n]=s;for(i=1;i<=n;i++)print a[i]>ARGV[1]}' /etc/modules
apt-get -q -y update
apt-get -q -y install i2c-tools
exit 0
