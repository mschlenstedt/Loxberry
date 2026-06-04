#!/bin/bash
LBHOMEDIR="${LBHOMEDIR:-/opt/loxberry}"
export PERL5LIB="$LBHOMEDIR/libs/perllib"
"$LBHOMEDIR/sbin/mqtt-handler.pl" action=bootstart
