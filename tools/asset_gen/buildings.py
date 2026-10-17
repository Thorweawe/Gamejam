"""Ozel binalar. 2x2 karo, kaldirim tabani (y 0-0.1), on cephe +Z, kat ~0.7."""
import os

import numpy as np

from kitgen import GLASS, Model, blob, cbox, chunk, cyl, rot
from parts import (KAYKIT, awning, base_slab, block, crack, cross_sign, door, flag_tr, ledge, wall_hole,
                   roof_flat, roof_hip, window, window_row)

F = 0.7  # kat yuksekligi
AI_DIR = os.path.join(os.path.dirname(KAYKIT), "ai_uretim")
Y0 = 0.1  # taban ustu


def floors_y(i):
    return Y0 + F * i


# ---------------------------------------------------------------- belediye
def town_hall(level):
    m = Model(f"building_townhall_lv{level}")
    base_slab(m)
    hw = {1: 0.7, 2: 0.85, 3: 0.85}[level]
    nf = {1: 1, 2: 2, 3: 3}[level]
    z0, z1 = -0.6, 0.35
    top = floors_y(nf)
    block(m, -hw - 0.04, hw + 0.04, Y0, Y0 + 0.08, z0 - 0.04, z1 + 0.04, "lightgrey", (0.3, 0.8))
    block(m, -hw, hw, Y0 + 0.08, top, z0, z1, "cream", (0.0, 0.7))
    for i in range(1, nf):
        ledge(m, -hw, hw, z0, z1, floors_y(i), "white")
    ledge(m, -hw, hw, z0, z1, top, "white", out=0.05, h=0.06)
    # pencereler
    xs = [x for x in np.linspace(-hw + 0.15, hw - 0.15, 6 if hw > 0.75 else 4) if abs(x) > 0.3]
    for i in range(nf):
        y = floors_y(i) + 0.38
        window_row(m, "+z", z1, xs, y, w=0.14, h=0.28)
        window_row(m, "-z", z0, np.linspace(-hw + 0.15, hw - 0.15, 5), y, w=0.14, h=0.28)
        for face, wall in (("+x", hw), ("-x", -hw)):
            window_row(m, face, wall, [-0.38, -0.05], y, w=0.14, h=0.28)
    # revak: sutunlar + alinlik + merdiven
    ph = F * min(nf, 2)
    pz = z1 + 0.28
    for x in (-0.27, -0.09, 0.09, 0.27):
        m.add(cyl(0.04, 0.035, Y0 + 0.1, Y0 + ph, n=8, center=(x, 0, pz)), "white", grad=(0.0, 0.5))
        m.add(cbox(x, Y0 + 0.1, pz, 0.1, 0.04, 0.1), "lightgrey")
    for i, d in enumerate((0.0, 0.08, 0.16)):
        block(m, -0.36 + d / 2, 0.36 - d / 2, Y0 + 0.03 * i, Y0 + 0.03 * (i + 1) + 0.0, z1, pz + 0.12 - d, "lightgrey", (0.2, 0.7))
    py = Y0 + ph
    block(m, -0.38, 0.38, py, py + 0.07, z1 - 0.02, pz + 0.07, "white", (0.0, 0.4))
    m.add([(x, py + 0.07, z) for x in (-0.38, 0.38) for z in (z1, pz + 0.07)] +
          [(0, py + 0.25, z) for z in (z1, pz + 0.07)], "cream", grad=(0.0, 0.6))
    m.add(cyl(0.05, 0.05, 0, 0.01, n=10, axis="z", center=(0, py + 0.13, pz + 0.075)), "ochre", grad=(0.0, 0.4))
    door(m, "+z", z1, 0, Y0 + 0.09, w=0.2, h=0.38, color="brown")
    m.add(cbox(0, Y0 + 0.55, z1 + 0.015, 0.3, 0.06, 0.02), "ochre", grad=(0.0, 0.4))  # isim tabelasi
    # cati
    if level == 3:
        roof_flat(m, -hw, hw, z0, z1, top + 0.03)
        # saat kulesi
        tw, tb = 0.22, top + 0.06
        block(m, -tw, tw, tb, tb + 0.55, -0.35, 0.09, "cream", (0.0, 0.6))
        ledge(m, -tw, tw, -0.35, 0.09, tb + 0.55, "white", out=0.03)
        m.add(cyl(0.14, 0.14, 0, 0.02, n=12, axis="z", center=(0, tb + 0.3, 0.09)), "white", grad=(0.0, 0.3))
        m.add(cbox(0, tb + 0.34, 0.112, 0.012, 0.08, 0.008), "black", grad=(0.2, 0.5))
        m.add(cbox(0.025, tb + 0.3, 0.112, 0.06, 0.012, 0.008), "black", grad=(0.2, 0.5))
        m.add(cyl(0.2, 0.02, tb + 0.58, tb + 0.92, n=8, center=(0, 0, -0.13)), "teal", grad=(0.0, 0.7))
        flag_tr(m, 0, tb + 0.9, -0.13, height=0.35, size=0.16)
    else:
        roof_hip(m, -hw, hw, z0, z1, top + 0.03, 0.28 if level == 1 else 0.32)
        flag_tr(m, hw - 0.12, Y0, 0.85, height=0.9 if level == 1 else 1.2)
    if level >= 2:
        for x in (-0.75, 0.75):
            m.add(cbox(x, Y0 + 0.08, 0.75, 0.3, 0.06, 0.3), "lightgrey")
            m.add(cbox(x, Y0 + 0.13, 0.75, 0.26, 0.04, 0.26), "green", grad=(0.1, 0.6))
    return m


def town_hall_1():
    return town_hall(1)


def town_hall_2():
    return town_hall(2)


def town_hall_3():
    return town_hall(3)


# ---------------------------------------------------------------- hastane
def hospital(level=1):
    m = Model("building_hospital" + ("" if level == 1 else f"_lv{level}"))
    base_slab(m)
    hw, z0, z1, nf = 0.75, -0.6, 0.45, 2 + level
    top = floors_y(nf)
    block(m, -hw, hw, Y0, top, z0, z1, "white", (0.0, 0.8))
    for i in range(nf):
        y = floors_y(i) + 0.38
        block(m, -hw - 0.01, hw + 0.01, floors_y(i) + 0.2, floors_y(i) + 0.22, z0 - 0.01, z1 + 0.01, "skyblue", (0.1, 0.5))
        xs = [-0.55, -0.3, 0.3, 0.55] if i == 0 else [-0.55, -0.3, -0.05, 0.2, 0.45]
        if i > 0:
            xs = [-0.55, -0.32, -0.1, 0.12, 0.34, 0.56]
        window_row(m, "+z", z1, xs, y, w=0.15, h=0.26)
        window_row(m, "-z", z0, [-0.55, -0.32, -0.1, 0.12, 0.34, 0.56], y, w=0.15, h=0.26)
        for face, wall in (("+x", hw), ("-x", -hw)):
            window_row(m, face, wall, [-0.4, -0.12, 0.16], y, w=0.15, h=0.26)
    ledge(m, -hw, hw, z0, z1, top, "lightgrey", out=0.03, h=0.06)
    # giris sacagi + cam kapi
    block(m, -0.32, 0.32, Y0 + 0.42, Y0 + 0.47, z1, z1 + 0.35, "lightgrey", (0.1, 0.5))
    block(m, -0.32, 0.32, Y0 + 0.47, Y0 + 0.53, z1 + 0.33, z1 + 0.36, "red", (0.2, 0.5))
    for x in (-0.28, 0.28):
        m.add(cyl(0.015, 0.015, Y0, Y0 + 0.42, n=6, center=(x, 0, z1 + 0.3)), "lightgrey")
    window(m, "+z", z1, 0, Y0 + 0.19, w=0.28, h=0.34, frame="lightgrey", sill=False)
    cross_sign(m, "+z", z1, 0, top - 0.25, size=0.26)
    # cati: helikopter pisti + klima
    roof_flat(m, -hw, hw, z0, z1, top + 0.03)
    m.add(cyl(0.38, 0.38, top + 0.06, top + 0.08, n=16, center=(0.15, 0, -0.1)), "darkgrey", grad=(0.3, 0.6))
    m.add(cyl(0.34, 0.34, top + 0.08, top + 0.085, n=16, center=(0.15, 0, -0.1)), "white", grad=(0.0, 0.2))
    m.add(cyl(0.31, 0.31, top + 0.085, top + 0.09, n=16, center=(0.15, 0, -0.1)), "darkgrey", grad=(0.3, 0.6))
    for dx in (-0.08, 0.08):
        m.add(cbox(0.15 + dx, top + 0.092, -0.1, 0.03, 0.006, 0.22), "white", grad=(0.0, 0.2))
    m.add(cbox(0.15, top + 0.092, -0.1, 0.16, 0.006, 0.03), "white", grad=(0.0, 0.2))
    for z in (-0.4, 0.2):
        m.add(cbox(-0.55, top + 0.12, z, 0.16, 0.12, 0.2, bevel=0.01), "lightgrey")
    if level >= 3:
        helicopter(m, 0.15, top + 0.09, -0.1)
    return m


