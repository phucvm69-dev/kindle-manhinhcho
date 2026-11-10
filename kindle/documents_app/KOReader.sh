#!/bin/sh
# Name: KOReader
# Author: koreader.rocks
# DontUseFBInk

# Mo trinh doc KOReader (cai thu cong vao /mnt/us/koreader).
# Thoat KOReader: cham canh tren man hinh -> bieu tuong banh rang -> Exit.
if [ ! -x /mnt/us/koreader/koreader.sh ]; then
    eips 2 10 "Chua cai KOReader (/mnt/us/koreader)" >/dev/null 2>&1
    sleep 4; exit 1
fi
cd /
setsid /mnt/us/koreader/koreader.sh --kual >/dev/null 2>&1 < /dev/null &
exit 0
