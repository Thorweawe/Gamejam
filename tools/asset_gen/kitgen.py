"""KayKit City Builder Bits stiline uygun low-poly model ureticisi.

Modeller KayKit'in palet dokusunu (citybits_texture.png) kullanir; her parca
paletteki bir renk hucresine UV'lenir, dikey gradyan da yukseklige gore verilir.
Cikti: Godot'nun dogrudan import edebildigi .gltf + .bin dosyalari.
"""
import json
import math
import os
import shutil
import struct

import numpy as np

# Palet hucreleri (sutun, satir) -- citybits_texture.png 8x4 grid
C = {
    "black": (0, 0), "white": (1, 0), "lightgrey": (2, 0), "darkgrey": (3, 0),
    "charcoal": (4, 0), "terracotta": (5, 0), "brick": (6, 0), "orange": (7, 0),
    "skyblue": (0, 1), "blue": (1, 1), "slate": (2, 1), "ochre": (3, 1),
    "red": (4, 1), "tan": (5, 1), "warmgrey": (6, 1), "brown": (7, 1),
    "lime": (0, 2), "teal": (1, 2), "green": (2, 2), "darkgreen": (3, 2),
    "fade": (4, 2), "cream": (5, 2), "flame": (6, 2), "salmon": (7, 2),
    "concrete": (0, 3), "sun": (2, 3),
}
GLASS = (0.03, 0.80, 0.88)  # (u, v_ust, v_alt) -- paletteki cam bolgesi


# ---------------------------------------------------------------- geometri
def hull(points, eps=1e-6):
    """Kucuk nokta kumeleri icin kaba-kuvvet konveks hull -> polygon listesi."""
    P = np.asarray(points, dtype=np.float64)
    P = np.unique(np.round(P, 6), axis=0)
    n = len(P)
    planes = []
    for i in range(n):
        for j in range(i + 1, n):
            for k in range(j + 1, n):
                nrm = np.cross(P[j] - P[i], P[k] - P[i])
                ln = np.linalg.norm(nrm)
                if ln < 1e-9:
                    continue
                nrm /= ln
                d = P @ nrm - P[i] @ nrm
                if np.all(d <= eps):
                    pass
                elif np.all(d >= -eps):
                    nrm = -nrm
                else:
                    continue
                off = P[i] @ nrm
                if not any(np.allclose(nrm, q[0], atol=1e-5) and abs(off - q[1]) < 1e-5 for q in planes):
                    planes.append((nrm, off))
    polys = []
    for nrm, off in planes:
        on = P[np.abs(P @ nrm - off) < 1e-5]
        c = on.mean(0)
        a = np.cross(nrm, [0, 1, 0] if abs(nrm[1]) < 0.9 else [1, 0, 0])
        a /= np.linalg.norm(a)
        b = np.cross(nrm, a)
        ang = np.arctan2((on - c) @ b, (on - c) @ a)
        polys.append((on[np.argsort(ang)], nrm))
    return polys


def cbox(cx, cy, cz, sx, sy, sz, bevel=0.0):
    """Merkez/boyut ile (istege bagli pahli) kutu noktalari."""
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    b = min(bevel, hx * 0.9, hy * 0.9, hz * 0.9)
    pts = []
    for x in (-1, 1):
        for y in (-1, 1):
            for z in (-1, 1):
                if b <= 0:
                    pts.append((x * hx, y * hy, z * hz))
                else:
                    pts += [(x * (hx - b), y * hy, z * (hz - b)),
                            (x * hx, y * (hy - b), z * (hz - b)),
                            (x * (hx - b), y * (hy - b), z * hz)]
    return [(p[0] + cx, p[1] + cy, p[2] + cz) for p in pts]


def ring(r, y, n, phase=0.0, axis="y", center=(0, 0, 0)):
    out = []
    for i in range(n):
        t = phase + 2 * math.pi * i / n
        a, b = r * math.cos(t), r * math.sin(t)
        if axis == "y":
            p = (a, y, b)
        elif axis == "x":
            p = (y, a, b)
        else:
            p = (a, b, y)
        out.append(tuple(p[i] + center[i] for i in range(3)))
    return out


def cyl(r_bot, r_top, y0, y1, n=8, phase=None, axis="y", center=(0, 0, 0)):
    phase = math.pi / n if phase is None else phase
    return ring(r_bot, y0, n, phase, axis, center) + ring(r_top, y1, n, phase, axis, center)


