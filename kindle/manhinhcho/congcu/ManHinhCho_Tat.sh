#!/bin/sh
# Name: Man hinh cho - TAT
# Author: kindle-manhinhcho

# Go han: dung dich vu, tra lai man hinh khoa goc, khong tu chay khi khoi dong nua.
D=/mnt/us/manhinhcho
initctl stop manhinhcho >/dev/null 2>&1
[ -f /var/local/manhinhcho/pid ] && kill $(cat /var/local/manhinhcho/pid) 2>/dev/null
pkill -f manhinhcho.sh 2>/dev/null
sleep 1
umount /usr/share/blanket/screensaver 2>/dev/null
# go sach ban cai trong /var/local (chi khi da tra lai man hinh khoa goc)
mount | grep -q " /usr/share/blanket/screensaver " || rm -rf /var/local/manhinhcho
if [ -f /etc/upstart/manhinhcho.conf ]; then
    mntroot rw && rm -f /etc/upstart/manhinhcho.conf
    mntroot ro
fi
rm -f /var/local/manhinhcho/pid
echo "Da TAT man hinh cho lich."
echo "Kindle tro ve man hinh khoa mac dinh."
sleep 5
