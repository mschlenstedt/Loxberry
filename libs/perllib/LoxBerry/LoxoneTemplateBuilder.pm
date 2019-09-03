#!/usr/bin/perl
use warnings;
use strict;
use Carp;
use HTML::Entities;


package LoxBerry::LoxoneTemplateBuilder;

our $VERSION = "2.0.0.6";
our $DEBUG = 0;

if ($DEBUG) {
	print STDERR "LoxBerry::LoxoneTemplateBuilder: Developer warning - DEBUG mode is enabled in module\n" if ($DEBUG);
}

# Virtual HTTP Input
sub VirtualInHttp 
{

	my $class = shift;
	if (@_ % 2) {
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	my %params = @_;
	
	my $self = { 
				Title => $params{Title},
				Comment => $params{Comment} ? $params{Comment} : "",
				Address => $params{Address} ? $params{Address} : "",
				PollingTime => $params{PollingTime} ? $params{PollingTime} : "60",
				_type => 'VirtualInHttp'
	};
	
	bless $self, $class;

	$self->{VirtualInHttpCmd} = ( );
	
	return $self;

}

# Virtual HTTP Input Command
sub VirtualInHttpCmd
{
	my $self = shift;
	
	print STDERR "VirtualInHttpCmd: Number of parameters: " . @_ . "\n" if ($DEBUG);
	if(@_ == 1) {
		my $elementnr = shift;
		return $self->{VirtualInHttpCmd}[@$self->{VirtualInHttpCmd}-1];
	}
	
	if (@_ % 2) {
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	if( $self->{_type} ne "VirtualInHttp" ) {
		Carp::croak "Call of VirtualInHttpCmd does not fit to class type " . $self->{_type};
	}
	
	my %params = @_;

	my %VICmd = ( 
				_deleted => undef,
				Title => $params{Title},
				Comment => $params{Comment} ? $params{Comment} : "",
				Check => $params{Check} ? $params{Check} : "",
				Signed => ( defined $params{Signed} and !is_enabled($params{Signed}) ) ? "false" : "true",
				Analog => ( defined $params{Analog} and !is_enabled($params{Analog}) ) ? "false" : "true",
				SourceValLow => $params{SourceValLow} ? $params{SourceValLow} : "0",
				DestValLow => $params{DestValLow} ? $params{DestValLow} : "0",
				SourceValHigh => $params{SourceValHigh} ? $params{SourceValHigh} : "100",
				DestValHigh => $params{DestValHigh} ? $params{DestValHigh} : "100",
				DefVal => $params{DefVal} ? $params{DefVal} : "0",
				MinVal => $params{MinVal} ? $params{MinVal} : "-2147483647",
				MaxVal => $params{MaxVal} ? $params{MaxVal} : "2147483647"
	);

	push @{$self->{VirtualInHttpCmd}}, \%VICmd;

	return @{$self->{VirtualInHttpCmd}};

}

# Virtual UDP Input
sub VirtualInUdp
{

	my $class = shift;
	if (@_ % 2) {
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	my %params = @_;
	
	my $self = { 
				Title => $params{Title},
				Comment => $params{Comment} ? $params{Comment} : "",
				Address => $params{Address} ? $params{Address} : "",
				Port => $params{Port} ? $params{Port} : "",
				_type => 'VirtualInUdp'
	};
	
	bless $self, $class;

	$self->{VirtualInUdp} = ( );
	
	return $self;

}

# Virtual UDP Input Command
sub VirtualInUdpCmd
{
	my $self = shift;
	
	print STDERR "VirtualInUdpCmd: Number of parameters: " . @_ . "\n" if ($DEBUG);
	if(@_ == 1) {
		my $elementnr = shift;
		return $self->{VirtualInUdpCmd}[@$self->{VirtualInUdpCmd}-1];
	}
	
	if (@_ % 2) {
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	if( $self->{_type} ne "VirtualInUdp" ) {
		Carp::croak "Call of VirtualInUdpCmd does not fit to class type " . $self->{_type};
	}

	my %params = @_;

	my %VICmd = ( 
				_deleted => undef,
				Title => $params{Title},
				Comment => $params{Comment} ? $params{Comment} : "",
				Address => $params{Address} ? $params{Address} : "",
				Check => $params{Check} ? $params{Check} : "",
				Signed => ( defined $params{Signed} and !is_enabled($params{Signed}) ) ? "false" : "true",
				Analog => ( defined $params{Analog} and !is_enabled($params{Analog}) ) ? "false" : "true",
				SourceValLow => $params{SourceValLow} ? $params{SourceValLow} : "0",
				DestValLow => $params{DestValLow} ? $params{DestValLow} : "0",
				SourceValHigh => $params{SourceValHigh} ? $params{SourceValHigh} : "100",
				DestValHigh => $params{DestValHigh} ? $params{DestValHigh} : "100",
				DefVal => $params{DefVal} ? $params{DefVal} : "0",
				MinVal => $params{MinVal} ? $params{MinVal} : "-2147483647",
				MaxVal => $params{MaxVal} ? $params{MaxVal} : "2147483647"
	);

	push @{$self->{VirtualInUdpCmd}}, \%VICmd;

	return @{$self->{VirtualInUdpCmd}};

}

# Virtual Output
sub VirtualOut
{

	my $class = shift;
	if (@_ % 2) {
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	my %params = @_;
	
	my $self = { 
				Title => $params{Title},
				Comment => $params{Comment} ? $params{Comment} : "",
				Address => $params{Address} ? $params{Address} : "",
				CmdInit => $params{CmdInit} ? $params{CmdInit} : "",
				CloseAfterSend => ( defined $params{CloseAfterSend} and !is_enabled($params{CloseAfterSend}) ) ? "false" : "true",
				CmdSep => $params{CmdSep} ? $params{CmdSep} : "",
				_type => 'VirtualOut'
	};
	
	bless $self, $class;
	$self->{VirtualOut} = ( );
	return $self;

}

# Virtual Output Command
sub VirtualOutCmd
{
	my $self = shift;
	
	print STDERR "VirtualOutCmd: Number of parameters: " . @_ . "\n" if ($DEBUG);
	if(@_ == 1) {
		my $elementnr = shift;
		return $self->{VirtualOutCmd}[@$self->{VirtualOutCmd}-1];
	}
	
	if (@_ % 2) {
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	if( $self->{_type} ne "VirtualOut" ) {
		Carp::croak "Call of VirtualOutCmd does not fit to class type " . $self->{_type};
	}
	
	my %params = @_;

	my %VICmd = ( 
				_deleted => undef,
				ID => undef,
				Title => $params{Title},
				Comment => $params{Comment} ? $params{Comment} : "",
				CmdOnMethod => $params{CmdOnMethod} ? $params{CmdOnMethod} : "GET",
				CmdOn => $params{CmdOn} ? $params{CmdOn} : "",
				CmdOnHTTP => $params{CmdOnHTTP} ? $params{CmdOnHTTP} : "",
				CmdOnPost => $params{CmdOnPost} ? $params{CmdOnPost} : "",
				CmdOffMethod => $params{CmdOffMethod} ? $params{CmdOffMethod} : "GET",
				CmdOff => $params{CmdOff} ? $params{CmdOff} : "",
				CmdOffHTTP => $params{CmdOffHTTP} ? $params{CmdOffHTTP} : "",
				CmdOffPost => $params{CmdOffPost} ? $params{CmdOffPost} : "",
				Analog => is_enabled($params{Analog}) ? "true" : "false",
				Repeat => $params{Repeat} ? $params{Repeat} : "0",
				RepeatRate => $params{RepeatRate} ? $params{RepeatRate} : "0",
	);

	push @{$self->{VirtualOutCmd}}, \%VICmd;

	return @{$self->{VirtualOutCmd}};

}

sub output
{
	my $self = shift;
	my $crlf = "\r\n";
	my $o;

	if($self->{_type} eq 'VirtualInHttp') {

		$o .= '<?xml version="1.0" encoding="utf-8"?>'.$crlf;

		$o .= '<VirtualInHttp ';
		$o .= 'Title="'.HTML::Entities::encode_entities($self->{Title}).'" ';
		$o .= 'Comment="'.HTML::Entities::encode_entities($self->{Comment}).'" ';
		$o .= 'Address="'.HTML::Entities::encode_entities($self->{Address}).'" ';
		$o .= 'PollingTime="'.$self->{PollingTime}.'"';
		$o .= '>'.$crlf;
		
		foreach my $VIcmd ( @{$self->{VirtualInHttpCmd}} ) {
			next if $VIcmd->{_deleted};
			
			$o .= "\t".'<VirtualInHttpCmd ';
			$o .= 'Title="'.HTML::Entities::encode_entities($VIcmd->{Title}).'" ';
			$o .= 'Comment="'.HTML::Entities::encode_entities($VIcmd->{Comment}).'" ';
			$o .= 'Check="'.HTML::Entities::encode_entities($VIcmd->{Check}).'" ';
			$o .= 'Signed="'.$VIcmd->{Signed}.'" ';
			$o .= 'Analog="'.$VIcmd->{Analog}.'" ';
			$o .= 'SourceValLow="'.$VIcmd->{SourceValLow}.'" ';
			$o .= 'DestValLow="'.$VIcmd->{DestValLow}.'" ';
			$o .= 'SourceValHigh="'.$VIcmd->{SourceValHigh}.'" ';
			$o .= 'DestValHigh="'.$VIcmd->{DestValHigh}.'" ';
			$o .= 'DefVal="'.$VIcmd->{DefVal}.'" ';
			$o .= 'MinVal="'.$VIcmd->{MinVal}.'" ';
			$o .= 'MaxVal="'.$VIcmd->{MaxVal}.'"';
			$o .= '/>'.$crlf;
		}
		
		$o .= '</VirtualInHttp>'.$crlf;
	}
	
	elsif($self->{_type} eq 'VirtualInUdp') {

		$o .= '<?xml version="1.0" encoding="utf-8"?>'.$crlf;

		$o .= '<VirtualInUdp ';
		$o .= 'Title="'.HTML::Entities::encode_entities($self->{Title}).'" ';
		$o .= 'Comment="'.HTML::Entities::encode_entities($self->{Comment}).'" ';
		$o .= 'Address="'.HTML::Entities::encode_entities($self->{Address}).'" ';
		$o .= 'Port="'.HTML::Entities::encode_entities($self->{Port}).'" ';
		$o .= '>'.$crlf;
		
		foreach my $VIcmd ( @{$self->{VirtualInUdpCmd}} ) {
			next if $VIcmd->{_deleted};
			
			$o .= "\t".'<VirtualInUdpCmd ';
			$o .= 'Title="'.HTML::Entities::encode_entities($VIcmd->{Title}).'" ';
			$o .= 'Comment="'.HTML::Entities::encode_entities($VIcmd->{Comment}).'" ';
			$o .= 'Address="'.HTML::Entities::encode_entities($VIcmd->{Address}).'" ';
			$o .= 'Check="'.HTML::Entities::encode_entities($VIcmd->{Check}).'" ';
			$o .= 'Signed="'.$VIcmd->{Signed}.'" ';
			$o .= 'Analog="'.$VIcmd->{Analog}.'" ';
			$o .= 'SourceValLow="'.$VIcmd->{SourceValLow}.'" ';
			$o .= 'DestValLow="'.$VIcmd->{DestValLow}.'" ';
			$o .= 'SourceValHigh="'.$VIcmd->{SourceValHigh}.'" ';
			$o .= 'DestValHigh="'.$VIcmd->{DestValHigh}.'" ';
			$o .= 'DefVal="'.$VIcmd->{DefVal}.'" ';
			$o .= 'MinVal="'.$VIcmd->{MinVal}.'" ';
			$o .= 'MaxVal="'.$VIcmd->{MaxVal}.'"';
			$o .= '/>'.$crlf;
		}
		
		$o .= '</VirtualInUdp>'.$crlf;
	}
	
		elsif($self->{_type} eq 'VirtualOut') {

		$o .= '<?xml version="1.0" encoding="utf-8"?>'.$crlf;

		$o .= '<VirtualOut ';
		$o .= 'Title="'.HTML::Entities::encode_entities($self->{Title}).'" ';
		$o .= 'Comment="'.HTML::Entities::encode_entities($self->{Comment}).'" ';
		$o .= 'Address="'.HTML::Entities::encode_entities($self->{Address}).'" ';
		$o .= 'CmdInit="'.HTML::Entities::encode_entities($self->{CmdInit}).'" ';
		$o .= 'CloseAfterSend="'.$self->{CloseAfterSend}.'" ';
		$o .= 'CmdSep="'.HTML::Entities::encode_entities($self->{CmdSep}).'" ';
		$o .= '>'.$crlf;
		
		my $id = 0;
		foreach my $VIcmd ( @{$self->{VirtualOutCmd}} ) {
			next if $VIcmd->{_deleted};
			$id++;
			$o .= "\t".'<VirtualOutCmd ';
			$o .= 'ID="'.$id.'" ';
			$o .= 'Title="'.HTML::Entities::encode_entities($VIcmd->{Title}).'" ';
			$o .= 'Comment="'.HTML::Entities::encode_entities($VIcmd->{Comment}).'" ';
			$o .= 'CmdOnMethod="'.uc($VIcmd->{CmdOnMethod}).'" ';
			$o .= 'CmdOn="'.HTML::Entities::encode_entities($VIcmd->{CmdOn}).'" ';
			$o .= 'CmdOnHTTP="'.HTML::Entities::encode_entities($VIcmd->{CmdOnHTTP}).'" ';
			$o .= 'CmdOnPost="'.HTML::Entities::encode_entities($VIcmd->{CmdOnPost}).'" ';
			$o .= 'CmdOffMethod="'.uc($VIcmd->{CmdOffMethod}).'" ';
			$o .= 'CmdOff="'.HTML::Entities::encode_entities($VIcmd->{CmdOff}).'" ';
			$o .= 'CmdOffHTTP="'.HTML::Entities::encode_entities($VIcmd->{CmdOffHTTP}).'" ';
			$o .= 'CmdOffPost="'.HTML::Entities::encode_entities($VIcmd->{CmdOffPost}).'" ';
			$o .= 'Analog="'.$VIcmd->{Analog}.'" ';
			$o .= 'Repeat="'.$VIcmd->{Repeat}.'" ';
			$o .= 'RepeatRate="'.$VIcmd->{RepeatRate}.'"';
			$o .= '/>'.$crlf;
		}
		
		$o .= '</VirtualOut>'.$crlf;
	}
	
	return $o;

}

sub htmltable
{
	my $self = shift;
	my $crlf = "\r\n";
	my $o;
	
	$o .= '<div class="templatebuilder_table" style="display:table;width:100%;">'.$crlf;
	
	
	if($self->{_type} eq 'VirtualInHttp') {
		$o .= '	<div class="templatebuilder_body" style="display:table-row-group">'.$crlf;
		$o .= '		<div class="templatebuilder_row" style="display:table-row">'.$crlf;
		$o .= "			".HTML::Entities::encode_entities($self->{Title}).$crlf;
		$o .= '		</div>'.$crlf;
		$o .= '	</div>'.$crlf;
		
		foreach my $VIcmd ( @{$self->{VirtualInHttpCmd}} ) {
			next if $VIcmd->{_deleted};
		
			$o .= '	<div class="templatebuilder_body" style="display:table-row-group">'.$crlf;
			$o .= '		<div class="templatebuilder_row templatebuilder_row_name" style="display:table-row">'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{Title}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{Comment}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{Check}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '		</div>'.$crlf;
			$o .= '	</div>'.$crlf;
			
		}
	}

	if($self->{_type} eq 'VirtualInUdp') {
		$o .= '	<div class="templatebuilder_body" style="display:table-row-group">'.$crlf;
		$o .= '		<div class="templatebuilder_row" style="display:table-row">'.$crlf;
		$o .= "			".HTML::Entities::encode_entities($self->{Title}).$crlf;
		$o .= '		</div>'.$crlf;
		$o .= '		<div class="templatebuilder_row" style="display:table-row">'.$crlf;
		$o .= "			".HTML::Entities::encode_entities($self->{Address}).$crlf;
		$o .= '		</div>'.$crlf;
		$o .= '		<div class="templatebuilder_row" style="display:table-row">'.$crlf;
		$o .= "			".HTML::Entities::encode_entities($self->{Port}).$crlf;
		$o .= '		</div>'.$crlf;
		$o .= '	</div>'.$crlf;
		
		foreach my $VIcmd ( @{$self->{VirtualInHttpCmd}} ) {
			next if $VIcmd->{_deleted};
		
			$o .= '	<div class="templatebuilder_body" style="display:table-row-group">'.$crlf;
			$o .= '		<div class="templatebuilder_row templatebuilder_row_name" style="display:table-row">'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{Title}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{Comment}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{Check}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '		</div>'.$crlf;
			$o .= '	</div>'.$crlf;
			
		}
	}
	
	if($self->{_type} eq 'VirtualOut') {
		$o .= '	<div class="templatebuilder_body" style="display:table-row-group">'.$crlf;
		$o .= '		<div class="templatebuilder_row" style="display:table-row">'.$crlf;
		$o .= "			".HTML::Entities::encode_entities($self->{Title}).$crlf;
		$o .= '		</div>'.$crlf;
		$o .= '		<div class="templatebuilder_row" style="display:table-row">'.$crlf;
		$o .= "			".HTML::Entities::encode_entities($self->{Address}).$crlf;
		$o .= '		</div>'.$crlf;
		$o .= '	</div>'.$crlf;
		
		foreach my $VIcmd ( @{$self->{VirtualInHttpCmd}} ) {
			next if $VIcmd->{_deleted};
		
			$o .= '	<div class="templatebuilder_body" style="display:table-row-group">'.$crlf;
			$o .= '		<div class="templatebuilder_row templatebuilder_row_name" style="display:table-row">'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{Title}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{Comment}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '			<div class="templatebuilder_cell" style="display:table-cell;">'.$crlf;
			$o .= "				".HTML::Entities::encode_entities($VIcmd->{CmdOnHTTP}).$crlf;
			$o .= '			</div>'.$crlf;
			$o .= '		</div>'.$crlf;
			$o .= '	</div>'.$crlf;
			
		}
	}
	
	$o .= '</div>'.$crlf;

	return $o;

}




sub delete 
{
	my $self = shift;
	
	if(@_ != 1) {
		Carp::croak "Delete needs exactly one parameter, the index of the element to delete";
	}
	
	my $elementnr = shift;
	$elementnr--;
	return 0 if ($elementnr < 0);

	if($self->{_type} eq 'VirtualInHttp') {
		if( defined $self->{VirtualInHttpCmd}[$elementnr] ) {
			$self->{VirtualInHttpCmd}[$elementnr]->{_deleted} = 1;
			return 1;
		}
	}

	elsif($self->{_type} eq 'VirtualInUdp') {
		if( defined $self->{VirtualInUdpCmd}[$elementnr] ) {
			$self->{VirtualInUdpCmd}[$elementnr]->{_deleted} = 1;
			return 1;
		}
	}
	
	elsif($self->{_type} eq 'VirtualOut') {
		if( defined $self->{VirtualOutCmd}[$elementnr] ) {
			$self->{VirtualOutCmd}[$elementnr]->{_deleted} = 1;
			return 1;
		}
	}
	return 0;
}






####################################################
# is_enabled - tries to detect if a string says 'True'
####################################################
sub is_enabled
{ 
	my ($text) = @_;
	return undef if (!$text);
	$text =~ s/^\s+|\s+$//g;
	$text = lc $text;
	if ($text eq "true") { return 1;}
	if ($text eq "yes") { return 1;}
	if ($text eq "on") { return 1;}
	if ($text eq "enabled") { return 1;}
	if ($text eq "enable") { return 1;}
	if ($text eq "1") { return 1;}
	if ($text eq "check") { return 1;}
	if ($text eq "checked") { return 1;}
	if ($text eq "select") { return 1;}
	if ($text eq "selected") { return 1;}
	return undef;
}

#####################################################
# Finally 1; ########################################
#####################################################
1;
