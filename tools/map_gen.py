"""Sehir haritasini ASCII plandan Godot sahnesine cevirir -> portofolyo/scenes/city_map.tscn

  python tools/map_gen.py

Plan karakterleri (her karakter 2x2'lik bir karo):
  .  kumsal          ~  (kullanilmaz, ada disi deniz otomatik)
  =  yol (yonu komsulara gore otomatik: duz / kose / T / dortyol)
  w  dere            g  cim           T  orman        r  kayalik
  p  park            P  meydan        A  toplanma alani
  b  kampanya panosu C  insaat alani (kule vincli)
  Binalar (Building yuvasi: normal/hasarli/yikik + animasyon):
  0 gecekondu  1 ev  2 apartman  3 gelismis bina  k kacak katli ev  K kacak katli apartman
  R guclendirilmis apartman   c dukkan binasi (KayKit A-H)
  H belediye  h hastane  f itfaiye  s okul  a AFAD  n gazete/TV
Binalar on yuzlerini otomatik olarak komsu yola cevirir.
"""
import math
import os
import random
import sys
from functools import lru_cache

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "asset_gen"))
from kitgen import load_raw  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "portofolyo", "scenes", "city_map.tscn")

PLAN = [
    "....................",
    ".rTwTTTpTTTpTTTpTTr.",
    ".TTw0g1g21g2c12g1gT.",
    ".Tgw0=============1.",
    ".rgw0=121=gsg=323=1.",
    ".Tgw0=2p1=ppp=Rp2=g.",
    ".Tgw0=12K=TbT=23K=1.",
    ".TTw0=============1.",
    ".rgw0=cnc=PPP=hca=1.",
    ".Tgw0=cPc=PHP=gPf=g.",
    ".TTw0=ccc=PPP=cbc=1.",
    ".Tgw0=============g.",
    ".Tgw0=1k2=TpT=2C3=1.",
    ".rgw0=2p1=pAp=2p2=g.",
    ".TTwg=12k=TpT=132=1.",
    ".Tgwg=============g.",
    ".Tgwg01g21g10g12gg..",
    "...w................",
]

BUILDINGS = {
    "0": "house_lv0_gecekondu", "1": "house_lv1", "2": "house_lv2", "3": "house_lv3",
    "k": "house_lv1_kacak", "K": "house_lv2_kacak", "R": "house_lv2_reinforced",
    "H": "building_townhall_lv1", "h": "building_hospital", "f": "building_firestation",
    "s": "building_school", "a": "building_afad", "n": "building_news",
}
SHOPS = [f"building_{c}" for c in "ABCDEFGH"]

# Arabalar ve yayalar sahnede durmaz; oyun basinda scripts/traffic.gd yol agina gore olusturur.

M = "res://assets/models/"
SIDES = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}
ROT90 = {"+z": "+x", "+x": "-z", "-z": "-x", "-x": "+z"}  # Godot'ta +90 derece Y donusu
YAW = {"+z": 0, "+x": 90, "-z": 180, "-x": 270}

SEA_SHADER = """shader_type spatial;
uniform vec3 deep = vec3(0.04, 0.26, 0.55);
uniform vec3 shallow = vec3(0.1, 0.48, 0.75);
varying float wave;
void vertex() {
\twave = sin(VERTEX.x * 0.45 + TIME * 1.1) * 0.5 + cos(VERTEX.z * 0.38 + TIME * 0.8) * 0.5;
\tVERTEX.y += wave * 0.025;
}
void fragment() {
\tALBEDO = mix(deep, shallow, 0.45 + wave * 0.15);
\tROUGHNESS = 0.55;
\tSPECULAR = 0.25;
}"""

ROAD_TILES = [  # (model, varsayilan acik kenarlar) -- KayKit yol modellerinden olculdu
    ("road_junction", {"+x", "-x", "+z", "-z"}),
    ("road_tsplit", {"+x", "+z", "-z"}),
    ("road_straight", {"+z", "-z"}),
    ("road_corner_curved", {"+x", "+z"}),
]
RIVER_TILES = [("tile_river_straight", {"+z", "-z"}), ("tile_river_corner", {"+x", "+z"})]


