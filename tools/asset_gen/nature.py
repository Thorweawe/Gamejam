"""Dag, kopru, piknik, yanik zemin, dere islahi duvari, hayvanlar, tekne."""
import math

import numpy as np

from kitgen import GLASS, Model, blob, cbox, chunk, cyl, rot
from parts import block

T = 0.1


# ---------------------------------------------------------------- daglar
def _ring(r, y, n, rng, jitter=0.15, cx=0.0, cz=0.0, phase=0.0):
    return [(cx + math.cos(phase + 2 * math.pi * i / n) * r * rng.uniform(1 - jitter, 1 + jitter), y,
             cz + math.sin(phase + 2 * math.pi * i / n) * r * rng.uniform(1 - jitter, 1 + jitter)) for i in range(n)]


def mountain(name, R, H, seed, snow=True):
    m = Model(name)
    rng = np.random.default_rng(seed)
    peak = (rng.uniform(-0.15, 0.15) * R, H, rng.uniform(-0.15, 0.15) * R)
    base = _ring(R, 0.0, 9, rng)
    mid = _ring(R * 0.55, H * 0.5, 7, rng, 0.2, peak[0] * 0.5, peak[2] * 0.5, 0.3)
    m.add(base + mid + [peak], "warmgrey", grad=(0.0, 0.9))
    # etekler yesil
    m.add(_ring(R * 1.03, 0.0, 9, rng, 0.08) + _ring(R * 0.8, H * 0.22, 9, rng, 0.08, 0, 0, 0.2), "darkgreen", grad=(0.1, 0.8))
    if snow:
        top = [(peak[0] + (x - peak[0]) * 0.28 * 1.06, H * 0.74, peak[2] + (z - peak[2]) * 0.28 * 1.06)
               for (x, _, z) in _ring(R, 0, 7, rng, 0.1)]
        m.add(top + [(peak[0], H * 1.01, peak[2])], "white", grad=(0.0, 0.4))
    # kucuk kayalar
    for i in range(4):
        a = rng.uniform(0, 2 * math.pi)
        m.add(chunk(math.cos(a) * R * 0.95, 0.0, math.sin(a) * R * 0.95, R * 0.12, seed + i), "warmgrey", grad=(0.2, 0.7))
    return m


def mountain_tall():
    """Sivri, karli yuksek zirve."""
    m = mountain("mountain_tall", 1.9, 4.6, 11)
    rng = np.random.default_rng(12)
    for i in range(3):  # yamacta kaya cikintilari
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.6, 1.0)
        m.add(chunk(math.cos(a) * r, rng.uniform(0.6, 1.6), math.sin(a) * r, 0.35, 20 + i), "warmgrey", grad=(0.2, 0.8))
    return m


def mountain_ridge():
    """Uzun dag sirti: uc zirveli, ortasi karli."""
    m = Model("mountain_ridge")
    rng = np.random.default_rng(13)
    for x, h in ((-1.1, 1.6), (0.0, 2.3), (1.1, 1.5)):
        base = _ring(1.1, 0.0, 8, rng, 0.15, x, 0.0)
        mid = _ring(0.6, h * 0.55, 6, rng, 0.2, x, 0.0, 0.4)
        m.add(base + mid + [(x + rng.uniform(-0.1, 0.1), h, rng.uniform(-0.1, 0.1))], "warmgrey", grad=(0.0, 0.9))
        m.add(_ring(1.15, 0.0, 8, rng, 0.08, x, 0.0) + _ring(0.9, h * 0.25, 8, rng, 0.08, x, 0.0, 0.2), "darkgreen", grad=(0.1, 0.8))
        if h > 2.0:
            m.add(_ring(0.24, h * 0.78, 6, rng, 0.1, x, 0.0) + [(x, h * 1.01, 0.0)], "white", grad=(0.0, 0.4))
    return m


def mountain_large():
    return mountain("mountain_large", 2.4, 3.6, 1)


