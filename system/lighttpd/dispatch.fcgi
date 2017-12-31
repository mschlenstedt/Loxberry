#!/usr/bin/perl

use CGI::Fast;

{
    while (new CGI::Fast) {
        do $ENV{SCRIPT_FILENAME};
    }
}
