#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Update;


LoxBerry::Update::init();

apt_install( qw/ 
	mosquitto
	mosquitto-clients
	libhash-flatten-perl
	libfile-monitor-perl
	libfile-find-rule-perl
	libbsd-resource-perl
/);


