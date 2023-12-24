if openssl x509 -checkend 86400 -noout -in $LBHOMEDIR/data/system/LoxBerryCA/cacert.pem
then
  echo "CA-Certificate is good for another 1 day!"
else
  echo "CA-Certificate has expired or will do so within 1 day!"
  echo "Create e new CA"
  rm -rf $LBHOMEDIR/data/system/LoxBerryCA
  $LBHOMEDIR/sbin/CA.pl -newca
  $LBHOMEDIR/sbin/makewwwcert.sh
  $LBHOMEDIR/sbin/make_mosq_cert.sh
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
CERT=`openssl x509 -noout -text -in $LBHOMEDIR/data/system/LoxBerryCA/certs/wwwcert.pem | egrep -i "$IP$"`
if [ -z "$CERT" ]
then
  $LBHOMEDIR/sbin/revokewwwcert.sh
  $LBHOMEDIR/sbin/makewwwcert.sh
  exit 0
fi

if openssl x509 -checkend 86400 -noout -in $LBHOMEDIR/data/system/mosquitto/certs/mosq_server.pem
then
  echo "Mosquitto Certificate is good for another 1 day!"
else
  echo "Mosquitto Certificate has expired or will do so within 1 day!"
  echo "Create a new one"
  $LBHOMEDIR/sbin/revoke_mosq_cert.sh
  $LBHOMEDIR/sbin/make_mosq_cert.sh
  exit 0
fi

IP=`perl -e "require LoxBerry::System; print LoxBerry::System::get_localip();"`
CERT=`openssl x509 -noout -text -in $LBHOMEDIR/data/system/mosquitto/certs/mosq_server.pem | egrep -i "$IP$"`
if [ -z "$CERT" ]
then
  $LBHOMEDIR/sbin/revoke_mosq_cert.sh
  $LBHOMEDIR/sbin/make_mosq_cert.sh
  exit 0
fi

exit 0