class Scene:
    def __init__(self):
        self.ext, self.nodes, self.subs = {}, [], []

    def res(self, path, typ="PackedScene"):
        if path not in self.ext:
            self.ext[path] = (typ, f"{len(self.ext) + 1}_r")
        return self.ext[path][1]

    def node(self, name, typ=None, parent=".", instance=None, props=None):
        head = f'[node name="{name}"'
        if typ:
            head += f' type="{typ}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if instance:
            head += f' instance=ExtResource("{self.res(instance)}")'
        lines = [head + "]"]
        for k, v in (props or {}).items():
            lines.append(f"{k} = {v}")
        self.nodes.append("\n".join(lines))

    def write(self, path):
        out = [f"[gd_scene load_steps={len(self.ext) + len(self.subs) + 1} format=3]", ""]
        for p, (typ, rid) in self.ext.items():
            out.append(f'[ext_resource type="{typ}" path="{p}" id="{rid}"]')
        out.append("")
        out += self.subs
        out += [n + "\n" for n in self.nodes]
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(out))


def xform(x, y, z, yaw=0.0, scale=1.0, pitch=0.0):
    """Godot Transform3D (satir sirali baz). Once pitch (X), sonra yaw (Y)."""
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rx = [[1, 0, 0], [0, cp, -sp], [0, sp, cp]]
    b = [[sum(ry[i][k] * rx[k][j] for k in range(3)) * scale for j in range(3)] for i in range(3)]
    nums = [b[i][j] for i in range(3) for j in range(3)] + [x, y, z]
    return "Transform3D(" + ", ".join(f"{v:.6g}" if abs(v) > 1e-9 else "0" for v in nums) + ")"


def rotate_set(s, k):
    for _ in range(k):
        s = {ROT90[d] for d in s}
    return s


def pick_tile(options, open_sides):
    for model, base in options:
        for k in range(4):
            if rotate_set(base, k) == open_sides:
                return model, k * 90
    # cikmaz / tek komsu: komsu eksenine gore duz parca
    straight = next(model for model, base in options if base == {"+z", "-z"})
    return straight, (90 if open_sides & {"+x", "-x"} else 0)


