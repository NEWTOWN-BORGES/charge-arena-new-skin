#!/usr/bin/env python3
"""Anime ink for the story portraits (after tools/render_story_faces.gd).

Flattens the toon render into a few clean tones, then draws the line art: a bold outline
round the silhouette and finer lines wherever two colours meet, as a cartoon would.
Rewrites art/story/faces/*.png in place (keeps a raw copy in art/story/faces/raw/).
"""
import glob
import os
import shutil

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "art", "story", "faces")


def ink(path):
    raw_dir = os.path.join(ROOT, "raw")
    os.makedirs(raw_dir, exist_ok=True)
    # Godot leaves the raw renders alone (they are not shipped).
    open(os.path.join(raw_dir, ".gdignore"), "a").close()
    raw = os.path.join(raw_dir, os.path.basename(path))
    if not os.path.exists(raw):
        shutil.copy(path, raw)
    image = Image.open(raw).convert("RGBA")
    rgba = np.asarray(image).astype(np.float32) / 255.0
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    solid = alpha > 0.5

    # Cel look: posterize the brightness into a few steps, keep the hue, and push the
    # saturation a little, like a painted cel.
    hsv = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8)).convert("HSV")).astype(np.float32) / 255.0
    # Lift the darks a little so the black robots (ECLIPSE) still read as painted shapes.
    value = hsv[..., 2] ** 0.8
    hsv[..., 2] = np.clip(np.round(value * 5.0) / 5.0 + 0.04, 0, 1)
    hsv[..., 1] = np.clip(hsv[..., 1] * 1.15, 0, 1)
    flat = np.asarray(Image.fromarray((hsv * 255).astype(np.uint8), "HSV").convert("RGB")).astype(np.float32) / 255.0

    # Inner lines: where neighbouring colours differ enough.
    grey = Image.fromarray((flat * 255).astype(np.uint8)).convert("RGB")
    edges = np.zeros(alpha.shape, np.float32)
    for channel in grey.split():
        e = np.asarray(channel.filter(ImageFilter.FIND_EDGES)).astype(np.float32) / 255.0
        edges = np.maximum(edges, e)
    inner = (edges > 0.2) & solid
    inner = np.asarray(Image.fromarray((inner * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0

    # The silhouette: a bold outline just outside the shape.
    mask = Image.fromarray((solid * 255).astype(np.uint8))
    grown = np.asarray(mask.filter(ImageFilter.MaxFilter(9))) > 0
    outline = grown & ~solid

    ink_colour = np.array([0.08, 0.07, 0.12], np.float32)
    out = np.zeros(rgba.shape, np.float32)
    out[..., :3] = flat
    out[..., 3] = solid.astype(np.float32)
    out[inner, :3] = out[inner, :3] * 0.25 + ink_colour * 0.75
    out[outline, :3] = ink_colour
    out[outline, 3] = 1.0
    result = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")
    # A touch of smoothing so the lines are not jagged.
    result = result.resize((result.width * 2, result.height * 2), Image.NEAREST).resize(result.size, Image.LANCZOS)
    result.save(path)
    print("INK", path)


if __name__ == "__main__":
    for file in sorted(glob.glob(os.path.join(ROOT, "*.png"))):
        ink(file)