def mountain_medium():
    return mountain("mountain_medium", 1.6, 2.3, 2)


def mountain_small():
    return mountain("mountain_small", 1.0, 1.2, 3, snow=False)


def hill():
    m = Model("hill")
    rng = np.random.default_rng(4)
    m.add(_ring(1.0, 0.0, 9, rng, 0.1) + _ring(0.6, 0.35, 7, rng, 0.15) + [(0.05, 0.5, 0.0)], "green", grad=(0.0, 0.7))
    return m


def tile_mountain():
    """Daglik zemin: koyu cim + kaya lekeleri."""
    m = Model("tile_mountain")
    block(m, -1, 1, 0, T - 0.025, -1, 1, "brown", (0.3, 0.9))
    block(m, -1, 1, T - 0.025, T, -1, 1, "darkgreen", (0.0, 0.4))
    rng = np.random.default_rng(5)
    for i in range(3):
        m.add(chunk(rng.uniform(-0.7, 0.7), T - 0.02, rng.uniform(-0.7, 0.7), 0.12, 70 + i, flat=0.35), "warmgrey",
              grad=(0.2, 0.7))
    return m


def _path(name, sides):
    """Orman ici toprak patika (itfaiye orman yanginina buradan gider). Acik kenarlar yol modelleriyle ayni kural."""
    m = Model(name)
    block(m, -1, 1, 0, T, -1, 1, "green", (0.0, 0.5))
    w = 0.34
    y0, y1 = T - 0.004, T + 0.006
    block(m, -w, w, y0, y1, -w, w, "tan", (0.2, 0.8))
    arms = {"+z": (-w, w, w, 1), "-z": (-w, w, -1, -w), "+x": (w, 1, -w, w), "-x": (-1, -w, -w, w)}
    for sd in sides:
        x0, x1, z0, z1 = arms[sd]
        block(m, x0, x1, y0, y1, z0, z1, "tan", (0.2, 0.8))
    rng = np.random.default_rng(len(name))
    for i in range(5):  # tekerlek izi / cakil
        m.add(cbox(rng.uniform(-0.2, 0.2), y1 + 0.003, rng.uniform(-0.8, 0.8) if "+z" in sides else rng.uniform(-0.2, 0.2),
                   0.05, 0.008, 0.05), "brown", grad=(0.2, 0.6))
    return m


def path_straight():
    return _path("path_straight", {"+z", "-z"})


def path_corner():
    return _path("path_corner", {"+x", "+z"})


def path_tsplit():
    return _path("path_tsplit", {"+x", "+z", "-z"})


def path_junction():
    return _path("path_junction", {"+x", "-x", "+z", "-z"})


def path_end():
    return _path("path_end", {"+z"})


def tile_grass_burnt():
    m = Model("tile_grass_burnt")
    block(m, -1, 1, 0, T - 0.025, -1, 1, "brown", (0.3, 0.9))
    block(m, -1, 1, T - 0.025, T, -1, 1, "charcoal", (0.0, 0.5))
    rng = np.random.default_rng(6)
    for i in range(6):
        x, z = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)
        m.add(cbox(x, T + 0.002, z, rng.uniform(0.15, 0.35), 0.004, rng.uniform(0.15, 0.35)), "black", grad=(0.3, 0.6))
    return m


