#!/bin/bash
rm /dev/shm/dummyfile
touch /dev/shm/dummyfile
du -h /dev/shm/dummyfile
free -m
echo "--------------------------"
while [ true ] ; do
	dd if=/dev/urandom conv=notrunc oflag=append of=/dev/shm/dummyfile bs=1 count=10240000 > /dev/null 2>&1
	du -h /dev/shm/dummyfile
	free -m
	echo "--------------------------"
done
