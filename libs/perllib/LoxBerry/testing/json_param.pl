#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::JSON;
use Data::Dumper;
use HTML::Template;

my $filename = "$lbhomedir/libs/perllib/LoxBerry/testing/jsontestdata2.json";
my $jsonobj = LoxBerry::JSON->new();
my $data = $jsonobj->open(filename => $filename);

my $template = HTML::Template->new(
    filename  => 'json_param.tmpl',
    associate => $jsonobj,
);

print $template->output();
