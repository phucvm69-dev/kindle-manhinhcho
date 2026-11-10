# -*- coding: utf-8 -*-
"""
Tạo ảnh màn hình chờ cho Kindle Oasis 3 (1264x1680, đen trắng):
lịch dương, lịch âm Việt Nam (thuật toán Hồ Ngọc Đức, GMT+7), thời tiết (Open-Meteo),
giá vàng miếng SJC và nhẫn trơn 999.9 (nguồn PNJ).

Chạy:  python tao_man_hinh_cho.py            -> tạo bg_ss00.png cạnh file script
       python tao_man_hinh_cho.py 2026-02-17 -> xem thử một ngày bất kỳ
"""
import json
import math
import os
import sys
import urllib.request
from datetime import date, datetime, timedelta, timezone

from PIL import Image, ImageDraw, ImageFont

# ======================= CẤU HÌNH =======================
THANH_PHO = "Hà Nội"
VI_DO, KINH_DO = 21.0285, 105.8542
RONG, CAO = 1264, 1680              # Kindle Oasis 3
THU_MUC = os.path.dirname(os.path.abspath(__file__))
FILE_RA = os.environ.get("FILE_RA", os.path.join(THU_MUC, "bg_ss00.png"))
FONT_DIR = os.path.join(THU_MUC, "fonts")
GIO_VN = timezone(timedelta(hours=7))   # Việt Nam không đổi giờ mùa hè
# ========================================================

TZ = 7
PI = math.pi


# ---------------- LỊCH ÂM (Hồ Ngọc Đức) ----------------
def jd_from_date(dd, mm, yy):
    a = (14 - mm) // 12
    y = yy + 4800 - a
    m = mm + 12 * a - 3
    jd = dd + (153 * m + 2) // 5 + 365 * y + y // 4 - y // 100 + y // 400 - 32045
    if jd < 2299161:
        jd = dd + (153 * m + 2) // 5 + 365 * y + y // 4 - 32083
    return jd


def new_moon_day(k):
    T = k / 1236.85
    T2, T3 = T * T, T * T * T
    dr = PI / 180
    jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3
    jd1 += 0.00033 * math.sin((166.56 + 132.87 * T - 0.009173 * T2) * dr)
    M = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3
    Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3
    F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3
    C1 = (0.1734 - 0.000393 * T) * math.sin(M * dr) + 0.0021 * math.sin(2 * dr * M)
    C1 -= 0.4068 * math.sin(Mpr * dr) - 0.0161 * math.sin(dr * 2 * Mpr)
    C1 -= 0.0004 * math.sin(dr * 3 * Mpr)
    C1 += 0.0104 * math.sin(dr * 2 * F) - 0.0051 * math.sin(dr * (M + Mpr))
    C1 -= 0.0074 * math.sin(dr * (M - Mpr)) - 0.0004 * math.sin(dr * (2 * F + M))
    C1 -= 0.0004 * math.sin(dr * (2 * F - M)) + 0.0006 * math.sin(dr * (2 * F + Mpr))
    C1 += 0.0010 * math.sin(dr * (2 * F - Mpr)) + 0.0005 * math.sin(dr * (2 * Mpr + M))
    if T < -11:
        deltat = 0.001 + 0.000839 * T + 0.0002261 * T2 - 0.00000845 * T3 - 0.000000081 * T * T3
    else:
        deltat = -0.000278 + 0.000265 * T + 0.000262 * T2
    return math.floor(jd1 + C1 - deltat + 0.5 + TZ / 24)


def sun_longitude_rad(jdn):
    T = (jdn - 2451545.5 - TZ / 24) / 36525
    T2 = T * T
    dr = PI / 180
    M = 357.52910 + 35999.05030 * T - 0.0001559 * T2 - 0.00000048 * T * T2
    L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2
    DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * math.sin(dr * M)
    DL += (0.019993 - 0.000101 * T) * math.sin(dr * 2 * M) + 0.000290 * math.sin(dr * 3 * M)
    L = (L0 + DL) * dr
    return L - 2 * PI * math.floor(L / (2 * PI))


def sun_longitude(jdn):
    return math.floor(sun_longitude_rad(jdn) / PI * 6)


def lunar_month11(yy):
    off = jd_from_date(31, 12, yy) - 2415021
    k = math.floor(off / 29.530588853)
    nm = new_moon_day(k)
    if sun_longitude(nm) >= 9:
        nm = new_moon_day(k - 1)
    return nm


def leap_month_offset(a11):
    k = math.floor((a11 - 2415021.076998695) / 29.530588853 + 0.5)
    i = 1
    arc = sun_longitude(new_moon_day(k + i))
    while True:
        last = arc
        i += 1
        arc = sun_longitude(new_moon_day(k + i))
        if not (arc != last and i < 14):
            break
    return i - 1


