"""Araclar. On yon +Z, zemin GROUND (KayKit arabalariyla ayni yerlesim)."""
from kitgen import GLASS, Model, cbox, cyl, rot
from parts import GROUND, add_wheels, car_lights, lightbar

G = GROUND


def van(name, body, stripe, stripe2=None, length=1.0, roof_h=0.44):
    """Kabinli kutu govde (ambulans / TV araci)."""
    m = Model(name)
    zf, zr = length / 2, -length / 2
    zc = zf - 0.26  # kabin/kutu siniri
    m.add(cbox(0, G + 0.075, 0, 0.38, 0.05, length - 0.08), "charcoal")
    m.add(cbox(0, (G + 0.09 + roof_h) / 2, (zr + zc) / 2, 0.42, roof_h - G - 0.09, zc - zr, bevel=0.03), body)
    m.add([(sx * w, y, z) for sx in (1, -1) for (w, y, z) in (
        (0.21, G + 0.09, zc), (0.21, G + 0.09, zf), (0.21, 0.18, zf),
        (0.19, 0.33, zf - 0.13), (0.19, 0.33, zc))], body)
    m.add([(sx * 0.165, y, z) for sx in (1, -1) for (y, z) in (
        (0.20, zf - 0.013), (0.315, zf - 0.12), (0.20, zf - 0.003), (0.315, zf - 0.11))], None, uv=GLASS)
    for sx in (1, -1):
        m.add(cbox(sx * 0.2, 0.25, zc + 0.06, 0.02, 0.10, 0.09), None, uv=GLASS)
        m.add(cbox(sx * 0.075, 0.33, zr + 0.012, 0.11, 0.11, 0.02), None, uv=GLASS)
        m.add(cbox(sx * 0.211, 0.135, 0.0, 0.006, 0.045, length - 0.02), stripe, grad=(0.2, 0.5))
        if stripe2:
            m.add(cbox(sx * 0.211, 0.10, (zr + zc) / 2, 0.006, 0.02, zc - zr - 0.02), stripe2, grad=(0.2, 0.5))
    m.add(cbox(0, 0.135, zr - 0.001, 0.40, 0.045, 0.006), stripe, grad=(0.2, 0.5))
    m.add(cbox(0, 0.045, zf + 0.005, 0.40, 0.06, 0.04, bevel=0.01), "darkgrey")
    m.add(cbox(0, 0.045, zr - 0.005, 0.40, 0.06, 0.04, bevel=0.01), "darkgrey")
    car_lights(m, 0.21, 0.12, zf + 0.002, zr - 0.002)
    add_wheels(m, 0.18, [zf - 0.21, zr + 0.22])
    return m


def ambulance():
    m = van("car_ambulance", "white", "red")
    for sx in (1, -1):
        m.add(cbox(sx * 0.212, 0.30, -0.13, 0.006, 0.15, 0.045), "red", grad=(0.2, 0.5))
        m.add(cbox(sx * 0.212, 0.30, -0.13, 0.006, 0.045, 0.15), "red", grad=(0.2, 0.5))
        m.add(cbox(sx * 0.17, 0.452, -0.47, 0.05, 0.03, 0.03), "red", grad=(0.0, 0.4))
    lightbar(m, 0, 0.34, 0.30, 0.28)
    return m


def tv_van():
    m = van("car_tv_van", "white", "blue", stripe2="sun")
    # catida uydu canagi + direk
    m.add(cbox(0, 0.455, -0.25, 0.12, 0.03, 0.12), "darkgrey")
    m.add(cyl(0.012, 0.012, 0.47, 0.56, n=6, center=(0, 0, -0.25)), "lightgrey")
    dish = cyl(0.11, 0.07, 0.0, 0.035, n=12) + [(0, -0.015, 0)]
    m.add([(p[0], p[1] + 0.58, p[2] - 0.25) for p in rot(dish, rx=-35)], "white", grad=(0.0, 0.4))
    m.add(cyl(0.008, 0.008, 0.56, 0.68, n=5, center=(0.0, 0, -0.19)), "darkgrey")
    m.add(cyl(0.012, 0.004, 0.42, 0.62, n=5, center=(0.12, 0, -0.42)), "lightgrey")
    lightbar(m, 0, 0.34, 0.30, 0.2, colors=("sun", "sun"))
    return m


