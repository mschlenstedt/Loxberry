#!/usr/bin/perl

# Copyright 2017 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is intended to reset previously created skel folders for
# /var/log and /opt/loxberry/system/log/system
# that where moved to tempfs and # are lost after system reboot.
#
# The script is called after a plugin installation and after a system upgrade.

use warnings;
use strict;
use LoxBerry::System;

if ($<) {
  print "This script has to be run as root.\n";
  exit (1);
}

# Restore Log folders on tmpfs
system ("cp -ra /var/log/* $lbhomedir/log/skel_syslog");
system ("cp -ra $lbhomedir/log/system_tmpfs/* $lbhomedir/log/skel_system/");
system ("find -type f $lbhomedir/log/skel_system/ -exec rm {} \\;");
system ("find -type f $lbhomedir/log/skel_syslog/ -exec rm {} \\;");

# Create lighttpd cache folder
system ("mkdir -p /tmp/lighttpdcompress/");
system ("chown loxberry:loxberry /tmp/lighttpdcompress/");

exit (0);
