#!/bin/sh
# Dich vu man hinh cho lich (chay boi upstart: /etc/upstart/manhinhcho.conf)
# - Thay anh man hinh khoa mac dinh bang anh lich (bind mount, khong sua file goc)
# - Dinh ky tu thuc day: tai anh moi + dong bo sach
. /var/local/manhinhcho/chung.sh
echo $$ > $R/pid
[ -s $IMG ] || cp $D/bg.png $IMG 2>/dev/null

SS_GOC=/usr/share/blanket/screensaver
SS_MOI=/var/local/manhinhcho/ss

gan_man_hinh_khoa() {
    mount | grep -q " $SS_GOC " && return 0
    mkdir -p $SS_MOI
    # giu nguyen cac anh khac (che do tre em...), thay bg_ssNN bang anh lich
    for f in $SS_GOC/*; do
        b=$(basename "$f")
        case "$b" in
            bg_ss[0-9][0-9].png) ln -sf $IMG "$SS_MOI/$b" ;;
            *) [ -e "$SS_MOI/$b" ] || cp -p "$f" "$SS_MOI/$b" ;;
        esac
    done
    if mount --bind $SS_MOI $SS_GOC; then
        log "da thay anh man hinh khoa ($(ls $SS_MOI | grep -c '^bg_ss') anh)"
    else
        log "LOI: khong thay duoc anh man hinh khoa"
    fi
}

go_man_hinh_khoa() { umount $SS_GOC 2>/dev/null && log "tra lai man hinh khoa goc"; }

tuoi() { echo $(( $(date +%s) - $(cat $R/last 2>/dev/null || echo 0) )); }

la_ban_dem() {
    if [ $GIO_NGU -gt $GIO_THUC ]; then [ $1 -ge $GIO_NGU ] || [ $1 -lt $GIO_THUC ]
    else [ $1 -ge $GIO_NGU ] && [ $1 -lt $GIO_THUC ]; fi
}

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

WPID=""
dung() { [ -n "$WPID" ] && kill $WPID 2>/dev/null; go_man_hinh_khoa; rm -f $R/pid; exit 0; }
trap dung TERM INT

log "bat dau (pid $$), chu ky ${CHU_KY}s, nghi ${GIO_NGU}h-${GIO_THUC}h"
gan_man_hinh_khoa
EVF=/tmp/manhinhcho.ev
ban_code() { stat -c %Y $D/manhinhcho.sh $D/chung.sh 2>/dev/null | tr '\n' ' '; }
BAN_DAU=$(ban_code)
tuoi_sach() { echo $(( $(date +%s) - $(cat $R/last_sach 2>/dev/null || echo 0) )); }

while true; do
    # doc lai cau hinh moi vong (neu khong o che do USB)
    [ -f $D/cauhinh.sh ] && cp $D/cauhinh.sh $R/cauhinh.sh 2>/dev/null
    . $R/cauhinh.sh
    MOI=$(ban_code)
    if [ -n "$BAN_DAU" ] && [ -n "$MOI" ] && [ "$MOI" != "$BAN_DAU" ]; then
        log "co ban code moi, khoi dong lai"
        exit 1                            # upstart (respawn) se chay lai ban moi
    fi
    # chay nen + wait de nhan duoc tin hieu dung ngay lap tuc
    lipc-wait-event com.lab126.powerd goingToScreenSaver,outOfScreenSaver,readyToSuspend,wakeupFromSuspend > $EVF 2>/dev/null &
    WPID=$!
    wait $WPID
    WPID=""
    EV=$(cat $EVF 2>/dev/null)
    case "$EV" in
        goingToScreenSaver*)
            log "vao man hinh cho"
            if [ "$VE_DE" = "1" ]; then sleep 4; dang_cho && ve && log "ve de: OK"; fi
            if [ $(tuoi) -ge $CHU_KY ]; then cap_nhat; dang_cho && ve; fi
            ;;
        outOfScreenSaver*)
            # mo khoa may: neu wifi dang bat san va lau chua dong bo -> dong bo sach (khong ton them pin)
            if [ "$(lipc-get-prop com.lab126.cmd wirelessEnable 2>/dev/null)" = "1" ] && \
               [ $(tuoi_sach) -ge ${DONG_BO_KHI_MO:-1800} ]; then
                ( sleep 5
                  [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ] && dong_bo_sach ) &
            fi
            ;;
        readyToSuspend*)
            con=$(lan_toi)
            lipc-set-prop -i com.lab126.powerd rtcWakeup $con >/dev/null 2>&1
            log "ngu, hen thuc sau $((con / 60)) phut"
            ;;
        wakeupFromSuspend*)
            log "thuc day"
            if dang_cho && [ $(tuoi) -ge $(( CHU_KY - 600 )) ]; then cap_nhat; dang_cho && ve; fi
            ;;
        *) sleep 5 ;;
    esac
done
