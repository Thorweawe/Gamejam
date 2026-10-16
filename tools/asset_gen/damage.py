"""Herhangi bir binadan otomatik hasarli (_damaged) ve yikik (_collapsed) versiyon uretir.

Catlak/delikler, modelin gercek yuzeyine isin atilarak (probe) yerlestirilir;
yikik halin renkleri modelin paletten en cok kullandigi renklerden secilir.
"""
import math
import os

import numpy as np

from kitgen import C, Model, chunk, load_raw, rot, cbox
from parts import KAYKIT, ROOT, base_slab, block

AI = os.path.join(ROOT, "portofolyo", "assets", "_kaynak", "ai_uretim")
CELL_NAME = {v: k for k, v in C.items()}
Y0 = 0.1


class Shape:
    """Kaynak modelin ucgenleri + yuzey sorgulari."""

    def __init__(self, path):
        P, U, I = [], [], []
        off = 0
        for p, n, u, i in load_raw(path):
            P.append(p), U.append(u), I.append(i + off)
            off += len(p)
        self.P, self.U = np.vstack(P), np.vstack(U)
        self.T = self.P[np.concatenate(I).reshape(-1, 3)]
        self.TU = self.U[np.concatenate(I).reshape(-1, 3)]
        body = self.P[self.P[:, 1] > Y0 + 0.02]
        self.lo, self.hi = body.min(0), body.max(0)

    def probe(self, axis, a, y):
        """+axis yonunden isin: (a, y) noktasindaki en distaki yuzey koordinati (yoksa None)."""
        k = 2 if axis == "z" else 0  # derinlik ekseni
        j = 0 if axis == "z" else 2  # cephe boyunca eksen
        A, B, Cc = self.T[:, 0], self.T[:, 1], self.T[:, 2]
        v0 = np.stack([Cc[:, j] - A[:, j], Cc[:, 1] - A[:, 1]], 1)
        v1 = np.stack([B[:, j] - A[:, j], B[:, 1] - A[:, 1]], 1)
        v2 = np.stack([a - A[:, j], y - A[:, 1]], 1)
        d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
        d02, d12 = (v0 * v2).sum(1), (v1 * v2).sum(1)
        den = d00 * d11 - d01 ** 2
        ok = np.abs(den) > 1e-12
        den = np.where(ok, den, 1)
        u = (d11 * d02 - d01 * d12) / den
        v = (d00 * d12 - d01 * d02) / den
        hit = ok & (u >= -1e-6) & (v >= -1e-6) & (u + v <= 1 + 1e-6)
        if not hit.any():
            return None
        depth = A[:, k] + u * (Cc[:, k] - A[:, k]) + v * (B[:, k] - A[:, k])
        return float(depth[hit].max())

    def colors(self, n=4):
        """Alan agirlikli en cok kullanilan palet hucreleri."""
        area = np.linalg.norm(np.cross(self.T[:, 1] - self.T[:, 0], self.T[:, 2] - self.T[:, 0]), axis=1)
        cu = self.TU.mean(1)
        weights = {}
        for (u, v), w in zip(cu, area):
            cell = (min(int(u * 8), 7), min(int(v * 4), 3))
            name = CELL_NAME.get(cell)
            if name and name not in ("concrete",):
                weights[name] = weights.get(name, 0) + w
        top = sorted(weights, key=weights.get, reverse=True)
        top = [c for c in top if c != "lightgrey"][:n]  # taban kaldirimi baskin cikmasin
        return top or ["warmgrey"]


def _on_face(axis, a, y, depth, w, h, d=0.012):
    if axis == "z":
        return cbox(a, y, depth + d / 2, w, h, d)
    return cbox(depth + d / 2, y, a, d, h, w)


def crack(m, shape, axis, a, y, length, rng, segs=5):
    for i in range(segs):
        ang = rng.uniform(-60, 60) - 90
        step = length / segs
        da, dy = step * math.cos(math.radians(ang)), step * math.sin(math.radians(ang))
        ca, cy = a + da / 2, y + dy / 2
        depth = shape.probe(axis, ca, cy)
        if depth is None or cy < Y0 + 0.05:
            break
        pts = _on_face(axis, 0, 0, 0, step * 1.15, 0.034 * (1 - i / (segs + 1)), 0.01)
        pts = rot(pts, rz=ang) if axis == "z" else rot(pts, rx=-ang)
        off = (ca, cy, depth + 0.004) if axis == "z" else (depth + 0.004, cy, ca)
        m.add([(p[0] + off[0], p[1] + off[1], p[2] + off[2]) for p in pts], "black", grad=(0.3, 0.6))
        a, y = a + da, y + dy


def hole(m, shape, axis, a, y, r, rng, wall_color):
    depth = shape.probe(axis, a, y)
    if depth is None:
        return
    ang = np.sort(rng.uniform(0, 2 * math.pi, 7))
    rad = r * rng.uniform(0.6, 1.0, 7)
    for col, k, d in ((wall_color, 1.0, 0.012), ("charcoal", 0.62, 0.02)):
        pts = []
        for t, rr in zip(ang, rad):
            u, v = a + math.cos(t) * rr * k, y + math.sin(t) * rr * k * 0.8
            for dd in (0.0, d):
                pts.append((u, v, depth + dd) if axis == "z" else (depth + dd, v, u))
        m.add(pts, col, grad=(0.2, 0.7))


