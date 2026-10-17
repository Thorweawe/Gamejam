"""assets/_kaynak/ altindaki modelleri kategorilere kopyalar -> assets/models/
ve kaynak listesini (assets/ASSETS.md) yazar. Tekrar calistirilabilir.

  python tools/organize_assets.py
"""
import filecmp
import glob
import json
import os
import re
import shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "portofolyo", "assets", "_kaynak")
DST = os.path.join(ROOT, "portofolyo", "assets", "models")

SOURCES = {
    "kaykit_city_builder_bits": ("KayKit City Builder Bits 1.0 (Kay Lousberg)", "CC0"),
    "kaykit_forest_nature": ("KayKit Forest Nature Pack 1.0 (Kay Lousberg)", "CC0"),
    "ai_uretim": ("Yapay zeka ile uretildi (Claude, tools/asset_gen)", "Proje ekibine ait"),
}

# (kaynak, regex) -> kategori. Ilk eslesen kazanir.
RULES = [
    ("ai_uretim", r"^car_", "araclar"),
    ("ai_uretim", r"^person_", "insanlar"),
    ("ai_uretim", r"^(seagull|bird_|deer|dog)", "canlilar"),
    ("ai_uretim", r"^boat_", "araclar"),
    ("ai_uretim", r"^(mountain_|hill)", "doga/dag"),
    ("ai_uretim", r"^(bbq_|picnic_)", "doga/piknik"),
    ("ai_uretim", r"^river_wall", "yol_zemin"),
    ("ai_uretim", r"^(fountain|beach_umbrella|pier|lighthouse)", "sokak"),
    ("kaykit_city_builder_bits", r"^car_", "araclar"),
    ("ai_uretim", r"^house_", "binalar/konut"),
    ("ai_uretim", r"^building_.*_(damaged|collapsed)$", "binalar/hasar"),
    ("ai_uretim", r"^building_(townhall|hospital|firestation|school|afad|news)", "binalar/kamu"),
    ("ai_uretim", r"^(scaffold_|building_construction|tower_crane)", "binalar/insaat"),
    ("ai_uretim", r"^building_.*(damaged|collapsed)", "binalar/hasar"),
    ("kaykit_city_builder_bits", r"^building_", "binalar/ticari"),
    ("ai_uretim", r"^(rubble_|fire_|smoke_|sandbag|tent_|sign_assembly|assembly_area|siren|road_barrier|traffic_cone|"
                  r"first_aid|earthquake_kit|aid_pallet)", "afet"),
    ("ai_uretim", r"^(billboard|newspaper)", "medya_kampanya"),
    ("ai_uretim", r"^(tile_|road_|flood_)", "yol_zemin"),
    ("kaykit_city_builder_bits", r"^(road_|base$)", "yol_zemin"),
    ("kaykit_city_builder_bits", r".", "sokak"),
    ("kaykit_forest_nature", r"^Tree_", "doga/agac"),
    ("kaykit_forest_nature", r"^Bush_", "doga/cali"),
    ("kaykit_forest_nature", r"^Rock_", "doga/kaya"),
    ("kaykit_forest_nature", r"^Grass_", "doga/cimen"),
]

CATEGORY_INFO = {
    "araclar": "Arabalar ve acil durum araclari (tekerlekler ayri node)",
    "insanlar": "Yayalar (kol/bacak ayri node -> yurume animasyonu, scripts/agent.gd)",
    "binalar/konut": "Konut zinciri: gecekondu -> lv1 -> lv2 -> lv3, kacak kat, guclendirilmis, hasarli, yikik",
    "binalar/kamu": "Belediye (3 seviye), hastane, itfaiye, okul, AFAD, gazete/TV",
    "binalar/ticari": "KayKit hazir binalari (dukkan/apartman)",
    "binalar/insaat": "Iskele, insaat alani, kule vinc (yukseltme sirasinda)",
    "binalar/hasar": "Kamu ve ticari binalarin hasarli (_damaged) ve yikik (_collapsed) halleri",
    "afet": "Moloz, yangin, duman, kum torbasi, cadir, tabelalar, siren, deprem cantasi...",
    "medya_kampanya": "Reklam panolari, gazete bayii (farkindalik kampanyalari)",
    "yol_zemin": "Yollar, kaldirim, cim, su, dere, catlak/sel basmis karolar",
    "sokak": "KayKit sokak objeleri (bank, lamba, cop kutusu...)",
    "canlilar": "Hayvanlar: marti, kus, geyik, kopek (kanat/bacak ayri node -> animasyon)",
    "doga/dag": "Daglar ve tepeler",
    "doga/piknik": "Mangal, piknik masasi, ortu",
    "doga/agac": "Agaclar", "doga/cali": "Calilar", "doga/kaya": "Kayalar", "doga/cimen": "Cimen",
}


def category(src, name):
    for s, pat, cat in RULES:
        if s == src and re.search(pat, name):
            return cat
    return None


def _sync(src, dst, wanted):
    """Sadece degisen dosyalari kopyala; Godot'un .import kayitlarini koru."""
    wanted.add(os.path.normcase(os.path.abspath(dst)))
    if os.path.exists(dst) and filecmp.cmp(src, dst, shallow=False):
        return
    shutil.copy(src, dst)


