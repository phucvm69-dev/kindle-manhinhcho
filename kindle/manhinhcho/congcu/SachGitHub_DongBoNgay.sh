#!/bin/sh
# Name: Sach GitHub - DONG BO NGAY
# Author: kindle-manhinhcho

. /mnt/us/manhinhcho/chung.sh
if [ ! -s $D/token.txt ]; then
    echo "Chua co token.txt trong thu muc manhinhcho."
    sleep 5; exit 1
fi
echo "Dang dong bo sach tu GitHub..."
truoc=$(wc -l < $D/da_tai.txt 2>/dev/null || echo 0)
if bat_wifi; then
    dong_bo_sach
    tai_anh
fi
tra_wifi
sau=$(wc -l < $D/da_tai.txt 2>/dev/null || echo 0)
echo "Xong: $((sau - truoc)) cuon moi."
tail -5 $LOG
sleep 6