# ---------------------------------------------------------------- kopru, dere islahi
def road_bridge():
    """Yol Z boyunca, nehir X boyunca akar. Tabliye karonun tamamini kaplar ve KayKit yoluyla
    ayni olculerde (asfalt 0.07, kaldirim 0.1, kaldirim x>0.92) -> komsu yol karolariyla bitisik."""
    m = Model("road_bridge")
    w = 0.45
    block(m, -1, 1, 0, 0.03, -w, w, "tan", (0.3, 0.9))
    block(m, -1, 1, 0.03, 0.05, -w, w, "blue", (0.05, 0.35))
    # ayaklar (sudan gorunur)
    for x in (-0.6, 0.0, 0.6):
        for z in (-0.3, 0.3):
            m.add(cbox(x, 0.03, z, 0.14, 0.06, 0.14), "lightgrey", grad=(0.2, 0.8))
    # tabliye
    block(m, -1.0, 1.0, 0.05, 0.068, -1, 1, "lightgrey", (0.2, 0.7))
    block(m, -0.92, 0.92, 0.068, 0.07, -1, 1, "darkgrey", (0.3, 0.6))
    for i in range(5):
        m.add(cbox(0, 0.072, -0.8 + i * 0.4, 0.03, 0.004, 0.2), "sun", grad=(0.0, 0.3))
    for sx in (1, -1):
        block(m, sx * 0.96 - 0.04, sx * 0.96 + 0.04, 0.068, 0.1, -1, 1, "lightgrey", (0.1, 0.5))  # kaldirim
        block(m, sx * 0.985 - 0.012, sx * 0.985 + 0.012, 0.1, 0.2, -w - 0.1, w + 0.1, "white", (0.0, 0.4))  # korkuluk
        for z in (-w - 0.1, -0.2, 0.2, w + 0.1):
            m.add(cbox(sx * 0.985, 0.16, z, 0.03, 0.12, 0.03), "lightgrey", grad=(0.1, 0.5))
        # tabliye kenari: suya bakan beton yuz
        block(m, sx * 1.0 - 0.02, sx * 1.0, 0.0, 0.068, -w, w, "lightgrey", (0.1, 0.8))
    return m


def river_wall():
    """Dere islahi: nehir kiyilarina beton duvar (tile_river_straight ile ayni yon, Z boyunca)."""
    m = Model("river_wall")
    for sx in (1, -1):
        block(m, sx * 0.47 - 0.06, sx * 0.47 + 0.06, 0.0, 0.24, -1, 1, "lightgrey", (0.1, 0.8))
        block(m, sx * 0.47 - 0.07, sx * 0.47 + 0.07, 0.24, 0.27, -1, 1, "sun", (0.0, 0.4))
        for i in range(4):
            m.add(cbox(sx * 0.395, 0.06, -0.75 + i * 0.5, 0.012, 0.06, 0.04), "darkgrey", grad=(0.2, 0.6))
    return m


# ---------------------------------------------------------------- piknik
def bbq_grill():
    m = Model("bbq_grill")
    for sx in (1, -1):
        for sz in (1, -1):
            m.add(cbox(sx * 0.06, 0.06, sz * 0.04, 0.012, 0.12, 0.012), "charcoal")
    m.add(cbox(0, 0.13, 0, 0.18, 0.04, 0.12, bevel=0.01), "black", grad=(0.2, 0.6))
    m.add(cbox(0, 0.152, 0, 0.16, 0.006, 0.1), "flame", grad=(0.0, 0.3))
    for i in range(5):
        m.add(cbox(-0.06 + i * 0.03, 0.157, 0, 0.006, 0.004, 0.11), "darkgrey")
    for i, x in enumerate((-0.04, 0.03)):
        m.add(cbox(x, 0.162, 0.01 * (i * 2 - 1), 0.04, 0.012, 0.025, bevel=0.004), "brick", grad=(0.1, 0.5))
    return m


def picnic_table():
    m = Model("picnic_table")
    m.add(cbox(0, 0.13, 0, 0.36, 0.02, 0.2), "brown", grad=(0.1, 0.6))
    for sz in (1, -1):
        m.add(cbox(0, 0.07, sz * 0.17, 0.34, 0.016, 0.07), "brown", grad=(0.1, 0.6))
        for sx in (1, -1):
            m.add(rot(cbox(sx * 0.13, 0.065, sz * 0.06, 0.02, 0.15, 0.02), rx=sz * 25, pivot=(sx * 0.13, 0.065, sz * 0.06)),
                  "brown", grad=(0.2, 0.7))
    m.add(cbox(0.08, 0.15, 0.03, 0.04, 0.02, 0.03), "white", grad=(0.0, 0.3))
    m.add(cyl(0.012, 0.012, 0.14, 0.2, n=6, center=(-0.1, 0, -0.04)), "teal", grad=(0.0, 0.5))  # cam sise
    return m


