
# Response hash
# status: 	0 / undef = ERROR
# 			1		  = WARNING
#			2 		  = OK
# title: Name of the test
# desc: Description of the test (opt.)
# result: Text result
# url: URL to a wiki page with help (opt.)
# logfile: Path to a logfile


my @checkresults;

## Run checks
push(@checkresults, check_logdb());


## Process results

results_shell();


exit;









###################################################
## CHECK LogDB
###################################################

sub check_logdb
{
	
	my %response;
	$response{title} = "Log Database";
	$response{desc} = "Checks the consistence of the Logfile Database.";
	$response{url} = "https://www.loxwiki.eu/x/oIMKAw";
	
	eval {
	
		require LoxBerry::Log;
		my $dbh = LoxBerry::Log::log_db_init_database();
		if (! $dbh) {
			$response{result} = "Could not init logfile database";
		} else {
			$response{result} = "Init logfile database ok";
			$response{status} = 2;
		}
	
	};
	if ($@) {
		$response{status} = 0;
		$response{result} = "Error executing the test: $@";
	}

	return \%response;

}
	

#######################################################
## RESULT PROCESSING
#######################################################

sub results_shell
{
	foreach my $result (@checkresults) {
		if( !defined $result->{status} ) {
			$result->{status} = 0;
		}
		print "Check: " . $result->{title} . "\n";
		print "Status: ERROR\n" if ($result->{status} == 0);
		print "Status: WARNING\n" if ($result->{status} == 1);
		print "Status: SUCCESS\n" if ($result->{status} == 2);
		print "Result: " . $result->{result} . "\n";
		print "URL: " . $result->{url} . "\n" if ( $result->{url} );
		print "Logfile: " . $result->{logfile} . "\n" if( $result->{logfile} ); 


	}



}