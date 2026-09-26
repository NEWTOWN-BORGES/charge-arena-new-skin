"""Tabela de cor (LUT 3D) que leva a imagem do Godot às cores do Blender.

    python3 tools/color/build_lut.py blender.png godot_raw.png   # escreve art/color/blender_lut.png

As duas imagens são o mesmo quadro de teste (tools/color/patches.json): uma renderizada no
Blender com AgX Medium High Contrast, a outra no Godot só com o mapeamento de tons (sem os
ajustes). Para cada cor que o Godot produz, a tabela diz a cor que o Blender mostra. Fica
em 33 fatias de 33 x 33 lado a lado (vermelho em x, verde em y, azul de fatia em fatia).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.interpolate import LinearNDInterpolator, NearestNDInterpolator

ROOT = Path(__file__).resolve().parents[2]
SIZE = 33


def sample(path, count, cols, cell):
    im = np.asarray(Image.open(path).convert("RGB")).astype(float) / 255.0
    return np.array([im[(i // cols) * cell + cell // 2, (i % cols) * cell + cell // 2] for i in range(count)])


def main(blender, godot):
    data = json.loads((ROOT / "tools" / "color" / "patches.json").read_text())
    n, cols, cell = len(data["patches"]), data["columns"], data["cell"]
    target = sample(blender, n, cols, cell)
    source = sample(godot, n, cols, cell)
    # Identical Godot colours (clipped highlights) keep one target, their mean.
    keys, inverse = np.unique(np.round(source * 255).astype(int), axis=0, return_inverse=True)
    inverse = inverse.reshape(-1)
    src = keys / 255.0
    dst = np.zeros_like(src)
    for k in range(len(keys)):
        dst[k] = target[inverse == k].mean(axis=0)
    grid = np.linspace(0.0, 1.0, SIZE)
    b, g, r = np.meshgrid(grid, grid, grid, indexing="ij")
    nodes = np.stack([r.ravel(), g.ravel(), b.ravel()], axis=1)
    linear = LinearNDInterpolator(src, dst)(nodes)
    nearest = NearestNDInterpolator(src, dst)(nodes)
    lut = np.where(np.isnan(linear), nearest, linear)
    image = lut.reshape(SIZE, SIZE, SIZE, 3)  # [b][g][r]
    strip = np.concatenate([image[z] for z in range(SIZE)], axis=1)  # rows: g, columns: slice*SIZE + r
    out = ROOT / "art" / "color" / "blender_lut.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(np.round(strip * 255), 0, 255).astype(np.uint8)).save(out)
    print("LUT", out.relative_to(ROOT), strip.shape)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
