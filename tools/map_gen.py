"""Sehir haritasini ASCII plandan Godot sahnesine cevirir -> portofolyo/scenes/city_map.tscn

  python tools/map_gen.py

Harita: batida daglar (nehir buradan dogar), kuzeyde orman ve piknik alanlari,
dogu ve guneyde kumsal + deniz. Nehir sehrin kuzeyinden gecip denize dokulur.

Plan karakterleri (her karakter 2x2'lik bir karo):
  ~  deniz (karo yok)   .  kumsal       M  dag          m  dag eteği (tepeler)
  R  kayalik kiyi       L  deniz feneri J  iskele (doguya uzanir)   U  plaj semsiyesi
  =  yol (yonu komsulara gore otomatik)  B  kopru (yol nehrin ustunden)
  w  nehir              g  cim          T  orman        Q  piknik / mangal alani
  p  park               P  meydan       A  toplanma alani
  b  kampanya panosu    C  insaat alani (kule vincli)
  Binalar (Building yuvasi: normal/hasarli/yikik + animasyon):
  0 gecekondu  1 ev  2 apartman  3 gelismis bina  k kacak katli ev  K kacak katli apartman
  R guclendirilmis apartman   c dukkan binasi (KayKit A-H)
  H belediye  h hastane  f itfaiye  s okul  a AFAD  n gazete/TV
Binalar on yuzlerini otomatik olarak komsu yola cevirir.
Oyun mantiginin ihtiyac duydugu bolgeler (orman, piknik, toplanma, sel bolgesi...)
sahnedeki MapInfo dugumune yazilir.
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
    "~~~~~~R~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~RRRRmR.......~~~~~~......L~~~~~~",
    "~RRRMMmmTT.TTTT......TTTTTTT~~~~~~",
    "~RMMMMMMTTTTTTTTTTTTTTTTTTT.~~~~~~",
    "~RMMMMMMTTTTTTTTTTTTTTTTTTT.~~~~~~",
    "~RMMMMmmTTTTTTTTTQTTTTQTTTT.~~~~~~",
    "~~RMMMmmTQTTTTTTQ=QTTTTTTTT.~~~~~~",
    "~~RMMMmmTTTTQTTTT=TTTTTTQTT.~~~~~~",
    "~RMMMMmmgTggTggTg=TggTggTgg.~~~~~~",
    "~RMMMwwwwwwwwwwwwBwwwwwwwwwww~~~~~",
    "RMMMMMmmg00k01001=01000k01g..~~~~~",
    "RMMMMMmm0=================1..~~~~~",
    "~RMMMMmm1=1A1=gsg=cnc=323=c..~~~~~",
    "~RMMMMmm0=2p1=ppp=cPc=2p3=1U.~~~~~",
    "~~RMMMmm1=12k=1b2=ccc=3R2=c.~~~~~~",
    "~~RMMMmm0=================c.~~~~~~",
    "~~RMMMmm0=1k2=PPP=hga=ccc=1.~~~~~~",
    "~~RMMMmm1=2p1=PHP=gPf=cPc=cJ.~~~~~",
    "~RMMMMmm0=121=PPP=cbc=ccc=1..~~~~~",
    "~RMMMMmm0=================c..~~~~~",
    "~~RMMMmm1=0A1=TpT=2C3=2A1=c..~~~~~",
    "~~RMMMmm0=0p1=pAp=2p2=1pK=1U~~~~~~",
    "~~RMMMmm0=100=TpT=132=121=c.~~~~~~",
    "~~RMMMmm0=================1.~~~~~~",
    "~~RMMMmmgg12g21g2g12g21g2g..~~~~~~",
    "~RMMMMMM....................~~~~~~",
    "~RRMMMMM...U...U....U...U...~~~~~~",
    "RMM~~RRR~~~~~..~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]

BUILDINGS = {
    "0": "house_lv0_gecekondu", "1": "house_lv1", "2": "house_lv2", "3": "house_lv3",
    "k": "house_lv1_kacak", "K": "house_lv2_kacak", "R": "house_lv2_reinforced",
    "H": "building_townhall_lv1", "h": "building_hospital", "f": "building_firestation",
    "s": "building_school", "a": "building_afad", "n": "building_news",
}
SHOPS = [f"building_{c}" for c in "ABCDEFGH"]
ROADLIKE = "=B"

# Arabalar, yayalar ve hayvanlar sahnede durmaz; oyun basinda scriptler olusturur.

M = "res://assets/models/"
SIDES = {"+x": (1, 0), "-x": (-1, 0), "+z": (0, 1), "-z": (0, -1)}
ROT90 = {"+z": "+x", "+x": "-z", "-z": "-x", "-x": "+z"}  # Godot'ta +90 derece Y donusu
YAW = {"+z": 0, "+x": 90, "-z": 180, "-x": 270}



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


def packed(points):
    return "PackedVector2Array(" + ", ".join(f"{v:.3f}" for p in points for v in p) + ")"


SEA_SHADER = """shader_type spatial;
uniform vec3 deep = vec3(0.02, 0.17, 0.42);
uniform vec3 mid = vec3(0.05, 0.36, 0.62);
uniform vec3 shallow = vec3(0.16, 0.66, 0.72);
uniform float light = 1.0;
uniform sampler2D land_mask : filter_linear, repeat_disable;
uniform vec2 map_min;
uniform vec2 map_size;
varying vec3 wpos;
varying float wave;
float land(vec2 p) {
\tvec2 uv = (p - map_min) / map_size;
\tif (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.0; }
\treturn texture(land_mask, uv).r;
}
void vertex() {
\twpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
\tfloat calm = 1.0 - land(wpos.xz) * 0.8;
\twave = sin(wpos.x * 0.45 + TIME * 1.1) * 0.5 + cos(wpos.z * 0.38 + TIME * 0.8) * 0.5;
\twave += sin((wpos.x + wpos.z) * 1.3 + TIME * 2.1) * 0.25;
\tVERTEX.y += wave * 0.045 * calm;
}
void fragment() {
\tfloat m = land(wpos.xz);
\tvec3 col = mix(deep, mid, smoothstep(0.0, 0.18, m));
\tcol = mix(col, shallow, smoothstep(0.12, 0.4, m));
\tfloat ripple = sin(m * 60.0 - TIME * 2.2 + sin(wpos.x * 0.7) * 1.5) * 0.5 + 0.5;
\tfloat foam = smoothstep(0.22, 0.36, m) * (1.0 - smoothstep(0.42, 0.5, m)) * smoothstep(0.6, 0.95, ripple);
\tfoam += smoothstep(0.4, 0.47, m);
\tcol = mix(col, vec3(0.95, 0.98, 1.0), clamp(foam, 0.0, 1.0) * 0.8);
\tcol += wave * 0.035;
\tALBEDO = col * light;
\tROUGHNESS = 0.2;
\tSPECULAR = 0.45;
}"""

DISTRICTS = [  # (ad, plan sutun, plan satir) -- binalar en yakin mahalle merkezine baglanir
    ("Dere Mahallesi", 17, 10),
    ("Dağ Eteği", 8, 18),
    ("Kuzey Mahallesi", 17, 13),
    ("Merkez", 17, 18),
    ("Sahil", 27, 17),
    ("Güney Mahallesi", 17, 23),
]
GRASS = ["tile_grass", "tile_grass_b", "tile_grass_c"]
LAND_CHARS = "".join(sorted(set("=BwgTQpPAbCMmR.UJL0123kKRcHhfsan")))


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

    def near(c, r, chars, dist=1):
        for dr in range(-dist, dist + 1):
            for dc in range(-dist, dist + 1):
                if 0 < abs(dr) + abs(dc) <= dist:
                    v = at(c + dc, r + dr)
                    if v is not None and v in chars:
                        return True
        return False

    def is_land(c, r):
        v = at(c, r)
        return v is not None and v != "~"

    info = {k: [] for k in ("forest_tiles", "picnic_spots", "assembly_points", "park_tiles", "plaza_tiles",
                            "flood_tiles", "river_tiles", "beach_tiles", "mountain_tiles", "sea_points")}

    # ---- kara maskesi (deniz shader'i: sig su + kiyi kopugu)
    from PIL import Image, ImageFilter
    px, pad = 8, 32
    mask = Image.new("L", (W * px + 2 * pad, H * px + 2 * pad), 0)
    for r in range(H):
        for c in range(W):
            if is_land(c, r):
                mask.paste(255, (pad + c * px, pad + r * px, pad + (c + 1) * px, pad + (r + 1) * px))
    mask = mask.filter(ImageFilter.GaussianBlur(9))
    tex_dir = os.path.join(ROOT, "portofolyo", "assets", "textures")
    os.makedirs(tex_dir, exist_ok=True)
    mask.save(os.path.join(tex_dir, "land_mask.png"))
    x0, z0 = pos(0, 0)
    tile_px = 2.0 / px  # dunya birimi / piksel
    map_min = (x0 - 1.0 - pad * tile_px, z0 - 1.0 - pad * tile_px)
    map_size = (mask.width * tile_px, mask.height * tile_px)

    s = Scene()
    for scr in ("city_map", "camera_rig", "building", "traffic", "map_info", "wildlife"):
        s.res(f"res://scripts/{scr}.gd", "Script")
    mask_id = s.res("res://assets/textures/land_mask.png", "Texture2D")
    s.subs += [
        '[sub_resource type="ProceduralSkyMaterial" id="sky_mat"]\n'
        "sky_top_color = Color(0.32, 0.56, 0.86, 1)\nsky_horizon_color = Color(0.74, 0.86, 0.96, 1)\n"
        "ground_bottom_color = Color(0.1, 0.3, 0.5, 1)\nground_horizon_color = Color(0.74, 0.86, 0.96, 1)\n",
        '[sub_resource type="Sky" id="sky"]\nsky_material = SubResource("sky_mat")\n',
        '[sub_resource type="Environment" id="env"]\nbackground_mode = 2\nsky = SubResource("sky")\n'
        "ambient_light_source = 3\nambient_light_energy = 0.9\ntonemap_mode = 2\ntonemap_white = 1.2\n"
        "ssao_enabled = true\nssao_intensity = 1.6\nglow_enabled = true\nglow_intensity = 0.45\nglow_bloom = 0.0\nglow_hdr_threshold = 1.2\n"
        "fog_enabled = true\nfog_light_color = Color(0.72, 0.84, 0.95, 1)\nfog_density = 0.0012\nfog_sky_affect = 0.25\n"
        "adjustment_enabled = true\nadjustment_saturation = 1.15\n",
        '[sub_resource type="Shader" id="sea_shader"]\ncode = "' + SEA_SHADER.replace("\n", "\\n") + '"\n',
        '[sub_resource type="ShaderMaterial" id="sea_mat"]\nshader = SubResource("sea_shader")\n'
        f'shader_parameter/land_mask = ExtResource("{mask_id}")\n'
        f"shader_parameter/map_min = Vector2({map_min[0]:.3f}, {map_min[1]:.3f})\n"
        f"shader_parameter/map_size = Vector2({map_size[0]:.3f}, {map_size[1]:.3f})\n",
        '[sub_resource type="PlaneMesh" id="sea_mesh"]\nmaterial = SubResource("sea_mat")\nsize = Vector2(600, 600)\n'
        "subdivide_width = 220\nsubdivide_depth = 220\n",
    ]

    s.node("CityMap", "Node3D", parent=None, props={"script": 'ExtResource("1_r")'})
    s.node("WorldEnvironment", "WorldEnvironment", props={"environment": 'SubResource("env")'})
    s.node("Sun", "DirectionalLight3D", props={
        "transform": xform(0, 30, 0, yaw=25, pitch=-55), "light_energy": "1.15", "shadow_enabled": "true",
        "directional_shadow_max_distance": "120.0"})
    hc, hr = next((c, r) for r in range(H) for c in range(W) if PLAN[r][c] == "H")
    cx, cz = pos(hc, hr)
    s.node("CameraRig", "Node3D", props={"transform": xform(cx, 0, cz - 2, yaw=45), "script": 'ExtResource("2_r")',
                                          "bounds": f"Vector2({W}, {H})", "zoom_max": "105.0"})
    dist, pitch = 62.0, 58.0
    s.node("Camera3D", "Camera3D", parent="CameraRig", props={
        "transform": xform(0, dist * math.sin(math.radians(pitch)), dist * math.cos(math.radians(pitch)), pitch=-pitch),
        "current": "true", "fov": "35.0", "far": "600.0"})
    s.node("Sea", "MeshInstance3D", props={"transform": xform(0, 0.03, 0), "mesh": 'SubResource("sea_mesh")'})
    for g in ("Ground", "Roads", "Nature", "Buildings", "Props", "Effects"):
        s.node(g, "Node3D")
    s.node("Traffic", "Node3D", props={"script": 'ExtResource("4_r")'})  # arabalar + yayalar, oyun basinda olusur
    s.node("Wildlife", "Node3D", props={"script": 'ExtResource("6_r")'})  # martilar, kuslar, geyikler, tekneler

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
        s.node(name, parent="Ground", instance=f"{M}yol_zemin/{model}.gltf", props={"transform": xform(x, 0, z, yaw=yaw)})

    def prop(name, path, x, y, z, yaw=0, scale=1.0, parent="Props"):
        s.node(name, parent=parent, instance=f"{M}{path}.gltf", props={"transform": xform(x, y, z, yaw=yaw, scale=scale)})

    shop_i = 0
    lamp_i = 0
    for r in range(H):
        for c in range(W):
            ch = PLAN[r][c]
            x, z = pos(c, r)
            n = f"{c}_{r}"
            # dere yatagi: nehrin hemen kuzey/guneyindeki kara karolari
            if ch not in "~=wBMmR." and (at(c, r - 1) in ("w", "B") or at(c, r + 1) in ("w", "B")):
                info["flood_tiles"].append((x, z))
            if ch == "~":
                if not near(c, r, LAND_CHARS, 2):
                    info["sea_points"].append((x, z))
            elif ch in ROADLIKE:
                open_sides = {d for d, (dc, dr) in SIDES.items() if at(c + dc, r + dr) in ROADLIKE}
                if ch == "B":
                    s.node(f"road_bridge_{n}", parent="Roads", instance=f"{M}yol_zemin/road_bridge.gltf",
                           props={"transform": xform(x, 0, z)})
                    info["river_tiles"].append((x, z))
                    continue
                model, yaw = pick_tile(ROAD_TILES, open_sides)
                if model == "road_straight" and near(c, r, "P"):
                    model = "road_straight_crossing"
                s.node(f"road_{n}", parent="Roads", instance=f"{M}yol_zemin/{model}.gltf", props={"transform": xform(x, 0, z, yaw=yaw)})
                # sokak lambalari: duz yollarin kaldiriminda, aralikli
                if model == "road_straight" and (c + r) % 3 == 0:
                    side = 1 if lamp_i % 2 == 0 else -1
                    lamp_i += 1
                    if yaw == 0:  # yol Z boyunca, kaldirim X kenarinda
                        prop(f"lamp_{n}", "sokak/streetlight", x + side * 0.93, 0.1, z, yaw=0 if side > 0 else 180)
                    else:
                        prop(f"lamp_{n}", "sokak/streetlight", x, 0.1, z + side * 0.93, yaw=270 if side > 0 else 90)
            elif ch == "w":
                open_sides = {d for d, (dc, dr) in SIDES.items() if at(c + dc, r + dr) in ("w", "B", "~", None)}
                if len(open_sides) > 2:
                    open_sides = {d for d in open_sides if at(c + SIDES[d][0], r + SIDES[d][1]) in "wB"} or {"+x", "-x"}
                if len(open_sides) == 1:
                    open_sides = {"+x", "-x"}
                model, yaw = pick_tile(RIVER_TILES, open_sides)
                ground(f"river_{n}", model, x, z, yaw)
                if not (at(c, r - 1) in ("M", "m", "R") and at(c, r + 1) in ("M", "m", "R")):
                    info["river_tiles"].append((x, z))
            elif ch in ".UJL":
                ground(f"sand_{n}", "tile_sand", x, z)
                info["beach_tiles"].append((x, z))
                if ch == "U":
                    for i in range(2):
                        prop(f"umbrella{i}_{n}", "sokak/beach_umbrella", x + rnd.uniform(-0.6, 0.6), 0.1, z + rnd.uniform(-0.6, 0.6),
                             yaw=rnd.uniform(0, 360), scale=1.4)
                elif ch == "J":
                    prop(f"pier_{n}", "sokak/pier", x + 0.6, 0.0, z)
                elif ch == "L":
                    prop(f"lighthouse_{n}", "sokak/lighthouse", x, 0.05, z, yaw=200, scale=1.1)
                elif rnd.random() < 0.06:
                    nature(f"rock_{n}", "Rock", x + rnd.uniform(-0.5, 0.5), z + rnd.uniform(-0.5, 0.5), rnd.uniform(0.2, 0.35))
            elif ch == "R":
                ground(f"sand_{n}", "tile_sand", x, z)
                for i in range(rnd.randint(2, 4)):
                    nature(f"rock_{n}_{i}", "Rock", x + rnd.uniform(-0.7, 0.7), z + rnd.uniform(-0.7, 0.7), rnd.uniform(0.3, 0.7))
            elif ch in "Mm":
                ground(f"mountain_{n}", "tile_mountain", x, z)
                info["mountain_tiles"].append((x, z))
                if ch == "M":
                    inner = sum(1 for dc, dr in SIDES.values() if at(c + dc, r + dr) == "M")
                    big = inner == 4 and (c + r) % 3 == 0
                    kind = "mountain_large" if big else rnd.choice(["mountain_medium", "mountain_medium", "mountain_small"])
                    prop(f"peak_{n}", f"doga/dag/{kind}", x + rnd.uniform(-0.4, 0.4), 0.05, z + rnd.uniform(-0.4, 0.4),
                         yaw=rnd.uniform(0, 360), scale=rnd.uniform(0.85, 1.15), parent="Nature")
                else:
                    if rnd.random() < 0.5:
                        prop(f"hill_{n}", "doga/dag/hill", x, 0.05, z, yaw=rnd.uniform(0, 360), scale=rnd.uniform(0.7, 1.0),
                             parent="Nature")
                    for i in range(rnd.randint(1, 3)):
                        nature(f"tree_{n}_{i}", "Tree", x + rnd.uniform(-0.7, 0.7), z + rnd.uniform(-0.7, 0.7), rnd.uniform(0.9, 1.4))
                    if rnd.random() < 0.5:
                        nature(f"rock_{n}", "Rock", x + rnd.uniform(-0.6, 0.6), z + rnd.uniform(-0.6, 0.6), rnd.uniform(0.25, 0.4))
            elif ch in "TQ":
                ground(f"forest_{n}", "tile_grass", x, z)
                info["forest_tiles"].append((x, z))
                if ch == "T":
                    for i in range(rnd.randint(4, 6)):
                        nature(f"tree_{n}_{i}", "Tree", x + rnd.uniform(-0.75, 0.75), z + rnd.uniform(-0.75, 0.75), rnd.uniform(1.0, 1.7))
                else:  # piknik alani: mangal + masa + ortu, kenarlarda agac
                    info["picnic_spots"].append((x, z))
                    prop(f"grill_{n}", "doga/piknik/bbq_grill", x - 0.35, 0.1, z + 0.1, yaw=rnd.uniform(0, 360))
                    prop(f"table_{n}", "doga/piknik/picnic_table", x + 0.35, 0.1, z - 0.2, yaw=rnd.uniform(-20, 20))
                    prop(f"blanket_{n}", "doga/piknik/picnic_blanket", x + 0.1, 0.1, z + 0.5, yaw=rnd.uniform(0, 90))
                    for i, (dx, dz) in enumerate(((-0.75, -0.7), (0.75, 0.7), (-0.8, 0.75))):
                        nature(f"tree_{n}_{i}", "Tree", x + dx, z + dz, rnd.uniform(1.1, 1.5))
            elif ch in "gpbA":
                ground(f"grass_{n}", rnd.choice(GRASS), x, z)
                if ch == "p":
                    info["park_tiles"].append((x, z))
                    for i, (dx, dz) in enumerate(((-0.55, -0.55), (0.55, 0.5))):
                        nature(f"tree_{n}_{i}", "Tree", x + dx, z + dz, rnd.uniform(0.9, 1.2))
                    nature(f"bush_{n}", "Bush", x + 0.5, z - 0.5, 0.3)
                    prop(f"bench_{n}", "sokak/bench", x - 0.3, 0.1, z + 0.45, yaw=0)
                elif ch == "g" and rnd.random() < 0.5:
                    nature(f"bush_{n}", "Bush", x + rnd.uniform(-0.6, 0.6), z + rnd.uniform(-0.6, 0.6), rnd.uniform(0.25, 0.35))
                    if rnd.random() < 0.4:
                        nature(f"tree_{n}", "Tree", x + rnd.uniform(-0.6, 0.6), z + rnd.uniform(-0.6, 0.6), rnd.uniform(0.8, 1.1))
                elif ch == "b":
                    prop(f"billboard_{n}", "medya_kampanya/billboard_campaign", x, 0.1, z, yaw=YAW[facing(c, r)])
                elif ch == "A":
                    info["assembly_points"].append((x, z))
                    prop(f"assembly_marker_{n}", "afet/assembly_area_marker", x, 0.1, z)
                    prop(f"assembly_sign_{n}", "afet/sign_assembly_area", x + 0.85, 0.1, z + 0.85, yaw=45)
            elif ch == "P":
                ground(f"plaza_{n}", "tile_plaza", x, z)
                info["plaza_tiles"].append((x, z))
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

    # meydan: belediyenin cevresindeki meydan karolarina lamba, cesme, bayi, siren
    for dc, dr in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        x, z = pos(hc + dc, hr + dr)
        prop(f"lamp_plaza_{dc}_{dr}", "sokak/streetlight", x - dc * 0.85, 0.1, z, yaw=0 if dc < 0 else 180)
    x, z = pos(hc, hr + 1)
    prop("fountain", "sokak/fountain", x, 0.1, z + 0.1)
    x, z = pos(hc - 1, hr)
    prop("newspaper_kiosk", "medya_kampanya/newspaper_kiosk", x, 0.1, z + 0.5, yaw=270)
    x, z = pos(hc + 1, hr)
    prop("siren_pole", "afet/siren_pole", x + 0.6, 0.1, z - 0.6)
    for dc in (-1, 1):
        x, z = pos(hc + dc, hr - 1)
        nature(f"tree_plaza_{dc}", "Tree", x, z, 1.1)

    districts = [(name, pos(c, r)) for name, c, r in DISTRICTS]
    s.node("MapInfo", "Node", props={
        "script": 'ExtResource("5_r")', **{k: packed(v) for k, v in info.items()},
        "district_names": "PackedStringArray(" + ", ".join(f'"{d[0]}"' for d in districts) + ")",
        "district_centers": packed([d[1] for d in districts])})
    s.write(OUT)
    print(OUT, len(s.nodes), "node,", len(s.ext), "kaynak,", {k: len(v) for k, v in info.items()})


if __name__ == "__main__":
    main()