def solar_to_lunar(dd, mm, yy):
    """Trả về (ngày, tháng, năm, nhuận, số ngày của tháng âm)."""
    day_number = jd_from_date(dd, mm, yy)
    k = math.floor((day_number - 2415021.076998695) / 29.530588853)
    month_start = new_moon_day(k + 1)
    if month_start > day_number:
        month_start = new_moon_day(k)
        next_start = new_moon_day(k + 1)
    else:
        next_start = new_moon_day(k + 2)
    a11 = lunar_month11(yy)
    b11 = a11
    if a11 >= month_start:
        lunar_year = yy
        a11 = lunar_month11(yy - 1)
    else:
        lunar_year = yy + 1
        b11 = lunar_month11(yy + 1)
    lunar_day = day_number - month_start + 1
    diff = math.floor((month_start - a11) / 29)
    leap = 0
    lunar_month = diff + 11
    if b11 - a11 > 365:
        lmd = leap_month_offset(a11)
        if diff >= lmd:
            lunar_month = diff + 10
            if diff == lmd:
                leap = 1
    if lunar_month > 12:
        lunar_month -= 12
    if lunar_month >= 11 and diff < 4:
        lunar_year -= 1
    return lunar_day, lunar_month, lunar_year, leap, next_start - month_start


CAN = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"]
CHI = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"]
THANG_AM = ["Giêng", "Hai", "Ba", "Tư", "Năm", "Sáu", "Bảy", "Tám", "Chín", "Mười", "Mười Một", "Chạp"]
TIET_KHI = ["Xuân phân", "Thanh minh", "Cốc vũ", "Lập hạ", "Tiểu mãn", "Mang chủng",
            "Hạ chí", "Tiểu thử", "Đại thử", "Lập thu", "Xử thử", "Bạch lộ",
            "Thu phân", "Hàn lộ", "Sương giáng", "Lập đông", "Tiểu tuyết", "Đại tuyết",
            "Đông chí", "Tiểu hàn", "Đại hàn", "Lập xuân", "Vũ thủy", "Kinh trập"]
GIO_HD = ["110100101100", "001101001011", "110011010010",
          "101100110100", "001011001101", "010010110011"]
THU = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"]
THU_NGAN = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

LE_DUONG = {(1, 1): "Tết Dương lịch", (14, 2): "Lễ Tình nhân", (8, 3): "Quốc tế Phụ nữ",
            (30, 4): "Giải phóng miền Nam", (1, 5): "Quốc tế Lao động", (1, 6): "Quốc tế Thiếu nhi",
            (2, 9): "Quốc khánh", (20, 10): "Phụ nữ Việt Nam", (20, 11): "Nhà giáo Việt Nam",
            (22, 12): "Quân đội Nhân dân", (24, 12): "Giáng sinh"}
LE_AM = {(1, 1): "Tết Nguyên Đán", (2, 1): "Mùng 2 Tết", (3, 1): "Mùng 3 Tết",
         (15, 1): "Rằm tháng Giêng", (3, 3): "Tết Hàn thực", (10, 3): "Giỗ Tổ Hùng Vương",
         (15, 4): "Lễ Phật đản", (5, 5): "Tết Đoan ngọ", (15, 7): "Lễ Vu lan",
         (15, 8): "Tết Trung thu", (9, 9): "Tết Trùng cửu", (10, 10): "Tết Thường tân",
         (23, 12): "Ông Công Ông Táo"}


def thong_tin_am(d: date):
    ld, lm, ly, leap, so_ngay = solar_to_lunar(d.day, d.month, d.year)
    jd = jd_from_date(d.day, d.month, d.year)
    chi_ngay = (jd + 1) % 12
    gio_hd = [CHI[i] for i, c in enumerate(GIO_HD[chi_ngay % 6]) if c == "1"]
    return {
        "ngay": ld, "thang": lm, "nam": ly, "nhuan": leap, "so_ngay": so_ngay,
        "can_chi_ngay": f"{CAN[(jd + 9) % 10]} {CHI[chi_ngay]}",
        "can_chi_thang": f"{CAN[(ly * 12 + lm + 3) % 10]} {CHI[(lm + 1) % 12]}",
        "can_chi_nam": f"{CAN[(ly + 6) % 10]} {CHI[(ly + 8) % 12]}",
        "tiet_khi": TIET_KHI[math.floor(sun_longitude_rad(jd + 1) / PI * 12)],
        "gio_hd": gio_hd,
    }


# ---------------- THỜI TIẾT ----------------
def lay_thoi_tiet():
    url = ("https://api.open-meteo.com/v1/forecast"
           f"?latitude={VI_DO}&longitude={KINH_DO}"
           "&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
           "weather_code,wind_speed_10m,is_day"
           "&daily=weather_code,temperature_2m_max,temperature_2m_min,"
           "precipitation_probability_max"
           "&timezone=Asia%2FHo_Chi_Minh&forecast_days=8")
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception as e:
        print("Không lấy được thời tiết:", e)
        return None


