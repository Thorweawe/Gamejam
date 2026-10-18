"""Fredoka (degisken font) icin Turkce harf duzeltmesi.

Orijinal Fredoka'da Ş ş Ğ ğ İ yok (Godot bunlari baska bir yedek fonttan cizer, farkli gorunur) ve
Ç ç'deki cengel cok ince / harften kopuk duruyor. Bu betik:
  - Ş ş Ç ç: harf + fontun kendi virgulunun kucultulmusu (sade, yuvarlak) altta ortali
  - Ğ ğ: harf + fontun kendi breve isareti
  - İ: I + fontun kendi noktasi (Ö'deki noktalarla ayni yukseklikte)
Harfler bilesik glif olarak kurulur; kalinlik / genislik eksenlerinde temel harfle birlikte degisir.

Kullanim: python font_add_turkish.py <Fredoka.ttf> <yedek.ttf>   (orijinal fonta uygulanir)
"""
import shutil
import sys
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph, GlyphComponent
from fontTools.ttLib.tables.TupleVariation import TupleVariation

SRC = sys.argv[1]
BACKUP = sys.argv[2]
shutil.copy(SRC, BACKUP)
f = TTFont(SRC)
glyf = f['glyf']
hmtx = f['hmtx']
gvar = f['gvar']
order = f.getGlyphOrder()


def bbox(name):
    g = glyf[name]
    g.recalcBounds(glyf)
    return g.xMin, g.yMin, g.xMax, g.yMax


def xmid(name):
    b = bbox(name)
    return (b[0] + b[2]) / 2.0


COMMA_GAP = 10  # virgulun ust ucu ile harfin alt kenari arasi (font birimi)
COMMA_SCALE = 0.6  # tam boy virgul harfin altinda fazla iri duruyor


def under_comma(base):
    """Kucultulmus virgul harfin altinda ortali, ust ucu harfin hemen altinda."""
    cb = [v * COMMA_SCALE for v in bbox('comma')]
    dx = round(xmid(base) - (cb[0] + cb[2]) / 2.0)
    dy = round(bbox(base)[1] - COMMA_GAP - cb[3])
    return dx, dy


def centered(base, mark, dy):
    mb = bbox(mark)
    return round(xmid(base) - (mb[0] + mb[2]) / 2.0), dy


# (glif, unicode ya da None = fontta var, temel, isaret, (dx, dy))
# Fontta buyuk harf ust isaretleri kucuk harf isaretinin 200 birim yukarisi (Odieresis: uni0308 @ y=200).
GLYPHS = [
    ('Scedilla', 0x015E, 'S', 'comma', under_comma('S')),
    ('scedilla', 0x015F, 's', 'comma', under_comma('s')),
    ('Ccedilla', None, 'C', 'comma', under_comma('C')),
    ('ccedilla', None, 'c', 'comma', under_comma('c')),
    ('Gbreve', 0x011E, 'G', 'uni0306', centered('G', 'uni0306', 200)),
    ('gbreve', 0x011F, 'g', 'uni0306', centered('g', 'uni0306', 0)),
    ('Idotaccent', 0x0130, 'I', 'uni0307.case', centered('I', 'uni0307.case', 200)),
]

for name, uni, base, mark, (dx, dy) in GLYPHS:
    g = Glyph()
    g.numberOfContours = -1
    comps = []
    for cn, x, y in ((base, 0, 0), (mark, dx, dy)):
        c = GlyphComponent()
        c.glyphName = cn
        c.x, c.y = x, y
        c.flags = 0x4  # ROUND_XY_TO_GRID
        if cn == 'comma':
            c.transform = [[COMMA_SCALE, 0.0], [0.0, COMMA_SCALE]]
        comps.append(c)
    comps[0].flags |= 0x200  # USE_MY_METRICS: genislik temel harften
    g.components = comps
    if name not in glyf.glyphs:
        order.append(name)
    glyf.glyphs[name] = g
    hmtx.metrics[name] = hmtx.metrics[base]
    # degisken font: temel harfin hayalet nokta degisimleri kopyalanir, isaret temel harfle birlikte kayar
    vars_ = []
    for tv in gvar.variations.get(base, []):
        phantom = tv.coordinates[-4:]
        rx = phantom[1][0] if phantom[1] is not None else 0
        lx = phantom[0][0] if phantom[0] is not None else 0
        new = [(0, 0), (round((rx - lx) / 2.0), 0)] + [p if p is not None else (0, 0) for p in phantom]
        vars_.append(TupleVariation(dict(tv.axes), new))
    gvar.variations[name] = vars_
    if uni is not None:
        for t in f['cmap'].tables:
            if t.isUnicode():
                t.cmap[uni] = name
    print(name, base, '+', mark, (dx, dy))

f.setGlyphOrder(order)
hv = f['HVAR'].table
if hv.AdvWidthMap is not None:
    for name, _u, base, _m, _o in GLYPHS:
        if base in hv.AdvWidthMap.mapping:
            hv.AdvWidthMap.mapping[name] = hv.AdvWidthMap.mapping[base]
if 'GDEF' in f and f['GDEF'].table.GlyphClassDef:
    cd = f['GDEF'].table.GlyphClassDef.classDefs
    for name, _u, base, _m, _o in GLYPHS:
        cd[name] = cd.get(base, 1)
f.save(SRC)
print('kaydedildi')
