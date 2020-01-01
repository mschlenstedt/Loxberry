# Please increment version number on EVERY change
# Major.Minor represents LoxBerry version (e.g. 0.3.1.12 = LoxBerry V0.3.1 the 12th change)

use strict;
use Carp;
use LoxBerry::System;
# use Time::Piece;
# use HTML::Entities;
# use JSON;
# use File::Basename;
# use File::Path;

################################################################
package LoxBerry::Log;
our $VERSION = "2.0.0.4";
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
my @db_attribute_exclude_list = qw ( package name LOGSTART LOGEND LASTMODIFIED filename dbh _FH dbkey loxberry_uid loxberry_gid _plugindb_timestamp);

################################################################
## Constructor
## 	Params [square brackets mean optional]
## See https://www.loxwiki.eu/x/pQHgAQ
##################################################################

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
				dbkey => $params{dbkey},
				nosession => $params{nosession},
	};
	
	bless $self, $class;
	
	if ($self->{autoraise} eq "") {
		$self->{autoraise} = 1;
	}
	
	if ( LoxBerry::System::is_enabled($self->{nosession}) ) {
		$self->{append} = 1;
	}
	
	
	
	# If nofile is given, we don't need to do any smart things
	if(!$self->{nofile}) {
		
		# If a dbkey was given, recreate logging session
		if($params{dbkey}) {
			my $recreatestate = $self->log_db_recreate_session_by_id();
			return undef if (!$recreatestate);
			$self->{append} = 1;
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
		
		if (!$self->{logdir} && !$self->{filename} && -e $LoxBerry::System::lbplogdir) {
			$self->{logdir} = $LoxBerry::System::lbplogdir;
		}
		# print STDERR "2. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
		if ($self->{logdir} && !$self->{filename}) {
			$self->{filename} = $self->{logdir} . "/" . LoxBerry::System::currtime('filehires') . "_" . $self->{name} . ".log";
			# print STDERR "3. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
				
		} elsif (!$self->{filename}) {
			# print STDERR "4. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
			if ($LoxBerry::System::lbplogdir && -e $LoxBerry::System::lbplogdir) {
				$self->{filename} = "$LoxBerry::System::lbplogdir/" . currtime('filehires') . "_" . $self->{name} . ".log";
				# print STDERR "5. logdir: " . $self->{logdir} . " filename: " . $self->{filename} . "\n";
				
			
			} else {
				Carp::croak "Cannot determine plugin log directory";
			}
		} 
		if (!$self->{filename}) {
			Carp::croak "Cannot smartly detect where your logfile should be placed. Check your parameters.";
		}
	}
	# Get loglevel
	# print STDERR "Log.pm: Loglevel is " . $self->{loglevel} . "\n";
	if (!defined $self->{loglevel}) {
		my $plugindata = LoxBerry::System::plugindata($self->{package});
		if ($plugindata and defined $plugindata->{PLUGINDB_LOGLEVEL}) {
			$self->{loglevel} = $plugindata->{'PLUGINDB_LOGLEVEL'};
		} else {
			$self->{loglevel} = 7;
			$self->{loglevel_is_static} = 1;
		}
	} else {
		$self->{loglevel_is_static} = 1;
	}
	
	# print STDERR "Log.pm: Loglevel is " . $self->{loglevel} . "\n";
	# print STDERR "filename: " . $self->{filename} . "\n";
	
	if (!$self->{append} and !$self->{nofile}) {
		unlink $self->{filename};
		require File::Basename;
		my $dir = File::Basename::dirname($self->{filename});
		if (! -d $dir) {
			require File::Path;
			File::Path::make_path($dir);
		}
	}
	
	if (!$LoxBerry::Log::mainobj) {
		$LoxBerry::Log::mainobj = $self;
	}
	
	# SQLite init

	if( LoxBerry::System::is_enabled($params{nosession}) ) {
		$self->{dbh} = log_db_init_database();
		$self->{dbkey} = $self->log_db_get_session_by_filename();
	} elsif($self->{append} && !$self->{nofile}) {
		$self->{dbh} = log_db_init_database();
		$self->{dbkey} = log_db_query_id($self->{dbh}, $self);
		# print STDERR "Appending to file $self->{filename} with key $self->{dbkey}\n";
	}
	

	
	
	return $self;
}

