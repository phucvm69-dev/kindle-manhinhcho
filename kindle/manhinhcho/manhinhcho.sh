#!/bin/sh
# Chay ngam: ve anh lich len man hinh cho; dinh ky tu thuc day cap nhat anh + sach.
. /mnt/us/manhinhcho/chung.sh
echo $$ > $D/pid

tuoi() { echo $(( $(date +%s) - $(cat $D/last 2>/dev/null || echo 0) )); }

la_ban_dem() {   # $1 = gio (0-23)
    if [ $GIO_NGU -gt $GIO_THUC ]; then [ $1 -ge $GIO_NGU ] || [ $1 -lt $GIO_THUC ]
    else [ $1 -ge $GIO_NGU ] && [ $1 -lt $GIO_THUC ]; fi
}

# So giay toi lan thuc day ke tiep (bo qua ban dem)
lan_toi() {
    h=$(date +%H); m=$(date +%M); s=$(date +%S)
    giay=$(( ${h#0} * 3600 + ${m#0} * 60 + ${s#0} ))
    con=$(( CHU_KY - $(tuoi) ))
    [ $con -lt 300 ] && con=300
    gio_toi=$(( ((giay + con) % 86400) / 3600 ))
    if la_ban_dem $gio_toi || la_ban_dem ${h#0}; then
        con=$(( (GIO_THUC * 3600 - giay + 86400) % 86400 + 120 ))
    fi
    echo $con
}

log "bat dau (pid $$), chu ky ${CHU_KY}s, nghi ${GIO_NGU}h-${GIO_THUC}h"
while true; do
    EV=$(lipc-wait-event com.lab126.powerd goingToScreenSaver,readyToSuspend,wakeupFromSuspend 2>/dev/null)
    case "$EV" in
        goingToScreenSaver*)
            sleep 2; ve
            if [ $(tuoi) -ge $CHU_KY ]; then cap_nhat; dang_cho && ve; fi
            ;;
        readyToSuspend*)
            con=$(lan_toi)
            lipc-set-prop -i com.lab126.powerd rtcWakeup $con >/dev/null 2>&1
            log "ngu, hen thuc sau $((con / 60)) phut"
            ;;
        wakeupFromSuspend*)
            if dang_cho && [ $(tuoi) -ge $(( CHU_KY - 600 )) ]; then cap_nhat; dang_cho && ve; fi
            ;;
        "") sleep 5 ;;
    esac
done