def fire_truck():
    m = Model("car_firetruck")
    L, zf, zr = 1.36, 0.68, -0.68
    zc = zf - 0.32
    m.add(cbox(0, G + 0.09, 0, 0.40, 0.06, L - 0.08), "charcoal")
    # kabin (hafif egik on cam)
    m.add([(sx * w, y, z) for sx in (1, -1) for (w, y, z) in (
        (0.22, G + 0.11, zc), (0.22, G + 0.11, zf), (0.22, 0.22, zf),
        (0.20, 0.40, zf - 0.07), (0.20, 0.40, zc))], "red")
    m.add([(sx * 0.17, y, z) for sx in (1, -1) for (y, z) in (
        (0.25, zf - 0.005), (0.37, zf - 0.058), (0.25, zf + 0.005), (0.37, zf - 0.048))], None, uv=GLASS)
    for sx in (1, -1):
        m.add(cbox(sx * 0.215, 0.31, zc + 0.12, 0.02, 0.11, 0.14), None, uv=GLASS)
    # arka govde + dolap kapaklari
    m.add(cbox(0, (G + 0.11 + 0.34) / 2, (zr + zc) / 2, 0.44, 0.34 - G - 0.11, zc - zr, bevel=0.02), "red")
    n = 4
    seg = (zc - zr - 0.06) / n
    for sx in (1, -1):
        for i in range(n):
            z = zr + 0.03 + seg * (i + 0.5)
            m.add(cbox(sx * 0.222, 0.17, z, 0.006, 0.20, seg - 0.03), "lightgrey", grad=(0.0, 0.6))
        m.add(cbox(sx * 0.224, 0.06, 0, 0.006, 0.03, L - 0.04), "white", grad=(0.0, 0.3))
    # merdiven
    for sx in (1, -1):
        m.add(cbox(sx * 0.12, 0.39, -0.02, 0.025, 0.035, L - 0.24), "lightgrey", grad=(0.0, 0.5))
    for i in range(9):
        m.add(cbox(0, 0.385, -0.55 + i * 0.13, 0.22, 0.015, 0.02), "lightgrey", grad=(0.0, 0.5))
    m.add(cbox(0, 0.355, -0.55, 0.2, 0.04, 0.12), "darkgrey")
    lightbar(m, 0, 0.41, zf - 0.17, 0.3, colors=("red", "red"))
    m.add(cbox(0, 0.06, zf + 0.01, 0.42, 0.07, 0.05, bevel=0.01), "lightgrey")
    m.add(cbox(0, 0.06, zr - 0.01, 0.42, 0.07, 0.04, bevel=0.01), "darkgrey")
    car_lights(m, 0.22, 0.15, zf + 0.004, zr - 0.004, fx=0.16)
    add_wheels(m, 0.18, [zf - 0.24, zr + 0.36, zr + 0.18], r=0.085, w=0.07)
    return m


def afad_rescue():
    """AFAD arama-kurtarma arazi araci (beyaz + turuncu/lacivert serit)."""
    m = Model("car_afad_rescue")
    zf, zr = 0.48, -0.48
    m.add(cbox(0, G + 0.08, 0, 0.36, 0.05, 0.86), "charcoal")
    m.add(cbox(0, 0.11, 0, 0.42, 0.17, 0.96, bevel=0.03), "white")
    m.add([(sx * w, y, z) for sx in (1, -1) for (w, y, z) in (
        (0.2, 0.19, zr + 0.02), (0.2, 0.19, 0.16), (0.18, 0.36, 0.06), (0.18, 0.36, zr + 0.04))], "white")
    m.add([(sx * 0.16, y, z) for sx in (1, -1) for (y, z) in (
        (0.20, 0.172), (0.345, 0.075), (0.20, 0.162), (0.345, 0.065))], None, uv=GLASS)
    for sx in (1, -1):
        for z in (-0.02, -0.28):
            m.add(cbox(sx * 0.19, 0.275, z, 0.02, 0.1, 0.19), None, uv=GLASS)
        m.add(cbox(sx * 0.212, 0.12, 0, 0.006, 0.05, 0.94), "orange", grad=(0.05, 0.4))
        m.add(cbox(sx * 0.212, 0.085, 0, 0.006, 0.02, 0.94), "blue", grad=(0.4, 0.8))
    m.add(cbox(0, 0.13, zr - 0.001, 0.38, 0.06, 0.006), "orange", grad=(0.05, 0.4))
    # tavan bagaji + ekipman
    for sx in (1, -1):
        m.add(cbox(sx * 0.15, 0.375, -0.2, 0.02, 0.02, 0.5), "darkgrey")
    m.add(cbox(0, 0.4, -0.3, 0.24, 0.05, 0.22, bevel=0.01), "orange", grad=(0.05, 0.5))
    lightbar(m, 0, 0.375, 0.02, 0.26, colors=("orange", "blue"))
    m.add(cbox(0, 0.05, zf + 0.01, 0.38, 0.07, 0.04, bevel=0.01), "darkgrey")
    m.add(cbox(0, 0.05, zr - 0.01, 0.38, 0.07, 0.04, bevel=0.01), "darkgrey")
    m.add(cyl(0.06, 0.06, zr - 0.04, zr - 0.01, n=10, axis="z", center=(0, 0.2, 0)), "charcoal")
    car_lights(m, 0.21, 0.14, zf + 0.002, zr - 0.002)
    add_wheels(m, 0.18, [0.29, -0.29], r=0.08, w=0.07)
    return m


