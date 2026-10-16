"""Modeller arasinda paylasilan parcalar (teker, pencere, kapi, bayrak...)."""
import math
import os

from kitgen import Model, cbox, cyl, rot

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KAYKIT = os.path.join(ROOT, "portofolyo", "assets", "_kaynak", "kaykit_city_builder_bits")

# KayKit arabalariyla ayni teker olculeri (car_sedan.gltf'ten)
WHEEL_R, WHEEL_W, WHEEL_Y = 0.072, 0.062, 0.0113
GROUND = WHEEL_Y - WHEEL_R  # arac modellerinde zemin seviyesi (KayKit ile ayni)
BUILDING_GLASS = ("skyblue", (0.05, 0.6))


# ---------------------------------------------------------------- araclar
def wheel(name, r=WHEEL_R, w=WHEEL_W):
    m = Model(name)
    m.add(cyl(r, r, -w / 2, w / 2, n=10, axis="x"), "charcoal")
    m.add(cyl(r * 0.5, r * 0.5, -w / 2 - 0.004, w / 2 + 0.004, n=8, axis="x"), "lightgrey")
    return m


def add_wheels(m, x, zs, r=WHEEL_R, w=WHEEL_W):
    """zs: aks konumlari (onden arkaya). Teker node'lari ayri -> Godot'ta dondurulebilir."""
    y = GROUND + r
    names = ["front", "rear", "rear2", "rear3"]
    for i, z in enumerate(zs):
        for side, sx in (("left", x), ("right", -x)):
            m.child(wheel(f"{m.name}_wheel_{names[i]}_{side}", r, w), (sx, y, z))


def lightbar(m, x, y, z, w, colors=("red", "blue")):
    m.add(cbox(x, y, z, w + 0.02, 0.022, 0.075), "darkgrey")
    m.add(cbox(x + w / 4, y + 0.025, z, w / 2 - 0.01, 0.032, 0.06, bevel=0.008), colors[0], grad=(0.0, 0.4))
    m.add(cbox(x - w / 4, y + 0.025, z, w / 2 - 0.01, 0.032, 0.06, bevel=0.008), colors[1], grad=(0.0, 0.4))


def car_lights(m, half_w, y, z_front, z_rear, fx=0.15):
    for sx in (1, -1):
        m.add(cbox(sx * fx, y, z_front, 0.07, 0.04, 0.012), "sun", grad=(0.0, 0.3))
        m.add(cbox(sx * (half_w - 0.04), y, z_rear, 0.05, 0.05, 0.012), "red", grad=(0.0, 0.3))


# ---------------------------------------------------------------- binalar
def base_slab(m, sx=2.0, sz=2.0):
    """KayKit 'base' kaldirimiyla ayni: 2x2, 0.1 yukseklik."""
    m.add(cbox(0, 0.05, 0, sx, 0.1, sz), "lightgrey", grad=(0.48, 0.88))


