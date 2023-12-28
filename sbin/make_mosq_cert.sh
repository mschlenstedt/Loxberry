#!/bin/bash

CA_DIR="$LBHOMEDIR/data/system/LoxBerryCA"
MOSQ_DIR="$LBHOMEDIR/data/system/mosquitto"
mkdir -p $MOSQ_DIR
mkdir $MOSQ_DIR/newcerts $MOSQ_DIR/certs $MOSQ_DIR/private
cd $MOSQ_DIR/newcerts
openssl req -new -subj='/C=/ST=/L=/O=/OU=/CN=loxberrymqtt' -keyout newkey.pem -out newreq.pem  -passout file:$LBHOMEDIR/data/system/LoxBerryCA/randb64
$LBHOMEDIR/sbin/CA.pl -sign
mv newcert.pem $MOSQ_DIR/certs/mosqcert.pem
mv newkeywp.pem $MOSQ_DIR/private/mosqkeywp.pem
chown mosquitto $MOSQ_DIR/private/mosqkeywp.pem
rm newkey.pem
rm newreq.pem
