"""Yaya modelleri. Kollar/bacaklar ayri node (omuz/kalca pivotlu) -> Godot'ta yurume animasyonu.
Boy ~0.34 birim (araba 0.94 uzunlukta). On +Z, zemin y=0."""
from kitgen import Model, blob, cbox

HIP, SHOULDER = 0.12, 0.235

# (ad, gomlek, pantolon, ten, sac, ekstra)
PEOPLE = [
    ("person_a", "red", "blue", "tan", "brown", None),
    ("person_b", "teal", "charcoal", "cream", "black", None),
    ("person_c", "sun", "blue", "brown", "black", None),
    ("person_d", "white", "slate", "tan", "ochre", None),
    ("person_e", "salmon", "darkgrey", "cream", "brown", "long_hair"),
    ("person_f", "green", "brown", "terracotta", "black", None),
    ("person_g", "blue", "charcoal", "tan", "darkgrey", "long_hair"),
    ("person_h", "lime", "slate", "brown", "brown", "cap"),
    ("person_afad", "orange", "blue", "tan", "black", "helmet"),
    ("person_doctor", "white", "white", "cream", "brown", None),
]


def limb(name, color, length, width, skin=None):
    m = Model(name)
    if skin:  # kol: ust kisim gomlek, el ten rengi
        m.add(cbox(0, -length * 0.4, 0, width, length * 0.8, width), color, grad=(0.1, 0.6))
        m.add(cbox(0, -length * 0.9, 0, width * 0.9, length * 0.2, width * 0.9), skin, grad=(0.1, 0.5))
    else:
        m.add(cbox(0, -length / 2, 0, width, length, width * 1.1), color, grad=(0.1, 0.7))
        m.add(cbox(0, -length + 0.008, 0.008, width * 1.05, 0.016, width * 1.5), "charcoal")  # ayakkabi
    return m


def person(name, shirt, pants, skin, hair, extra):
    m = Model(name)
    m.add(cbox(0, HIP + 0.005, 0, 0.085, 0.03, 0.05), pants, grad=(0.1, 0.6))
    m.add(cbox(0, (HIP + SHOULDER) / 2 + 0.01, 0, 0.1, SHOULDER - HIP + 0.01, 0.06, bevel=0.012), shirt, grad=(0.05, 0.7))
    if name == "person_afad":  # reflektor seridi
        m.add(cbox(0, 0.19, 0, 0.104, 0.012, 0.064), "white", grad=(0.0, 0.2))
    if name == "person_doctor":
        m.add(cbox(0, 0.16, 0.031, 0.02, 0.08, 0.004), "skyblue", grad=(0.1, 0.5))
    m.add(cbox(0, SHOULDER + 0.012, 0, 0.03, 0.02, 0.03), skin, grad=(0.1, 0.5))
    m.add(blob(0, SHOULDER + 0.06, 0, 0.042, sy=1.05, jitter=0.03, seed=1, smooth=True), skin, grad=(0.0, 0.6))
    m.add(blob(0, SHOULDER + 0.083, -0.006, 0.042, sy=0.6, jitter=0.03, seed=2), hair, grad=(0.1, 0.6))
    if extra == "long_hair":
        m.add(cbox(0, SHOULDER + 0.035, -0.025, 0.07, 0.07, 0.03), hair, grad=(0.1, 0.6))
    elif extra == "cap":
        m.add(cbox(0, SHOULDER + 0.1, 0.0, 0.085, 0.025, 0.08), "red", grad=(0.1, 0.5))
        m.add(cbox(0, SHOULDER + 0.09, 0.05, 0.07, 0.008, 0.04), "red", grad=(0.1, 0.5))
    elif extra == "helmet":
        m.add(blob(0, SHOULDER + 0.09, 0, 0.05, sy=0.7, jitter=0.0, seed=3, smooth=True), "white", grad=(0.0, 0.3))
    m.add(cbox(0.016, SHOULDER + 0.065, 0.04, 0.008, 0.008, 0.004), "black", grad=(0.3, 0.6))  # gozler
    m.add(cbox(-0.016, SHOULDER + 0.065, 0.04, 0.008, 0.008, 0.004), "black", grad=(0.3, 0.6))
    for side, sx in (("l", 1), ("r", -1)):
        m.child(limb(f"{name}_leg_{side}", pants, HIP, 0.038), (sx * 0.024, HIP, 0))
        m.child(limb(f"{name}_arm_{side}", shirt, 0.11, 0.028, skin=skin), (sx * 0.066, SHOULDER - 0.01, 0))
    return m


def _mk(args):
    f = lambda: person(*args)
    f.__name__ = args[0]
    return f


MODELS = [_mk(p) for p in PEOPLE]
