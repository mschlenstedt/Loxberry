#!/usr/bin/perl

use CGI::Fast;
use Carp;
use JSON;
use Config::Simple;
use URI::Escape;
use LWP::UserAgent;
use XML::Simple;
use Sys::Hostname;
use CGI;
use HTML::Template;
use Time::Piece;

{
    while (new CGI::Fast) {
        do $ENV{SCRIPT_FILENAME};
    }
}