def helicopter(m, x, y, z):
    """Ambulans helikopteri (hastane lv3 catisinda)."""
    m.add([(p[0] * 1.0 + x, p[1] * 0.75 + y + 0.1, p[2] * 1.5 + z) for p in blob(0, 0, 0, 0.1, jitter=0.02, seed=9, smooth=True)],
          "red", grad=(0.0, 0.6))
    m.add(cbox(x, y + 0.12, z + 0.13, 0.12, 0.07, 0.04), None, uv=GLASS)
    m.add(cbox(x, y + 0.14, z - 0.25, 0.04, 0.04, 0.3), "white", grad=(0.0, 0.4))
    m.add(cbox(x + 0.03, y + 0.17, z - 0.39, 0.01, 0.1, 0.06), "red", grad=(0.0, 0.5))
    for sx in (1, -1):
        m.add(cbox(x + sx * 0.07, y + 0.01, z, 0.015, 0.015, 0.3), "darkgrey")
    m.add(cyl(0.015, 0.015, y + 0.17, y + 0.22, n=5, center=(x, 0, z)), "darkgrey")
    m.add(rot(cbox(x, y + 0.22, z, 0.7, 0.008, 0.04), ry=30, pivot=(x, y, z)), "charcoal")
    m.add(rot(cbox(x, y + 0.22, z, 0.7, 0.008, 0.04), ry=120, pivot=(x, y, z)), "charcoal")
    m.add(cbox(x, y + 0.13, z + 0.0, 0.205, 0.03, 0.06), "white", grad=(0.0, 0.3))


# ---------------------------------------------------------------- itfaiye
def fire_station(level=1):
    m = Model("building_firestation" + ("" if level == 1 else f"_lv{level}"))
    base_slab(m)
    hw, z0, z1 = 0.8, -0.6, 0.45
    nf = 2 if level == 1 else 3
    top = floors_y(nf)
    block(m, -hw, 0.45, Y0, top, z0, z1, "brick", (0.0, 0.8))
    block(m, -0.4, 0.4, Y0 + 0.002, Y0 + 0.004, z1, 0.95, "darkgrey", (0.2, 0.6))  # garaj onu
    # garaj kapilari
    for x in (-0.48, -0.0):
        m.add(cbox(x, Y0 + 0.24, z1 + 0.012, 0.38, 0.48, 0.024), "white", grad=(0.0, 0.3))
        m.add(cbox(x, Y0 + 0.23, z1 + 0.02, 0.32, 0.44, 0.024), "lightgrey", grad=(0.0, 0.7))
        for k in range(6):
            m.add(cbox(x, Y0 + 0.05 + k * 0.07, z1 + 0.033, 0.32, 0.01, 0.006), "darkgrey", grad=(0.2, 0.5))
        m.add(cbox(x, Y0 + 0.36, z1 + 0.034, 0.26, 0.06, 0.006), *("skyblue", (0.05, 0.5)))
    # tabela
    m.add(cbox(-0.24, Y0 + 0.58, z1 + 0.02, 0.75, 0.1, 0.03), "red", grad=(0.2, 0.5))
    m.add(cbox(-0.24, Y0 + 0.58, z1 + 0.037, 0.5, 0.025, 0.006), "white", grad=(0.0, 0.2))
    ledge(m, -hw, 0.45, z0, z1, floors_y(1), "white", out=0.02)
    window_row(m, "+z", z1, [-0.6, -0.36, -0.12, 0.12, 0.34], floors_y(1) + 0.36, w=0.14, h=0.24)
    window_row(m, "-z", z0, [-0.6, -0.3, 0.0, 0.3], floors_y(1) + 0.36, w=0.14, h=0.24)
    window_row(m, "-z", z0, [-0.6, -0.3, 0.0, 0.3], floors_y(0) + 0.36, w=0.14, h=0.24)
    window_row(m, "-x", -hw, [-0.35, 0.1], floors_y(1) + 0.36, w=0.14, h=0.24)
    for i in range(2, nf):
        ledge(m, -hw, 0.45, z0, z1, floors_y(i), "white", out=0.02)
        window_row(m, "+z", z1, [-0.6, -0.36, -0.12, 0.12, 0.34], floors_y(i) + 0.36, w=0.14, h=0.24)
        window_row(m, "-z", z0, [-0.6, -0.3, 0.0, 0.3], floors_y(i) + 0.36, w=0.14, h=0.24)
        window_row(m, "-x", -hw, [-0.35, 0.1], floors_y(i) + 0.36, w=0.14, h=0.24)
    roof_flat(m, -hw, 0.45, z0, z1, top)
    if level >= 3:
        flag_tr(m, -0.2, top + 0.03, -0.2, height=0.6, size=0.2)
        for x in (-0.7, -0.45):  # catida su tanklari
            m.add(cyl(0.09, 0.09, top + 0.03, top + 0.22, n=8, center=(x, 0, 0.25)), "red", grad=(0.0, 0.6))
    # hortum kulesi
    tx0, tx1 = 0.45, 0.8
    block(m, tx0, tx1, Y0, top + 0.75, -0.45, -0.1, "brick", (0.0, 0.8))
    for i in range(3):
        window(m, "+z", -0.1, (tx0 + tx1) / 2, Y0 + 0.75 + i * 0.55, w=0.1, h=0.22)
        window(m, "+x", tx1, -0.27, Y0 + 0.4 + i * 0.6, w=0.1, h=0.22)
    ledge(m, tx0, tx1, -0.45, -0.1, top + 0.75, "white", out=0.03, h=0.06)
    m.add([(x, top + 0.78, z) for x in (tx0 - 0.03, tx1 + 0.03) for z in (-0.48, -0.07)] +
          [((tx0 + tx1) / 2, top + 0.98, -0.275)], "darkgrey")
    door(m, "+z", -0.1, (tx0 + tx1) / 2, Y0, w=0.16, h=0.3, color="red")
    # siren
    m.add(cyl(0.02, 0.02, top + 0.03, top + 0.2, n=6, center=(-0.6, 0, -0.3)), "lightgrey")
    m.add(cyl(0.05, 0.05, top + 0.2, top + 0.26, n=8, center=(-0.6, 0, -0.3)), "red", grad=(0.0, 0.4))
    return m


