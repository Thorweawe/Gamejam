"""Afet / farkindalik objeleri. Zemin y=0 (KayKit sokak objeleri gibi), on +Z."""
import math

import numpy as np

from kitgen import Model, blob, cbox, chunk, cyl, rot
from parts import cross_sign


def person_icon(m, x, y, z, s, color="white"):
    """Tabela uzerindeki insan figuru (on yuz +Z)."""
    m.add(cyl(s * 0.22, s * 0.22, 0, 0.006, n=8, axis="z", center=(x, y + s * 0.78, z)), color, grad=(0.0, 0.2))
    m.add(cbox(x, y + s * 0.3, z + 0.003, s * 0.3, s * 0.5, 0.006), color, grad=(0.0, 0.2))
    for sx in (-1, 1):
        m.add(cbox(x + sx * s * 0.09, y - s * 0.1, z + 0.003, s * 0.1, s * 0.35, 0.006), color, grad=(0.0, 0.2))


def assembly_sign():
    """Afet toplanma alani tabelasi (yesil zemin, beyaz figurler)."""
    m = Model("sign_assembly_area")
    m.add(cbox(0, 0.02, 0, 0.12, 0.04, 0.12), "lightgrey", grad=(0.3, 0.8))
    m.add(cyl(0.015, 0.015, 0.04, 0.95, n=6), "lightgrey")
    m.add(cbox(0, 0.78, 0.02, 0.4, 0.34, 0.02), "white", grad=(0.0, 0.2))
    m.add(cbox(0, 0.78, 0.024, 0.37, 0.31, 0.02), "green", grad=(0.1, 0.5))
    for i, x in enumerate((-0.1, 0.0, 0.1)):
        person_icon(m, x, 0.73 + (0.02 if i == 1 else 0), 0.035, 0.12 if i == 1 else 0.1)
    m.add(cbox(0, 0.645, 0.035, 0.3, 0.012, 0.006), "white", grad=(0.0, 0.2))
    return m


def assembly_ground_marker():
    """Toplanma alani zemin isareti (2x2 karonun uzerine konur)."""
    m = Model("assembly_area_marker")
    m.add(cbox(0, 0.005, 0, 1.6, 0.01, 1.6), "green", grad=(0.1, 0.4))
    m.add(cbox(0, 0.012, 0, 1.4, 0.006, 1.4), "green", grad=(0.0, 0.12))
    for sx in (-1, 1):
        m.add(cbox(sx * 0.75, 0.016, 0, 0.06, 0.006, 1.5), "white", grad=(0.0, 0.2))
        m.add(cbox(0, 0.016, sx * 0.75, 1.5, 0.006, 0.06), "white", grad=(0.0, 0.2))
    return m


def tent():
    m = Model("tent_disaster")
    w, d, h, ridge = 0.34, 0.3, 0.16, 0.36
    m.add(cbox(0, h / 2, 0, w * 2 - 0.04, h, d * 2), "white", grad=(0.0, 0.6))
    m.add([(sx * (w + 0.02), h, sz * (d + 0.03)) for sx in (1, -1) for sz in (1, -1)] +
          [(sx * (w + 0.02), h - 0.005, sz * (d + 0.03)) for sx in (1, -1) for sz in (1, -1)] +
          [(0, ridge, sz * (d + 0.03)) for sz in (1, -1)], "blue", grad=(0.0, 0.5))
    m.add([(sx * 0.09, y, d + 0.005) for sx in (1, -1) for y in (0.0, h)] +
          [(0, h + 0.09, d + 0.005), (0, 0, d + 0.012), (0, h + 0.08, d + 0.012)], "slate", grad=(0.2, 0.7))
    for sx in (1, -1):
        for sz in (1, -1):
            m.add(cbox(sx * (w + 0.1), 0.015, sz * (d + 0.05), 0.02, 0.03, 0.02), "darkgrey")
    m.add(cbox(0, ridge - 0.02, 0, 0.03, 0.03, d * 2 + 0.07), "lightgrey")
    return m