def picnic_blanket():
    m = Model("picnic_blanket")
    for i in range(4):
        for j in range(4):
            m.add(cbox(-0.15 + i * 0.1, 0.004, -0.15 + j * 0.1, 0.1, 0.008, 0.1), "red" if (i + j) % 2 else "white",
                  grad=(0.1, 0.4))
    m.add(cbox(0.1, 0.03, 0.08, 0.08, 0.05, 0.06, bevel=0.01), "ochre", grad=(0.0, 0.5))
    return m


# ---------------------------------------------------------------- hayvanlar
def bird(name, body, wing, beak, size=1.0):
    """Kanatlar ayri node (wing_l / wing_r) -> cirpma animasyonu. On +Z."""
    s = size
    m = Model(name)
    m.add(blob(0, 0, 0, 0.05 * s, sy=0.7, jitter=0.02, seed=1, smooth=True), body, grad=(0.0, 0.6))
    m.add([(p[0], p[1], p[2] * 1.7) for p in blob(0, 0, 0, 0.05 * s, sy=0.7, jitter=0.0, seed=2)], body, grad=(0.0, 0.6))
    m.add(blob(0, 0.025 * s, 0.075 * s, 0.03 * s, seed=3, smooth=True), body, grad=(0.0, 0.5))
    m.add(cyl(0.012 * s, 0.0, 0.0, 0.035 * s, n=4, axis="z", center=(0, 0.022 * s, 0.1 * s)), beak, grad=(0.0, 0.4))
    m.add(cbox(0, 0.005, -0.1 * s, 0.05 * s, 0.01 * s, 0.05 * s), wing, grad=(0.1, 0.5))
    for side, sx in (("l", 1), ("r", -1)):
        w = Model(f"{name}_wing_{side}")
        w.add([(sx * x, y, z) for (x, y, z) in ((0, 0, 0.03 * s), (0, 0, -0.04 * s), (0.2 * s, 0, -0.01 * s),
                                                 (0.17 * s, 0, -0.06 * s), (0, 0.008, 0), (0.18 * s, 0.006, -0.03 * s))],
              wing, grad=(0.0, 0.5))
        m.child(w, (sx * 0.035 * s, 0.015 * s, 0))
    return m


def seagull():
    return bird("seagull", "white", "lightgrey", "orange", 1.0)


def crow():
    return bird("bird_small", "charcoal", "black", "darkgrey", 0.7)


