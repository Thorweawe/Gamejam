"""Zemin karolari: 2x2, ust yuzey y=0.1 (KayKit yol/base ile ayni)."""
import math
import os

import numpy as np

from kitgen import Model, cbox, chunk, rot
from parts import KAYKIT, block

T = 0.1  # karo ust yuzeyi


def grass_slab(m, x0, x1, z0, z1):
    block(m, x0, x1, 0, T - 0.025, z0, z1, "brown", (0.2, 0.9))
    block(m, x0, x1, T - 0.025, T, z0, z1, "green", (0.15, 0.5))


def tile_grass():
    m = Model("tile_grass")
    grass_slab(m, -1, 1, -1, 1)
    return m


def tile_sand():
    """Kumsal (ada kenari)."""
    m = Model("tile_sand")
    block(m, -1, 1, 0, T - 0.02, -1, 1, "brown", (0.4, 0.9))
    block(m, -1, 1, T - 0.02, T, -1, 1, "tan", (0.0, 0.25))
    return m


def tile_plaza():
    """Park / toplanma alani zemini (acik tas)."""
    m = Model("tile_plaza")
    block(m, -1, 1, 0, T, -1, 1, "tan", (0.1, 0.6))
    for i in range(1, 4):
        a = -1 + i * 0.5
        m.add(cbox(a, T + 0.001, 0, 0.012, 0.004, 2.0), "warmgrey", grad=(0.3, 0.6))
        m.add(cbox(0, T + 0.001, a, 2.0, 0.004, 0.012), "warmgrey", grad=(0.3, 0.6))
    return m


def water(m, x0, x1, z0, z1, top=0.06):
    block(m, x0, x1, 0, top - 0.02, z0, z1, "tan", (0.3, 0.9))
    block(m, x0, x1, top - 0.02, top, z0, z1, "blue", (0.05, 0.35))


def tile_water():
    m = Model("tile_water")
    water(m, -1, 1, -1, 1)
    return m


def tile_river_straight():
    """Dere: Z yonunde akar."""
    m = Model("tile_river_straight")
    w = 0.45
    water(m, -w, w, -1, 1)
    for sx in (1, -1):
        grass_slab(m, *sorted((sx * w, sx * 1.0)), -1, 1)
        block(m, *sorted((sx * w, sx * (w + 0.06))), 0.04, T - 0.02, -1, 1, "tan", (0.3, 0.8))
    rng = np.random.default_rng(2)
    for i in range(6):
        sx = 1 if i % 2 else -1
        m.add(chunk(sx * (w + 0.02), T - 0.03, rng.uniform(-0.9, 0.9), 0.05, 20 + i), "warmgrey", grad=(0.2, 0.7))
    return m


def tile_river_corner():
    """Dere donusu: +Z'den girer, +X'ten cikar."""
    m = Model("tile_river_corner")
    w = 0.45
    water(m, -w, w, -w, w)
    water(m, -w, w, w, 1)
    water(m, w, 1, -w, w)
    grass_slab(m, -1, -w, -1, 1)
    grass_slab(m, -w, 1, -1, -w)
    grass_slab(m, w, 1, w, 1)
    block(m, -w - 0.06, -w, 0.04, T - 0.02, -1, 1, "tan", (0.3, 0.8))
    block(m, -w, 1, 0.04, T - 0.02, -w - 0.06, -w, "tan", (0.3, 0.8))
    block(m, w, w + 0.06, 0.04, T - 0.02, w, 1, "tan", (0.3, 0.8))
    block(m, w, 1, 0.04, T - 0.02, w, w + 0.06, "tan", (0.3, 0.8))
    return m


def tile_road_cracked():
    """KayKit road_straight + deprem catlaklari, kalkmis asfalt parcalari."""
    m = Model("road_straight_cracked")
    m.add_raw(os.path.join(KAYKIT, "road_straight.gltf"))
    rng = np.random.default_rng(8)
    for k in range(3):
        x, z = rng.uniform(-0.4, 0.4), rng.uniform(-0.6, 0.6)
        ang = rng.uniform(0, 180)
        for s in range(6):
            ln = rng.uniform(0.12, 0.22)
            ang += rng.uniform(-45, 45)
            dx, dz = math.cos(math.radians(ang)) * ln, math.sin(math.radians(ang)) * ln
            if abs(x + dx) > 0.85 or abs(z + dz) > 0.85:  # karo disina tasma
                break
            cx, cz = x + dx / 2, z + dz / 2
            m.add(rot(cbox(cx, T + 0.002, cz, ln * 1.1, 0.006, 0.03 * (1 - s / 7)), ry=-ang, pivot=(cx, T, cz)),
                  "black", grad=(0.3, 0.6))
            x, z = x + dx, z + dz
    for i, (x, z) in enumerate(((0.3, 0.2), (-0.35, -0.4), (0.1, -0.1))):
        m.add(rot(cbox(x, T + 0.02, z, 0.3, 0.04, 0.25), rz=rng.uniform(6, 14), rx=rng.uniform(-8, 8), ry=rng.uniform(0, 90),
                  pivot=(x, T, z)), "charcoal", grad=(0.3, 0.6))
    for i in range(10):
        m.add(chunk(rng.uniform(-0.8, 0.8), T, rng.uniform(-0.9, 0.9), rng.uniform(0.02, 0.05), 50 + i), "darkgrey",
              grad=(0.3, 0.7))
    return m


def flood_puddles(m, y, seed, coverage=0.75):
    rng = np.random.default_rng(seed)
    for i in range(5):
        cx, cz = rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45)
        r = rng.uniform(0.4, 0.6) * coverage / 0.75
        ang = np.linspace(0, 2 * math.pi, 12, endpoint=False) + rng.uniform(0, 0.5)
        pts = []
        for a in ang:
            rr = r * rng.uniform(0.92, 1.0)
            px = float(np.clip(cx + math.cos(a) * rr, -1, 1))
            pz = float(np.clip(cz + math.sin(a) * rr, -1, 1))
            pts += [(px, y, pz), (px, y + 0.012, pz)]
        m.add(pts, "skyblue", grad=(0.4, 0.6))


def flood_overlay():
    """Sel suyu katmani (2x2). Her karonun ustune konup y'si yukseltilerek animasyon yapilabilir."""
    m = Model("flood_water_overlay")
    m.add(cbox(0, 0.01, 0, 2.0, 0.02, 2.0), "skyblue", grad=(0.4, 0.6))
    return m


def flood_puddle_overlay():
    m = Model("flood_puddles_overlay")
    flood_puddles(m, 0.0, 4)
    return m


def tile_road_flooded():
    m = Model("road_straight_flooded")
    m.add_raw(os.path.join(KAYKIT, "road_straight.gltf"))
    flood_puddles(m, T + 0.01, 6, coverage=0.9)
    rng = np.random.default_rng(1)
    for i in range(5):
        x, z = rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7)
        m.add(rot(cbox(x, T + 0.03, z, 0.18, 0.015, 0.04), ry=rng.uniform(0, 180), pivot=(x, T, z)), "brown", grad=(0.2, 0.7))
    return m


def tile_grass_flooded():
    m = Model("tile_grass_flooded")
    grass_slab(m, -1, 1, -1, 1)
    flood_puddles(m, T + 0.002, 9, coverage=0.85)
    return m


MODELS = [tile_grass, tile_sand, tile_plaza, tile_water, tile_river_straight, tile_river_corner, tile_road_cracked,
          tile_road_flooded, tile_grass_flooded, flood_overlay, flood_puddle_overlay]
