#!/usr/bin/perl

# Script for setting a new Secure PIN

use LoxBerry::System;

if ($<) {
  print "This script has to be run as root.\n";
  exit (1);
}

my $command = $ARGV[0];

if ($command eq 'changesecurepin') {
	changesecurepin($ARGV[1], $ARGV[2]);
} elsif ($command eq 'checkpasswd') {
	exit(check_current_passwd($ARGV[1], $ARGV[2]));
} else {
	print "Usage: $0 command parameters\n";
	print "Commands:\n";
	print "	 checkpasswd user pass -> Returns 0 if ok, 1 to 3 on error\n";
	print "  changesecurepin oldpin newpin -> Returns 0 if ok, else if error\n";
}

exit (1);

sub changesecurepin
{
	my( $pinold, $pinnew) = @_;

	if (!$pinold || !$pinnew) {
	  print "changesecurepin usage: $0 changesecurepin <OLDPIN> <NEWPIN>\n";
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
}

#####################################################
# Check User / PW
# Parameter: user, password
# Returns: 
#	0 user and pw ok
#	1 password incorrect
#	2 user not found
#	3 on error reading shadow file
#####################################################

# Only works as root (loxberry cannot access shadow file)
# Need to be in an extra file, therefore not used

sub check_current_passwd 
{
	my ($user, $pass) = @_;
	my @shadow;
	eval {
		open (my $fh, "<", "/etc/shadow");
			  @shadow = <$fh>;
		close ($fh);
	}; 
	return(3) if $@;
	

	my $founduser;
	my $foundencpass;

	foreach my $userline (@shadow) {
		my @fields = split /:/, $userline;
		if ($fields[0] eq $user) {
			$founduser = $fields[0];
			$foundencpass = $fields[1];
			last;
		}
	}

	if (!$founduser) {
		# print STDERR "User not found\n";
		return(2);
	}

	my ($empty, $algo, $salt, $hashedpw) = split /\$/, $foundencpass;

	my $crypt_test = crypt($pass, $foundencpass);

	print STDERR "Shadow : $foundencpass\n";
	print STDERR "Entered: $crypt_test\n";

	if ($foundencpass ne $crypt_test) {
		print STDERR "Wrong password\n";
		return(1);
	}
	return(0);
}	

#####################################################
# Random Sub
#####################################################
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
