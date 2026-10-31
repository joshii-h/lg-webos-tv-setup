#!/usr/bin/env python3
"""Turn any image into a Luma wallpaper folder (no phone/QR upload needed).

Luma (github.com/ecklf/lg-luma) only accepts exactly 1920x1080 and stores three
files per wallpaper. wallpaper.jpg carries the same dark gradient Luma applies
to uploads (port of shade() in src/wallpapers.rs), so text stays readable.

Usage:  make-luma-wallpaper.py input.jpg outdir/
Then copy outdir/custom-<id>/ to /media/developer/com.ecklf.luma/wallpapers/
on the TV, chown -R to the owner of preferences.json, chmod 600 the files, and
set "background": "custom-<id>" in preferences.json while Luma is closed.
"""
import json, os, secrets, sys
import numpy as np
from PIL import Image, ImageOps

STOPS = [(0.00, (13, 16, 19), 0.24), (0.19, (14, 17, 21), 0.08),
         (0.35, (15, 17, 20), 0.35), (0.63, (17, 19, 23), 0.86),
         (0.85, (23, 25, 29), 0.92157), (1.00, (23, 25, 29), 0.96078)]

def shade(a):
    h, w = a.shape[:2]
    xs = np.arange(w, dtype=np.float32)
    horiz = (0.42 * np.maximum(1 - xs / (1919 * 0.75), 0))[:, None]
    out = np.empty_like(a)
    for y in range(h):
        yy = y / 1079
        p0, p1 = next((STOPS[k], STOPS[k + 1]) for k in range(len(STOPS) - 1) if yy <= STOPS[k + 1][0])
        t = (yy - p0[0]) / (p1[0] - p0[0])
        alpha = p0[2] * (1 - t) + p1[2] * t
        grad = np.array(p0[1]) * p0[2] * (1 - t) + np.array(p1[1]) * p1[2] * t
        base = a[y] * 0.92 + np.array([23, 25, 28]) * 0.08
        base = base * (1 - horiz) + np.array([17, 20, 23]) * horiz
        out[y] = base * (1 - alpha) + grad
    return np.clip(np.round(out), 0, 255).astype(np.uint8)

def main(src, outdir):
    wid = "custom-" + secrets.token_hex(16)
    d = os.path.join(outdir, wid)
    os.makedirs(d)
    im = ImageOps.fit(Image.open(src).convert("RGB"), (1920, 1080), Image.LANCZOS)
    im.save(os.path.join(d, "original.jpg"), quality=94)
    im.resize((480, 270), Image.BILINEAR).save(os.path.join(d, "thumbnail.jpg"), quality=82)
    Image.fromarray(shade(np.asarray(im).astype(np.float32))).save(os.path.join(d, "wallpaper.jpg"), quality=94)
    json.dump({"id": wid}, open(os.path.join(d, "metadata.json"), "w"))
    print(wid)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
