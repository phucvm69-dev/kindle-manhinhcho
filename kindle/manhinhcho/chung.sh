# Ham dung chung cho man hinh cho + dong bo sach
D=/mnt/us/manhinhcho
IMG=$D/bg.png
LOG=$D/log.txt
. $D/cauhinh.sh

log() {
    echo "$(date '+%m-%d %H:%M:%S') $*" >> $LOG
    if [ $(wc -l < $LOG) -gt 400 ]; then tail -300 $LOG > $LOG.tmp && mv $LOG.tmp $LOG; fi
}

dang_cho() { lipc-get-prop com.lab126.powerd status 2>/dev/null | grep -q "Screen Saver"; }

ve() { [ -s $IMG ] && /usr/sbin/eips -f -g $IMG >/dev/null 2>&1; }

# --- Wi-Fi: bat khi can, tra ve trang thai cu sau khi xong ---
WIFI_TRUOC=""
bat_wifi() {
    WIFI_TRUOC=$(lipc-get-prop com.lab126.cmd wirelessEnable 2>/dev/null)
    [ "$WIFI_TRUOC" = "0" ] && lipc-set-prop com.lab126.cmd wirelessEnable 1
    i=0
    while [ $i -lt 40 ]; do
        [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = "CONNECTED" ] && { sleep 2; return 0; }
        sleep 1; i=$((i + 1))
    done
    log "wifi khong ket noi duoc"
    return 1
}
tra_wifi() { [ "$WIFI_TRUOC" = "0" ] && lipc-set-prop com.lab126.cmd wirelessEnable 0; }

tai_anh() {
    if curl -sfL -k -m 40 "$URL_ANH?t=$(date +%s)" -o $IMG.tmp && [ -s $IMG.tmp ]; then
        mv $IMG.tmp $IMG; log "anh: OK"
    else
        rm -f $IMG.tmp; log "anh: LOI tai"
    fi
}

# --- Dong bo sach mot chieu GitHub -> Kindle ---
# Nho ma bam cac sach da tai trong da_tai.txt: xoa tren Kindle se khong bi tai lai.
dong_bo_sach() {
    TOKEN=$(cat $D/token.txt 2>/dev/null | tr -cd 'A-Za-z0-9_')
    [ -z "$TOKEN" ] && return 0
    API="https://api.github.com/repos/$REPO_SACH/contents"
    H1="Authorization: Bearer $TOKEN"
    H2="Accept: application/vnd.github.raw"
    if ! curl -sfL -k -m 30 -H "$H1" -H "$H2" "$API/kindle/danh_sach.txt" -o $D/ds.tmp; then
        log "sach: LOI tai danh sach (kiem tra token.txt)"; return 1
    fi
    touch $D/da_tai.txt
    moi=0
    while IFS="	" read -r sha duong ten; do
        [ -z "$sha" ] && continue
        grep -q "^$sha\$" $D/da_tai.txt && continue
        dich="$THU_MUC_SACH/$ten"
        mkdir -p "$(dirname "$dich")"
        lipc-set-prop com.lab126.powerd deferSuspend 300 >/dev/null 2>&1
        if curl -sfL -k -m 600 -H "$H1" -H "$H2" "$API/$duong" -o "$dich.tmp" && [ -s "$dich.tmp" ]; then
            mv "$dich.tmp" "$dich"
            echo "$sha" >> $D/da_tai.txt
            moi=$((moi + 1)); log "sach: + $ten"
        else
            rm -f "$dich.tmp"; log "sach: LOI tai $ten"
        fi
    done < $D/ds.tmp
    rm -f $D/ds.tmp
    if [ $moi -gt 0 ]; then
        lipc-set-prop com.lab126.scanner doFullScan 1 >/dev/null 2>&1
        log "sach: da tai $moi cuon moi"
    fi
    return 0
}

# Mot lan cap nhat day du: wifi -> anh -> sach -> tra wifi
cap_nhat() {
    date +%s > $D/last
    lipc-set-prop com.lab126.powerd deferSuspend 90 >/dev/null 2>&1
    if bat_wifi; then
        tai_anh
        dong_bo_sach
    fi
    tra_wifi
}
