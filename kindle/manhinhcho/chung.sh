# Ham dung chung cho man hinh cho + dong bo sach
# Ban chay that nam o /var/local/manhinhcho (chi root ghi duoc), cai bang "Man hinh cho - BAT".
D=/mnt/us/manhinhcho          # thu muc cua ban (USB): token, log, cau hinh
R=/var/local/manhinhcho       # code + anh + chung chi (khong ai sua qua USB duoc)
mkdir -p $R && chmod 700 $R
IMG=$R/bg.png
LOG=$D/log.txt
CACERT=$R/cacert.pem

log() {
    [ -d $D ] || return 0          # dang o che do USB
    echo "$(date '+%m-%d %H:%M:%S') $*" >> $LOG
    if [ $(wc -l < $LOG) -gt 150 ]; then tail -100 $LOG > $LOG.tmp && mv $LOG.tmp $LOG; fi
}

# --- Cau hinh: DOC tung gia tri va KIEM TRA, khong chay file cau hinh nhu code ---
cfg() {   # cfg TEN MAC_DINH MAU(regex)
    v=$(sed -n "s/^$1=[\"']\{0,1\}\([^\"' #]*\).*/\1/p" $D/cauhinh.txt 2>/dev/null | tail -1)
    if [ -n "$v" ] && echo "$v" | grep -qE "^($3)\$"; then echo "$v"; else echo "$2"; fi
}
doc_cau_hinh() {
    [ -f $D/cauhinh.txt ] || return 0      # che do USB: giu gia tri cu
    URL_ANH=$(cfg URL_ANH "https://phucvm69-dev.github.io/kindle-manhinhcho/bg.png" 'https://[A-Za-z0-9.-]+/[A-Za-z0-9._/~-]*')
    CHU_KY=$(cfg CHU_KY 21600 '[0-9]{3,6}')
    GIO_NGU=$(cfg GIO_NGU 23 '[0-9]|1[0-9]|2[0-3]')
    GIO_THUC=$(cfg GIO_THUC 6 '[0-9]|1[0-9]|2[0-3]')
    REPO_SACH=$(cfg REPO_SACH "phucvm69-dev/kindle-sach" '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+')
    VE_DE=$(cfg VE_DE 1 '[01]')
    DONG_BO_KHI_MO=$(cfg DONG_BO_KHI_MO 1800 '[0-9]{1,6}')
    LAM_MOI_KHI_MO=$(cfg LAM_MOI_KHI_MO 1800 '[0-9]{1,6}')
    [ $CHU_KY -lt 900 ] && CHU_KY=900       # it nhat 15 phut, tranh hao pin
}
THU_MUC_SACH=/mnt/us/documents/Sach-GitHub
doc_cau_hinh

dang_cho() { lipc-get-prop com.lab126.powerd status 2>/dev/null | grep -q "Screen Saver"; }

ve() { [ -s $IMG ] && /usr/sbin/eips -f -g $IMG >/dev/null 2>&1; }

# --- HTTPS bat buoc xac thuc chung chi (chong gia mao Wi-Fi / an cap token) ---
tai() {   # tai URL FILE_RA [them tham so curl...]  -> in ma HTTP
    u=$1; o=$2; shift 2
    [ -s $CACERT ] || { echo "nocert"; return; }
    curl -sL --proto '=https' --proto-redir '=https' --cacert $CACERT \
         --max-filesize 104857600 -m 600 -w "%{http_code}" "$@" "$u" -o "$o"
}

# --- Wi-Fi: bat khi can, tra ve trang thai cu sau khi xong ---
WIFI_TRUOC=""
cho_ket_noi() {   # cho toi da $1 giay, giu may khong ngu trong luc cho
    j=0
    while [ $j -lt $1 ]; do
        [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ] && return 0
        [ $((j % 15)) -eq 0 ] && lipc-set-prop com.lab126.powerd deferSuspend 120 >/dev/null 2>&1
        sleep 1; j=$((j + 1))
    done
    return 1
}
bat_wifi() {
    WIFI_TRUOC=$(lipc-get-prop com.lab126.cmd wirelessEnable 2>/dev/null)
    t0=$(date +%s)
    [ "$WIFI_TRUOC" = "0" ] && lipc-set-prop com.lab126.cmd wirelessEnable 1
    if cho_ket_noi 30; then sleep 2; log "wifi: OK ($(( $(date +%s) - t0 ))s)"; return 0; fi
    s1=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)
    # cach 2: tat roi bat lai Wi-Fi de ep ket noi lai
    lipc-set-prop com.lab126.cmd wirelessEnable 0; sleep 3
    lipc-set-prop com.lab126.cmd wirelessEnable 1
    if cho_ket_noi 45; then
        sleep 2; log "wifi: OK sau khi bat lai ($(( $(date +%s) - t0 ))s, truoc do $s1)"; return 0
    fi
    log "wifi khong ket noi duoc (wifi truoc=$WIFI_TRUOC, $s1 -> $(lipc-get-prop com.lab126.wifid cmState 2>/dev/null), $(lipc-get-prop com.lab126.powerd status 2>/dev/null | head -1))"
    # ghi ten cac thuoc tinh cua dich vu Wi-Fi mot lan de chan doan (chi ten, khong co mat khau)
    [ -f $D/wifid_probe.txt ] || lipc-probe com.lab126.wifid > $D/wifid_probe.txt 2>&1
    return 1
}
tra_wifi() { [ "$WIFI_TRUOC" = "0" ] && lipc-set-prop com.lab126.cmd wirelessEnable 0; }

