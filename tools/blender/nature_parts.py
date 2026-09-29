"""Natureza refinada para os cenários: árvores de folha larga com tronco curvo, ramos e copa
em massas de folhagem irregulares; pinheiros com andares de ramos caídos e recortados; arbustos,
pedregulhos arredondados, cordilheiras com neve pela encosta e nuvens de cúmulo com a base
plana. Formas orgânicas (ruído de Perlin sobre malhas finas, sombreado suave), em vez das
formas geométricas facetadas de env_parts.py, cujas peças estas substituem (mesmos nomes).

Papéis: shell (folhagem escura / rocha / nuvem), label (folhagem clara), trim (casca, neve,
topo da rocha, barriga da nuvem), dark (tronco da ilha). Origem no chão, Y para cima.
"""
import math
import random

import bmesh
from mathutils import Vector, noise

from mech_parts import T
from mech_kit import sub


def _low():
    # The kit's half-detail pass (robot_kit.py builds "lo_" copies of LOW_DETAIL parts).
    import sys
    return getattr(sys.modules["__main__"], "DETAIL", 1.0) < 1.0


def _offset(seed):
    rng = random.Random(seed)
    return Vector((rng.uniform(-50, 50), rng.uniform(-50, 50), rng.uniform(-50, 50)))


def blob(p, role, center, radius, seed, squash=0.85, lobes=0.22, clumps=0.09, detail=2, flat_base=None):
    """Massa orgânica: icosfera deformada por dois ruídos, lóbulos grandes e tufos pequenos
    (as folhas em cachos de uma copa, os calombos de uma nuvem)."""
    off = _offset(seed)
    bm = bmesh.new()
    if _low():
        detail = max(1, detail - 1)
    bmesh.ops.create_icosphere(bm, subdivisions=detail, radius=1.0)
    for v in bm.verts:
        n = v.co.normalized()
        r = 1.0 + lobes * noise.noise(n * 1.6 + off) + clumps * noise.noise(n * 5.5 + off * 1.7)
        co = n * radius * r
        co.y *= squash
        if flat_base is not None and co.y < -flat_base * radius:
            co.y = -flat_base * radius + (co.y + flat_base * radius) * 0.12
        v.co = co
    p.add(role, bm, T(*center))


def limb(p, role, points, r0, r1, sides=10, seed=0, bark=0.12):
    """Tubo que segue uma linha de pontos e afunila de r0 a r1, com a casca irregular."""
    off = _offset(seed)
    bm = bmesh.new()
    rings = []
    count = len(points)
    prev_side = None
    for i, point in enumerate(points):
        a = Vector(points[max(i - 1, 0)])
        b = Vector(points[min(i + 1, count - 1)])
        tangent = (b - a).normalized()
        helper = Vector((1, 0, 0)) if abs(tangent.x) < 0.9 else Vector((0, 0, 1))
        side = prev_side if prev_side is not None else tangent.cross(helper).normalized()
        side = (side - tangent * side.dot(tangent)).normalized()
        prev_side = side
        up = tangent.cross(side).normalized()
        radius = r0 + (r1 - r0) * (i / max(count - 1, 1))
        ring = []
        for k in range(sides):
            ang = math.tau * k / sides
            d = side * math.cos(ang) + up * math.sin(ang)
            rr = radius * (1.0 + bark * noise.noise(Vector(point) * 6.0 + d * 1.5 + off))
            ring.append(bm.verts.new(Vector(point) + d * rr))
        rings.append(ring)
    for i in range(count - 1):
        for k in range(sides):
            a, b = rings[i][k], rings[i][(k + 1) % sides]
            c, d = rings[i + 1][(k + 1) % sides], rings[i + 1][k]
            bm.faces.new((a, b, c, d))
    tip = bm.verts.new(Vector(points[-1]) + (Vector(points[-1]) - Vector(points[-2])).normalized() * r1)
    for k in range(sides):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    p.add(role, bm, T(0, 0, 0))


def _curve(start, direction, length, bend, steps, rng):
    """Pontos de um ramo que sai de `start` e se curva para cima."""
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    for i in range(steps):
        d = (d + Vector((rng.uniform(-0.15, 0.15), bend, rng.uniform(-0.15, 0.15)))).normalized()
        pts.append(pts[-1] + d * (length / steps))
    return pts