# ---------------------------------------------------------------- okul
def school():
    m = Model("building_school")
    base_slab(m)
    hw, z0, z1 = 0.9, -0.65, 0.3
    top = floors_y(2)
    block(m, -hw - 0.03, hw + 0.03, Y0, Y0 + 0.07, z0 - 0.03, z1 + 0.03, "lightgrey", (0.3, 0.8))
    block(m, -hw, hw, Y0 + 0.07, top, z0, z1, "ochre", (0.0, 0.45))
    for i in range(2):
        y = floors_y(i) + 0.38
        xs = [-0.72, -0.5, -0.28, 0.28, 0.5, 0.72]
        window_row(m, "+z", z1, xs, y, w=0.15, h=0.28)
        window_row(m, "-z", z0, [-0.72, -0.5, -0.28, -0.06, 0.16, 0.38, 0.6], y, w=0.15, h=0.28)
        for face, wall in (("+x", hw), ("-x", -hw)):
            window_row(m, face, wall, [-0.4, -0.1], y, w=0.15, h=0.28)
    ledge(m, -hw, hw, z0, z1, floors_y(1), "white", out=0.02)
    # orta giris kismi (one cikik)
    block(m, -0.2, 0.2, Y0 + 0.07, top + 0.2, z1, z1 + 0.12, "white", (0.0, 0.5))
    door(m, "+z", z1 + 0.12, 0, Y0 + 0.07, w=0.2, h=0.34, color="teal")
    window(m, "+z", z1 + 0.12, 0, floors_y(1) + 0.38, w=0.18, h=0.28)
    m.add(cyl(0.08, 0.08, 0, 0.02, n=12, axis="z", center=(0, top + 0.05, z1 + 0.12)), "white", grad=(0.0, 0.2))
    m.add(cyl(0.065, 0.065, 0, 0.024, n=12, axis="z", center=(0, top + 0.05, z1 + 0.12)), "cream", grad=(0.0, 0.2))
    m.add(cbox(0, top + 0.07, z1 + 0.146, 0.01, 0.05, 0.006), "black", grad=(0.2, 0.5))
    m.add(cbox(0.015, top + 0.05, z1 + 0.146, 0.04, 0.01, 0.006), "black", grad=(0.2, 0.5))
    block(m, -0.28, 0.28, Y0 + 0.44, Y0 + 0.48, z1 + 0.12, z1 + 0.32, "white", (0.0, 0.4))
    for i, d in enumerate((0.0, 0.06)):
        block(m, -0.25 + d, 0.25 - d, Y0 + 0.035 * i, Y0 + 0.035 * (i + 1), z1 + 0.12, z1 + 0.32 - d, "lightgrey", (0.2, 0.7))
    roof_hip(m, -hw, hw, z0, z1, top, 0.3)
    # bahce: bayrak + basketbol potasi
    flag_tr(m, -0.75, Y0, 0.75, height=1.0)
    m.add(cyl(0.015, 0.015, Y0, Y0 + 0.5, n=6, center=(0.8, 0, 0.82)), "lightgrey")
    m.add(cbox(0.8, Y0 + 0.5, 0.79, 0.16, 0.11, 0.015), "white", grad=(0.0, 0.3))
    m.add(cyl(0.035, 0.035, Y0 + 0.455, Y0 + 0.462, n=8, center=(0.8, 0, 0.74)), "orange", grad=(0.1, 0.4))
    return m


# ---------------------------------------------------------------- AFAD
def afad_center(level=1):
    m = Model("building_afad" + ("" if level == 1 else f"_lv{level}"))
    base_slab(m)
    hw, z0, z1 = 0.8, -0.6, 0.4
    nf = 2 if level == 1 else 3
    top = floors_y(nf)
    block(m, -hw, hw, Y0, top, z0, z1, "white", (0.0, 0.8))
    for i in range(nf):
        block(m, -hw - 0.012, hw + 0.012, floors_y(i) + 0.03, floors_y(i) + 0.1, z0 - 0.012, z1 + 0.012, "orange", (0.05, 0.4))
    block(m, -hw - 0.01, hw + 0.01, top - 0.1, top, z0 - 0.01, z1 + 0.01, "blue", (0.4, 0.9))
    window_row(m, "+z", z1, [-0.6, -0.36, -0.12], floors_y(0) + 0.38, w=0.15, h=0.24)
    window_row(m, "+z", z1, [-0.6, -0.36, -0.12, 0.12, 0.36, 0.6], floors_y(1) + 0.38, w=0.15, h=0.24)
    for i in range(2, nf):
        window_row(m, "+z", z1, [-0.6, -0.36, -0.12, 0.12, 0.36, 0.6], floors_y(i) + 0.38, w=0.15, h=0.24)
    for i in range(nf):
        window_row(m, "-z", z0, [-0.6, -0.3, 0.0, 0.3, 0.6], floors_y(i) + 0.38, w=0.15, h=0.24)
        for face, wall in (("+x", hw), ("-x", -hw)):
            window_row(m, face, wall, [-0.35, 0.05], floors_y(i) + 0.38, w=0.15, h=0.24)
    # garaj + giris
    m.add(cbox(0.4, Y0 + 0.23, z1 + 0.012, 0.5, 0.46, 0.024), "lightgrey", grad=(0.0, 0.3))
    for k in range(6):
        m.add(cbox(0.4, Y0 + 0.05 + k * 0.07, z1 + 0.026, 0.44, 0.01, 0.006), "darkgrey", grad=(0.2, 0.5))
    door(m, "+z", z1, -0.36, Y0, w=0.2, h=0.34, color="blue")
    block(m, -0.52, -0.2, Y0 + 0.42, Y0 + 0.46, z1, z1 + 0.22, "orange", (0.05, 0.4))
    # tabela (lacivert + turuncu logo kutusu)
    m.add(cbox(-0.36, top - 0.22, z1 + 0.02, 0.5, 0.12, 0.03), "blue", grad=(0.4, 0.8))
    m.add(cbox(-0.52, top - 0.22, z1 + 0.037, 0.08, 0.08, 0.006), "orange", grad=(0.05, 0.4))
    m.add(cbox(-0.3, top - 0.22, z1 + 0.037, 0.28, 0.025, 0.006), "white", grad=(0.0, 0.2))
    roof_flat(m, -hw, hw, z0, z1, top)
    # anten diregi + uydu
    for i in range(6):
        y = top + 0.03 + i * 0.15
        m.add(cbox(0.5, y + 0.075, -0.3, 0.04 - i * 0.004, 0.15, 0.04 - i * 0.004), "red" if i % 2 else "white", grad=(0.1, 0.5))
    m.add(cyl(0.02, 0.0, top + 0.93, top + 1.1, n=5, center=(0.5, 0, -0.3)), "lightgrey")
    dish = cyl(0.1, 0.06, 0.0, 0.03, n=12) + [(0, -0.012, 0)]
    m.add([(p[0] - 0.4, p[1] + top + 0.2, p[2] - 0.2) for p in rot(dish, rx=-40)], "white", grad=(0.0, 0.4))
    m.add(cbox(-0.4, top + 0.1, -0.2, 0.04, 0.12, 0.04), "darkgrey")
    if level >= 3:  # bahcede afet cadiri ve yardim paleti
        m.add_raw(os.path.join(AI_DIR, "tent_disaster.gltf"), offset=(-0.55, Y0, 0.75), yaw=0, scale=0.8)
        m.add_raw(os.path.join(AI_DIR, "aid_pallet.gltf"), offset=(0.55, Y0, 0.75), yaw=20)
    return m


# ---------------------------------------------------------------- gazete / TV
def news_building():
    m = Model("building_news")
    base_slab(m)
    hw, z0, z1, nf = 0.65, -0.6, 0.5, 3
    top = floors_y(nf)
    block(m, -hw, hw, Y0, top, z0, z1, "slate", (0.0, 0.7))
    for i in range(nf):
        y0 = floors_y(i)
        for face, wall, span in (("+z", z1, hw), ("-z", z0, hw), ("+x", hw, 0.55), ("-x", -hw, 0.55)):
            m.add(face_box_strip(face, wall, y0 + 0.36, span * 2 - 0.1, 0.36), "skyblue", grad=(0.05, 0.6))
            for a in np.linspace(-span + 0.05, span - 0.05, 6):
                m.add(face_box_strip(face, wall, y0 + 0.36, 0.015, 0.36, a=a, d=0.034), "white", grad=(0.0, 0.3))
        ledge(m, -hw, hw, z0, z1, y0 + 0.13, "white", out=0.015, h=0.05)
    ledge(m, -hw, hw, z0, z1, top, "white", out=0.03, h=0.07)
    # giris + sacak + dev ekran (ayri node: Godot'ta material degistirilebilir)
    window(m, "+z", z1, 0, Y0 + 0.17, w=0.3, h=0.3, frame="darkgrey", sill=False)
    block(m, -0.3, 0.3, Y0 + 0.36, Y0 + 0.4, z1, z1 + 0.25, "darkgrey", (0.1, 0.5))
    screen = Model("building_news_screen")
    screen.add(cbox(0, 0, 0, 0.6, 0.34, 0.012), "white", grad=(0.0, 0.2))
    m.add(cbox(0, floors_y(1) + 0.4, z1 + 0.03, 0.66, 0.4, 0.04), "charcoal")
    m.child(screen, (0, floors_y(1) + 0.4, z1 + 0.056))
    roof_flat(m, -hw, hw, z0, z1, top + 0.03)
    # yayin kulesi + uydu canagi
    for i in range(5):
        w = 0.1 - i * 0.015
        m.add(cbox(-0.35, top + 0.13 + i * 0.2, -0.3, w, 0.2, w), "red" if i % 2 == 0 else "white", grad=(0.1, 0.5))
    m.add(cyl(0.012, 0.0, top + 1.03, top + 1.2, n=5, center=(-0.35, 0, -0.3)), "lightgrey")
    dish = cyl(0.2, 0.12, 0.0, 0.05, n=12) + [(0, -0.02, 0)]
    m.add([(p[0] + 0.3, p[1] + top + 0.32, p[2] - 0.1) for p in rot(dish, rx=-35)], "white", grad=(0.0, 0.4))
    m.add(cbox(0.3, top + 0.16, -0.12, 0.06, 0.2, 0.06), "darkgrey")
    return m


