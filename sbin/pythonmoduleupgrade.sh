#!/bin/bash

ID=$(id -u)
if [ "$ID" != "0" ] ; then
	echo "This script has to be run as root. Exiting."
	exit 1
fi

if [ "$1" != "python2" ] && [ "$1" != "python3" ]; then
	echo "Usage: $0 [python2|python3] [backup|restore] <file>."
	exit 1
fi

if [ "$2" != "restore" ] && [ "$2" != "backup" ]; then
	echo "Usage: $0 [python2|python3] [backup|restore] <file>."
	exit 1
fi

if [ -z "$3" ]; then
	echo "Usage: $0 [python2|python3] [backup|restore] <file>."
	exit 1
fi

if [ "$1" = "python2" ]; then
	PYTHON=$(which python2)
elif [ "$1" = "python3" ]; then
	PYTHON=$(which python3)
else
	PYTHON=""
fi

if [ -z "$PYTHON" ]; then
	echo "Usage: $0 [python2|python3] [backup|restore] <file>."
	exit 1
fi

case $2 in
restore)
	if [ ! -e $3 ]; then
		echo "$3: No such file or directory"
		exit 1
	fi
	cat $3 | cut -d = -f 1 | xargs -n1 $PYTHON -m pip install
	mv $3 $3.old
	;;

backup)
	$PYTHON -m pip list --format=freeze > $3
	;;

*)
	echo "Usage: $0 [python2|python3] [backup|restore] <file>."
	exit 1
	;;

esac

exit 0
