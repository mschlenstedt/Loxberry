#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use HTML::Template;
use Email::MIME;
use MIME::Base64;
use Email::Sender::Simple qw(sendmail);

# read argument

my $p = from_json(Encode::decode("UTF-8", $ARGV[0]));

# Read Mailconfig

my $sysmailobj = LoxBerry::JSON->new();
my $mcfg = $sysmailobj->open(filename => "$LoxBerry::System::lbsconfigdir/mail.json", readonly => 1);
my $email = $mcfg->{SMTP}->{EMAIL};

# Prepare email template

my $mailTmpl = HTML::Template->new(
	filename => "$LoxBerry::System::lbstemplatedir/notifyproviders/notify_email_template.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params=> 0,
);

# Prepare required variables

my %SL = LoxBerry::System::readlanguage($mailTmpl, undef, 1);

my $hostname = LoxBerry::System::lbhostname();
my $friendlyname = LoxBerry::System::lbfriendlyname();
$friendlyname = defined $friendlyname ? $friendlyname : $hostname;
$friendlyname .= " LoxBerry";

$mailTmpl->param( "hostname", $hostname );
$mailTmpl->param( "friendlyname", $friendlyname );
$mailTmpl->param( "serverport" , LoxBerry::System::lbwebserverport() );
$mailTmpl->param( "LOGFILE_REL" , $p->{LOGFILE_REL} );


my $status = $p->{SEVERITY} == 3 ? $SL{'NOTIFY.SUBJECT_ERROR'} : $SL{'NOTIFY.SUBJECT_INFO'} ;

my $package = $p->{PACKAGE};
my $name = $p->{NAME};

$package =~ s/([^\s\w]*)(\S+)/$1\u\L$2/g;
$name =~  s/([^\s\w]*)(\S+)/$1\u\L$2/g;

if ($p->{_ISSYSTEM}) {
	
	$mailTmpl->param( 'package' , $package);
	$mailTmpl->param( 'name' , $name);

	$subject = "$friendlyname $status " . $SL{'NOTIFY.SUBJECT_SYSTEM_IN'} . " $package $name";
				
	$mailTmpl->param( "severitytext", $SL{'NOTIFY.MESSAGE_SYSTEM_INFO'} ) if ($p->{SEVERITY} == 6);
	$mailTmpl->param( "severitytext", $SL{'NOTIFY.MESSAGE_SYSTEM_ERROR'} ) if ($p->{SEVERITY} == 3);
	
}
else 
{
	my $plugintitle = defined $p->{PLUGINTITLE} ? $p->{PLUGINTITLE} : $package;
	
	$subject = "$friendlyname $status " . $SL{'NOTIFY.SUBJECT_PLUGIN_IN'} . " $plugintitle " . $SL{'NOTIFY.SUBJECT_PLUGIN_PLUGIN'};
	
	$mailTmpl->param( 'package' , $plugintitle );
	$mailTmpl->param( 'name' , $name );
	
	$mailTmpl->param( "severitytext", $SL{'NOTIFY.MESSAGE_PLUGIN_INFO'} ) if ($p->{SEVERITY} == 6);
	$mailTmpl->param( "severitytext", $SL{'NOTIFY.MESSAGE_PLUGIN_ERROR'} ) if ($p->{SEVERITY} == 3);

	
}

$p->{MESSAGE} =~ s/$/<br>/mg; # Convert \n to <br>
$mailTmpl->param( "message", $p->{MESSAGE} );
$mailTmpl->param( "link", $p->{LINK});
$mailTmpl->param( "severitylevel_error", 1 ) if ($p->{SEVERITY} == 3);
$mailTmpl->param( "severitylevel_info", 1 ) if ($p->{SEVERITY} == 6);
$mailTmpl->param( "currtime", LoxBerry::System::currtime() );

my $htmlbody = $mailTmpl->output();

###################################
#### New MIME implementation
###################################

my $image_filename;

## HTML Part

my $html_part = Email::MIME->create(
	attributes => {
		content_type => "text/html",
		charset      => "UTF-8",
		encoding     => "quoted-printable",
	},
	body_str => Encode::decode("UTF-8", $htmlbody),
);


## Attachment 1

my $image_filename = "$LoxBerry::System::lbhomedir/libs/perllib/LoxBerry/testing/image.png"; 
my $image_bin = LoxBerry::System::read_file($image_filename);

my $img_part1 = Email::MIME->create(
	header_str => [
		'Content-ID' => '<img1>',
		'Content-Disposition' => 'inline',
	],
	attributes => {
		content_type => "image/png",
		encoding     => "base64",
	},
	body => $image_bin,
);

## Info/Error-Symbol

# my $info_filename = $p->{SEVERITY} == 3 ? "$LoxBerry::System::lbhomedir/libs/perllib/LoxBerry/testing/image.png"; 

# my $info_bin = LoxBerry::System::read_file($info_filename);

# my $img_part2 = Email::MIME->create(
	# header_str => [
		# 'Content-ID' => '<info>',
		# 'Content-Disposition' => 'inline',
	# ],
	# attributes => {
		# content_type => "image/png",
		# encoding     => "base64",
	# },
	# body => $info_bin,
# );


## Mixed part (joining all together)

my $mailobj = Email::MIME->create(
	header_str => [
		'To' => $email,
		'From' => Encode::decode("UTF-8", $friendlyname) . " <$email>",
		'Subject' => Encode::decode("UTF-8", $subject),
	],
	attributes => {
		content_type => "multipart/related",
	},
	parts => [
		$html_part,
		#$img_part1,
		#$img_part2,
	],
);

my $mailstr = $mailobj->as_string;

# send the message
my $sendmail_result;
eval {
	$sendmail_result = sendmail($mailstr);
};
if ($@) {
	# Sendmail exception
	print "notifyprovider email: sendmail failed:" . $@ . "\n";
	exit(1);
}
exit(0);

# print $htmlbody;
