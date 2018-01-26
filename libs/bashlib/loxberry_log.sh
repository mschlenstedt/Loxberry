#only works in bash scripting

function LOGDEB { 
	if [ "$LOGLEVEL" -gt 6 ]
	then
	  if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		WRITE "<DEBUG> $CURRTIME$@"
	fi
}
function LOGINF { 
	if [ "$LOGLEVEL" -gt 5 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		WRITE "<INFO> $CURRTIME$@"
	fi
}
function LOGOK { 
	if [ "$LOGLEVEL" -gt 4 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		WRITE "<OK> $CURRTIME$@"
	fi
}
function LOGWARN { 
	if [ "$LOGLEVEL" -gt 3 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		WRITE "<WARNING> $CURRTIME$@"
	fi
}
function LOGERR { 
	if [ "$LOGLEVEL" -gt 2 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		WRITE "<ERROR> $CURRTIME$@"
	fi
}
function LOGCRIT { 
	if [ "$LOGLEVEL" -gt 1 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		WRITE "<CRITICAL> $CURRTIME$@"
	fi
}
function LOGALERT { 
	if [ "$LOGLEVEL" -gt 0 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		WRITE "<ALERT> $CURRTIME$@"
	fi
}
function LOGEMERGE { 
	if [ "$LOGLEVEL" -ge 0 ]
	then
		if [ -n "$ADDTIME" ];then CURRTIME=$(date +"%H:%M:%S ");else CURRTIME=""; fi
		WRITE "<EMERGE> $CURRTIME$@"
	fi
}
function LOGSTART {
	if [ -n "$PACKAGE" ] && [ -n "$NAME" ] && ([ -n "$FILENAME" ] || [ -n "$NOFILE" ])
	then
		if [ -n "$STDERR" ];then PARAM=" --stderr"; fi
		#if [ -n "$NOFILE" ];then PARAM="$PARAM --nofile";else PARAM="$PARAM --filename=$FILENAME"; fi
		LOG=(`$LBHOMEDIR/libs/bashlib/initlog.pl --name=$NAME --package=$PACKAGE$PARAM --message=$@`)
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
			WRITE "<LOGEND>$@"
			WRITE "<LOGEND>"$(date +"%d.%m.%Y %H:%M:%S")" TASK FINISHED"
	fi
}
function WRITE {
		if [ -n "$NOFILE" ];then echo "$@"; fi
		if [ -n "$STDERR" ] || ([ -z ${NOFILE+x} ] && [ -z ${FILENAME+x} ]);then echo "$@" 1>&2; fi
		if [ -z ${NOFILE+x} ] && [ -n "$FILENAME" ];then echo "$@" >> $FILENAME; fi
}	