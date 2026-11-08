#!/bin/sh
# Name: Man hinh cho - CHAY THU
# Author: kindle-manhinhcho
# DontUseFBInk

# Chi chay thu: ve anh lich len man hinh + ghi thong tin may ra log. Khong cai gi.
D=/mnt/us/manhinhcho
LOG=$D/chaythu.log
mkdir -p $D
{
  echo "=== $(date)"
  echo "--- id"; id
  echo "--- uname"; uname -a
  echo "--- eips -i"; /usr/sbin/eips -i 2>&1 | head -20
  echo "--- fbink -e"; /mnt/us/libkh/bin/fbink -e 2>&1 | head -5
  echo "--- powerd status"; lipc-get-prop com.lab126.powerd status 2>&1 | head -5
  echo "--- wirelessEnable"; lipc-get-prop com.lab126.cmd wirelessEnable 2>&1
  echo "--- wifid cmState"; lipc-get-prop com.lab126.wifid cmState 2>&1
  echo "--- curl"; curl --version 2>&1 | head -2
  echo "--- which"; which curl wget ping eips lipc-wait-event lipc-set-prop 2>&1
  echo "--- rtc"; ls /sys/class/rtc/ 2>&1; ls /sys/devices/platform/ 2>&1 | grep -i rtc
  echo "--- df"; df -h /mnt/us 2>&1
  echo "--- ve anh"
  /usr/sbin/eips -f -g $D/bg.png 2>&1; echo "eips exit=$?"
} > $LOG 2>&1
sleep 15
/usr/sbin/eips -f -c 2>/dev/null
echo "=== xong" >> $LOG
