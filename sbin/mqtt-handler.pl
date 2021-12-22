#!/usr/bin/perl
use warnings;
use strict;
use CGI::Simple qw(-debug1);
use LoxBerry::System;
use LoxBerry::Log;
use LoxBerry::JSON;

my $generaljsonfile = "$lbsconfigdir/general.json";
my $cfgfile = "$lbsconfigdir/mqttgateway.json";
my $mosq_configdir = "$lbsconfigdir/mosquitto";
my $mosq_cfgfile = "$mosq_configdir/mosquitto.conf";
my $mosq_passwdfile = "$mosq_configdir/mosq_passwd";

my $generaljsonobj;
my $generalcfg;
my $mqttobj;
my $cfg;
	
my $q = CGI::Simple->new;
my $action = $q->param('action');

my $log = LoxBerry::Log->new (
    package => 'mqtt',
	name => 'Update Configuration',
	stderr => 1 ,
	loglevel => 7,
);

LOGSTART "Updating configuration during plugin installation";

if( $action eq "updateconfig" ) { 
	open_configs();
	update_config(); 
}
elsif( $action eq "mosquitto_set" ) { 
	open_configs();
	mosquitto_set(); 
}

exit;

sub open_configs
{
	$generaljsonobj = LoxBerry::JSON->new();
	$generalcfg = $generaljsonobj->open(filename => $generaljsonfile, lockexclusive=> 1, writeonclose=>1);
	$mqttobj = LoxBerry::JSON->new();
	$cfg = $mqttobj->open(filename => $cfgfile, lockexclusive=> 1, writeonclose=>1);
}

sub update_config
{

	my $changed = 0;
	if(! defined $cfg->{Main}->{msno}) { 
		$cfg->{Main}->{msno} = 1;
		LOGINF "Setting Miniserver to " . $cfg->{Main}->{msno};
		}
	if(! defined $cfg->{Main}->{udpport}) { 
		$cfg->{Main}->{udpport} = 11883; 
		LOGINF "Setting Miniserver UDP Out-Port to " . $cfg->{Main}->{udpport};
		}
	if(! defined $generalcfg->{Mqtt}->{Uselocalbroker}) { 
		$generalcfg->{Mqtt}->{Uselocalbroker} = 'true'; 
		LOGINF "Setting 'Enable local Mosquitto broker' to " . $cfg->{Mqtt}->{Uselocalbroker};
		}
	if(! defined $generalcfg->{Mqtt}->{Brokerhost}) { 
		$generalcfg->{Mqtt}->{Brokerhost} = 'localhost';
		LOGINF "Setting MQTT brokerhost to " . $generalcfg->{Main}->{Brokerhost};
		}
	if(! defined $generalcfg->{Mqtt}->{Brokerport}) { 
		$generalcfg->{Mqtt}->{Brokerport} = '1883';
		LOGINF "Setting MQTT brokerport to " . $generalcfg->{Main}->{Brokerport};
		}
	if(! defined $cfg->{Main}->{convert_booleans}) { 
		$cfg->{Main}->{convert_booleans} = 1; 
		LOGINF "Setting 'Convert booleans' to " . $cfg->{Main}->{convert_booleans};
		}
	if(! defined $cfg->{Main}->{expand_json}) { 
		$cfg->{Main}->{expand_json} = 1; 
		LOGINF "Setting 'Expand JSON' to " . $cfg->{Main}->{expand_json};
		}
	if(! defined $generalcfg->{Mqtt}->{Udpinport}) { 
		$generalcfg->{Mqtt}->{Udpinport} = 11884; 
		LOGINF "Setting MQTT gateway UDP In-Port to " . $generalcfg->{Mqtt}->{Udpinport};
		}
	
	if(! defined $cfg->{Main}->{pollms}) { 
		$cfg->{Main}->{pollms} = 50; 
		LOGINF "Setting poll time for MQTT and UDP connection to " . $cfg->{Main}->{pollms} . " milliseconds";
		}
	if(! defined $cfg->{Main}->{resetaftersendms}) { 
		$cfg->{Main}->{resetaftersendms} = 13; 
		LOGINF "Setting Reset-After-Send delay to " . $cfg->{Main}->{resetaftersendms} . " milliseconds";
		}
	if(! defined $cfg->{Main}->{toMS_delimiter}) { 
		$cfg->{Main}->{toMS_delimiter} = '|'; 
		LOGINF "Setting delimiter for subscription miniserver list to " . $cfg->{Main}->{toMS_delimiter};
		}
	if(! defined $cfg->{Main}->{cpuperf}) { 
		$cfg->{Main}->{cpuperf} = "5"; 
		LOGINF "Setting Performance Profile to " . $cfg->{Main}->{cpuperf};
		}
	if(! defined $generalcfg->{Mqtt}->{Websocketport}) { 
		$generalcfg->{Mqtt}->{Websocketport} = "9001"; 
		LOGINF "Setting Mosquitto WebSocket port to " . $generalcfg->{Mqtt}->{Websocketport};
		}
	
	
	# Create Mosquitto config and password
	
	if( !defined $generalcfg->{Mqtt}->{Brokeruser} ) {
		$generalcfg->{Mqtt}->{Brokeruser} = 'loxberry';
		$generalcfg->{Mqtt}->{Brokerpass} = generate(16);
	}
	
	`chown loxberry:loxberry $cfgfile`;
	`mkdir $mosq_configdir`;
	`ln -f -s $mosq_cfgfile /etc/mosquitto/conf.d/mqttgateway.conf`;

}

