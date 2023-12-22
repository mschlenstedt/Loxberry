#!/bin/bash

CA_DIR="$LBHOMEDIR/data/system/LoxBerryCA"
MOSQ_DIR="$LBHOMEDIR/data/system/mosquitto"
mkdir $MOSQ_DIR
cp $CA_DIR/cacert.pem $MOSQ_DIR/certs/cacert.pem
cp $CA_DIR/certs/wwwcert.pem $MOSQ_DIR/certs/mqtt_server.pem
cp $CA_DIR/private/wwwkeywp.pem $MOSQ_DIR/certs/private/mqtt_server_key.pem
chown mosquitto $MOSQ_DIR/certs/cacert.pem
chown mosquitto $MOSQ_DIR/certs/mqtt_server.pem
chown mosquitto $MOSQ_DIR/certs/private/mqtt_server_key.pem
