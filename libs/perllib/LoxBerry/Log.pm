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
our $VERSION = "0.3.5.5";
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
delete_notifications
get_notification_count
get_notifications
notification_content
parsedatestring

);

# Variables

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


sub notify
{
	my ($package, $name, $message, $error) = @_;
	if (! $package || ! $name || ! $message) {
		print STDERR "Notification: Missing parameters\n";
		return;
	}
	$package = lc($package);
	$package =~ s/_//g;
	$name = lc($name);
	$name =~ s/_//g;
	
	if ($error) {
		$error = '_err';
	} else { 
		$error = "";
	}
	
	my ($login,$pass,$uid,$gid) = getpwnam('loxberry');
	my $filename = $notification_dir . "/" . LoxBerry::System::currtime('file') . "_${package}_${name}${error}.system";
	open(my $fh, '>', $filename) or warn "Could not create a notification at '$filename' $!";
	flock($fh,2);
	print $fh $message;
	eval {
		chown $uid, $gid, $fh;
	};
	flock($fh,8);
	close $fh;
}


################################################################
# get_notifications
# Input: (optional) specific notification event filter
# Output: Hash with notifications
################################################################

sub get_notifications
{
	# print STDERR "get_notifications called.\n" if ($DEBUG);
	my ($package, $name, $latest, $count, $getcontent) = @_;
	LoxBerry::Log::read_notificationlist($getcontent);
	if (! $package) {
		return @notifications if (! $count);
		return $notifications_error, $notifications_ok, ($notifications_error+$notifications_ok);
	}
	
	$package = lc($package) if ($package);
	$name = lc($name) if ($name);
	
	my @filtered = ();
	my $filtered_errors=0;
	my $filtered_ok=0;
	
	foreach my $notification (@notifications) {
		next if ($package ne $notification->{PACKAGE});
		next if ($name && $name ne $notification->{NAME});
		if ($notification->{'SEVERITY'} eq 'err') {
			$filtered_errors++;
		} else {
			$filtered_ok++;
		}
		push(@filtered, $notification);
		last if ($latest);
		# print STDERR "Notification datestring: " . $notification->{DATESTR} . "\n" if ($DEBUG);
	}
	print STDERR "get_notifications: \n" if ($DEBUG);
	print STDERR "Countings: $filtered_errors errors / $filtered_ok ok's\n" if ($DEBUG);
	return @filtered if (! $count);
	return $filtered_errors, $filtered_ok, ($filtered_errors+$filtered_ok);
}

sub get_notifications_with_content
{
	my ($package, $name, $latest) = @_;
	my @filtered = LoxBerry::Log::get_notifications($package, $name, $latest, undef, 1);
	return @filtered;
}

# Retuns an array with the number of notifications
sub get_notification_count
{
	my ($package, $name, $latest) = @_;
	my ($notification_error, $notification_ok, $notification_sum) = LoxBerry::Log::get_notifications($package, $name, $latest, 1);
	return $notification_error, $notification_ok, $notification_sum;

}

sub delete_notifications
{
	my ($package, $name, $ignorelatest) = @_;
	LoxBerry::Log::read_notificationlist();
	my $latestkept=0;
	
	foreach my $notification (@notifications) {
		next if (lc($package) ne $notification->{PACKAGE});
		next if ($name && lc($name) ne $notification->{NAME});
		if ($ignorelatest && $latestkept == 0) {
			$latestkept = 1;
		} else {
			unlink $notification->{FULLPATH};
		}
		# print STDERR "Notification datestring: " . $notification->{DATESTR} . "\n" if ($DEBUG);
	}
	undef @notifications;
}

sub notification_content
{
	my ($key) = @_;
	my $notifyfile = "$notification_dir/$key";
	open (my $fh, "<" , $notifyfile) or return undef; 
	my $content = <$fh>;
	close ($fh);
	my $contenthtml = $content;
	$contenthtml =~ s/\n/<br>\n/g;
	$contenthtml = HTML::Entities::encode_entities($contenthtml, '<>&"');
	print STDERR "Contentraw: $content ContentHTML: $contenthtml\n" if ($DEBUG);
	return $content, $contenthtml;
}

