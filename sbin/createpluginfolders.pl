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

# This script is intended to re-create folders that where moved to tempfs and
# are lost after system reboot.
# The script is called in initloxberry.sh

use warnings;
use strict;
use LoxBerry::System;

my @plugins = LoxBerry::System::get_plugins();

my ($login,$pass,$uid,$gid) = getpwnam("loxberry") or die "User loxberry not in passwd file";

foreach my $plugin (@plugins) {
    if ( ! -d "$lbhomedir/log/plugins/$plugin->{PLUGINDB_FOLDER}") {
		mkdir "$lbhomedir/log/plugins/$plugin->{PLUGINDB_FOLDER}" or warn "createpluginfolders.pl: Could not create log folder $lbhomedir/log/plugins/$plugin->{PLUGINDB_FOLDER}\n";
		chown $uid, $gid, "$lbhomedir/log/plugins/$plugin->{PLUGINDB_FOLDER}";
	}
}