def quadruped(name, body, dark, belly, L, Hh, head_len, extras=None):
    """Bacaklar ayri node (leg_fl, leg_fr, leg_bl, leg_br) -> yurume animasyonu. On +Z."""
    m = Model(name)
    leg_h = Hh * 0.55
    m.add(cbox(0, leg_h + Hh * 0.18, 0, L * 0.35, Hh * 0.36, L, bevel=0.02), body, grad=(0.0, 0.6))
    m.add(cbox(0, leg_h + Hh * 0.04, 0, L * 0.3, 0.02, L * 0.8), belly, grad=(0.0, 0.4))
    neck = cbox(0, leg_h + Hh * 0.45, L * 0.45, L * 0.18, Hh * 0.45, L * 0.18)
    m.add(rot(neck, rx=-25, pivot=(0, leg_h + Hh * 0.3, L * 0.45)), body, grad=(0.0, 0.6))
    hy = leg_h + Hh * 0.68
    m.add(cbox(0, hy, L * 0.58, L * 0.2, Hh * 0.2, head_len, bevel=0.01), body, grad=(0.0, 0.5))
    m.add(cbox(0, hy - 0.01, L * 0.58 + head_len * 0.55, L * 0.12, Hh * 0.12, head_len * 0.3), dark, grad=(0.1, 0.5))
    for sx in (1, -1):
        m.add(cbox(sx * L * 0.12, hy + Hh * 0.12, L * 0.52, L * 0.06, Hh * 0.14, 0.02), body, grad=(0.0, 0.5))
        m.add(cbox(sx * L * 0.07, hy + 0.01, L * 0.58 + head_len * 0.25, 0.012, 0.012, 0.004), "black", grad=(0.3, 0.6))
    m.add(cbox(0, leg_h + Hh * 0.28, -L * 0.52, L * 0.07, L * 0.07, L * 0.12), belly, grad=(0.0, 0.4))
    if extras:
        extras(m, hy, L, Hh)
    for nm, sx, sz in (("fl", 1, 1), ("fr", -1, 1), ("bl", 1, -1), ("br", -1, -1)):
        leg = Model(f"{name}_leg_{nm}")
        leg.add(cbox(0, -leg_h / 2, 0, L * 0.08, leg_h, L * 0.08), body, grad=(0.0, 0.6))
        leg.add(cbox(0, -leg_h + 0.008, 0, L * 0.085, 0.016, L * 0.09), dark)
        m.child(leg, (sx * L * 0.12, leg_h, sz * L * 0.38))
    return m


def _antlers(m, hy, L, Hh):
    for sx in (1, -1):
        m.add(rot(cbox(sx * 0.03, hy + 0.08, L * 0.52, 0.01, 0.1, 0.01), rz=-sx * 20, pivot=(sx * 0.02, hy + 0.04, L * 0.52)),
              "brown", grad=(0.2, 0.6))
        m.add(rot(cbox(sx * 0.05, hy + 0.11, L * 0.55, 0.008, 0.05, 0.008), rx=-30, pivot=(sx * 0.05, hy + 0.09, L * 0.53)),
              "brown", grad=(0.2, 0.6))


def deer():
    return quadruped("deer", "terracotta", "brown", "cream", 0.3, 0.3, 0.1, _antlers)


def _horns(m, hy, L, Hh):
    for sx in (1, -1):
        h = cbox(sx * 0.025, hy + 0.06, L * 0.5, 0.014, 0.08, 0.014)
        m.add(rot(h, rx=40, rz=-sx * 15, pivot=(sx * 0.025, hy + 0.03, L * 0.52)), "warmgrey", grad=(0.2, 0.6))
    m.add(cbox(0, hy - 0.05, L * 0.62, 0.02, 0.05, 0.02), "lightgrey", grad=(0.0, 0.5))  # sakal


def goat():
    """Dag keçisi: daglarda gezer (wildlife.gd)."""
    return quadruped("goat", "white", "warmgrey", "lightgrey", 0.22, 0.2, 0.08, _horns)


def dog():
    return quadruped("dog", "ochre", "brown", "cream", 0.2, 0.14, 0.07)


