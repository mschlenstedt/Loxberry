#!/bin/bash

CATOP="$LBHOMEDIR/data/system/LoxBerryCA"
cd "$CATOP/newcerts"
$LBHOMEDIR/sbin/CA.pl -newreq
$LBHOMEDIR/sbin/CA.pl -sign
cp ../cacert.pem $LBHOMEDIR/webfrontend/html/system/cacert.pem
mv newcert.pem $CATOP/certs/wwwcert.pem
mv newkeywp.pem $CATOP/private/wwwkeywp.pem
mv newkey.pem $CATOP/private/wwwkey.pem
rm newreq.pem
systemctl stop apache2
systemctl start apache2