def sample_tree(p, size=1.0, turn=0.0):
    """A árvore de exemplo (tools/blender/assets/lowpoly_tree_sample.obj): tronco retorcido,
    ramos finos abertos e copas facetadas na ponta de cada ramo."""
    from pathlib import Path
    path = Path(__file__).resolve().parent / "assets" / "lowpoly_tree_sample.obj"
    verts = []
    groups = {}
    material = ""
    for line in path.read_text().splitlines():
        if line.startswith("v "):
            verts.append(Vector(map(float, line.split()[1:4])))
        elif line.startswith("usemtl"):
            material = line.split()[1]
        elif line.startswith("f "):
            groups.setdefault(material, []).append([int(x.split("/")[0]) - 1 for x in line.split()[1:]])
    scale = 2.6 * size / 26.5
    rot = math.radians(turn)
    for material, faces in groups.items():
        bm = bmesh.new()
        lookup = {}
        for face in faces:
            vs = []
            for i in face:
                if i not in lookup:
                    v = verts[i] * scale
                    lookup[i] = bm.verts.new(Vector((v.x * math.cos(rot) - v.z * math.sin(rot), v.y, v.x * math.sin(rot) + v.z * math.cos(rot))))
                vs.append(lookup[i])
            try:
                bm.faces.new(vs)
            except ValueError:
                pass
        p.add("trim" if "Bark" in material else "leaf", bm, T(0, 0, 0))


def _crown(p, seed, center, radii, count, clump, roles=("leaf", "leaf2")):
    """Copa ao estilo Ghibli: muitos tufos redondos juntos na superfície de um elipsoide (e
    alguns por dentro para não ficar oca), cada um com o seu tamanho."""
    rng = random.Random(seed)
    for k in range(count):
        # A point on the ellipsoid, biased to the top and the sides the camera sees.
        u = rng.uniform(-0.55, 1.0)
        a = rng.uniform(0, math.tau)
        ring = math.sqrt(max(0.0, 1.0 - u * u))
        depth = rng.uniform(0.7, 1.0) if k > count // 5 else rng.uniform(0.2, 0.6)
        at = Vector((math.cos(a) * ring * radii[0], u * radii[1], math.sin(a) * ring * radii[2])) * depth + Vector(center)
        r = clump * rng.uniform(0.7, 1.25)
        blob(p, roles[k % 2], at, r, seed + k * 7, squash=0.92, lobes=0.12, clumps=0.04, detail=2)


def broadleaf(p, seed, size=1.0):
    """Árvore de folha larga ao estilo Ghibli: tronco fino e escuro que se abre em dois ou
    três ramos e uma copa grande e fofa de tufos."""
    rng = random.Random(seed)
    s = size
    top = Vector((rng.uniform(-0.08, 0.08) * s, 1.0 * s, rng.uniform(-0.08, 0.08) * s))
    limb(p, "trim", [(0, 0, 0), (0.03 * s, 0.45 * s, 0.0), top], 0.1 * s, 0.07 * s, 7, seed, bark=0.15)
    for k in range(3):
        a = math.tau * k / 3 + rng.uniform(-0.4, 0.4)
        pts = _curve(top, Vector((math.cos(a) * 0.8, 1.0, math.sin(a) * 0.8)), 0.55 * s, 0.1, 3, rng)
        limb(p, "trim", pts, 0.05 * s, 0.02 * s, 6, seed + k, bark=0.15)
    _crown(p, seed + 100, top + Vector((0, 0.65 * s, 0)), (0.95 * s, 0.7 * s, 0.95 * s), 22, 0.36 * s)


def conifer(p, seed, size=1.0):
    """Cipreste / pinheiro ao estilo Ghibli: um cone alto e fofo de tufos sobre um tronco curto."""
    rng = random.Random(seed)
    s = size
    limb(p, "trim", [(0, 0, 0), (0, 0.35 * s, 0), (0, 0.6 * s, 0)], 0.08 * s, 0.05 * s, 6, seed)
    count = 18
    height = 2.0 * s
    for k in range(count):
        t = (k + rng.uniform(0, 1)) / count
        y = 0.35 * s + t * height
        radius = (1.0 - t) ** 0.9 * 0.62 * s + 0.08 * s
        a = rng.uniform(0, math.tau)
        at = Vector((math.cos(a) * radius * rng.uniform(0.55, 1.0), y, math.sin(a) * radius * rng.uniform(0.55, 1.0)))
        blob(p, "leaf" if k % 2 == 0 else "leaf2", at, (0.22 + 0.24 * (1.0 - t)) * s * rng.uniform(0.8, 1.2), seed + k * 5, squash=0.95, lobes=0.12, clumps=0.04, detail=2)


