# Please increment version number on EVERY change 
# Major.Minor represents LoxBerry version (e.g. 0.3.1.12 = LoxBerry V0.3.1 the 12th change)

use strict;
use Carp;
use LoxBerry::System;
use Time::Piece;
use HTML::Entities;
use JSON;
use File::Basename;
use File::Path;

################################################################
package LoxBerry::Log;
our $VERSION = "1.0.0.10";
our $DEBUG;

# This object is the object the exported LOG* functions use
our $mainobj;
our $packagedb;
# 
my $packagedbfile = "$LoxBerry::System::lbsdatadir/logpackages.json";
our %severitylist = ( 
	0 => 'EMERGE', 
	1 => 'ALERT', 
	2 => 'CRITICAL', 
	3 => 'ERROR', 
	4 => 'WARNING', 
	5 => 'OK', 
	6 => 'INFO', 
	7 => 'DEBUG' );

### Exports ###
use base 'Exporter';
our @EXPORT = qw (

notify
notify_ext
delete_notifications
delete_notification_key
get_notification_count
get_notifications
parsedatestring

);

# Variables

my $notifymailerror;

################################################################
## Constructor
## 	Params [square brackets mean optional]
##		name 			The name of the log
##		[filename]		If provided, this file is be used
##		[logdir]		If provided without filename, a file in this directory will be created
##		append = 1		If the file already exists, it will append


##################################################################

# raise loglevel after critic
# persistently raise loglevel on critic
#
#
sub new 

