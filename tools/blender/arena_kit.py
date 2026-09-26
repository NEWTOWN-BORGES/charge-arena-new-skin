"""Arena v2 modelada como os robôs: uma arena de verdade, feita de peças mecânicas.

    python3 tools/blender/arena_kit.py saida.png [tema]     # render de estúdio (Cycles)

Chão de placas hexagonais separadas (juntas escuras), marcações pintadas, muralhas de
blindagem aparafusada sobre uma viga escura com faixa da equipa e luz na aresta, torres nos
cantos com holofotes em dobradiças, portões das balizas com arco e pistões, uma plataforma
com painéis, ventilação e luzes na orla, e bancadas com público robô. Coordenadas em
unidades do Godot (Y para cima); o contorno é o "stadium" estreito da primeira arena.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import robot_kit as rk  # noqa: E402
from mech_kit import (at, axis_frame, bolts, dome, frame, lathe, mbox, mring, mtube, rod, sub, vents,  # noqa: E402
                      warning, serial, piston, cable)
from mech_parts import T  # noqa: E402
from mech_cast import arc_tube, ball  # noqa: E402

# Tema Aurora da paleta nova.
THEME = {
    "tile": "eef3f7", "tile_alt": "cfe3f2", "tile_near": "a9ecd9", "tile_far": "ffcdbd", "paint": "ffffff",
    "shell": "f6f2e8", "dark": "2a3140", "metal": "b9c2cc", "glow": "8ff6e2", "near": "2fc4a5", "far": "ff7a5c",
    "accent": "ffc53d", "rubber": "15171c", "hazard": "f2c230", "base": "4f6f8a", "base_dark": "2d4054",
    "seat": "e9edf2", "crowd1": "2fc4a5", "crowd2": "ff7a5c", "crowd3": "ffc53d", "crowd4": "8f7cf0", "screen": "0b0f18",
}
SKY = ("2f7fd0", "5fa8e6", "d6eef6")

SCALE = 1.24
HALF_W = 6.0 * SCALE * 0.71
HALF_L = 6.93 * SCALE
OUTLINE = [(-5.0 * 0.71, -HALF_L), (5.0 * 0.71, -HALF_L), (HALF_W, -HALF_L + 2.6), (HALF_W, HALF_L - 2.6),
           (5.0 * 0.71, HALF_L), (-5.0 * 0.71, HALF_L), (-HALF_W, HALF_L - 2.6), (-HALF_W, -HALF_L + 2.6)]


def offset(points, d):
    """Contorno convexo afastado `d` para fora (linhas paralelas cruzadas nos vértices)."""
    n = len(points)
    lines = []
    for i in range(n):
        a, b = Vector(points[i]), Vector(points[(i + 1) % n])
        e = (b - a).normalized()
        normal = Vector((e.y, -e.x))
        if normal.dot((a + b) / 2) < 0:
            normal = -normal
        lines.append((a + normal * d, e))
    out = []
    for i in range(n):
        (p1, d1), (p2, d2) = lines[i - 1], lines[i]
        den = d1.x * d2.y - d1.y * d2.x
        t = ((p2.x - p1.x) * d2.y - (p2.y - p1.y) * d2.x) / den
        out.append(tuple(p1 + d1 * t))
    return out


def slab(p, role, points, y0, y1, bevel=0.0):
    """Prisma vertical com o contorno `points` (x, z) entre as alturas y0 e y1."""
    bm = bmesh.new()
    low = [bm.verts.new((x, y0, z)) for x, z in points]
    high = [bm.verts.new((x, y1, z)) for x, z in points]
    bm.faces.new(low)
    bm.faces.new(list(reversed(high)))
    for i in range(len(points)):
        j = (i + 1) % len(points)
        bm.faces.new((low[i], low[j], high[j], high[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    p.add(role, bm, Matrix.Identity(4))


def inside(pt, points, margin):
    n = len(points)
    for i in range(n):
        a, b = Vector(points[i]), Vector(points[(i + 1) % n])
        e = (b - a).normalized()
        normal = Vector((e.y, -e.x))
        if normal.dot((a + b) / 2) < 0:
            normal = -normal
        if (Vector(pt) - a).dot(normal) > -margin:
            return False
    return True


def edges(points):
    for i in range(len(points)):
        yield Vector(points[i]), Vector(points[(i + 1) % len(points)])


def inward(a, b):
    e = (b - a).normalized()
    normal = Vector((-e.y, e.x))
    return normal if normal.dot(-(a + b) / 2) > 0 else -normal


def build_floor(p):
    # Placas hexagonais soltas sobre a grelha escura: juntas de 3 cm, biséis que apanham a luz.
    slab(p, "dark", OUTLINE, -0.12, -0.02)
    r = 0.42
    dx = math.sqrt(3) * r
    dz = 1.5 * r
    row = 0
    z = -HALF_L
    while z <= HALF_L:
        x0 = -HALF_W - (dx / 2 if row % 2 else 0)
        x = x0
        while x <= HALF_W + dx:
            if inside((x, z), OUTLINE, r * 0.9):
                role = "tile_alt" if (row + int((x - x0) / dx)) % 3 == 0 else "tile"
                if z > HALF_L - 2.4:
                    role = "tile_near"
                elif z < -HALF_L + 2.4:
                    role = "tile_far"
                mtube(p, role, sub(T(x, -0.04, z), rot=(0, 30, 0)), r - 0.03, 0.08, 6, bevel=0.012)
            x += dx
        z += dz
        row += 1
    # Marcações pintadas (em relevo de 3 mm): anéis do centro, traço do meio, áreas das balizas.
    mring(p, "paint", T(0, 0.004, 0), 2.12, 0.035, 64, 4)
    mring(p, "paint", T(0, 0.004, 0), 2.34, 0.014, 64, 4)
    for i in range(24):
        a = math.radians(i * 15)
        mbox(p, "paint", sub(T(math.cos(a) * 2.55, 0.004, math.sin(a) * 2.55), rot=(0, -i * 15, 0)), (0.06, 0.008, 0.18), 0.0, 1)
    x = -HALF_W + 0.3
    while x < HALF_W - 0.3:
        mbox(p, "paint", T(x + 0.2, 0.004, 0), (0.4, 0.008, 0.035), 0.0, 1)
        x += 0.75
    for side, role in ((1, "near"), (-1, "far")):
        arc_tube(p, role, T(0, 0.006, side * HALF_L), 3.0, 0.035, 180 if side > 0 else 0, 360 if side > 0 else 180, 48, 4)
        arc_tube(p, "paint", T(0, 0.006, side * HALF_L), 1.9, 0.02, 180 if side > 0 else 0, 360 if side > 0 else 180, 40, 4)


def build_walls(p):
    """Muralhas: viga escura contínua, painéis de blindagem com juntas, faixa da equipa, luz
    na aresta de dentro, parafusos nas pontas de cada painel e postes com tampas."""
    for a, b in edges(OUTLINE):
        mid = (a + b) / 2
        length = (b - a).length
        e = (b - a).normalized()
        n = inward(a, b)
        yaw = math.degrees(math.atan2(e.x, e.y))
        base = sub(T(mid.x, 0, mid.y), rot=(0, yaw - 90, 0))
        # Viga escura e sapata de borracha.
        mbox(p, "dark", sub(base, 0, 0.2, 0.0), (length + 0.1, 0.4, 0.3), 0.04)
        mbox(p, "rubber", sub(base, 0, 0.02, 0.0), (length + 0.06, 0.05, 0.36), 0.02)
        count = max(1, round(length / 1.05))
        seg = length / count
        for i in range(count):
            u = -length / 2 + seg * (i + 0.5)
            half = "near" if (mid.y + e.y * u) > 0 else "far"
            # Blindagem de fora e de dentro, faixa da equipa e tampa de cima.
            for s in (-1, 1):
                mbox(p, "shell", sub(base, u, 0.3, s * 0.17), (seg - 0.06, 0.46, 0.06), 0.028)
                mbox(p, half, sub(base, u, 0.2, s * 0.205), (seg - 0.14, 0.07, 0.02), 0.008, 1)
                for v in (-1, 1):
                    mtube(p, "metal", sub(base, u + v * (seg / 2 - 0.08), 0.46, s * 0.202, rot=(90, 0, 0)), 0.014, 0.012, 6)
            mbox(p, "shell", sub(base, u, 0.57, 0.0), (seg - 0.06, 0.06, 0.4), 0.025)
            if i % 2 == 0:
                vents(p, sub(base, u, 0.36, -0.2), 3, seg * 0.35, depth=0.02, spacing=0.05, height=0.015)
        # Luz na aresta de dentro.
        side = 1 if Vector((0, 0)).dot(n) >= 0 else 1
        glow_offset = n * 0.21
        mbox(p, "glow", T(mid.x + glow_offset.x, 0.52, mid.y + glow_offset.y) @ Matrix.Rotation(math.radians(yaw - 90), 4, "Y"), (length - 0.2, 0.025, 0.02), 0.006, 1)


def build_pylons(p):
    """Torres nos cantos: tambor escuro, cintas de blindagem, rolamento, cúpula, faixa de
    perigo e holofote numa dobradiça virado para o centro."""
    for i, (x, z) in enumerate(OUTLINE):
        c = Vector((x, z))
        mtube(p, "dark", T(x, 0.55, z), 0.26, 1.1, 20, bevel=0.02)
        for y in (0.25, 0.75):
            mtube(p, "shell", T(x, y, z), 0.3, 0.32, 24, bevel=0.03)
        mring(p, "hazard", T(x, 0.47, z), 0.3, 0.03, 24, 5)
        mring(p, "metal", T(x, 1.0, z), 0.27, 0.025, 24, 5)
        bolts(p, T(x, 1.03, z), 0.22, 8, size=0.02)
        dome(p, "accent", T(x, 1.1, z), 0.24, 0.16, 20, 5)
        # Holofote: forquilha, cabeça, lente acesa.
        d = (-c).normalized()
        head = Vector((x, 1.45, z)) + Vector((d.x, 0, d.y)) * 0.05
        rod(p, "dark", (x, 1.2, z), head, 0.04, 10)
        lamp = frame(head, Vector((d.x, -0.55, d.y)), front=(0, 1, 0))
        mtube(p, "dark", lamp, 0.13, 0.16, 18, bevel=0.015)
        mtube(p, "glow", sub(lamp, 0, 0.085, 0), 0.105, 0.01, 18)
        mring(p, "metal", sub(lamp, 0, 0.08, 0), 0.12, 0.012, 18, 4)
        mtube(p, "metal", axis_frame(head, "x"), 0.03, 0.3, 10)


def build_goals(p):
    """Portões das balizas: pilares rechonchudos, arco com anel de luz da equipa e placa."""
    for side, role in ((1, "near"), (-1, "far")):
        zc = side * (HALF_L + 0.1)
        for x in (-2.0, 2.0):
            mtube(p, "wall", T(x, 0.7, zc), 0.3, 1.4, 20, bevel=0.08)
            mring(p, role, T(x, 1.1, zc), 0.31, 0.05, 20, 5)
            dome(p, "wall_top", T(x, 1.4, zc), 0.33, 0.25, 20, 5)
        gate = sub(T(0, 1.35, zc), rot=(-90, 0, 0))
        arc_tube(p, "wall", gate, 2.0, 0.16, 0, 180, 40, 12)
        arc_tube(p, role, gate, 2.0, 0.08, 4, 176, 40, 10)
        arc_tube(p, "glow", sub(gate, 0, -side * 0.12, 0), 1.8, 0.035, 8, 172, 40, 6)
        mbox(p, "dark", T(0, 3.1, zc), (1.0, 0.42, 0.16), 0.08, 3)
        serial(p, rk_plane((0, 3.1, zc - side * 0.085), (0, 0, -side), (-side, 0, 0)), "01" if side > 0 else "02", 0.24, role="glow")
        # Tijolos da equipa à frente da baliza, como numa partida.
        for row in range(3):
            for col in range(-4, 5):
                if abs(col) < 1 and row == 0:
                    continue
                zz = zc - side * (1.4 + row * 0.62)
                mbox(p, role, T(col * 0.62, 0.2, zz), (0.54, 0.38, 0.5), 0.1, 3)
                mbox(p, "wall", T(col * 0.62, 0.42, zz), (0.46, 0.08, 0.42), 0.04, 2)


def rk_plane(origin, normal, right):
    from mech_kit import plane
    return plane(origin, normal, right)


def build_base(p):
    """Plataforma: dois degraus de painéis com juntas, orla de luz, ventilação e parafusos."""
    outer = offset(OUTLINE, 0.55)
    lower = offset(OUTLINE, 1.2)
    slab(p, "base", outer, -0.7, -0.04, 0.05)
    slab(p, "base_dark", lower, -1.35, -0.62, 0.06)
    for a, b in edges(outer):
        e = (b - a).normalized()
        n = -inward(a, b)
        length = (b - a).length
        yaw = math.degrees(math.atan2(e.x, e.y))
        count = max(1, int(length / 1.1))
        for i in range(count + 1):
            q = a + e * (length * i / count)
            mbox(p, "dark", sub(T(q.x + n.x * 0.005, -0.37, q.y + n.y * 0.005), rot=(0, yaw - 90, 0)), (0.04, 0.6, 0.03), 0.0, 1)
        mid = (a + b) / 2
        mbox(p, "glow", sub(T(mid.x + n.x * 0.01, -0.12, mid.y + n.y * 0.01), rot=(0, yaw - 90, 0)), (length - 0.3, 0.03, 0.02), 0.0, 1)
        if length > 3:
            vents(p, sub(T(mid.x + n.x * 0.01, -0.45, mid.y + n.y * 0.01), rot=(0, yaw - 90, 0)), 4, 1.2, depth=0.03, spacing=0.07, height=0.03)


def build_stands(p):
    """Bancadas nos lados compridos: três degraus, cadeiras, público robô e grades."""
    import random
    rng = random.Random(7)
    for side in (-1, 1):
        x0 = side * (HALF_W + 1.9)
        for tier in range(3):
            x = x0 + side * tier * 0.7
            y = -0.9 + tier * 0.45
            mbox(p, "base", T(x, y, 0), (0.7, 0.45 + tier * 0.9, HALF_L * 1.3), 0.04)
            z = -HALF_L * 0.6
            while z < HALF_L * 0.6:
                sy = y + 0.225 + tier * 0.45
                mbox(p, "seat", T(x, sy, z), (0.3, 0.08, 0.3), 0.03)
                if rng.random() < 0.8:
                    role = rng.choice(["crowd1", "crowd2", "crowd3", "crowd4", "shell"])
                    mbox(p, role, T(x, sy + 0.2, z), (0.22, 0.3, 0.2), 0.08)
                    mbox(p, "shell", T(x, sy + 0.42, z), (0.24, 0.16, 0.2), 0.05)
                    mbox(p, "screen", T(x - side * 0.1, sy + 0.42, z), (0.02, 0.1, 0.14), 0.01, 1)
                z += 0.42
        rail_x = x0 - side * 0.4
        for z in (-HALF_L * 0.62, HALF_L * 0.62):
            rod(p, "metal", (rail_x, -0.3, z), (rail_x, 0.25, z), 0.03)
        rod(p, "metal", (rail_x, 0.25, -HALF_L * 0.62), (rail_x, 0.25, HALF_L * 0.62), 0.03)



# ======================================================================================
# Diorama vivo (estilo das referências): planalto de relva com falésias, rochas redondas,
# árvores, arbustos, cristais e nuvens à volta da arena.
# ======================================================================================
VIVID = {
    "grass": "5cc75a", "grass_dark": "3fa24f", "cliff": "c9855a", "cliff_dark": "a8674a", "rock": "b9a896",
    "rock_dark": "8f7f70", "leaf1": "7fd64e", "leaf2": "4fbf5c", "leaf3": "a6e05a", "trunk": "9a5e3c",
    "crystal": "4fe3ff", "crystal2": "ff6fd8", "cloud": "ffffff", "track": "ff9a3c", "track_edge": "fff1d8",
    "check1": "3fbfa0", "check2": "37ad91", "wall": "fff4e2", "wall_top": "ff7a3c", "flower": "ffd23f",
}


def blob_rock(p, role, role2, at_pt, size, rng):
    """Rocha estilizada: blocos de arestas muito arredondadas empilhados, como nas referências."""
    x, y, z = at_pt
    for k in range(rng.randint(2, 4)):
        w = size * rng.uniform(0.5, 1.0)
        h = size * rng.uniform(0.6, 1.6)
        d = size * rng.uniform(0.5, 0.9)
        ox, oz = rng.uniform(-0.4, 0.4) * size, rng.uniform(-0.4, 0.4) * size
        mbox(p, role if k % 2 == 0 else role2, sub(T(x + ox, y + h / 2, z + oz), rot=(rng.uniform(-6, 6), rng.uniform(0, 90), rng.uniform(-6, 6))),
             (w, h, d), min(w, h, d) * 0.28, 3)


def tree(p, at_pt, size, rng):
    x, y, z = at_pt
    mtube(p, "trunk", T(x, y + size * 0.35, z), size * 0.09, size * 0.7, 10, radius2=size * 0.06)
    for k, (dy, r) in enumerate(((0.75, 0.42), (1.05, 0.34), (1.3, 0.22))):
        ball(p, ("leaf1", "leaf2", "leaf3")[(k + rng.randint(0, 2)) % 3], (x + rng.uniform(-0.05, 0.05) * size, y + dy * size, z), r * size, 14)


def bush(p, at_pt, size, rng):
    x, y, z = at_pt
    for k in range(rng.randint(3, 5)):
        ball(p, ("leaf1", "leaf2", "leaf3")[rng.randint(0, 2)], (x + rng.uniform(-0.5, 0.5) * size, y + size * 0.35, z + rng.uniform(-0.5, 0.5) * size), size * rng.uniform(0.35, 0.55), 12)
    if rng.random() < 0.5:
        ball(p, "flower", (x, y + size * 0.8, z), size * 0.12, 8)


def crystal(p, at_pt, size, rng, role):
    x, y, z = at_pt
    for k in range(rng.randint(2, 4)):
        h = size * rng.uniform(0.6, 1.3)
        tilt = (rng.uniform(-22, 22), 0, rng.uniform(-22, 22))
        m = sub(T(x + rng.uniform(-0.2, 0.2) * size, y, z + rng.uniform(-0.2, 0.2) * size), rot=tilt)
        lathe(p, role, m, [(0.0, 0.0), (size * 0.16, 0.02), (size * 0.16, h * 0.75), (0.0, h)], 6)


def cloud(p, at_pt, size):
    x, y, z = at_pt
    for dx, dy, r in ((-0.5, 0, 0.45), (0, 0.15, 0.6), (0.55, 0.02, 0.42), (0.2, -0.1, 0.4)):
        ball(p, "cloud", (x + dx * size, y + dy * size, z), r * size, 16)


def build_vivid(p):
    import random
    rng = random.Random(3)
    # Planalto: relva em cima, falésias em camadas nos lados.
    plateau = offset(OUTLINE, 5.5)
    slab(p, "grass", plateau, -0.35, -0.05, 0.12)
    slab(p, "cliff", offset(OUTLINE, 5.2), -1.4, -0.3, 0.15)
    slab(p, "cliff_dark", offset(OUTLINE, 4.6), -2.6, -1.3, 0.2)
    # Pista laranja à volta da arena, com orla clara.
    slab(p, "track_edge", offset(OUTLINE, 1.25), -0.09, -0.03, 0.05)
    slab(p, "track", offset(OUTLINE, 1.05), -0.07, -0.01, 0.05)
    # Cenário: rochas, árvores, arbustos e cristais no anel entre a pista e a borda.
    placed = []
    tries = 0
    while len(placed) < 70 and tries < 2000:
        tries += 1
        x, z = rng.uniform(-HALF_W - 5, HALF_W + 5), rng.uniform(-HALF_L - 5, HALF_L + 5)
        if inside((x, z), offset(OUTLINE, 1.6), 0.0) or not inside((x, z), offset(OUTLINE, 4.8), 0.0):
            continue
        if any((Vector((x, z)) - Vector(q)).length < 1.1 for q in placed):
            continue
        placed.append((x, z))
        kind = rng.random()
        if kind < 0.3:
            tree(p, (x, -0.05, z), rng.uniform(1.1, 1.8), rng)
        elif kind < 0.55:
            bush(p, (x, -0.05, z), rng.uniform(0.5, 0.8), rng)
        elif kind < 0.8:
            blob_rock(p, "rock", "rock_dark", (x, -0.05, z), rng.uniform(0.5, 1.0), rng)
        else:
            crystal(p, (x, -0.05, z), rng.uniform(0.6, 1.0), rng, "crystal" if rng.random() < 0.6 else "crystal2")
    for x, y, z, s in ((-HALF_W - 4, 1.5, -HALF_L - 2, 1.6), (HALF_W + 4.5, 1.2, HALF_L + 1, 1.8), (HALF_W + 3, 2.0, -HALF_L - 3.5, 1.3), (-HALF_W - 5, 1.8, HALF_L + 3, 1.4)):
        cloud(p, (x, y, z), s)


def build_vivid_floor(p):
    # Chão em xadrez de placas arredondadas (dois tons de verde-água) e marcações claras.
    slab(p, "dark", OUTLINE, -0.12, -0.02)
    t = 1.0
    z = -HALF_L
    k = 0
    while z < HALF_L:
        x = -HALF_W
        j = 0
        while x < HALF_W:
            if inside((x + t / 2, z + t / 2), OUTLINE, 0.05):
                mbox(p, "check1" if (j + k) % 2 == 0 else "check2", T(x + t / 2, -0.04, z + t / 2), (t - 0.05, 0.1, t - 0.05), 0.04, 2)
            x += t
            j += 1
        z += t
        k += 1
    mring(p, "track_edge", T(0, 0.02, 0), 2.1, 0.06, 64, 4)
    mring(p, "flower", T(0, 0.02, 0), 1.0, 0.05, 48, 4)
    for side, role in ((1, "near"), (-1, "far")):
        arc_tube(p, role, T(0, 0.02, side * HALF_L), 2.8, 0.06, 180 if side > 0 else 0, 360 if side > 0 else 180, 48, 4)


def build_vivid_walls(p):
    # Muros rechonchudos: blocos creme com tampa laranja arredondada, e postes-holofote.
    for a, b in edges(OUTLINE):
        length = (b - a).length
        e = (b - a).normalized()
        yaw = math.degrees(math.atan2(e.x, e.y))
        count = max(1, round(length / 0.9))
        for i in range(count):
            q = a + e * (length * (i + 0.5) / count)
            m = sub(T(q.x, 0, q.y), rot=(0, yaw - 90, 0))
            mbox(p, "wall", sub(m, 0, 0.25, 0), (length / count - 0.06, 0.5, 0.4), 0.12, 3)
            mbox(p, "wall_top", sub(m, 0, 0.53, 0), (length / count - 0.04, 0.12, 0.46), 0.06, 3)
    for i, (x, z) in enumerate(OUTLINE):
        mtube(p, "wall", T(x, 0.5, z), 0.32, 1.0, 20, bevel=0.08)
        dome(p, "wall_top", T(x, 1.0, z), 0.34, 0.26, 20, 5)
        c = Vector((x, z))
        d = (-c).normalized()
        head = Vector((x, 1.4, z))
        rod(p, "dark", (x, 1.1, z), head, 0.05, 10)
        lamp = frame(head, Vector((d.x, -0.6, d.y)), front=(0, 1, 0))
        mtube(p, "dark", lamp, 0.15, 0.18, 18, bevel=0.03)
        mtube(p, "glow", sub(lamp, 0, 0.095, 0), 0.12, 0.012, 18)



# ======================================================================================
# Arena flutuante sci-fi: plataforma no céu com propulsores, convés com sucata, contentores,
# grua robótica, drones e placar. Sem fantasia: tudo é máquina.
# ======================================================================================
TECH = {
    "deck": "c9d6e2", "deck_dark": "36404f", "deck_panel": "5d7fa3", "pad": "ffc53d", "crate": "ffae3d", "crate2": "2fa6e0", "barrel": "ff5c4d",
    "scrap": "a39a92", "rust": "c9794a", "container1": "ff7a3c", "container2": "2fc4a5", "container3": "8f7cf0",
    "hull": "e9edf1", "hull_dark": "4a5566", "thruster": "ffb35c",
}


def barrel(p, at_pt, rng, lying=False):
    x, y, z = at_pt
    role = rng.choice(["barrel", "crate2", "container2"])
    m = sub(T(x, y + (0.2 if lying else 0.3), z), rot=(90 if lying else 0, rng.uniform(0, 180), 0))
    mtube(p, role, m, 0.2, 0.58, 16, bevel=0.02)
    for v in (-0.18, 0.18):
        mring(p, "dark", sub(m, 0, v, 0), 0.205, 0.018, 16, 4)
    mtube(p, "metal", sub(m, 0, 0.29, 0), 0.05, 0.02, 8)


def crate(p, at_pt, size, rng):
    x, y, z = at_pt
    m = sub(T(x, y + size / 2, z), rot=(0, rng.uniform(0, 90), 0))
    mbox(p, rng.choice(["crate", "crate2", "deck"]), m, (size, size, size), 0.04, 2)
    for u in (-1, 1):
        mbox(p, "dark", sub(m, u * size * 0.36, 0, 0), (size * 0.1, size * 1.01, size * 1.01), 0.01, 1)
    mbox(p, "dark", sub(m, 0, 0, 0), (size * 1.01, size * 0.1, size * 1.01), 0.01, 1)


def gear(p, at_pt, radius, rng, role="scrap"):
    x, y, z = at_pt
    m = sub(T(x, y + 0.05, z), rot=(rng.uniform(-15, 15), rng.uniform(0, 90), rng.uniform(-15, 15)))
    mtube(p, role, m, radius, 0.08, 24)
    mtube(p, "dark", m, radius * 0.3, 0.1, 12)
    for k in range(12):
        a = k * 30
        mbox(p, role, sub(m, 0, 0, 0, rot=(0, a, 0)) @ Matrix.Translation(Vector((radius + 0.04, 0, 0))), (0.1, 0.08, 0.08), 0.01, 1)


def tire(p, at_pt, rng):
    x, y, z = at_pt
    m = sub(T(x, y + 0.08, z), rot=(rng.uniform(-10, 10), 0, rng.uniform(-10, 10)))
    mring(p, "rubber", m, 0.26, 0.1, 24, 10)
    mtube(p, "metal", m, 0.17, 0.08, 16)


def robot_head(p, at_pt, rng):
    x, y, z = at_pt
    m = sub(T(x, y + 0.2, z), rot=(rng.uniform(-25, 25), rng.uniform(0, 360), rng.uniform(-30, 30)))
    mbox(p, "deck", m, (0.5, 0.36, 0.38), 0.07, 3)
    mbox(p, "screen", sub(m, 0, 0, -0.19), (0.36, 0.2, 0.02), 0.02, 1)
    mbox(p, "glow", sub(m, -0.08, 0.02, -0.2), (0.05, 0.08, 0.01), 0.01, 1)
    mtube(p, "dark", sub(m, 0, -0.24, 0), 0.08, 0.12, 12)
    rod(p, "metal", at(m, 0.12, 0.18, 0), at(m, 0.16, 0.42, 0.05), 0.012)


def scrap_pile(p, at_pt, rng):
    x, y, z = at_pt
    # Monte de sucata: chapas tortas, tubos, uma roda, engrenagens e peças de robô.
    for k in range(6):
        mbox(p, rng.choice(["scrap", "rust", "deck", "hull_dark"]), sub(T(x + rng.uniform(-0.6, 0.6), y + 0.08 + k * 0.06, z + rng.uniform(-0.6, 0.6)),
             rot=(rng.uniform(-25, 25), rng.uniform(0, 180), rng.uniform(-25, 25))), (rng.uniform(0.4, 0.9), 0.05, rng.uniform(0.3, 0.6)), 0.02, 1)
    for k in range(3):
        a = Vector((x + rng.uniform(-0.7, 0.7), y + rng.uniform(0.1, 0.4), z + rng.uniform(-0.7, 0.7)))
        b = a + Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.1, 0.3), rng.uniform(-0.8, 0.8)))
        rod(p, rng.choice(["metal", "rust"]), a, b, 0.05, 10)
    gear(p, (x + 0.4, y + 0.3, z - 0.3), 0.3, rng, rng.choice(["scrap", "rust"]))
    tire(p, (x - 0.5, y, z + 0.4), rng)
    robot_head(p, (x + 0.1, y + 0.35, z + 0.2), rng)


def container(p, at_pt, yaw, role):
    x, y, z = at_pt
    m = sub(T(x, y + 0.45, z), rot=(0, yaw, 0))
    mbox(p, role, m, (2.2, 0.9, 0.95), 0.04, 2)
    for k in range(9):
        mbox(p, role, sub(m, -0.98 + k * 0.245, 0, 0), (0.06, 0.86, 0.99), 0.01, 1)
    for u in (-1.1, 1.1):
        mbox(p, "dark", sub(m, u, 0, 0), (0.04, 0.92, 0.97), 0.01, 1)
    mbox(p, "hazard", sub(m, 0.6, 0.28, -0.49), (0.3, 0.1, 0.01), 0.0, 1)


def crane(p, base_pt, reach_pt):
    """Grua robótica: torre giratória, dois braços com dobradiças e pistões, garra."""
    b = Vector(base_pt)
    mtube(p, "hull_dark", T(b.x, b.y + 0.2, b.z), 0.6, 0.4, 24, bevel=0.03)
    mring(p, "hazard", T(b.x, b.y + 0.4, b.z), 0.6, 0.04, 24, 5)
    mtube(p, "hull", T(b.x, b.y + 0.7, b.z), 0.4, 0.6, 20, bevel=0.05)
    bolts(p, T(b.x, b.y + 1.0, b.z), 0.32, 8, size=0.03)
    shoulder = b + Vector((0, 1.1, 0))
    r = Vector(reach_pt)
    elbow = shoulder.lerp(r, 0.5) + Vector((0, 2.2, 0))
    for a0, a1, w in ((shoulder, elbow, 0.2), (elbow, r + Vector((0, 0.9, 0)), 0.15)):
        rod(p, "container1", a0, a1, w, 14)
        mtube(p, "metal", axis_frame(a0, "x"), w * 1.2, w * 2.4, 16)
        piston(p, a0 + (a1 - a0) * 0.1 + Vector((0, -0.2, 0)), a0 + (a1 - a0) * 0.6 + Vector((0, -0.1, 0)), 0.06)
    wrist = r + Vector((0, 0.9, 0))
    mtube(p, "dark", T(wrist.x, wrist.y, wrist.z), 0.16, 0.2, 14)
    for k in range(3):
        a = math.radians(k * 120)
        d = Vector((math.cos(a), 0, math.sin(a)))
        rod(p, "metal", wrist, wrist + d * 0.3 + Vector((0, -0.3, 0)), 0.04)
        rod(p, "metal", wrist + d * 0.3 + Vector((0, -0.3, 0)), wrist + d * 0.15 + Vector((0, -0.55, 0)), 0.035)
    mbox(p, "rust", T(r.x, r.y + 0.2, r.z), (0.4, 0.3, 0.4), 0.03)


def drone(p, at_pt):
    x, y, z = at_pt
    mbox(p, "hull", T(x, y, z), (0.36, 0.14, 0.36), 0.06, 3)
    mbox(p, "glow", T(x, y - 0.08, z), (0.14, 0.02, 0.14), 0.02, 1)
    for dx, dz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        rod(p, "dark", (x, y, z), (x + dx * 0.32, y + 0.04, z + dz * 0.32), 0.02)
        mring(p, "dark", T(x + dx * 0.32, y + 0.06, z + dz * 0.32), 0.14, 0.012, 16, 4)
        mtube(p, "metal", T(x + dx * 0.32, y + 0.07, z + dz * 0.32), 0.02, 0.03, 8)


def scoreboard(p, at_pt):
    x, y, z = at_pt
    for dx in (-1.6, 1.6):
        rod(p, "hull_dark", (x + dx, 0, z), (x + dx, y, z), 0.12)
        for k in range(1, 5):
            rod(p, "metal", (x + dx, y * k / 5, z), (x + dx * 0.8, y * (k + 0.5) / 5, z), 0.03)
    mbox(p, "hull", T(x, y + 0.9, z), (3.8, 1.9, 0.3), 0.1, 3)
    mbox(p, "screen", T(x, y + 0.9, z + 0.16), (3.4, 1.5, 0.02), 0.04, 1)
    mbox(p, "near", T(x - 0.9, y + 0.9, z + 0.18), (1.2, 0.8, 0.01), 0.04, 1)
    mbox(p, "far", T(x + 0.9, y + 0.9, z + 0.18), (1.2, 0.8, 0.01), 0.04, 1)
    mbox(p, "glow", T(x, y + 1.9, z), (3.8, 0.05, 0.32), 0.02, 1)


def build_tech_goals(p):
    """Portões mecânicos: pilares blindados, arco em duas meias-luas com rolamentos, pistões
    e anel de luz da equipa."""
    for side, role in ((1, "near"), (-1, "far")):
        zc = side * (HALF_L + 0.05)
        for x in (-1.95, 1.95):
            mbox(p, "hull_dark", T(x, 0.7, zc), (0.36, 1.4, 0.4), 0.05)
            mbox(p, "hull", T(x, 0.55, zc - side * 0.05), (0.42, 0.9, 0.44), 0.06)
            mbox(p, role, T(x, 1.08, zc - side * 0.05), (0.43, 0.08, 0.45), 0.02, 1)
            mtube(p, "metal", axis_frame((x, 1.45, zc), "z"), 0.14, 0.46, 16)
            bolts(p, axis_frame((x, 1.45, zc + side * 0.23), "z" if side > 0 else "-z"), 0.1, 6, size=0.02)
            piston(p, (x * 0.85, 0.15, zc - side * 0.45), (x * 0.9, 1.1, zc - side * 0.2), 0.05)
        gate = sub(T(0, 1.45, zc), rot=(-90, 0, 0))
        arc_tube(p, "hull", gate, 1.95, 0.14, 0, 180, 40, 8)
        arc_tube(p, role, gate, 1.95, 0.07, 4, 176, 40, 8)
        arc_tube(p, "glow", sub(gate, 0, -side * 0.1, 0), 1.78, 0.03, 8, 172, 40, 6)
        mbox(p, "dark", T(0, 3.55, zc), (1.0, 0.42, 0.14), 0.05)
        serial(p, rk_plane((0, 3.55, zc - side * 0.075), (0, 0, -side), (-side, 0, 0)), "01" if side > 0 else "02", 0.24, role="glow")


def build_sky_platform(p):
    """Plataforma no céu: convés largo com juntas, orla de luz, casco em degraus por baixo,
    quatro propulsores acesos, antenas e nuvens a passar."""
    import random
    rng = random.Random(11)
    deck = offset(OUTLINE, 3.6)
    slab(p, "deck", deck, -0.35, -0.03, 0.06)
    slab(p, "deck_dark", offset(OUTLINE, 3.7), -0.55, -0.33, 0.04)
    for a, b in edges(deck):
        e = (b - a).normalized()
        n = -inward(a, b)
        length = (b - a).length
        yaw = math.degrees(math.atan2(e.x, e.y))
        mid = (a + b) / 2
        mbox(p, "glow", sub(T(mid.x + n.x * 0.06, -0.44, mid.y + n.y * 0.06), rot=(0, yaw - 90, 0)), (length - 0.4, 0.04, 0.02), 0.0, 1)
        count = max(1, int(length / 1.6))
        for i in range(1, count):
            q = a + e * (length * i / count)
            mbox(p, "deck_dark", sub(T(q.x, -0.028, q.y), rot=(0, yaw - 90, 0)), (0.04, 0.01, 0.9), 0.0, 1)
    # Painéis do convés em azul, faixa de perigo na orla e duas plataformas de aterragem.
    # Por baixo do chão da arena (cujo topo escuro fica em y = -0.02): só se veem à volta.
    slab(p, "deck_panel", offset(OUTLINE, 2.9), -0.06, -0.026, 0.01)
    slab(p, "deck", offset(OUTLINE, 1.0), -0.05, -0.022, 0.01)
    for a, b in edges(offset(OUTLINE, 3.35)):
        e = (b - a).normalized()
        length = (b - a).length
        yaw = math.degrees(math.atan2(e.x, e.y))
        n = int(length / 0.3)
        for i in range(n):
            q = a + e * (length * (i + 0.5) / n)
            mbox(p, "hazard" if i % 2 == 0 else "deck_dark", sub(T(q.x, -0.02, q.y), rot=(0, yaw - 90 + 30, 0)), (0.28, 0.02, 0.3), 0.0, 1)
    for x, z in ((-HALF_W - 2.2, -HALF_L + 1.8), (HALF_W + 2.2, HALF_L - 1.2)):
        mtube(p, "deck_dark", T(x, 0.01, z), 0.95, 0.04, 32)
        mring(p, "pad", T(x, 0.035, z), 0.8, 0.04, 32, 4)
        mbox(p, "pad", T(x - 0.2, 0.035, z), (0.08, 0.01, 0.6), 0.0, 1)
        mbox(p, "pad", T(x + 0.2, 0.035, z), (0.08, 0.01, 0.6), 0.0, 1)
        mbox(p, "pad", T(x, 0.035, z), (0.4, 0.01, 0.08), 0.0, 1)
        for k in range(8):
            ang = math.radians(k * 45)
            ball(p, "glow", (x + math.cos(ang) * 0.95, 0.04, z + math.sin(ang) * 0.95), 0.05, 8)
    # Casco por baixo, em degraus que afunilam.
    for k, (d, y0, y1) in enumerate(((3.2, -1.3, -0.55), (2.2, -2.1, -1.25), (0.9, -2.8, -2.05))):
        slab(p, "hull" if k % 2 == 0 else "hull_dark", offset(OUTLINE, d), y0, y1, 0.08)
    for x, z in ((-3.2, -5.0), (3.2, -5.0), (-3.2, 5.0), (3.2, 5.0)):
        m = T(x, -2.9, z)
        lathe(p, "hull_dark", m, [(0.55, 0.3), (0.7, 0.0), (0.8, -0.5), (0.6, -0.55), (0.45, -0.1)], 24)
        mtube(p, "thruster", sub(m, 0, -0.5, 0), 0.62, 0.02, 24)
        mring(p, "metal", sub(m, 0, 0.1, 0), 0.72, 0.05, 24, 5)
    # Nuvens em volta e por baixo.
    for x, y, z, sz in ((-13, -3.5, -6, 2.6), (12, -4.0, 4, 3.0), (-11, -5.0, 10, 2.2), (10, -2.5, -12, 2.4), (0, -6, 14, 3.2), (-6, -7, -14, 2.8)):
        cloud(p, (x, y, z), sz)
    # Antenas e sinalização nos cantos do convés.
    for x, z in offset(OUTLINE, 3.2)[::2]:
        rod(p, "hull_dark", (x, 0, z), (x, 2.2, z), 0.05)
        ball(p, "glow", (x, 2.25, z), 0.08, 10)
        mbox(p, "hazard", T(x, 0.3, z), (0.3, 0.6, 0.3), 0.04)


def build_tech_dressing(p):
    import random
    rng = random.Random(5)
    # Sucata e cargas no convés, entre a muralha e a orla.
    spots = []
    tries = 0
    while len(spots) < 40 and tries < 4000:
        tries += 1
        x, z = rng.uniform(-HALF_W - 3.4, HALF_W + 3.4), rng.uniform(-HALF_L - 3.4, HALF_L + 3.4)
        if inside((x, z), offset(OUTLINE, 1.0), 0.0) or not inside((x, z), offset(OUTLINE, 3.2), 0.0):
            continue
        if abs(x) < 2.8 and abs(z) > HALF_L - 1:
            continue
        if any((Vector((x, z)) - Vector(q)).length < 1.4 for q in spots):
            continue
        spots.append((x, z))
        k = rng.random()
        if k < 0.3:
            scrap_pile(p, (x, 0, z), rng)
        elif k < 0.55:
            crate(p, (x, 0, z), rng.uniform(0.45, 0.7), rng)
            if rng.random() < 0.5:
                crate(p, (x + 0.1, 0.55, z + 0.05), 0.4, rng)
        elif k < 0.8:
            for j in range(rng.randint(1, 3)):
                barrel(p, (x + j * 0.42, 0, z + rng.uniform(-0.2, 0.2)), rng, lying=rng.random() < 0.3)
        else:
            robot_head(p, (x, 0.0, z), rng)
            gear(p, (x + 0.5, 0.0, z), 0.35, rng)
    container(p, (-HALF_W - 2.4, 0, 1.5), 90, "container1")
    container(p, (-HALF_W - 2.4, 0.9, 1.3), 92, "container2")
    container(p, (HALF_W + 2.4, 0, -2.0), 90, "container3")
    crane(p, (HALF_W + 2.3, 0, 3.4), (HALF_W + 0.8, 0, 6.2))
    for x, y, z in ((-2.5, 3.0, -2.0), (3.0, 2.6, 3.0), (-4.5, 3.4, 5.5)):
        drone(p, (x, y, z))
    scoreboard(p, (0, 3.6, -HALF_L - 2.4))


def hex_rgb(value):
    return rk.hex_rgb(value)


def render(out, samples=96):
    rk.reset()
    parts = {}
    for name, fn in (("floor", build_floor), ("walls", build_walls), ("pylons", build_pylons), ("goals", build_tech_goals),
                     ("platform", build_sky_platform), ("dressing", build_tech_dressing)):
        prt = rk.Part("arena_" + name)
        fn(prt)
        parts[name] = prt
    mats = {}
    for role, value in {**THEME, **VIVID, **TECH}.items():
        mat = bpy.data.materials.new(role)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        col = hex_rgb(value)
        bsdf.inputs["Base Color"].default_value = (*col, 1)
        bsdf.inputs["Roughness"].default_value = {"metal": 0.3, "rubber": 0.85, "dark": 0.5, "screen": 0.15, "paint": 0.5}.get(role, 0.4)
        bsdf.inputs["Metallic"].default_value = {"metal": 0.85, "dark": 0.3}.get(role, 0.0)
        if role in ("glow", "crystal", "crystal2", "thruster"):
            bsdf.inputs["Emission Color"].default_value = (*col, 1)
            bsdf.inputs["Emission Strength"].default_value = 5.0 if role in ("glow", "thruster") else 0.8
        mats[role] = mat
    for prt in parts.values():
        for role, me in prt.meshes.items():
            for poly in me.polygons:
                poly.use_smooth = True
            me.set_sharp_from_angle(angle=math.radians(40))
            me.materials.append(mats.get(role) or mats["shell"])
            obj = bpy.data.objects.new(me.name, me)
            bpy.context.collection.objects.link(obj)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1100
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    grad = nodes.new("ShaderNodeTexGradient")
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    world.node_tree.links.new(coord.outputs["Generated"], sep.inputs[0])
    world.node_tree.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].color = (*hex_rgb(SKY[2]), 1)
    ramp.color_ramp.elements[1].color = (*hex_rgb(SKY[0]), 1)
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[1].position = 0.75
    nodes["Background"].inputs[0].default_value = (*hex_rgb(SKY[1]), 1)
    nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(12)
    sun.rotation_euler = (math.radians(48), math.radians(-18), math.radians(-35))
    bpy.context.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 30
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    target = rk.CONVERT @ Vector((0, -1.0, 0.5, 1))
    cam.location = (rk.CONVERT @ Vector((14.0, 10.5, 21.0, 1))).to_3d()
    cam.rotation_euler = (target.to_3d() - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    # Vista baixa: a plataforma a flutuar, com os propulsores por baixo.
    cam.location = (rk.CONVERT @ Vector((16.0, 3.0, 19.0, 1))).to_3d()
    cam.rotation_euler = (target.to_3d() - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(Path(out).with_name(Path(out).stem + "_low.png"))
    bpy.ops.render.render(write_still=True)
    # Segunda vista: a câmara do jogo (de cima e de trás da baliza de baixo).
    cam.location = (rk.CONVERT @ Vector((0.0, 22.0, 16.0, 1))).to_3d()
    cam.rotation_euler = (target.to_3d() - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 42
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1400
    scene.render.filepath = str(Path(out).with_name(Path(out).stem + "_game.png"))
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    render(args[0], int(args[1]) if len(args) > 1 else 96)