def mo_ta_thoi_tiet(code):
    if code == 0: return "Trời quang", "nang"
    if code in (1, 2): return ("Ít mây" if code == 1 else "Có mây"), "it_may"
    if code == 3: return "Nhiều mây", "may"
    if code in (45, 48): return "Sương mù", "suong"
    if code in (51, 53, 55, 56, 57): return "Mưa phùn", "mua"
    if code in (61, 63, 80, 81): return "Mưa", "mua"
    if code in (65, 82, 66, 67): return "Mưa to", "mua"
    if code in (71, 73, 75, 77, 85, 86): return "Tuyết", "may"
    if code in (95, 96, 99): return "Dông", "dong"
    return "—", "may"


# ---------------- VẼ ----------------
DEN, XAM_DAM, XAM, XAM_NHAT, TRANG = 0, 0x44, 0x80, 0xC8, 255


def font(ten, co):
    return ImageFont.truetype(os.path.join(FONT_DIR, ten), co)


F_LIGHT, F_REG, F_SEMI, F_BOLD = ("BeVietnamPro-Light.ttf", "BeVietnamPro-Regular.ttf",
                                  "BeVietnamPro-SemiBold.ttf", "BeVietnamPro-Bold.ttf")


def chu(dr, xy, text, f, fill=DEN, anchor="la"):
    dr.text(xy, text, font=f, fill=fill, anchor=anchor)


def ve_may(dr, cx, cy, s, fill=TRANG, vien=DEN, w=None):
    """Đám mây tâm (cx, cy), rộng ~ 2s."""
    w = w or max(3, int(s * 0.07))
    parts = [(cx - s * 0.55, cy + s * 0.05, s * 0.42), (cx - s * 0.05, cy - s * 0.2, s * 0.55),
             (cx + s * 0.55, cy + s * 0.1, s * 0.38)]
    # viền
    for x, y, r in parts:
        dr.ellipse([x - r - w, y - r - w, x + r + w, y + r + w], fill=vien)
    dr.rounded_rectangle([cx - s * 0.97 - w, cy + s * 0.05 - w, cx + s * 0.93 + w, cy + s * 0.47 + w],
                         radius=s * 0.21 + w, fill=vien)
    # ruột
    for x, y, r in parts:
        dr.ellipse([x - r, y - r, x + r, y + r], fill=fill)
    dr.rounded_rectangle([cx - s * 0.97, cy + s * 0.05, cx + s * 0.93, cy + s * 0.47],
                         radius=s * 0.21, fill=fill)


def ve_mat_troi(dr, cx, cy, s, ngay=True):
    if not ngay:
        r = s * 0.55
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=DEN)
        dr.ellipse([cx - r + s * 0.35, cy - r - s * 0.15, cx + r + s * 0.35, cy + r - s * 0.15], fill=TRANG)
        return
    r = s * 0.42
    w = max(3, int(s * 0.09))
    for i in range(8):
        a = i * PI / 4
        x1, y1 = cx + math.cos(a) * s * 0.6, cy + math.sin(a) * s * 0.6
        x2, y2 = cx + math.cos(a) * s * 0.88, cy + math.sin(a) * s * 0.88
        dr.line([x1, y1, x2, y2], fill=DEN, width=w)
    dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=DEN)


def ve_icon(dr, loai, cx, cy, s, ngay=True):
    if loai == "nang":
        ve_mat_troi(dr, cx, cy, s, ngay)
    elif loai == "it_may":
        ve_mat_troi(dr, cx - s * 0.3, cy - s * 0.3, s * 0.7, ngay)
        ve_may(dr, cx + s * 0.1, cy + s * 0.15, s * 0.7)
    elif loai == "may":
        ve_may(dr, cx, cy, s * 0.85, fill=XAM_NHAT)
    elif loai == "suong":
        w = max(3, int(s * 0.1))
        for i, dx in enumerate([0, s * 0.2, -s * 0.1, s * 0.1]):
            y = cy - s * 0.45 + i * s * 0.3
            dr.line([cx - s * 0.8 + dx, y, cx + s * 0.6 + dx, y], fill=DEN, width=w)
    elif loai in ("mua", "dong"):
        ve_may(dr, cx, cy - s * 0.25, s * 0.8, fill=XAM_NHAT)
        w = max(3, int(s * 0.08))
        if loai == "mua":
            for dx in (-0.45, 0, 0.45):
                x = cx + dx * s
                dr.line([x, cy + s * 0.35, x - s * 0.15, cy + s * 0.75], fill=DEN, width=w)
        else:
            x = cx
            dr.polygon([(x + s * 0.05, cy + s * 0.25), (x - s * 0.25, cy + s * 0.6), (x, cy + s * 0.6),
                        (x - s * 0.15, cy + s * 0.95), (x + s * 0.3, cy + s * 0.48),
                        (x + s * 0.05, cy + s * 0.48)], fill=DEN)


