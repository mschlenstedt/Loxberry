#!/usr/bin/perl

use LoxBerry::Web;
use LoxBerry::JSON;


my $filename = "$lbhomedir/libs/perllib/LoxBerry/testing/jsontestdata2.json";
my $jsonobj = LoxBerry::JSON->new();
$jsonobj->open(filename => $filename);

LoxBerry::Web::lbheader();

print "<h1>Hello World</h1>\n";
print "<script>\n";
print $jsonobj->jsblock( "varname" => "cfg" );
print "console.log(cfg.SMTP.EMAIL);\n";
print "</script>\n";

LoxBerry::Web::lbfooter();

