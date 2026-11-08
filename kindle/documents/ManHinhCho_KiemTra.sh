#!/bin/sh
# Name: Man hinh cho - KIEM TRA HE THONG
# Author: kindle-manhinhcho
# DontUseFBInk

# Chi doc thong tin he thong ra file, khong sua gi.
OUT=/mnt/us/manhinhcho/kiemtra.log
{
  echo "=== $(date)"
  echo "--- blanket screensaver"; ls -la /usr/share/blanket/screensaver/ 2>&1 | head -40
  echo "--- blanket dirs"; ls /usr/share/blanket/ 2>&1
  echo "--- mounts"; mount 2>&1 | grep -E " / |blanket|/mnt/us|/var/local"
  echo "--- upstart"; ls -la /etc/upstart/ 2>&1
  echo "--- upstart co nhac jailbreak/kpm/hotfix"; grep -l -i -E "jailbreak|kpm|hotfix|libkh|mkk|sh_integration" /etc/upstart/* 2>/dev/null
  for f in $(grep -l -i -E "jailbreak|kpm|hotfix|libkh|sh_integration" /etc/upstart/* 2>/dev/null); do echo "##### $f"; head -40 "$f"; done
  echo "--- var/local/mkk"; ls -la /var/local/mkk 2>&1 | head
  echo "--- kmc"; ls /var/local/kmc 2>&1 | head
  echo "--- libkh"; ls -R /mnt/us/libkh 2>&1 | head -20
  echo "--- kpm"; which kpm 2>&1; ls /mnt/us/kpm /var/local/kpm 2>&1 | head
  echo "--- ads"; ls /var/local/adunits 2>&1 | head -5
  echo "--- blanket props"; lipc-probe com.lab126.blanket 2>&1 | head -40
  echo "--- powerd props"; lipc-probe com.lab126.powerd 2>&1 | grep -i -E "rtc|defer|wake|suspend" | head -20
  echo "--- scanner"; lipc-probe com.lab126.scanner 2>&1 | head -20
  echo "--- mntroot"; which mntroot 2>&1
  echo "--- daemon dang chay?"; ps 2>/dev/null | grep -v grep | grep manhinhcho
  echo "--- log"; tail -20 /mnt/us/manhinhcho/log.txt 2>&1
} > $OUT 2>&1
echo "=== xong" >> $OUT
