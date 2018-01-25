#only works in bash scripting

function LOGDEB { 
	if [ "$LOGLEVEL" -gt 6 ]
	then
	  if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		if [ -n "$NOFILE" ];then
			echo "<DEBUG> $CURRTIME$@"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<DEBUG> $CURRTIME$@" 1>&2
		else
			echo "<DEBUG> $CURRTIME$@" >> $FILENAME
		fi	fi
}
function LOGINF { 
	if [ "$LOGLEVEL" -gt 5 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		if [ -n "$NOFILE" ];then
			echo "<INFO> $CURRTIME$@"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<INFO> $CURRTIME$@" 1>&2
		else
			echo "<INFO> $CURRTIME$@" >> $FILENAME
		fi
	fi
}
function LOGOK { 
	if [ "$LOGLEVEL" -gt 4 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		if [ -n "$NOFILE" ];then
			echo "<OK> $CURRTIME$@"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<OK> $CURRTIME$@" 1>&2
		else
			echo "<OK> $CURRTIME$@" >> $FILENAME
		fi
	fi
}
function LOGWARN { 
	if [ "$LOGLEVEL" -gt 3 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		if [ -n "$NOFILE" ];then
			echo "<WARNING> $CURRTIME$@"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<WARNING> $CURRTIME$@" 1>&2
		else
			echo "<WARNING> $CURRTIME$@" >> $FILENAME
		fi
	fi
}
function LOGERR { 
	if [ "$LOGLEVEL" -gt 2 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		if [ -n "$NOFILE" ];then
			echo "<ERROR> $CURRTIME$@"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<ERROR> $CURRTIME$@" 1>&2
		else
			echo "<ERROR> $CURRTIME$@" >> $FILENAME
		fi
	fi
}
function LOGCRIT { 
	if [ "$LOGLEVEL" -gt 1 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		if [ -n "$NOFILE" ];then
			echo "<CRITICAL> $CURRTIME$@"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<CRITICAL> $CURRTIME$@" 1>&2
		else
			echo "<CRITICAL> $CURRTIME$@" >> $FILENAME
		fi
	fi
}
function LOGALERT { 
	if [ "$LOGLEVEL" -gt 0 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		if [ -n "$NOFILE" ];then
			echo "<ALERT> $CURRTIME$@"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<ALERT> $CURRTIME$@" 1>&2
		else
			echo "<ALERT> $CURRTIME$@" >> $FILENAME
		fi
	fi
}
function LOGEMERGE { 
	if [ "$LOGLEVEL" -ge 0 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		if [ -n "$NOFILE" ];then
			echo "<EMERGE> $CURRTIME$@"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<EMERGE> $CURRTIME$@" 1>&2
		else
			echo "<EMERGE> $CURRTIME$@" >> $FILENAME
		fi
	fi
}
function LOGSTART {
	if [ -n "$PACKAGE" ] && [ -n "$NAME" ] && ([ -n "$FILENAME" ] || [ -n "$NOFILE" ] || [-n "$STDERR" ])
	then
		if [ -n "$STDERR" ];then
			PARAM=--stderr
		elif [ -n "$NOFILE" ];then
			PARAM=--nofile
		fi
		LOG=(`$LBHOMEDIR/libs/bashlib/initlog.pl --name=$NAME --package=$PACKAGE --filename=$FILENAME $PARAM --message=$@`)
		FILENAME=${LOG[0]//\"}
		if [ -z ${LOGLEVEL+x} ];then LOGLEVEL=${LOG[1]}; fi
		if [ -z ${FILENAME+x} ] || [ -z ${LOGLEVEL+x} ]
		then
			echo "Log could not be startet" 1>&2
			exit 1
		fi
	else
		echo "Log could not be set because PACKAGE and/or NAME is not given" 1>&2
		exit 1
	fi
}
function LOGEND {
	if [ "$LOGLEVEL" -ge -1 ]
	then
		if [ -n "$NOFILE" ];then
			echo "<LOGEND>$@"
			echo "<LOGEND>"$(date +"%d.%m.%Y %H:%M:%S")" TASK FINISHED"
		elif [ -n "$STDERR" ] || [ -z ${FILENAME+x} ];then
			echo "<LOGEND>$@" 1>&2
			echo "<LOGEND>"$(date +"%d.%m.%Y %H:%M:%S")" TASK FINISHED" 1>&2
		else
			echo "<LOGEND>$@" >> $FILENAME
			echo "<LOGEND>"$(date +"%d.%m.%Y %H:%M:%S")" TASK FINISHED" >> $FILENAME
		fi
	fi
}
