#!/usr/bin/perl

# Handle Loxberry's credentials
# Script for setting a new Secure PIN and System/WebUI 
# users and passwords

use LoxBerry::System;

if ($<) {
  print "This script has to be run as root.\n";
  exit (1);
}

my $command = $ARGV[0];

if ($command eq 'changesecurepin') {

	&changesecurepin($ARGV[1], $ARGV[2]);

} elsif ($command eq 'changepasswd') {

	&change_current_passwd ($ARGV[1], $ARGV[2], $ARGV[3]);

} elsif ($command eq 'checkpasswd') {

	exit ( &check_current_passwd($ARGV[1], $ARGV[2]) );

} elsif ($command eq 'changewebuipasswd') {

	&change_webui_passwd ($ARGV[1], $ARGV[2]);

} else {

	print "Usage: $0 command parameters\n";
	print "Commands:\n";
	print "  checkpasswd user pass -> Returns 0 if ok, 1 to 3 on error\n";
	print "  changesecurepin oldpin newpin -> Returns 0 if ok, else if error\n";
	print "  changepasswd user oldpassword newpassword -> Returns 0 if ok, else if error\n";
	print "  changewebuipasswd user password -> Returns 0 if ok, else if error\n";

}

exit (1);

#####################################################
# Change SecurePIN
# Parameter: old pin, new pin
# Returns: 
#	0 pin set successfully
#	1 Old PIN is wrong or old/new pin empty
#####################################################

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
#	2 user unknown
######################################################

sub check_current_passwd 
{
	my ($user, $pass) = @_;

	my ($name, $passwd, $uid, $gid, $quota, $comment, $gcos, $dir, $shell) = getpwnam ($user);
	if (!$passwd) {
		print "User not found\n";
		return (2);
	}

	if ( crypt($pass, $passwd) ne $passwd ) {
		print "Wrong password\n";
		return(1);
	} else {
		return(0);
	}
}	

#####################################################
# Change User Password
# Parameter: user, old password, new password
# Returns: 
#	0 new password ok
#	1 old password incorrect
#	2 user unknown
#	3 Other error
######################################################

sub change_current_passwd 
{
	my ($user, $oldpass, $newpass) = @_;

	# Check old Password
	my $checkoldpass = &check_current_passwd ($user, $oldpass);
	return(2) if ($checkoldpass eq "2");
	return(1) if ($checkoldpass eq "1");

	# Set new system password
	if ($checkoldpass eq "0") {
		system ("echo \"$user:$newpass\" | /usr/sbin/chpasswd -c SHA512");
	} else {
		return(3);
	}
	return(3) if $@;

	# Set new samba password if not root
	if ($user ne "root") {
		system ("(echo \"$newpass\"; echo \"$newpass\") | smbpasswd -a -s $user");
	} else {
		return(0);
	}
	if ($@) {
		# Something went wrong, try to reset old password
		system ("echo \"$user:$oldpass\" | /usr/sbin/chpasswd -c SHA512");
		return (3);
	}

	# All seems to be ok.
	return (0);
}	

#####################################################
# Change User Password WebUI
# Parameter: user, new password
# Returns: 
#	0 new password ok
#	1 error
######################################################

sub change_webui_passwd 
{
	my ($user, $newpass) = @_;

	system ("/usr/bin/htpasswd -c -b $lbhomedir/config/system/htusers.dat \"$user\" \"$newpass\"");
	return(1) if $@;

	return (0);
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