# ---------------------------------------------------------------- tekne
def boat():
    m = Model("boat_fishing")
    hull = []
    for (w, y, z) in ((0.16, 0.0, 0.42), (0.2, 0.0, -0.38), (0.0, 0.0, 0.52), (0.22, 0.14, 0.42), (0.24, 0.14, -0.4),
                      (0.0, 0.16, 0.62)):
        hull += [(w, y, z), (-w, y, z)]
    m.add(hull, "white", grad=(0.0, 0.6))
    m.add([(p[0] * 1.02, min(p[1], 0.05) - 0.01, p[2] * 1.01) for p in hull if p[1] < 0.1] +
          [(p[0] * 1.03, 0.05, p[2] * 1.01) for p in hull if p[1] < 0.1], "red", grad=(0.1, 0.5))
    m.add(cbox(0, 0.15, 0, 0.42, 0.02, 0.9), "brown", grad=(0.1, 0.6))
    m.add(cbox(0, 0.25, -0.12, 0.26, 0.18, 0.26, bevel=0.01), "white", grad=(0.0, 0.5))
    m.add(cbox(0, 0.25, 0.01, 0.2, 0.08, 0.006), None, uv=GLASS)
    m.add(cbox(0, 0.35, -0.12, 0.3, 0.03, 0.3), "blue", grad=(0.1, 0.5))
    m.add(cyl(0.01, 0.008, 0.16, 0.7, n=5, center=(0, 0, 0.2)), "lightgrey")
    m.add(cbox(0, 0.62, 0.16, 0.004, 0.004, 0.12), "charcoal")
    m.add(cbox(0.12, 0.18, -0.32, 0.12, 0.05, 0.1), "orange", grad=(0.0, 0.5))
    return m


MODELS = [mountain_large, mountain_medium, mountain_small, hill, tile_mountain, tile_grass_burnt, road_bridge,
          river_wall, bbq_grill, picnic_table, picnic_blanket, seagull, crow, deer, dog, boat]


# ---------------------------------------------------------------- harita suslemeleri
def fountain():
    m = Model("fountain")
    m.add(cyl(0.55, 0.55, 0.1, 0.2, n=16), "lightgrey", grad=(0.2, 0.8))
    m.add(cyl(0.48, 0.48, 0.12, 0.185, n=16), "skyblue", grad=(0.0, 0.3))
    m.add(cyl(0.08, 0.06, 0.18, 0.5, n=8), "white", grad=(0.0, 0.5))
    m.add(cyl(0.2, 0.12, 0.48, 0.55, n=12), "lightgrey", grad=(0.2, 0.7))
    m.add(cyl(0.17, 0.17, 0.5, 0.545, n=12), "skyblue", grad=(0.0, 0.3))
    m.add(cyl(0.03, 0.0, 0.55, 0.75, n=6), "skyblue", grad=(0.0, 0.2))
    for i in range(6):
        a = i * math.pi / 3
        m.add(rot(cbox(math.cos(a) * 0.3, 0.3, math.sin(a) * 0.3, 0.02, 0.12, 0.02), rz=math.degrees(a) * 0 + 25,
                  ry=-math.degrees(a), pivot=(math.cos(a) * 0.3, 0.3, math.sin(a) * 0.3)), "white", grad=(0.0, 0.2))
    return m


def beach_umbrella():
    m = Model("beach_umbrella")
    m.add(cyl(0.012, 0.012, 0.0, 0.42, n=6), "white")
    n = 8
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        pts = [(0, 0.48, 0), (math.cos(a0) * 0.3, 0.38, math.sin(a0) * 0.3), (math.cos(a1) * 0.3, 0.38, math.sin(a1) * 0.3),
               (0, 0.47, 0), (math.cos(a0) * 0.3, 0.375, math.sin(a0) * 0.3), (math.cos(a1) * 0.3, 0.375, math.sin(a1) * 0.3)]
        m.add(pts, "red" if i % 2 else "white", grad=(0.1, 0.4))
    m.add(cbox(0.18, 0.006, 0.05, 0.14, 0.012, 0.3), "blue", grad=(0.1, 0.4))
    m.add(cbox(0.18, 0.012, 0.05, 0.1, 0.004, 0.26), "sun", grad=(0.0, 0.3))
    return m


