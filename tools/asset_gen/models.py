"""Tum ozel modelleri uretir -> assets/custom/

  python tools/asset_gen/models.py            # hepsi
  python tools/asset_gen/models.py vehicles   # tek grup
"""
import os
import shutil
import sys

from kitgen import export
from parts import KAYKIT, ROOT

GROUPS = ["vehicles", "buildings", "damage", "props", "tiles", "people", "nature"]  # damage, buildings ciktisini kullanir
OUT = os.path.join(ROOT, "portofolyo", "assets", "_kaynak", "ai_uretim")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    shutil.copy(os.path.join(KAYKIT, "citybits_texture.png"), os.path.join(OUT, "citybits_texture.png"))
    for group in sys.argv[1:] or GROUPS:
        for fn in __import__(group).MODELS:
            print(os.path.basename(export(fn(), OUT)))