def face_box_strip(face, wall, y, w, h, a=0.0, d=0.03):
    from parts import face_box
    return face_box(face, wall, a, y, w, h, d)


# ---------------------------------------------------------------- insaat
def scaffold(name, nf, hw=0.7, z0=-0.72, z1=0.72):
    """KayKit tek-karo bina govdesinin (x +-0.6, z +-0.65) etrafina oturur."""
    m = Model(name)
    top = Y0 + F * nf + 0.1
    xs = np.linspace(-hw, hw, 4)
    rows = ((z1, 1), (z0, -1))  # (ic sira, disa dogru yon)
    pole = lambda x, z: m.add(cbox(x, (Y0 + top) / 2, z, 0.02, top - Y0, 0.02), "lightgrey", grad=(0.0, 0.5))
    for z, sgn in rows:
        for x in xs:
            pole(x, z)
            pole(x, z + sgn * 0.2)
    for i in range(1, nf + 1):
        y = Y0 + 0.05 + F * i - 0.1
        for z, sgn in rows:
            for dz in (0.0, 0.2):
                m.add(cbox(0, y, z + sgn * dz, hw * 2 + 0.04, 0.02, 0.02), "lightgrey", grad=(0.0, 0.5))
            m.add(cbox(0, y + 0.02, z + sgn * 0.1, hw * 2, 0.02, 0.2), "tan", grad=(0.1, 0.6))
            m.add(cbox(0, y + 0.3, z + sgn * 0.2, hw * 2 + 0.04, 0.015, 0.015), "sun", grad=(0.0, 0.4))
        for x in (hw, -hw):
            m.add(cbox(x, y, 0, 0.02, 0.02, z1 - z0 + 0.4), "lightgrey", grad=(0.0, 0.5))
    # caprazlar + koruma agi (bazi bolmelerde)
    for k in range(len(xs) - 1):
        for i in range(nf):
            y = Y0 + F * (i + 0.5)
            xm = (xs[k] + xs[k + 1]) / 2
            ln = ((xs[k + 1] - xs[k]) ** 2 + F ** 2) ** 0.5
            ang = np.degrees(np.arctan2(F, xs[k + 1] - xs[k])) * (1 if (k + i) % 2 else -1)
            m.add(rot(cbox(xm, y, z1 + 0.2, ln, 0.015, 0.015), rz=ang, pivot=(xm, y, z1 + 0.2)), "lightgrey", grad=(0.0, 0.5))
            if (k + i) % 2 == 0:
                m.add(cbox(xm, y + 0.05, z1 + 0.215, xs[k + 1] - xs[k] - 0.03, F - 0.12, 0.006), "orange", grad=(0.1, 0.4))
    return m


def scaffold_2():
    return scaffold("scaffold_2floor", 2)


def scaffold_4():
    return scaffold("scaffold_4floor", 4)


def construction_site():
    """Yukseltme sirasinda: beton iskelet + malzeme."""
    m = Model("building_construction")
    base_slab(m)
    block(m, -0.7, 0.7, Y0, Y0 + 0.06, -0.65, 0.65, "warmgrey", (0.3, 0.8))
    for i in range(2):
        y = floors_y(i)
        for x in (-0.6, 0.0, 0.6):
            for z in (-0.55, 0.0, 0.55):
                h = F if not (i == 1 and x > 0.3) else F * 0.5
                m.add(cbox(x, y + h / 2, z, 0.1, h, 0.1), "lightgrey", grad=(0.2, 0.8))
                if i == 1 and h < F:
                    for dx in (-0.03, 0.03):
                        m.add(cbox(x + dx, y + h + 0.08, z, 0.008, 0.16, 0.008), "charcoal")
        block(m, -0.66, 0.66, y + F - 0.05, y + F, -0.6, 0.6, "lightgrey", (0.3, 0.8)) if i == 0 else None
    block(m, -0.66, 0.3, floors_y(2) - 0.05, floors_y(2), -0.6, 0.6, "lightgrey", (0.3, 0.8))
    # tugla duvar (yarim)
    for k in range(4):
        block(m, -0.65, -0.05, Y0 + 0.06 + k * 0.08, Y0 + 0.13 + k * 0.08, 0.5, 0.6, "brick", (0.1, 0.7))
    # malzemeler: tugla paleti, kum, beton mikseri
    m.add(cbox(0.75, Y0 + 0.02, 0.8, 0.26, 0.04, 0.26), "tan")
    m.add(cbox(0.75, Y0 + 0.1, 0.8, 0.22, 0.12, 0.22), "brick", grad=(0.1, 0.7))
    m.add(cyl(0.2, 0.02, Y0, Y0 + 0.18, n=8, center=(-0.75, 0, 0.8)), "ochre", grad=(0.1, 0.7))
    m.add(cbox(0.82, Y0 + 0.08, -0.2, 0.16, 0.16, 0.16, bevel=0.01), "orange", grad=(0.0, 0.5))
    m.add(rot(cyl(0.08, 0.06, -0.1, 0.1, n=8, axis="z"), rx=30), "orange", grad=(0.0, 0.5))
    return m


def tower_crane():
    m = Model("tower_crane")
    m.add(cbox(0, 0.08, 0, 0.5, 0.16, 0.5), "lightgrey", grad=(0.3, 0.8))
    H, s = 3.6, 0.09
    for x in (-s, s):
        for z in (-s, s):
            m.add(cbox(x, 0.16 + H / 2, z, 0.025, H, 0.025), "ochre", grad=(0.0, 0.5))
    n = 12
    for i in range(n):
        y = 0.16 + H * (i + 0.5) / n
        for face in range(4):
            pts = cbox(0, 0, s, 2 * s * 1.41, 0.015, 0.015)
            pts = rot(pts, rz=45 if i % 2 else -45)
            pts = rot(pts, ry=90 * face)
            m.add([(p[0], p[1] + y, p[2]) for p in pts], "ochre", grad=(0.0, 0.5))
    ty = 0.16 + H
    m.add(cbox(0, ty + 0.04, 0, 0.26, 0.08, 0.26), "darkgrey")
    m.add(cbox(0.16, ty + 0.15, 0.0, 0.14, 0.16, 0.14, bevel=0.01), "ochre", grad=(0.0, 0.5))
    m.add(cbox(0.235, ty + 0.17, 0.0, 0.01, 0.08, 0.1), "skyblue", grad=(0.05, 0.5))
    # kol (jib) + karsi agirlik
    m.add(cbox(0, ty + 0.12, 1.2, 0.1, 0.08, 2.4), "ochre", grad=(0.0, 0.5))
    m.add(cbox(0, ty + 0.12, -0.5, 0.12, 0.08, 1.0), "ochre", grad=(0.0, 0.5))
    m.add(cbox(0, ty + 0.1, -0.85, 0.2, 0.16, 0.3), "lightgrey", grad=(0.2, 0.8))
    m.add([(0, ty + 0.5, 0), (0.04, ty + 0.16, 0.04), (-0.04, ty + 0.16, -0.04), (0.04, ty + 0.16, -0.04),
           (-0.04, ty + 0.16, 0.04)], "ochre", grad=(0.0, 0.5))
    for z in (1.0, -0.6):
        a, b = (0, ty + 0.5, 0), (0, ty + 0.16, z * 1.6 if z > 0 else z)
        mid = [(a[i] + b[i]) / 2 for i in range(3)]
        ln = ((b[1] - a[1]) ** 2 + (b[2] - a[2]) ** 2) ** 0.5
        ang = np.degrees(np.arctan2(b[1] - a[1], b[2] - a[2]))
        m.add(rot(cbox(mid[0], mid[1], mid[2], 0.008, 0.008, ln), rx=-ang, pivot=mid), "charcoal")
    m.add(cbox(0, ty + 0.06, 1.8, 0.07, 0.04, 0.1), "darkgrey")
    m.add(cbox(0, ty - 0.5, 1.8, 0.008, 1.1, 0.008), "charcoal")
    m.add(cbox(0, ty - 1.07, 1.8, 0.05, 0.06, 0.04), "orange", grad=(0.0, 0.5))
    return m