def shrub(p, seed, size=1.0):
    """Arbusto ao estilo Ghibli: uma massa baixa e fofa de tufos, com flores espalhadas."""
    rng = random.Random(seed)
    _crown(p, seed, (0, 0.32 * size, 0), (0.5 * size, 0.3 * size, 0.45 * size), 9, 0.24 * size)
    for _ in range(9):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0.2, 0.45) * size
        blob(p, "hazard", (math.cos(a) * rr, rng.uniform(0.35, 0.6) * size, math.sin(a) * rr), 0.04 * size, seed + 90, lobes=0.1, clumps=0.0, detail=1)


def boulder(p, seed, size=1.0):
    """Pedregulho: rocha arredondada e irregular, meio enterrada, com o topo gasto num tom mais
    claro (trim)."""
    rng = random.Random(seed)
    off = _offset(seed)
    for k in range(rng.randint(1, 3)):
        r = size * rng.uniform(0.45, 0.7) * (1.0 if k == 0 else 0.6)
        cx, cz = (rng.uniform(-0.4, 0.4) * size, rng.uniform(-0.4, 0.4) * size) if k else (0.0, 0.0)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        sx, sy, sz = rng.uniform(0.9, 1.3), rng.uniform(0.55, 0.8), rng.uniform(0.8, 1.1)
        for v in bm.verts:
            n = v.co.normalized()
            # Ridged noise gives the fractured planes of real stone.
            ridge = 1.0 - abs(noise.noise(n * 2.2 + off + Vector((k, 0, 0))))
            rr = 1.0 + 0.16 * noise.noise(n * 1.3 + off) + 0.1 * ridge + 0.03 * noise.noise(n * 9.0 + off)
            v.co = Vector((n.x * sx, n.y * sy, n.z * sz)) * r * rr
            if v.co.y < -0.15 * r:
                v.co.y = -0.15 * r
        bm.normal_update()
        top = [f for f in bm.faces if f.normal.y > 0.72]
        rest = [f for f in bm.faces if f.normal.y <= 0.72]
        cap = bm.copy()
        bmesh.ops.delete(cap, geom=[f for f, keep in zip(cap.faces, [f.normal.y > 0.72 for f in bm.faces]) if not keep], context="FACES")
        bmesh.ops.delete(bm, geom=top, context="FACES")
        p.add("rock", bm, T(cx, 0.15 * r, cz))
        p.add("rock2", cap, T(cx, 0.15 * r, cz))