def main():
    rows = []
    wanted = set()
    for src in SOURCES:
        for gltf in sorted(glob.glob(os.path.join(SRC, src, "*.gltf"))):
            name = os.path.splitext(os.path.basename(gltf))[0]
            cat = category(src, name)
            if cat is None:
                print("kategorisiz:", src, name)
                continue
            out = os.path.join(DST, *cat.split("/"))
            os.makedirs(out, exist_ok=True)
            g = json.load(open(gltf))
            deps = [b["uri"] for b in g.get("buffers", [])] + [i["uri"] for i in g.get("images", [])]
            for f in [os.path.basename(gltf)] + deps:
                _sync(os.path.join(SRC, src, f), os.path.join(out, f), wanted)
            rows.append((cat, name, src))

    # artik kaynagi olmayan eski dosyalari (ve onlarin .import kayitlarini) temizle
    for dirpath, _, files in os.walk(DST):
        for f in files:
            full = os.path.normcase(os.path.abspath(os.path.join(dirpath, f)))
            src_file = full[:-len(".import")] if full.endswith(".import") else full
            if f != "index.json" and src_file not in wanted:
                os.remove(os.path.join(dirpath, f))

    # onizleme sayfasi icin dizin
    index = {cat: [{"name": n, "ai": s == "ai_uretim"} for c, n, s in rows if c == cat] for cat in CATEGORY_INFO}
    with open(os.path.join(DST, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, indent=1)

    # kaynak klasorleri Godot'ta iki kez import edilmesin
    open(os.path.join(SRC, ".gdignore"), "w").close()

    lines = ["# Asset Listesi", "",
             "Bu dosya `tools/organize_assets.py` ile otomatik uretilir, elle duzenlemeyin.", "",
             "- Oyunda kullanilacak modeller: `assets/models/<kategori>/`",
             "- Orijinal kaynaklar (sunum icin, Godot import etmez): `assets/_kaynak/`",
             "  - `kaykit_city_builder_bits/`, `kaykit_forest_nature/`: hazir asset paketleri",
             "  - `ai_uretim/`: yapay zeka ile uretilen modeller", "",
             "## Ozet", "", "| Kaynak | Lisans | Model sayisi |", "|---|---|---|"]
    for src, (label, lic) in SOURCES.items():
        lines.append(f"| {label} | {lic} | {sum(1 for r in rows if r[2] == src)} |")
    lines += ["", f"**Toplam: {len(rows)} model**", "",
              "## Yazi tipi, ses ve arayuz", "",
              "| Varlik | Kaynak | Lisans |", "|---|---|---|",
              "| `assets/fonts/Fredoka.ttf` | Fredoka (The Fredoka Project Authors), github.com/google/fonts | SIL OFL 1.1 "
              "(`assets/fonts/Fredoka_OFL.txt`) |",
              "| `assets/audio/*.wav` | Kodla uretildi: `tools/audio_gen.py` | Projeye ait |",
              "| Arayuz ikonlari | Kodla ciziliyor: `scripts/ui_icon.gd` | Projeye ait |", "",
              "## Godot notlari", "",
              "- `.gltf` dosyalarini sahneye surukleyin; Godot 4 otomatik import eder. Tum sehir modelleri tek doku "
              "(`citybits_texture.png`) kullanir, ayni stilde gorunur.",
              "- Olcek: bir karo 2x2 birim, kat yuksekligi ~0.7. Binalar ve karolar y=0'dan baslar "
              "(ust yuzey y=0.1). Araclar KayKit arabalari gibi yol karosunun ustune y=0.161'e konur.",
              "- On yon +Z. Arac tekerlekleri ayri node (`*_wheel_*`) -> dondurulebilir. "
              "`car_cranetruck_boom` vinc kolu da ayri node.",
              "- `billboard_screen` ve `building_news_screen` ayri node: kendi kampanya gorselinizi "
              "material_override ile verin.",
              "- `flood_water_overlay`: herhangi bir karonun ustune koyup y'sini artirarak sel yukselme animasyonu "
              "yapilabilir.",
              "- Konut zinciri: `house_lv0_gecekondu` -> `house_lv1` -> `house_lv2` -> `house_lv3`. Her seviyenin "
              "`_damaged` ve `_collapsed` hali var; lv1/lv2 icin `_kacak` (kacak kat) ve `_reinforced` "
              "(guclendirilmis) versiyonlari var.",
              "- Modelleri yeniden uretmek: `python tools/asset_gen/models.py` sonra "
              "`python tools/organize_assets.py`.",
              "- Onizleme: `python -m http.server 8765` -> http://localhost:8765/tools/preview/index.html", ""]
    for cat in CATEGORY_INFO:
        items = [r for r in rows if r[0] == cat]
        if not items:
            continue
        lines += [f"## {cat} ({len(items)})", "", CATEGORY_INFO[cat], "", "| Model | Kaynak |", "|---|---|"]
        for _, name, src in items:
            lines.append(f"| `{name}` | {'AI uretimi' if src == 'ai_uretim' else SOURCES[src][0].split(' (')[0]} |")
        lines.append("")
    with open(os.path.join(ROOT, "portofolyo", "assets", "ASSETS.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    for cat in CATEGORY_INFO:
        print(f"{cat:20s} {sum(1 for r in rows if r[0] == cat)}")
    print("toplam", len(rows))


if __name__ == "__main__":
    main()
