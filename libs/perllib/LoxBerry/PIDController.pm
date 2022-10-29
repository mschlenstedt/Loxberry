package LoxBerry::PIDController;
$PIDController::VERSION = '0.1';
# PID Controller in Perl by Christian Fenzl
# GitHub: https://github.com/christianTF/Perl_PIDController

# Based on Python code from Caner Durmusoglu (https://github.com/ivmech/ivPID/blob/master/PID.py)

# Apache License, Version 2.0
# http://www.apache.org/licenses/LICENSE-2.0.html

use strict;
use warnings;
use Time::HiRes;

sub new {
	# Class PIDController
	
	my $class = shift;
	
	if (@_ % 2) {
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	my %params = @_;
	my $self = {};
	
	$self->{Kp} = $params{P};
	$self->{Ki} = $params{I};
	$self->{Kd} = $params{D};
	
	$self->{sample_time} = 0;
	$self->{current_time} = Time::HiRes::gettimeofday();
	$self->{last_time} = $self->{current_time};
	
	bless $self, $class;
	
	$self->clear();
	
	return $self;
	
}

sub clear {
	# Clears PID computations and coefficients
	
	my $self = shift;
	$self->{SetPoint} = 0.0;
	$self->{PTerm} = 0.0;
	$self->{ITerm} = 0.0;
	$self->{DTerm} = 0.0;
	$self->{last_error} = 0.0;

	# Windup Guard
	$self->{int_error} = 0.0;
	$self->{windup_guard} = 20.0;
	
	$self->{output} = 0.0;
	return $self->{output};

}

sub update {
	# Calculates PID value for given reference feedback
	# 	u(t) = K_p e(t) + K_i \int_{0}^{t} e(t)dt + K_d {de}/{dt}
	# 	Test PID with Kp=1.2, Ki=1, Kd=0.001
	
	my $self = shift;
	my $feedback_value = shift;
	my $current_time = shift;
	
	my $error = defined $self->{setPoint} ? $self->{setPoint} - $feedback_value : -$feedback_value;
	
	$self->{current_time} = Time::HiRes::gettimeofday();
	my $delta_time = $self->{current_time} - $self->{last_time};
	my $delta_error = $error - $self->{last_error};
	
	if( $delta_time >= $self->{sample_time}) {
		$self->{PTerm} = $self->{Kp} * $error;
		$self->{ITerm} += $error * $delta_time;
		
		if( $self->{ITerm} < -$self->{windup_guard} ) {
			$self->{ITerm} = -$self->{windup_guard};
		} elsif ($self->{ITerm} > $self->{windup_guard} ) {
			$self->{ITerm} = $self->{windup_guard};
		}
		
		$self->{DTerm} = 0;
		if ($delta_time > 0 ) {
			$self->{DTerm} = $delta_error / $delta_time;
		}
		
		# Remember last time and last error for next calculation
		$self->{last_time} = $self->{current_time};
		$self->{last_error} = $error;

		$self->{output} = $self->{PTerm} + ($self->{Ki} * $self->{ITerm}) + ($self->{Kd} * $self->{DTerm});
		return $self->{output};
		
		
	}
}

sub setKp {
	# Determines how aggressively the PID reacts to the current error with setting Proportional Gain
	my $self = shift;
	my $proportional_gain = shift;
	$self->{Kp} = $proportional_gain;
}

sub setKi {
	# Determines how aggressively the PID reacts to the current error with setting Integral Gain
	my $self = shift;
	my $integral_gain = shift;
	$self->{Ki} = $integral_gain;
}

sub setKd {
	# Determines how aggressively the PID reacts to the current error with setting Derivative Gain
	my $self = shift;
	my $derivative_gain = shift;
	$self->{Kd} = $derivative_gain;
}
	
sub setWindup {
	# Integral windup, also known as integrator windup or reset windup,
	# refers to the situation in a PID feedback controller where
	# a large change in setpoint occurs (say a positive change)
	# and the integral terms accumulates a significant error
	# during the rise (windup), thus overshooting and continuing
	# to increase as this accumulated error is unwound
	# (offset by errors in the other direction).
	# The specific problem is the excess overshooting.

	my $self = shift;
	my $windup = shift;
	$self->{windup_guard} = $windup;
}

sub setSampleTime {
	# PID that should be updated at a regular interval.
	# Based on a pre-determined sampe time, the PID decides if it should compute or return immediately.
	
	my $self = shift;
	my $sample_time = shift;
	$self->{sample_time} = $sample_time;
}





# === FINALLY 1 ===
1;