def mountain_range(p, seed, size=1.0):
    """Cordilheira distante: um campo de alturas com três picos e cristas de ruído, a neve nas
    faces altas e pouco inclinadas (trim), a rocha no resto."""
    rng = random.Random(seed)
    off = _offset(seed)
    w, d = 34.0 * size, 14.0 * size
    nx, nz = 56, 24
    peaks = [(rng.uniform(-11, -6) * size, rng.uniform(-2, 2) * size, rng.uniform(7, 10) * size),
             (rng.uniform(-2, 2) * size, rng.uniform(-2, 2) * size, rng.uniform(11, 14) * size),
             (rng.uniform(6, 11) * size, rng.uniform(-2, 2) * size, rng.uniform(7, 10) * size)]

    def height(x, z):
        h = 0.0
        for px, pz, ph in peaks:
            dist = math.hypot((x - px) / (ph * 1.05), (z - pz) / (ph * 0.7))
            h = max(h, ph * max(0.0, 1.0 - dist) ** 1.15)
        ridge = 1.0 - abs(noise.noise(Vector((x * 0.18, z * 0.18, 0)) + off))
        detail = noise.noise(Vector((x * 0.6, z * 0.6, 1.0)) + off)
        edge = min(1.0, (w / 2 - abs(x)) / (w * 0.12), (d / 2 - abs(z)) / (d * 0.25))
        return max(0.0, (h * (0.85 + 0.3 * ridge) + detail * 0.35 * size) * max(edge, 0.0))

    bm = bmesh.new()
    grid = []
    for j in range(nz + 1):
        row = []
        for i in range(nx + 1):
            x = -w / 2 + w * i / nx
            z = -d / 2 + d * j / nz
            row.append(bm.verts.new(Vector((x, height(x, z) - 0.3 * size, z))))
        grid.append(row)
    for j in range(nz):
        for i in range(nx):
            f = bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]))
    bm.normal_update()
    for f in bm.faces:
        if f.normal.y < 0:
            f.normal_flip()
    bm.normal_update()
    top = max(v.co.y for v in bm.verts)
    snow_flags = []
    for f in bm.faces:
        c = f.calc_center_median()
        line = top * (0.64 + 0.1 * noise.noise(c * 0.4 + off))
        snow_flags.append(c.y > line and f.normal.y > 0.45)
    snow = bm.copy()
    bmesh.ops.delete(snow, geom=[f for f, flag in zip(snow.faces, snow_flags) if not flag], context="FACES")
    bmesh.ops.delete(bm, geom=[f for f, flag in zip(bm.faces, snow_flags) if flag], context="FACES")
    p.add("rock", bm, T(0, 0, 0))
    p.add("rock2", snow, T(0, 0, 0))


def cumulus(p, seed, size=1.0):
    """Cúmulo em torre, como nos céus dos filmes de anime: uma base larga e plana e, por cima,
    montes de rolos redondos que sobem em torres de alturas diferentes."""
    rng = random.Random(seed)
    span = 2.2 * size
    # The flat base: a row of wide, squashed rolls.
    for k in range(7):
        t = (k / 6) * 2 - 1
        blob(p, "cloud", (t * span, 0.25 * size, rng.uniform(-0.3, 0.3) * size), 0.75 * size * rng.uniform(0.85, 1.1), seed + k, squash=0.7, lobes=0.16, clumps=0.06, flat_base=0.3)
    # Towers: two or three, each a stack of rolls shrinking upwards.
    for tower in range(rng.randint(2, 3)):
        cx = rng.uniform(-0.6, 0.6) * span
        levels = rng.randint(3, 5)
        for lv in range(levels):
            r = size * (0.85 - lv * 0.12) * rng.uniform(0.85, 1.1)
            y = 0.55 * size + lv * 0.62 * size
            for j in range(2):
                blob(p, "cloud", (cx + rng.uniform(-0.45, 0.45) * size, y + rng.uniform(-0.1, 0.15) * size, rng.uniform(-0.35, 0.35) * size), r * rng.uniform(0.75, 1.0), seed + 50 + tower * 20 + lv * 3 + j, squash=0.92, lobes=0.18, clumps=0.07)


