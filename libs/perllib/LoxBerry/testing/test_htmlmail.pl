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

# # SendTo email id
# my $email = 'fenzl@t-r-t.at';

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