def rubble(name, n, radius, height, seed):
    m = Model(name)
    rng = np.random.default_rng(seed)
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = radius * math.sqrt(rng.uniform(0, 1))
        x, z = math.cos(a) * d, math.sin(a) * d
        y = height * max(0.0, 1 - d / radius) * rng.uniform(0.4, 1.0)
        col = ["lightgrey", "warmgrey", "brick", "terracotta", "darkgrey"][i % 5]
        m.add(chunk(x, y, z, rng.uniform(0.04, 0.1) * radius / 0.4, seed * 100 + i), col, grad=(0.2, 0.8))
    for i in range(max(2, n // 8)):
        x, z = rng.uniform(-radius, radius) * 0.6, rng.uniform(-radius, radius) * 0.6
        m.add(rot(cbox(x, height * 0.4, z, radius * 0.7, 0.02, 0.035), ry=rng.uniform(0, 180), rz=rng.uniform(-20, 20),
                  pivot=(x, height * 0.4, z)), "brown", grad=(0.2, 0.7))
        m.add(rot(cbox(x, height * 0.6, z + 0.05, 0.006, height * 0.9, 0.006), rx=rng.uniform(-40, 40),
                  rz=rng.uniform(-40, 40), pivot=(x, height * 0.3, z)), "charcoal")
    return m


def rubble_small():
    return rubble("rubble_small", 12, 0.25, 0.12, 3)


def rubble_large():
    return rubble("rubble_large", 34, 0.6, 0.35, 7)


def fire(name, scale, seed):
    """Low-poly alev. Godot'ta olcek/sallanma animasyonu verilebilir."""
    m = Model(name)
    rng = np.random.default_rng(seed)
    n = 5
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        d = 0.08 * scale
        x, z = math.cos(a) * d, math.sin(a) * d
        h = scale * rng.uniform(0.3, 0.5)
        r = scale * rng.uniform(0.07, 0.1)
        pts = cyl(r, 0.0, 0, h, n=5, phase=rng.uniform(0, 3))
        pts = rot(pts, rx=rng.uniform(-12, 12), rz=rng.uniform(-12, 12))
        m.add([(p[0] + x, p[1], p[2] + z) for p in pts], "flame", grad=(0.0, 0.45))
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.5
        x, z = math.cos(a) * 0.03 * scale, math.sin(a) * 0.03 * scale
        pts = cyl(scale * 0.09, 0.0, 0, scale * rng.uniform(0.55, 0.7), n=5, phase=a)
        m.add([(p[0] + x, p[1], p[2] + z) for p in pts], "orange", grad=(0.0, 0.5))
    m.add(cyl(scale * 0.07, 0.0, 0, scale * 0.38, n=5), "sun", grad=(0.0, 0.3))
    for i in range(4):
        a = 2 * math.pi * i / 4
        m.add(rot(cbox(math.cos(a) * 0.1 * scale, 0.02 * scale, math.sin(a) * 0.1 * scale, 0.3 * scale, 0.04 * scale, 0.05 * scale),
                  ry=math.degrees(a) + 90, pivot=(math.cos(a) * 0.1 * scale, 0, math.sin(a) * 0.1 * scale)), "black", grad=(0.3, 0.7))
    return m


def fire_small():
    return fire("fire_small", 0.6, 1)


def fire_large():
    return fire("fire_large", 1.3, 2)


def smoke():
    m = Model("smoke_column")
    rng = np.random.default_rng(4)
    for i in range(6):
        y = 0.1 + i * 0.17 + 0.01 * i * i
        r = 0.07 + i * 0.025
        x = 0.012 * i * i + rng.uniform(-0.02, 0.02)
        col = "lightgrey" if i < 2 else "white"
        m.add(blob(x, y, rng.uniform(-0.03, 0.03), r, sy=0.75, jitter=0.05, seed=40 + i, smooth=True), col, grad=(0.0, 0.5))
        if i >= 2:
            m.add(blob(x + r * 0.8, y + 0.03, r * 0.4, r * 0.65, sy=0.75, jitter=0.05, seed=60 + i, smooth=True), col,
                  grad=(0.0, 0.5))
    return m


def sandbags():
    m = Model("sandbag_wall")
    rng = np.random.default_rng(9)
    for row in range(3):
        n = 5 - (row % 2)
        for i in range(n):
            x = (i - (n - 1) / 2) * 0.17
            y = 0.035 + row * 0.06
            pts = cbox(x, y, 0, 0.16, 0.065, 0.1, bevel=0.025)
            m.add(rot(pts, ry=rng.uniform(-6, 6), pivot=(x, y, 0)), "tan", grad=(0.0, 0.7))
    return m


def barrier():
    m = Model("road_barrier")
    for sx in (1, -1):
        m.add(cbox(sx * 0.27, 0.13, 0, 0.03, 0.26, 0.03), "white", grad=(0.0, 0.5))
        m.add(cbox(sx * 0.27, 0.01, 0, 0.06, 0.02, 0.16), "darkgrey")
    for row, y in enumerate((0.21, 0.12)):
        for i in range(6):
            x = -0.25 + 0.5 * (i + 0.5) / 6
            m.add(cbox(x, y, 0.02, 0.5 / 6, 0.06, 0.02), "red" if (i + row) % 2 == 0 else "white", grad=(0.15, 0.45))
    m.add(cyl(0.02, 0.02, 0.26, 0.29, n=6, center=(-0.27, 0, 0)), "orange", grad=(0.0, 0.3))
    return m


def traffic_cone():
    m = Model("traffic_cone")
    m.add(cbox(0, 0.008, 0, 0.13, 0.016, 0.13, bevel=0.01), "charcoal")
    m.add(cyl(0.05, 0.01, 0.016, 0.22, n=8), "orange", grad=(0.0, 0.6))
    m.add(cyl(0.039, 0.028, 0.08, 0.125, n=8), "white", grad=(0.0, 0.3))
    return m


def siren_pole():
    """Afet uyari sireni (direk + hoparlorler + isik)."""
    m = Model("siren_pole")
    m.add(cbox(0, 0.03, 0, 0.14, 0.06, 0.14), "lightgrey", grad=(0.3, 0.8))
    m.add(cyl(0.025, 0.02, 0.06, 1.25, n=6), "lightgrey")
    m.add(cbox(0.0, 0.3, 0.035, 0.1, 0.14, 0.05), "darkgrey")
    m.add(cbox(0.0, 0.32, 0.061, 0.05, 0.03, 0.006), "sun", grad=(0.0, 0.3))
    m.add(cbox(0, 1.1, 0, 0.12, 0.05, 0.12), "darkgrey")
    for i in range(4):
        horn = cyl(0.025, 0.065, 0.0, 0.14, n=8, axis="z")
        horn = rot(horn, ry=90 * i)
        m.add([(p[0], p[1] + 1.1, p[2]) for p in horn], "lightgrey", grad=(0.0, 0.6))
    m.add(cyl(0.03, 0.03, 1.125, 1.17, n=8), "red", grad=(0.0, 0.4))
    m.add(cyl(0.025, 0.012, 1.17, 1.2, n=8), "red", grad=(0.0, 0.4))
    return m


def billboard():
    """Kampanya panosu. Ekran ayri node -> Godot'ta kendi gorselinizi verin."""
    m = Model("billboard")
    for sx in (1, -1):
        m.add(cbox(sx * 0.35, 0.04, 0, 0.12, 0.08, 0.12), "lightgrey", grad=(0.3, 0.8))
        m.add(cbox(sx * 0.35, 0.5, 0, 0.04, 0.9, 0.04), "darkgrey")
    m.add(cbox(0, 0.97, 0, 1.2, 0.6, 0.05), "darkgrey")
    m.add(cbox(0, 0.97, -0.03, 1.1, 0.5, 0.01), "lightgrey")
    m.add(cbox(0, 0.64, 0.12, 1.2, 0.02, 0.2), "darkgrey")
    for x in (-0.35, 0.35):
        m.add(cbox(x, 1.29, 0.08, 0.02, 0.02, 0.16), "darkgrey")
        m.add(cyl(0.025, 0.02, 0, 0.05, n=6, axis="z", center=(x, 1.28, 0.14)), "white", grad=(0.0, 0.3))
    screen = Model("billboard_screen")
    screen.add(cbox(0, 0, 0, 1.12, 0.52, 0.01), "white", grad=(0.0, 0.25))
    m.child(screen, (0, 0.97, 0.03))
    return m


def billboard_campaign():
    """Hazir kampanya gorselli pano: 'deprem cantasi hazirla' (turuncu canta ikonu)."""
    m = billboard()
    m.name = "billboard_campaign"
    m.children = []
    m.add(cbox(0, 0.97, 0.03, 1.12, 0.52, 0.01), "skyblue", grad=(0.2, 0.6))
    _kit_icon(m, -0.3, 0.76, 0.04, 1.4)
    for i, w in enumerate((0.5, 0.42, 0.46)):
        m.add(cbox(0.18, 1.12 - i * 0.1, 0.04, w, 0.05, 0.008), "white" if i else "orange", grad=(0.0, 0.4))
    return m


def _kit_icon(m, x, y, z, s):
    m.add(cbox(x, y + 0.1 * s, z, 0.16 * s, 0.2 * s, 0.01), "orange", grad=(0.0, 0.4))
    m.add(cbox(x, y + 0.06 * s, z + 0.005, 0.11 * s, 0.07 * s, 0.01), "flame", grad=(0.0, 0.3))
    m.add(cbox(x, y + 0.22 * s, z, 0.08 * s, 0.03 * s, 0.01), "darkgrey")
    m.add(cbox(x, y + 0.14 * s, z + 0.007, 0.16 * s, 0.02 * s, 0.01), "white", grad=(0.0, 0.2))


def newspaper_kiosk():
    m = Model("newspaper_kiosk")
    w, d, h = 0.26, 0.2, 0.42
    m.add(cbox(0, h / 2, 0, w * 2, h, d * 2), "teal", grad=(0.0, 0.7))
    m.add(cbox(0, h + 0.02, 0, w * 2 + 0.08, 0.04, d * 2 + 0.1), "darkgrey")
    m.add(cbox(0, h + 0.1, d - 0.02, w * 2, 0.12, 0.03), "white", grad=(0.0, 0.3))
    m.add(cbox(0, h + 0.1, d + 0.0, w * 2 - 0.06, 0.06, 0.006), "red", grad=(0.2, 0.5))
    m.add(cbox(0, 0.3, d + 0.004, w * 2 - 0.1, 0.16, 0.006), "skyblue", grad=(0.05, 0.5))
    m.add(cbox(0, 0.19, d + 0.04, w * 2 + 0.02, 0.025, 0.1), "brown", grad=(0.1, 0.6))
    for i, x in enumerate(np.linspace(-0.2, 0.2, 5)):
        m.add(cbox(x, 0.215, d + 0.04, 0.07, 0.025 + 0.01 * (i % 2), 0.08), "white", grad=(0.0, 0.4))
        m.add(cbox(x, 0.232 + 0.01 * (i % 2), d + 0.06, 0.05, 0.004, 0.02), "black", grad=(0.2, 0.5))
    for sx in (1, -1):
        m.add(cbox(sx * (w + 0.04), 0.25, 0, 0.08, 0.35, 0.25), "brown", grad=(0.1, 0.6))
        for k in range(3):
            m.add(cbox(sx * (w + 0.085), 0.12 + k * 0.1, 0, 0.01, 0.07, 0.18), ["white", "sun", "salmon"][k], grad=(0.0, 0.4))
    return m


def newspaper_stack():
    m = Model("newspaper_stack")
    for i in range(5):
        m.add(rot(cbox(0, 0.012 + i * 0.022, 0, 0.16, 0.02, 0.22), ry=(i % 3 - 1) * 4), "white", grad=(0.0, 0.5))
    m.add(cbox(0, 0.06, 0, 0.165, 0.11, 0.012), "brown", grad=(0.1, 0.5))
    m.add(cbox(0, 0.12, 0.02, 0.1, 0.002, 0.08), "black", grad=(0.2, 0.5))
    return m


def earthquake_kit():
    """Deprem cantasi (sirt cantasi)."""
    m = Model("earthquake_kit")
    m.add(cbox(0, 0.1, 0, 0.16, 0.2, 0.09, bevel=0.025), "orange", grad=(0.0, 0.5))
    m.add(cbox(0, 0.07, 0.05, 0.12, 0.09, 0.03, bevel=0.012), "flame", grad=(0.0, 0.3))
    m.add(cbox(0, 0.135, 0.046, 0.161, 0.02, 0.006), "white", grad=(0.0, 0.2))
    m.add(cbox(0, 0.21, 0, 0.06, 0.02, 0.025), "darkgrey")
    for sx in (1, -1):
        m.add(cbox(sx * 0.045, 0.1, -0.05, 0.025, 0.18, 0.015), "darkgrey")
    m.add(cyl(0.03, 0.03, 0.0, 0.006, n=8, axis="z", center=(0.0, 0.095, 0.066)), "white", grad=(0.0, 0.2))
    m.add(cbox(0, 0.095, 0.069, 0.035, 0.01, 0.006), "red", grad=(0.2, 0.5))
    m.add(cbox(0, 0.095, 0.069, 0.01, 0.035, 0.006), "red", grad=(0.2, 0.5))
    return m


def first_aid_box():
    m = Model("first_aid_box")
    m.add(cbox(0, 0.06, 0, 0.2, 0.12, 0.13, bevel=0.012), "white", grad=(0.0, 0.6))
    m.add(cbox(0, 0.13, 0, 0.07, 0.02, 0.025), "darkgrey")
    cross_sign(m, "+z", 0.065, 0, 0.06, size=0.08, bg="white", fg="red")
    return m


def water_pallet():
    """Yardim malzemesi: su paketleri paleti."""
    m = Model("aid_pallet")
    m.add(cbox(0, 0.025, 0, 0.42, 0.05, 0.32), "tan", grad=(0.1, 0.7))
    for x in (-0.11, 0.11):
        for z in (-0.08, 0.08):
            for k in range(2):
                m.add(cbox(x, 0.09 + k * 0.08, z, 0.2, 0.075, 0.15, bevel=0.01), "skyblue", grad=(0.0, 0.6))
    m.add(cbox(0, 0.25, 0, 0.3, 0.08, 0.22, bevel=0.01), "tan", grad=(0.0, 0.5))
    m.add(cbox(0, 0.25, 0.111, 0.1, 0.03, 0.006), "red", grad=(0.2, 0.5))
    return m


MODELS = [assembly_sign, assembly_ground_marker, tent, rubble_small, rubble_large, fire_small, fire_large, smoke,
          sandbags, barrier, traffic_cone, siren_pole, billboard, billboard_campaign, newspaper_kiosk,
          newspaper_stack, earthquake_kit, first_aid_box, water_pallet]