def main():
    rnd = random.Random(7)
    H, W = len(PLAN), len(PLAN[0])
    assert all(len(r) == W for r in PLAN), "plan satirlari esit uzunlukta olmali"

    def at(c, r):
        return PLAN[r][c] if 0 <= r < H and 0 <= c < W else None

    def pos(c, r):
        return (c - (W - 1) / 2) * 2.0, (r - (H - 1) / 2) * 2.0

    def facing(c, r):
        for d in ("+z", "+x", "-x", "-z"):  # once kameraya bakan yonler
            dc, dr = SIDES[d]
            if at(c + dc, r + dr) == "=":
                return d
        return "+z"

    s = Scene()
    s.res("res://scripts/city_map.gd", "Script")
    s.res("res://scripts/camera_rig.gd", "Script")
    s.res("res://scripts/building.gd", "Script")
    s.res("res://scripts/traffic.gd", "Script")
    s.subs += [
        '[sub_resource type="ProceduralSkyMaterial" id="sky_mat"]\n'
        "sky_top_color = Color(0.36, 0.6, 0.86, 1)\nsky_horizon_color = Color(0.72, 0.85, 0.95, 1)\n"
        "ground_bottom_color = Color(0.2, 0.42, 0.6, 1)\nground_horizon_color = Color(0.72, 0.85, 0.95, 1)\n",
        '[sub_resource type="Sky" id="sky"]\nsky_material = SubResource("sky_mat")\n',
        '[sub_resource type="Environment" id="env"]\nbackground_mode = 2\nsky = SubResource("sky")\n'
        "ambient_light_source = 3\nambient_light_energy = 0.9\ntonemap_mode = 2\nssao_enabled = true\n"
        "ssao_intensity = 1.5\nadjustment_enabled = true\nadjustment_saturation = 1.1\n",
        '[sub_resource type="Shader" id="sea_shader"]\ncode = "' + SEA_SHADER.replace("\n", "\\n") + '"\n',
        '[sub_resource type="ShaderMaterial" id="sea_mat"]\nshader = SubResource("sea_shader")\n',
        '[sub_resource type="PlaneMesh" id="sea_mesh"]\nmaterial = SubResource("sea_mat")\nsize = Vector2(400, 400)\n'
        "subdivide_width = 160\nsubdivide_depth = 160\n",
    ]

    s.node("CityMap", "Node3D", parent=None, props={"script": 'ExtResource("1_r")'})
    s.node("WorldEnvironment", "WorldEnvironment", props={"environment": 'SubResource("env")'})
    s.node("Sun", "DirectionalLight3D", props={
        "transform": xform(0, 30, 0, yaw=25, pitch=-55), "light_energy": "1.15", "shadow_enabled": "true",
        "directional_shadow_max_distance": "90.0"})
    # kus bakisi kamera, harita merkezinde baslar
    s.node("CameraRig", "Node3D", props={"transform": xform(0, 0, 0, yaw=45), "script": 'ExtResource("2_r")',
                                          "bounds": f"Vector2({W - 2}, {H - 2})", "zoom_max": "75.0"})
    dist, pitch = 66.0, 58.0
    s.node("Camera3D", "Camera3D", parent="CameraRig", props={
        "transform": xform(0, dist * math.sin(math.radians(pitch)), dist * math.cos(math.radians(pitch)), pitch=-pitch),
        "current": "true", "fov": "35.0", "far": "400.0"})
    s.node("Sea", "MeshInstance3D", props={"transform": xform(0, 0.03, 0), "mesh": 'SubResource("sea_mesh")'})
    for g in ("Ground", "Roads", "Nature", "Buildings", "Props"):
        s.node(g, "Node3D")
    s.node("Traffic", "Node3D", props={"script": 'ExtResource("4_r")'})  # arabalar + yayalar, oyun basinda olusur

    trees = [f"Tree_{a}_{b}_Color1" for a, bs in (("1", "AB"), ("2", "ABC"), ("3", "AB"), ("4", "AB")) for b in bs]
    rocks = [f"Rock_{a}_{b}_Color1" for a, bs in (("1", "ABCDEF"), ("2", "BCD"), ("3", "ABCDEF")) for b in bs]
    bushes = [f"Bush_{a}_{b}_Color1" for a, bs in (("1", "ABCDE"), ("2", "ABCD"), ("3", "AB"), ("4", "ABCD")) for b in bs]
    folders = {"Tree": "doga/agac", "Rock": "doga/kaya", "Bush": "doga/cali"}

    @lru_cache(None)
    def model_height(rel):
        P = np.vstack([p for p, _, _, _ in load_raw(os.path.join(ROOT, "portofolyo", "assets", "models", rel + ".gltf"))])
        return float(P[:, 1].max() - max(P[:, 1].min(), 0.0))

    def nature(name, kind, x, z, height, yaw=None):
        """height: hedef yukseklik (birim). Orman paketindeki varyantlarin boyutlari cok farkli."""
        rel = f"{folders[kind]}/{rnd.choice({'Tree': trees, 'Rock': rocks, 'Bush': bushes}[kind])}"
        s.node(name, parent="Nature", instance=f"{M}{rel}.gltf",
               props={"transform": xform(x, 0.1, z, yaw=rnd.uniform(0, 360) if yaw is None else yaw,
                                         scale=height / model_height(rel))})

    def ground(name, model, x, z, yaw=0):
        folder = "yol_zemin"
        s.node(name, parent="Ground", instance=f"{M}{folder}/{model}.gltf", props={"transform": xform(x, 0, z, yaw=yaw)})

    def prop(name, path, x, y, z, yaw=0, scale=1.0):
        s.node(name, parent="Props", instance=f"{M}{path}.gltf", props={"transform": xform(x, y, z, yaw=yaw, scale=scale)})

    shop_i = 0
    for r in range(H):
        for c in range(W):
            ch = PLAN[r][c]
            x, z = pos(c, r)
            n = f"{c}_{r}"
            if ch == "=":
                open_sides = {d for d, (dc, dr) in SIDES.items() if at(c + dc, r + dr) == "="}
                model, yaw = pick_tile(ROAD_TILES, open_sides)
                if model == "road_straight" and (c, r) in ((11, 7), (11, 11), (9, 9), (13, 9)):
                    model = "road_straight_crossing"
                s.node(f"road_{n}", parent="Roads", instance=f"{M}yol_zemin/{model}.gltf", props={"transform": xform(x, 0, z, yaw=yaw)})
            elif ch == "w":
                open_sides = {d for d, (dc, dr) in SIDES.items() if at(c + dc, r + dr) in ("w", None)}
                if len(open_sides) > 2:
                    open_sides = {d for d in open_sides if at(c + SIDES[d][0], r + SIDES[d][1]) == "w"} or {"+z", "-z"}
                model, yaw = pick_tile(RIVER_TILES, open_sides)
                ground(f"river_{n}", model, x, z, yaw)
            elif ch == ".":
                ground(f"sand_{n}", "tile_sand", x, z)
                if rnd.random() < 0.08:
                    nature(f"rock_{n}", "Rock", x + rnd.uniform(-0.5, 0.5), z + rnd.uniform(-0.5, 0.5), rnd.uniform(0.2, 0.35))
            elif ch in "gTrpbA":
                ground(f"grass_{n}", "tile_grass", x, z)
                if ch == "T":
                    for i in range(rnd.randint(4, 6)):
                        nature(f"tree_{n}_{i}", "Tree", x + rnd.uniform(-0.75, 0.75), z + rnd.uniform(-0.75, 0.75), rnd.uniform(1.0, 1.7))
                elif ch == "r":
                    for i in range(rnd.randint(1, 3)):
                        nature(f"rock_{n}_{i}", "Rock", x + rnd.uniform(-0.6, 0.6), z + rnd.uniform(-0.6, 0.6), rnd.uniform(0.25, 0.45))
                    nature(f"tree_{n}", "Tree", x + rnd.uniform(-0.5, 0.5), z + rnd.uniform(-0.5, 0.5), 1.1)
                elif ch == "p":
                    for i, (dx, dz) in enumerate(((-0.55, -0.55), (0.55, 0.5))):
                        nature(f"tree_{n}_{i}", "Tree", x + dx, z + dz, rnd.uniform(0.9, 1.2))
                    nature(f"bush_{n}", "Bush", x + 0.5, z - 0.5, 0.3)
                    prop(f"bench_{n}", "sokak/bench", x - 0.3, 0.1, z + 0.45, yaw=0)
                elif ch == "g" and rnd.random() < 0.4:
                    nature(f"bush_{n}", "Bush", x + rnd.uniform(-0.6, 0.6), z + rnd.uniform(-0.6, 0.6), rnd.uniform(0.25, 0.35))
                elif ch == "b":
                    prop(f"billboard_{n}", "medya_kampanya/billboard_campaign", x, 0.1, z, yaw=YAW[facing(c, r)])
                elif ch == "A":
                    prop(f"assembly_marker_{n}", "afet/assembly_area_marker", x, 0.1, z)
                    prop(f"assembly_sign_{n}", "afet/sign_assembly_area", x + 0.85, 0.1, z + 0.85, yaw=45)
            elif ch == "P":
                ground(f"plaza_{n}", "tile_plaza", x, z)
            elif ch == "C":
                prop(f"construction_{n}", "binalar/insaat/building_construction", x, 0, z, yaw=YAW[facing(c, r)])
                prop(f"crane_{n}", "binalar/insaat/tower_crane", x - 0.7, 0.1, z - 0.7, yaw=90, scale=0.9)
            elif ch in BUILDINGS or ch == "c":
                if ch == "c":
                    model = SHOPS[shop_i % len(SHOPS)]
                    shop_i += 1
                else:
                    model = BUILDINGS[ch]
                s.node(f"{model}_{n}", "Node3D", parent="Buildings", props={
                    "transform": xform(x, 0, z, yaw=YAW[facing(c, r)]),
                    "script": 'ExtResource("3_r")', "model_name": f'"{model}"'})
            else:
                raise ValueError(f"bilinmeyen plan karakteri {ch!r} ({c},{r})")

    # meydan suslemeleri: lambalar, gazete bayii, siren
    for (c, r) in ((10, 8), (12, 8), (10, 10), (12, 10)):
        x, z = pos(c, r)
        prop(f"lamp_{c}_{r}", "sokak/streetlight", x + (0.85 if c == 10 else -0.85), 0.1, z, yaw=0 if c == 10 else 180)
    x, z = pos(10, 9)
    prop("newspaper_kiosk", "medya_kampanya/newspaper_kiosk", x, 0.1, z + 0.5, yaw=270)
    x, z = pos(12, 9)
    prop("siren_pole", "afet/siren_pole", x + 0.6, 0.1, z - 0.6)

    s.node("HUD", "CanvasLayer")
    s.node("Help", "Label", parent="HUD", props={
        "offset_left": "14.0", "offset_top": "10.0",
        "theme_override_colors/font_outline_color": "Color(0, 0, 0, 1)",
        "theme_override_constants/outline_size": "6",
        "text": '"WASD / sag tik: kaydir   Tekerlek: zoom   Q/E: dondur\\n'
                '1: deprem testi   2: tum binalari onar   3: rastgele evi gelistir"'})
    s.write(OUT)
    print(OUT, len(s.nodes), "node,", len(s.ext), "kaynak")


if __name__ == "__main__":
    main()