# ---------------------------------------------------------------- hasar
def damaged(src, name, cracks, holes, seed):
    m = Model(name)
    m.add_raw(os.path.join(KAYKIT, src + ".gltf"))
    rng = np.random.default_rng(seed)
    for face, wall, a, y, r in holes:
        wall_hole(m, face, wall, a, y, r, seed=int(rng.integers(1000)))
    for face, wall, a, y, ln in cracks:
        crack(m, face, wall, a, y, ln, seed=int(rng.integers(1000)), segs=5)
    for i in range(22):
        x, z = rng.uniform(-0.8, 0.8), rng.uniform(0.75, 0.97)
        if i % 3 == 0:
            x, z = rng.uniform(0.62, 0.95), rng.uniform(-0.6, 0.7)
        col = ["lightgrey", "warmgrey", "brick", "darkgrey"][i % 4]
        m.add(chunk(x, 0.1, z, rng.uniform(0.05, 0.11), seed + i), col, grad=(0.2, 0.8))
    for i in range(3):
        x = rng.uniform(-0.5, 0.5)
        m.add(rot(cbox(x, 0.13, 0.85, 0.25, 0.015, 0.03), ry=rng.uniform(-40, 40), rz=rng.uniform(-10, 10),
                  pivot=(x, 0.13, 0.85)), "brown", grad=(0.2, 0.7))
    return m


def damaged_A():
    return damaged("building_A", "building_A_damaged",
                   [("+z", 0.65, -0.12, 1.55, 0.6), ("+z", 0.65, 0.45, 1.25, 0.5),
                    ("+x", 0.6, 0.1, 1.5, 0.7), ("+x", 0.6, -0.4, 1.0, 0.5)],
                   [("+z", 0.65, 0.2, 1.48, 0.1), ("+x", 0.6, 0.35, 1.15, 0.12)], 11)


def damaged_C():
    return damaged("building_C", "building_C_damaged",
                   [("+z", 0.65, -0.1, 2.25, 0.8), ("+z", 0.65, 0.42, 1.6, 0.6),
                    ("+x", 0.6, -0.2, 2.1, 0.8), ("+x", 0.6, 0.3, 1.2, 0.6)],
                   [("+z", 0.65, 0.15, 1.95, 0.12), ("+x", 0.6, 0.0, 1.55, 0.13), ("+x", 0.6, -0.35, 0.7, 0.1)], 23)


def collapsed():
    m = Model("building_collapsed")
    base_slab(m)
    rng = np.random.default_rng(5)
    # kalan duvar parcalari (kirik ust kenar)
    for x0, x1, hs in ((-0.65, -0.1, (0.9, 0.7, 0.5, 0.35)), (0.2, 0.65, (0.45, 0.6, 0.3))):
        seg = (x1 - x0) / len(hs)
        for i, h in enumerate(hs):
            block(m, x0 + i * seg, x0 + (i + 1) * seg, Y0, Y0 + h, -0.65, -0.55, "brick", (0.0, 0.8))
    for z0, z1, hs in ((-0.55, 0.0, (0.75, 0.55, 0.3)),):
        seg = (z1 - z0) / len(hs)
        for i, h in enumerate(hs):
            block(m, -0.65, -0.55, Y0, Y0 + h, z0 + i * seg, z0 + (i + 1) * seg, "brick", (0.0, 0.8))
    window(m, "+z", -0.55, -0.4, Y0 + 0.55, w=0.14, h=0.22, glass=("charcoal", (0.3, 0.7)))
    # egik dosemeler
    m.add(rot(cbox(0.05, Y0 + 0.3, -0.2, 0.9, 0.05, 0.6), rz=-18, rx=8, pivot=(0.05, Y0 + 0.3, -0.2)), "lightgrey", grad=(0.3, 0.8))
    m.add(rot(cbox(-0.15, Y0 + 0.18, 0.3, 0.8, 0.05, 0.5), rz=12, rx=-6, pivot=(-0.15, Y0 + 0.18, 0.3)), "lightgrey", grad=(0.3, 0.8))
    # moloz yigini
    for i in range(40):
        r = rng.uniform(0.05, 0.13)
        x, z = rng.uniform(-0.7, 0.7), rng.uniform(-0.5, 0.8)
        hgt = max(0.0, 0.35 - 0.3 * (x * x + (z - 0.1) ** 2) ** 0.5)
        col = ["lightgrey", "warmgrey", "brick", "terracotta", "darkgrey"][i % 5]
        m.add(chunk(x, Y0 + hgt * rng.uniform(0.3, 1.0), z, r, 100 + i), col, grad=(0.2, 0.8))
    for i in range(6):
        x, z = rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.5)
        m.add(rot(cbox(x, Y0 + 0.3, z, 0.006, 0.35, 0.006), rx=rng.uniform(-35, 35), rz=rng.uniform(-35, 35),
                  pivot=(x, Y0 + 0.15, z)), "charcoal")
    for i in range(4):
        x, z = rng.uniform(-0.5, 0.5), rng.uniform(0.3, 0.85)
        m.add(rot(cbox(x, Y0 + 0.06, z, 0.35, 0.02, 0.04), ry=rng.uniform(0, 180), rz=rng.uniform(-15, 15),
                  pivot=(x, Y0 + 0.06, z)), "brown", grad=(0.2, 0.7))
    return m


# ---------------------------------------------------------------- konut zinciri
# gecekondu -> lv1 ev -> lv2 apartman -> lv3 gelismis (depreme dayanikli)
# + lv1/lv2 kacak kat, lv2 guclendirilmis, her seviye icin hasarli ve yikik hali
RES = {
    # seviye: (yari genislik, z0, z1, kat, duvar rengi, cati)
    1: (0.55, -0.5, 0.45, 2, "cream", "hip"),
    2: (0.65, -0.55, 0.5, 3, "salmon", "flat"),
    3: (0.72, -0.6, 0.55, 5, "white", "flat"),
}