def bus():
    m = Model("car_bus")
    L, zf, zr = 1.8, 0.9, -0.9
    m.add(cbox(0, G + 0.08, 0, 0.42, 0.05, L - 0.1), "charcoal")
    m.add(cbox(0, (G + 0.1 + 0.6) / 2, 0, 0.46, 0.6 - G - 0.1, L, bevel=0.035), "white")
    for sx in (1, -1):
        m.add(cbox(sx * 0.231, 0.39, -0.02, 0.006, 0.15, L - 0.22), None, uv=GLASS)
        for i in range(7):
            m.add(cbox(sx * 0.234, 0.39, zr + 0.2 + i * 0.235, 0.006, 0.15, 0.02), "white", grad=(0.0, 0.3))
        m.add(cbox(sx * 0.231, 0.13, 0, 0.006, 0.1, L - 0.04), "teal", grad=(0.1, 0.5))
        m.add(cbox(sx * 0.232, 0.23, zf - 0.22, 0.006, 0.28, 0.14), None, uv=GLASS)
    m.add(cbox(0, 0.36, zf + 0.001, 0.4, 0.26, 0.006), None, uv=GLASS)
    m.add(cbox(0, 0.535, zf + 0.002, 0.34, 0.05, 0.006), "black", grad=(0.2, 0.5))
    m.add(cbox(0, 0.535, zf + 0.004, 0.2, 0.025, 0.006), "sun", grad=(0.0, 0.3))
    m.add(cbox(0, 0.4, zr - 0.001, 0.36, 0.16, 0.006), None, uv=GLASS)
    m.add(cbox(0, 0.13, zf + 0.002, 0.44, 0.1, 0.006), "teal", grad=(0.1, 0.5))
    m.add(cbox(0, 0.64, -0.3, 0.3, 0.07, 0.4, bevel=0.015), "lightgrey")
    m.add(cbox(0, 0.05, zf + 0.01, 0.44, 0.06, 0.03, bevel=0.01), "darkgrey")
    m.add(cbox(0, 0.05, zr - 0.01, 0.44, 0.06, 0.03, bevel=0.01), "darkgrey")
    car_lights(m, 0.23, 0.2, zf + 0.004, zr - 0.004, fx=0.17)
    add_wheels(m, 0.19, [zf - 0.28, zr + 0.32], r=0.08, w=0.07)
    return m


