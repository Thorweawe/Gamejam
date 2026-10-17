"""ChatGPT'den indirilen 2x2 ikon sayfasini 4 ikona boler, beyaz arka plani seffaf yapar.

Kullanim:  python tools/ui_icon_cut.py <sayfa.png> <ad1> <ad2> <ad3> <ad4> [--out klasor] [--size 256]
Siralama: sol ust, sag ust, sol alt, sag alt.
Arka plan: kenarlardan baslayan, beyaza yakin bitisik pikseller (ikonun icindeki beyazlar korunur).
"""
import argparse
import os
from collections import deque

import numpy as np
from PIL import Image, ImageFilter


def cut(quad: Image.Image, size: int) -> Image.Image:
    a = np.asarray(quad.convert("RGB")).astype(np.int16)
    h, w, _ = a.shape
    # beyaza yakinlik: en koyu kanal 232'den buyukse arka plan adayi
    near_white = a.min(axis=2) >= 232
    bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near_white[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx] and near_white[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))
    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8))
    # kenarlari yumusat, beyaz hale kalmasin
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    rgba = quad.convert("RGBA")
    rgba.putalpha(alpha)
    bbox = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    obj = rgba.crop(bbox)
    side = int(max(obj.size) * 1.06)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(obj, ((side - obj.width) // 2, (side - obj.height) // 2))
    return canvas.resize((size, size), Image.LANCZOS)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("sheet")
    p.add_argument("names", nargs=4)
    p.add_argument("--out", default=None)
    p.add_argument("--size", type=int, default=256)
    p.add_argument("--suffix", default="")
    args = p.parse_args()
    im = Image.open(args.sheet)
    out = args.out or os.path.dirname(os.path.abspath(args.sheet))
    W, H = im.size
    for i, name in enumerate(args.names):
        quad = im.crop(((i % 2) * W // 2, (i // 2) * H // 2, (i % 2 + 1) * W // 2, (i // 2 + 1) * H // 2))
        path = os.path.join(out, name + args.suffix + ".png")
        cut(quad, args.size).save(path)
        print("yazildi:", path)


if __name__ == "__main__":
    main()
