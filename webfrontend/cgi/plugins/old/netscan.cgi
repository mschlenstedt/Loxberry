#!/usr/bin/perl

# Version of this script
$version = "0.0.1";

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

# Figure out own IP and own Network
foreach ("eth0","wlan0") {
  my $result = qx(/usr/sbin/ifstatus $_ 2>/dev/null);
  if ($? >> 8 == 2) {
    $ownip = qx (/sbin/ifconfig $_ | grep inet | cut -f2 -d ":" | cut -f1 -d " ");
    $ownip =~ s/[\n\r]//g;    
  }
  last;
}
$net = $ownip;
$net =~ s/(.*)\.(.*)\.(.*)\.(.*)$/$1\.$2\.$3/;
$net = "$net.0/24";

# Scan network into tmp file
if ((-f "/tmp/netscan.dat" && !-l "/tmp/netscan.dat") || !-e "/tmp/netscan.dat") {
  my $result = qx(/usr/bin/nmap -d0 -T5 -sP -oG /tmp/netscan.dat $net 2>/dev/null);
}

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
        my $url = "http://@fields[1]";
        my $ua = LWP::UserAgent->new;
        $ua->timeout(2);
        $ua->env_proxy;
        my $response = $ua->get($url);
        my $server = $response->header('Server');
        if ($server =~ /Loxone/) {
          $miniserverip = @fields[1],
          last;
        }
      }
    }
    flock(F,8) if($flock);
  close(F);
}

if (!-l "/tmp/netscan.dat" && -T "/tmp/netscan.dat") {
  unlink ("/tmp/netscan.dat");
}
print "Content-Type: text/plain\n\n";
print "$miniserverip";
