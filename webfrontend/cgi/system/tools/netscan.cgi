#!/usr/bin/perl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
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


# Version of this script
$version = "0.0.2";

##########################################################################
#
# Modules
#
##########################################################################

require LWP::UserAgent;
use CGI::Carp qw(fatalsToBrowser);

##########################################################################
#
# Main
#
##########################################################################


# Scan both possible devices: eth0 and wlan0
foreach ("wlan0","eth0") {

  # Figure out own IP and own Network
  my $result = qx(/usr/sbin/ifplugstatus $_ 2>/dev/null);

  # If device is plugged in (link detected)
  if ($? >> 8 == 2) {
    $ownip = qx (/sbin/ifconfig $_ | grep "inet " | awk '{ printf \$2; }');
    $ownip =~ s/[\n\r]//g;    
    $net = $ownip;
    $net =~ s/(.*)\.(.*)\.(.*)\.(.*)$/$1\.$2\.$3/;
    $net = "$net.0/24";

    # Scan network into tmp file
    if ((-f "/tmp/netscan.dat" && !-l "/tmp/netscan.dat") || !-e "/tmp/netscan.dat") {
      my $result = qx(/usr/bin/nmap -d0 -T5 -sP -oG /tmp/netscan.dat $net 2>/dev/null);
    }

    # Scan each IP address in tmp file for a Miniserver
    if (-e "/tmp/netscan.dat") {
      open(F,"</tmp/netscan.dat") || die "Cannot open /tmp/netscan.dat";
        flock(F,2) if($flock);
        my @netscan = <F>;
        foreach (@netscan){
          s/[\n\r]//g;
          # Kommentare und Leerzeilen überspringen
          $commentchar = substr($_,0,1);
          if ($commentchar eq "#" || $_ eq "") {
            next;
          }
          @fields = split(/ /);
          if (@fields[1] =~ /(\d*)\.(\d*)\.(\d*)\.(\d*)/) {
            my $url = "http://@fields[1]/dev/cfg/version";
            my $ua = LWP::UserAgent->new;
            $ua->timeout(1);
            local $SIG{ALRM} = sub { die };
            eval {
              alarm(1);
              my $response = $ua->get($url);
              # Test server sig (will not work from V7.0 on due to
              # security reasons)...
              my $server = $response->header('Server');
              if ($server =~ /Loxone/) {
                $miniserverip = @fields[1],
                last;
              }
              # ... so we scan for blocked Auth - not as accurate but
              # better then nothing...
              my $statusline = $response->status_line;
              if ($statusline =~ /Unauthorized/) {
                $miniserverip = @fields[1],
                last;
              }
            };
            alarm(0);
          }
        }
        flock(F,8) if($flock);
      close(F);
    }

    # Delete tmp file
    if (!-l "/tmp/netscan.dat" && -T "/tmp/netscan.dat") {
      unlink ("/tmp/netscan.dat");
    }

  }

}

# Print last found ip address
print "Content-type: text/html; charset=iso-8859-15\n\n";
print "$miniserverip";

exit;
