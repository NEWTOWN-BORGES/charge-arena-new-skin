"""The surface textures of the worlds, generated (no photos, no licences).

    python3 tools/make_surfaces.py      # writes art/materials/<kind>_{albedo,roughness,normal}.png

Each kind is a 512 px tile that repeats without a seam: an albedo that multiplies the
material's own colour (so one texture serves every paint), a roughness map and a normal map.
scripts/arena_finish.gd picks the kind from the material and projects it in world space.
  panel   painted steel plates: seams, rivets, scuffs and a little dirt in the joints
  alloy   brushed metal
  graphite dark rubber/plastic with a fine pebble grain
  grass   short blades and clumps
  stone   layered rock with cracks and pits (cliffs, rocks, sand banks)
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "materials")
N = 512
rng = np.random.default_rng(11)


def tile_noise(scale, octaves=4, persistence=0.5):
    """Seamless fractal noise: random phases on a periodic spectrum."""
    out = np.zeros((N, N))
    amp = 1.0
    freq = scale
    for _ in range(octaves):
        spec = np.zeros((N, N), complex)
        k = int(freq)
        for _ in range(64):
            fx, fy = rng.integers(-k, k + 1, 2)
            spec[fy % N, fx % N] += (rng.standard_normal() + 1j * rng.standard_normal())
        field = np.real(np.fft.ifft2(spec))
        field /= np.abs(field).max() + 1e-9
        out += field * amp
        amp *= persistence
        freq *= 2
    out -= out.min()
    return out / (out.max() + 1e-9)


def blur(x, r):
    """Seamless box blur by FFT."""
    k = np.zeros((N, N))
    k[:r, :r] = 1
    k = np.roll(k, (-(r // 2), -(r // 2)), (0, 1))
    return np.real(np.fft.ifft2(np.fft.fft2(x) * np.fft.fft2(k / k.sum())))


def normal_from(height, strength):
    gy, gx = np.gradient(np.pad(height, 1, mode="wrap"))
    gx, gy = gx[1:-1, 1:-1] * strength, gy[1:-1, 1:-1] * strength
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(kind, albedo, rough, height, strength):
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, kind + "_albedo.png"))
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, kind + "_roughness.png"))
    Image.fromarray(normal_from(height, strength), "RGB").save(os.path.join(OUT, kind + "_normal.png"))
    print("SURFACE", kind)


def scratches(count, length, width=1):
    field = np.zeros((N, N))
    for _ in range(count):
        x, y = rng.random(2) * N
        a = rng.random() * np.pi
        for s in np.linspace(0, length * (0.5 + rng.random()), int(length * 2)):
            px, py = int(x + np.cos(a) * s) % N, int(y + np.sin(a) * s) % N
            field[py, px] = 1
    return blur(field, width + 1) * (width + 1)


def panel():
    # Plates of 256 px (two a tile): a recessed seam, rivets along it, scuffs and grime.
    yy, xx = np.mgrid[0:N, 0:N]
    cell = 256
    dx = np.minimum(xx % cell, cell - xx % cell)
    dy = np.minimum(yy % cell, cell - yy % cell)
    seam = np.clip(1 - np.minimum(dx, dy) / 3.0, 0, 1)
    rivet = np.zeros((N, N))
    for c in range(0, N, cell):
        for t in range(16, cell, 32):
            for (rx, ry) in ((c + 12, t), (t, c + 12)):
                for oy in range(0, N, cell):
                    r = np.hypot(xx - (rx + (oy if rx == c + 12 else 0)) % N, yy - (ry + (oy if ry == c + 12 else 0)) % N)
                    rivet = np.maximum(rivet, np.clip(1 - r / 4.0, 0, 1))
    wave = tile_noise(3, 4)
    grime = blur(seam, 15) * 0.5 + tile_noise(4, 5) * 0.4
    scuff = scratches(90, 40)
    height = -seam * 1.0 + rivet * 0.8 + wave * 0.25 + scuff * 0.15
    albedo = 0.94 + wave * 0.06 - grime * 0.1 - seam * 0.25 + scuff * 0.05
    rough = 0.38 + tile_noise(8, 4) * 0.15 + scuff * 0.2 + seam * 0.3
    save("panel", albedo, rough, height, 6.0)


def alloy():
    streak = blur(rng.random((N, N)), 1)
    streak = np.real(np.fft.ifft2(np.fft.fft2(streak) * np.fft.fft2(np.roll(np.pad(np.ones((1, 60)) / 60, ((0, N - 1), (0, N - 60))), -30, 1))))
    streak = (streak - streak.min()) / (streak.max() - streak.min())
    blot = tile_noise(3, 3)
    albedo = 0.88 + streak * 0.12 - blot * 0.05
    rough = 0.22 + streak * 0.14 + blot * 0.08
    save("alloy", albedo, rough, streak * 0.3, 3.0)


def graphite():
    pebble = tile_noise(40, 3, 0.6)
    albedo = 0.9 + pebble * 0.1 - tile_noise(4, 3) * 0.06
    rough = 0.5 + pebble * 0.2
    save("graphite", albedo, rough, pebble, 2.5)


def grass():
    blades = tile_noise(60, 3, 0.7)
    clumps = tile_noise(5, 4)
    albedo = 0.72 + blades * 0.22 + clumps * 0.14 - (1 - clumps) * 0.05
    rough = 0.7 + blades * 0.2
    save("grass", albedo, rough, blades * 0.6 + clumps * 0.4, 5.0)


def stone():
    yy, xx = np.mgrid[0:N, 0:N]
    strata = (np.sin(2 * np.pi * (yy / N * 6 + tile_noise(2, 3) * 0.8)) * 0.5 + 0.5)
    rock = tile_noise(6, 5, 0.55)
    cracks = np.clip(1 - np.abs(tile_noise(8, 3) - 0.5) * 25, 0, 1)
    pits = (tile_noise(50, 2) > 0.8) * 1.0
    height = rock * 0.7 + strata * 0.35 - cracks * 0.6 - pits * 0.2
    albedo = 0.78 + rock * 0.2 + strata * 0.08 - cracks * 0.25 - pits * 0.08
    rough = 0.7 + rock * 0.2 + cracks * 0.1
    save("stone", albedo, rough, height, 6.0)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    panel()
    alloy()
    graphite()
    grass()
    stone()
