#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Update;
use LoxBerry::JSON;
use LoxBerry::System::General;

my $newconfigfile = "$lbsconfigdir/mqttgateway.json";
my $oldconfigfile = "$lbhomedir/config/plugins/mqttgateway/mqtt.json";
my $oldcredfile = "$lbhomedir/config/plugins/mqttgateway/cred.json";

LoxBerry::Update::init();

execute( command => "mkdir --parents $lbhomedir/bin/mqtt/transform/custom", log => $log, ignoreerrors => 1 );
execute( command => "mkdir --parents $lbhomedir/bin/mqtt/datastore", log => $log, ignoreerrors => 1 );
execute( command => "mkdir --parents $lbhomedir/config/system/mosquitto", log => $log, ignoreerrors => 1 );

# Clean broken Mosquitto config (could be left from very old Gateway installation)
if( -l "/etc/mosquitto/conf.d/mqttgateway.conf" and not -e "/etc/mosquitto/conf.d/mqttgateway.conf" ) {
	execute( command => "unlink /etc/mosquitto/conf.d/mqttgateway.conf", log => $log, ignoreerrors => 1 );
}

install_packages();
stop_mqttgateway();

# Migration steps
if( -e $oldconfigfile ) {
	config_migration();
	transformers_migration();
	remove_plugin_folders();
	remove_plugindb_entry();
}

create_interface_symlinks();

update_config();

set_file_permissions();

start_mqttgateway();


sub install_packages
{
	LOGINF "Installing new packages";

	apt_install( qw/
		mosquitto
		mosquitto-clients
		libhash-flatten-perl
		libfile-monitor-perl
		libfile-find-rule-perl
		libbsd-resource-perl
		libcgi-simple-perl
	/);

  # Install Mosquitto and keep the original config file shipped with the package
  execute( command => "APT_LISTCHANGES_FRONTEND=none DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends -y --allow-unauthenticated --fix-broken --reinstall --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::='--force-confask,confnew,confmiss' install mosquitto", log => $log, ignoreerrors => 1 );

}


sub update_config
{

	execute( command => $lbhomedir."/sbin/mqtt-handler.pl action=updateconfig", log => $log, ignoreerrors => 1 );

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

	if( -e "/etc/mosquitto/mosquitto.conf.dpkg-dist" ) {
		execute( command => "cp /etc/mosquitto/mosquitto.conf /opt/backup.mqttgateway/", log => $log );
		unlink ("/etc/mosquitto/mosquitto.conf");
		execute( command => "mv /etc/mosquitto/mosquitto.conf.dpkg-dist /etc/mosquitto/mosquitto.conf", log => $log );
	}
	
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
	$generaljson->{Mqtt}->{TLSWebsocketport} = defined $newcfg->{Main}->{TLSwebsocketport} ? trim($newcfg->{Main}->{TLSwebsocketport}) : 9084;
	$generaljson->{Mqtt}->{TLSport} = defined $newcfg->{Main}->{tlsport} ? trim($newcfg->{Main}->{tlsport}) : 8884;

	LOGINF "Removing migrated data from old config";

	delete $newcfg->{Main}->{brokeraddress};
	delete $newcfg->{Main}->{enable_mosquitto};
	delete $newcfg->{Main}->{udpinport};
	delete $newcfg->{Main}->{websocketport};

	LOGINF "Moving Mosquitto plugin configuration to $lbhomedir/config/system/mosquitto...";

	execute( command => "cp -f $lbhomedir/config/plugins/mqttgateway/mosquitto.conf $lbhomedir/config/system/mosquitto/mosq_mqttgateway.conf", log => $log, ignoreerrors => 1 );
	execute( command => "cp -f $lbhomedir/config/plugins/mqttgateway/mosq_passwd /etc/mosquitto/conf.d/", log => $log, ignoreerrors => 1 );

	LOGINF "Recreating Mosquitto configuration symlink...";

	execute( command => "unlink /etc/mosquitto/conf.d/mqttgateway.conf", log => $log, ignoreerrors => 1 );
	execute( command => "ln -f -s $lbhomedir/config/system/mosquitto/mosq_mqttgateway.conf /etc/mosquitto/conf.d/mosq_mqttgateway.conf", log => $log, ignoreerrors => 1 );

}

sub transformers_migration
{

	###
	### Transformers migration
	###

	LOGINF "Migrating MQTT Gateway user transformers";

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

	execute( command => "rm -R -f $lbhomedir/bin/plugins/mqttgateway", log => $log );
	execute( command => "rm -R -f $lbhomedir/config/plugins/mqttgateway", log => $log );
	execute( command => "rm -R -f $lbhomedir/data/plugins/mqttgateway", log => $log );
	execute( command => "rm -R -f $lbhomedir/log/plugins/mqttgateway", log => $log );
	execute( command => "rm -R -f $lbhomedir/templates/plugins/mqttgateway", log => $log );
	execute( command => "rm -R -f $lbhomedir/webfrontend/html/plugins/mqttgateway", log => $log );
	execute( command => "rm -R -f $lbhomedir/webfrontend/htmlauth/plugins/mqttgateway", log => $log );

}

sub create_interface_symlinks
{

	###
	### Creating symlinks for legacy interfaces
	###

	# Generic GET/POST/JSON receiver
	execute( command => "mkdir --parents $lbhomedir/webfrontend/html/plugins/mqttgateway", log => $log, ignoreerrors => 1 );
	execute( command => "ln -f -s $lbhomedir/webfrontend/html/mqtt/receive.php $lbhomedir/webfrontend/html/plugins/mqttgateway/receive.php", log => $log, ignoreerorrs => 1 );
	execute( command => "ln -f -s $lbhomedir/webfrontend/html/mqtt/receive_pub.php $lbhomedir/webfrontend/html/plugins/mqttgateway/receive_pub.php", log => $log, ignoreerorrs => 1 );

	# HTTP interface
	execute( command => "mkdir --parents $lbhomedir/webfrontend/htmlauth/plugins/mqttgateway", log => $log, ignoreerrors => 1 );
	execute( command => "ln -f -s $lbhomedir/webfrontend/htmlauth/system/tools/mqtt.php $lbhomedir/webfrontend/htmlauth/plugins/mqttgateway/mqtt.php", log => $log, ignoreerorrs => 1 );

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

	execute( command => "chown -R loxberry:loxberry $lbhomedir/bin/mqtt", log => $log, ignoreerrors => 1 );
	execute( command => "chown -R loxberry:loxberry $lbhomedir/config/system/mosquitto", log => $log, ignoreerrors => 1 );
	execute( command => "chown -R loxberry:loxberry $lbsconfigdir/mqttgateway.json", log => $log, ignoreerrors => 1 );
	execute( command => "chown -R loxberry:loxberry /opt/backup.mqttgateway", log => $log, ignoreerrors => 1 );
	execute( command => "chown -R loxberry:loxberry $lbhomedir/webfrontend/htmlauth/plugins/mqttgateway", log => $log, ignoreerrors => 1 );
	execute( command => "chown -R loxberry:loxberry $lbhomedir/webfrontend/html/plugins/mqttgateway", log => $log, ignoreerrors => 1 );
	execute( command => "chown -R loxberry:loxberry $lbsconfigdir/general.json", log => $log, ignoreerrors => 1 );

}

sub start_mqttgateway
{

	LOGINF "Starting MQTT Gateway";
	`su loxberry -c "$lbhomedir/sbin/mqttgateway.pl  > /dev/null 2>&1 &"`;
}
