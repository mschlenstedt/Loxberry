#!/bin/bash

CATOP="$LBHOMEDIR/data/system/LoxBerryCA"
cd "$CATOP/newcerts"
$LBHOMEDIR/sbin/CA.pl -newreq
$LBHOMEDIR/sbin/CA.pl -sign
mv newcert.pem $CATOP/certs/wwwcert.pem
mv newkeywp.pem $CATOP/private/wwwkeywp.pem
mv newkey.pem $CATOP/private/wwwkey.pem
chmod g+r $CATOP/private/wwwkeywp.pem
chmod g+r $CATOP/private/wwwkey.pem
rm newreq.pem
systemctl is-enabled apache2
if [ $? -eq 0 ]
then
  echo "restart Apache"
  systemctl stop apache2
  systemctl start apache2
fi