sub mosquitto_set
{
	
	if( is_enabled($generalcfg->{Mqtt}->{Uselocalbroker}) ) { 
		`mkdir $mosq_configdir`;
		`ln -f -s $mosq_cfgfile /etc/mosquitto/conf.d/mqttgateway.conf`;
		mosquitto_setcred();
		mosquitto_enable();
		mosquitto_readconfig();
	} 
	else {
		mosquitto_disable();
	}
	
}

sub mosquitto_enable
{
	`systemctl enable mosquitto`;
}

sub mosquitto_disable
{
	`systemctl disable mosquitto`;
	`systemctl stop mosquitto`;
}


sub mosquitto_setcred
{

	my $brokeruser = $generalcfg->{Mqtt}->{Brokeruser};
	my $brokerpass = $generalcfg->{Mqtt}->{Brokerpass};
	my $brokerport = $generalcfg->{Mqtt}->{Brokerport};
	my $websocketport = $generalcfg->{Mqtt}->{Websocketport};
	
	# Create and write config file
	my $mosq_config;
	
	$mosq_config  = "# This file is directly managed by LoxBerry.\n";
	$mosq_config .= "# Do not change this file, as your changes will be lost on saving in the MQTT Gateway webinterface.\n\n";
	
	$mosq_config .= "port $brokerport\n\n";
	$mosq_config .= "# To reduce SD writes, save Mosquitto DB only once a day\n";
	$mosq_config .= "autosave_interval 86400\n\n";

	## Not working because of permissions (user mosquitto has no access)
	# $mosq_config .= "# Use LoxBerry's Plugin logging directory for Mosquitto logfile\n";
	# $mosq_config .= "log_dest file $lbplogdir/mosquitto.log\n\n";
		
	# User and pass, or anonymous
	if(!$brokeruser and !$brokerpass) {
		# Anonymous when no credentials are provided
		$mosq_config .= "allow_anonymous true\n";
	} else {
		# User/Pass and password file when credentials are provided
		$mosq_config .= "allow_anonymous false\n";
		$mosq_config .= "password_file $mosq_passwdfile\n";
	}
	
	# # TLS listener
	# if ($Credentials{brokerpsk}) {
		# $mosq_config .= "# TLS-PSK listener\n";
		# $mosq_config .= "listener 8883\n";
		# $mosq_config .= "use_identity_as_username true\n";
		# $mosq_config .= "tls_version tlsv1.2\n";
		# $mosq_config .= "psk_hint mqttgateway_psk\n";
		# $mosq_config .= "psk_file $mosq_pskfile\n";
	# }
	
	# Websocket listener (currently without TLS)
	$mosq_config .= "\n# Websockets listener\n";
	$mosq_config .= "listener $websocketport\n";
	$mosq_config .= "protocol websockets\n";
	
	LoxBerry::System::write_file($mosq_cfgfile, $mosq_config);
	`chown loxberry:loxberry $mosq_cfgfile`;
			
	# Passwords
	unlink $mosq_passwdfile;
	if ($brokeruser or $brokerpass) {
		`touch $mosq_passwdfile`;
		my $res = qx { mosquitto_passwd -b $mosq_passwdfile $brokeruser $brokerpass };
	}
	`chown loxberry:loxberry $mosq_passwdfile`;
	
}

sub mosquitto_readconfig
{
	my ($exitcode, undef) = LoxBerry::System::execute('pgrep mosquitto');
	if( $exitcode != 0 ) {
		LoxBerry::System::execute('systemctl restart mosquitto');
	} 
	else {
		LoxBerry::System::execute('pkill -HUP mosquitto');
	}
}


#####################################################
# Random Sub
#####################################################
sub generate {
        my ($count) = @_;
        my($zufall,@words,$more);

        if($count =~ /^\d+$/){
                $more = $count;
        }else{
                $more = 10;
        }

        @words = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9);

        foreach (1..$more){
                $zufall .= $words[int rand($#words+1)];
        }

        return($zufall);
}


################################################
# Generate a key in hex string representation
# Parameter is keylength in bit
################################################
sub generate_hexkey
{

	my ($keybits) = @_;
	
	if (! $keybits or $keybits < 40) {
		$keybits = 128;
	}
	
	my $keybytes = int($keybits/8+0.5);
	# print STDERR "Keybits: $keybits Keybytes: $keybytes\n";
	my $hexstr = "";
	
	for(1...$keybytes) { 
		my $rand = int(rand(256));
		$hexstr .= sprintf('%02X', $rand);
		# print STDERR "Rand: $rand \tHEX: $hexstr\n";
	}
	
	if ( length($hexstr) < ($keybytes*2) ) {
		return undef;
	}
	return $hexstr;

}








END
{
	
	# Return http response here
	# Check for $errorstr
	
	if ($log) {
		$log->LOGEND();
	}
}