def ke_ngang(dr, y, x1=80, x2=RONG - 80, fill=DEN, w=3):
    dr.line([x1, y, x2, y], fill=fill, width=w)


# ---------------- GIÁ VÀNG (PNJ) ----------------
FILE_LS_VANG = os.environ.get("FILE_LS_VANG", os.path.join(THU_MUC, "gia_vang_lich_su.json"))
LOAI_VANG = [("SJC", "Vàng miếng SJC"), ("N24K", "Nhẫn trơn 999.9")]


def lay_gia_vang():
    """Giá theo nghìn đồng/chỉ, kèm giờ cập nhật và giá ngày trước (để tính tăng/giảm)."""
    try:
        with open(FILE_LS_VANG, encoding="utf-8") as f:
            ls = json.load(f)
    except Exception:
        ls = {}
    moi, gio, cu = None, None, False
    try:
        req = urllib.request.Request("https://edge-api.pnj.io/ecom-frontend/v1/get-gold-price?zone=00",
                                     headers={"User-Agent": "kindle-screensaver"})
        with urllib.request.urlopen(req, timeout=20) as r:
            d = json.loads(r.read().decode("utf-8"))
        ma_can = dict(LOAI_VANG)
        moi = {x["masp"]: [float(x["giamua"]), float(x["giaban"])]
               for x in d["data"] if x["masp"] in ma_can}
        gio = d.get("updateDate", "")
        ls[datetime.now(GIO_VN).date().isoformat()] = {"gia": moi, "gio": gio}
        with open(FILE_LS_VANG, "w", encoding="utf-8") as f:
            json.dump(dict(sorted(ls.items())[-60:]), f, ensure_ascii=False, indent=1)
    except Exception as e:
        print("Không lấy được giá vàng:", e)
        if ls:
            k = max(ls)
            moi, gio, cu = ls[k]["gia"], ls[k]["gio"], True
    if not moi:
        return None
    hom_nay = datetime.now(GIO_VN).date().isoformat()
    truoc = [k for k in ls if k < hom_nay]
    gia_truoc = ls[max(truoc)]["gia"] if truoc else None
    return {"gia": moi, "gio": gio, "cu": cu, "truoc": gia_truoc}


def trieu_luong(v):
    """nghìn đồng/chỉ -> triệu đồng/lượng, VD 14100 -> '141,0'."""
    s = f"{v / 100:.2f}".rstrip("0")
    if s.endswith("."):
        s += "0"
    return s.replace(".", ",")


# ---------------- NGÀY TỐT XẤU (lịch vạn niên) ----------------
# Sao trực ngày: tháng âm lịch 1&7 khởi Thanh Long ở ngày Tý, 2&8 ở Dần, 3&9 Thìn, 4&10 Ngọ, 5&11 Thân, 6&12 Tuất.
# Đã đối chiếu 8/8 ngày công bố tháng 10/2026.
SAO = [("Thanh Long", True), ("Minh Đường", True), ("Thiên Hình", False), ("Chu Tước", False),
       ("Kim Quỹ", True), ("Kim Đường", True), ("Bạch Hổ", False), ("Ngọc Đường", True),
       ("Thiên Lao", False), ("Huyền Vũ", False), ("Tư Mệnh", True), ("Câu Trận", False)]
TRUC = ["Kiến", "Trừ", "Mãn", "Bình", "Định", "Chấp", "Phá", "Nguy", "Thành", "Thu", "Khai", "Bế"]
HY_THAN = ["Đông Bắc", "Tây Bắc", "Tây Nam", "Chính Nam", "Đông Nam"]   # theo can ngày (Giáp/Kỷ, Ất/Canh, ...)


