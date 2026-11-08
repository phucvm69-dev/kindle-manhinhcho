#!/bin/sh
# Name: Man hinh cho - TAT
# Author: kindle-manhinhcho

D=/mnt/us/manhinhcho
[ -f $D/pid ] && kill $(cat $D/pid) 2>/dev/null
pkill -f manhinhcho.sh 2>/dev/null
rm -f $D/pid
echo "Da TAT man hinh cho lich. Kindle tro ve man hinh cho mac dinh."
sleep 4
