#only works in bash scripting

function LOGDEB { 
	if [ "$LOGLVL" -gt 6 ]
	then
		echo "<DEBUG>$@" >> $LOGFILE
	fi
}
function LOGINF { 
	if [ "$LOGLVL" -gt 5 ]
	then
		echo "<INFO>$@" >> $LOGFILE
	fi
}
function LOGOK { 
	if [ "$LOGLVL" -gt 4 ]
	then
		echo "<OK>$@" >> $LOGFILE
	fi
}
function LOGWARN { 
	if [ "$LOGLVL" -gt 3 ]
	then
		echo "<WARNING>$@" >> $LOGFILE
	fi
}
function LOGERR { 
	if [ "$LOGLVL" -gt 2 ]
	then
		echo "<ERROR>$@" >> $LOGFILE
	fi
}
function LOGCRIT { 
	if [ "$LOGLVL" -gt 1 ]
	then
		echo "<CRITICAL>$@" >> $LOGFILE
	fi
}
function LOGALERT { 
	if [ "$LOGLVL" -gt 0 ]
	then
		echo "<ALERT>$@" >> $LOGFILE
	fi
}
function LOGEMERGE { 
	if [ "$LOGLVL" -ge 0 ]
	then
		echo "<EMERGE>$@" >> $LOGFILE
	fi
}
function LOGSTART { 
	
}
function LOGEND {
	if [ "$LOGLVL" -ge -1 ]
	then
		echo "<LOGEND>$@" >> $LOGFILE
		echo "<LOGEND>"$(date +"%d.%m.%Y %H:%M:%S")" TASK FINISHED" >> $LOGFILE
	fi
}
