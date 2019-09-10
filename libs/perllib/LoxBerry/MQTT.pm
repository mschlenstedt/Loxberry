# Please increment version number on EVERY change
# Major.Minor represents LoxBerry version (e.g. 2.0.3.2 = LoxBerry V2.0.3 the 2nd change)

################################################################
# LoxBerry::MQTT 
# Supporting library for MQTT
################################################################

use strict;
use LoxBerry::System;

################################################################
package LoxBerry::MQTT;
our $VERSION = "2.0.0.1";
our $DEBUG;

### Exports ###
use base 'Exporter';
our @EXPORT = qw (

);


sub connectiondetails {

	# Check if MQTT Gateway plugin is installed
	my $mqttplugindata = LoxBerry::System::plugindata("mqttgateway");
	my $pluginfolder = $mqttplugindata->{PLUGINDB_FOLDER};
	return undef if(!$pluginfolder);

	my $mqttconf;
    my $mqttcred;
	
	require JSON;
	
	eval {	
		# Read connection details
		$mqttconf = JSON::decode_json(LoxBerry::System::read_file($LoxBerry::System::lbhomedir . "/config/plugins/" . $pluginfolder . "/mqtt.json" ));
		$mqttcred = JSON::decode_json(LoxBerry::System::read_file($LoxBerry::System::lbhomedir . "/config/plugins/" . $pluginfolder . "/cred.json" ));
	};
	if ($@) {
		print STDERR "LoxBerry::MQTT::connectiondetails: Failed to read/parse connection details: $@\n";
		return undef;
	}
	
	my %cred;
	
	my ($brokerhost, $brokerport) = split(':', $mqttconf->{Main}->{brokeraddress}, 2);
	$brokerport = $brokerport ? $brokerport : 1883;
	$cred{brokeraddress} = $brokerhost.":".$brokerport;
	$cred{brokerhost} = $brokerhost;
	$cred{brokerport} = $brokerport;
	$cred{brokeruser} = $mqttcred->{Credentials}->{brokeruser};
	$cred{brokerpass} = $mqttcred->{Credentials}->{brokerpass};
	$cred{udpinport} = $mqttconf->{Main}->{udpinport};

	return \%cred;

}






#####################################################
# Finally 1; ########################################
#####################################################
1;
