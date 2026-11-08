#!/bin/sh
# Name: Man hinh cho - BAT / CAP NHAT
# Author: kindle-manhinhcho

# Cai (hoac cap nhat) dich vu: chep code tu USB vao /var/local (root-only), tu chay khi khoi dong.
D=/mnt/us/manhinhcho
R=/var/local/manhinhcho
CONF=/etc/upstart/manhinhcho.conf

for f in manhinhcho.sh chung.sh cacert.pem manhinhcho.conf cauhinh.txt; do
    [ -s $D/$f ] || { echo "LOI: thieu $D/$f"; sleep 6; exit 1; }
done

initctl stop manhinhcho >/dev/null 2>&1
[ -f $R/pid ] && kill $(cat $R/pid) 2>/dev/null
sleep 1

mkdir -p $R && chmod 700 $R
cp $D/manhinhcho.sh $D/chung.sh $D/cacert.pem $R/ && chmod 600 $R/*.sh $R/cacert.pem
[ -s $R/bg.png ] || cp $D/bg.png $R/bg.png 2>/dev/null

if ! cmp -s $D/manhinhcho.conf $CONF; then
    mntroot rw && cp $D/manhinhcho.conf $CONF && chmod 644 $CONF
    mntroot ro
    initctl reload-configuration >/dev/null 2>&1
fi
[ -f $CONF ] || { echo "LOI: khong cai duoc dich vu."; sleep 6; exit 1; }

rm -f $R/last $R/cauhinh.sh $D/cauhinh.sh $D/pid $D/last   # don file kieu cu
initctl start manhinhcho >/dev/null 2>&1
sleep 3
if initctl status manhinhcho 2>/dev/null | grep -q running; then
    echo "Da BAT / CAP NHAT man hinh cho lich."
    echo "Tu chay lai moi khi khoi dong may."
else
    echo "LOI: dich vu khong chay. Xem $D/log.txt"
fi
tail -3 $D/log.txt 2>/dev/null
sleep 5
