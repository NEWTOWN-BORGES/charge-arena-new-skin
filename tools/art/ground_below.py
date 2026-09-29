"""A paisagem vista do céu, por baixo da Aurora: campos em manta de retalhos, florestas, rios,
lagos e uma vila com ruas, pintada em tons suaves (o jogo põe-lhe névoa por cima).

    python3 tools/art/ground_below.py art/worlds/ground_below.png
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 1024
rng = np.random.default_rng(7)


def smooth_noise(scale, octaves=4):
    out = np.zeros((N, N))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        cells = int(scale * 2 ** o) + 2
        grid = rng.random((cells, cells))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
        out += np.asarray(img, dtype=float) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


# Fields: Voronoi patches in greens and wheat, each a flat colour.
points = rng.random((140, 2)) * N
palette = np.array([[118, 158, 84], [138, 172, 92], [164, 184, 104], [196, 190, 120], [104, 142, 78], [150, 166, 98], [182, 170, 110]], dtype=float)
colours = palette[rng.integers(0, len(palette), len(points))]
yy, xx = np.mgrid[0:N, 0:N]
best = np.full((N, N), 1e12)
index = np.zeros((N, N), dtype=int)
for i, (px, py) in enumerate(points):
    d = (xx - px) ** 2 + (yy - py) ** 2
    closer = d < best
    best[closer] = d[closer]
    index[closer] = i
image = colours[index]
# Hedgerows: darker lines along the field borders.
edge = np.zeros((N, N), dtype=bool)
edge[:, 1:] |= index[:, 1:] != index[:, :-1]
edge[1:, :] |= index[1:, :] != index[:-1, :]
image[edge] = image[edge] * 0.72

# Forests: big soft masses of dark, dotted green.
forest = smooth_noise(3.0) > 0.56
dots = rng.random((N, N))
tree = np.where(dots > 0.5, 1.0, 0.8)[..., None]
image = np.where(forest[..., None], np.array([62, 104, 70]) * tree, image)

img = Image.fromarray(np.clip(image, 0, 255).astype(np.uint8))
draw = ImageDraw.Draw(img)

# Rivers winding across, and two lakes.
for r in range(2):
    x = rng.uniform(0, N)
    pts = []
    for y in range(-20, N + 40, 32):
        x += rng.uniform(-38, 38)
        pts.append((x, y))
    if r == 1:
        pts = [(p[1], p[0]) for p in pts]
    draw.line(pts, fill=(96, 150, 190), width=11, joint="curve")
for _ in range(2):
    cx, cy = rng.uniform(150, N - 150, 2)
    draw.ellipse([cx - 60, cy - 38, cx + 60, cy + 38], fill=(104, 160, 198))

# A small town: a road grid with roofs in warm tiles and grey slate.
tx, ty = N * 0.62, N * 0.38
for k in range(-4, 5):
    draw.line([(tx - 150, ty + k * 34), (tx + 150, ty + k * 34)], fill=(200, 196, 184), width=5)
    draw.line([(tx + k * 34, ty - 150), (tx + k * 34, ty + 150)], fill=(200, 196, 184), width=5)
for gx in range(-4, 4):
    for gy in range(-4, 4):
        if rng.random() < 0.18:
            continue
        x0, y0 = tx + gx * 34 + 6, ty + gy * 34 + 6
        for bx in range(2):
            for by in range(2):
                roof = [(196, 110, 84), (176, 96, 76), (150, 150, 160), (210, 140, 96)][rng.integers(0, 4)]
                draw.rectangle([x0 + bx * 12, y0 + by * 12, x0 + bx * 12 + 9, y0 + by * 12 + 9], fill=roof)
# Country roads from the town.
for angle in (0.3, 2.2, 4.0):
    ex, ey = tx + np.cos(angle) * 700, ty + np.sin(angle) * 700
    draw.line([(tx, ty), (ex, ey)], fill=(196, 188, 164), width=4)

img = img.filter(ImageFilter.GaussianBlur(1.2))
img.save(sys.argv[1] if len(sys.argv) > 1 else "ground_below.png")
print("GROUND", img.size)
