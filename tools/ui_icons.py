"""Magaza ikonlari (SVG) -> portofolyo/assets/ui_icons/<id>.svg

  python tools/ui_icons.py

Tek tip: yumusak renk dolgusu + ayni rengin koyu tonunda kenar (siyah cizgi yok), bir parlama,
alta hafif golge. Renkler Tailwind CSS paletinden (uyumlu, okunakli tonlar).
Her ikon, magazadaki urunun yazisini dogrudan anlatir.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "portofolyo", "assets", "ui_icons")

# Tailwind paleti: (dolgu, kenar)
P = {
    "sky": ("#38bdf8", "#0369a1"), "blue": ("#60a5fa", "#1d4ed8"), "navy": ("#3b82f6", "#1e3a8a"),
    "amber": ("#fbbf24", "#b45309"), "orange": ("#fb923c", "#c2410c"), "red": ("#f87171", "#b91c1c"),
    "deepred": ("#ef4444", "#991b1b"), "emerald": ("#34d399", "#047857"), "green": ("#4ade80", "#15803d"),
    "slate": ("#cbd5e1", "#64748b"), "steel": ("#94a3b8", "#475569"), "cream": ("#fef3c7", "#b45309"),
    "brown": ("#c08457", "#7c2d12"), "violet": ("#a78bfa", "#6d28d9"), "white": ("#f8fafc", "#64748b"),
    "wood": ("#d6a26b", "#92400e"), "teal": ("#2dd4bf", "#0f766e"), "skin": ("#fcd5b5", "#c2410c"),
}
SW = 4  # kenar kalinligi


def st(c):
    f, s = P[c]
    return f'fill="{f}" stroke="{s}" stroke-width="{SW}" stroke-linejoin="round" stroke-linecap="round"'


def rect(x, y, w, h, c, r=4):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" {st(c)}/>'


def circ(x, y, r, c):
    return f'<circle cx="{x}" cy="{y}" r="{r}" {st(c)}/>'


def ell(x, y, rx, ry, c):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" {st(c)}/>'


def poly(pts, c):
    return f'<polygon points="{" ".join(f"{x},{y}" for x, y in pts)}" {st(c)}/>'


def path(d, c, fill=True):
    if fill:
        return f'<path d="{d}" {st(c)}/>'
    return f'<path d="{d}" fill="none" stroke="{P[c][1]}" stroke-width="{SW}" stroke-linecap="round" stroke-linejoin="round"/>'


def line(x1, y1, x2, y2, c, w=SW):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{P[c][1]}" stroke-width="{w}" stroke-linecap="round"/>'


def shine(x, y, w, h, r=3):
    """Ust-sol parlama."""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="#ffffff" opacity="0.45"/>'


def dot(x, y, r, color="#ffffff", op=1.0):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}" opacity="{op}"/>'


def shadow(y=116, w=44):
    return f'<ellipse cx="64" cy="{y}" rx="{w}" ry="6" fill="#0f172a" opacity="0.14"/>'


def badge(x, y, kind):
    """Sag alt kose rozetleri: check (yesil), no (kirmizi yasak), plus (kirmizi arti)."""
    if kind == "check":
        return circ(x, y, 15, "emerald") + path(f"M{x-7},{y} L{x-2},{y+6} L{x+8},{y-6}", "white", fill=False).replace(P["white"][1], "#ffffff")
    if kind == "no":
        return circ(x, y, 15, "deepred") + line(x - 8, y - 8, x + 8, y + 8, "white", 5).replace(P["white"][1], "#ffffff")
    if kind == "shield":
        return (path(f"M{x},{y-17} L{x+15},{y-11} L{x+13},{y+5} Q{x},{y+18} {x},{y+18} Q{x},{y+18} {x-13},{y+5} L{x-15},{y-11} Z", "emerald")
                + path(f"M{x-6},{y} L{x-1},{y+5} L{x+7},{y-5}", "white", fill=False).replace(P["white"][1], "#ffffff"))
    return ""


def person(x, y, c="blue", s=1.0, head="skin"):
    return (path(f"M{x-12*s},{y+22*s} Q{x-12*s},{y+4*s} {x},{y+4*s} Q{x+12*s},{y+4*s} {x+12*s},{y+22*s} Z", c)
            + circ(x, y - 6 * s, 8 * s, head))


def house(x, y, w=40, wall="cream", roof="red"):
    h = w * 0.7
    return (rect(x, y, w, h, wall, 3)
            + poly([(x - 5, y + 2), (x + w / 2, y - w * 0.45), (x + w + 5, y + 2)], roof)
            + rect(x + w * 0.38, y + h * 0.42, w * 0.24, h * 0.58, "wood", 2))


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 128 128">'
            + body + "</svg>")


ICONS = {}


def icon(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco


# ------------------------------------------------------------------ DEPREM
@icon("reinforce_district")
def _():
    return (shadow() + house(10, 52, 44, "cream", "red") + house(56, 40, 52, "slate", "blue")
            + shine(60, 64, 10, 18) + badge(94, 92, "shield"))


@icon("kacak_all")
def _():
    b = rect(34, 46, 52, 66, "steel", 3)
    for yy in (56, 76, 96):
        for xx in (42, 66):
            b += rect(xx, yy, 12, 12, "sky", 2)
    illegal = rect(30, 20, 60, 26, "orange", 3).replace('stroke-width="4"', 'stroke-width="4" stroke-dasharray="7 5"')
    return shadow() + b + illegal + shine(36, 24, 16, 6) + badge(92, 32, "no")


@icon("gas_valves")
def _():
    return (shadow(112, 50) + rect(8, 64, 112, 26, "amber", 8) + shine(12, 67, 30, 6)
            + rect(44, 54, 40, 46, "steel", 8) + rect(60, 36, 8, 20, "steel", 2)
            + circ(64, 32, 16, "red") + circ(64, 32, 5, "deepred")
            + path("M58,84 Q58,74 64,70 Q70,76 70,84 Q70,90 64,90 Q58,90 58,84 Z", "orange"))


@icon("assembly")
def _():
    sign = rect(22, 14, 84, 70, "emerald", 10) + shine(28, 19, 30, 8)
    people = ""
    for i, x in enumerate((44, 64, 84)):
        people += (f'<circle cx="{x}" cy="{38}" r="7" fill="#ffffff"/>'
                   f'<path d="M{x-10},{66} Q{x-10},{48} {x},{48} Q{x+10},{48} {x+10},{66} Z" fill="#ffffff"/>')
    return shadow(118, 26) + rect(58, 82, 12, 34, "steel", 2) + sign + people


@icon("renewal")
def _():
    old = (rect(8, 70, 40, 32, "wood", 2) + poly([(4, 72), (28, 52), (52, 72)], "brown")
           + line(14, 80, 24, 92, "brown", 3) + line(34, 78, 30, 92, "brown", 3))
    new = rect(76, 26, 44, 82, "blue", 4) + shine(80, 30, 10, 30)
    for yy in (36, 56, 76):
        for xx in (84, 102):
            new += rect(xx, yy, 10, 12, "sky", 2)
    arrow = path("M44,40 Q60,24 72,40", "emerald", fill=False) + poly([(66, 34), (78, 44), (66, 48)], "emerald")
    return shadow() + old + new + arrow


@icon("warning")
def _():
    waves = "".join(path(f"M{96+i*8},{30-i*6} Q{104+i*10},{46} {96+i*8},{62+i*6}", "amber", fill=False) for i in range(2))
    waves += "".join(path(f"M{32-i*8},{30-i*6} Q{24-i*10},{46} {32-i*8},{62+i*6}", "amber", fill=False) for i in range(2))
    return (shadow(118, 30) + rect(58, 70, 12, 46, "steel", 2) + rect(40, 62, 48, 14, "steel", 4)
            + path("M42,62 Q42,22 64,22 Q86,22 86,62 Z", "red") + shine(50, 30, 8, 18) + waves)


# ------------------------------------------------------------------ SEL
@icon("drain_clean")
def _():
    water = path("M4,96 Q20,88 36,96 Q52,104 68,96 Q84,88 100,96 Q112,102 124,96 L124,120 L4,120 Z", "sky")
    mud = path("M30,92 Q36,66 58,66 Q80,66 84,92 Z", "brown") + dot(46, 78, 4, "#7c2d12", 0.5) + dot(66, 74, 3, "#7c2d12", 0.5)
    shovel = (line(78, 18, 98, 62, "wood", 7) + poly([(92, 56), (110, 50), (116, 70), (100, 80)], "steel")
              + rect(70, 10, 18, 9, "wood", 4))
    return water + mud + shovel + shine(10, 100, 20, 4)


@icon("storm_drains")
def _():
    cloud = path("M28,46 Q22,26 42,24 Q50,8 70,16 Q92,10 96,30 Q112,32 108,46 Z", "slate")
    drops = "".join(path(f"M{x},{y} Q{x-5},{y+9} {x},{y+12} Q{x+5},{y+9} {x},{y} Z", "sky") for x, y in ((40, 54), (64, 58), (88, 54)))
    grate = rect(22, 84, 84, 30, "steel", 6)
    for i in range(6):
        grate += rect(32 + i * 12, 90, 6, 18, "white", 2).replace(P["white"][0], "#334155").replace(P["white"][1], "#334155")
    return cloud + shine(40, 22, 22, 6) + drops + grate


@icon("flood_barriers")
def _():
    water = path("M2,98 Q14,90 26,98 Q38,106 50,98 L50,122 L2,122 Z", "sky")
    bags = ""
    for i, (x, y) in enumerate(((48, 96), (66, 96), (84, 96), (57, 82), (75, 82))):
        bags += ell(x, y, 11, 7, "wood")
    return shadow(118, 50) + house(62, 40, 48, "cream", "red") + water + bags


@icon("river")
def _():
    walls = poly([(8, 116), (40, 30), (52, 30), (34, 116)], "slate") + poly([(120, 116), (88, 30), (76, 30), (94, 116)], "slate")
    river = poly([(34, 116), (52, 30), (76, 30), (94, 116)], "blue")
    waves = path("M48,94 Q56,88 64,94 Q72,100 80,94", "white", fill=False).replace(P["white"][1], "#e0f2fe")
    waves += path("M54,64 Q60,60 66,64 Q72,68 76,64", "white", fill=False).replace(P["white"][1], "#e0f2fe")
    return walls + river + waves + shine(16, 90, 10, 20, 2)


# ------------------------------------------------------------------ YANGIN
@icon("forest")
def _():
    tree = (rect(22, 84, 12, 28, "wood", 2) + path("M28,18 L52,64 L40,64 L54,88 L2,88 L16,64 L4,64 Z", "green"))
    tower = rect(84, 46, 8, 68, "steel", 2) + rect(70, 28, 40, 24, "steel", 6) + circ(78, 40, 8, "slate")
    heat = circ(78, 40, 5, "orange")
    beam = '<path d="M74,46 L44,96 L74,76 Z" fill="#fb923c" opacity="0.35"/>'
    return shadow() + tree + beam + tower + heat + shine(96, 32, 10, 5)


@icon("wiring")
def _():
    cable = path("M12,104 Q30,70 58,82 Q78,90 82,64", "steel", fill=False)
    plug = rect(70, 30, 30, 36, "amber", 6) + rect(76, 14, 6, 18, "steel", 2) + rect(88, 14, 6, 18, "steel", 2) + shine(74, 34, 8, 12)
    bolt = poly([(40, 14), (24, 46), (38, 46), (30, 70), (56, 34), (42, 34), (50, 14)], "amber")
    return shadow(116, 46) + cable + plug + bolt + badge(98, 96, "check")


@icon("hydrants")
def _():
    body = (rect(38, 48, 52, 62, "deepred", 8) + path("M38,50 Q38,22 64,22 Q90,22 90,50 Z", "deepred")
            + rect(58, 12, 12, 12, "deepred", 3) + rect(22, 62, 18, 18, "red", 4) + rect(88, 62, 18, 18, "red", 4)
            + rect(32, 104, 64, 12, "red", 4) + circ(64, 72, 9, "red"))
    return shadow() + body + shine(44, 30, 10, 40)


@icon("extinguishers")
def _():
    tank = rect(44, 38, 40, 76, "deepred", 16) + shine(50, 46, 8, 48)
    head = rect(54, 22, 20, 18, "steel", 4) + path("M74,26 L98,22 L98,30 L74,32 Z", "steel")
    hose = path("M50,38 Q28,40 30,70 Q32,92 40,96", "steel", fill=False)
    label = rect(50, 66, 28, 22, "white", 4)
    return shadow() + hose + tank + head + label + path("M64,84 Q58,78 60,72 Q64,74 66,70 Q70,76 68,84 Z", "orange")


@icon("plane")
def _():
    water = ('<path d="M44,74 Q40,100 30,120 L86,120 Q76,100 72,74 Z" fill="#7dd3fc" opacity="0.65"/>'
             + "".join(dot(x, y, 3.5, "#0ea5e9") for x, y in ((48, 96), (62, 106), (74, 92), (56, 116), (40, 112))))
    plane = (path("M10,56 Q14,44 30,44 L104,44 Q120,46 120,56 Q118,66 104,66 L30,66 Q14,66 10,56 Z", "amber")
             + poly([(46, 54), (84, 20), (96, 20), (74, 56)], "red") + poly([(46, 58), (84, 92), (96, 92), (74, 58)], "red")
             + poly([(14, 52), (6, 30), (20, 30), (30, 48)], "red") + rect(98, 48, 12, 8, "sky", 3))
    return water + plane + shine(34, 47, 40, 5)


# ------------------------------------------------------------------ FARKINDALIK
@icon("news")
def _():
    paper = rect(16, 18, 90, 96, "white", 6) + rect(22, 12, 90, 96, "white", 6)
    paper += rect(32, 24, 70, 12, "blue", 3)
    for i, w in enumerate((40, 40, 40, 70, 70)):
        y = 46 + i * 12 if i < 3 else 46 + i * 12
        paper += rect(32 if i >= 3 else 62, y, w if i >= 3 else 40, 5, "slate", 2)
    tri = poly([(44, 44), (58, 70), (30, 70)], "amber") + rect(42, 52, 4, 10, "orange", 1)
    return shadow() + paper + tri


@icon("drill")
def _():
    door = rect(76, 20, 40, 92, "emerald", 6) + rect(84, 30, 24, 72, "white", 3)
    arrow = poly([(24, 46), (58, 46), (58, 34), (74, 54), (58, 74), (58, 62), (24, 62)], "emerald")
    runner = (circ(34, 22, 9, "skin") + path("M28,32 L44,36 L48,62 L36,64 Z", "blue")
              + line(40, 62, 30, 90, "blue", 7) + line(44, 62, 58, 86, "blue", 7) + line(30, 40, 16, 52, "blue", 6))
    return shadow() + door + arrow + runner


@icon("booklet")
def _():
    book = (path("M64,30 Q40,20 14,26 L14,104 Q40,98 64,108 Z", "blue")
            + path("M64,30 Q88,20 114,26 L114,104 Q88,98 64,108 Z", "sky")
            + line(64, 30, 64, 108, "navy", 3))
    for i in range(3):
        book += line(24, 44 + i * 14, 52, 42 + i * 14, "white", 3).replace(P["white"][1], "#dbeafe")
    star = poly([(89, 40), (94, 52), (106, 53), (97, 61), (100, 74), (89, 67), (78, 74), (81, 61), (72, 53), (84, 52)], "amber")
    return shadow() + book + star


@icon("kits")
def _():
    bag = (rect(28, 34, 72, 78, "orange", 16) + path("M44,36 Q44,14 64,14 Q84,14 84,36", "orange", fill=False)
           + rect(36, 76, 56, 28, "amber", 8) + shine(34, 42, 10, 30))
    cross = (circ(64, 52, 14, "white").replace(P["white"][0], "#ffffff")
             + '<rect x="58" y="42" width="12" height="20" rx="2" fill="#ef4444"/>'
             + '<rect x="54" y="46" width="20" height="12" rx="2" fill="#ef4444"/>')
    return shadow() + bag + cross


@icon("tv")
def _():
    tv = (rect(10, 26, 108, 76, "violet", 10) + rect(20, 34, 88, 58, "white", 6).replace(P["white"][0], "#e0f2fe")
          + line(44, 26, 34, 10, "violet") + line(84, 26, 94, 10, "violet") + rect(44, 102, 40, 10, "violet", 3))
    table = rect(36, 52, 56, 8, "wood", 3) + line(42, 60, 42, 86, "brown", 4) + line(86, 60, 86, 86, "brown", 4)
    kid = circ(60, 72, 7, "skin") + path("M50,88 Q50,76 62,76 Q74,76 74,88 Z", "blue")
    return shadow(118, 40) + tv + table + kid


@icon("volunteers")
def _():
    def vol(x, y, s):
        return (path(f"M{x-15*s},{y+38*s} Q{x-15*s},{y+10*s} {x},{y+10*s} Q{x+15*s},{y+10*s} {x+15*s},{y+38*s} Z", "orange")
                + rect(x - 15 * s, y + 22 * s, 30 * s, 5 * s, "amber", 1)
                + circ(x, y, 10 * s, "skin") + path(f"M{x-12*s},{y-3*s} Q{x-12*s},{y-16*s} {x},{y-16*s} Q{x+12*s},{y-16*s} {x+12*s},{y-3*s} Z", "white"))
    return shadow() + vol(38, 52, 1.35) + vol(90, 46, 1.5)


# ------------------------------------------------------------------ magaza secici (Deprem / Sel / Yangin)
@icon("hazard_deprem")
def _():
    b = rect(30, 24, 52, 84, "orange", 4)
    for yy in (34, 56, 78):
        b += rect(40, yy, 12, 14, "cream", 2) + rect(60, yy, 12, 14, "cream", 2)
    crack = path("M56,24 L48,46 L60,58 L50,80 L58,108", "brown", fill=False)
    ground = path("M4,108 L46,108 L52,116 L60,108 L124,108", "brown", fill=False)
    lines = line(96, 40, 112, 36, "orange") + line(98, 60, 116, 60, "orange") + line(96, 80, 112, 84, "orange")
    return b + crack + ground + lines


@icon("hazard_sel")
def _():
    h = house(30, 34, 64, "cream", "blue")
    water = path("M4,82 Q20,74 36,82 Q52,90 68,82 Q84,74 100,82 Q112,88 124,82 L124,120 L4,120 Z", "sky")
    return h + water + shine(10, 88, 24, 5)


@icon("hazard_yangin")
def _():
    outer = path("M64,10 Q90,40 92,66 Q96,100 64,116 Q32,100 36,66 Q38,50 50,38 Q52,56 62,60 Q56,32 64,10 Z", "red")
    inner = path("M64,52 Q80,70 78,88 Q76,104 64,108 Q52,104 50,88 Q50,72 64,52 Z", "amber")
    return outer + inner + shine(46, 70, 6, 16)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(svg(fn()))
    print(len(ICONS), "ikon ->", OUT)
