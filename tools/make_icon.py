"""Oyun ikonu: portofolyo/icon.png (1024) + portofolyo/icon.ico (16-256).

  python tools/make_icon.py <sehir_goruntusu.png>

Buyuk boyutlar (48-256): oyunun aksam ustu sehir goruntusu (oyunun icinden alinir) uzerinde turuncu kalkan,
icinde beyaz ev ve yesil "hazir" onay rozeti. Kucuk boyutlar (16, 32): ayrinti kaybolmasin diye sade surum
(turuncu zemin + beyaz kalkan + ev).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "portofolyo")
N = 1024
S = 4  # kenar yumusatma: 4 kat buyuk ciz, kucult

ORANGE_HI = (255, 166, 77)
ORANGE = (230, 112, 48)
ORANGE_DK = (176, 70, 28)
GREEN = (18, 147, 90)
CREAM = (255, 250, 242)


def rounded_mask(size, r):
    m = Image.new("L", (size * S, size * S), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size * S - 1, size * S - 1), r * S, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def vgrad(size, top, bottom):
    g = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize(size, Image.BICUBIC)


def shield_points(cx, cy, w, h):
    """Yuvarlak omuzlu, altta sivri kalkan (ust kenar hafif kavisli)."""
    pts = []
    top = cy - h * 0.5
    # ust kenar: hafif yukari kavis
    for i in range(21):
        t = i / 20
        x = cx - w * 0.5 + w * t
        y = top + (abs(t - 0.5) * 2) ** 2 * h * 0.06 - h * 0.03
        pts.append((x, y))
    # yanlar ustte dik iner, alt yarida yumusakca sivri uca kivrilir (klasik arma kalkani)
    def side(t):
        k = max(0.0, (t - 0.38) / 0.62)
        return w * 0.5 * (1 - k ** 1.7) ** 0.75
    for i in range(1, 41):
        t = i / 40
        pts.append((cx + side(t), top + h * 0.03 + h * 0.97 * t))
    for i in range(39, 0, -1):
        t = i / 40
        pts.append((cx - side(t), top + h * 0.03 + h * 0.97 * t))
    return pts


def draw_badge(img, cx, cy, w, h, border, check=True):
    """Kalkan + ev (+ onay rozeti). img: RGBA, koordinatlar img olceginde."""
    d = ImageDraw.Draw(img)
    # golge
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon(shield_points(cx, cy + h * 0.04, w + border * 2, h + border * 2), fill=(40, 20, 10, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(h * 0.05))
    img.alpha_composite(sh)
    d.polygon(shield_points(cx, cy, w + border * 2, h + border * 2), fill=CREAM)
    # turuncu ic: dikey degrade
    inner = Image.new("L", img.size, 0)
    ImageDraw.Draw(inner).polygon(shield_points(cx, cy, w, h), fill=255)
    grad = vgrad(img.size, ORANGE_HI, ORANGE_DK).convert("RGBA")
    img.paste(grad, (0, 0), inner)
    # ust parlak serit (cam / emaye hissi)
    gl = Image.new("L", img.size, 0)
    ImageDraw.Draw(gl).polygon(shield_points(cx, cy - h * 0.28, w * 0.86, h * 0.36), fill=55)
    gl = Image.composite(gl, Image.new("L", img.size, 0), inner)
    img.paste(Image.new("RGBA", img.size, (255, 255, 255, 255)), (0, 0), gl)
    # ev: cati ucgeni + govde + kapi
    hw = w * 0.3
    roof_y = cy - h * 0.16
    base_y = cy + h * 0.13
    body_l, body_r = cx - hw * 0.72, cx + hw * 0.72
    d.polygon([(cx - hw, roof_y + hw * 0.62), (cx, roof_y - hw * 0.28), (cx + hw, roof_y + hw * 0.62)], fill=CREAM)
    d.rectangle((body_l, roof_y + hw * 0.5, body_r, base_y), fill=CREAM)
    d.rounded_rectangle((cx - hw * 0.2, base_y - hw * 0.62, cx + hw * 0.2, base_y), hw * 0.08, fill=ORANGE_DK)
    # baca
    d.rectangle((cx + hw * 0.38, roof_y - hw * 0.02, cx + hw * 0.6, roof_y + hw * 0.3), fill=CREAM)
    if check:
        r = w * 0.19
        ox, oy = cx + w * 0.42, cy + h * 0.32
        d.ellipse((ox - r - border * 0.8, oy - r - border * 0.8, ox + r + border * 0.8, oy + r + border * 0.8), fill=CREAM)
        d.ellipse((ox - r, oy - r, ox + r, oy + r), fill=GREEN)
        lw = int(r * 0.32)
        d.line([(ox - r * 0.48, oy + r * 0.02), (ox - r * 0.1, oy + r * 0.4), (ox + r * 0.52, oy - r * 0.38)], fill=CREAM, width=lw, joint="curve")


def big_icon(city_path):
    city = Image.open(city_path).convert("RGB")
    w, h = city.size
    s = min(w, h)
    # sag kenardaki arayuz parcalari kalmasin diye merkezden biraz sola kare kirp
    left = max(0, (w - s) // 2 - int(s * 0.08))
    city = city.crop((left, (h - s) // 2, left + s, (h - s) // 2 + s)).resize((N, N), Image.LANCZOS)
    city = ImageEnhance.Color(city).enhance(1.15)
    # sicak aksam tonu + kenarlarda karartma (amblem one ciksin)
    warm = vgrad((N, N), (255, 170, 90), (60, 40, 90))
    city = Image.blend(city, warm, 0.22)
    vig = Image.new("L", (N, N), 0)
    ImageDraw.Draw(vig).ellipse((-N * 0.25, -N * 0.25, N * 1.25, N * 1.25), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(N * 0.12))
    city = Image.composite(city, ImageEnhance.Brightness(city).enhance(0.45), vig)
    canvas = city.convert("RGBA").resize((N * S, N * S), Image.LANCZOS)
    draw_badge(canvas, N * S * 0.48, N * S * 0.5, N * S * 0.56, N * S * 0.64, N * S * 0.028)
    canvas = canvas.resize((N, N), Image.LANCZOS)
    # ince ic kenar parlakligi
    rim = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle((6, 6, N - 7, N - 7), 176, outline=(255, 255, 255, 70), width=10)
    canvas.alpha_composite(rim)
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(canvas, (0, 0), rounded_mask(N, 184))
    return out


def small_icon(size):
    big = size * 16
    bg = vgrad((big, big), (52, 74, 120), (28, 38, 70)).convert("RGBA")  # gece mavisi: turuncu kalkan ayrissin
    draw_badge(bg, big * 0.5, big * 0.52, big * 0.7, big * 0.78, big * 0.05, check=False)
    # kucukte kalkan da krem: turuncu zeminde ayrissin -> kalkani tamamen krem kenarli birak
    bg = bg.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(bg, (0, 0), rounded_mask(size, max(2, int(size * 0.2))))
    return out


if __name__ == "__main__":
    big = big_icon(sys.argv[1])
    big.save(os.path.join(OUT, "icon.png"))
    imgs = {sz: big.resize((sz, sz), Image.LANCZOS) for sz in (256, 128, 64, 48)}
    imgs[32] = small_icon(32)
    imgs[16] = small_icon(16)
    order = [256, 128, 64, 48, 32, 16]
    imgs[256].save(os.path.join(OUT, "icon.ico"), format="ICO", sizes=[(s, s) for s in order],
                   append_images=[imgs[s] for s in order[1:]])
    prev = Image.new("RGBA", (256 + 128 + 64 + 48 + 32 + 16 + 70, 256), (40, 40, 46, 255))
    x = 0
    for s in order:
        prev.alpha_composite(imgs[s], (x, 256 - s))
        x += s + 12
    prev.save(os.path.join(os.environ.get("TEMP", "."), "icon_preview.png"))  # onizleme repoya girmesin
    print("icon.png, icon.ico yazildi")