tai_anh() {
    ma=$(tai "$URL_ANH?t=$(date +%s)" $IMG.tmp --max-filesize 5000000)
    # chi nhan dung file PNG (8 byte dau)
    if [ "$ma" = "200" ] && [ "$(head -c 8 $IMG.tmp 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]; then
        mv $IMG.tmp $IMG; date +%s > $R/last; log "anh: OK"; return 0
    else
        rm -f $IMG.tmp; log "anh: LOI tai (HTTP $ma)"; return 1
    fi
}

# --- Dong bo sach mot chieu GitHub -> Kindle ---
# Nho ma bam cac sach da tai trong da_tai.txt: xoa tren Kindle se khong bi tai lai.
# Moi dong trong danh sach deu duoc kiem tra truoc khi ghi file (chong ghi de file he thong).
hop_le() {   # hop_le sha duong ten
    echo "$1" | grep -qE '^[0-9a-f]{40}$' || return 1
    echo "$2" | grep -qE '^(sach|kindle)/[A-Za-z0-9%._~/-]+$' || return 1
    case "$2$3" in *..*) return 1 ;; esac
    case "$3" in /*|*/./*|"") return 1 ;; esac
    echo "$3" | grep -qiE '\.(azw3|azw|mobi|kfx|pdf|txt)$' || return 1
    return 0
}

dong_bo_sach() {
    TOKEN=$(tr -cd 'A-Za-z0-9_' < $D/token.txt 2>/dev/null)
    [ -z "$TOKEN" ] && return 0
    API="https://api.github.com/repos/$REPO_SACH/contents"
    HDR=$R/.hdr                       # token nam trong file root-only, khong lo tren dong lenh
    umask 077
    printf 'Authorization: Bearer %s\nAccept: application/vnd.github.raw\n' "$TOKEN" > $HDR
    TOKEN=""
    ma=$(tai "$API/kindle/danh_sach.txt" $R/ds.tmp -H @$HDR --max-filesize 2000000)
    if [ "$ma" != "200" ]; then
        case "$ma" in
            401) ly="token sai hoac het han" ;;
            403|404) ly="token khong co quyen doc kho $REPO_SACH (can Contents: Read-only)" ;;
            000) ly="khong ket noi duoc GitHub (hoac chung chi khong hop le)" ;;
            nocert) ly="thieu file chung chi, bam BAT de cai lai" ;;
            *) ly="loi khac" ;;
        esac
        log "sach: LOI tai danh sach - HTTP $ma: $ly"
        rm -f $R/ds.tmp $HDR; return 1
    fi
    date +%s > $R/last_sach
    touch $D/da_tai.txt
    moi=0
    while IFS="	" read -r sha duong ten; do
        [ -z "$sha" ] && continue
        if ! hop_le "$sha" "$duong" "$ten"; then log "sach: BO QUA dong khong hop le"; continue; fi
        grep -q "^$sha\$" $D/da_tai.txt && continue
        dich="$THU_MUC_SACH/$ten"
        mkdir -p "$(dirname "$dich")"
        lipc-set-prop com.lab126.powerd deferSuspend 300 >/dev/null 2>&1
        ma=$(tai "https://api.github.com/repos/$REPO_SACH/contents/$duong" "$dich.tmp" -H @$HDR)
        if [ "$ma" = "200" ] && [ -s "$dich.tmp" ]; then
            mv "$dich.tmp" "$dich"
            echo "$sha" >> $D/da_tai.txt
            moi=$((moi + 1)); log "sach: + $ten"
        else
            rm -f "$dich.tmp"; log "sach: LOI tai $ten (HTTP $ma)"
        fi
    done < $R/ds.tmp
    rm -f $R/ds.tmp $HDR
    if [ $moi -gt 0 ]; then
        lipc-set-prop com.lab126.scanner doFullScan 1 >/dev/null 2>&1
        log "sach: da tai $moi cuon moi"
    fi
    return 0
}

# Mot lan cap nhat day du: wifi -> anh -> sach -> tra wifi
cap_nhat() {
    date +%s > $R/last_thu        # thoi diem THU (thanh cong ghi rieng vao last)
    lipc-set-prop com.lab126.powerd deferSuspend 120 >/dev/null 2>&1
    if bat_wifi; then
        tai_anh
        dong_bo_sach
    fi
    tra_wifi
}
