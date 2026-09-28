#!/usr/bin/env python3
"""Neon glow for the locked hard-skin portraits (after tools/render_portraits.gd).

The silhouettes are black with thin neon lines; at thumbnail size the lines vanish. This
blooms the neon: the lit pixels are blurred into a soft halo in their own colour, laid
over the black shape and past its edge, so the skin glows in the dark.
Rewrites art/robots/portraits/cast_*_dark.png in place (keeps a raw copy next to the
renders in art/robots/portraits/raw_dark/, which Godot ignores).
"""
import glob
import os
import shutil

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "art", "robots", "portraits")


def glow(path):
    raw_dir = os.path.join(ROOT, "raw_dark")
    os.makedirs(raw_dir, exist_ok=True)
    open(os.path.join(raw_dir, ".gdignore"), "a").close()
    raw = os.path.join(raw_dir, os.path.basename(path))
    if not os.path.exists(raw):
        shutil.copy(path, raw)
    source = Image.open(raw).convert("RGBA")
    # The halo is sized for a 256 px portrait; bigger renders scale it with them.
    k = source.width / 256.0
    base = np.asarray(source).astype(np.float32) / 255.0
    rgb, alpha = base[..., :3], base[..., 3:]
    # The neon: whatever is lit well above the black body.
    lit = (rgb.max(axis=2, keepdims=True) > 0.18).astype(np.float32) * alpha
    neon = rgb * lit
    layers = []
    for radius, gain in ((2, 1.4), (6, 1.1), (14, 0.8)):
        blurred = []
        for channel in range(3):
            c = Image.fromarray((neon[..., channel] * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius * k))
            blurred.append(np.asarray(c).astype(np.float32) / 255.0)
        layers.append(np.stack(blurred, axis=2) * gain)
    halo = np.clip(sum(layers), 0, 1)
    halo_alpha = np.clip(halo.max(axis=2, keepdims=True) * 1.6, 0, 1)
    # Over the silhouette: add the light; outside it: the halo on its own.
    out_rgb = np.clip(rgb + halo, 0, 1)
    out_alpha = np.maximum(alpha, halo_alpha)
    # Where only the halo is, its colour stands alone (not added to transparent black).
    outside = alpha[..., 0] < 0.5
    out_rgb[outside] = np.clip(halo[outside] / np.maximum(halo_alpha[outside], 1e-3), 0, 1)
    out = np.concatenate([out_rgb, out_alpha], axis=2)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(path)
    print("GLOW", path)


if __name__ == "__main__":
    for file in sorted(glob.glob(os.path.join(ROOT, "cast_*_dark.png"))):
        glow(file)
