#!/bin/bash

###########################################################
# Calls per Minute
INTERVAL=200

# Pause between Call blocks/after 1 minute
PAUSE=60

# Call Blocks
MAX=10

# Logfile
LOGFILE="rc_log_brute.csv"

# MS Serial No.
SERIAL="504XXXXXXFB9"
###########################################################

SLEEPTIME=`echo "60/$INTERVAL" | bc -l`
LOOPS=1
INT=1

until [ $LOOPS -gt $MAX ]
do
	echo
	echo "--> Start Block $LOOPS of $MAX"
	echo
	INT=1
	until [ $INT -gt $INTERVAL ]
	do
		DATE=`date +"%d.%m.%Y %T.%3N"`
		echo -n "$DATE Call $INT: "
		DATA=`curl "http://dns.loxonecloud.com/?getip&snr=504F94A00FB9&json=true" 2>/dev/null`
		echo $DATA
		echo -n $DATE >> $LOGFILE
		echo -n "|" >> $LOGFILE
		echo $DATA >> $LOGFILE
		INT=$[$INT+1]
		sleep $SLEEPTIME
	done
	echo
	echo "--> Sleep after Block $LOOPS: $PAUSE sec."
	echo
	sleep $PAUSE
	LOOPS=$[$LOOPS+1]
done
