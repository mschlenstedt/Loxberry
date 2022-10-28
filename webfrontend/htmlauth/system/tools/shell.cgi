#!/bin/bash

# This is a simple demo CGI script that illustrates how to use ShellInABox in
# CGI mode.

# This script is run as user loxberry - so it is only possible to login as user loxberry. Use "su"
# after logging in to change login.
#shellinaboxd --cgi -t -s "/:AUTH:HOME:/bin/bash" --user-css "Normal:-$LBHOMEDIR/system/shellinabox/blackonwhite.css,Reverse:+$LBHOMEDIR/system/shellinabox/whiteonblack.css" --user-css "Color:+$LBHOMEDIR/system/shellinabox/colorterminal.css,Monochrome:-$LBHOMEDIR/system/shellinabox/monochrome.css"
shellinaboxd --cgi -t -n -s "/:AUTH:HOME:/bin/bash" --user-css "Normal:-/etc/shellinabox/options-available/00+Black on White.css,Reverse:+/etc/shellinabox/options-available/00_White On Black.css" --user-css "Color:+/etc/shellinabox/options-available/01+Color Terminal.css,Monochrome:-/etc/shellinabox/options-available/01_Monochrome.css"
