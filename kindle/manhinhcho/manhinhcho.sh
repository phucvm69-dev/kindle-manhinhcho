#!/bin/sh
# Dich vu man hinh cho lich (chay boi upstart: /etc/upstart/manhinhcho.conf)
# - Thay anh man hinh khoa mac dinh bang anh lich (bind mount, khong sua file goc)
# - Dinh ky tu thuc day: tai anh moi + dong bo sach
. /var/local/manhinhcho/chung.sh     # ban da cai bang BAT, khong doc code tu USB
echo $$ > $R/pid
rmdir $R/dang_cap_nhat 2>/dev/null   # xoa khoa cu neu lan truoc bi ngat giua chung
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

tuoi() { echo $(( $(date +%s) - $(cat $R/last 2>/dev/null || echo 0) )); }          # tu lan tai anh THANH CONG
tuoi_thu() { echo $(( $(date +%s) - $(cat $R/last_thu 2>/dev/null || echo 0) )); }  # tu lan THU (bat wifi) gan nhat
tuoi_sach() { echo $(( $(date +%s) - $(cat $R/last_sach 2>/dev/null || echo 0) )); }
can_lam_gi() { den_han || [ $(tuoi) -ge ${LAM_MOI_KHI_MO:-1800} ] || [ $(tuoi_sach) -ge ${DONG_BO_KHI_MO:-1800} ]; }
den_han() { [ $(tuoi) -ge $(( CHU_KY - 300 )) ]; }                                   # da den gio cap nhat anh
co_mang() { [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ]; }

la_ban_dem() {
    if [ $GIO_NGU -gt $GIO_THUC ]; then [ $1 -ge $GIO_NGU ] || [ $1 -lt $GIO_THUC ]
    else [ $1 -ge $GIO_NGU ] && [ $1 -lt $GIO_THUC ]; fi
}

# So giay toi lan tu thuc day ke tiep:
#  - binh thuong: CHU_KY tinh tu lan tai THANH CONG gan nhat
#  - neu dang no (lan truoc khong co mang): thu lai sau CHU_KY tinh tu lan thu gan nhat
#  - khong thuc day ban dem
lan_toi() {
    h=$(date +%H); m=$(date +%M); s=$(date +%S)
    giay=$(( ${h#0} * 3600 + ${m#0} * 60 + ${s#0} ))
    if den_han; then con=$(( CHU_KY - $(tuoi_thu) )); else con=$(( CHU_KY - $(tuoi) )); fi
    [ $con -lt 300 ] && con=300
    gio_toi=$(( ((giay + con) % 86400) / 3600 ))
    if la_ban_dem $gio_toi || la_ban_dem ${h#0}; then
        con=$(( (GIO_THUC * 3600 - giay + 86400) % 86400 + 120 ))
    fi
    echo $con
}

# Tranh thu khi DANG CO MANG (khong tu bat wifi): tai anh neu den han, dong bo sach neu lau chua lam
tranh_thu() {
    co_mang || return 1
    mkdir $R/dang_cap_nhat 2>/dev/null || return 0
    if den_han; then
        log "co mang tro lai, tai bu"
        tai_anh && dong_bo_sach
        dang_cho && ve
    elif [ $(tuoi) -ge ${LAM_MOI_KHI_MO:-1800} ]; then
        log "dang co mang, lam moi anh"
        tai_anh
        [ $(tuoi_sach) -ge ${DONG_BO_KHI_MO:-1800} ] && dong_bo_sach
        dang_cho && ve
    elif [ $(tuoi_sach) -ge ${DONG_BO_KHI_MO:-1800} ]; then
        dong_bo_sach
    fi
    rmdir $R/dang_cap_nhat
    return 0
}

# Khi may dang mo (khong o man hinh khoa): cu 20 giay xem co mang chua, co la tai bu ngay
canh_mang() {
    mkdir $R/canh 2>/dev/null || return 0
    k=0
    while [ $k -lt 540 ]; do                      # toi da ~3 gio
        dang_cho && break
        can_lam_gi || break
        co_mang && { tranh_thu; break; }
        sleep 20; k=$((k + 1))
    done
    rmdir $R/canh
}

WPID=""
dung() { [ -n "$WPID" ] && kill $WPID 2>/dev/null; go_man_hinh_khoa; rm -f $R/pid; exit 0; }
trap dung TERM INT

log "bat dau (pid $$), chu ky ${CHU_KY}s, nghi ${GIO_NGU}h-${GIO_THUC}h"
gan_man_hinh_khoa
rmdir $R/canh 2>/dev/null
dang_cho || canh_mang &
EVF=/tmp/manhinhcho.ev

while true; do
    doc_cau_hinh                          # doc lai cau hinh (chi lay gia tri, co kiem tra)
    # chay nen + wait de nhan duoc tin hieu dung ngay lap tuc
    lipc-wait-event com.lab126.powerd goingToScreenSaver,outOfScreenSaver,readyToSuspend,wakeupFromSuspend > $EVF 2>/dev/null &
    WPID=$!
    wait $WPID
    WPID=""
    EV=$(cat $EVF 2>/dev/null)
    case "$EV" in
        goingToScreenSaver*)
            log "vao man hinh cho"
            ( if [ "$VE_DE" = "1" ]; then sleep 4; dang_cho && ve; fi
              can_lam_gi && tranh_thu ) &       # dang co mang luc khoa may: tai bu / lam moi luon
            ;;
        outOfScreenSaver*)
            canh_mang &                          # mo may: co mang la tai bu ngay
            ;;
        readyToSuspend*)
            con=$(lan_toi)
            lipc-set-prop -i com.lab126.powerd rtcWakeup $con >/dev/null 2>&1
            [ "$((con / 60))" != "$DA_LOG" ] && log "ngu, hen thuc sau $((con / 60)) phut"
            DA_LOG=$((con / 60))
            ;;
        wakeupFromSuspend*)
            log "thuc day"
            DA_LOG=""
            # den gio theo lich: tu bat wifi de tai (that bai thi cho lan co mang tiep theo)
            if dang_cho && den_han && [ $(tuoi_thu) -ge 1200 ] && mkdir $R/dang_cap_nhat 2>/dev/null; then
                ( cap_nhat; dang_cho && ve; rmdir $R/dang_cap_nhat ) &
            fi
            ;;
        *) sleep 5 ;;
    esac
done
