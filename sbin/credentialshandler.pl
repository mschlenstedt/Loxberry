#!/usr/bin/perl

# Handle Loxberry's credentials
# Script for setting a new Secure PIN and System/WebUI 
# users and passwords

use LoxBerry::System;

if ($<) {
	print "This script has to be run as root.\n";
	exit (1);
}

# Single and double quotes are not allowed
foreach (@ARGV) {
	if ( $_ =~ m/[\"\'\\]/ ) {
		print "Single, double quotes and backslahes are not allowed.\n";
		exit (1);
	}
}

# Check command
my $command = $ARGV[0];
my $response = 1;

if ($command eq 'checksecurepin') {

	$response = &check_securepin($ARGV[1]);

} elsif ($command eq 'changesecurepin') {

	$response = &change_securepin($ARGV[1], $ARGV[2]);

} elsif ($command eq 'changepasswd') {

	$response = &change_current_passwd ($ARGV[1], $ARGV[2], $ARGV[3]);

} elsif ($command eq 'checkpasswd') {

	$response = &check_current_passwd($ARGV[1], $ARGV[2]);

} elsif ($command eq 'changewebuipasswd') {

	$response = &change_webui_passwd ($ARGV[1], $ARGV[2]);

} else {

	print "Usage: $0 command parameters\n";
	print "Commands:\n";
	print "  checksecurepin <pin> -> Returns 0 if ok, else if error\n";
	print "  changesecurepin <oldpin> <newpin> -> Returns 0 if ok, else if error\n";
	print "  checkpasswd <user> <pass> -> Returns 0 if ok, 1 to 3 on error\n";
	print "  changepasswd <user> <oldpassword> <newpassword> -> Returns 0 if ok, else if error\n";
	print "  changewebuipasswd <user> <password> -> Returns 0 if ok, else if error\n";
	$response = 1;

}

exit ($response);

#####################################################
# Check Secure PIN
# Parameter: pin
# Returns: 
#	0 pin ok
#	1 pin nok
######################################################

sub check_securepin
{
	my ($pin) = @_;

	my $pinsaved = LoxBerry::System::read_file("$lbsconfigdir/securepin.dat");
	if (!$pinsaved) {
		print "Cannot read saved pin\n";
		return (1);
	}

	if (crypt($pin,$pinsaved) ne $pinsaved) {
		print "PIN is wrong.\n";
		return (1);
	} else {
		return (0);
	}
}	

#####################################################
# Change SecurePIN
# Parameter: old pin, new pin
# Returns: 
#	0 pin set successfully
#	1 Old PIN is wrong or another error
#####################################################

sub change_securepin
{
	my ($pinold, $pinnew) = @_;

	if (!$pinold || !$pinnew) {
	  print "changesecurepin usage: $0 changesecurepin <OLDPIN> <NEWPIN>\n";
	  return (1);
	}

	# Check not allowed chars
	if ( $pinnew !~ m/^((([A-Za-z0-9]){4,10})|(){0})$/ ) {
		print "Not allowed chars (A-Z, a-z, 0-9. At least 4 chars, maximum 10. Cannot set secure pin.\n";
		exit(1);
	}

	if (!-e "$lbsconfigdir/securepin.dat") {
		my $output = LoxBerry::System::write_file("$lbsconfigdir/securepin.dat", "6MWpk/BkBr06.");
		if ($output) {
		      print "Cannot save default pin\n";
		      return (1);
		}
		my $chmodbin = $bins->{CHMOD};
		my $chownbin = $bins->{CHOWN};
		system("$chownbin root:root $lbsconfigdir/securepin.dat 2>&1");
		system("$chmodbin 600 $lbsconfigdir/securepin.dat 2>&1");
	}

	my $pinsaved = LoxBerry::System::read_file("$lbsconfigdir/securepin.dat");
	if (!$pinsaved) {
		print "Cannot read old pin\n";
		return (1);
	}

	if (crypt($pinold,$pinsaved) ne $pinsaved) {
		print "Old PIN is wrong.\n";
		return (1);
	}

	my $random = generate();
	my $pincrypt = crypt("$pinnew", "$random");

	my $output = LoxBerry::System::write_file("$lbsconfigdir/securepin.dat", $pincrypt);
	if ($output) {
	      print "Cannot save new pin\n";
	      return (1);
	}
	system("$chmodbin 600 $lbsconfigdir/securepin.dat 2>&1");

	return (0);
}

#####################################################
# Check User / PW
# Parameter: user, password
# Returns: 
#	0 user and pw ok
#	1 password incorrect or user unknown
######################################################

sub check_current_passwd 
{
	my ($user, $pass) = @_;

	if ($user eq "root" || $user eq "0") {
		print "Root password cannot be set or checked by this tool\n";
		exit (1);
	}

	my ($name, $passwd, $uid, $gid, $quota, $comment, $gcos, $dir, $shell) = getpwnam ($user);
	if (!$passwd) {
		print "User not found\n";
		return (1);
	}
	# Perl's crypt function has a problem with special chars, e. g. password '' does not work
	#if ( crypt($pass, $passwd) ne $passwd ) {
	# Fallback to python's crypt implementation...
	my $output = qx(python3 -c 'import crypt; print(crypt.crypt("$pass", "$passwd"));');
	chomp($output);
	if ( $output ne $passwd ) {
		print "Wrong password\n";
		return (1);
	} else {
		return (0);
	}
}	

#####################################################
# Change User Password
# Parameter: user, old password, new password
# Returns: 
#	0 new password ok
#	1 setting new password failed
######################################################

sub change_current_passwd 
{
	my ($user, $oldpass, $newpass) = @_;
	
	# Check old Password
	my $output = &check_current_passwd ("$user", "$oldpass");
	return (1) if ($output > 0);
	
	# Set new system password
	$output = qx(echo '$user:$newpass' | /usr/sbin/chpasswd -c SHA512);
	if ($@) {
		chomp($output);
		print "Cannot set new system password: $output\n";
		return (1);
	}

	# Set new samba password 
	$output = qx( (echo '$newpass'; echo '$newpass') | smbpasswd -a -s $user );
	if ($@) {
		# Something went wrong, try to reset old system password
		print "Cannot set new system password (smb password failed): $output\n";
		$output = qx(echo '$user:$oldpass' | /usr/sbin/chpasswd -c SHA512);
		return (1);
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

	my $output = qx (/usr/bin/htpasswd -c -b $lbhomedir/config/system/htusers.dat '$user' '$newpass' > /dev/null 2>&1);
	if ($@) {
		print "Setting Webpassword failed: $output\n";
		return (1);
	}

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