def damaged(src, name, seed):
    shape = Shape(src)
    m = Model(name)
    m.add_raw(src)
    rng = np.random.default_rng(seed)
    cols = shape.colors()
    lo, hi = shape.lo, shape.hi
    H = hi[1] - Y0
    for axis, (a0, a1) in (("z", (lo[0], hi[0])), ("x", (lo[2], hi[2]))):
        n = 2 + int(H / 0.8)
        for k in range(n):
            a = rng.uniform(a0 + 0.12, a1 - 0.12)
            y = rng.uniform(Y0 + H * 0.35, hi[1] - 0.08)
            crack(m, shape, axis, a, y, rng.uniform(0.35, 0.7), rng)
        for k in range(1 + int(H / 1.2)):
            hole(m, shape, axis, rng.uniform(a0 + 0.2, a1 - 0.2), rng.uniform(Y0 + 0.4, hi[1] - 0.15), rng.uniform(0.08, 0.13),
                 rng, cols[0])
    for i in range(20):
        if i % 3 == 0:
            x, z = rng.uniform(min(hi[0] + 0.02, 0.9), 0.95), rng.uniform(-0.8, 0.8)
        else:
            x, z = rng.uniform(-0.85, 0.85), rng.uniform(min(hi[2] + 0.02, 0.9), 0.95)
        m.add(chunk(x, Y0, z, rng.uniform(0.05, 0.1), seed * 31 + i), (cols + ["lightgrey", "warmgrey"])[i % (len(cols) + 2)],
              grad=(0.2, 0.8))
    for i in range(3):
        x = rng.uniform(-0.6, 0.6)
        m.add(rot(cbox(x, Y0 + 0.03, 0.85, 0.25, 0.015, 0.03), ry=rng.uniform(-40, 40), pivot=(x, Y0, 0.85)), "brown",
              grad=(0.2, 0.7))
    return m


def collapsed(src, name, seed):
    shape = Shape(src)
    m = Model(name)
    base_slab(m)
    rng = np.random.default_rng(seed)
    cols = shape.colors()
    lo, hi = shape.lo, shape.hi
    H = hi[1] - Y0
    heap = min(0.65, 0.15 + 0.17 * H)
    wall = cols[0]
    # kalan duvar kutuklari (arka ve sol kenar, kirik ust)
    n = 4
    for i in range(n):
        x0 = lo[0] + (hi[0] - lo[0]) * i / n
        h = heap * rng.uniform(0.7, 1.5) * (1 - i / (n + 1))
        block(m, x0, x0 + (hi[0] - lo[0]) / n, Y0, Y0 + h, lo[2], lo[2] + 0.1, wall, (0.0, 0.8))
    for i in range(3):
        z0 = lo[2] + (hi[2] - lo[2]) * i / 3
        h = heap * rng.uniform(0.6, 1.3) * (1 - i / 4)
        block(m, lo[0], lo[0] + 0.1, Y0, Y0 + h, z0, z0 + (hi[2] - lo[2]) / 3, wall, (0.0, 0.8))
    # egik dosemeler
    for i in range(2 + int(H > 1.5)):
        cx, cz = rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.2)
        cy = Y0 + heap * (0.35 + 0.3 * i)
        m.add(rot(cbox(cx, cy, cz, (hi[0] - lo[0]) * 0.5, 0.05, (hi[2] - lo[2]) * 0.45), rz=rng.uniform(-25, 25),
                  rx=rng.uniform(-12, 12), pivot=(cx, cy, cz)), "lightgrey", grad=(0.3, 0.8))
    # moloz yigini
    palette = cols + ["lightgrey", "warmgrey", "darkgrey"]
    for i in range(70):
        r = rng.uniform(0.07, 0.17)
        x, z = rng.uniform(-0.8, 0.8), rng.uniform(-0.6, 0.88)
        h = max(0.0, heap - heap * 1.1 * (x * x + (z - 0.05) ** 2) ** 0.5)
        m.add(chunk(x, Y0 + h * rng.uniform(0.3, 1.0), z, r, seed * 100 + i), palette[i % len(palette)], grad=(0.2, 0.8))
    # filiz demirleri + kalaslar
    for i in range(7):
        x, z = rng.uniform(-0.45, 0.45), rng.uniform(-0.35, 0.45)
        m.add(rot(cbox(x, Y0 + heap * 0.7, z, 0.006, heap * 0.9, 0.006), rx=rng.uniform(-35, 35), rz=rng.uniform(-35, 35),
                  pivot=(x, Y0 + heap * 0.3, z)), "charcoal")
    for i in range(4):
        x, z = rng.uniform(-0.6, 0.6), rng.uniform(0.2, 0.85)
        m.add(rot(cbox(x, Y0 + 0.05, z, 0.35, 0.02, 0.04), ry=rng.uniform(0, 180), rz=rng.uniform(-15, 15),
                  pivot=(x, Y0 + 0.05, z)), "brown", grad=(0.2, 0.7))
    return m


def _pair(src_path, base_name, seed):
    def d():
        return damaged(src_path, base_name + "_damaged", seed)

    def c():
        return collapsed(src_path, base_name + "_collapsed", seed + 1)

    d.__name__, c.__name__ = base_name + "_damaged", base_name + "_collapsed"
    return [d, c]


KAYKIT_BUILDINGS = [f"building_{c}" for c in "ABCDEFGH"]
AI_BUILDINGS = ["building_townhall_lv1", "building_townhall_lv2", "building_townhall_lv3", "building_hospital",
                "building_firestation", "building_school", "building_afad", "building_news",
                "building_hospital_lv2", "building_hospital_lv3", "building_firestation_lv2", "building_firestation_lv3",
                "building_afad_lv2", "building_afad_lv3"]

MODELS = []
for i, n in enumerate(KAYKIT_BUILDINGS):
    MODELS += _pair(os.path.join(KAYKIT, n + ".gltf"), n, 100 + i * 7)
for i, n in enumerate(AI_BUILDINGS):
    MODELS += _pair(os.path.join(AI, n + ".gltf"), n, 300 + i * 7)
