# Please increment version number on EVERY change 
# Major.Minor represents LoxBerry version (e.g. 0.3.1.12 = LoxBerry V0.3.1 the 12th change)

use strict;
use Carp;
use LoxBerry::System;
use JSON;

################################################################
package LoxBerry::Log;
our $VERSION = "0.3.1.2";

# This object is the object the exported LOG* functions use
our $mainobj;
our $packagedb;
# 
my $packagedbfile = "$LoxBerry::System::lbsdatadir/logpackages.json";
our %severitylist = ( 0 => 'EMERGE', 1 => 'ALERT', 2 => 'CRITICAL', 3 => 'ERROR', 4 => 'WARNING', 5 => 'OK', 6 => 'INFO', 7 => 'DEBUG' );

### Exports ###
use base 'Exporter';
our @EXPORT = qw (

LOGDEB
LOGINF
LOGOK
LOGWARN
LOGERR
LOGCRIT
LOGALERT
LOGEMERGE
LOGSTART
LOGEND

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
	
	Carp::croak "Illegal parameter list has odd number of values" if @_ % 2;
	
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
	};
	
	bless $self, $class;
	
	if ($self->{autoraise} eq "") {
		$self->{autoraise} = 1;
	}
	
	# Setting package
	print STDERR "Package: " . $self->{package} . "\n";
	if (!$self->{package}) {
		if ($LoxBerry::System::lbpplugindir) {
			$self->{package} = $LoxBerry::System::lbpplugindir;
		}
		if (!$self->{package}) {
		Carp::croak "A 'package' must be defined if this log is not from a plugin";
		}
	}
	
	# Generating filename
	if (!$self->{logdir} && !$self->{filename} && -e $LoxBerry::System::lbplogdir) {
		$self->{logdir} = $LoxBerry::System::lbplogdir;
	}
	if ($self->{logdir} && !$self->{filename}) {
		$self->{filename} = $self->{logdir} . "/" . LoxBerry::System::currtime('file') . "_" . $self->{name} . ".log";
	} elsif (!$self->{filename}) {
		if ($LoxBerry::System::lbplogdir && -e $LoxBerry::System::lbplogdir) {
			$self->{filename} = "$LoxBerry::System::lbplogdir/" . currtime('file') . "_" . $self->{name} . ".log";
		} else {
			Carp::croak "Cannot determine plugin log directory";
		}
	} 
	if (!$self->{filename}) {
		Carp::croak "Cannot smartly detect where your logfile should be placed. Check your parameters.";
	}
	
	# Get loglevel
	if (!$self->{loglevel}) {
		my %plugindata = LoxBerry::System::plugindata();
		if ($plugindata{'PLUGINDB_LOGLEVEL'}) {
			$self->{loglevel} = $plugindata{'PLUGINDB_LOGLEVEL'};
		} else {
			$self->{loglevel} = 7;
		}
	} 
	
	print STDERR "filename: " . $self->{filename} . "\n";
	
	my $writetype = $self->{append} ? ">>" : ">";
	
	open(my $fh, $writetype, $self->{filename}) or Carp::croak "Cannot open logfile " . $self->{filename};
		
	$self->{'_FH'} = $fh;
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
	
	# print STDERR "\nSeverity: $severity / Loglevel: " . $self->{loglevel} . "\n";
	# print STDERR "Log: $s\n";
	# Do not log if loglevel is lower than severity
	if ($severity <= 2 && $self->{autoraise} == 1) {
		$self->{loglevel} = 6;
	}
	
	if ($severity < $self->{loglevel} || $severity < 0) {
		# print STDERR "Not filtered.\n";
		my $fh = $self->{'_FH'};
		my $string;
		if ($severity == 7) {
			$string = $s . "\n"; 
		} else {
			$string = '<' . $severitylist{$severity} . '> ' . $s . "\n"; 
		}
		if (!$self->nolog) {
			print $fh $string;
			}
		if ($self->{stderr}) {
			print STDERR $string;
		}
		if ($self->{stdout}) {
			print STDOUT $string;
		}
	}
}


#################################################################################
# The severity functions
#################################################################################
# 0 => 'EMERGE', 1 => 'ALERT', 2 => 'CRITICAL', 3 => 'ERROR', 4 => 'WARNING', 5 => 'OK', 6 => 'INFO', 7 => 'DEBUG'
sub LOGDEB
{
	print "DEBUG\n";
	my $self = shift;
	my ($s)=@_;
	$self->write(7, $s);
}

sub LOGINF
{
	my $self = shift;
	my ($s)=@_;
	$self->write(6, $s);
}

sub LOGOK
{
	my $self = shift;
	my ($s)=@_;
	$self->write(5, $s);
}

sub LOGWARN
{
	my $self = shift;
	my ($s)=@_;
	$self->write(4, $s);
}

sub LOGERR
{
	my $self = shift;
	my ($s)=@_;
	$self->write(3, $s);
}

sub LOGCRIT
{
	my $self = shift;
	my ($s)=@_;
	$self->write(2, $s);
}
sub LOGALERT
{
	my $self = shift;
	my ($s)=@_;
	$self->write(1, $s);
}
sub LOGEMERGE
{
	my $self = shift;
	my ($s)=@_;
	$self->write(0, $s);
}

sub LOGSTART
{
	my $self = shift;
	my ($s)=@_;
	$self->write(-1, "####################################################################################");
	$self->write(-1, LoxBerry::System::currtime . " TASK STARTED");
	$self->write(-1, $s);
}

sub LOGEND
{
	my $self = shift;
	my ($s)=@_;
	$self->write(-1, $s);
	$self->write(-1, LoxBerry::System::currtime . " TASK FINISHED");
}



## Sets this log object the default object 
sub default
{
	my $self = shift;
	$LoxBerry::Log::mainobj = $self;
}


our $AUTOLOAD;
sub AUTOLOAD {
	my $self = shift;
	# Remove qualifier from original method name...
	my $called =  $AUTOLOAD =~ s/.*:://r;
	# Is there an attribute of that name?
	Carp::carp "No such attribute: $called"
		unless exists $self->{$called};
	# If so, return it...
	return $self->{$called};
}

sub DESTROY { 
	my $self = shift;
	close $self->{"_FH"};
	print STDERR "Desctuctor closed file.\n";
} 


####################################################
# Exported helpers
####################################################
sub LOGDEB 
{
	$LoxBerry::Log::mainobj->LOGDEB(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGINF 
{
	$LoxBerry::Log::mainobj->LOGINF(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGOK 
{
	$LoxBerry::Log::mainobj->LOGOK(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGWARN
{
	$LoxBerry::Log::mainobj->LOGWARN(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGERR 
{
	$LoxBerry::Log::mainobj->LOGERR(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGCRIT 
{
	$LoxBerry::Log::mainobj->LOGCRIT(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGALERT 
{
	$LoxBerry::Log::mainobj->LOGALERT(@_); # or Carp::carp("No default object set for exported logging functions.");
}
sub LOGEMERGE 
{
	$LoxBerry::Log::mainobj->LOGEMERGE(@_); # or Carp::carp("No default object set for exported logging functions.");
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
