#!/bin/bash

MOSQ_DIR="$LBHOMEDIR/data/system/mosquitto"
mkdir -p $MOSQ_DIR
mkdir newcerts certs private
cd $MOSQ_DIR/newcerts
$LBHOMEDIR/sbin/CA.pl -newreq
$LBHOMEDIR/sbin/CA.pl -sign
mv newcert.pem $MOSQ_DIR/certs/mosq_server.pem
mv newkeywp.pem $MOSQ_DIR/private/mosq_server_pkey.pem
rm newkey.pem
rm newreq.pem