def sky_island(p, seed, size=1.0):
    """Ilha flutuante: rocha pendurada em estalactite irregular, relva por cima e duas árvores."""
    rng = random.Random(seed)
    off = _offset(seed)
    bm = bmesh.new()
    rings = 9
    sides = 18
    prof = [(1.65, 0.0), (1.6, -0.25), (1.4, -0.6), (1.1, -1.0), (0.8, -1.4), (0.5, -1.8), (0.28, -2.2), (0.12, -2.5), (0.0, -2.7)]
    verts = []
    for rr, yy in prof:
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            n = Vector((math.cos(a), 0, math.sin(a)))
            wob = 1.0 + 0.2 * noise.noise(n * 2.0 + Vector((0, yy, 0)) + off)
            ring.append(bm.verts.new(Vector((n.x * rr * wob * size, yy * size * (1.0 + 0.1 * noise.noise(n * 3.0 + off)), n.z * rr * wob * size))))
        verts.append(ring)
    for i in range(len(verts) - 1):
        for k in range(sides):
            bm.faces.new((verts[i][k], verts[i][(k + 1) % sides], verts[i + 1][(k + 1) % sides], verts[i + 1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    p.add("rock", bm, T(0, 0, 0))
    blob(p, "leaf2", (0, 0.02 * size, 0), 1.72 * size, seed + 3, squash=0.08, lobes=0.08, clumps=0.03)
    for k in range(2):
        a = rng.uniform(0, math.tau)
        rr = rng.uniform(0.2, 0.8) * size
        sub = _Shifted(p, Vector((math.cos(a) * rr, 0.1 * size, math.sin(a) * rr)))
        broadleaf(sub, seed + 50 + k, rng.uniform(0.55, 0.75) * size)


class _Shifted:
    """Uma peça vista com a origem noutro ponto: para pôr uma árvore em cima de uma ilha."""

    def __init__(self, part, offset):
        self.part = part
        self.offset = offset

    def add(self, role, bm, matrix):
        for v in bm.verts:
            v.co = v.co + self.offset
        self.part.add(role, bm, matrix)


def grass_tuft(p, seed, size=1.0):
    """Tufo de erva: lâminas finas e curvas, de alturas diferentes, que se abrem em leque (o
    jogo fá-las ondular com o vento)."""
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(rng.randint(9, 13)):
        a = rng.uniform(0, math.tau)
        lean = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-math.sin(a), 0, math.cos(a)))
        base = lean * rng.uniform(0.0, 0.12) * size
        height = rng.uniform(0.22, 0.45) * size
        width = rng.uniform(0.018, 0.03) * size
        bend = rng.uniform(0.25, 0.6)
        rows = []
        steps = 3
        for i in range(steps + 1):
            t = i / steps
            c = base + lean * (bend * height * t * t) + Vector((0, height * t, 0))
            w = width * (1.0 - t * 0.85)
            rows.append((c - side * w, c + side * w))
        verts_front = [(bm.verts.new(l), bm.verts.new(r)) for l, r in rows]
        verts_back = [(bm.verts.new(l), bm.verts.new(r)) for l, r in rows]
        for i in range(steps):
            a1, b1 = verts_front[i]
            a2, b2 = verts_front[i + 1]
            bm.faces.new((a1, b1, b2, a2))
            c1, d1 = verts_back[i]
            c2, d2 = verts_back[i + 1]
            bm.faces.new((d1, c1, c2, d2))
    p.add("grass", bm, T(0, 0, 0))


LIGHT_NAMES = ["env_oak_%d" % i for i in range(3)] + ["env_pine_%d" % i for i in range(3)] + ["env_cloud_%d" % i for i in range(3)] + ["env_bush_0", "env_bush_1", "env_island_0", "env_island_1", "prop_cloud"]


def define(part):
    # Phones below the top profile draw these at half detail (lo_ copies in the kit).
    import sys
    low = getattr(sys.modules["__main__"], "LOW_DETAIL", None)
    if low is not None:
        low.extend(n for n in LIGHT_NAMES if n not in low)
    for i in range(2):
        part("env_grass_%d" % i)(lambda p, s=i: grass_tuft(p, 300 + s * 17, 1.0 + s * 0.3))
    for i in range(3):
        part("env_rock_%d" % i)(lambda p, s=i: boulder(p, 11 + s * 7, 1.0 + s * 0.25))
        part("env_pine_%d" % i)(lambda p, s=i: conifer(p, 3 + s, 1.3 + s * 0.35))
        part("env_oak_%d" % i)(lambda p, s=i: broadleaf(p, 51 + s * 13, 1.2 + s * 0.3))
        part("env_cloud_%d" % i)(lambda p, s=i: cumulus(p, 61 + s * 7, 1.0 + s * 0.3))
    for i in range(2):
        part("env_bush_%d" % i)(lambda p, s=i: shrub(p, 71 + s * 5, 1.0 + s * 0.3))
        part("env_mountain_%d" % i)(lambda p, s=i: mountain_range(p, 91 + s * 9, 1.0))
        part("env_island_%d" % i)(lambda p, s=i: sky_island(p, 101 + s * 3, 1.0 + s * 0.4))
    part("prop_cloud")(lambda p: cumulus(p, 7, 0.8))
    define_town_and_sea(part)


# ======================================================================================
# Cidade: prédios com janelas uma a uma (caixilho, vidro aceso ou escuro, parapeito),
# cornijas a cada andar, pilastras, rés-do-chão com montras e toldos, varandas e telhado
# com platibanda, depósito e antena.
# ======================================================================================
def _facade(p, rng, width, face, floors, y0, floor_h, axis, lit_share=0.5, bay=1.0):
    """Janelas numa face: `face` é a distância da face ao centro, `axis` "z" (+Z) ou "x+"/"x-"."""
    from mech_kit import mbox
    count = max(1, int(width / bay))
    step = width / count
    for f in range(floors):
        y = y0 + f * floor_h + floor_h * 0.5
        for k in range(count):
            u = -width / 2 + step * (k + 0.5)
            lit = rng.random() < lit_share
            glass = "glow" if lit else "dark"
            ww, hh = step * 0.55, floor_h * 0.55
            if axis == "z":
                mbox(p, "trim", T(u, y, face + 0.02), (ww + 0.12, hh + 0.12, 0.05), 0.0, 1)
                mbox(p, glass, T(u, y, face + 0.05), (ww, hh, 0.02), 0.0, 1)
                mbox(p, "label", T(u, y - hh / 2 - 0.07, face + 0.08), (ww + 0.2, 0.06, 0.14), 0.0, 1)
            else:
                sx = 1 if axis == "x+" else -1
                mbox(p, "trim", T(sx * (face + 0.02), y, u), (0.05, hh + 0.12, ww + 0.12), 0.0, 1)
                mbox(p, glass, T(sx * (face + 0.05), y, u), (0.02, hh, ww), 0.0, 1)
                mbox(p, "label", T(sx * (face + 0.08), y - hh / 2 - 0.07, u), (0.14, 0.06, ww + 0.2), 0.0, 1)


def town_tower(p, height, seed):
    """Prédio de 3 x 3 m com a origem no chão."""
    from mech_kit import mbox, mtube, mring, lathe, rod
    rng = random.Random(seed)
    w = 3.0
    ground = 1.0
    floor_h = 0.72
    floors = max(1, int((height - ground - 0.3) / floor_h))
    top = ground + floors * floor_h
    # Ground floor: a darker plinth with shop windows and an awning on the front.
    mbox(p, "dark", T(0, ground / 2, 0), (w + 0.1, ground, w + 0.1), 0.03, 1)
    mbox(p, "glow", T(0, ground * 0.45, w / 2 + 0.07), (w * 0.8, ground * 0.6, 0.02), 0.0, 1)
    mbox(p, "hazard", sub(T(0, ground * 0.92, w / 2 + 0.3), rot=(-18, 0, 0)), (w * 0.86, 0.04, 0.55), 0.01, 1)
    # Body with pilasters and a cornice at every floor.
    mbox(p, "shell", T(0, (ground + top) / 2, 0), (w, top - ground, w), 0.02, 1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            mbox(p, "trim", T(sx * (w / 2 - 0.05), (ground + top) / 2, sz * (w / 2 - 0.05)), (0.2, top - ground, 0.2), 0.01, 1)
    for f in range(floors + 1):
        y = ground + f * floor_h
        mbox(p, "trim", T(0, y, 0), (w + 0.12, 0.07, w + 0.12), 0.01, 1)
    _facade(p, rng, w - 0.5, w / 2, floors, ground, floor_h, "z")
    _facade(p, rng, w - 0.5, w / 2, floors, ground, floor_h, "x+")
    _facade(p, rng, w - 0.5, w / 2, floors, ground, floor_h, "x-")
    # A balcony here and there.
    for f in range(1, floors, 3):
        y = ground + f * floor_h
        mbox(p, "label", T(0, y + 0.02, w / 2 + 0.3), (1.2, 0.06, 0.55), 0.01, 1)
        for x in (-0.58, 0.58):
            rod(p, "metal", (x, y, w / 2 + 0.56), (x, y + 0.35, w / 2 + 0.56), 0.015, 5)
        rod(p, "metal", (-0.6, y + 0.35, w / 2 + 0.56), (0.6, y + 0.35, w / 2 + 0.56), 0.015, 5)
    # Roof: parapet, a water tank on legs, a vent box and an antenna.
    for s in (-1, 1):
        mbox(p, "trim", T(s * (w / 2 - 0.06), top + 0.18, 0), (0.12, 0.36, w), 0.01, 1)
        mbox(p, "trim", T(0, top + 0.18, s * (w / 2 - 0.06)), (w, 0.36, 0.12), 0.01, 1)
    tx, tz = rng.choice(((-0.6, -0.6), (0.6, -0.5), (-0.5, 0.5)))
    for lx in (-0.25, 0.25):
        for lz in (-0.25, 0.25):
            rod(p, "dark", (tx + lx, top, tz + lz), (tx + lx * 0.8, top + 0.55, tz + lz * 0.8), 0.025, 5)
    mtube(p, "label", T(tx, top + 0.85, tz), 0.36, 0.6, 16, bevel=0.02)
    lathe(p, "label", T(tx, top + 1.15, tz), [(0.38, 0.0), (0.0, 0.22)], 16)
    mring(p, "dark", T(tx, top + 0.7, tz), 0.37, 0.02, 16, 4)
    mbox(p, "metal", T(-tx, top + 0.25, -tz), (0.6, 0.5, 0.5), 0.03, 1)
    rod(p, "metal", (tx * -0.2, top, 0.9), (tx * -0.2, top + 1.3, 0.9), 0.02, 5)


def city_block(p, w, d, h, seed):
    """Prédio grande visto de cima, origem no telhado e o corpo a descer `h` m: pilastras,
    cornijas, janelas uma a uma nos andares de cima e telhado com platibanda e equipamento."""
    from mech_kit import mbox, mtube, rod
    rng = random.Random(seed)
    mbox(p, "shell", T(0, -h / 2, 0), (w, h, d), 0.03, 1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            mbox(p, "trim", T(sx * (w / 2 - 0.12), -h / 2, sz * (d / 2 - 0.12)), (0.3, h, 0.3), 0.02, 1)
    floor_h = 1.1
    floors = min(12, int((h - 0.6) / floor_h))
    y0 = -0.6 - floors * floor_h
    for f in range(floors + 1):
        mbox(p, "trim", T(0, y0 + f * floor_h, 0), (w + 0.1, 0.08, d + 0.1), 0.01, 1)
    _facade(p, rng, w - 0.8, d / 2, floors, y0, floor_h, "z", bay=1.3)
    _facade(p, rng, d - 0.8, w / 2, floors, y0, floor_h, "x+", bay=1.3)
    _facade(p, rng, d - 0.8, w / 2, floors, y0, floor_h, "x-", bay=1.3)
    mbox(p, "rubber", T(0, 0.02, 0), (w - 0.5, 0.04, d - 0.5), 0.0, 1)
    for sx in (-1, 1):
        mbox(p, "trim", T(sx * (w / 2 - 0.08), 0.22, 0), (0.16, 0.44, d), 0.02, 1)
    for sz in (-1, 1):
        mbox(p, "trim", T(0, 0.22, sz * (d / 2 - 0.08)), (w - 0.3, 0.44, 0.16), 0.02, 1)
    for k in range(rng.randint(2, 4)):
        x, z = rng.uniform(-w / 2 + 1, w / 2 - 1), rng.uniform(-d / 2 + 1, d / 2 - 1)
        mbox(p, "metal", T(x, 0.3, z), (rng.uniform(0.6, 1.2), 0.55, rng.uniform(0.5, 0.9)), 0.04, 1)
    mtube(p, "label", T(-w / 4, 0.7, d / 4), 0.5, 1.2, 16, bevel=0.02)
    rod(p, "metal", (w / 3, 0, -d / 3), (w / 3, 2.2, -d / 3), 0.03, 6)


# ======================================================================================
# Mar: corais ramificados, corais-cérebro, esponjas-tubo e algas em fita ondulada
# ======================================================================================
def staghorn(p, seed, size=1.0):
    """Coral ramificado: ramos que se dividem duas vezes e se curvam para cima, pontas claras."""
    rng = random.Random(seed)

    def grow(start, direction, length, radius, depth):
        pts = _curve(start, direction, length, 0.25, 4, rng)
        limb(p, "shell", pts, radius, radius * 0.7, 8, rng.randint(0, 999), bark=0.08)
        end = Vector(pts[-1])
        if depth == 0:
            blob(p, "label", end, radius * 1.25, rng.randint(0, 999), squash=1.0, lobes=0.1, clumps=0.0, detail=1)
            return
        for k in range(2):
            a = rng.uniform(0, math.tau)
            d = Vector((math.cos(a) * 0.6, 1.0, math.sin(a) * 0.6))
            grow(end, d, length * 0.72, radius * 0.72, depth - 1)

    for k in range(rng.randint(3, 4)):
        a = math.tau * k / 4 + rng.uniform(-0.3, 0.3)
        grow(Vector((0, 0, 0)), Vector((math.cos(a) * 0.5, 1.0, math.sin(a) * 0.5)), 0.45 * size, 0.06 * size, 2)


def brain_coral(p, seed, size=1.0):
    """Coral-cérebro e esponjas: uma cúpula de rugas fundas e dois ou três tubos abertos."""
    from mech_kit import lathe
    rng = random.Random(seed)
    off = _offset(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    for v in bm.verts:
        n = v.co.normalized()
        folds = abs(math.sin(noise.noise(n * 3.0 + off) * 9.0))
        co = n * 0.45 * size * (1.0 + 0.06 * folds + 0.08 * noise.noise(n * 1.5 + off))
        if co.y < 0:
            co.y *= 0.2
        v.co = co
    p.add("shell", bm, T(0, 0, 0))
    for k in range(rng.randint(2, 3)):
        a = rng.uniform(0, math.tau)
        x, z = math.cos(a) * 0.45 * size, math.sin(a) * 0.45 * size
        h = rng.uniform(0.5, 0.9) * size
        r = rng.uniform(0.09, 0.13) * size
        lathe(p, "trim", T(x, 0, z), [(r * 0.8, 0.0), (r, h * 0.5), (r * 1.15, h), (r * 0.8, h), (r * 0.7, h - 0.1 * size)], 16)


def kelp_ribbons(p, seed, size=1.0):
    """Algas: fitas compridas e onduladas que sobem e balançam, com bolhas de ar nas folhas."""
    rng = random.Random(seed)
    for k in range(rng.randint(3, 5)):
        x, z = rng.uniform(-0.3, 0.3) * size, rng.uniform(-0.3, 0.3) * size
        phase = rng.uniform(0, math.tau)
        height = rng.uniform(1.6, 2.4) * size
        turn = rng.uniform(0, math.pi)
        bm = bmesh.new()
        rows = []
        steps = 16
        for s in range(steps + 1):
            t = s / steps
            y = t * height
            sway = math.sin(phase + t * 5.0) * 0.18 * size * t
            width = 0.09 * size * (0.5 + math.sin(t * math.pi) * 0.9)
            c = Vector((x + sway * math.cos(turn), y, z + sway * math.sin(turn)))
            side = Vector((math.cos(turn + 1.57), 0, math.sin(turn + 1.57))) * width
            ripple = Vector((0, 0, 0.03 * size * math.sin(t * 20.0 + phase)))
            left, right = c - side + ripple, c + side - ripple
            # Both faces of the ribbon, each with its own vertices (seen from either side).
            rows.append((bm.verts.new(left), bm.verts.new(right), bm.verts.new(left), bm.verts.new(right)))
        for s in range(steps):
            a, b, a2, b2 = rows[s]
            c, d, c2, d2 = rows[s + 1]
            bm.faces.new((a, b, d, c))
            bm.faces.new((b2, a2, c2, d2))
        p.add("shell" if k % 2 == 0 else "trim", bm, T(0, 0, 0))


def define_town_and_sea(part):
    for i, h in enumerate((3.0, 5.5, 8.0)):
        part("env_tower_%d" % i)(lambda p, hh=h, s=i: town_tower(p, hh, 20 + s))
    for i, (w, d) in enumerate(((6.0, 6.0), (5.0, 8.0), (4.0, 4.5))):
        part("env_block_%d" % i)(lambda p, ww=w, dd=d, s=i: city_block(p, ww, dd, 26.0, 40 + s))
    for i in range(2):
        part("env_coral_tubes_%d" % i)(lambda p, s=i: brain_coral(p, 5 + s * 9, 1.0))
        part("env_coral_fan_%d" % i)(lambda p, s=i: staghorn(p, 2 + s * 5, 1.0))
        part("env_kelp_%d" % i)(lambda p, s=i: kelp_ribbons(p, 8 + s * 3, 1.0))