sub loglevel 
{
	my $self = shift;
	my $loglevel = shift;
	if (defined $loglevel && $loglevel >= 0 && $loglevel <= 7) {
		$self->{loglevel} = $loglevel;
		$self->{loglevel_is_static} = 1;
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

# Legacy for LB <1.2.5
sub filehandle
{
	my $self = shift;
	if ($self->{'_FH'}) {
		return $self->{'_FH'};
	} else {
		$self->open();
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

sub dbkey
{
	my $self = shift;
	if ($self->{dbkey}) {
		return $self->{dbkey};
	}
}

sub open
{
	my $self = shift;
	my $writetype = ">>";
	my $fh;

	eval {
		open($fh, $writetype, $self->{filename});
		$self->{'_FH'} = $fh if($fh);
	};
	if ($@) {
		print STDERR "Cannot open logfile " . $self->{filename} . " (writetype " . $writetype . "): $@";
		return;
	}
	eval {
		if(!$self->{loxberry_uid}) {
			my (undef,undef,$uid,$gid) = getpwnam('loxberry');
			$self->{loxberry_uid} = $uid;
			$self->{loxberry_uid} = $gid;
		}
		chown $self->{loxberry_uid}, $self->{loxberry_uid}, $fh;
		chmod 0666, $fh;
	};
}

sub close
{
	my $self = shift;
	close $self->{'_FH'} if $self->{'_FH'};
	undef $self->{'_FH'};
	return $self->{filename};
}

sub addtime
{
	my $self = shift;
	my $param = shift;
	if ($param == 0) {
		undef $self->{addtime};
	} elsif ($param == 1) {
		$self->{addtime} = 1;
	}
	return $self->{addtime};
}

sub logtitle
{
	my $self = shift;
	my $title = shift;
	if ($title) {
		$self->{LOGSTARTMESSAGE} = $title;
		if (!$self->{nofile} and $self->{dbkey} and $self->{dbh}) {
			eval {
				my $dbh = $self->{dbh};
				$dbh->do("UPDATE logs_attr SET value = '$self->{LOGSTARTMESSAGE}' WHERE keyref = $self->{dbkey} AND attrib = 'LOGSTARTMESSAGE';");
			};
		}
	}
	
	return $self->{LOGSTARTMESSAGE};
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
	
	# Check if the database entry is still present
	if (!$self->{_next_db_check} or time > $self->{_next_db_check}) {
		print STDERR "write: DB session check called\n" if ($DEBUG);
		if(!$self->{dbh}) {
			$self->{dbh} = log_db_init_database();
		}
		log_db_recreate_session($self->{dbh}, $self);
		$self->{_next_db_check} = time+120;
	}
	
	# print STDERR "Severity: $severity / Loglevel: " . $self->{loglevel} . "\n";
	# print STDERR "Log: $s\n";
	# Do not log if loglevel is lower than severity
	# print STDERR "--> write \n";
	# print STDERR "    autoraise\n";
	
	# Change loglevel if it was changed in the UI aka PluginDB
	if( !$self->{loglevel_is_static} and LoxBerry::System::plugindb_changed_time() != $self->{_plugindb_timestamp} ) {
		$self->{_plugindb_timestamp} = LoxBerry::System::plugindb_changed_time();
		my $newloglevel = LoxBerry::System::pluginloglevel($self->{package});
		if ( defined $newloglevel and $newloglevel >= 0 and $newloglevel <=7 and $newloglevel != $self->{loglevel} ) {
			my $oldloglevel = $self->{loglevel};
			$self->{loglevel} = $newloglevel;
			$self->write(-1, "<INFO> User changed loglevel from $oldloglevel to $newloglevel");
		}
	}
	
	
	if ($severity <= 2 && $severity >= 0 && $self->{loglevel} < 6 && $self->{autoraise} == 1) {
		# print STDERR "    autoraise to loglevel 6\n";
		$self->{loglevel} = 6;
		$self->{loglevel_is_static} = 1;
	}
	
	if ((!defined($self->{STATUS}) or $severity < $self->{STATUS}) and $severity >= 0) {
		# Remember highest severity sent
		$self->{STATUS} = "$severity";
	}
	
	if($severity >= 0 and $severity <= 4) {
		# Store all warnings, errors, etc. in a string
		$self->{ATTENTIONMESSAGES} .= "\n" if ($self->{ATTENTIONMESSAGES});
		$self->{ATTENTIONMESSAGES} .= '<' . $severitylist{$severity} . '> ' . $s;
	}
	
	if ($self->{loglevel} != 0 and $severity <= $self->{loglevel} or $severity < 0) {
		#print STDERR "Not filtered.\n";
		if(!$self->{'_FH'}) {
			$self->open();
		}
		my $fh = $self->{'_FH'};
		my $string;
		my $currtime = "";
		
		if ($self->{addtime} and $severity > -2) {
			$currtime = LoxBerry::System::currtime('hrtimehires') . " ";
		}
		if ($severity == 7 or $severity < 0) {
			$string = $currtime . $s . "\n"; 
		} else {
			$string = $currtime . '<' . $severitylist{$severity} . '> ' . $s . "\n"; 
		}
		if (!$self->{nofile} && $self->{loglevel} != 0) {
			# print STDERR "   Print to file\n";
			print $fh $string if($fh);
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
	$self->close();
}

sub INF
{
	my $self = shift;
	my ($s)=@_;
	$self->write(6, $s);
	$self->close();
}

sub OK
{
	my $self = shift;
	my ($s)=@_;
	$self->write(5, $s);
	$self->close();
}

sub WARN
{
	my $self = shift;
	my ($s)=@_;
	$self->write(4, $s);
	$self->close();
}

sub ERR
{
	my $self = shift;
	my ($s)=@_;
	$self->write(3, $s);
	$self->close();
}

sub CRIT
{
	my $self = shift;
	my ($s)=@_;
	$self->write(2, $s);
	$self->close();
}
sub ALERT
{
	my $self = shift;
	my ($s)=@_;
	$self->write(1, $s);
	$self->close();
}
sub EMERGE
{
	my $self = shift;
	my ($s)=@_;
	$self->write(0, $s);
	$self->close();
}

sub LOGSTART
{
	my $self = shift;
	my ($s)=@_;
	
	# If nosession is given, only an initial header is written
	if( !LoxBerry::System::is_enabled($self->{nosession}) ) {
		
		# print STDERR "Logstart -->\n";
		$self->{LOGSTARTBYTE} = -e $self->{filename} ? -s $self->{filename} : 0;
		$self->write(-2, "================================================================================");
		$self->write(-2, "<LOGSTART> " . LoxBerry::System::currtime . " TASK STARTED");
		$self->write(-2, "<LOGSTART> " . $s);
	}
	$self->{LOGSTARTMESSAGE} = $s if ($s);	
	
	opendir(my $DIR, "$LoxBerry::System::lbsconfigdir/");
	my @is_files = grep(/is\_.*\.cfg/,readdir($DIR));
	closedir($DIR);
	
	my $is_file_str = "";
	foreach my $is_file (@is_files) {
		$is_file_str .= substr($is_file, rindex($is_file, '/')+1) . " ";
	}
	if ($is_file_str) {
		$is_file_str = "( " . $is_file_str . ")";
	}
	
	my $plugin = LoxBerry::System::plugindata($self->{package});
	
	if( !LoxBerry::System::is_enabled($self->{nosession}) or ! -e $self->{filename} ) {
		$self->write(-1, "<INFO> LoxBerry Version " . LoxBerry::System::lbversion() . " " . $is_file_str);
		$self->write(-1, "<INFO> " . $plugin->{PLUGINDB_TITLE} . " Version " . $plugin->{PLUGINDB_VERSION} ) if ($plugin);
		$self->write(-1, "<INFO> Loglevel: " . $self->{loglevel});
	}
	
	if( LoxBerry::System::is_enabled($self->{nosession})) {
		# $self->write(-2, "<INFO> " . $s);
		$self->OK($s);
	}
	
	
	if(! $self->{nofile}) {
		if(!$self->{dbh}) {
			$self->{dbh} = log_db_init_database();
		}
		
		if ( !LoxBerry::System::is_enabled($self->{nosession}) ) {
			$self->{dbkey} = log_db_logstart($self->{dbh}, $self);
		}
		
	}
	$self->close();
}

sub LOGEND
{
	my $self = shift;
	my ($s)=@_;
	
	if( !LoxBerry::System::is_enabled($self->{nosession}) ) {
		$self->write(-2, "<LOGEND> " . $s) if $s;
		$self->write(-2, "<LOGEND> " . LoxBerry::System::currtime . " TASK FINISHED");
	}
	$self->{LOGENDMESSAGE} = $s if ($s);
	
	if(!defined($self->{STATUS})) {
		# If no status was collected, let's say it's ok
		$self->{STATUS} = 5;
	}
	
	if(! $self->{nofile}) {
		if(!$self->{dbh}) {
			$self->{dbh} = log_db_init_database();
		}
		if(!$self->{dbkey}) {
			$self->{dbkey} = log_db_query_id($self->{dbh}, $self);
		}
		log_db_logend($self->{dbh}, $self);		
	}
	
	$self->{logend_called} = 1;
	$self->DESTROY();
	
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
		CORE::close $self->{"_FH"};
	}
	if ($LoxBerry::Log::mainobj == $self) {
		# Reset default object
		undef $LoxBerry::Log::mainobj;
	};	
	
	if(!$self->{nofile} and $self->{dbkey} 
		and defined $self->{STATUS} and !$self->{logend_called}) {
		if(!$self->{dbh}) {
			$self->{dbh} = log_db_init_database();
		}
		my $dbh = $self->{dbh};
		$dbh->do("INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (" . $self->{dbkey} . ", 'STATUS', '" . $self->{STATUS} . "');COMMIT;") if ($dbh);
	}
} 

################################################
# Database function for logging
################################################

# INTERNAL FUNCTIONS
sub log_db_init_database
{
	require DBI;
	
	print STDERR "log_db_init_database\n" if ($DEBUG);
	my $dbfile = $LoxBerry::System::lbhomedir . "/log/system_tmpfs/logs_sqlite.dat";
	
	my $dbh;
	my $dores;
	
	my $dbok = 1;
	my $dbierr;
	my $dbierrstr;
	
	for (my $i=1; $i <= 2; $i++) {  
	
		$dbierr = undef;
		$dbierrstr = undef;
	
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","") or 
			do {
				print STDERR "log_init_database connect: $DBI::errstr\n";
				return undef;
				};
		#$dbh->{sqlite_unicode} = 1;
		$dbh->do('PRAGMA journal_mode = wal;');
		$dbh->do('PRAGMA busy_timeout = 5000;'); 
		$dbh->do('BEGIN;');
		$dbh->do("CREATE TABLE IF NOT EXISTS logs (
					PACKAGE VARCHAR(255) NOT NULL,
					NAME VARCHAR(255) NOT NULL,
					FILENAME VARCHAR (2048) NOT NULL,
					LOGSTART DATETIME,
					LOGEND DATETIME,
					LASTMODIFIED DATETIME NOT NULL,
					LOGKEY INTEGER PRIMARY KEY 
				)") or 
			do {
				print STDERR "log_init_database create table notifications: $DBI::errstr\n";
				$dbierr = $DBI::err;
				$dbierrstr = $DBI::errstr;
				$dbh->do('ROLLBACK;');
				$dbok = 0;
				log_db_repair($dbfile, $dbh, $dbierr);
				
				};

		$dbh->do("CREATE TABLE IF NOT EXISTS logs_attr (
					keyref INTEGER NOT NULL,
					attrib VARCHAR(255) NOT NULL,
					value VARCHAR(255),
					PRIMARY KEY ( keyref, attrib )
					)") or
			do {
				print STDERR "log_db_init_database create table logs_attr: $DBI::errstr\n";
				$dbierr = $DBI::err;
				$dbierrstr = $DBI::errstr;
				$dbh->do('ROLLBACK;');
				$dbok = 0;
				log_db_repair($dbfile, $dbh, $dbierr);
			};
		
		$dbh->do('COMMIT;');
		
		if ($dbok) {
			last;
		}
	}
	
	if(!$dbok) {
		print STDERR "log_db_init_database: FAILED TO RECOVER DATABASE (Database error $dbierr - $dbierrstr)\n";
		# LoxBerry::Log::notify( "logmanager", "Log Database", "The logfile database sends an error and cannot automatically be recovered. Please inform the LoxBerry-Core team about this error:\nError $dbierr ($dbierrstr)", 'error');
		return undef;
	}
	
	eval {
		my $uid = (stat $dbfile)[4];
		my $owner = (getpwuid $uid)[0];
		if ($owner ne 'loxberry') {
			my ($login,$pass,$uid,$gid) = getpwnam('loxberry');
			chown $uid, $gid, $dbfile;
		}
	};
	
	return $dbh;

}

sub log_db_repair
{
	my ($dbfile, $dbh, $dbierror) = @_;
	print STDERR "log_db_repair: Repairing DB (Error $dbierror)\n";
	# https://www.sqlite.org/c3ref/c_abort.html
	# 11 - The database disk image is malformed
	if ($dbierror eq "11") {
		print STDERR "logdb seems to be corrupted - deleting and recreating...\n";
		$dbh->disconnect();
		unlink $dbfile;
		$dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","") or 
			do {    
				$dbh->disconnect() if ($dbh);
				return undef;
			};
	} else {
		$dbh->disconnect() if ($dbh);
		return undef;
	}
		
}

sub log_db_query_id
{
	
	my $dbh = shift;
	my %p = %{shift()};
		
	# Check mandatory fields
	Carp::cluck "log_db_query_id: No FILENAME defined\n" if (!$p{filename});
	Carp::cluck "Create DB log entry: DBH not defined\n" if (!$dbh);
	if (!$p{filename} or !$dbh) {
		return;
	}
	
	# Search filename
	my $qu = "SELECT LOGKEY FROM logs WHERE FILENAME LIKE '$p{filename}' ORDER BY LOGSTART DESC LIMIT 1;"; 
	my ($logid) = $dbh->selectrow_array($qu) or
		do {
				Carp::carp "log_db_query_id: No database entry found for given filename $p{filename}. File will be created.\n";
				return undef;
			};
	
	if ($logid) {
		return $logid;
	} else {
		print STDERR "log_db_query_id: Could not find filename $p{filename}\n" if ($DEBUG);
	}
	return;

}


sub log_db_logstart
{
	
	my $dbh = shift;
	my %p = %{shift()};
		
	# print STDERR "Package: " . $p{'package'} . "\n";
	
	# Check mandatory fields
	Carp::cluck "Create DB log entry: DBH not defined\n" if (!$dbh);
	Carp::cluck "Create DB log entry: No PACKAGE defined\n" if (! $p{package});
	Carp::cluck "Create DB log entry: No NAME defined\n" if (! $p{name});
	Carp::cluck "Create DB log entry: No FILENAME defined\n" if (! $p{filename});
	if(!$dbh or !$p{package} or !$p{name} or !$p{filename}) {
		return;
	}
	
	if (!$p{LOGSTART}) {
		require Time::Piece;
		my $t = Time::Piece->localtime;
		# my $t = localtime;
		$p{LOGSTART} = $t->strftime("%Y-%m-%d %H:%M:%S");
	}
	
	my $plugin = LoxBerry::System::plugindata($p{package});
	if ($plugin and $plugin->{PLUGINDB_TITLE}) {
		$p{_ISPLUGIN} = 1;
		$p{PLUGINTITLE} = $plugin->{PLUGINDB_TITLE};
	}
	
	# Start transaction
	$dbh->do("BEGIN TRANSACTION;"); 
	
	# Insert main attributes
	my $sth = $dbh->prepare('INSERT INTO logs (PACKAGE, NAME, FILENAME, LOGSTART, LASTMODIFIED) VALUES (?, ?, ?, ?, ?) ;');
	# print STDERR "package $p{package}, name $p{name}\n";
	$sth->execute($p{package}, $p{name}, $p{filename} , $p{LOGSTART}, $p{LOGSTART}) or 
		do {
			Carp::cluck "Error inserting log to DB: $DBI::errstr\n";
			return undef;
		};
	
	my $id = $dbh->sqlite_last_insert_rowid();
	
	# Process further attributes
	
	my $sth2;
	$sth2 = $dbh->prepare('INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (?, ?, ?);');
	
	for my $key (keys %p) {
		next if ( grep ( /^$key$/, @db_attribute_exclude_list ) or !$p{$key} );
		# print STDERR "INSERT id $id, key $key, value $p{$key}\n";
		$sth2->execute($id, $key, $p{$key});
	}

	$dbh->do("COMMIT;") or
		do {
			print STDERR "log_db_logstart: commit failed: $DBI::errstr\n";
			return undef;
		};
	
	return $id;

}

sub log_db_logend
{
	
	my $dbh = shift;
	my %p = %{shift()};
		
	# print STDERR "Package: " . $p{'package'} . "\n";
	
	# Check mandatory fields
	Carp::cluck "log_db_logend: Create DB log entry: DBH not defined\n" if (!$dbh);
	Carp::cluck "log_db_logend: No dbkey defined\n" if (!$p{dbkey});
	if (!$dbh or !$p{dbkey}) {
		return;
	}
	
	require Time::Piece;
	my $t = Time::Piece->localtime;
	my $logend = $t->strftime("%Y-%m-%d %H:%M:%S");

	
	# Start transaction
	$dbh->do("BEGIN TRANSACTION;"); 
	
	# Insert main attributes
	my $sth = $dbh->prepare('UPDATE logs set LOGEND = ?, LASTMODIFIED = ? WHERE LOGKEY = ? ;');
	$sth->execute($logend, $logend, $p{dbkey}) or 
		do {
			Carp::cluck "Error updating logend in DB: $DBI::errstr\n";
			return undef;
		};
	
	# Process further attributes
	
	my $sth2;
	$sth2 = $dbh->prepare('INSERT OR REPLACE INTO logs_attr (keyref, attrib, value) VALUES (?, ?, ?);');
	
	for my $key (keys %p) {
		next if ( grep ( /^$key$/, @db_attribute_exclude_list ) );
		$sth2->execute($p{dbkey}, $key, $p{$key});
	}

	$dbh->do("COMMIT;") or
		do {
			print STDERR "log_db_logend: commit failed: $DBI::errstr\n";
			return undef;
		};
	
	return "Success";

}

sub log_db_recreate_session_by_id
{
	my $self = shift;
	
	my $key = $self->{dbkey};
	my $dbh = log_db_init_database();
		
	if(!$dbh) {
		print STDERR "   dbh not defined. Return undef\n<-- log_db_recreate_session_by_id\n";
		return undef;
	}
	
	if(!$key) {
		print STDERR "   No logdb key defined. Return undef\n<-- log_db_recreate_session_by_id\n";
		return undef;
	}

	require DBI;
	
	# Get log object
	my $qu = "SELECT PACKAGE, NAME, FILENAME, LOGSTART, LOGEND FROM logs WHERE LOGKEY = $key LIMIT 1;";
	my $logshr = $dbh->selectall_arrayref($qu, { Slice => {} });
	if (!@$logshr) {
		print STDERR "   LOGKEY does not exist. Return undef\n<-- log_db_recreate_session_by_id\n";
		return undef;
	}
	
	# It is not possible to recover a finished session
	if (@$logshr[0]->{LOGEND}) {
		print STDERR "   LOGKEY $key found, but log session has a LOGEND (session is finished) - return undef\n";
		return undef;
	}
			
	# Get log attributes
	my $qu2 = "SELECT attrib, value FROM logs_attr WHERE keyref = $key;";
	my $logattrshr = $dbh->selectall_arrayref($qu2, { Slice => {} });
	
	## Recreate log object with data
	
	# Data from log table
	$self->{package} = @$logshr[0]->{PACKAGE} if (@$logshr[0]->{PACKAGE});
	$self->{name} = @$logshr[0]->{NAME} if (@$logshr[0]->{NAME});
	$self->{filename} = @$logshr[0]->{FILENAME} if (@$logshr[0]->{FILENAME});
	
	# Data from attribute table - loop through attributes
	foreach my $attr ( keys @$logattrshr ) {
		print STDERR "Attribute: @$logattrshr[$attr]->{attrib} / Value: @$logattrshr[$attr]->{value} \n" if ($DEBUG);
		$self->{@$logattrshr[$attr]->{attrib}} = @$logattrshr[$attr]->{value} if (!$self->{@$logattrshr[$attr]->{attrib}});
	}

	return $key;

}

sub log_db_get_session_by_filename
{
	my $self = shift;
	
	my $filename = $self->{filename};
	my $dbh = log_db_init_database();
		
	if(!$dbh) {
		print STDERR "   dbh not defined. Return undef\n<-- log_db_get_session_by_filename\n";
		return undef;
	}
	
	if(!$filename) {
		print STDERR "   No logdb key defined. Return undef\n<-- log_db_get_session_by_filename\n";
		return undef;
	}

	require DBI;
	
	# Get log object
	my $qu = "SELECT PACKAGE, NAME, FILENAME, LOGSTART, LOGEND, LOGKEY FROM logs WHERE FILENAME = '$filename' ORDER BY LOGSTART DESC LIMIT 1;";
	my $logshr = $dbh->selectall_arrayref($qu, { Slice => {} });
	if (!@$logshr) {
		print STDERR "log_db_get_session_by_filename: FILENAME has no dbkey. New key is created.\n" if ($DEBUG);
		$self->{dbkey} = log_db_logstart($self->{dbh}, $self);
		print STDERR "log_db_get_session_by_filename: New dbkey is " . $self->{dbkey} . "\n" if ($DEBUG);
	} else {
		$self->{dbkey} = @$logshr[0]->{LOGKEY};
		print STDERR "log_db_get_session_by_filename: Existing dbkey is used " . $self->{dbkey} . "\n" if ($DEBUG);
	}
	
	# Get log attributes
	my $qu2 = "SELECT attrib, value FROM logs_attr WHERE keyref = '" . $self->{dbkey} . "';";
	my $logattrshr = $dbh->selectall_arrayref($qu2, { Slice => {} });
	
	## Recreate log object with data
	
	# Data from log table
	
	# Data from attribute table - loop through attributes
	foreach my $attr ( keys @$logattrshr ) {
		print STDERR "Attribute: @$logattrshr[$attr]->{attrib} / Value: @$logattrshr[$attr]->{value} \n" if ($DEBUG);
		$self->{@$logattrshr[$attr]->{attrib}} = @$logattrshr[$attr]->{value} if (!$self->{@$logattrshr[$attr]->{attrib}});
	}

	return $self->{dbkey};

}

sub log_db_bulk_delete_logkey
{
	my ($dbh, @keys) = @_;
	if(!$dbh && $DEBUG) {
		print STDERR "   dbh not defined. Return undef\n<-- log_db_bulk_delete_logkey\n";
		return undef;
	}
	
	if(!@keys && $DEBUG) {
		print STDERR "   No Keys defined. Return undef\n<-- log_db_bulk_delete_logkey\n";
		return undef;
	}

	require DBI;
	return undef if (! $dbh);
	print STDERR "Bulk delete BEGIN TRAN\n" if ($DEBUG);
	$dbh->do("BEGIN TRANSACTION;"); 
	foreach my $key (@keys) {
		$dbh->do("DELETE FROM logs_attr WHERE keyref = $key;");
		$dbh->do("DELETE FROM logs WHERE LOGKEY = $key;");	
	}
	$dbh->do("DELETE FROM logs_attr WHERE keyref NOT IN (SELECT logkey FROM logs);");	
	
	print STDERR "Bulk delete COMMIT\n" if ($DEBUG);
	$dbh->do("COMMIT;"); 
	
}

sub log_db_delete_logkey
{
	my ($dbh, $key) = @_;
	# print STDERR "log_db_deletelogkey -->\n" if ($DEBUG);
	if(!$dbh && $DEBUG) {
		print STDERR "   dbh not defined. Return undef\n<-- log_db_deletelogkey\n";
		return undef;
	}
	
	if(!$key && $DEBUG) {
		print STDERR "   No Key defined. Return undef\n<-- log_db_deletelogkey\n";
		return undef;
	}
	
	# SQLite interface
	require DBI;
	# my $dbh = log_db_init_database();
	return undef if (! $dbh);

	$dbh->do("BEGIN TRANSACTION;"); 
	$dbh->do("DELETE FROM logs_attr WHERE keyref = $key;");
	$dbh->do("DELETE FROM logs WHERE LOGKEY = $key;");
	
	print STDERR "   Commit\n" if ($DEBUG);
	$dbh->do("COMMIT;"); 
	
	print STDERR "<--- log_db_delete_logkey\n" if ($DEBUG);
	
}

sub log_db_recreate_session
{

	my $dbh = shift;
	my $self = shift;
	my $key = $self->{dbkey};
	
	if(!$dbh) { 
		print STDERR "log_db_recreate_session: dbh not defined - Abort\n" if($DEBUG);
		return;
	}
	
	if(!$key) {
		print STDERR "log_db_recreate_session: dbkey not defined - Abort\n" if($DEBUG);
		return;
	}
	
	
	my $qu = "SELECT PACKAGE, NAME, FILENAME, LOGSTART, LOGEND FROM logs WHERE LOGKEY = $key LIMIT 1;";
	my $logshr = $dbh->selectall_arrayref($qu, { Slice => {} });
	if (@$logshr) {
		print STDERR "log_db_recreate_session: logkey exists, nothing to do\n" if($DEBUG);
		return;
	}
	
	print STDERR "log_db_recreate_session: Session does not exist in DB - creating a new session\n";
	$self->{dbkey} = log_db_logstart($self->{dbh}, $self);

}


################################################################
# get_logs
# Input: (optional) package, name
# Output: Array with hashref to log entries
################################################################
# PUBLIC FUNCTION
sub get_logs
{
	my ($package, $name, $nofilter) = @_;

	print STDERR "--> get_logs\n" if ($DEBUG);
		
	# SQLite interface
	require DBI;
	my $dbh = log_db_init_database();
	print STDERR "get_logs: Could not init database\n" if (! $dbh);
	return undef if (! $dbh);
	
	my $qu;
	$qu = "SELECT * FROM logs ";
	$qu .= "WHERE " if ($package);
	$qu .= "PACKAGE = '$package' AND NAME = '$name' " if ($package && $name);
	$qu .= "PACKAGE = '$package' " if ($package && !$name);
	$qu .= "ORDER BY PACKAGE, NAME, LASTMODIFIED DESC ";
	print STDERR "   Query: $qu\n" if ($DEBUG);
	
	my $logshr = $dbh->selectall_arrayref($qu, { Slice => {} });
	
	my @logs;
	my %logcount;
	# my @keystodelete;
	
	foreach my $key (@$logshr) {
		my $filesize;
		my $fileexists;
		$fileexists = -e $key->{'FILENAME'};
		$filesize = -s $key->{'FILENAME'} if ($fileexists);
		
		if (!$nofilter and $key->{'LOGSTART'} and ! -e "$key->{'FILENAME'}") {
			print STDERR "$key->{'FILENAME'} does not exist - skipping" if ($DEBUG);
			next;
		}
		
		my %log;
		require Time::Piece;
		my $logstartobj = Time::Piece->strptime($key->{'LOGSTART'}, "%Y-%m-%d %H:%M:%S") if ($key->{'LOGSTART'});
		my $logendobj = Time::Piece->strptime($key->{'LOGEND'}, "%Y-%m-%d %H:%M:%S") if ($key->{'LOGEND'});
		my $lastmodifiedobj = Time::Piece->strptime($key->{'LASTMODIFIED'}, "%Y-%m-%d %H:%M:%S") if ($key->{'LASTMODIFIED'});
		
		# # Delete by age (older than 1 month)
		# if (time > ($lastmodifiedobj+2629746) ) {
			# push @keystodelete, $key->{'LOGKEY'};
			# # log_db_delete_logkey($dbh, $key->{'LOGKEY'});
			# next;
		# }
		
		# # Count and delete (more than 20 per package)
		# $logcount{$key->{'PACKAGE'}}{$key->{'NAME'}}++;
		# if ($logcount{$key->{'PACKAGE'}}{$key->{'NAME'}} > 20) {
			# push @keystodelete, $key->{'LOGKEY'};
			# # log_db_delete_logkey($dbh, $key->{'LOGKEY'});
			# next;
		# }
		
		$log{'LOGSTARTISO'} = $logstartobj->datetime if($logstartobj);
		$log{'LOGSTARTSTR'} = $logstartobj->strftime("%d.%m.%Y %H:%M") if($logstartobj);
		$log{'LOGENDISO'} = $logendobj->datetime if ($logendobj);
		$log{'LOGENDSTR'} = $logendobj->strftime("%d.%m.%Y %H:%M") if ($logendobj);
		$log{'LASTMODIFIEDISO'} = $lastmodifiedobj->datetime if ($lastmodifiedobj);
		$log{'LASTMODIFIEDSTR'} = $lastmodifiedobj->strftime("%d.%m.%Y %H:%M") if ($lastmodifiedobj);
		
		$log{'PACKAGE'} = $key->{'PACKAGE'};
		$log{'NAME'} = $key->{'NAME'};
		$log{'FILENAME'} = $key->{'FILENAME'};
		$log{'KEY'} = $key->{'LOGKEY'};
		
		my $qu_attr = "SELECT * FROM logs_attr WHERE keyref = '$key->{'LOGKEY'}';";
		my @attribs = $dbh->selectall_array($qu_attr);
		if (@attribs) {
			foreach my $attrib (@attribs) {
				$log{@$attrib[1]} =  @$attrib[2];
				# print STDERR "Attrib: 0:" . @$attrib[0] . " 1:" . @$attrib[1] . " 2:" . @$attrib[2] . "\n";
			}
		}
		
		push(@logs, \%log);

	}
	
	# log_db_bulk_delete_logkey($dbh, @keystodelete);
	
	return @logs;
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
	my $dbfile = $dbh->sqlite_db_filename();
	$dbh->disconnect;
	eval {
		my $uid = (stat $dbfile)[4];
		my $owner = (getpwuid $uid)[0];
		if ($owner ne 'loxberry') {
			my ($login,$pass,$uid,$gid) = getpwnam('loxberry');
			chown $uid, $gid, $dbfile;
		}
	};
	notify_send_mail(\%data);
	
	print STDERR "<--- notify\n" if ($DEBUG);

}

# PUBLIC FUNCTION
sub notify_ext
{
	print STDERR "notify_ext --->\n" if ($DEBUG);
	
	# SQLite interface
	require DBI;
	require HTML::Entities;
	my $dbh;
	
	my $data = shift;
	$data->{MESSAGE} = HTML::Entities::decode($data->{MESSAGE});

	$dbh = notify_init_database();
	print STDERR "notify_ext: Could not init database.\n" if (! $dbh);
	return undef if (! $dbh);
	
	if (! $data->{_ISPLUGIN} && ! $data->{_ISSYSTEM}) {
		my $plugin = LoxBerry::System::plugindata($data->{PACKAGE});
		if ($LoxBerry::System::lbpplugindir || $plugin) {
			print STDERR "   Detected plugin notification\n" if ($DEBUG);
			$data->{_ISPLUGIN} = 1;
		} else {
			print STDERR "   Detected system notification\n" if ($DEBUG);
			$data->{_ISSYSTEM} = 1;
		}
	}
	
	#require Encode;	
	#$data->{MESSAGE} = Encode::encode("utf8", $data->{MESSAGE});
	notify_insert_notification($dbh, $data);
	my $dbfile = $dbh->sqlite_db_filename();
	$dbh->disconnect;
	eval {
		my $uid = (stat $dbfile)[4];
		my $owner = (getpwuid $uid)[0];
		if ($owner ne 'loxberry') {
			my ($login,$pass,$uid,$gid) = getpwnam('loxberry');
			chown $uid, $gid, $dbfile;
		}
	};
	
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
	$dbh->{sqlite_unicode} = 1;
	
	$dbh->do("CREATE TABLE IF NOT EXISTS notifications (
				PACKAGE VARCHAR(255) NOT NULL,
				NAME VARCHAR(255) NOT NULL,
				MESSAGE TEXT,
				SEVERITY INT,
				timestamp DATETIME DEFAULT (datetime('now','localtime')) NOT NULL,
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
	Carp::croak "Create notification: No NAME defined\n" if (! $p{NAME});
	Carp::croak "Create notification: No MESSAGE defined\n" if (! $p{MESSAGE});
	Carp::croak "Create notification: No SEVERITY defined\n" if (! $p{SEVERITY});

	# Strip HTML from $message
	$p{MESSAGE} =~ s/<br>/\\n/g;
	$p{MESSAGE} =~ s/<p>/\\n/g;
	$p{MESSAGE} =~ s/<.+?>//g;
	
	
	# Start transaction
	$dbh->do("BEGIN TRANSACTION;"); 
	
	# Insert main notification
	my $sth = $dbh->prepare('INSERT INTO notifications (PACKAGE, NAME, MESSAGE, SEVERITY) VALUES (?, ?, ?, ?) ;');
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
	
	# Don't try to send email that we cannot send emails
	return if ($notifymailerror);
	
	# Read mail settings
	require LoxBerry::JSON;
	my $sysmailobj = LoxBerry::JSON->new();
	my $mcfg = $sysmailobj->open(filename => "$LoxBerry::System::lbsconfigdir/mail.json", readonly => 1);
	
	# Don't send email if mail in general, or the specific mail type is disabled
	return if ($p{SEVERITY} != 3 && $p{SEVERITY} != 6);
	return if (! $mcfg or ! LoxBerry::System::is_enabled($mcfg->{SMTP}->{ACTIVATE_MAIL}));
	return if (! LoxBerry::System::is_enabled($mcfg->{NOTIFICATION}->{MAIL_SYSTEM_ERRORS}) && $p{_ISSYSTEM} && $p{SEVERITY}  == 3);
	return if (! LoxBerry::System::is_enabled($mcfg->{NOTIFICATION}->{MAIL_SYSTEM_INFOS}) && $p{_ISSYSTEM} && $p{SEVERITY}  == 6);
	return if (! LoxBerry::System::is_enabled($mcfg->{NOTIFICATION}->{MAIL_PLUGIN_ERRORS}) && $p{_ISPLUGIN} && $p{SEVERITY}  == 3);
	return if (! LoxBerry::System::is_enabled($mcfg->{NOTIFICATION}->{MAIL_PLUGIN_INFOS}) && $p{_ISPLUGIN} && $p{SEVERITY}  == 6);
	
	# Prepare some additional fields
	
	my $plugintitle;
	
	if(!$p{_ISSYSTEM}) {
		my $plugin = LoxBerry::System::plugindata($p{PACKAGE});
		$plugintitle = defined $plugin->{PLUGINDB_TITLE} ? $plugin->{PLUGINDB_TITLE} : $p{PACKAGE};
	}
	
	# Add some values to the options
	$p{SEVERITY_STR} = "INFO" if ($p{SEVERITY}  == 6);
	$p{SEVERITY_STR} = "ERROR" if ($p{SEVERITY}  == 3);
	$p{PLUGINTITLE} = $plugintitle;
	
	if ($p{LOGFILE}) {
		$p{LOGFILE_REL} = $p{LOGFILE};
		$p{LOGFILE_REL} =~ s/^$LoxBerry::System::lbhomedir\///;
		$p{LOGFILE_REL} =~ s/^log\///;
	}

	## Call the email provider
	
	require JSON;
	
	my $options_json = quotemeta(JSON::to_json(\%p) ) ;
	
	my ($exitcode, $output) = LoxBerry::System::execute("$LoxBerry::System::lbssbindir/notifyproviders/email.pl $options_json");
	if ($exitcode != 0) {
		my %SL = LoxBerry::System::readlanguage(undef, undef, 1);
		$notifymailerror = 1; # Prevents loops
		my %notification = (
            PACKAGE => "mailserver",
            NAME => "mailerror",
            MESSAGE => $SL{'MAILSERVER.NOTIFY_MAIL_ERROR'},
            SEVERITY => 3, # Error
			_ISSYSTEM => 1
		);
		LoxBerry::Log::notify_ext( \%notification );
		print STDERR "Error sending email notification - Output: $output\n";
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
	
	
	my $notifhr = $dbh->selectall_arrayref($qu, { Slice => {} });
	
	my @notifications;
	
	foreach my $key (@$notifhr ) {
		require HTML::Entities;
		require Time::Piece;
		my %notification;
		my $dateobj = Time::Piece->strptime($key->{'timestamp'}, "%Y-%m-%d %H:%M:%S");
		my $contenthtml = $key->{'MESSAGE'};
		$contenthtml = HTML::Entities::encode_entities($contenthtml, '<>&"');
		$contenthtml =~ s/\n/<br>\n/g;
		
		$notification{'DATEISO'} = $dateobj->datetime;
		$notification{'DATESTR'} = $dateobj->strftime("%d.%m.%Y %H:%M");
		$notification{'PACKAGE'} = $key->{'PACKAGE'};
		$notification{'NAME'} = $key->{'NAME'};
		$notification{'SEVERITY'} = $key->{'SEVERITY'};
		$notification{'KEY'} = $key->{'notifykey'};
		$notification{'CONTENTRAW'} =  $key->{'MESSAGE'};
		$notification{'CONTENTHTML'} =  $contenthtml;
		
		my $qu_attr = "SELECT * FROM notifications_attr WHERE keyref = '$key->{'notifykey'}';";
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
		
		print STDERR "   Nothing to do. Rollback and returning.\n<--- delete_notifications\n" if ($DEBUG);
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
		
		next if ($not->{SEVERITY} != 3 && $not->{SEVERITY} != 6);
		
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
			$logfilepath =~ s/^log\///;
		
		}
		
		my $link;
		my $linktarget;
		if ( $not->{LINK} ) {
			$link = $not->{LINK};
			$linktarget = ( LoxBerry::System::begins_with($link, "http://") or LoxBerry::System::begins_with($link, "https://") ) ? "_blank" : "_self";
		}
		
		my $notif_line;
		$notif_line = 	qq(<div style='display:table-row;' class='notifyrow$randval' id='notifyrow$not->{KEY}'>\n);
		$notif_line .= 	qq(   <div style="display:table-cell; vertical-align: middle; width:30px; padding:10px;">\n);
		if ($not->{SEVERITY} == 6) {
			$notif_line .= qq(      <img src="/system/images/notification_info_small.svg">\n);
		} elsif ($not->{SEVERITY} == 3) {
			$notif_line .= qq(      <img src="/system/images/notification_error_small.svg">\n);
		}
		$notif_line .= qq(   </div>\n);
		$notif_line .= qq(   <div style='vertical-align: middle; width:75%; display: table-cell; padding: 7px;'><b>$not->{DATESTR}:</b> $not->{CONTENTHTML}</div>\n);
		$notif_line .= qq(   <div style='vertical-align: middle; width:25%; display: table-cell; align:right; text-align: right;'>\n);
		$notif_line .= qq(      <a class="btnlogs" data-role="button" href="/admin/system/tools/logfile.cgi?logfile=$logfilepath&header=html&format=template" target="_blank" data-inline="true" data-mini="true" data-icon="arrow-d">Logfile</a>\n) if ($logfilepath);
		$notif_line .= qq(      <a class="btnlink" data-role="button" href="$link" target="$linktarget" data-inline="true" data-mini="true" data-icon="action">Details</a>\n) if ($link);
		$notif_line .= qq(      <a href='#' class='notifdelete' id='notifdelete$not->{KEY}' data-delid='$not->{KEY}' data-role='button' data-icon='delete' data-iconpos='notext' data-inline='true' data-mini='true'>(X)</a>\n);
		$notif_line .= qq(   </div>\n);
		# print STDERR $notif_line if ($DEBUG);
		$notif_line .= qq(</div>\n);
		$all_notifys .= $notif_line;
		push (@notify_html, $notif_line);
	}
	
	return if (! $all_notifys);
	
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
	my %SL = LoxBerry::System::readlanguage($maintemplate, undef, 1);
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
		require Time::Piece;
		$dt = Time::Piece->strptime($datestring, "%Y%m%d_%H%M%S");
	};
	# LOGDEB "parsedatestring: Calculated date/time: " . $dt->strftime("%d.%m.%Y %H:%M");
	return $dt;
}

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
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->DEB(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGINF 
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->INF(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGOK 
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->OK(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGWARN
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->WARN(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGERR
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->ERR(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGCRIT 
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->CRIT(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGALERT 
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->ALERT(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGEMERGE 
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->EMERGE(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGSTART 
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->LOGSTART(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGEND 
{
	create_temp_logobject() if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->LOGEND(@_); # or Carp::carp("No default object set for exported logging functions.");
}

sub LOGTITLE
{
	return if (! $LoxBerry::Log::mainobj);
	$LoxBerry::Log::mainobj->logtitle(@_);
}

sub create_temp_logobject
{
	my $package;
	if (! $LoxBerry::System::lbpplugindir) {
		# No package found
		$package = $0;
	}
	else {
		$package = $LoxBerry::System::lbpplugindir;
	}
	
	my $pluginloglevel = LoxBerry::System::pluginloglevel();
	if (! $pluginloglevel or $pluginloglevel < 0) {
		$pluginloglevel = 7;
	}
	
	$LoxBerry::Log::mainobj = LoxBerry::Log->new (
				package => $package,
				name => 'STDERR',
				stderr => 1,
				nofile => 1,
				addtime => 1,
				loglevel => $pluginloglevel
	);
}





#####################################################
# Finally 1; ########################################
#####################################################
1;
