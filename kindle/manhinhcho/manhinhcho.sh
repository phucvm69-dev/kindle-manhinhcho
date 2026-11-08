#!/bin/sh
# Chay ngam: ve anh lich len man hinh cho, moi gio tu thuc day tai anh moi.
D=/mnt/us/manhinhcho
IMG=$D/bg.png
LOG=$D/log.txt
INTERVAL=3600                       # giay giua 2 lan tai anh
URL=$(cat $D/url.txt 2>/dev/null | tr -d '\r\n ')

echo $$ > $D/pid

log() {
    echo "$(date '+%m-%d %H:%M:%S') $*" >> $LOG
    # giu log gon (toi da ~300 dong)
    if [ $(wc -l < $LOG) -gt 400 ]; then tail -300 $LOG > $LOG.tmp && mv $LOG.tmp $LOG; fi
}

dang_cho() { lipc-get-prop com.lab126.powerd status 2>/dev/null | grep -q "Screen Saver"; }

ve() { [ -s $IMG ] && /usr/sbin/eips -f -g $IMG >/dev/null 2>&1; }

tuoi() {   # so giay ke tu lan tai gan nhat
    echo $(( $(date +%s) - $(cat $D/last 2>/dev/null || echo 0) ))
}

tai_anh() {
    [ -z "$URL" ] && { log "chua co url.txt"; return; }
    date +%s > $D/last
    lipc-set-prop com.lab126.powerd deferSuspend 60 >/dev/null 2>&1
    WIFI_TRUOC=$(lipc-get-prop com.lab126.cmd wirelessEnable 2>/dev/null)
    [ "$WIFI_TRUOC" = "0" ] && lipc-set-prop com.lab126.cmd wirelessEnable 1
    i=0
    while [ $i -lt 40 ]; do
        [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ] && break
        sleep 1; i=$((i + 1))
    done
    sleep 2
    if curl -sfL -k -m 40 "$URL?t=$(date +%s)" -o $IMG.tmp && [ -s $IMG.tmp ]; then
        mv $IMG.tmp $IMG
        log "tai anh OK (cho wifi ${i}s)"
    else
        rm -f $IMG.tmp
        log "tai anh LOI (wifi=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null))"
    fi
    [ "$WIFI_TRUOC" = "0" ] && lipc-set-prop com.lab126.cmd wirelessEnable 0
}

log "bat dau (pid $$)"
while true; do
    EV=$(lipc-wait-event com.lab126.powerd goingToScreenSaver,readyToSuspend,wakeupFromSuspend 2>/dev/null)
    case "$EV" in
        goingToScreenSaver*)
            sleep 2; ve
            if [ $(tuoi) -ge $INTERVAL ]; then tai_anh; dang_cho && ve; fi
            ;;
        readyToSuspend*)
            con=$(( INTERVAL - $(tuoi) ))
            [ $con -lt 120 ] && con=120
            lipc-set-prop -i com.lab126.powerd rtcWakeup $con >/dev/null 2>&1
            log "ngu, hen thuc sau ${con}s"
            ;;
        wakeupFromSuspend*)
            if dang_cho && [ $(tuoi) -ge $(( INTERVAL - 180 )) ]; then tai_anh; dang_cho && ve; fi
            ;;
        "") sleep 5 ;;
    esac
done
