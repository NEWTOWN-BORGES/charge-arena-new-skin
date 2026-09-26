"""Afina a tabela de cor a partir de uma medição: onde o Godot com a tabela ainda não dá a cor
do Blender, empurra as entradas vizinhas pela diferença que falta.

    python3 tools/color/refine_lut.py blender.png godot_raw.png godot_com_tabela.png
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from build_lut import ROOT, SIZE, sample


def main(blender, raw, measured):
    data = json.loads((ROOT / "tools" / "color" / "patches.json").read_text())
    n, cols, cell = len(data["patches"]), data["columns"], data["cell"]
    target, source, got = (sample(p, n, cols, cell) for p in (blender, raw, measured))
    path = ROOT / "art" / "color" / "blender_lut.png"
    strip = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
    lut = np.stack([strip[:, z * SIZE:(z + 1) * SIZE] for z in range(SIZE)])  # [b][g][r]
    push = np.zeros_like(lut)
    weight = np.zeros(lut.shape[:3])
    # Spread each patch's missing difference over the eight table entries around its colour.
    for s, e in zip(source, target - got):
        p = s * (SIZE - 1)
        i0 = np.minimum(np.floor(p).astype(int), SIZE - 2)
        f = p - i0
        for dz in (0, 1):
            for dy in (0, 1):
                for dx in (0, 1):
                    w = (f[2] if dz else 1 - f[2]) * (f[1] if dy else 1 - f[1]) * (f[0] if dx else 1 - f[0])
                    push[i0[2] + dz, i0[1] + dy, i0[0] + dx] += w * e
                    weight[i0[2] + dz, i0[1] + dy, i0[0] + dx] += w
    seen = weight > 1e-4
    lut[seen] += push[seen] / weight[seen][:, None]
    lut = np.clip(lut, 0.0, 1.0)
    strip = np.concatenate([lut[z] for z in range(SIZE)], axis=1)
    Image.fromarray(np.round(strip * 255).astype(np.uint8)).save(path)
    print("REFINED mean error before", np.abs(target - got).mean() * 255)


if __name__ == "__main__":
    main(*sys.argv[1:4])
