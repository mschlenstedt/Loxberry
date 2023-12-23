#!/bin/bash

CA_DIR="$LBHOMEDIR/data/system/LoxBerryCA"
MOSQ_DIR="$LBHOMEDIR/data/system/mosquitto"
mkdir $MOSQ_DIR/certs/private
cp $CA_DIR/cacert.pem $MOSQ_DIR/certs/cacert.pem
cp $CA_DIR/certs/wwwcert.pem $MOSQ_DIR/certs/mqtt_server.pem
cp $CA_DIR/private/wwwkeywp.pem $MOSQ_DIR/certs/private/mqtt_server_key.pem
chmod 600 $MOSQ_DIR/certs/cacert.pem $MOSQ_DIR/certs/mqtt_server.pem $MOSQ_DIR/certs/private/mqtt_server_key.pem
chown mosquitto $MOSQ_DIR/certs/cacert.pem mosquitto $MOSQ_DIR/certs/mqtt_server.pem mosquitto $MOSQ_DIR/certs/private/mqtt_server_key.pem
