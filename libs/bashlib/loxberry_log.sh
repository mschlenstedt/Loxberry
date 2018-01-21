#only works in bash scripting

function LOGDEB { 
	if [ "$LOGLEVEL" -gt 6 ]
	then
		if [ -z ${ADDTIME+x} ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		echo "<DEBUG> $CURRTIME$@" >> $LOGFILE
	fi
}
function LOGINF { 
	if [ "$LOGLEVEL" -gt 5 ]
	then
		if [ -z ${ADDTIME+x} ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		echo "<INFO> $CURRTIME$@" >> $LOGFILE
	fi
}
function LOGOK { 
	if [ "$LOGLEVEL" -gt 4 ]
	then
		if [ -z ${ADDTIME+x} ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		echo "<OK> $CURRTIME$@" >> $LOGFILE
	fi
}
function LOGWARN { 
	if [ "$LOGLEVEL" -gt 3 ]
	then
		if [ -z ${ADDTIME+x} ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		echo "<WARNING> $CURRTIME$@" >> $LOGFILE
	fi
}
function LOGERR { 
	if [ "$LOGLEVEL" -gt 2 ]
	then
		if [ -z ${ADDTIME+x} ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		echo "<ERROR> $CURRTIME$@" >> $LOGFILE
	fi
}
function LOGCRIT { 
	if [ "$LOGLEVEL" -gt 1 ]
	then
		if [ -z ${ADDTIME+x} ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		echo "<CRITICAL> $CURRTIME$@" >> $LOGFILE
	fi
}
function LOGALERT { 
	if [ "$LOGLEVEL" -gt 0 ]
	then
		if [ -z ${ADDTIME+x} ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		echo "<ALERT> $CURRTIME$@" >> $LOGFILE
	fi
}
function LOGEMERGE { 
	if [ "$LOGLEVEL" -ge 0 ]
	then
		if [ -z ${ADDTIME+x} ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		echo "<EMERGE> $CURRTIME$@" >> $LOGFILE
	fi
}
function LOGSTART {
	if [ -n "$LOGPACKAGE" ] && [ -n "$LOGNAME" ]
	then
		echo "$LOGNAME:$LOGPACKAGE:$@\n"
		LOG=(`./initlog.pl --name=$LOGNAME --package=$LOGPACKAGE --message=\"$@\"`)
		LOGFILE=${LOG[0]//\"}
		if [ -z ${LOGLEVEL+x} ];then LOGLEVEL=${LOG[1]}; fi
		if [ -z ${LOGFILE+x} ] || [ -z ${LOGLEVEL} ]
		then
			echo "Log could not be startet" 1>&2
			exit 1
		fi
	else
		echo "Log could not be set because LOGPACKAGE and/or LOGNAME is not given" 1>&2
		exit 1
	fi
}
function LOGEND {
	if [ "$LOGLEVEL" -ge -1 ]
	then
		echo "<LOGEND>$@" >> $LOGFILE
		echo "<LOGEND>"$(date +"%d.%m.%Y %H:%M:%S")" TASK FINISHED" >> $LOGFILE
	fi
}