def tot_xau(d: date):
    ld, lm, *_ = solar_to_lunar(d.day, d.month, d.year)
    jd = jd_from_date(d.day, d.month, d.year)
    chi = (jd + 1) % 12
    can = (jd + 9) % 10
    ten_sao, tot = SAO[(chi - ((lm - 1) % 6) * 2) % 12]
    kd = math.degrees(sun_longitude_rad(jd + 1))
    chi_thang_tiet = (2 + int(((kd - 315) % 360) // 30)) % 12      # tháng theo tiết khí (Dần = Lập xuân)
    return {"sao": ten_sao, "hoang_dao": tot, "truc": TRUC[(chi - chi_thang_tiet) % 12],
            "xung": CHI[(chi + 6) % 12], "hy_than": HY_THAN[can % 5]}


def dem_tet(d: date):
    """(số ngày tới mùng 1 Tết kế tiếp, tên năm âm lịch đó) hoặc (0, ...) nếu đang trong 3 ngày Tết."""
    ld, lm, ly, leap, _ = solar_to_lunar(d.day, d.month, d.year)
    if lm == 1 and ld <= 3 and not leap:
        return 0, ld, f"{CAN[(ly + 6) % 10]} {CHI[(ly + 8) % 12]}"
    for k in range(1, 400):
        n = d + timedelta(days=k)
        a, b, y, lp, _ = solar_to_lunar(n.day, n.month, n.year)
        if a == 1 and b == 1 and not lp:
            return k, 1, f"{CAN[(y + 6) % 10]} {CHI[(y + 8) % 12]}"
    return None, None, ""


# ---------------- THỊ TRƯỜNG ----------------
def _get(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (kindle-screensaver)"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", errors="replace")


def lay_thi_truong():
    import re, html as _html
    kq = {}
    try:   # Tỷ giá Vietcombank
        x = _get("https://portal.vietcombank.com.vn/Usercontrols/TVPortal.TyGia/pXML.aspx")
        m = re.search(r'CurrencyCode="USD"[^>]*Buy="([\d,.]+)"[^>]*Sell="([\d,.]+)"', x)
        if m:
            kq["usd"] = (float(m.group(1).replace(",", "")), float(m.group(2).replace(",", "")))
    except Exception as e:
        print("Tỷ giá lỗi:", e)
    try:   # VN-Index (SSI iBoard)
        j = json.loads(_get("https://iboard-query.ssi.com.vn/exchange-index/VNINDEX?hasHistory=false"))["data"]
        kq["vni"] = (float(j["indexValue"]), float(j["indexValue"]) - float(j["prevIndexValue"]),
                     (float(j["indexValue"]) / float(j["prevIndexValue"]) - 1) * 100)
    except Exception as e:
        print("VN-Index lỗi:", e)
    try:   # Bitcoin (CoinGecko)
        j = json.loads(_get("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin"
                            "&vs_currencies=usd&include_24hr_change=true"))["bitcoin"]
        kq["btc"] = (float(j["usd"]), float(j.get("usd_24h_change") or 0))
    except Exception as e:
        print("Bitcoin lỗi:", e)
    try:   # Giá xăng (giaxanghomnay.com tổng hợp giá Petrolimex/PVOIL), vùng 1
        s = _get("https://giaxanghomnay.com/")
        t = re.sub(r"<script.*?</script>", " ", s, flags=re.S)
        t = re.sub(r"<[^>]+>", " | ", t)
        t = re.sub(r"(\s*\|\s*)+", " | ", _html.unescape(t))
        m = re.search(r"RON 95 Mức \d \| [^|]* \| ([-+]?[\d,]+) \| ([\d,]+) \|", t)
        if m:
            kq["xang"] = (float(m.group(2).replace(",", "")), float(m.group(1).replace(",", "")))
    except Exception as e:
        print("Giá xăng lỗi:", e)
    print("Thị trường:", kq)
    return kq


def so_vn(v, le=0):
    """Định dạng số kiểu Việt Nam: 25790 -> '25.790', 1743.07 -> '1.743,07'."""
    s = f"{v:,.{le}f}"
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


def tam_giac(dr, x, y, len_tren, co=9):
    if len_tren:
        dr.polygon([(x - co, y + co * 0.8), (x + co, y + co * 0.8), (x, y - co)], fill=DEN)
    else:
        dr.polygon([(x - co, y - co * 0.8), (x + co, y - co * 0.8), (x, y + co)], fill=DEN)


# ---------------- VẼ ----------------
def ve(hom_nay: date, thoi_tiet, vang=None, thi_truong=None):
    img = Image.new("L", (RONG, CAO), TRANG)
    dr = ImageDraw.Draw(img)
    L, R = 80, RONG - 80
    am = thong_tin_am(hom_nay)
    tx = tot_xau(hom_nay)

    # ---- Đầu trang ----
    chu(dr, (L, 58), THU[hom_nay.weekday()].upper(), font(F_BOLD, 48))
    chu(dr, (R, 60), f"THÁNG {hom_nay.month} · {hom_nay.year}", font(F_SEMI, 40), anchor="ra")
    ke_ngang(dr, 130, w=4)

    # ---- Ngày dương + tuần (trái) + đếm ngược Tết (phải) ----
    le = LE_DUONG.get((hom_nay.day, hom_nay.month)) or \
        (None if am["nhuan"] else LE_AM.get((am["ngay"], am["thang"])))
    if not le:
        le = "Mùng 1" if am["ngay"] == 1 else ("Ngày Rằm" if am["ngay"] == 15 else None)
    cy_so = 240 if le else 268
    chu(dr, (RONG // 2, cy_so), f"{hom_nay.day:02d}", font(F_LIGHT, 220), anchor="mm")

    tuan = hom_nay.isocalendar()[1]
    tong_tuan = date(hom_nay.year, 12, 28).isocalendar()[1]
    chu(dr, (L, cy_so - 40), "TUẦN", font(F_BOLD, 24), fill=XAM, anchor="ls")
    chu(dr, (L - 4, cy_so + 34), str(tuan), font(F_SEMI, 72), anchor="ls")
    w_tuan = dr.textlength(str(tuan), font=font(F_SEMI, 72))
    chu(dr, (L + w_tuan + 6, cy_so + 34), f"/{tong_tuan}", font(F_REG, 28), fill=XAM, anchor="ls")

    so_ngay_tet, mung, nam_tet = dem_tet(hom_nay)
    if so_ngay_tet == 0:
        chu(dr, (R, cy_so - 40), f"TẾT {nam_tet.upper()}", font(F_BOLD, 24), fill=XAM, anchor="rs")
        chu(dr, (R, cy_so + 34), f"Mùng {mung}", font(F_SEMI, 60), anchor="rs")
    elif so_ngay_tet:
        chu(dr, (R, cy_so - 40), f"TẾT {nam_tet.upper()}", font(F_BOLD, 24), fill=XAM, anchor="rs")
        f_so, f_ng = font(F_SEMI, 72), font(F_REG, 28)
        w_ng = dr.textlength(" ngày", font=f_ng)
        chu(dr, (R, cy_so + 34), " ngày", f_ng, fill=XAM, anchor="rs")
        chu(dr, (R - w_ng, cy_so + 34), str(so_ngay_tet), f_so, anchor="rs")
        chu(dr, (R, cy_so + 64), "nữa", f_ng, fill=XAM, anchor="rs")

    if le:
        f = font(F_SEMI, 32)
        tw = dr.textlength(le, font=f)
        x0 = RONG // 2 - tw / 2 - 24
        dr.rounded_rectangle([x0, 350, RONG - x0, 396], radius=23, fill=DEN)
        chu(dr, (RONG // 2, 373), le, f, fill=TRANG, anchor="mm")
    ke_ngang(dr, 418, fill=XAM, w=2)

    # ---- Âm lịch + ngày tốt xấu ----
    chu(dr, (L, 436), "ÂM LỊCH", font(F_BOLD, 26), fill=XAM)
    chu(dr, (L - 6, 458), f"{am['ngay']}/{am['thang']}", font(F_SEMI, 130))
    ten_thang = f"Tháng {THANG_AM[am['thang'] - 1]}{' (nhuận)' if am['nhuan'] else ''}"
    ten_thang += f" · {'Đủ' if am['so_ngay'] == 30 else 'Thiếu'}"
    chu(dr, (L, 622), ten_thang, font(F_REG, 30), fill=XAM_DAM)
    # nhãn hoàng đạo / hắc đạo
    f_nhan = font(F_SEMI, 27)
    nhan = f"{'HOÀNG ĐẠO' if tx['hoang_dao'] else 'HẮC ĐẠO'} · {tx['sao']}"
    wn = dr.textlength(nhan, font=f_nhan)
    if tx["hoang_dao"]:
        dr.rounded_rectangle([L, 664, L + wn + 36, 706], radius=21, fill=DEN)
        chu(dr, (L + 18, 685), nhan, f_nhan, fill=TRANG, anchor="lm")
    else:
        dr.rounded_rectangle([L, 664, L + wn + 36, 706], radius=21, outline=DEN, width=3)
        chu(dr, (L + 18, 685), nhan, f_nhan, fill=DEN, anchor="lm")

    cot = 690
    f_l, f_v = font(F_REG, 26), font(F_SEMI, 34)
    for i, (k, v) in enumerate([("Ngày", am["can_chi_ngay"]), ("Tháng", am["can_chi_thang"]),
                                ("Năm", am["can_chi_nam"]), ("Tiết", am["tiet_khi"]),
                                ("Trực", tx["truc"])]):
        y = 446 + i * 50
        chu(dr, (cot, y + 6), k, f_l, fill=XAM)
        chu(dr, (cot + 100, y), v, f_v)

    f_g = font(F_REG, 27)
    chu(dr, (L, 728), f"Kỵ tuổi {tx['xung']}  ·  Xuất hành hướng {tx['hy_than']} (Hỷ thần)", f_g, fill=XAM_DAM)
    chu(dr, (L, 764), "Giờ hoàng đạo:  ", f_g, fill=XAM)
    chu(dr, (L + dr.textlength("Giờ hoàng đạo:  ", font=f_g), 762), "  ·  ".join(am["gio_hd"]),
        font(F_SEMI, 28))
    ke_ngang(dr, 812, fill=XAM, w=2)

    # ---- Thời tiết ----
    chu(dr, (L, 830), f"THỜI TIẾT · {THANH_PHO.upper()}", font(F_BOLD, 26), fill=XAM)
    d = thoi_tiet["daily"] if thoi_tiet else None
    i0 = d["time"].index(hom_nay.isoformat()) if d and hom_nay.isoformat() in d["time"] else None
    if thoi_tiet and i0 is not None and len(d["time"]) >= i0 + 5:
        x2 = 690
        f_s = font(F_REG, 28)
        if i0 == 0:
            c = thoi_tiet["current"]
            mo_ta, loai = mo_ta_thoi_tiet(c["weather_code"])
            ve_icon(dr, loai, L + 80, 918, 64, ngay=bool(c.get("is_day", 1)))
            chu(dr, (L + 175, 918), f"{round(c['temperature_2m'])}°", font(F_LIGHT, 116), anchor="lm")
            chu(dr, (x2, 858), mo_ta, font(F_SEMI, 38))
            chu(dr, (x2, 908), f"Cảm giác  {round(c['apparent_temperature'])}°", f_s, fill=XAM_DAM)
            chu(dr, (x2, 946), f"Độ ẩm  {c['relative_humidity_2m']}%  ·  Gió  {round(c['wind_speed_10m'])} km/h",
                f_s, fill=XAM_DAM)
        else:
            mo_ta, loai = mo_ta_thoi_tiet(d["weather_code"][i0])
            ve_icon(dr, loai, L + 80, 918, 64)
            chu(dr, (L + 175, 918), f"{round(d['temperature_2m_max'][i0])}°", font(F_LIGHT, 116), anchor="lm")
            chu(dr, (x2, 858), f"{mo_ta} (dự báo)", font(F_SEMI, 38))
            chu(dr, (x2, 908), f"Thấp nhất  {round(d['temperature_2m_min'][i0])}°", f_s, fill=XAM_DAM)
            mua0 = d.get("precipitation_probability_max", [None] * 16)[i0]
            chu(dr, (x2, 946), f"Khả năng mưa  {mua0 if mua0 is not None else '—'}%", f_s, fill=XAM_DAM)
        o = (R - L) / 4
        for i in range(i0 + 1, i0 + 5):
            ngay_dt = datetime.strptime(d["time"][i], "%Y-%m-%d").date()
            cx = L + o * (i - i0 - 1) + o / 2
            ten = "Mai" if i == i0 + 1 else THU_NGAN[ngay_dt.weekday()]
            chu(dr, (cx, 1010), ten, font(F_SEMI, 28), anchor="mm")
            ve_icon(dr, mo_ta_thoi_tiet(d["weather_code"][i])[1], cx, 1050, 28)
            chu(dr, (cx, 1094), f"{round(d['temperature_2m_max'][i])}°", font(F_SEMI, 30), anchor="rm")
            chu(dr, (cx + 8, 1094), f" {round(d['temperature_2m_min'][i])}°", font(F_REG, 30),
                fill=XAM, anchor="lm")
            mua = d.get("precipitation_probability_max", [None] * 16)[i]
            if mua:
                chu(dr, (cx, 1124), f"mưa {mua}%", font(F_REG, 21), fill=XAM, anchor="mm")
            if i < i0 + 4:
                dr.line([L + o * (i - i0), 994, L + o * (i - i0), 1132], fill=XAM_NHAT, width=2)
    else:
        chu(dr, (L, 900), "Chưa có dữ liệu thời tiết", font(F_REG, 36), fill=XAM)
    ke_ngang(dr, 1146, fill=XAM, w=2)

    # ---- Giá vàng ----
    chu(dr, (L, 1156), "GIÁ VÀNG · TRIỆU ĐỒNG/LƯỢNG", font(F_BOLD, 26), fill=XAM)
    if vang:
        nguon = f"PNJ · {vang['gio'][:16]}" + (" (cũ)" if vang["cu"] else "")
        chu(dr, (R, 1158), nguon, font(F_REG, 22), fill=XAM, anchor="ra")
        f_ten, f_nh, f_so, f_ch = font(F_REG, 28), font(F_REG, 23), font(F_SEMI, 36), font(F_SEMI, 25)
        for j, (ma, ten) in enumerate(LOAI_VANG):
            if ma not in vang["gia"]:
                continue
            mua, ban = vang["gia"][ma]
            cy = 1206 + j * 42
            chu(dr, (L, cy), ten, f_ten, fill=XAM_DAM, anchor="lm")
            for nhan, v, x in [("Mua", mua, 620), ("Bán", ban, 860)]:
                chu(dr, (x - 8, cy + 3), nhan, f_nh, fill=XAM, anchor="rm")
                chu(dr, (x + 2, cy), trieu_luong(v), f_so, anchor="lm")
            if vang["truoc"] and ma in vang["truoc"]:
                ch = ban - vang["truoc"][ma][1]
                if abs(ch) < 1e-6:
                    chu(dr, (R, cy), "—", f_nh, fill=XAM, anchor="rm")
                else:
                    s = trieu_luong(abs(ch))
                    chu(dr, (R, cy + 2), s, f_ch, anchor="rm")
                    tam_giac(dr, R - dr.textlength(s, font=f_ch) - 18, cy, ch > 0)
    else:
        chu(dr, (L, 1230), "Chưa có dữ liệu giá vàng", font(F_REG, 30), fill=XAM)

    # ---- Tỷ giá · xăng · VN-Index · Bitcoin ----
    tt = thi_truong or {}
    o = (R - L) / 4
    f_lb, f_gt, f_bd = font(F_BOLD, 19), font(F_SEMI, 29), font(F_REG, 21)
    o_tt = [
        ("USD · VCB BÁN", f"{so_vn(tt['usd'][1])}" if "usd" in tt else "—", None),
        ("XĂNG RON 95", f"{so_vn(tt['xang'][0])}đ" if "xang" in tt else "—",
         (tt["xang"][1], f"{so_vn(abs(tt['xang'][1]))}đ") if "xang" in tt and tt["xang"][1] else None),
        ("VN-INDEX", so_vn(tt["vni"][0], 2) if "vni" in tt else "—",
         (tt["vni"][1], f"{so_vn(abs(tt['vni'][2]), 2)}%") if "vni" in tt else None),
        ("BITCOIN", f"{so_vn(tt['btc'][0])}$" if "btc" in tt else "—",
         (tt["btc"][1], f"{so_vn(abs(tt['btc'][1]), 1)}%") if "btc" in tt else None),
    ]
    for k, (nhan, gt, bd) in enumerate(o_tt):
        x = L + o * k
        chu(dr, (x, 1272), nhan, f_lb, fill=XAM)
        chu(dr, (x, 1314), gt, f_gt, anchor="lm")
        if bd:
            xb = x + dr.textlength(gt, font=f_gt) + 20
            tam_giac(dr, xb, 1315, bd[0] > 0, co=7)
            chu(dr, (xb + 11, 1316), bd[1], f_bd, fill=XAM_DAM, anchor="lm")
        if k:
            dr.line([x - 14, 1272, x - 14, 1332], fill=XAM_NHAT, width=2)
    ke_ngang(dr, 1344, fill=XAM, w=2)

    # ---- Lịch tháng mini ----
    top = 1352
    o = (R - L) / 7
    for i, t in enumerate(THU_NGAN):
        chu(dr, (L + o * i + o / 2, top + 14), t, font(F_BOLD, 21), fill=XAM, anchor="mm")
    dau_thang = hom_nay.replace(day=1)
    so_ngay = ((dau_thang + timedelta(days=32)).replace(day=1) - dau_thang).days
    so_hang = math.ceil((dau_thang.weekday() + so_ngay) / 7)
    h = min(50, (CAO - 38 - (top + 30)) / so_hang)
    f_d, f_db, f_a = font(F_SEMI, 25), font(F_BOLD, 25), font(F_REG, 17)
    for n in range(1, so_ngay + 1):
        dd = dau_thang.replace(day=n)
        idx = dau_thang.weekday() + n - 1
        cx = L + o * (idx % 7) + o / 2
        cy = top + 30 + h * (idx // 7) + h / 2
        ld, lm, *_ = solar_to_lunar(n, dd.month, dd.year)
        am_txt = f"{ld}/{lm}" if ld == 1 else str(ld)
        hom = dd == hom_nay
        if hom:
            dr.rounded_rectangle([cx - o / 2 + 10, cy - h / 2 + 3, cx + o / 2 - 10, cy + h / 2 - 3],
                                 radius=10, fill=DEN)
        mau = TRANG if hom else (XAM_DAM if idx % 7 == 6 else DEN)
        chu(dr, (cx - 8, cy), str(n), f_db if hom else f_d, fill=mau, anchor="rm")
        chu(dr, (cx + 2, cy + 4), am_txt, f_a, fill=TRANG if hom else XAM, anchor="lm")

    chu(dr, (R, CAO - 14), f"Cập nhật {datetime.now(GIO_VN):%H:%M %d/%m}", font(F_REG, 19),
        fill=XAM, anchor="rb")
    return img


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    d = datetime.strptime(sys.argv[1], "%Y-%m-%d").date() if len(sys.argv) > 1 else datetime.now(GIO_VN).date()
    tt, vang, thi_truong = lay_thoi_tiet(), lay_gia_vang(), lay_thi_truong()
    img = ve(d, tt, vang, thi_truong)
    img.save(FILE_RA, optimize=True)
    print("Đã lưu:", FILE_RA)
    so_ngay = int(os.environ.get("SO_NGAY_LAM_SAN", "0"))
    thu_muc = os.path.dirname(os.path.abspath(FILE_RA))
    for k in range(so_ngay):
        n = d + timedelta(days=k)
        p = os.path.join(thu_muc, f"bg-{n.isoformat()}.png")
        ve(n, tt, vang, thi_truong).save(p, optimize=True)
        print("Đã lưu:", p)


if __name__ == "__main__":
    main()
