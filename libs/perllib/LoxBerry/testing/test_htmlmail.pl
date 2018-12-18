#!/usr/bin/perl
use LoxBerry::System;
use strict;
use warnings;

# Read mail settings
use LoxBerry::JSON;
my $mailfile = $lbsconfigdir . "/mail.json";
my $mailobj = LoxBerry::JSON->new();
my $mcfg = $mailobj->open(filename => $mailfile, readonly => 1);
my $from = $mcfg->{SMTP}->{EMAIL};
my $to = $mcfg->{SMTP}->{EMAIL};

print "Sender/Receiver: $from\n";

###########################################
# MIME::Lite
# Developer recommends: Use something else
###########################################

# use MIME::Lite;

# # create a new MIME Lite based email
# my $msg = MIME::Lite->new
# (
# Subject => "HTML email test",
# From    => $from,
# To      => $to,
# Type    => 'text/html',
# Data    => '<H1>Hello</H1><br>This is a test email.
# Please visit our site <a href="http://cyberciti.biz/">online</a><hr>'
# );

# $msg->send();


###########################################
# Email::Stuffer
# Installs a list of libs (1,5MB)
###########################################

# require Email::Stuffer;

# my $body = <<'AMBUSH_READY';
# <h2>Dear Santa</h2>
 
# I have killed Bun Bun.
 
# <i>Yes, I know what you are thinking... but it was actually a total accident.</i>
 
# I was in a crowded line at a BayWatch signing, and I tripped, and stood on
# his head.

# <img src="main_admin.png" alt="Admin widget">
# <b>I know. Oops! :/</b>
 
# So anyways, I am willing to sell you the body for $1 million dollars.
 
# Be near the pinhole to the Dimension of Pain at midnight.
 
# <i>Alias</i>
 
# AMBUSH_READY
 
# # Create and send the email in one shot
# Email::Stuffer->from     ( $from )
              # ->to       ( $to )
              # #->bcc      ('bunbun@sluggy.com'       )
              # ->html_body( $body                     )
              # ->attach_file( "$lbshtmldir/images/icons/main_admin.png" )
              # ->send;

			  
			  
####################################################
# EMail::MIME			  
# https://www.perlmonks.org/?node_id=1077724
####################################################

require Email::MIME;
require MIME::Base64;

my $html = <<EOF;
<html>
    <head>
        <title>Testmail</title>
    </head>
    <body>
        <p>Eine Mäil müt Büdern<br/>
			<img src="cid:logo" alt="Logo" width="158px" height="70px" />
			<p>Das ist cool</p>
			</p>
		
    </body>
</html>
EOF

# read the file
my $filename = "$lbshtmldir/images/icons/main_admin.png";  # take filename of a small 158x70 png
my $image = LoxBerry::System::read_file($filename);
my $image_encoded = MIME::Base64::encode_base64($image);

my $mail_part = Email::MIME->create(
    attributes => {
        content_type => "text/html",
        charset      => "UTF-8",
        encoding     => "quoted-printable",
    },
    body_str => Encode::decode("UTF-8", $html),
);

my $jpeg_part = Email::MIME->create(
    header_str => [
        'Content-ID' => '<logo>',
        'Content-Disposition' => 'inline',
    ],
    attributes => {
        content_type => "image/png",
        encoding     => "base64",
    },
    body => $image,
);

my $mail = Email::MIME->create(
    header_str => [
        'To' => $to,
        'From' => $from,
        'Subject' => Encode::decode("UTF-8", 'Testmail Österreich'),
    ],
    attributes => {
        content_type => "multipart/related",
    },
    parts => [
        #$mail_part,
        $jpeg_part,
    ],
);

print $mail->as_string;

# send the message
use Email::Sender::Simple qw(sendmail);
sendmail($mail->as_string);


