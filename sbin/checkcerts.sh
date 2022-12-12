if openssl x509 -checkend 86400 -noout -in $LBHOMEDIR/data/system/LoxBerryCA/cacert.pem
then
  echo "CA-Certificate is good for another 1 day!"
else
  echo "CA-Certificate has expired or will do so within 1 day!"
  echo "Create e new CA"
  rm -rf $LBHOMEDIR/data/system/LoxBerryCA
  $LBHOMEDIR/sbin/CA.pl -newca
  $LBHOMEDIR/sbin/makewwwcert.sh
  exit 0
fi

if openssl x509 -checkend 86400 -noout -in $LBHOMEDIR/data/system/LoxBerryCA/certs/wwwcert.pem
then
  echo "WWW-Certificate is good for another 1 day!"
else
  echo "WWW-Certificate has expired or will do so within 1 day!"
  echo "Create a new one"
  $LBHOMEDIR/sbin/revokewwwcert.sh
  $LBHOMEDIR/sbin/makewwwcert.sh
  exit 0
fi

IP=`perl -e "require LoxBerry::System; print LoxBerry::System::get_localip();"`
CERT=`openssl x509 -noout -in $LBHOMEDIR/data/system/LoxBerryCA/wwwcert.pem | grep "$IP"`
if [ -z "$CERT" ]
then
  $LBHOMEDIR/sbin/revokewwwcert.sh
  $LBHOMEDIR/sbin/makewwwcert.sh
  exit 0
fi
