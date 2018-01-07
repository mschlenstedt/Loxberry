#!/usr/bin/perl

# Script for setting a new Secure PIN

use LoxBerry::System;

if ($<) {
  print "This script has to be run as root.\n";
  exit (1);
}

my $pinold = $ARGV[0];
my $pinnew = $ARGV[1];

if (!$pinold || !$pinnew) {
  print "Usage: $0 <OLDPIN> <NEWPIN>\n";
  exit (1);
}

if (!-e "$lbsconfigdir/securepin.dat") {
  open (F, ">$lbsconfigdir/securepin.dat");
    print F "6MWpk/BkBr06.";
  close (F);
  my $chmodbin = $bins->{CHMOD};
  my $chownbin = $bins->{CHOWN};
  system("$chownbin root.root $lbsconfigdir/securepin.dat 2>&1");
  system("$chmodbin 600 $lbsconfigdir/securepin.dat 2>&1");
}

open (F, "<$lbsconfigdir/securepin.dat");
  my $pinsaved = <F>;
close (F);

if (crypt($pinold,$pinsaved) ne $pinsaved) {
  print "Old PIN is wrong.\n";
  exit (1);
}

my $random = generate();
my $pincrypt = crypt($pinnew, "$random");

open (F, ">$lbsconfigdir/securepin.dat");
  print F "$pincrypt";
close (F);
system("$chmodbin 600 $lbsconfigdir/securepin.dat 2>&1");

print "New PIN saved successfully.\n";

exit (0);

# Random Sub
sub generate {
        local($e) = @_;
        my($zufall,@words,$more);

        if($e =~ /^\d+$/){
                $more = $e;
        }else{
                $more = "10";
        }

        @words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

        foreach (1..$more){
                $zufall .= $words[int rand($#words+1)];
        }

        return($zufall);
}