def pier():
    """Iskele: +X yonunde denize uzanir (3 karo)."""
    m = Model("pier")
    L = 5.6
    m.add(cbox(L / 2, 0.12, 0, L, 0.04, 0.5), "brown", grad=(0.1, 0.6))
    for i in range(14):
        m.add(cbox(0.2 + i * 0.4, 0.143, 0, 0.02, 0.004, 0.5), "tan", grad=(0.2, 0.6))
    for i in range(8):
        for sz in (1, -1):
            m.add(cyl(0.035, 0.035, -0.3, 0.2, n=6, center=(0.3 + i * 0.75, 0, sz * 0.27)), "brown", grad=(0.2, 0.8))
    for sz in (1, -1):
        m.add(cbox(L / 2, 0.25, sz * 0.24, L, 0.02, 0.02), "white", grad=(0.0, 0.3))
    m.add(cyl(0.012, 0.012, 0.14, 0.6, n=5, center=(L - 0.1, 0, 0.2)), "darkgrey")
    m.add(cbox(L - 0.1, 0.62, 0.2, 0.06, 0.06, 0.06), "sun", grad=(0.0, 0.3))
    return m


def lighthouse():
    m = Model("lighthouse")
    rng = np.random.default_rng(12)
    for i in range(6):
        a = 2 * math.pi * i / 6
        m.add(chunk(math.cos(a) * 0.5, 0.0, math.sin(a) * 0.5, 0.22, 200 + i), "warmgrey", grad=(0.2, 0.8))
    m.add(cyl(0.45, 0.42, 0.0, 0.15, n=10), "lightgrey", grad=(0.2, 0.8))
    for i in range(5):
        y0 = 0.15 + i * 0.4
        r0, r1 = 0.3 - i * 0.03, 0.3 - (i + 1) * 0.03
        m.add(cyl(r0, r1, y0, y0 + 0.4, n=10), "red" if i % 2 else "white", grad=(0.0, 0.6))
    top = 2.15
    m.add(cyl(0.26, 0.26, top, top + 0.05, n=10), "darkgrey")
    for i in range(10):
        a = 2 * math.pi * i / 10
        m.add(cbox(math.cos(a) * 0.24, top + 0.12, math.sin(a) * 0.24, 0.015, 0.12, 0.015), "darkgrey")
    m.add(cyl(0.15, 0.15, top + 0.05, top + 0.3, n=8), None, uv=GLASS)
    m.add(cyl(0.08, 0.08, top + 0.08, top + 0.26, n=8), "sun", grad=(0.0, 0.2))
    m.add(cyl(0.2, 0.02, top + 0.3, top + 0.5, n=8), "red", grad=(0.0, 0.5))
    m.add(cbox(0.0, 0.3, 0.29, 0.1, 0.16, 0.03), "brown", grad=(0.1, 0.6))
    return m


def _grass_tile(name, shade, flowers, seed):
    m = Model(name)
    block(m, -1, 1, 0, T - 0.025, -1, 1, "brown", (0.2, 0.9))
    block(m, -1, 1, T - 0.025, T, -1, 1, "green", shade)
    rng = np.random.default_rng(seed)
    for i in range(7):
        x, z = rng.uniform(-0.85, 0.85), rng.uniform(-0.85, 0.85)
        m.add(cyl(0.05, 0.0, T, T + rng.uniform(0.05, 0.09), n=4, phase=rng.uniform(0, 3), center=(x, 0, z)),
              "darkgreen", grad=(0.0, 0.6))
    for i in range(flowers):
        x, z = rng.uniform(-0.85, 0.85), rng.uniform(-0.85, 0.85)
        col = ["white", "sun", "salmon", "skyblue"][i % 4]
        m.add(cbox(x, T + 0.012, z, 0.035, 0.024, 0.035), col, grad=(0.0, 0.3))
    return m


def tile_grass_b():
    return _grass_tile("tile_grass_b", (0.2, 0.55), 9, 31)


def tile_grass_c():
    return _grass_tile("tile_grass_c", (0.3, 0.65), 0, 32)


MODELS += [fountain, beach_umbrella, pier, lighthouse, tile_grass_b, tile_grass_c, goat, mountain_tall, mountain_ridge,
           path_straight, path_corner, path_tsplit, path_junction, path_end]
