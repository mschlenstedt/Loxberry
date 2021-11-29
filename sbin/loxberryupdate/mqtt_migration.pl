#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Update;
use LoxBerry::JSON;
use LoxBerry::System::General;

my $newconfigfile = "$lbsconfigdir/mqttgateway.json";
my $oldconfigfile = "$lbhomedir/config/plugins/mqttgateway/mqtt.json";
my $oldcredfile = "$lbhomedir/config/plugins/mqttgateway/cred.json";


LoxBerry::Update::init();

# install_packages();


# Migration steps
if( -e $oldconfigfile ) {
	stop_mqttgateway();
	config_migration();
	transformers_migration();
	# remove_plugin_folders();
	create_interface_symlinks();
	remove_plugindb_entry();
	set_file_permissions();
}



sub install_packages
{
	## Installation of required packages and Perl modules
	apt_install( qw/ 
		mosquitto
		mosquitto-clients
		libhash-flatten-perl
		libfile-monitor-perl
		libfile-find-rule-perl
		libbsd-resource-perl
	/);
	
	
}



sub stop_mqttgateway
{
	###
	### Stop MQTT Gateway
	###

	LOGINF "Stopping MQTT Gateway plugin";
	execute( command => "pkill mqttgateway.pl", log => $log, ignoreerrors => 1 );

}


sub config_migration 
{
	
	###
	### Config Migration
	###
	
	LOGINF "Creating configuration backup of MQTT Gateway plugin";
	execute( command => "mkdir --parents /opt/backup.mqttgateway", log => $log, ignoreerrors => 1);
	execute( command => "cp $lbhomedir/config/plugins/mqttgateway/* /opt/backup.mqttgateway/", log => $log );

	
	LOGOK "Starting migration of MQTT Gateway plugin settings to general.json and mqttgateway.json";

	execute( command => "cp -f $oldconfigfile $newconfigfile", log => $log );

	LOGINF "Open and lock general.json";
	my $generaljsonobj = LoxBerry::System::General->new();
	my $generaljson = $generaljsonobj->open( writeonclose => 1, lockexclusive => 1 );

	LOGINF "Open and lock new mqttgateway.json";
	my $newconfobj = LoxBerry::JSON->new();
	my $newcfg = $newconfobj->open(filename => $newconfigfile, writeonclose => 1, lockexclusive => 1 );
	
	LOGINF "Open plugin cred.json";
	my $oldcredobj = LoxBerry::JSON->new();
	my $oldcred = $oldcredobj->open(filename => $oldcredfile, readonly => 1 );

	LOGINF "Migrating data to general.json";

	my ($brokerhost, $brokerport) = split(':', $newcfg->{Main}->{brokeraddress}, 2);
	$brokerport = defined $brokerport ? $brokerport : "1883";
		
	
	$generaljson->{Mqtt}->{Udpinport} = $newcfg->{Main}->{udpinport};
	$generaljson->{Mqtt}->{Brokerhost} = $brokerhost;
	$generaljson->{Mqtt}->{Brokerport} = $brokerport;
	$generaljson->{Mqtt}->{Brokeruser} = $oldcred->{Credentials}->{brokeruser};
	$generaljson->{Mqtt}->{Brokerpass} = $oldcred->{Credentials}->{brokerpass};
	
	if( is_enabled( $newcfg->{Main}->{enable_mosquitto} ) ) {
		$generaljson->{Mqtt}->{Uselocalbroker} = 1;
	} else {
		$generaljson->{Mqtt}->{Uselocalbroker} = 0;
	}
	$generaljson->{Mqtt}->{Websocketport} = defined $newcfg->{Main}->{websocketport} ? trim($newcfg->{Main}->{websocketport}) : 9002;

	LOGINF "Removing migrated data from old config";
	
	delete $newcfg->{Main}->{brokeraddress};
	delete $newcfg->{Main}->{enable_mosquitto};
	delete $newcfg->{Main}->{udpinport};
	delete $newcfg->{Main}->{websocketport};
	
	
}

sub transformers_migration
{
	
	###
	### Transformers migration
	###
	
	LOGINF "Migrating MQTT Gateway user transformers";
	
	execute( command => "mkdir --parents $lbhomedir/bin/mqtt/transform/custom", log => $log );
	execute( command => "mkdir --parents $lbhomedir/bin/mqtt/datastore", log => $log );
	
	if( -d "$lbhomedir/data/plugins/mqttgateway/transform/custom" ) {
		execute( command => "cp -f -R $lbhomedir/data/plugins/mqttgateway/transform/custom/* $lbhomedir/bin/mqtt/transform/custom", log => $log );
	}
	
	if( -d "$lbhomedir/data/plugins/mqttgateway/transform/datastore" ) {
		execute( command => "cp -f -R $lbhomedir/data/plugins/mqttgateway/transform/datastore/* $lbhomedir/bin/mqtt/datastore/", log => $log);
	}
	LOGOK "Your own MQTT Transformers are now located in $lbhomedir/bin/mqtt/transform/custom/";

}

sub remove_plugin_folders
{
	###
	### Removing plugin folders
	###
	
	execute( command => 'rm -R -f $lbhomedir/bin/plugins/mqttgateway', log => $log );
	execute( command => 'rm -R -f $lbhomedir/config/plugins/mqttgateway', log => $log );
	execute( command => 'rm -R -f $lbhomedir/data/plugins/mqttgateway', log => $log );
	execute( command => 'rm -R -f $lbhomedir/log/plugins/mqttgateway', log => $log );
	execute( command => 'rm -R -f $lbhomedir/templates/plugins/mqttgateway', log => $log );
	execute( command => 'rm -R -f $lbhomedir/webfrontend/html/plugins/mqttgateway', log => $log );
	execute( command => 'rm -R -f $lbhomedir/webfrontend/htmlauth/plugins/mqttgateway', log => $log );
	
}

sub create_interface_symlinks
{
	###
	### Creating symlinks for legacy interfaces
	###
	

	
}

sub remove_plugindb_entry
{
	###
	### Remove plugin from plugin database
	###
	use LoxBerry::System::PluginDB;
	
	my $plugin = LoxBerry::System::PluginDB->plugin( md5 => '07a6053111afa90479675dbcd29d54b5' );
	if(!$plugin) {
		LOGWARN "MQTT Gateway Plugin not found in Plugindatabase";
	} else {
		LOGOK "Removing MQTT Gateway Plugin from Plugindatabase";
		$plugin->remove();
	}
	
}

sub set_file_permissions
{
	###
	### Set file permissions
	###
	
	
}