def blob(cx, cy, cz, r, sy=1.0, jitter=0.12, seed=0, smooth=False):
    """Hafif bozulmus ikosahedron -> low-poly cali / duman. smooth=True: daha yuvarlak (42 nokta)."""
    rng = np.random.default_rng(seed)
    t = (1 + 5 ** 0.5) / 2
    v = np.array([(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
                  (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)], float)
    v /= np.linalg.norm(v[0])
    if smooth:  # kenar ortalarini ekle -> 1 kez alt bolunmus ikosfer
        mids = {tuple(np.round((v[i] + v[j]) / np.linalg.norm(v[i] + v[j]), 6))
                for i in range(12) for j in range(i + 1, 12) if np.linalg.norm(v[i] - v[j]) < 1.1}
        v = np.vstack([v, np.array(sorted(mids))])
    rot = rng.uniform(0, 2 * math.pi)
    R = np.array([[math.cos(rot), 0, math.sin(rot)], [0, 1, 0], [-math.sin(rot), 0, math.cos(rot)]])
    v = v @ R.T * r * (1 + rng.uniform(-jitter, jitter, (len(v), 1)))
    v[:, 1] *= sy
    return [tuple(p) for p in v + (cx, cy, cz)]


def rot(points, ry=0.0, rx=0.0, rz=0.0, pivot=(0, 0, 0)):
    """Noktalari pivot etrafinda dondur (derece; sira: z, x, y)."""
    P = np.asarray(points, float) - pivot
    for ang, ax in ((rz, 2), (rx, 0), (ry, 1)):
        if not ang:
            continue
        a = math.radians(ang)
        c, s = math.cos(a), math.sin(a)
        i, j = [(1, 2), (2, 0), (0, 1)][ax]
        pi, pj = P[:, i].copy(), P[:, j].copy()
        P[:, i], P[:, j] = c * pi - s * pj, s * pi + c * pj
    return [tuple(p) for p in P + pivot]


def chunk(cx, cy, cz, r, seed, flat=0.6):
    """Rastgele kirik parca (moloz/kaya) noktalari."""
    rng = np.random.default_rng(seed)
    pts = rng.normal(size=(9, 3))
    pts /= np.linalg.norm(pts, axis=1, keepdims=True)
    pts *= r * rng.uniform(0.7, 1.0, (9, 1))
    pts[:, 1] *= flat
    pts[:, 1] = np.maximum(pts[:, 1], -r * flat * 0.3)
    return [tuple(p) for p in pts + (cx, cy, cz)]


def load_raw(path):
    """KayKit .gltf'ini tek mesh olarak oku (node donusumleri uygulanir)."""
    g = json.load(open(path))
    b = open(os.path.join(os.path.dirname(path), g["buffers"][0]["uri"]), "rb").read()
    CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}
    NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}

    def acc(i):
        a = g["accessors"][i]
        bv = g["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        return np.frombuffer(b, CT[a["componentType"]], a["count"] * NC[a["type"]], off).reshape(a["count"], -1)

    out = []

    def walk(ni, M):
        n = g["nodes"][ni]
        T = np.eye(4)
        if "scale" in n:
            T = np.diag(n["scale"] + [1]) @ T
        if "rotation" in n:
            x, y, z, w = n["rotation"]
            R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                          [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                          [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
            R4 = np.eye(4)
            R4[:3, :3] = R
            T = R4 @ T
        if "translation" in n:
            T[:3, 3] += n["translation"]
        M = M @ T
        if "mesh" in n:
            p = g["meshes"][n["mesh"]]["primitives"][0]
            P = acc(p["attributes"]["POSITION"]).astype(np.float64)
            N = acc(p["attributes"]["NORMAL"]).astype(np.float64)
            P = P @ M[:3, :3].T + M[:3, 3]
            N = N @ M[:3, :3].T
            N /= np.linalg.norm(N, axis=1, keepdims=True)
            out.append((P, N, acc(p["attributes"]["TEXCOORD_0"]).copy(), acc(p["indices"]).ravel().astype(np.int64)))
        for c in n.get("children", []):
            walk(c, M)

    for ni in g["scenes"][0]["nodes"]:
        walk(ni, np.eye(4))
    return out


# ---------------------------------------------------------------- model
class Part:
    def __init__(self, points, color, grad=(0.15, 0.85), uv=None):
        self.polys = hull(points)
        self.color, self.grad, self.uv = color, grad, uv


class Model:
    """Bir mesh (+ cocuk node'lar). Parcalar tek mesh'te birlestirilir."""

    def __init__(self, name):
        self.name, self.parts, self.children, self.raw = name, [], [], []

    def add(self, points, color, grad=(0.15, 0.85), uv=None):
        self.parts.append(Part(points, color, grad, uv))
        return self

    def add_raw(self, path, offset=(0, 0, 0), yaw=0.0, scale=1.0):
        a = math.radians(yaw)
        R = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
        for P, N, U, I in load_raw(path):
            self.raw.append(((P * scale) @ R.T + offset, N @ R.T, U, I))
        return self

    def child(self, model, translation):
        self.children.append((model, translation))
        return model

    def build(self):
        pos, nor, uvs, idx = [], [], [], []
        for part in self.parts:
            ys = np.concatenate([p[:, 1] for p, _ in part.polys])
            y0, y1 = ys.min(), ys.max()
            for poly, n in part.polys:
                base = len(pos)
                for p in poly:
                    t = 0.5 if y1 - y0 < 1e-6 else (y1 - p[1]) / (y1 - y0)
                    if part.uv:
                        u, va, vb = part.uv
                        v = va + (vb - va) * t
                    else:
                        col, row = C[part.color]
                        g0, g1 = part.grad
                        u = (col + 0.35) / 8
                        v = (row + g0 + (g1 - g0) * t) / 4
                    pos.append(p), nor.append(n), uvs.append((u, v))
                for i in range(1, len(poly) - 1):
                    idx += [base, base + i, base + i + 1]
        for P, N, U, I in self.raw:
            base = len(pos)
            pos += [tuple(p) for p in P]
            nor += [tuple(n) for n in N]
            uvs += [tuple(u) for u in U]
            idx += list(I + base)
        assert len(pos) < 65536, self.name
        return (np.array(pos, np.float32), np.array(nor, np.float32),
                np.array(uvs, np.float32), np.array(idx, np.uint16))


def export(model, out_dir, texture="citybits_texture.png"):
    g = {"asset": {"generator": "kitgen.py", "version": "2.0"}, "scene": 0,
         "scenes": [{"name": "Scene", "nodes": []}], "nodes": [], "meshes": [],
         "materials": [{"name": "citybits_texture",
                        "pbrMetallicRoughness": {"baseColorTexture": {"index": 0},
                                                 "metallicFactor": 0, "roughnessFactor": 0.4}}],
         "textures": [{"sampler": 0, "source": 0}],
         "images": [{"mimeType": "image/png", "name": "citybits_texture", "uri": texture}],
         "samplers": [{"magFilter": 9729, "minFilter": 9987}],
         "accessors": [], "bufferViews": [], "buffers": []}
    blob_ = bytearray()

    def view(data, target):
        while len(blob_) % 4:
            blob_.append(0)
        g["bufferViews"].append({"buffer": 0, "byteOffset": len(blob_), "byteLength": data.nbytes, "target": target})
        blob_.extend(data.tobytes())
        return len(g["bufferViews"]) - 1

    def accessor(data, ctype, typ, target, minmax=False):
        a = {"bufferView": view(data, target), "componentType": ctype, "count": len(data), "type": typ}
        if minmax:
            a["min"], a["max"] = data.min(0).tolist(), data.max(0).tolist()
        g["accessors"].append(a)
        return len(g["accessors"]) - 1

    def add_node(m, translation=None):
        P, N, U, I = m.build()
        g["meshes"].append({"name": m.name, "primitives": [{
            "attributes": {"POSITION": accessor(P, 5126, "VEC3", 34962, True),
                           "TEXCOORD_0": accessor(U, 5126, "VEC2", 34962),
                           "NORMAL": accessor(N, 5126, "VEC3", 34962)},
            "indices": accessor(I, 5123, "SCALAR", 34963), "material": 0}]})
        node = {"name": m.name, "mesh": len(g["meshes"]) - 1}
        if translation:
            node["translation"] = list(translation)
        kids = [add_node(c, t) for c, t in m.children]
        if kids:
            node["children"] = kids
        g["nodes"].append(node)
        return len(g["nodes"]) - 1

    root = add_node(model)
    g["scenes"][0]["nodes"] = [root]
    g["buffers"] = [{"byteLength": len(blob_), "uri": model.name + ".bin"}]
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, model.name + ".bin"), "wb") as f:
        f.write(blob_)
    with open(os.path.join(out_dir, model.name + ".gltf"), "w") as f:
        json.dump(g, f, indent=2)
    return os.path.join(out_dir, model.name + ".gltf")