def residential_body(m, level):
    hw, z0, z1, nf, wall, roof = RES[level]
    top = floors_y(nf)
    block(m, -hw - 0.03, hw + 0.03, Y0, Y0 + 0.06, z0 - 0.03, z1 + 0.03, "lightgrey", (0.3, 0.8))
    block(m, -hw, hw, Y0 + 0.06, top, z0, z1, wall, (0.0, 0.6) if level < 3 else (0.0, 0.8))
    xs = np.linspace(-hw + 0.17, hw - 0.17, 3 if level == 1 else 4)
    for i in range(nf):
        y = floors_y(i) + 0.38
        front = [x for x in xs if i > 0 or abs(x) > 0.2]
        glass = ("skyblue", (0.05, 0.6))
        if level == 3:
            block(m, -hw - 0.005, hw + 0.005, floors_y(i) + 0.2, floors_y(i) + 0.56, z1, z1 + 0.025, "skyblue", (0.05, 0.6))
            for x in np.linspace(-hw + 0.04, hw - 0.04, 7):
                m.add(cbox(x, floors_y(i) + 0.38, z1 + 0.03, 0.02, 0.36, 0.012), "lightgrey", grad=(0.0, 0.4))
        else:
            window_row(m, "+z", z1, front, y, w=0.15, h=0.26, glass=glass)
        window_row(m, "-z", z0, xs, y, w=0.15, h=0.26, glass=glass)
        for face, wall_x in (("+x", hw), ("-x", -hw)):
            window_row(m, face, wall_x, [z0 + 0.25, z1 - 0.25], y, w=0.14, h=0.26, glass=glass)
        if i > 0:
            ledge(m, -hw, hw, z0, z1, floors_y(i), "white" if level < 3 else "slate", out=0.015, h=0.04)
        if level == 2 and i > 0:  # balkonlar
            for x in (-0.35, 0.35):
                block(m, x - 0.2, x + 0.2, floors_y(i) + 0.03, floors_y(i) + 0.06, z1, z1 + 0.18, "lightgrey", (0.3, 0.7))
                block(m, x - 0.2, x + 0.2, floors_y(i) + 0.06, floors_y(i) + 0.2, z1 + 0.16, z1 + 0.18, "white", (0.0, 0.4))
                for sx in (-1, 1):
                    block(m, x + sx * 0.19 - 0.01, x + sx * 0.19 + 0.01, floors_y(i) + 0.06, floors_y(i) + 0.2, z1, z1 + 0.18,
                          "white", (0.0, 0.4))
    door(m, "+z", z1, 0, Y0 + 0.06, w=0.18, h=0.32, color={1: "brown", 2: "teal", 3: "slate"}[level])
    if level >= 2:
        block(m, -0.18, 0.18, Y0 + 0.42, Y0 + 0.45, z1, z1 + 0.14, "lightgrey", (0.2, 0.6))
    if level == 1:
        block(m, -0.62, -0.25, Y0, Y0 + 0.12, z1 + 0.15, z1 + 0.42, "brown", (0.1, 0.6))  # bahce kutusu
        for k in range(3):
            m.add(blob(-0.53 + k * 0.12, Y0 + 0.17, z1 + 0.28, 0.07, seed=k), "green", grad=(0.0, 0.7))
    return top


def residential_roof(m, level):
    hw, z0, z1, nf, wall, roof = RES[level]
    top = floors_y(nf)
    if roof == "hip":
        roof_hip(m, -hw, hw, z0, z1, top, 0.3)
        block(m, 0.25, 0.37, top + 0.05, top + 0.38, -0.2, -0.08, "brick", (0.1, 0.7))  # baca
    else:
        roof_flat(m, -hw, hw, z0, z1, top)
        if level == 3:  # gunes panelleri + guclu cerceve hissi
            for x in (-0.4, -0.05, 0.3):
                pts = cbox(x, top + 0.12, -0.2, 0.3, 0.02, 0.4)
                m.add(rot(pts, rx=-20, pivot=(x, top + 0.12, -0.2)), "blue", grad=(0.3, 0.9))
                m.add(cbox(x, top + 0.07, -0.2, 0.03, 0.08, 0.03), "lightgrey")
        else:
            m.add(cbox(-0.35, top + 0.1, -0.25, 0.14, 0.12, 0.14), "lightgrey")  # su deposu
            m.add(cbox(0.35, top + 0.08, 0.1, 0.12, 0.09, 0.08, bevel=0.01), "lightgrey")  # klima
    if level == 3:  # dayanikli yapi: kose kolonlari vurgulu
        for sx in (-1, 1):
            for z in (z0, z1):
                block(m, sx * hw - 0.04, sx * hw + 0.04, Y0 + 0.06, top, z - 0.04, z + 0.04, "slate", (0.1, 0.7))


def illegal_floors(m, level, n=1):
    """Kacak kat: siva yok, tugla duvar, cikintili, ust uste eklenmis."""
    hw, z0, z1, nf, wall, roof = RES[level]
    y = floors_y(nf)
    block(m, -hw - 0.04, hw + 0.04, y, y + 0.05, z0 - 0.04, z1 + 0.1, "lightgrey", (0.3, 0.8))
    for k in range(n):
        y0 = y + 0.05
        off = 0.06 if k % 2 == 0 else -0.04  # yamuk/cikintili
        x0, x1 = -hw + 0.05 + off, hw - 0.02 + off
        block(m, x0, x1, y0, y0 + 0.55, z0 + 0.02, z1 + 0.08, "brick" if k % 2 == 0 else "terracotta", (0.0, 0.7))
        for x in np.linspace(x0 + 0.2, x1 - 0.2, 3):
            window(m, "+z", z1 + 0.08, x, y0 + 0.3, w=0.13, h=0.2, frame="darkgrey", glass=("charcoal", (0.3, 0.7)), sill=False)
        window(m, "+x", x1, 0, y0 + 0.3, w=0.13, h=0.2, frame="darkgrey", glass=("charcoal", (0.3, 0.7)), sill=False)
        block(m, x0 - 0.02, x1 + 0.02, y0 + 0.55, y0 + 0.6, z0, z1 + 0.1, "lightgrey", (0.3, 0.8))
        y = y0 + 0.55
    top = y + 0.05
    # ust: filiz demirler + mavi branda + tuglalar
    for x in (-hw + 0.1, 0.0, hw - 0.1):
        for z in (z0 + 0.08, z1):
            for dx in (-0.02, 0.02):
                m.add(cbox(x + dx, top + 0.1, z, 0.008, 0.2, 0.008), "charcoal")
    m.add(rot(cbox(0.2, top + 0.08, -0.2, 0.3, 0.012, 0.25), rz=25, rx=-10, pivot=(0.2, top, -0.2)), "blue", grad=(0.1, 0.5))
    m.add(cbox(-0.35, top + 0.05, 0.2, 0.2, 0.1, 0.14), "brick", grad=(0.1, 0.7))
    # disaridan merdiven / dis cephe borusu
    m.add(cbox(hw + 0.02, (Y0 + top) / 2, z1 - 0.1, 0.03, top - Y0, 0.03), "lightgrey", grad=(0.0, 0.5))


def reinforcement(m, level):
    """Guclendirme: cephede celik capraz + mantolama."""
    hw, z0, z1, nf, wall, roof = RES[level]
    for i in range(nf):
        y = floors_y(i) + F / 2
        for face, wall_c, span in (("+x", hw, (z0, z1)), ("-x", -hw, (z0, z1))):
            a0, a1 = span
            mid = (a0 + a1) / 2
            ln = ((a1 - a0) ** 2 + F ** 2) ** 0.5
            ang = np.degrees(np.arctan2(F, a1 - a0))
            for sgn in (1, -1):
                pts = cbox(wall_c + (0.03 if face[0] == "+" else -0.03), y, mid, 0.03, 0.04, ln - 0.05)
                m.add(rot(pts, rx=sgn * ang, pivot=(wall_c, y, mid)), "orange", grad=(0.05, 0.5))
    for sx in (-1, 1):
        for z in (z0, z1):
            block(m, sx * hw - 0.05, sx * hw + 0.05, Y0 + 0.06, floors_y(nf), z - 0.05, z + 0.05, "lightgrey", (0.1, 0.7))
    for i in range(1, nf + 1):
        block(m, -hw - 0.05, hw + 0.05, floors_y(i) - 0.04, floors_y(i) + 0.01, z0 - 0.05, z0 + 0.0, "orange", (0.05, 0.5))