{
	my $class = shift;
	# print STDERR "Class: $class\n";
	if (@_ % 2) {
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	my %params = @_;
	
	my $self = { 
				name => $params{name},
				filename => $params{filename},
				logdir => $params{logdir},
				append => $params{append},
				package => $params{package},
				loglevel => $params{loglevel},
				stderr => $params{stderr},
				stdout => $params{stdout},
				nofile => $params{nofile},
				autoraise => $params{nofile},
				addtime => $params{addtime},
	};
	
	bless $self, $class;
	
	if ($self->{autoraise} eq "") {
		$self->{autoraise} = 1;
	}
	
	# Setting package
	# print STDERR "Package: " . $self->{package} . "\n";
	if (!$self->{package}) {
		if ($LoxBerry::System::lbpplugindir) {
			$self->{package} = $LoxBerry::System::lbpplugindir;
		}
		if (!$self->{package}) {
		Carp::croak "A 'package' must be defined if this log is not from a plugin";
		}
	}
	
	# Generating filename
	# print STDERR "1. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
	if (!$self->{logdir} && !$self->{filename} && -e $LoxBerry::System::lbplogdir) {
		$self->{logdir} = $LoxBerry::System::lbplogdir;
	}
	# print STDERR "2. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
	if ($self->{logdir} && !$self->{filename}) {
		$self->{filename} = $self->{logdir} . "/" . LoxBerry::System::currtime('file') . "_" . $self->{name} . ".log";
		# print STDERR "3. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
			
	} elsif (!$self->{filename}) {
		# print STDERR "4. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
		if ($LoxBerry::System::lbplogdir && -e $LoxBerry::System::lbplogdir) {
			$self->{filename} = "$LoxBerry::System::lbplogdir/" . currtime('file') . "_" . $self->{name} . ".log";
			# print STDERR "5. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
			
		
		} elsif (! $self->{nofile}) {
			Carp::croak "Cannot determine plugin log directory";
		}
	} 
	if (!$self->{filename} && !$self->{nofile}) {
		Carp::croak "Cannot smartly detect where your logfile should be placed. Check your parameters.";
	}
	
	# Get loglevel
	# print STDERR "Log.pm: Loglevel is " . $self->{loglevel} . "\n";
	if (!$self->{loglevel}) {
		my %plugindata = LoxBerry::System::plugindata();
		if ($plugindata{'PLUGINDB_LOGLEVEL'}) {
			$self->{loglevel} = $plugindata{'PLUGINDB_LOGLEVEL'};
		} else {
			$self->{loglevel} = 7;
		}
	}
	# print STDERR "Log.pm: Loglevel is " . $self->{loglevel} . "\n";
	# print STDERR "filename: " . $self->{filename} . "\n";
	
	my $writetype = defined $self->{append} ? ">>" : ">";
	# print STDERR "Write type is : " . $writetype . "\n";
	
	if (!$self->{nofile}) {
		$self->open($writetype);
	}
	
	if (!$LoxBerry::Log::mainobj) {
		$LoxBerry::Log::mainobj = $self;
	}
	
	
	return $self;
}

sub loglevel 
{
	my $self = shift;
	my $loglevel = shift;
	if ($loglevel && $loglevel >= 0 && $loglevel <= 7) {
		$self->{loglevel} = $loglevel;
	}
	return $self->{loglevel};
}

sub autoraise
{
	my $self = shift;
	my $param = shift;
	if ($param == 0) {
		undef $self->{autoraise};
	} elsif ($param == 1) {
		$self->{autoraise} = 1;
	}
	return $self->{autoraise};
}

sub filehandle
{
	my $self = shift;
	if ($self->{'_FH'}) {
		return $self->{'_FH'};
	}
}
sub filename
{
	my $self = shift;
	if ($self->{filename}) {
		return $self->{filename};
	}
}

sub open
{
	my $self = shift;
	my $writetype = shift;
	# print STDERR "Log open writetype before processing: " . $writetype . "\n";
	if (!$writetype) {
		$writetype = ">>";
	}
	
	my $dir = File::Basename::dirname($self->{filename});
	File::Path::make_path($dir);
	
	# print STDERR "log open Writetype after processing is " . $writetype . "\n";
	open(my $fh, $writetype, $self->{filename}) or Carp::croak "Cannot open logfile " . $self->{filename};
	$self->{'_FH'} = $fh;
}

sub close
{
	my $self = shift;
	close $self->{'_FH'} if $self->{'_FH'};
	return $self->{filename};
}

##########################################################
# Functions to enable strerr and stdout, and
# disable file writing (nofile)
##########################################################
sub stderr
{
	my $self = shift;
	my $param = shift;
	if ($param == 0) {
		undef $self->{stderr};
	} elsif ($param == 1) {
		$self->{stderr} = 1;
	}
	return $self->{stderr};
}

sub stdout
{
	my $self = shift;
	my $param = shift;
	if ($param == 0) {
		undef $self->{stdout};
	} elsif ($param == 1) {
		$self->{stdout} = 1;
	}
	return $self->{stdout};
}

sub nofile
{
	my $self = shift;
	my $param = shift;
	if ($param == 0) {
		undef $self->{nofile};
	} elsif ($param == 1) {
		$self->{nofile} = 1;
	}
	return $self->{nofile};
}

##################################################################################
# Writing to logfile function
##################################################################################
sub write
{
	my $self = shift;
	my $severity = shift;
	my ($s)=@_;
	
	# print STDERR "Severity: $severity / Loglevel: " . $self->{loglevel} . "\n";
	# print STDERR "Log: $s\n";
	# Do not log if loglevel is lower than severity
	# print STDERR "--> write \n";
	# print STDERR "    autoraise\n";
	if ($severity <= 2 && $severity >= 0 && $self->{loglevel} < 6 && $self->{autoraise} == 1) {
		# print STDERR "    autoraise to loglevel 6\n";
		$self->{loglevel} = 6;
	}
	
	if ($severity <= $self->{loglevel} || $severity < 0) {
		#print STDERR "Not filtered.\n";
		my $fh = $self->{'_FH'};
		my $string;
		my $currtime = "";
		if ($self->{addtime}) {
			my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
			$year += 1900;
			$currtime = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
			$currtime = $currtime . " ";
		}
		
		
		if ($severity == 7 || $severity < 0) {
			$string = $currtime . $s . "\n"; 
		} else {
			$string = '<' . $severitylist{$severity} . '> ' . $currtime . $s . "\n"; 
		}
		if (!$self->{nofile}) {
			# print STDERR "   Print to file\n";
			print $fh $string;
			}
		if ($self->{stderr}) {
			print STDERR $string;
		}
		if ($self->{stdout}) {
			print STDOUT $string;
		}
	} else {
		# print STDERR "Filtered: $s\n";
	}
}


#################################################################################
# The severity functions
#################################################################################
# 0 => 'EMERGE', 1 => 'ALERT', 2 => 'CRITICAL', 3 => 'ERROR', 4 => 'WARNING', 5 => 'OK', 6 => 'INFO', 7 => 'DEBUG'
sub DEB
{
	my $self = shift;
	my ($s)=@_;
	$self->write(7, $s);
}

sub INF
{
	my $self = shift;
	my ($s)=@_;
	$self->write(6, $s);
}

sub OK
{
	my $self = shift;
	my ($s)=@_;
	$self->write(5, $s);
}

sub WARN
{
	my $self = shift;
	my ($s)=@_;
	$self->write(4, $s);
}

sub ERR
{
	my $self = shift;
	my ($s)=@_;
	$self->write(3, $s);
}

sub CRIT
{
	my $self = shift;
	my ($s)=@_;
	$self->write(2, $s);
}
sub ALERT
{
	my $self = shift;
	my ($s)=@_;
	$self->write(1, $s);
}
sub EMERGE
{
	my $self = shift;
	my ($s)=@_;
	$self->write(0, $s);
}

sub LOGSTART
{
	my $self = shift;
	my ($s)=@_;
	# print STDERR "Logstart -->\n";
	$self->write(-1, "================================================================================");
	$self->write(-1, "<LOGSTART>" . LoxBerry::System::currtime . " TASK STARTED");
	$self->write(-1, "<LOGSTART>" . $s);
}

sub LOGEND
{
	my $self = shift;
	my ($s)=@_;
	$self->write(-1, "<LOGEND>" . $s);
	$self->write(-1, "<LOGEND>" . LoxBerry::System::currtime . " TASK FINISHED");
	$self->DESTROY;
}



## Sets this log object the default object 
sub default
{
	my $self = shift;
	$LoxBerry::Log::mainobj = $self;
}


# our $AUTOLOAD;
# sub AUTOLOAD {
	# my $self = shift;
	# # Remove qualifier from original method name...
	# my $called =  $AUTOLOAD =~ s/.*:://r;
	# # Is there an attribute of that name?
	# Carp::carp "No such attribute: $called"
		# unless exists $self->{$called};
	# # If so, return it...
	# return $self->{$called};
# }

sub DESTROY { 
	my $self = shift;
	if ($self->{"_FH"}) {
		close $self->{"_FH"};
	}
	if ($LoxBerry::Log::mainobj == $self) {
		# Reset default object
		undef $LoxBerry::Log::mainobj;
	};
	# print STDERR "Desctuctor closed file.\n";
} 


##################################################################
##################################################################
# NOTIFICATION FUNCTIONS (notify)

my @notifications;
my $content_was_read;
my $notifications_error;
my $notifications_ok;
our $notification_dir = $LoxBerry::System::lbsdatadir . "/notifications";

# PUBLIC FUNCTION
sub notify
{
	
	my ($package, $name, $message, $error) = @_;
	
	print STDERR "notify --->\n" if ($DEBUG);
	
	my $severity;
	if ($error) {
		$severity = 3;
	} else {
		$severity = 6;
	}
	
	# SQLite interface
	require DBI;
	my $dbh;
	
	$dbh = notify_init_database();
	print STDERR "notify: Could not init database.\n" if (! $dbh);
	return undef if (! $dbh);
	
	# Build hash
	my %data = ( 
		PACKAGE => $package,
		NAME => $name,
		MESSAGE => $message,
		SEVERITY => $severity,
	);
	
	if ($LoxBerry::System::lbpplugindir) {
		print STDERR "   Detected plugin notification\n" if ($DEBUG);
		$data{_ISPLUGIN} = 1;
	} else {
		print STDERR "   Detected system notification\n" if ($DEBUG);
		$data{_ISSYSTEM} = 1;
	}
	
	notify_insert_notification($dbh, \%data);
	notify_send_mail(\%data);
	
	print STDERR "<--- notify\n" if ($DEBUG);

}

# PUBLIC FUNCTION
sub notify_ext
{
	print STDERR "notify_ext --->\n" if ($DEBUG);
	
	# SQLite interface
	require DBI;
	my $dbh;
	
	my $data = shift;
	
	$dbh = notify_init_database();
	print STDERR "notify_ext: Could not init database.\n" if (! $dbh);
	return undef if (! $dbh);
	
	if (! $data->{_ISPLUGIN} && ! $data->{_ISSYSTEM}) {
		if ($LoxBerry::System::lbpplugindir) {
			print STDERR "   Detected plugin notification\n" if ($DEBUG);
			$data->{_ISPLUGIN} = 1;
		} else {
			print STDERR "   Detected system notification\n" if ($DEBUG);
			$data->{_ISSYSTEM} = 1;
		}
	}
	notify_insert_notification($dbh, $data);
	notify_send_mail($data);
	
	print STDERR "<--- notify_ext finished\n" if ($DEBUG);

}


# INTERNAL FUNCTIONS
sub notify_init_database
{

	my $dbfile = $LoxBerry::System::lbsdatadir . "/notifications_sqlite.dat";
	
	my $dbh;
	my $dores;
	
	$dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","") or 
		do {
			print STDERR "notify_init_database connect: $DBI::errstr\n";
			return undef;
			};
	
	$dbh->do("CREATE TABLE IF NOT EXISTS notifications (
				PACKAGE VARCHAR(255) NOT NULL,
				NAME VARCHAR(255) NOT NULL,
				MESSAGE TEXT,
				SEVERITY INT,
				timestamp DATETIME NOT NULL,
				notifykey INTEGER PRIMARY KEY 
			)") or 
		do {
			print STDERR "notify_init_database create table notifications: $DBI::errstr\n";
			return undef;
			};

	$dbh->do("CREATE TABLE IF NOT EXISTS notifications_attr (
				keyref INTEGER NOT NULL,
				attrib VARCHAR(255) NOT NULL,
				value VARCHAR(255),
				PRIMARY KEY ( keyref, attrib )
				)") or
		do {
			print STDERR "notify_init_database create table notifications_attr: $DBI::errstr\n";
			return undef;
		};
	
	return $dbh;

}

# INTERNAL FUNCTION
sub notify_insert_notification
{
	
	my $dbh = shift;
	my %p = %{shift()};
		
	# print STDERR "Package: " . $p{'package'} . "\n";
	
	# Check mandatory fields
	Carp::croak "Create notification: No PACKAGE defined\n" if (! $p{PACKAGE});
	Carp::croak "Create notification: No NAMEdefined\n" if (! $p{NAME});
	Carp::croak "Create notification: No MESSAGE defined\n" if (! $p{MESSAGE});
	Carp::croak "Create notification: No SEVERITY defined\n" if (! $p{SEVERITY});

	# Start transaction
	
	$dbh->do("BEGIN TRANSACTION;"); 
	
	# Insert main notification
	my $sth = $dbh->prepare('INSERT INTO notifications (PACKAGE, NAME, MESSAGE, SEVERITY, timestamp) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP);');
	$sth->execute($p{PACKAGE}, $p{NAME}, $p{MESSAGE} , $p{SEVERITY}) or 
		do {
			Carp::croak "Error inserting notification: $DBI::errstr\n";
			return undef;
		};
	
	my $id = $dbh->sqlite_last_insert_rowid();
	
	# Process further attributes
	
	my $sth2;
	$sth2 = $dbh->prepare('INSERT INTO notifications_attr (keyref, attrib, value) VALUES (?, ?, ?);');
	
	for my $key (keys %p) {
		next if ($key eq 'PACKAGE' or $key eq 'NAME' or $key eq 'MESSAGE' or $key eq 'SEVERITY');
		$sth2->execute($id, $key, $p{$key});
	}

	$dbh->do("COMMIT;") or
		do {
			print STDERR "notify: commit failed: $DBI::errstr\n";
			return undef;
		};
	
	return "Success";
	
	$sth2->execute($id, 'logfile', 'This is the log');
	$sth2->execute($id, 'level', 5);

}

# INTERNAL FUNCTION
sub notify_send_mail
{
	my %p = %{shift()};
	
	my $subject;
	my $message;
	my %mcfg;
	
	return if ($notifymailerror);
	
	Config::Simple->import_from("$LoxBerry::System::lbsconfigdir/mail.cfg", \%mcfg) or return;

	return if ($p{SEVERITY} != 3 && $p{SEVERITY} != 6);
	return if (! LoxBerry::System::is_enabled($mcfg{'NOTIFICATION.MAIL_SYSTEM_ERRORS'}) && $p{_ISSYSTEM} && $p{SEVERITY}  == 3);
	return if (! LoxBerry::System::is_enabled($mcfg{'NOTIFICATION.MAIL_SYSTEM_INFOS'}) && $p{_ISSYSTEM} && $p{SEVERITY}  == 6);
	return if (! LoxBerry::System::is_enabled($mcfg{'NOTIFICATION.MAIL_PLUGIN_ERRORS'}) && $p{_ISPLUGIN} && $p{SEVERITY}  == 3);
	return if (! LoxBerry::System::is_enabled($mcfg{'NOTIFICATION.MAIL_PLUGIN_INFOS'}) && $p{_ISPLUGIN} && $p{SEVERITY}  == 6);
	
	my $hostname = LoxBerry::System::lbhostname();
	my $friendlyname = LoxBerry::System::lbfriendlyname();
	$friendlyname = defined $friendlyname ? $friendlyname : $hostname;
	$friendlyname .= " LoxBerry";
	
	my $status = $p{SEVERITY} == 3 ? "Error" : "Info";
	
	if ($p{_ISSYSTEM}) {
		# Camel-case Package and Name
		my $package = $p{PACKAGE};
		$package =~  s/([^\s\w]*)(\S+)/$1\u\L$2/g;
		my $name = $p{NAME};
		$name =~  s/([^\s\w]*)(\S+)/$1\u\L$2/g;
		
		$subject = "$friendlyname $status in $package $name";
		$message = $p{MESSAGE} . "\n\n";
		$message .= "$friendlyname (http://$hostname:" . LoxBerry::System::lbwebserverport() . "/)";
	}
	else 
	{
		my %plugin = LoxBerry::System::plugindata($p{PACKAGE});
		my $plugintitle = $plugin{PLUGINDB_TITLE};
		
		$subject = "$friendlyname $status in $plugintitle";
		$message = $p{MESSAGE} . "\n\n";
		$message .= "$friendlyname (http://$hostname:" . LoxBerry::System::lbwebserverport() . "/)";
	}

	my $bins = LoxBerry::System::get_binaries(); 
	my $mailbin = $bins->{MAIL};
	my $email = $mcfg{'SMTP.EMAIL'};

	my $result = qx(echo "$message" | $mailbin -a "From: $email" -s "$subject" -v $email 2>&1);
	my $exitcode  = $? >> 8;
	if ($exitcode != 0) {
		$notifymailerror = 1; # Prevents loops
		my %SL = LoxBerry::System::readlanguage(undef, undef, 1);
		notify("mailserver", "mailerror", $SL{'MAILSERVER.NOTIFY_MAIL_ERROR'}, "error");
		print STDERR "Error sending email notification - Error $exitcode:\n";
		print STDERR $result . "\n";
	} 
}


################################################################
# get_notifications
# Input: (optional) specific notification event filter
# Output: Hash with notifications
################################################################
# PUBLIC FUNCTION
sub get_notifications
{
	# print STDERR "get_notifications called.\n" if ($DEBUG);
	my ($package, $name) = @_;

	print STDERR "--> get_notifications\n" if ($DEBUG);
	
	# SQLite interface
	require DBI;
	my $dbh = notify_init_database();
	print STDERR "get_notifications: Could not init database\n" if (! $dbh);
	return undef if (! $dbh);
	
	my $qu;
	$qu = "SELECT * FROM notifications ";
	$qu .= "WHERE " if ($package);
	$qu .= "PACKAGE = '$package' AND NAME = '$name' " if ($package && $name);
	$qu .= "PACKAGE = '$package' " if ($package && !$name);
	$qu .= "ORDER BY timestamp DESC ";
	print STDERR "   Query: $qu\n" if ($DEBUG);
	
	
	my $notifhr = $dbh->selectall_hashref($qu, "timestamp");
	
	my @notifications;
	
	foreach my $key (reverse sort keys %$notifhr ) {
		my %notification;
		
		my $dateobj = Time::Piece->strptime(${$notifhr}{$key}{'timestamp'}, "%Y-%m-%d %H:%M:%S");
		my $contenthtml = ${$notifhr}{$key}{'MESSAGE'};
		$contenthtml =~ s/\n/<br>\n/g;
		$contenthtml = HTML::Entities::encode_entities($contenthtml, '<>&"');
		
		$notification{'DATEISO'} = $dateobj->datetime;
		$notification{'DATESTR'} = $dateobj->strftime("%d.%m.%Y %H:%M");
		$notification{'PACKAGE'} = ${$notifhr}{$key}{'PACKAGE'};
		$notification{'NAME'} = ${$notifhr}{$key}{'NAME'};
		$notification{'SEVERITY'} = ${$notifhr}{$key}{'SEVERITY'};
		$notification{'KEY'} = ${$notifhr}{$key}{'notifykey'};
		$notification{'CONTENTRAW'} =  ${$notifhr}{$key}{'MESSAGE'};
		$notification{'CONTENTHTML'} =  $contenthtml;
		
		my $qu_attr = "SELECT * FROM notifications_attr WHERE keyref = '${$notifhr}{$key}{'notifykey'}';";
		my @attribs = $dbh->selectall_array($qu_attr);
		if (@attribs) {
			foreach my $attrib (@attribs) {
				$notification{@$attrib[1]} =  @$attrib[2];
				# print STDERR "Attrib: 0:" . @$attrib[0] . " 1:" . @$attrib[1] . " 2:" . @$attrib[2] . "\n";
			}
		}
		
		push(@notifications, \%notification);

	}
	
	return @notifications;
}

# sub get_notifications_with_content
# {
	# my ($package, $name, $latest) = @_;
	# my @filtered = LoxBerry::Log::get_notifications($package, $name, $latest, undef, 1);
	# return @filtered;
# }

# Retuns an array with the number of notifications
# PUBLIC FUNCTION
sub get_notification_count
{
	my ($package, $name, $latest) = @_;
	#my ($notification_error, $notification_ok, $notification_sum) = LoxBerry::Log::get_notifications($package, $name, $latest, 1);
	
	print STDERR "get_notification_count -->\n" if ($DEBUG);
	
	# SQLite interface
	require DBI;
	my $dbh = notify_init_database();
	return undef if (! $dbh);

	my $qu;
	my @resinf;
	my @reserr;
	
	$qu = "SELECT count(*) FROM notifications ";
	$qu .= "WHERE " if ($package);
	$qu .= "PACKAGE = '$package' AND NAME = '$name' AND " if ($package && $name);
	$qu .= "PACKAGE = '$package' AND " if ($package && !$name);
	my $querr = $qu . "SEVERITY = 3;";
	my $quinf = $qu . "SEVERITY = 6;";
	# print STDERR "Error Query: $querr\n" if ($DEBUG);
	# print STDERR "Info Query: $quinf\n" if ($DEBUG);
	my ($notification_error) = $dbh->selectrow_array($querr);
	my ($notification_ok) = $dbh->selectrow_array($quinf);
		
	print STDERR "   Error Count: $notification_error\n" if ($DEBUG);
	print STDERR "   Info Count: $notification_ok\n" if ($DEBUG);
	print STDERR "<-- get_notification_count\n" if ($DEBUG);
	
	return $notification_error, $notification_ok, ($notification_error+$notification_ok);

}
# PUBLIC FUNCTION
sub delete_notifications
{
	my ($package, $name, $ignorelatest) = @_;
	print STDERR "delete_notifications -->\n" if ($DEBUG);
	print STDERR "   No PACKAGE defined. Return undef\n<-- delete_notifications\n" if (!$package && $DEBUG);
	return undef if (!$package);
	
	# SQLite interface
	require DBI;
	my $dbh = notify_init_database();
	return undef if (! $dbh);

	my $qu;
	my @resinf;
	my @reserr;
	
	$dbh->do("BEGIN TRANSACTION;"); 
	
	$qu = "SELECT notifykey FROM notifications ";
	$qu .= "WHERE " if ($package || $name || $ignorelatest);
	$qu .= "PACKAGE = '$package' AND NAME = '$name' " if ($package && $name);
	$qu .= "PACKAGE = '$package' " if ($package && !$name);
	if ($ignorelatest) {
		my $qu_latest = $qu . "ORDER BY timestamp DESC LIMIT 1;"; 
		my ($latest) = $dbh->selectrow_array($qu_latest);
		$qu .= "AND " if ($package && $latest);
		$qu .= "notifykey <> $latest " if ($package && $latest);
		print STDERR "   Key to keep: $latest\n" if ($DEBUG);
	}
	$qu .=";";
	#  print STDERR "Select Keys to delete query: $qu\n";
	my @keylist = $dbh->selectall_array($qu);
	my $number_to_delete = scalar @keylist;
	print STDERR "   Number of elements to delete: $number_to_delete\n" if ($DEBUG);
	if ($number_to_delete < 1) {
		
		print STDERR "   Nothing to do. Rollback and returning.\n<--- delete_notifications\n";
		$dbh->do("ROLLBACK;");
		return;
	}
	
	my $deletelist;
	foreach my $key (@keylist) {
		$deletelist .= "@$key[0], ";
	}
	$deletelist = LoxBerry::System::trim($deletelist);
	$deletelist =~ s/,$//;
	print STDERR "   Deletelist: $deletelist\n" if ($DEBUG);
	$dbh->do("DELETE FROM notifications_attr WHERE keyref IN ($deletelist);");
	$dbh->do("DELETE FROM notifications WHERE notifykey IN ($deletelist);");
	
	print STDERR "   Commit\n" if ($DEBUG);
	$dbh->do("COMMIT;"); 
	
	print STDERR "<--- delete_notifications\n" if ($DEBUG);
	
}

sub delete_notification_key
{
	my ($key) = @_;
	print STDERR "delete_notification_key -->\n" if ($DEBUG);
	print STDERR "   No Key defined. Return undef\n<-- delete_notification_key\n" if (!$key && $DEBUG);
	return undef if (!$key);
	
	# SQLite interface
	require DBI;
	my $dbh = notify_init_database();
	return undef if (! $dbh);

	$dbh->do("BEGIN TRANSACTION;"); 
	$dbh->do("DELETE FROM notifications_attr WHERE keyref = $key;");
	$dbh->do("DELETE FROM notifications WHERE notifykey = $key;");
	
	print STDERR "   Commit\n" if ($DEBUG);
	$dbh->do("COMMIT;"); 
	
	print STDERR "<--- delete_notification_key\n" if ($DEBUG);
	
}

# sub notification_content
# {
	# my ($key) = @_;
	# my $notifyfile = "$notification_dir/$key";
	# open (my $fh, "<" , $notifyfile) or return undef; 
	# my $content = <$fh>;
	# close ($fh);
	# my $contenthtml = $content;
	# $contenthtml =~ s/\n/<br>\n/g;
	# $contenthtml = HTML::Entities::encode_entities($contenthtml, '<>&"');
	# print STDERR "Contentraw: $content ContentHTML: $contenthtml\n" if ($DEBUG);
	# return $content, $contenthtml;
# }

sub get_notifications_html
{
	
	my %p = @_;
	my ($package, $name, $type, $buttons) = @_;
	
	print STDERR "get_notifications_html --->\n" if ($DEBUG);
	
	$p{package} = $package if ($package);
	$p{name} = $name if ($name);
	$p{buttons} = $buttons if ($buttons);
	
	$p{error} = 1 if (!$type || $type == 2 || $type eq 'all' || $type eq 'err' || $type eq 'error' || $type eq 'errors');
	$p{info} = 1 if (!$type || $type == 1 || $type eq 'all' || $type eq 'inf' || $type eq 'info' || $type eq 'infos');
		
	my @notifs = LoxBerry::Log::get_notifications($package, $name);
	
	if ($DEBUG) {
		print STDERR "   Parameters used:\n";
		print STDERR "      package: $p{package}\n";
		print STDERR "      name: $p{name}\n";
		print STDERR "      buttons: $p{buttons}\n";
		print STDERR "      error: $p{error}\n";
		print STDERR "      info: $p{info}\n";
	}
		
	if (! @notifs) {
		print STDERR "<--- No notifications found. Returning nothing.\n" if ($DEBUG);
		return;
	}
	
	my @notify_html;
	my $all_notifys;
	
	my $randval = int(rand(30000));
	
	foreach my $not (@notifs) {
		# Don't show info when errors are requested
		print STDERR "Notification: $not->{SEVERITY} $not->{DATESTR} $not->{PACKAGE} $not->{NAME} $not->{CONTENTRAW}\n" if ($DEBUG);
		
		
		if ( $not->{SEVERITY} == 3 && ! $p{error} ) {
			print STDERR "Skipping notification - is error but info requested\n" if ($DEBUG);
			next;
		}
		# Don't show errors when infos are requested
		if ( $not->{SEVERITY} == 6 && ! $p{error} ) {
			print STDERR "Skipping notification - is info but error requested\n" if ($DEBUG);
			next;
		}
		
		my $logfilepath;
		if ( $not->{LOGFILE} ) {
			$logfilepath = $not->{LOGFILE};
			$logfilepath =~ s/^$LoxBerry::System::lbhomedir\///;
		}
		
		
		my $notif_line;
		$notif_line .= 	"<div style='display:table-row;' class='notifyrow$randval' id='notifyrow$not->{KEY}'>";
		$notif_line .= 	'<div style="display:table-cell; vertical-align: middle; width:30px; padding:10px;">';
		if ($not->{SEVERITY} == 6) {
			$notif_line .= '<img src="/system/images/notification_info_small.svg">';
		} elsif ($not->{SEVERITY} == 3) {
			$notif_line .= '<img src="/system/images/notification_error_small.svg">';
		}
		$notif_line .= "</div>";
		$notif_line .= "<div style='vertical-align: middle; width:80%; display: table-cell; '><b>$not->{DATESTR}:</b> $not->{CONTENTRAW}</div>";
		$notif_line .= "<div style='vertical-align: middle; width:20%; display: table-cell; align:right; text-align: right;'>";
		$notif_line .= '<a class="btnlogs" data-role="button" href="/admin/system/tools/logfile.cgi?logfile=' . $logfilepath . '&header=html&format=template" target="_blank" data-inline="true" data-mini="true" data-icon="arrow-d">Logfile</a>' if ($logfilepath);
		$notif_line .= "<a href='#' class='notifdelete' id='notifdelete$not->{KEY}' data-delid='$not->{KEY}' data-role='button' data-icon='delete' data-iconpos='notext' data-inline='true' data-mini='true'>Dismiss</a>";
		$notif_line .= "</div>";
		# print STDERR $notif_line if ($DEBUG);
		$notif_line .= "</div>";
		$all_notifys .= $notif_line;
		push (@notify_html, $notif_line);
	}
	
	require HTML::Template;
	
	our $maintemplate = HTML::Template->new(
				filename => "$LoxBerry::System::lbstemplatedir/get_notification_html.html",
				global_vars => 1,
				loop_context_vars => 1,
				die_on_bad_params=> 0,
				%LoxBerry::System::htmltemplate_options,
				);
	$maintemplate->param( 'NOTIFICATIONS' => $all_notifys);
	$maintemplate->param( 'RAND' => $randval );
	#print STDERR 
	return $maintemplate->output();
	
	
}

#####################################################
# Parse yyyymmdd_hhmmss date to date object
#####################################################
sub parsedatestring 
{
	my ($datestring) = @_;
	
	my $dt;
	eval {
		$dt = Time::Piece->strptime($datestring, "%Y%m%d_%H%M%S");
	};
	# LOGDEB "parsedatestring: Calculated date/time: " . $dt->strftime("%d.%m.%Y %H:%M");
	return $dt;
}

# # INTERNAL function read_notificationlist
# sub read_notificationlist
# {
	# my ($getcontent) = @_;
		
	# opendir( my $DIR, $notification_dir );
	# my @files = sort {$b cmp $a} readdir($DIR);
	# my $direntry;
	# my $notifycount;
	# @notifications = ();
		
	# while ( my $direntry = shift @files ) {
		# next if $direntry eq '.' or $direntry eq '..' or $direntry eq '.dummy';
		# print STDERR "Direntry: $direntry\n" if ($DEBUG);
		# my $notstr = substr($direntry, 16, rindex($direntry, '.')-16);
		# my ($package, $name, $severity) = split(/_/, $notstr);
		# my $notdate = substr($direntry, 0, 15);
		# # LOGDEB "Log type: $nottype  Date: $notdate";
		# my $dateobj = LoxBerry::Log::parsedatestring($notdate);
		# next if (!$dateobj); 
		# my %notification;
		# $notifycount++;
		# if (lc($severity) eq 'err') {
			# $notifications_error++;
		# } else {
			# $notifications_ok++;
		# }
		# $notification{'PACKAGE'} = lc($package);
		# $notification{'NAME'} = lc($name);
		# $notification{'SEVERITY'} = lc($severity);
		# $notification{'DATEOBJ'} = $dateobj;
		# $notification{'DATESTR'} = $dateobj->strftime("%d.%m.%Y %H:%M");
		# $notification{'KEY'} = $direntry;
		# $notification{'FULLPATH'} = "$notification_dir/$direntry";
		# ($notification{'CONTENTRAW'}, $notification{'CONTENTHTML'}) = notification_content($notification{'KEY'}) if ($getcontent);
		
		# push(@notifications, \%notification);
	# }
	# # return @notifications;
	# closedir $DIR;
	# $content_was_read = 1;
	# print STDERR "Number of elements: " . scalar(@notifications) . "\n" if ($DEBUG);
# }

# INTERNAL FUNCTION
sub get_severity
{
	my ($sevstr) = @_;
	$sevstr = lc $sevstr;
	
	# Ordered by most possible occurrency
	
	# 3
	my @error = ("3", "err", "error", "logerr");
	return 3 if ( grep( /^$sevstr$/, @error ) );
	
	# 6
	my @info = ("6", "inf", "info", "loginf");
	return 6 if ( grep( /^$sevstr$/, @info ) );
	
	# 4
	my @warning = ("4", "warn", "warning", "logwarn");
	return 4 if ( grep( /^$sevstr$/, @warning ) );
	
	# 5
	my @ok = ("5", "ok", "logok");
	return 5 if ( grep( /^$sevstr$/, @ok ) );

	# 7
	my @debug = ("7", "debug", "deb", "logdeb", "logdebug");
	return 7 if ( grep( /^$sevstr$/, @debug ) );

	# 2
	my @critical = ("2", "critical", "crit", "critic", "logcrit");
	return 2 if ( grep( /^$sevstr$/, @critical ) );

	# 1
	my @alert = ("1", "alert", "logalert");
	return 1 if ( grep( /^$sevstr$/, @alert ) );

	# 0
	my @emerge = ("0", "emerg", "emerge", "emergency", "logemerge");
	return 0 if ( grep( /^$sevstr$/, @emerge ) );

	return undef;
}

##################################################################
##################################################################
##  PACKAGE MAIN

package main;

####################################################
# Exported helpers
####################################################
sub LOGDEB 
{
	$LoxBerry::Log::mainobj->DEB(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGINF 
{
	$LoxBerry::Log::mainobj->INF(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGOK 
{
	$LoxBerry::Log::mainobj->OK(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGWARN
{
	$LoxBerry::Log::mainobj->WARN(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGERR
{
	$LoxBerry::Log::mainobj->ERR(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGCRIT 
{
	$LoxBerry::Log::mainobj->CRIT(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGALERT 
{
	$LoxBerry::Log::mainobj->ALERT(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGEMERGE 
{
	$LoxBerry::Log::mainobj->EMERGE(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGSTART 
{
	$LoxBerry::Log::mainobj->LOGSTART(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGEND 
{
	$LoxBerry::Log::mainobj->LOGEND(@_); # or Carp::carp("No default object set for exported logging functions.");
}


#####################################################
# Finally 1; ########################################
#####################################################
1;