sub get_notifications_html
{
	
	my %p = @_;
	my ($package, $name, $type, $buttons) = @_;
	
	print STDERR "get_notifications_html called.\n" if ($DEBUG);
	
	$p{package} = lc($package) if ($package);
	$p{name} = lc($name) if ($name);
	$p{buttons} = $buttons if ($buttons);
	
	$p{error} = 1 if (!$type || $type == 2 || $type eq 'all' || $type eq 'err' || $type eq 'error' || $type eq 'errors');
	$p{info} = 1 if (!$type || $type == 1 || $type eq 'all' || $type eq 'inf' || $type eq 'info' || $type eq 'infos');
		
	my @notifs = LoxBerry::Log::get_notifications($package, $name, undef, undef, 1);
	
	if ($DEBUG) {
		print STDERR "Parameters used:\n";
		print STDERR "   package: $p{package}\n";
		print STDERR "   name: $p{name}\n";
		print STDERR "   buttons: $p{buttons}\n";
		print STDERR "   error: $p{error}\n";
		print STDERR "   info: $p{info}\n";
	}
		
	if (! @notifs) {
		print STDERR "No notifications found. Returning nothing.\n" if ($DEBUG);
		return;
	}
	
	my @notify_html;
	my $all_notifys;
	
	my $randval = int(rand(30000));
	
	for my $not (@notifs) {
		# Don't show info when errors are requested
		print STDERR "Notification: $not->{SEVERITY} $not->{DATESTR} $not->{PACKAGE} $not->{NAME} $not->{CONTENT_RAW}\n" if ($DEBUG);
		
		
		if (! $not->{SEVERITY} && ! $p{error} ) {
			print STDERR "Skipping notification - is error but info requested\n" if ($DEBUG);
			next;
		}
		# Don't show errors when infos are requested
		if ( $not->{SEVERITY} eq 'err' && ! $p{error} ) {
			print STDERR "Skipping notification - is info but error requested\n" if ($DEBUG);
			next;
		}
		my $notif_line;
		$notif_line .= 	"<div style='display:table-row;' class='notifyrow$randval' id='notifyrow$not->{KEY}'>";
		$notif_line .= 	'<div style="display:table-cell; vertical-align: middle; width:30px; padding:10px;">';
		if (! $not->{SEVERITY}) {
			$notif_line .= '<img src="/system/images/notification_info_small.svg">';
		} elsif ($not->{SEVERITY} eq 'err') {
			$notif_line .= '<img src="/system/images/notification_error_small.svg">';
		}
		$notif_line .= "</div>";
		$notif_line .= "<div style='vertical-align: middle; width:90%; display: table-cell; '><b>$not->{DATESTR}:</b> $not->{CONTENTRAW}</div>";
		$notif_line .= "<div style='vertical-align: middle; width:10%; display: table-cell; align:right; text-align: right;'>";
		$notif_line .= "<a href='#' class='notifdelete' id='notifdelete$not->{KEY}' data-delid='$not->{KEY}' data-role='button' data-icon='delete' data-iconpos='notext' data-inline='true' data-mini='true'>Dismiss</a>";
		$notif_line .= "</div>";
		# print STDERR $notif_line if ($DEBUG);
		$notif_line .= "</div>";
		$all_notifys .= $notif_line;
		push (@notify_html, $notif_line);
	}
	
	
	
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

# INTERNAL function read_notificationlist
sub read_notificationlist
{
	my ($getcontent) = @_;
	return if (@notifications && !$getcontent); 
	#return if (@notifications && $getcontent && $content_was_read);
		
	opendir( my $DIR, $notification_dir );
	my @files = sort {$b cmp $a} readdir($DIR);
	my $direntry;
	my $notifycount;
	@notifications = ();
		
	while ( my $direntry = shift @files ) {
		next if $direntry eq '.' or $direntry eq '..' or $direntry eq '.dummy';
		print STDERR "Direntry: $direntry\n" if ($DEBUG);
		my $notstr = substr($direntry, 16, rindex($direntry, '.')-16);
		my ($package, $name, $severity) = split(/_/, $notstr);
		my $notdate = substr($direntry, 0, 15);
		# LOGDEB "Log type: $nottype  Date: $notdate";
		my $dateobj = LoxBerry::Log::parsedatestring($notdate);
		next if (!$dateobj); 
		my %notification;
		$notifycount++;
		if (lc($severity) eq 'err') {
			$notifications_error++;
		} else {
			$notifications_ok++;
		}
		$notification{'PACKAGE'} = lc($package);
		$notification{'NAME'} = lc($name);
		$notification{'SEVERITY'} = lc($severity);
		$notification{'DATEOBJ'} = $dateobj;
		$notification{'DATESTR'} = $dateobj->strftime("%d.%m.%Y %H:%M");
		$notification{'KEY'} = $direntry;
		$notification{'FULLPATH'} = "$notification_dir/$direntry";
		($notification{'CONTENTRAW'}, $notification{'CONTENTHTML'}) = notification_content($notification{'KEY'}) if ($getcontent);
		
		push(@notifications, \%notification);
	}
	# return @notifications;
	closedir $DIR;
	$content_was_read = 1;
	print STDERR "Number of elements: " . scalar(@notifications) . "\n" if ($DEBUG);
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
