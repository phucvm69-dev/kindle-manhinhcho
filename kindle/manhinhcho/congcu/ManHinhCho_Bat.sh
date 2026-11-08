#!/bin/sh
# Name: Man hinh cho - BAT
# Author: kindle-manhinhcho

# Cai dich vu tu chay khi khoi dong + bat ngay. Chay lai de ap dung cau hinh moi.
D=/mnt/us/manhinhcho
CONF=/etc/upstart/manhinhcho.conf

# dung ban cu chay tu scriptlet (neu con)
if [ -f /var/local/manhinhcho/pid ] && kill -0 $(cat /var/local/manhinhcho/pid) 2>/dev/null && ! initctl status manhinhcho 2>/dev/null | grep -q running; then
    kill $(cat /var/local/manhinhcho/pid) 2>/dev/null
fi

if ! cmp -s $D/manhinhcho.conf $CONF; then
    mntroot rw && cp $D/manhinhcho.conf $CONF && chmod 644 $CONF
    mntroot ro
    initctl reload-configuration >/dev/null 2>&1
fi
if [ ! -f $CONF ]; then
    echo "LOI: khong cai duoc dich vu."; sleep 6; exit 1
fi

rm -f /var/local/manhinhcho/last          # tai anh ngay lan ngu dau tien
initctl stop manhinhcho >/dev/null 2>&1
sleep 1
initctl start manhinhcho >/dev/null 2>&1
sleep 3
if initctl status manhinhcho 2>/dev/null | grep -q running; then
    echo "Da BAT man hinh cho lich."
    echo "Tu chay lai moi khi khoi dong may."
    echo "Bam nut nguon de xem."
else
    echo "LOI: dich vu khong chay. Xem $D/log.txt"
fi
tail -3 $D/log.txt 2>/dev/null
sleep 5
