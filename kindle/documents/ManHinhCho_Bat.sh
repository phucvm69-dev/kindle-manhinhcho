#!/bin/sh
# Name: Man hinh cho - BAT
# Author: kindle-manhinhcho

D=/mnt/us/manhinhcho
if [ -f $D/pid ] && kill -0 $(cat $D/pid) 2>/dev/null; then
    kill $(cat $D/pid) 2>/dev/null
    sleep 1
fi
rm -f $D/last          # tai anh ngay lan ngu dau tien
setsid sh $D/manhinhcho.sh >/dev/null 2>&1 < /dev/null &
sleep 2
if [ -f $D/pid ] && kill -0 $(cat $D/pid) 2>/dev/null; then
    echo "Da BAT man hinh cho lich."
    echo "Bam nut nguon de thu."
    echo "(Sau khi khoi dong lai Kindle, bam muc nay lan nua.)"
else
    echo "LOI: khong chay duoc. Xem $D/log.txt"
fi
sleep 4