def block(m, x0, x1, y0, y1, z0, z1, color, grad=(0.1, 0.9), bevel=0.0):
    m.add(cbox((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, bevel), color, grad)


def face_box(face, wall, a, y, w, h, d):
    """Bir cepheye (+z, -z, +x, -x) yapisik kutu. a: cephe boyunca konum."""
    s = 1 if face[0] == "+" else -1
    c = wall + s * d / 2
    if face[1] == "z":
        return cbox(a, y, c, w, h, d)
    return cbox(c, y, a, d, h, w)


def window(m, face, wall, a, y, w=0.16, h=0.24, frame="white", glass=BUILDING_GLASS, sill=True):
    m.add(face_box(face, wall, a, y, w + 0.05, h + 0.05, 0.02), frame, grad=(0.0, 0.3))
    m.add(face_box(face, wall, a, y, w, h, 0.028), glass[0], grad=glass[1])
    m.add(face_box(face, wall, a, y, 0.012, h, 0.032), frame, grad=(0.0, 0.3))
    if sill:
        m.add(face_box(face, wall, a, y - h / 2 - 0.025, w + 0.08, 0.025, 0.05), frame, grad=(0.0, 0.3))


def window_row(m, face, wall, positions, y, **kw):
    for a in positions:
        window(m, face, wall, a, y, **kw)


def door(m, face, wall, a, y0, w=0.2, h=0.34, color="brown", frame="white", glass=True):
    y = y0 + h / 2
    m.add(face_box(face, wall, a, y + 0.01, w + 0.05, h + 0.03, 0.02), frame, grad=(0.0, 0.3))
    m.add(face_box(face, wall, a, y, w, h, 0.026), color, grad=(0.1, 0.7))
    if glass:
        m.add(face_box(face, wall, a, y + h * 0.18, w * 0.6, h * 0.35, 0.03), *BUILDING_GLASS)


def ledge(m, x0, x1, z0, z1, y, color="darkgrey", out=0.03, h=0.045):
    block(m, x0 - out, x1 + out, y - h / 2, y + h / 2, z0 - out, z1 + out, color, grad=(0.1, 0.6))


def roof_flat(m, x0, x1, z0, z1, y, color="lightgrey", rim="darkgrey"):
    block(m, x0, x1, y, y + 0.03, z0, z1, color, grad=(0.3, 0.7))
    t = 0.05
    for (a0, a1, b0, b1) in ((x0, x1, z0, z0 + t), (x0, x1, z1 - t, z1), (x0, x0 + t, z0, z1), (x1 - t, x1, z0, z1)):
        block(m, a0 - 0.02, a1 + 0.02, y, y + 0.09, b0 - 0.02, b1 + 0.02, rim, grad=(0.1, 0.5))


def roof_hip(m, x0, x1, z0, z1, y, h, color="terracotta", over=0.06):
    x0, x1, z0, z1 = x0 - over, x1 + over, z0 - over, z1 + over
    inset = min(x1 - x0, z1 - z0) / 2 * 0.9
    m.add([(x0, y, z0), (x1, y, z0), (x0, y, z1), (x1, y, z1),
           (x0 + inset, y + h, z0 + inset), (x1 - inset, y + h, z0 + inset),
           (x0 + inset, y + h, z1 - inset), (x1 - inset, y + h, z1 - inset)], color, grad=(0.0, 0.7))
    block(m, x0, x1, y - 0.03, y, z0, z1, "white", grad=(0.0, 0.3))


def awning(m, face, wall, a, y, w, colors=("red", "white"), depth=0.18, n=6):
    """Cizgili tente (KayKit dukkan tentesi gibi)."""
    s = 1 if face[0] == "+" else -1
    seg = w / n
    for i in range(n):
        u0 = a - w / 2 + i * seg
        u1 = u0 + seg
        pts = []
        for u in (u0, u1):
            for (dd, yy) in ((0.0, y), (depth, y - 0.12), (0.0, y - 0.02), (depth, y - 0.14)):
                c = wall + s * dd
                pts.append((u, yy, c) if face[1] == "z" else (c, yy, u))
        m.add(pts, colors[i % 2], grad=(0.0, 0.5))


def flag_tr(m, x, y0, z, height=0.7, size=0.22):
    """Direk + Turk bayragi (kirmizi zemin, beyaz ay-yildiz)."""
    m.add(cyl(0.012, 0.009, y0, y0 + height, n=6, center=(x, 0, z)), "lightgrey")
    m.add(cyl(0.02, 0.02, y0 + height, y0 + height + 0.025, n=6, center=(x, 0, z)), "sun")
    fy = y0 + height - size * 0.35
    fw = size
    m.add(cbox(x + fw / 2 + 0.012, fy, z, fw, size * 0.66, 0.012), "red", grad=(0.15, 0.45))
    cx = x + 0.012 + fw * 0.38
    for side in (1, -1):
        m.add(cyl(size * 0.17, size * 0.17, 0, 0.004, n=10, axis="z", center=(cx, fy, z + side * 0.006)), "white", grad=(0.0, 0.2))
        m.add(cyl(size * 0.135, size * 0.135, 0, 0.004, n=10, axis="z",
                  center=(cx + size * 0.045, fy, z + side * 0.0085)), "red", grad=(0.15, 0.45))
        m.add(cbox(cx + size * 0.2, fy, z + side * 0.0075, size * 0.07, size * 0.07, 0.004), "white", grad=(0.0, 0.2))


def cross_sign(m, face, wall, a, y, size=0.22, bg="white", fg="red"):
    m.add(face_box(face, wall, a, y, size, size, 0.03), bg, grad=(0.0, 0.3))
    m.add(face_box(face, wall, a, y, size * 0.62, size * 0.2, 0.036), fg, grad=(0.2, 0.5))
    m.add(face_box(face, wall, a, y, size * 0.2, size * 0.62, 0.036), fg, grad=(0.2, 0.5))


def crack(m, face, wall, a, y, length, seed=0, color="black", segs=4):
    """Cephede zikzak catlak."""
    import numpy as np
    rng = np.random.default_rng(seed)
    pa, py = a, y
    step = length / segs
    for i in range(segs):
        ang = rng.uniform(-60, 60) - 90
        da, dy = step * math.cos(math.radians(ang)), step * math.sin(math.radians(ang))
        ca, cy_ = pa + da / 2, py + dy / 2
        thick = 0.034 * (1 - i / (segs + 1))
        pts = face_box(face, wall, 0, 0, step * 1.1, thick, 0.01)
        if face[1] == "z":
            pts = rot(pts, rz=ang)
            pts = [(p[0] + ca, p[1] + cy_, p[2]) for p in pts]
        else:
            pts = rot(pts, rx=-ang)
            pts = [(p[0], p[1] + cy_, p[2] + ca) for p in pts]
        m.add(pts, color, grad=(0.3, 0.6))
        pa, py = pa + da, py + dy


def wall_hole(m, face, wall, a, y, r, seed=0):
    """Cephede dokulmus siva / delik: duzensiz koyu yama + kenarinda tugla."""
    import numpy as np
    rng = np.random.default_rng(seed)
    ang = np.sort(rng.uniform(0, 2 * math.pi, 7))
    rad = r * rng.uniform(0.6, 1.0, 7)
    s = 1 if face[0] == "+" else -1
    for col, k, d in (("brick", 1.0, 0.012), ("charcoal", 0.65, 0.02)):
        pts = []
        for t, rr in zip(ang, rad):
            u, v = a + math.cos(t) * rr * k, y + math.sin(t) * rr * k * 0.8
            for dd in (0.0, d):
                c = wall + s * dd
                pts.append((u, v, c) if face[1] == "z" else (c, v, u))
        m.add(pts, col, grad=(0.2, 0.7))
