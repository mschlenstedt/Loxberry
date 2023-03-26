#!/usr/bin/env python3

import sys
import os
import json

def mqtt_connectiondetails():
	LBSCONFIG = os.getenv('LBSCONFIG')
	generaljsonPath = LBSCONFIG+'/general.json'
	generaljsonFilehandle = open(generaljsonPath)
	generaljson = json.load(generaljsonFilehandle)

	sys.stderr.write ("Get LoxBerry MQTT Credentials from general.json\n")
	sys.stderr.write ("System config dir: " + LBSCONFIG + "\n")
	sys.stderr.write ("System config file: " + generaljsonPath + "\n")

	if "Mqtt" in generaljson:
		return generaljson['Mqtt']
	else:
		sys.stderr.write ("MQTT Gateway not installed\n")


mqttcred = mqtt_connectiondetails()

if not mqttcred:
	sys.stderr.write ("MQTT Gateway not installed. MQTT Gateway V2.0+ plugin, or LoxBerry V3.0+ required.\n")
	quit()

sys.stderr.write( "Brokerhost: " + mqttcred['Brokerhost'] + "\n" )
sys.stderr.write( "Brokerport: " + mqttcred['Brokerport'] + "\n" )
sys.stderr.write( "Brokeruser: " + mqttcred['Brokeruser'] + "\n" )
sys.stderr.write( "Brokerpass: " + mqttcred['Brokerpass'] + "\n" )
sys.stderr.write( "Udpinport: " + mqttcred['Udpinport'] + "\n" )
sys.stderr.write( "Websocketport: " + mqttcred['Websocketport'] + "\n" )
sys.stderr.write( "TLSport: " + mqttcred['TLSport'] + "\n" )
sys.stderr.write( "TLSWebsocketport: " + mqttcred['TLSWebsocketport'] + "\n" )