def dump_truck():
    m = Model("car_dumptruck")
    zf, zr = 0.62, -0.62
    zc = zf - 0.3
    m.add(cbox(0, G + 0.09, 0, 0.36, 0.06, 1.16), "charcoal")
    m.add([(sx * w, y, z) for sx in (1, -1) for (w, y, z) in (
        (0.21, G + 0.12, zc), (0.21, G + 0.12, zf), (0.21, 0.2, zf),
        (0.19, 0.4, zf - 0.06), (0.19, 0.4, zc))], "ochre", grad=(0.0, 0.5))
    m.add([(sx * 0.16, y, z) for sx in (1, -1) for (y, z) in (
        (0.24, zf - 0.005), (0.37, zf - 0.05), (0.24, zf + 0.005), (0.37, zf - 0.04))], None, uv=GLASS)
    for sx in (1, -1):
        m.add(cbox(sx * 0.205, 0.31, zc + 0.12, 0.02, 0.11, 0.14), None, uv=GLASS)
    # damper kasa (hafif yatik)
    bed = []
    for (w, y, z) in ((0.23, 0.12, zc - 0.02), (0.23, 0.12, zr), (0.24, 0.36, zc + 0.04), (0.24, 0.36, zr - 0.02)):
        bed += [(w, y, z), (-w, y, z)]
    m.add(rot(bed, rx=-4, pivot=(0, 0.12, zr)), "darkgrey")
    m.add(rot(cbox(0, 0.345, (zc + zr) / 2, 0.4, 0.04, zc - zr - 0.06), rx=-4, pivot=(0, 0.12, zr)), "brown", grad=(0.0, 0.5))
    m.add(cbox(0, 0.05, zf + 0.01, 0.4, 0.06, 0.04, bevel=0.01), "darkgrey")
    lightbar(m, 0, 0.41, zf - 0.17, 0.18, colors=("orange", "orange"))
    car_lights(m, 0.21, 0.14, zf + 0.004, zr - 0.004)
    add_wheels(m, 0.17, [zf - 0.2, zr + 0.34, zr + 0.16], r=0.085, w=0.07)
    return m


def crane_truck():
    m = Model("car_cranetruck")
    zf, zr = 0.75, -0.75
    zc = zf - 0.3
    m.add(cbox(0, G + 0.09, 0, 0.38, 0.07, 1.46), "charcoal")
    m.add(cbox(0, 0.1, (zc + zr) / 2, 0.42, 0.06, zc - zr, bevel=0.01), "ochre", grad=(0.0, 0.5))
    m.add([(sx * w, y, z) for sx in (1, -1) for (w, y, z) in (
        (0.21, G + 0.12, zc), (0.21, G + 0.12, zf), (0.21, 0.2, zf),
        (0.19, 0.38, zf - 0.06), (0.19, 0.38, zc))], "ochre", grad=(0.0, 0.5))
    m.add([(sx * 0.16, y, z) for sx in (1, -1) for (y, z) in (
        (0.24, zf - 0.005), (0.35, zf - 0.045), (0.24, zf + 0.005), (0.35, zf - 0.035))], None, uv=GLASS)
    for sx in (1, -1):
        m.add(cbox(sx * 0.205, 0.3, zc + 0.12, 0.02, 0.1, 0.14), None, uv=GLASS)
        m.add(cbox(sx * 0.24, 0.07, zr + 0.1, 0.06, 0.03, 0.06), "darkgrey")  # destek ayagi
        m.add(cbox(sx * 0.24, 0.07, zc - 0.08, 0.06, 0.03, 0.06), "darkgrey")
    # doner tabla + bom (ayri node: Godot'ta dondurulebilir)
    m.add(cyl(0.16, 0.16, 0.13, 0.17, n=10, center=(0, 0, -0.35)), "darkgrey")
    boom = Model("car_cranetruck_boom")
    boom.add(cbox(0, 0.1, 0, 0.26, 0.16, 0.3, bevel=0.015), "ochre", grad=(0.0, 0.5))
    boom.add(cbox(0.08, 0.13, 0.12, 0.08, 0.1, 0.08), None, uv=GLASS)
    arm = cbox(0, 0.22, 0.45, 0.1, 0.09, 1.0, bevel=0.01)
    boom.add(rot(arm, rx=-30, pivot=(0, 0.2, 0)), "ochre", grad=(0.0, 0.5))
    tip = rot([(0, 0.22, 0.94)], rx=-30, pivot=(0, 0.2, 0))[0]
    boom.add(cbox(tip[0], tip[1] - 0.2, tip[2], 0.008, 0.4, 0.008), "black", grad=(0.3, 0.6))
    boom.add(cbox(tip[0], tip[1] - 0.42, tip[2], 0.05, 0.05, 0.03), "darkgrey")
    m.child(boom, (0, 0.17, -0.35))
    m.add(cbox(0, 0.05, zf + 0.01, 0.4, 0.06, 0.04, bevel=0.01), "darkgrey")
    lightbar(m, 0, 0.39, zf - 0.17, 0.18, colors=("orange", "orange"))
    car_lights(m, 0.21, 0.14, zf + 0.004, zr - 0.004)
    add_wheels(m, 0.18, [zf - 0.2, zr + 0.4, zr + 0.2], r=0.085, w=0.07)
    return m


MODELS = [ambulance, fire_truck, afad_rescue, tv_van, bus, dump_truck, crane_truck]