def damage_overlay(m, level, seed, extra_top=0.0):
    hw, z0, z1, nf, wall, roof = RES[level]
    top = floors_y(nf) + extra_top
    rng = np.random.default_rng(seed)
    for k in range(2 + nf // 2):
        y = rng.uniform(Y0 + 0.4, top - 0.1)
        crack(m, "+z", z1, rng.uniform(-hw + 0.15, hw - 0.15), y, rng.uniform(0.35, 0.6), seed=seed + k, segs=5)
        crack(m, "+x", hw, rng.uniform(z0 + 0.15, z1 - 0.15), y, rng.uniform(0.35, 0.6), seed=seed + 50 + k, segs=5)
    for k in range(1 + nf // 2):
        wall_hole(m, "+z", z1 + 0.002, rng.uniform(-hw + 0.2, hw - 0.2), rng.uniform(Y0 + 0.5, top - 0.2), 0.1, seed=seed + 90 + k)
    for i in range(18):
        x, z = rng.uniform(-0.85, 0.85), rng.uniform(z1 + 0.1, 0.97)
        col = ["lightgrey", "warmgrey", "brick", wall][i % 4]
        m.add(chunk(x, Y0, z, rng.uniform(0.05, 0.1), seed * 7 + i), col, grad=(0.2, 0.8))


def collapsed_heap(name, colors, height, walls, seed):
    """Seviyeye gore yikik bina: yukseklik ve renkler kaynaga uyar."""
    m = Model(name)
    base_slab(m)
    rng = np.random.default_rng(seed)
    wall = colors[0]
    for x0, x1, hs in walls:
        seg = (x1 - x0) / len(hs)
        for i, h in enumerate(hs):
            block(m, x0 + i * seg, x0 + (i + 1) * seg, Y0, Y0 + h, -0.62, -0.52, wall, (0.0, 0.8))
    for i in range(3):
        cx, cy, cz = rng.uniform(-0.3, 0.3), Y0 + height * (0.3 + 0.25 * i), rng.uniform(-0.3, 0.2)
        m.add(rot(cbox(cx, cy, cz, 0.85, 0.05, 0.55), rz=rng.uniform(-25, 25), rx=rng.uniform(-12, 12), pivot=(cx, cy, cz)),
              "lightgrey", grad=(0.3, 0.8))
    for i in range(46):
        r = rng.uniform(0.07, 0.17)
        x, z = rng.uniform(-0.75, 0.75), rng.uniform(-0.55, 0.85)
        h = max(0.0, height - height * 1.1 * (x * x + (z - 0.05) ** 2) ** 0.5)
        m.add(chunk(x, Y0 + h * rng.uniform(0.3, 1.0), z, r, seed * 100 + i), colors[i % len(colors)], grad=(0.2, 0.8))
    for i in range(7):
        x, z = rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.4)
        m.add(rot(cbox(x, Y0 + height * 0.6, z, 0.006, height * 0.8, 0.006), rx=rng.uniform(-35, 35), rz=rng.uniform(-35, 35),
                  pivot=(x, Y0 + height * 0.3, z)), "charcoal")
    return m


def house_gecekondu(damage=False):
    m = Model("house_lv0_gecekondu" + ("_damaged" if damage else ""))
    base_slab(m)
    hw, z0, z1, h = 0.42, -0.4, 0.3, 0.5
    block(m, -hw, hw, Y0, Y0 + h, z0, z1, "cream", (0.0, 0.7))
    # sivasi dokulmus yerler
    for (a, y, r, s) in ((-0.25, Y0 + 0.15, 0.08, 1), (0.3, Y0 + 0.35, 0.06, 2)):
        wall_hole(m, "+z", z1, a, y, r, seed=s)
    # ek oda (farkli renk, alcak)
    block(m, hw, hw + 0.3, Y0, Y0 + 0.38, z0 + 0.1, z1 - 0.1, "skyblue", (0.2, 0.8))
    door(m, "+z", z1, 0.05, Y0, w=0.16, h=0.3, color="blue", frame="lightgrey", glass=False)
    window(m, "+z", z1, -0.25, Y0 + 0.3, w=0.13, h=0.13, frame="brown")
    window(m, "+x", hw + 0.3, 0.0, Y0 + 0.22, w=0.1, h=0.1, frame="brown")
    window(m, "-x", -hw, -0.05, Y0 + 0.3, w=0.13, h=0.13, frame="brown")
    # egik oluklu teneke cati + uzerinde tas/lastik
    ry = Y0 + h
    for i in range(9):
        x = -hw - 0.06 + i * (2 * hw + 0.12) / 9
        pts = cbox(x + 0.05, ry + 0.06, (z0 + z1) / 2, 0.095, 0.02 + 0.008 * (i % 2), z1 - z0 + 0.16)
        m.add(rot(pts, rx=8, pivot=(0, ry, (z0 + z1) / 2)), "lightgrey" if i % 3 else "warmgrey", grad=(0.0, 0.6))
    m.add(rot(cbox(hw + 0.15, Y0 + 0.4, (z0 + z1) / 2, 0.38, 0.02, z1 - z0 - 0.1), rz=-10, pivot=(hw, Y0 + 0.42, 0)),
          "brick", grad=(0.0, 0.6))
    for x, z in ((-0.2, -0.1), (0.2, 0.05)):
        m.add(chunk(x, ry + 0.1, z, 0.05, 7), "warmgrey", grad=(0.2, 0.7))
    m.add(cyl(0.06, 0.06, 0, 0.035, n=10, center=(0.05, ry + 0.1, -0.2)), "charcoal")
    # soba borusu, cit, camasir ipi
    m.add(cyl(0.02, 0.02, Y0 + 0.3, ry + 0.3, n=6, center=(-0.3, 0, -0.3)), "darkgrey")
    m.add(cyl(0.035, 0.035, ry + 0.3, ry + 0.33, n=6, center=(-0.3, 0, -0.3)), "darkgrey")
    for i in range(9):
        x = -0.85 + i * 0.21
        m.add(cbox(x, Y0 + 0.1, 0.85, 0.04, 0.2, 0.02), "brown", grad=(0.1, 0.7))
    m.add(cbox(0, Y0 + 0.15, 0.85, 1.7, 0.02, 0.015), "brown", grad=(0.1, 0.7))
    for x in (-0.75, -0.35):
        m.add(cyl(0.01, 0.01, Y0, Y0 + 0.4, n=5, center=(x, 0, 0.55)), "darkgrey")
    m.add(cbox(-0.55, Y0 + 0.39, 0.55, 0.4, 0.004, 0.004), "charcoal")
    for i, col in enumerate(("red", "white", "sun")):
        m.add(cbox(-0.68 + i * 0.12, Y0 + 0.33, 0.55, 0.08, 0.1, 0.006), col, grad=(0.1, 0.5))
    m.add(cbox(0.6, Y0 + 0.08, 0.5, 0.1, 0.16, 0.1), "teal", grad=(0.1, 0.6))  # bidon
    if damage:
        for k in range(3):
            crack(m, "+z", z1, -0.3 + k * 0.28, Y0 + 0.42, 0.3, seed=k + 3, segs=4)
        rng = np.random.default_rng(3)
        for i in range(14):
            m.add(chunk(rng.uniform(-0.6, 0.6), Y0, rng.uniform(0.35, 0.75), rng.uniform(0.04, 0.08), 300 + i),
                  ["cream", "lightgrey", "brick"][i % 3], grad=(0.2, 0.8))
    return m


def house(level, kacak=0, reinforced=False, damage=False):
    suffix = ("_kacak" if kacak else "") + ("_reinforced" if reinforced else "") + ("_damaged" if damage else "")
    m = Model(f"house_lv{level}{suffix}")
    base_slab(m)
    residential_body(m, level)
    if kacak:
        illegal_floors(m, level, kacak)
    else:
        residential_roof(m, level)
    if reinforced:
        reinforcement(m, level)
    if damage:
        damage_overlay(m, level, seed=level * 13 + kacak, extra_top=0.6 * kacak)
    return m


def house_collapsed(level):
    wall = RES[level][4] if level else "cream"
    height = {0: 0.2, 1: 0.35, 2: 0.5, 3: 0.55}[level]
    walls = {0: [(-0.4, 0.4, (0.3, 0.2, 0.12))],
             1: [(-0.55, -0.05, (0.7, 0.45, 0.3)), (0.2, 0.55, (0.3, 0.5))],
             2: [(-0.65, -0.1, (1.0, 0.7, 0.5, 0.3)), (0.2, 0.65, (0.4, 0.8, 0.5))],
             3: [(-0.7, 0.7, (1.4, 0.9, 0.5, 0.35, 0.6, 1.1))]}[level]
    colors = [wall, "lightgrey", "warmgrey", "brick" if level < 3 else "slate", "darkgrey"]
    name = "house_lv0_gecekondu_collapsed" if level == 0 else f"house_lv{level}_collapsed"
    return collapsed_heap(name, colors, height, walls, seed=level + 40)


# ---------------------------------------------------------------- muzeler (deprem / sel / yangin)
MUSEUM_STYLE = {  # ana renk (cati, afis, amblem), ikinci renk
    "deprem": ("orange", "brown"),
    "sel": ("blue", "skyblue"),
    "yangin": ("red", "flame"),
}


def museum(kind):
    """Klasik muze: basamaklar, sutunlu giris, ucgen alinlik + afet amblemi, iki yanda renkli afis."""
    main, second = MUSEUM_STYLE[kind]
    m = Model(f"building_museum_{kind}")
    base_slab(m)
    hw, z0, z1 = 0.8, -0.65, 0.25
    top = Y0 + 0.95
    for i in range(3):  # basamaklar
        block(m, -hw + 0.05 - i * 0.03, hw - 0.05 + i * 0.03, Y0, Y0 + (3 - i) * 0.04,
              z1 + 0.05 + i * 0.12, z1 + 0.18 + i * 0.12, "lightgrey", (0.1, 0.5))
    block(m, -hw, hw, Y0 + 0.12, top, z0, z1, "cream", (0.0, 0.7))
    for x in (-0.6, -0.3, 0.0, 0.3, 0.6):  # sutunlar
        m.add(cyl(0.06, 0.055, Y0 + 0.12, top - 0.02, n=8, center=(x, 0, z1 + 0.22)), "white", grad=(0.0, 0.4))
        m.add(cbox(x, top - 0.02, z1 + 0.22, 0.15, 0.04, 0.15), "white", grad=(0.0, 0.3))
        m.add(cbox(x, Y0 + 0.14, z1 + 0.22, 0.15, 0.04, 0.15), "white", grad=(0.0, 0.3))
    block(m, -hw - 0.04, hw + 0.04, top, top + 0.1, z0 - 0.04, z1 + 0.34, "white", (0.0, 0.4))  # arsitrav
    peak = 0.38
    m.add([(-hw - 0.04, top + 0.1, z1 + 0.34), (hw + 0.04, top + 0.1, z1 + 0.34), (0, top + 0.1 + peak, z1 + 0.34),
           (-hw - 0.04, top + 0.1, z0 - 0.04), (hw + 0.04, top + 0.1, z0 - 0.04), (0, top + 0.1 + peak, z0 - 0.04)],
          "lightgrey", grad=(0.0, 0.5))
    m.add([(-hw - 0.08, top + 0.1, z1 + 0.38), (hw + 0.08, top + 0.1, z1 + 0.38), (0, top + 0.12 + peak, z1 + 0.38),
           (-hw - 0.08, top + 0.1, z0 - 0.08), (hw + 0.08, top + 0.1, z0 - 0.08), (0, top + 0.12 + peak, z0 - 0.08)],
          main, grad=(0.3, 0.9))
    # alinlik amblemi (beyaz disk + afet simgesi)
    ey, ez = top + 0.21, z1 + 0.37
    m.add(cyl(0.1, 0.1, ez - 0.01, ez + 0.01, n=12, axis="z", center=(0, ey, 0)), "white", grad=(0.0, 0.3))
    if kind == "deprem":
        for x, y in ((-0.05, 0.03), (-0.015, -0.02), (0.02, 0.025), (0.055, -0.02)):
            m.add(cbox(x, ey + y, ez + 0.015, 0.035, 0.022, 0.01), main, grad=(0.2, 0.5))
    elif kind == "sel":
        for k in range(2):
            for i in range(4):
                m.add(cbox(-0.06 + i * 0.04, ey - 0.025 + k * 0.05 + (0.008 if i % 2 else -0.008), ez + 0.015,
                           0.04, 0.016, 0.008), main, grad=(0.2, 0.5))
    else:
        m.add(cbox(0, ey - 0.02, ez + 0.015, 0.08, 0.07, 0.01), main, grad=(0.1, 0.5))
        m.add(cbox(0, ey + 0.035, ez + 0.015, 0.04, 0.06, 0.01), main, grad=(0.1, 0.5))
        m.add(cbox(0, ey - 0.025, ez + 0.022, 0.035, 0.035, 0.01), "sun", grad=(0.0, 0.3))
    door(m, "+z", z1, 0, Y0 + 0.12, w=0.26, h=0.5, color="brown")
    window_row(m, "+z", z1, [-0.45, 0.45], Y0 + 0.55, w=0.16, h=0.3)
    for face, wall in (("+x", hw), ("-x", -hw)):
        window_row(m, face, wall, [-0.35, 0.0], Y0 + 0.55, w=0.16, h=0.3)
    for sx in (1, -1):  # dikey afisler
        m.add(cbox(sx * (hw + 0.02), top - 0.3, 0.0, 0.02, 0.5, 0.22), main, grad=(0.1, 0.6))
        m.add(cbox(sx * (hw + 0.035), top - 0.3, 0.0, 0.01, 0.12, 0.12), "white", grad=(0.0, 0.3))
    for sx in (1, -1):  # saksida agaclar
        m.add(cbox(sx * 0.82, Y0 + 0.06, 0.82, 0.16, 0.12, 0.16), "lightgrey", grad=(0.1, 0.5))
        m.add(blob(sx * 0.82, Y0 + 0.25, 0.82, 0.13, seed=7 + int(sx)), "darkgreen", grad=(0.1, 0.7))
    m.add(cbox(0.55, Y0 + 0.14, 0.88, 0.32, 0.18, 0.04), main, grad=(0.1, 0.6))  # tabela
    m.add(cbox(0.55, Y0 + 0.14, 0.905, 0.24, 0.03, 0.01), "white", grad=(0.0, 0.3))
    return m


def museum_lot():
    """Bos muze arsasi: cim zemin, beyaz cit, tabela, turuncu kaziklar."""
    m = Model("museum_lot")
    block(m, -0.95, 0.95, 0.0, 0.1, -0.95, 0.95, "green", (0.2, 0.7))
    for i in range(7):
        t = -0.9 + i * 0.3
        for (x, z) in ((t, -0.9), (t, 0.9), (-0.9, t), (0.9, t)):
            m.add(cbox(x, 0.18, z, 0.04, 0.16, 0.04), "white", grad=(0.0, 0.4))
    for z in (-0.9, 0.9):
        m.add(cbox(0, 0.22, z, 1.82, 0.03, 0.02), "white", grad=(0.0, 0.4))
    for x in (-0.9, 0.9):
        m.add(cbox(x, 0.22, 0, 0.02, 0.03, 1.82), "white", grad=(0.0, 0.4))
    for x in (-0.25, 0.25):
        m.add(cbox(x, 0.35, 0.6, 0.04, 0.5, 0.04), "brown", grad=(0.2, 0.6))
    m.add(cbox(0, 0.52, 0.6, 0.62, 0.3, 0.04), "cream", grad=(0.0, 0.4))
    m.add(cbox(0, 0.52, 0.625, 0.5, 0.05, 0.01), "brown", grad=(0.2, 0.5))
    for (x, z) in ((-0.5, -0.4), (0.5, -0.4), (0.0, 0.1)):
        m.add(cbox(x, 0.16, z, 0.04, 0.12, 0.04), "orange", grad=(0.1, 0.5))
    return m


def _mk(fn, *a, **k):
    f = lambda: fn(*a, **k)
    f.__name__ = fn.__name__
    return f


RESIDENTIAL = [
    _mk(house_gecekondu), _mk(house_gecekondu, damage=True), _mk(house_collapsed, 0),
    _mk(house, 1), _mk(house, 1, kacak=1), _mk(house, 1, reinforced=True),
    _mk(house, 1, damage=True), _mk(house, 1, kacak=1, damage=True), _mk(house, 1, reinforced=True, damage=True),
    _mk(house_collapsed, 1),
    _mk(house, 2), _mk(house, 2, kacak=2), _mk(house, 2, reinforced=True),
    _mk(house, 2, damage=True), _mk(house, 2, kacak=2, damage=True), _mk(house, 2, reinforced=True, damage=True),
    _mk(house_collapsed, 2),
    _mk(house, 3), _mk(house, 3, damage=True), _mk(house_collapsed, 3),
]

SERVICE_LEVELS = [_mk(f, lv) for f in (hospital, fire_station, afad_center) for lv in (2, 3)]

MUSEUMS = [_mk(museum, k) for k in ("deprem", "sel", "yangin")] + [museum_lot]

MODELS = RESIDENTIAL + SERVICE_LEVELS + MUSEUMS + [town_hall_1, town_hall_2, town_hall_3, hospital, fire_station, school, afad_center, news_building,
          scaffold_2, scaffold_4, construction_site, tower_crane]
