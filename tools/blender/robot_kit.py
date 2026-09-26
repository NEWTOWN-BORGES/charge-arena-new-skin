"""Kit de peças dos robôs do Charge Arena, modelado em Blender.

    python3 tools/blender/robot_kit.py                # escreve art/robots/kit.glb
    python3 tools/blender/robot_kit.py --sheet a.png  # e renderiza o elenco (Cycles)

Cada peça é um nó vazio na raiz do .glb com uma malha por material; o nome do material é o
papel da cor (ver ROLES). As peças já estão na posição final:
- cabeças, topos, troncos, ombreiras, costas e braços no espaço do nó Body;
- pernas no espaço de uma perna (pivô na anca, LEG_PIVOT), simétricas, servem às duas;
- armas no espaço do nó Gun (origem igual à do Body), boca do cano em MUZZLE;
- topos e cristas desenhados para uma cabeça com o topo em y = 1.80 e o centro em 1.44; o jogo
  desloca-os para a cabeça real (tabela "heads" em art/robots/roster.json);
- peças "spin_" giram no jogo.
O desgaste da pintura (arestas claras e lascas) é calculado no shader a partir da curvatura.

Coordenadas escritas em unidades do Godot: Y para cima, frente em -Z, direita em +X.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh  # depois do bpy: é o módulo bpy que o regista
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "art" / "robots" / "kit.glb"
ROSTER = ROOT / "art" / "robots" / "roster.json"

# Papéis de material. Os valores são só para a pré-visualização no Blender.
ROLES = {
    "shell": (0.93, 0.90, 0.82),
    "trim": (0.95, 0.45, 0.16),
    "dark": (0.12, 0.13, 0.17),
    "metal": (0.62, 0.66, 0.72),
    "glow": (0.3, 0.95, 1.0),
    "team": (0.3, 0.85, 0.78),
    "screen": (0.03, 0.04, 0.07),
    "rubber": (0.05, 0.05, 0.06),
    "hazard": (0.95, 0.75, 0.16),
    "label": (0.96, 0.95, 0.91),
}
EMISSIVE = {"glow"}
LEG_PIVOT = Vector((0.2, 0.42, 0.0))
MUZZLE = Vector((0.29, 0.70, -0.86))
HEAD_TOP = 1.80
HEAD_CENTER = 1.44

CONVERT = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Godot -> Blender
# Detalhe das primitivas: 1 no kit normal. LOW_DETAIL lista peças a gerar também com metade
# do detalhe, com o prefixo "lo_" (hoje nenhuma: os tijolos têm peças temáticas próprias).
DETAIL = 1.0
LOW_DETAIL = []


def seg(n, least=1):
    return max(least, int(round(n * DETAIL)))


def xform(at=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Transformação em espaço Godot: escala, depois rotação X, Y, Z (graus), depois posição."""
    rx, ry, rz = (math.radians(a) for a in rot)
    r = Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")
    s = Matrix.Diagonal((*scale, 1))
    return Matrix.Translation(Vector(at)) @ r @ s


class Part:
    """Acumula geometria de uma peça, separada por papel de material."""

    def __init__(self, name):
        self.name = name
        self.meshes = {}

    def add(self, role, bm, matrix):
        m = CONVERT @ matrix
        for v in bm.verts:
            v.co = m.to_3x3() @ v.co + m.translation
        if matrix.to_3x3().determinant() < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
        for f in bm.faces:
            f.smooth = True
        target = self.meshes.setdefault(role, bpy.data.meshes.new(f"{self.name}__{role}"))
        acc = bmesh.new()
        acc.from_mesh(target)
        tmp = bpy.data.meshes.new("tmp")
        bm.to_mesh(tmp)
        acc.from_mesh(tmp)
        acc.to_mesh(target)
        acc.free()
        bm.free()
        bpy.data.meshes.remove(tmp)

    # --- primitivas ------------------------------------------------------------------
    def box(self, role, at, size, radius=0.04, rot=(0, 0, 0), segments=3):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        r = min(radius, min(size) * 0.48)
        if r > 0.001:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, segments=seg(segments), profile=0.5,
                            affect="EDGES", clamp_overlap=True)
        self.add(role, bm, xform(at, rot))

    def ball(self, role, at, size, rot=(0, 0, 0), detail=16):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg(detail, 6), v_segments=max(4, seg(detail, 6) // 2), radius=0.5)
        self.add(role, bm, xform(at, rot, size))

    def tube(self, role, at, radius, length, rot=(0, 0, 0), detail=16, radius2=None, bevel=0.0, caps=True):
        """Cilindro ao longo do Y local (roda-o com `rot`)."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=caps, segments=seg(detail, 5), radius1=radius,
                              radius2=radius if radius2 is None else radius2, depth=length)
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
        if bevel > 0 and caps:
            rims = [e for e in bm.edges if len(e.link_faces) == 2 and
                    abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.5]
            bmesh.ops.bevel(bm, geom=rims, offset=bevel, segments=2, profile=0.5, affect="EDGES",
                            clamp_overlap=True)
        self.add(role, bm, xform(at, rot))

    def strut(self, role, a, b, radius, detail=12, radius2=None):
        """Cilindro (ou cone) de `a` a `b`: juntas, cabos, braços, chifres."""
        a, b = Vector(a), Vector(b)
        d = b - a
        q = Vector((0, 1, 0)).rotation_difference(d.normalized())
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg(detail, 5), radius1=radius,
                              radius2=radius if radius2 is None else radius2, depth=d.length)
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
        self.add(role, bm, Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())

    def path(self, role, points, radii, detail=12):
        """Tubo que segue uma lista de pontos, com raio a variar (chifres, cabos, asas de fio)."""
        for (a, ra), (b, rb) in zip(zip(points, radii), zip(points[1:], radii[1:])):
            self.strut(role, a, b, ra, detail, rb)
            self.ball(role, b, (rb * 2, rb * 2, rb * 2), detail=detail)

    def ring(self, role, at, major, minor, rot=(0, 0, 0), detail=24, sides=6):
        """Toro deitado no plano XZ local (eixo Y)."""
        detail, sides = seg(detail, 6), seg(sides, 3)
        bm = bmesh.new()
        verts = []
        for i in range(detail):
            a = i / detail * math.tau
            row = []
            for j in range(sides):
                b = j / sides * math.tau
                r = major + minor * math.cos(b)
                row.append(bm.verts.new((r * math.cos(a), minor * math.sin(b), r * math.sin(a))))
            verts.append(row)
        for i in range(detail):
            for j in range(sides):
                a, b = verts[i][j], verts[(i + 1) % detail][j]
                c, d = verts[(i + 1) % detail][(j + 1) % sides], verts[i][(j + 1) % sides]
                bm.faces.new((a, d, c, b))
        self.add(role, bm, xform(at, rot))

    def wedge(self, role, at, size, rot=(0, 0, 0), taper=0.0, radius=0.015):
        """Caixa cujo topo encolhe para `taper` (0 = aresta): cunhas, dentes, bicos, orelhas."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            k = taper if v.co.y > 0 else 1.0
            v.co = Vector((v.co.x * size[0] * k, v.co.y * size[1], v.co.z * size[2] * max(k, 0.35)))
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        if radius > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=radius, segments=seg(2), profile=0.5,
                            affect="EDGES", clamp_overlap=True)
        self.add(role, bm, xform(at, rot))

    def screen(self, at, size, bulge=0.02, rot=(0, 0, 0)):
        """Ecrã do rosto: grelha com UV 0-1, ligeiramente abaulada para a frente (-Z)."""
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        n = 10
        grid = [[bm.verts.new(((i / n - 0.5) * size[0], (j / n - 0.5) * size[1],
                               -bulge * (1 - (2 * i / n - 1) ** 2) * (1 - (2 * j / n - 1) ** 2)))
                 for j in range(n + 1)] for i in range(n + 1)]
        for i in range(n):
            for j in range(n):
                f = bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
                for loop, (u, v) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                    loop[uv].uv = (u / n, v / n)
        bm.normal_update()
        bm.faces.ensure_lookup_table()
        if bm.faces[0].normal.z > 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
        self.add("screen", bm, xform(at, rot))


PARTS = {}
HEADS = {}


def part(name):
    def register(fn):
        PARTS[name] = fn
        return fn
    return register


def sides():
    return (-1, 1)


# ======================================================================================
# CABEÇAS: caixa-televisor com ecrã, moldura, cantos de cor, painéis laterais e auscultadores.
# ======================================================================================
def head_common(p, name, center, size, radius, screen_size, ear=0.15, screws=True, vents=3, corners=True):
    cx, cy, cz = center
    w, h, d = size
    HEADS[name] = {"top": round(cy + h / 2, 3), "center": round(cy, 3), "aspect": round(screen_size[0] / screen_size[1], 3)}
    p.box("shell", center, size, radius, segments=4)
    front = cz - d / 2
    sw, sh = screen_size
    # Moldura em relevo e o ecrã, um pouco mais à frente.
    p.box("dark", (cx, cy - 0.01, front + 0.004), (sw + 0.1, sh + 0.1, 0.05), 0.045, segments=3)
    p.screen((cx, cy - 0.01, front - 0.024), (sw, sh), bulge=0.018)
    if screws:
        for sx in sides():
            for sy in sides():
                p.tube("metal", (cx + sx * (sw / 2 + 0.014), cy - 0.01 + sy * (sh / 2 + 0.014), front - 0.022),
                       0.017, 0.012, rot=(90, 0, 0), detail=10)
    if corners:
        # Cantos de cor na frente da caixa, como fita de sinalização num equipamento.
        for sx in sides():
            for sy in sides():
                p.box("trim", (cx + sx * (w / 2 - 0.05), cy + sy * (h / 2 - 0.05), front + 0.02),
                      (0.12, 0.12, 0.06), 0.03, segments=2)
    # Painéis laterais na cor de acento, por trás dos auscultadores.
    for side in sides():
        p.box("trim", (cx + side * (w / 2 + 0.006), cy - 0.02, cz + 0.06), (0.03, h * 0.62, d * 0.62), 0.012)
    if ear > 0:
        for side in sides():
            x = cx + side * (w / 2 + 0.03)
            p.tube("dark", (x, cy, cz + 0.02), ear, 0.1, rot=(0, 0, 90), detail=24, bevel=0.022)
            p.ring("glow", (x + side * 0.052, cy, cz + 0.02), ear * 0.72, 0.017, rot=(0, 0, 90), detail=28)
            p.tube("metal", (x + side * 0.056, cy, cz + 0.02), ear * 0.46, 0.03, rot=(0, 0, 90), detail=20, bevel=0.008)
    for i in range(vents):
        p.box("dark", (cx - (vents - 1) * 0.06 + i * 0.12, cy + h / 2 + 0.004, cz + 0.08), (0.07, 0.02, 0.2), 0.008)
    # Nuca: tampa de manutenção com uma risca de cor.
    p.box("dark", (cx, cy + 0.02, cz + d / 2 + 0.004), (w * 0.44, h * 0.34, 0.03), 0.012)
    p.box("trim", (cx, cy + 0.02 + h * 0.12, cz + d / 2 + 0.022), (w * 0.3, 0.035, 0.012), 0.005)


@part("head_box")
def _(p):
    head_common(p, "head_box", (0, 1.44, 0), (0.94, 0.72, 0.78), 0.13, (0.72, 0.5))


@part("head_wide")
def _(p):
    head_common(p, "head_wide", (0, 1.40, 0), (1.1, 0.62, 0.76), 0.12, (0.88, 0.42), ear=0.13, vents=4)


@part("head_tall")
def _(p):
    head_common(p, "head_tall", (0, 1.50, 0), (0.82, 0.86, 0.76), 0.14, (0.62, 0.62), ear=0.14)


@part("head_round")
def _(p):
    head_common(p, "head_round", (0, 1.44, 0), (0.96, 0.74, 0.8), 0.27, (0.68, 0.46), ear=0.15, screws=False, vents=0, corners=False)


@part("head_slant")
def _(p):
    # Testa em pala inclinada para a frente: de lado lê-se "zangado".
    head_common(p, "head_slant", (0, 1.44, 0.02), (0.9, 0.7, 0.82), 0.11, (0.68, 0.42), ear=0.13, corners=False)
    p.wedge("trim", (0, 1.82, -0.1), (0.84, 0.12, 0.5), rot=(-10, 0, 0), taper=0.65, radius=0.03)


@part("head_visor")
def _(p):
    # Cabeça pequena de tanque: uma fenda de visor em vez de um ecrã inteiro.
    head_common(p, "head_visor", (0, 1.32, 0.02), (0.82, 0.48, 0.72), 0.1, (0.62, 0.17), ear=0.1, screws=False, vents=2)
    p.box("trim", (0, 1.58, 0.02), (0.6, 0.06, 0.5), 0.02)


# ======================================================================================
# TOPOS (para uma cabeça com o topo em HEAD_TOP)
# ======================================================================================
T = HEAD_TOP


@part("top_antenna")
def _(p):
    p.tube("metal", (0.24, T + 0.02, 0.1), 0.055, 0.04, detail=14, bevel=0.01)
    p.tube("dark", (0.24, T + 0.16, 0.1), 0.02, 0.26, detail=8)
    p.ball("glow", (0.24, T + 0.3, 0.1), (0.09, 0.09, 0.09))


@part("top_handle")
def _(p):
    for side in sides():
        p.box("dark", (side * 0.36, T + 0.06, 0.06), (0.06, 0.14, 0.08), 0.02)
    p.box("dark", (0, T + 0.13, 0.06), (0.78, 0.06, 0.08), 0.025)
    p.box("trim", (0, T + 0.135, 0.06), (0.3, 0.075, 0.1), 0.03)


@part("top_dish")
def _(p):
    p.tube("dark", (-0.3, T + 0.07, 0.14), 0.022, 0.16, detail=8)
    p.tube("metal", (-0.33, T + 0.2, 0.14), 0.22, 0.05, rot=(0, 0, 25), detail=24, radius2=0.08)
    p.ball("glow", (-0.36, T + 0.25, 0.14), (0.07, 0.07, 0.07))


@part("top_leaves")
def _(p):
    # Duas folhas grandes como orelhas, e um rebento no meio.
    for side in sides():
        p.ball("shell", (side * 0.3, T + 0.2, 0.06), (0.24, 0.5, 0.07), rot=(0, side * 20, side * -24))
        p.box("glow", (side * 0.31, T + 0.2, 0.024), (0.02, 0.36, 0.012), 0.005, rot=(0, side * 20, side * -24))
        p.tube("dark", (side * 0.22, T + 0.02, 0.06), 0.05, 0.06, detail=12)
    p.tube("trim", (0, T + 0.1, 0.04), 0.02, 0.2, rot=(0, 0, 6), detail=8)
    p.ball("glow", (0.02, T + 0.21, 0.04), (0.1, 0.06, 0.08))


@part("top_beacon")
def _(p):
    # Pirilampo de obra: base, cúpula luminosa e grade.
    p.tube("dark", (0, T + 0.035, 0.0), 0.12, 0.07, detail=20, bevel=0.015)
    p.ball("glow", (0, T + 0.09, 0.0), (0.18, 0.2, 0.18))
    for i in range(4):
        a = i * 90 + 45
        p.box("metal", (math.cos(math.radians(a)) * 0.09, T + 0.12, math.sin(math.radians(a)) * 0.09), (0.02, 0.14, 0.02), 0.006)
    p.ring("metal", (0, T + 0.19, 0.0), 0.09, 0.012, detail=18, sides=4)


@part("top_horns")
def _(p):
    # Chifres curvos, grossos na base e a afinar para trás e para fora.
    for side in sides():
        pts = [(side * 0.3, T - 0.02, 0.0), (side * 0.4, T + 0.14, 0.04), (side * 0.47, T + 0.3, 0.16), (side * 0.46, T + 0.42, 0.34)]
        p.path("shell", pts, [0.085, 0.07, 0.048, 0.012], detail=12)
        p.path("trim", pts[2:], [0.05, 0.014], detail=12)
        p.tube("dark", (side * 0.3, T - 0.01, 0.0), 0.1, 0.06, detail=16)


@part("top_goggles")
def _(p):
    # Óculos de soldador na testa, presos por uma correia à volta da cabeça.
    for side in sides():
        p.box("dark", (side * 0.475, T - 0.1, 0.0), (0.03, 0.08, 0.74), 0.012)
        p.tube("metal", (side * 0.17, T - 0.02, -0.34), 0.12, 0.1, rot=(90, 0, 0), detail=20, bevel=0.02)
        p.tube("glow", (side * 0.17, T - 0.02, -0.395), 0.085, 0.01, rot=(90, 0, 0), detail=20)
        p.ring("dark", (side * 0.17, T - 0.02, -0.395), 0.1, 0.015, rot=(90, 0, 0), detail=20)
    p.box("dark", (0, T - 0.02, -0.34), (0.12, 0.05, 0.06), 0.015)
    p.box("dark", (0, T + 0.005, 0.0), (0.96, 0.03, 0.08), 0.01)


@part("top_bolts")
def _(p):
    # "Cabelo" em espigões varridos para trás, com raios luminosos.
    for i, (x, lean, height) in enumerate(((-0.26, -18, 0.3), (-0.09, -6, 0.42), (0.09, 6, 0.4), (0.26, 18, 0.28))):
        p.wedge("trim", (x, T + height / 2 - 0.04, -0.02), (0.16, height, 0.36), rot=(-32, 0, lean), taper=0.0, radius=0.02)
    for x in (-0.18, 0.18):
        p.box("glow", (x, T + 0.12, -0.2), (0.025, 0.12, 0.02), 0.006, rot=(-30, 0, x * 60))


@part("top_cat")
def _(p):
    # Orelhas triangulares e auscultadores grandes presos por uma bandolete.
    for side in sides():
        p.wedge("shell", (side * 0.27, T + 0.13, 0.04), (0.28, 0.3, 0.2), rot=(0, 0, side * -12), taper=0.0, radius=0.035)
        p.wedge("glow", (side * 0.27, T + 0.11, -0.05), (0.14, 0.18, 0.04), rot=(0, 0, side * -12), taper=0.0, radius=0.01)
        p.tube("dark", (side * 0.54, T - 0.36, 0.02), 0.2, 0.12, rot=(0, 0, 90), detail=28, bevel=0.03)
        p.ring("trim", (side * 0.605, T - 0.36, 0.02), 0.18, 0.02, rot=(0, 0, 90), detail=28)
        p.tube("glow", (side * 0.61, T - 0.36, 0.02), 0.11, 0.01, rot=(0, 0, 90), detail=24)
    band = [(-0.56, T - 0.22, 0.02), (-0.48, T + 0.02, 0.02), (-0.2, T + 0.1, 0.02), (0.2, T + 0.1, 0.02), (0.48, T + 0.02, 0.02), (0.56, T - 0.22, 0.02)]
    p.path("dark", band, [0.035] * len(band), detail=10)


@part("top_hood")
def _(p):
    # Capuz de lona sobre a cabeça, aberto à frente, com a ponta caída para trás.
    p.box("trim", (0, 1.5, 0.06), (1.08, 0.72, 0.84), 0.24, segments=4)
    p.box("trim", (0, 1.13, 0.28), (0.96, 0.34, 0.34), 0.12)
    p.wedge("trim", (0, 1.66, 0.52), (0.36, 0.34, 0.24), rot=(70, 0, 0), taper=0.15, radius=0.04)
    p.ring("dark", (0, 1.44, -0.35), 0.44, 0.03, rot=(90, 0, 0), detail=36)


@part("top_crest")
def _(p):
    # Crista central em lâmina e duas asinhas laterais.
    p.wedge("trim", (0, T + 0.16, 0.05), (0.07, 0.34, 0.52), rot=(-12, 0, 0), taper=0.2, radius=0.02)
    p.box("glow", (0, T + 0.12, -0.2), (0.075, 0.1, 0.02), 0.008)
    for side in sides():
        p.wedge("shell", (side * 0.3, T + 0.05, 0.08), (0.08, 0.16, 0.26), rot=(-20, 0, side * -30), taper=0.2, radius=0.015)


@part("top_fins")
def _(p):
    for side in sides():
        p.wedge("shell", (side * 0.3, T + 0.08, 0.12), (0.1, 0.36, 0.28), rot=(-22, 0, side * -14), taper=0.3, radius=0.03)
        p.wedge("team", (side * 0.3, T + 0.09, 0.03), (0.04, 0.26, 0.12), rot=(-22, 0, side * -14), taper=0.3, radius=0.01)


@part("top_mohawk")
def _(p):
    for i in range(4):
        p.wedge("team", (0, T + 0.04 + (i % 2) * 0.01, -0.22 + i * 0.15), (0.07, 0.24 - i * 0.03, 0.15), rot=(-15, 0, 0), taper=0.3, radius=0.012)


@part("top_rods")
def _(p):
    for side in sides():
        x = side * 0.3
        pts = [(x, T - 0.04, 0.05), (x + side * 0.04, T + 0.08, 0.05), (x - side * 0.02, T + 0.15, 0.05), (x + side * 0.05, T + 0.28, 0.05)]
        p.path("metal", pts, [0.024] * 4, detail=8)
        p.ball("glow", pts[-1], (0.07, 0.07, 0.07))


@part("top_sprout")
def _(p):
    p.tube("team", (0, T + 0.05, 0.05), 0.022, 0.24, rot=(0, 0, 8), detail=8)
    for side, lift in ((-1, T + 0.17), (1, T + 0.21)):
        p.ball("glow", (side * 0.1, lift, 0.05), (0.2, 0.05, 0.12), rot=(0, 0, side * -25))


@part("spin_rays")
def _(p):
    p.ring("metal", (0, HEAD_CENTER, 0.42), 0.5, 0.025, rot=(90, 0, 0), detail=40)
    for i in range(12):
        a = i / 12 * 360
        r = math.radians(a)
        p.wedge("glow", (math.cos(r) * 0.62, HEAD_CENTER + math.sin(r) * 0.62, 0.42), (0.08, 0.22, 0.03), rot=(0, 0, a - 90), taper=0.0, radius=0.0)


@part("spin_laurel")
def _(p):
    p.ring("metal", (0, T + 0.12, 0), 0.34, 0.03, detail=36)
    for i in range(10):
        r = i / 10 * math.tau
        p.ball("metal", (math.cos(r) * 0.36, T + 0.15, math.sin(r) * 0.36), (0.13, 0.05, 0.07), rot=(0, -math.degrees(r), 20))


@part("spin_orbit")
def _(p):
    p.ring("glow", (0, HEAD_CENTER - 0.02, 0), 0.64, 0.014, rot=(0, 0, 18), detail=48)
    for a in (40, 220):
        r = math.radians(a)
        x, z = math.cos(r) * 0.64, math.sin(r) * 0.64
        p.ball("metal", (x, HEAD_CENTER - 0.02 + x * math.tan(math.radians(18)), z), (0.11, 0.11, 0.11))


@part("spin_halo")
def _(p):
    p.ring("dark", (0, HEAD_CENTER + 0.06, 0.44), 0.4, 0.045, rot=(90, 0, 0), detail=40)
    p.ring("glow", (0, HEAD_CENTER + 0.06, 0.47), 0.4, 0.018, rot=(90, 0, 0), detail=40)
    for i in range(8):
        a = i / 8 * 360
        r = math.radians(a)
        p.wedge("trim", (math.cos(r) * 0.49, HEAD_CENTER + 0.06 + math.sin(r) * 0.49, 0.44), (0.05, 0.12, 0.03), rot=(0, 0, a - 90), taper=0.0, radius=0.0)


# ======================================================================================
# TRONCOS (peito centrado em y ~ 0.8)
# ======================================================================================
def torso_common(p, width=0.62, height=0.38, depth=0.46, chest_y=0.8):
    p.box("dark", (0, 0.5, 0), (0.46, 0.13, 0.34), 0.045)               # bacia
    for side in sides():
        p.box("trim", (side * 0.17, 0.5, -0.12), (0.14, 0.1, 0.12), 0.03)  # placas das ancas
    p.tube("dark", (0, 0.6, 0), 0.17, 0.14, detail=18)                  # abdómen articulado
    for y in (0.565, 0.635):
        p.ring("metal", (0, y, 0), 0.175, 0.009, detail=24, sides=4)
    p.box("shell", (0, chest_y, 0), (width, height, depth), 0.11, segments=4)
    p.tube("dark", (0, chest_y + height / 2 + 0.04, 0), 0.21, 0.07, detail=20)  # gola
    p.tube("dark", (0, 1.06, 0), 0.09, 0.1, detail=12)                     # pescoço
    for side in sides():
        p.ball("dark", (side * 0.38, 0.92, 0), (0.2, 0.2, 0.2))            # articulação do ombro
    p.box("team", (0, 0.5, -0.172), (0.22, 0.06, 0.02), 0.008)             # faixa de equipa no cinto


@part("torso_std")
def _(p):
    torso_common(p)
    p.box("trim", (0, 0.8, -0.235), (0.4, 0.22, 0.06), 0.03)
    p.wedge("glow", (0, 0.8, -0.268), (0.13, 0.11, 0.02), rot=(0, 0, 180), taper=0.0, radius=0.0)
    p.box("dark", (0, 0.81, 0.235), (0.36, 0.22, 0.04), 0.02)


@part("torso_heavy")
def _(p):
    torso_common(p, width=0.8, height=0.44, depth=0.54, chest_y=0.81)
    p.box("shell", (0, 0.9, -0.24), (0.66, 0.16, 0.1), 0.04)
    for side in sides():
        for i in range(3):
            p.box("dark", (side * 0.2, 0.8 - i * 0.055, -0.272), (0.18, 0.025, 0.02), 0.006)
    for i in range(5):
        p.box("trim" if i % 2 else "dark", (-0.16 + i * 0.08, 0.66, -0.272), (0.07, 0.08, 0.02), 0.005, rot=(0, 0, 35))


@part("torso_slim")
def _(p):
    torso_common(p, width=0.54, height=0.36, depth=0.42)
    for i in range(3):
        p.box("trim", (0, 0.9 - i * 0.075, -0.215), (0.34 - i * 0.05, 0.045, 0.04), 0.015)
    p.ball("glow", (0, 0.68, -0.21), (0.08, 0.08, 0.04))


@part("torso_barrel")
def _(p):
    torso_common(p, width=0.01, height=0.01, depth=0.01)
    p.ball("shell", (0, 0.8, 0), (0.7, 0.48, 0.54), detail=28)
    p.ring("trim", (0, 0.8, 0), 0.34, 0.035, detail=36)
    p.tube("trim", (0, 0.82, -0.26), 0.09, 0.04, rot=(90, 0, 0), detail=24)
    p.tube("glow", (0, 0.82, -0.285), 0.06, 0.01, rot=(90, 0, 0), detail=20)


@part("torso_core")
def _(p):
    torso_common(p, width=0.64, height=0.4, depth=0.48)
    p.ring("trim", (0, 0.8, -0.245), 0.13, 0.03, rot=(90, 0, 0), detail=32)
    p.tube("glow", (0, 0.8, -0.245), 0.1, 0.03, rot=(90, 0, 0), detail=28)
    for side in sides():
        p.box("trim", (side * 0.24, 0.86, -0.23), (0.1, 0.2, 0.05), 0.02, rot=(0, 0, side * 12))


# ======================================================================================
# OMBREIRAS (sobre as articulações em (±0.38, 0.92))
# ======================================================================================
@part("shoulders_round")
def _(p):
    for side in sides():
        p.box("trim", (side * 0.48, 1.0, 0), (0.3, 0.22, 0.36), 0.1, segments=4)
        p.box("team", (side * 0.48, 1.0, -0.185), (0.16, 0.05, 0.02), 0.008)


@part("shoulders_block")
def _(p):
    for side in sides():
        p.box("trim", (side * 0.52, 1.02, 0), (0.34, 0.3, 0.4), 0.06)
        p.box("shell", (side * 0.52, 1.18, 0), (0.28, 0.04, 0.34), 0.012)
        for i in range(3):
            p.box("team", (side * 0.692, 1.06 - i * 0.055, -0.06 + i * 0.06), (0.02, 0.028, 0.1), 0.006)


@part("shoulders_speaker")
def _(p):
    for side in sides():
        p.box("dark", (side * 0.5, 1.0, 0), (0.28, 0.3, 0.3), 0.06)
        p.tube("trim", (side * 0.645, 1.0, 0), 0.12, 0.02, rot=(0, 0, 90), detail=24)
        p.tube("dark", (side * 0.655, 1.0, 0), 0.095, 0.03, rot=(0, 0, 90), detail=24, radius2=0.035)
        p.ring("glow", (side * 0.66, 1.0, 0), 0.12, 0.012, rot=(0, 0, 90), detail=28)


@part("shoulders_pod")
def _(p):
    # Lança-mísseis de quatro tubos no ombro esquerdo; ombreira em bloco no direito.
    p.box("trim", (-0.54, 1.08, 0.02), (0.34, 0.3, 0.4), 0.05)
    for i in range(2):
        for j in range(2):
            p.tube("dark", (-0.62 + i * 0.15, 1.02 + j * 0.12, -0.18), 0.05, 0.05, rot=(90, 0, 0), detail=12)
            p.ball("glow", (-0.62 + i * 0.15, 1.02 + j * 0.12, -0.205), (0.055, 0.055, 0.02))
    p.box("shell", (-0.54, 1.24, 0.02), (0.28, 0.035, 0.34), 0.01)
    p.box("trim", (0.5, 1.02, 0), (0.3, 0.26, 0.38), 0.06)
    p.box("team", (0.5, 1.02, -0.2), (0.16, 0.05, 0.02), 0.008)


@part("shoulders_spike")
def _(p):
    for side in sides():
        p.box("trim", (side * 0.49, 1.0, 0), (0.3, 0.22, 0.36), 0.08, segments=3)
        for k, z in enumerate((-0.1, 0.02, 0.14)):
            p.wedge("shell", (side * (0.55 + k * 0.01), 1.17, z), (0.08, 0.2 - k * 0.03, 0.08), rot=(0, 0, side * -25), taper=0.0, radius=0.01)


@part("shoulders_wing")
def _(p):
    for side in sides():
        p.box("trim", (side * 0.48, 1.0, 0), (0.28, 0.2, 0.34), 0.09, segments=3)
        for k in range(2):
            p.wedge("shell", (side * (0.62 + k * 0.05), 1.15 + k * 0.05, 0.14 + k * 0.08), (0.05, 0.46 - k * 0.1, 0.14),
                    rot=(-40, 0, side * (-38 - k * 12)), taper=0.1, radius=0.012)


# ======================================================================================
# COSTAS
# ======================================================================================
@part("back_pack")
def _(p):
    p.box("dark", (0, 0.82, 0.3), (0.44, 0.38, 0.17), 0.05)
    p.box("trim", (0, 0.92, 0.39), (0.32, 0.06, 0.03), 0.01)
    for x in (-0.13, 0.13):
        p.tube("metal", (x, 0.66, 0.33), 0.055, 0.08, detail=14, radius2=0.07)


@part("back_tanks")
def _(p):
    p.box("dark", (0, 0.84, 0.27), (0.42, 0.32, 0.1), 0.03)
    for x in (-0.13, 0.13):
        p.tube("metal", (x, 0.82, 0.36), 0.08, 0.42, detail=18, bevel=0.025)
        p.ring("trim", (x, 0.9, 0.36), 0.083, 0.012, detail=18, sides=4)


@part("back_planter")
def _(p):
    p.tube("trim", (0, 0.86, 0.35), 0.17, 0.26, detail=20, radius2=0.2, bevel=0.02)
    p.tube("dark", (0, 1.0, 0.35), 0.18, 0.03, detail=20)
    for i in range(6):
        r = i / 6 * math.tau
        p.ball("glow", (math.cos(r) * 0.09, 1.07, 0.35 + math.sin(r) * 0.09), (0.14, 0.05, 0.09), rot=(0, -math.degrees(r), 35))


@part("back_toolbox")
def _(p):
    p.box("trim", (0, 0.82, 0.34), (0.46, 0.3, 0.21), 0.03)
    p.box("dark", (0, 0.98, 0.34), (0.48, 0.03, 0.23), 0.01)
    p.strut("metal", (-0.12, 1.01, 0.34), (0.12, 1.01, 0.34), 0.018)
    p.box("metal", (0.2, 1.16, 0.34), (0.05, 0.34, 0.02), 0.01, rot=(0, 0, -20))
    p.ring("metal", (0.26, 1.33, 0.34), 0.055, 0.02, rot=(90, 0, 0), detail=16)


@part("back_coil")
def _(p):
    p.box("dark", (0, 0.8, 0.28), (0.4, 0.34, 0.12), 0.04)
    p.tube("metal", (0, 1.05, 0.34), 0.04, 0.44, detail=10)
    for i in range(4):
        p.ring("glow", (0, 0.9 + i * 0.085, 0.34), 0.095 - i * 0.012, 0.013, detail=18)
    p.ball("glow", (0, 1.29, 0.34), (0.11, 0.11, 0.11))


@part("back_cape")
def _(p):
    # Capa de campeão: painéis rígidos com orla dourada e brasão.
    for x in (-0.21, 0.0, 0.21):
        p.box("trim", (x, 0.64, 0.31 + abs(x) * 0.12), (0.22, 0.74, 0.03), 0.012, rot=(-8, x * 40, 0))
        p.box("metal", (x, 0.28, 0.36 + abs(x) * 0.12), (0.22, 0.04, 0.035), 0.01, rot=(-8, x * 40, 0))
    p.box("metal", (0, 1.0, 0.28), (0.54, 0.06, 0.07), 0.018)
    p.tube("glow", (0, 0.72, 0.335), 0.06, 0.02, rot=(90, 0, 0), detail=16)


@part("back_rags")
def _(p):
    # Capa de lona rasgada, com pontas de comprimentos diferentes.
    for x, length in ((-0.22, 0.62), (-0.08, 0.78), (0.07, 0.56), (0.21, 0.7)):
        p.box("trim", (x, 0.98 - length / 2, 0.3 + abs(x) * 0.1), (0.15, length, 0.025), 0.01, rot=(-10, x * 50, x * 20))
        p.wedge("trim", (x, 0.98 - length - 0.04, 0.3 + abs(x) * 0.1 + 0.04), (0.15, 0.1, 0.025), rot=(170, x * 50, 0), taper=0.0, radius=0.0)


@part("back_scarf")
def _(p):
    # Cachecol enrolado ao pescoço, com duas pontas caídas atrás.
    p.ring("trim", (0, 1.04, 0.0), 0.2, 0.06, detail=24, sides=8)
    for x, length, lean in ((-0.08, 0.46, 6), (0.08, 0.36, -10)):
        p.box("trim", (x, 1.0 - length / 2, 0.26), (0.13, length, 0.03), 0.012, rot=(-18, 0, lean))
        p.box("dark", (x, 1.0 - length + 0.03, 0.26 + length * 0.3), (0.13, 0.03, 0.035), 0.008, rot=(-18, 0, lean))


@part("back_thruster")
def _(p):
    p.box("dark", (0, 0.84, 0.28), (0.46, 0.32, 0.12), 0.04)
    for x in (-0.15, 0.15):
        p.tube("metal", (x, 0.74, 0.37), 0.085, 0.32, detail=16, bevel=0.02)
        p.tube("dark", (x, 0.55, 0.37), 0.075, 0.08, detail=16, radius2=0.095)
        p.tube("glow", (x, 0.505, 0.37), 0.065, 0.01, detail=16)


# ======================================================================================
# BRAÇOS: o esquerdo completo, com punho grande; o direito só até ao cotovelo (a arma faz de
# antebraço).
# ======================================================================================
def arm_right(p, shoulder_x=0.38):
    p.strut("dark", (shoulder_x, 0.92, 0), (0.3, 0.75, -0.14), 0.065)
    p.ball("dark", (0.3, 0.74, -0.15), (0.14, 0.14, 0.14))


def fist(p, at, size, fingers=4):
    x, y, z = at
    w, h, d = size
    p.box("dark", at, size, 0.045)
    for i in range(fingers):
        p.box("dark", (x - w / 2 + w * (i + 0.5) / fingers, y - h * 0.4, z - d * 0.38), (w / fingers * 0.8, h * 0.45, d * 0.3), 0.018)
    p.box("metal", (x + w * 0.52, y + h * 0.05, z - d * 0.2), (0.04, h * 0.5, d * 0.35), 0.015)


@part("arm_std")
def _(p):
    p.strut("dark", (-0.38, 0.92, 0), (-0.46, 0.72, -0.02), 0.065)
    p.ball("dark", (-0.46, 0.71, -0.02), (0.13, 0.13, 0.13))
    p.box("shell", (-0.48, 0.58, -0.05), (0.21, 0.24, 0.24), 0.07)
    p.box("trim", (-0.48, 0.66, -0.05), (0.225, 0.06, 0.255), 0.02)
    p.box("team", (-0.48, 0.55, -0.172), (0.12, 0.04, 0.015), 0.006)
    fist(p, (-0.48, 0.41, -0.07), (0.18, 0.15, 0.2))
    arm_right(p)


@part("arm_heavy")
def _(p):
    p.strut("dark", (-0.44, 0.96, 0), (-0.54, 0.72, -0.02), 0.08)
    p.ball("dark", (-0.54, 0.71, -0.02), (0.16, 0.16, 0.16))
    p.box("shell", (-0.56, 0.56, -0.05), (0.28, 0.28, 0.3), 0.07)
    p.box("trim", (-0.56, 0.66, -0.05), (0.3, 0.06, 0.32), 0.02)
    p.box("team", (-0.56, 0.53, -0.203), (0.14, 0.04, 0.015), 0.006)
    fist(p, (-0.56, 0.37, -0.07), (0.24, 0.19, 0.25))
    arm_right(p, 0.44)


@part("arm_claw")
def _(p):
    p.strut("dark", (-0.38, 0.92, 0), (-0.46, 0.72, -0.02), 0.065)
    p.ball("dark", (-0.46, 0.71, -0.02), (0.13, 0.13, 0.13))
    p.box("shell", (-0.48, 0.58, -0.05), (0.2, 0.24, 0.24), 0.07)
    p.box("trim", (-0.48, 0.66, -0.05), (0.215, 0.06, 0.255), 0.02)
    p.tube("dark", (-0.48, 0.44, -0.06), 0.07, 0.06, detail=14)
    for i, a in enumerate((-35, 0, 35)):
        r = math.radians(a)
        p.wedge("metal", (-0.48 + math.sin(r) * 0.07, 0.35, -0.06 - math.cos(r) * 0.03), (0.05, 0.16, 0.05), rot=(160, a, 0), taper=0.0, radius=0.01)
    arm_right(p)


@part("arm_slim")
def _(p):
    p.strut("dark", (-0.36, 0.92, 0), (-0.44, 0.7, -0.02), 0.05)
    p.ball("dark", (-0.44, 0.69, -0.02), (0.11, 0.11, 0.11))
    p.box("shell", (-0.46, 0.57, -0.04), (0.15, 0.22, 0.18), 0.05)
    p.box("team", (-0.46, 0.57, -0.133), (0.08, 0.04, 0.015), 0.006)
    fist(p, (-0.46, 0.42, -0.05), (0.13, 0.12, 0.15), fingers=3)
    arm_right(p, 0.36)


# ======================================================================================
# PERNAS (espaço da perna: pivô da anca na origem, chão em y = -LEG_PIVOT.y)
# ======================================================================================
F = -LEG_PIVOT.y  # altura do chão no espaço da perna


def knee(p, shin=(0.23, 0.22, 0.25)):
    p.ball("dark", (0, 0, 0), (0.2, 0.2, 0.2))
    p.strut("dark", (0, 0, 0), (0, -0.17, -0.01), 0.075)
    p.ball("dark", (0, -0.17, -0.01), (0.17, 0.17, 0.17))
    p.box("shell", (0, -0.27, 0.0), shin, 0.07, segments=3)
    p.box("trim", (0, -0.17, -0.11), (0.15, 0.11, 0.07), 0.03)


@part("leg_std")
def _(p):
    knee(p)
    p.strut("dark", (0, -0.33, 0), (0, F + 0.1, -0.02), 0.065)
    p.box("trim", (0, F + 0.07, -0.07), (0.29, 0.12, 0.44), 0.06)
    p.box("dark", (0, F + 0.02, -0.07), (0.3, 0.04, 0.45), 0.015)
    p.box("dark", (0, F + 0.08, -0.23), (0.012, 0.06, 0.1), 0.004)
    p.box("metal", (0, F + 0.07, 0.14), (0.18, 0.08, 0.08), 0.02)


@part("leg_heavy")
def _(p):
    knee(p, shin=(0.3, 0.24, 0.3))
    p.strut("dark", (0, -0.34, 0), (0, F + 0.12, -0.02), 0.08)
    p.box("trim", (0, F + 0.08, -0.07), (0.36, 0.14, 0.5), 0.06)
    p.box("dark", (0, F + 0.022, -0.07), (0.37, 0.045, 0.51), 0.015)
    for x in (-0.1, 0.0, 0.1):
        p.wedge("metal", (x, F + 0.06, -0.33), (0.08, 0.1, 0.08), rot=(-90, 0, 0), taper=0.3, radius=0.012)
    p.box("metal", (0, F + 0.08, 0.17), (0.24, 0.1, 0.1), 0.025)


@part("leg_slim")
def _(p):
    p.ball("dark", (0, 0, 0), (0.17, 0.17, 0.17))
    p.box("shell", (0, -0.12, -0.02), (0.17, 0.2, 0.19), 0.055)
    p.strut("dark", (0, -0.1, 0), (0, F + 0.08, 0.02), 0.05)
    p.ball("dark", (0, -0.25, 0.01), (0.12, 0.12, 0.12))
    p.box("dark", (0, F + 0.025, -0.04), (0.2, 0.05, 0.32), 0.02)
    p.wedge("trim", (0, F + 0.05, -0.2), (0.17, 0.07, 0.12), rot=(-90, 0, 0), taper=0.3, radius=0.012)


@part("leg_wheel")
def _(p):
    knee(p)
    p.strut("dark", (0, -0.33, 0), (0, F + 0.1, -0.02), 0.065)
    p.box("trim", (0, F + 0.07, -0.08), (0.26, 0.12, 0.38), 0.05)
    p.box("dark", (0, F + 0.02, -0.08), (0.27, 0.04, 0.39), 0.015)
    for z in (-0.18, 0.1):
        p.tube("dark", (0.15, F + 0.08, z), 0.08, 0.06, rot=(0, 0, 90), detail=18, bevel=0.015)
        p.tube("metal", (0.185, F + 0.08, z), 0.04, 0.02, rot=(0, 0, 90), detail=12)


@part("leg_bird")
def _(p):
    # Perna de pássaro: joelho para trás e pé com três garras.
    p.ball("dark", (0, 0, 0), (0.19, 0.19, 0.19))
    p.box("shell", (0, -0.08, 0.06), (0.2, 0.22, 0.22), 0.06, rot=(-30, 0, 0))
    p.strut("dark", (0, -0.1, 0.08), (0, -0.2, 0.14), 0.06)
    p.ball("dark", (0, -0.2, 0.14), (0.14, 0.14, 0.14))
    p.box("trim", (0, -0.28, 0.06), (0.16, 0.24, 0.14), 0.05, rot=(28, 0, 0))
    p.strut("dark", (0, -0.2, 0.14), (0, F + 0.07, -0.02), 0.05)
    p.ball("dark", (0, F + 0.07, -0.02), (0.11, 0.11, 0.11))
    for a in (-28, 0, 28):
        r = math.radians(a)
        p.wedge("metal", (math.sin(r) * 0.1, F + 0.035, -0.02 - math.cos(r) * 0.14), (0.06, 0.2, 0.05), rot=(-95, a, 0), taper=0.1, radius=0.01)
    p.wedge("metal", (0, F + 0.035, 0.1), (0.05, 0.12, 0.05), rot=(95, 0, 0), taper=0.1, radius=0.01)


@part("leg_tread")
def _(p):
    # Lagarta de tanque em vez de pé.
    p.ball("dark", (0, 0, 0), (0.2, 0.2, 0.2))
    p.strut("dark", (0, 0, 0), (0, -0.2, 0), 0.08)
    p.box("trim", (0, -0.14, -0.02), (0.22, 0.14, 0.2), 0.05)
    p.box("dark", (0, F + 0.11, -0.04), (0.26, 0.2, 0.56), 0.09, segments=4)
    for z in (-0.24, -0.08, 0.08):
        p.tube("metal", (0.135, F + 0.1, z - 0.04 + 0.08), 0.07, 0.03, rot=(0, 0, 90), detail=16)
    for i in range(9):
        p.box("metal", (0, F + 0.215, -0.28 + i * 0.065), (0.27, 0.02, 0.03), 0.006)
    p.box("shell", (0, F + 0.24, -0.04), (0.3, 0.04, 0.5), 0.02)


@part("leg_hover")
def _(p):
    # Propulsor em vez de perna: o robô flutua sobre um cone de luz.
    p.ball("dark", (0, 0, 0), (0.18, 0.18, 0.18))
    p.tube("shell", (0, -0.14, 0), 0.14, 0.2, detail=20, radius2=0.1, bevel=0.02)
    p.ring("trim", (0, -0.06, 0), 0.14, 0.02, detail=20)
    p.tube("dark", (0, -0.27, 0), 0.1, 0.07, detail=20, radius2=0.13)
    p.tube("glow", (0, -0.31, 0), 0.1, 0.015, detail=20)
    p.tube("glow", (0, -0.36, 0), 0.07, 0.06, detail=16, radius2=0.0)


# ======================================================================================
# ARMAS (espaço do Gun; boca em MUZZLE)
# ======================================================================================
def gun_base(p, casing=(0.26, 0.26, 0.42), z=-0.36):
    p.box("shell", (0.29, 0.70, z), casing, 0.075, segments=3)
    p.box("trim", (0.29, 0.70, z - casing[2] * 0.3), (casing[0] + 0.015, casing[1] + 0.015, 0.06), 0.03)
    p.box("team", (0.29, 0.70 + casing[1] / 2 + 0.004, z + 0.04), (0.06, 0.012, casing[2] * 0.5), 0.004)


@part("gun_cannon")
def _(p):
    gun_base(p)
    p.tube("dark", (0.29, 0.70, -0.66), 0.11, 0.2, rot=(90, 0, 0), detail=20, bevel=0.015)
    p.ring("trim", (0.29, 0.70, -0.77), 0.11, 0.028, rot=(90, 0, 0), detail=24)
    p.tube("glow", (0.29, 0.70, -0.795), 0.075, 0.01, rot=(90, 0, 0), detail=20)
    p.box("glow", (0.425, 0.70, -0.3), (0.012, 0.05, 0.2), 0.004)


@part("gun_twin")
def _(p):
    gun_base(p, (0.3, 0.24, 0.4))
    for dx in (-0.07, 0.07):
        p.tube("dark", (0.29 + dx, 0.70, -0.67), 0.06, 0.28, rot=(90, 0, 0), detail=14)
        p.ring("trim", (0.29 + dx, 0.70, -0.8), 0.06, 0.015, rot=(90, 0, 0), detail=16)
        p.tube("glow", (0.29 + dx, 0.70, -0.81), 0.038, 0.01, rot=(90, 0, 0), detail=12)
    p.box("metal", (0.29, 0.845, -0.38), (0.09, 0.06, 0.22), 0.02)


@part("gun_scope")
def _(p):
    gun_base(p, (0.22, 0.22, 0.38))
    p.tube("dark", (0.29, 0.70, -0.68), 0.065, 0.36, rot=(90, 0, 0), detail=16, radius2=0.08)
    p.ring("metal", (0.29, 0.70, -0.81), 0.085, 0.015, rot=(90, 0, 0), detail=20)
    p.tube("glow", (0.29, 0.70, -0.855), 0.058, 0.01, rot=(90, 0, 0), detail=16)
    p.tube("metal", (0.29, 0.875, -0.42), 0.045, 0.3, rot=(90, 0, 0), detail=14)
    p.ball("glow", (0.29, 0.875, -0.575), (0.065, 0.065, 0.02))


@part("gun_seed")
def _(p):
    p.ball("shell", (0.29, 0.70, -0.4), (0.32, 0.3, 0.48))
    p.ring("trim", (0.29, 0.70, -0.4), 0.15, 0.025, rot=(90, 0, 0), detail=24)
    p.tube("dark", (0.29, 0.70, -0.67), 0.075, 0.12, rot=(90, 0, 0), detail=16, radius2=0.11)
    p.ball("glow", (0.29, 0.70, -0.75), (0.13, 0.13, 0.08))
    for i in range(3):
        r = i / 3 * math.tau
        p.ball("glow", (0.29 + math.cos(r) * 0.13, 0.70 + math.sin(r) * 0.13, -0.3), (0.15, 0.05, 0.08), rot=(0, 0, math.degrees(r)))


@part("gun_drill")
def _(p):
    gun_base(p, (0.32, 0.32, 0.44), -0.34)
    p.tube("metal", (0.29, 0.70, -0.6), 0.13, 0.1, rot=(90, 0, 0), detail=20)
    p.tube("trim", (0.29, 0.70, -0.77), 0.12, 0.28, rot=(90, 0, 0), detail=16, radius2=0.015)
    for i in range(3):
        p.ring("dark", (0.29, 0.70, -0.69 - i * 0.065), 0.09 - i * 0.027, 0.013, rot=(90, 0, 0), detail=16, sides=4)


@part("gun_lance")
def _(p):
    gun_base(p, (0.22, 0.22, 0.36))
    p.tube("dark", (0.29, 0.70, -0.63), 0.038, 0.3, rot=(90, 0, 0), detail=10)
    p.ring("glow", (0.29, 0.70, -0.72), 0.11, 0.02, rot=(90, 0, 0), detail=24)
    p.tube("metal", (0.29, 0.70, -0.83), 0.055, 0.14, rot=(90, 0, 0), detail=10, radius2=0.0)


@part("gun_wrench")
def _(p):
    gun_base(p, (0.26, 0.28, 0.38))
    for i in range(4):
        p.ring("metal", (0.29, 0.70, -0.57 - i * 0.05), 0.08, 0.017, rot=(90, 0, 0), detail=16)
    p.tube("dark", (0.29, 0.70, -0.73), 0.065, 0.16, rot=(90, 0, 0), detail=14)
    p.tube("glow", (0.29, 0.70, -0.815), 0.048, 0.01, rot=(90, 0, 0), detail=14)
    p.box("trim", (0.29, 0.88, -0.3), (0.13, 0.08, 0.13), 0.02)
    p.ring("metal", (0.29, 0.94, -0.3), 0.055, 0.015, rot=(90, 0, 0), detail=14)


@part("gun_tesla")
def _(p):
    gun_base(p, (0.24, 0.24, 0.36))
    p.tube("metal", (0.29, 0.70, -0.67), 0.038, 0.34, rot=(90, 0, 0), detail=10)
    for i in range(4):
        p.ring("glow", (0.29, 0.70, -0.57 - i * 0.07), 0.075 - i * 0.006, 0.014, rot=(90, 0, 0), detail=18)
    p.ball("glow", (0.29, 0.70, -0.85), (0.11, 0.11, 0.11))


@part("gun_horn")
def _(p):
    gun_base(p, (0.26, 0.26, 0.36))
    p.tube("dark", (0.29, 0.70, -0.67), 0.065, 0.24, rot=(90, 0, 0), detail=20, radius2=0.17)
    p.ring("trim", (0.29, 0.70, -0.79), 0.17, 0.02, rot=(90, 0, 0), detail=28)
    p.tube("glow", (0.29, 0.70, -0.78), 0.13, 0.01, rot=(90, 0, 0), detail=24)


@part("gun_blunder")
def _(p):
    p.box("trim", (0.29, 0.66, -0.3), (0.18, 0.22, 0.32), 0.04)
    p.tube("metal", (0.29, 0.70, -0.6), 0.065, 0.34, rot=(90, 0, 0), detail=16, radius2=0.14)
    p.ring("metal", (0.29, 0.70, -0.78), 0.14, 0.022, rot=(90, 0, 0), detail=24)
    p.tube("glow", (0.29, 0.70, -0.775), 0.11, 0.01, rot=(90, 0, 0), detail=20)
    p.ring("metal", (0.29, 0.5, -0.42), 0.075, 0.018, rot=(0, 0, 90), detail=16)
    p.wedge("metal", (0.29, 0.43, -0.44), (0.03, 0.08, 0.06), rot=(180, 0, 0), taper=0.0, radius=0.005)


@part("gun_scepter")
def _(p):
    gun_base(p, (0.22, 0.22, 0.34))
    p.tube("metal", (0.29, 0.70, -0.63), 0.032, 0.32, rot=(90, 0, 0), detail=10)
    p.ball("glow", (0.29, 0.70, -0.81), (0.17, 0.17, 0.17))
    for i in range(8):
        a = i / 8 * 360
        r = math.radians(a)
        p.wedge("metal", (0.29 + math.cos(r) * 0.14, 0.70 + math.sin(r) * 0.14, -0.81), (0.035, 0.09, 0.02), rot=(0, 0, a - 90), taper=0.1, radius=0.0)


@part("gun_gauntlet")
def _(p):
    gun_base(p, (0.3, 0.3, 0.46))
    p.box("metal", (0.29, 0.70, -0.63), (0.26, 0.26, 0.1), 0.04)
    for dy in (-0.075, 0.0, 0.075):
        p.box("metal", (0.29 + 0.14, 0.70 + dy, -0.44), (0.02, 0.045, 0.28), 0.008)
    p.tube("glow", (0.29, 0.70, -0.685), 0.085, 0.02, rot=(90, 0, 0), detail=20)
    p.ring("trim", (0.29, 0.70, -0.69), 0.105, 0.022, rot=(90, 0, 0), detail=24)


# ======================================================================================
# ARENA: caixote dos tijolos (espaço do tijolo, topo em y = 0.6), obstáculo e poste da baliza.
# ======================================================================================
@part("brick_crate")
def _(p):
    # Pouco detalhe de propósito: há até oitenta destes no ecrã.
    p.box("dark", (0, 0.05, 0), (0.56, 0.1, 0.3), 0.02, segments=1)
    p.box("shell", (0, 0.31, 0), (0.52, 0.44, 0.27), 0.04, segments=1)
    for x in (-0.245, 0.245):
        p.box("trim", (x, 0.31, 0), (0.06, 0.46, 0.3), 0.015, segments=1)
    p.box("team", (0, 0.17, 0), (0.44, 0.05, 0.285), 0.0)
    for z in (-0.137, 0.137):
        p.box("glow", (0, 0.37, z * 1.03), (0.2, 0.08, 0.012), 0.0)
    # A tampa é o que a câmara de jogo vê: fica na cor da equipa, com uma moldura escura.
    p.box("dark", (0, 0.56, 0), (0.54, 0.04, 0.3), 0.01, segments=1)
    p.box("team", (0, 0.585, 0), (0.48, 0.03, 0.25), 0.008, segments=1)


def brick_base(p, height=0.1):
    """Soco comum dos tijolos temáticos: base escura e faixa na cor da equipa."""
    p.box("dark", (0, height / 2, 0), (0.56, height, 0.3), 0.02, segments=1)
    p.box("team", (0, height + 0.02, 0), (0.54, 0.04, 0.29), 0.0)


# Tijolos temáticos: um por robô, no mesmo espaço do caixote (0,56 x 0,3, topo perto de 0,6).
# A cor da equipa fica sempre à vista de cima (faixa, tampa ou luzes), para as muralhas se
# lerem de relance; o resto usa as cores do robô que as defende.
@part("brick_ammo")
def _(p):
    # SALVO: caixa de munições com três obuses de pé.
    brick_base(p)
    p.box("shell", (0, 0.3, 0), (0.52, 0.36, 0.27), 0.03, segments=1)
    for x in (-0.2, 0.2):
        p.box("trim", (x, 0.3, 0), (0.06, 0.38, 0.29), 0.01, segments=1)
    p.box("team", (0, 0.49, 0), (0.46, 0.03, 0.24), 0.0)
    for x in (-0.13, 0.0, 0.13):
        p.tube("metal", (x, 0.56, 0), 0.05, 0.12, detail=8)
        p.tube("trim", (x, 0.66, 0), 0.05, 0.08, detail=8, radius2=0.0)
    p.box("glow", (0, 0.3, 0.137), (0.18, 0.05, 0.01), 0.0)


@part("brick_observatory")
def _(p):
    # ÓRBITA: casinha com cúpula rasgada e luneta.
    brick_base(p)
    p.box("shell", (0, 0.24, 0), (0.5, 0.24, 0.27), 0.03, segments=1)
    p.box("team", (0, 0.37, 0), (0.46, 0.03, 0.25), 0.0)
    p.ball("trim", (0, 0.4, 0), (0.3, 0.3, 0.24), detail=10)
    p.box("dark", (0.0, 0.5, 0), (0.05, 0.12, 0.25), 0.0)
    p.strut("metal", (0.02, 0.48, 0), (0.2, 0.62, 0.02), 0.035, detail=8)
    p.ring("glow", (0, 0.37, 0), 0.26, 0.012, detail=10, sides=3)


@part("brick_planter")
def _(p):
    # BROTO: canteiro com rebentos.
    brick_base(p)
    p.box("trim", (0, 0.27, 0), (0.54, 0.3, 0.29), 0.03, segments=1)
    p.box("dark", (0, 0.43, 0), (0.48, 0.03, 0.23), 0.0)
    p.box("team", (0, 0.43, 0.13), (0.54, 0.04, 0.03), 0.0)
    p.box("team", (0, 0.43, -0.13), (0.54, 0.04, 0.03), 0.0)
    for x, h, lean in ((-0.16, 0.2, -20), (0.0, 0.26, 8), (0.16, 0.18, 24)):
        p.strut("metal", (x, 0.44, 0), (x, 0.44 + h, 0), 0.015, detail=5)
        p.wedge("shell", (x - 0.05, 0.44 + h, 0), (0.12, 0.05, 0.08), rot=(0, 0, 30 + lean), taper=0.2)
        p.wedge("shell", (x + 0.05, 0.42 + h, 0), (0.12, 0.05, 0.08), rot=(0, 0, -30 + lean), taper=0.2)
    p.box("glow", (0, 0.27, 0.147), (0.2, 0.05, 0.005), 0.0)


@part("brick_anvil")
def _(p):
    # BIGORNA: uma bigorna de ferreiro.
    brick_base(p)
    p.box("dark", (0, 0.2, 0), (0.36, 0.1, 0.24), 0.02, segments=1)
    p.box("metal", (0, 0.32, 0), (0.18, 0.16, 0.16), 0.02, segments=1)
    p.box("shell", (-0.03, 0.47, 0), (0.44, 0.14, 0.24), 0.03, segments=1)
    p.wedge("shell", (0.27, 0.47, 0), (0.14, 0.14, 0.2), rot=(0, 0, -90), taper=0.15)
    p.box("team", (-0.03, 0.55, 0), (0.4, 0.025, 0.2), 0.0)
    p.box("glow", (0.0, 0.47, 0.123), (0.16, 0.04, 0.005), 0.0)


@part("brick_monolith")
def _(p):
    # ECLIPSE: laje negra com um crescente de luz e estilhaços.
    brick_base(p)
    p.box("dark", (0, 0.38, 0), (0.4, 0.56, 0.18), 0.02, segments=1)
    p.ring("glow", (0, 0.42, 0.095), 0.1, 0.018, rot=(90, 0, 0), detail=12, sides=3)
    p.ball("dark", (0.035, 0.44, 0.1), (0.17, 0.17, 0.02), detail=10)
    for x, h in ((-0.24, 0.3), (0.24, 0.24)):
        p.wedge("shell", (x, 0.12 + h / 2, 0), (0.1, h, 0.12), taper=0.0)
    p.box("team", (0, 0.67, 0), (0.42, 0.03, 0.19), 0.0)


@part("brick_gear")
def _(p):
    # ROSCA: engrenagem de pé sobre um soco.
    brick_base(p)
    p.box("trim", (0, 0.17, 0), (0.4, 0.1, 0.2), 0.02, segments=1)
    p.box("team", (0, 0.23, 0), (0.36, 0.02, 0.18), 0.0)
    p.ring("shell", (0, 0.43, 0), 0.17, 0.045, rot=(90, 0, 0), detail=14, sides=4)
    for i in range(8):
        a = i * 45
        r = math.radians(a)
        p.box("shell", (math.cos(r) * 0.225, 0.43 + math.sin(r) * 0.225, 0), (0.06, 0.06, 0.09), 0.01, rot=(0, 0, a), segments=1)
    p.tube("metal", (0, 0.43, 0), 0.06, 0.12, rot=(90, 0, 0), detail=10)
    p.tube("glow", (0, 0.43, 0), 0.025, 0.14, rot=(90, 0, 0), detail=8)


@part("brick_coil")
def _(p):
    # FAÍSCA: condensador com bobina de Tesla e uma bola de luz.
    brick_base(p)
    p.box("shell", (0, 0.24, 0), (0.5, 0.24, 0.27), 0.03, segments=1)
    p.box("team", (0, 0.37, 0), (0.46, 0.03, 0.25), 0.0)
    p.tube("metal", (0, 0.47, 0), 0.07, 0.18, detail=10)
    for y in (0.41, 0.47, 0.53):
        p.ring("trim", (0, y, 0), 0.08, 0.014, detail=10, sides=3)
    p.ball("glow", (0, 0.62, 0), (0.13, 0.13, 0.13), detail=10)
    for x in (-0.19, 0.19):
        p.tube("dark", (x, 0.42, 0), 0.03, 0.08, detail=6)


@part("brick_speaker")
def _(p):
    # BATIDA: coluna de som com cones à frente e atrás.
    brick_base(p)
    p.box("shell", (0, 0.35, 0), (0.52, 0.46, 0.27), 0.04, segments=1)
    for z in (-0.137, 0.137):
        for x, r in ((-0.12, 0.09), (0.14, 0.06)):
            p.tube("dark", (x, 0.34, z), r, 0.02, rot=(90, 0, 0), detail=10)
            p.tube("metal", (x, 0.34, z * 1.05), r * 0.45, 0.02, rot=(90, 0, 0), detail=8)
        p.box("glow", (0, 0.52, z), (0.36, 0.03, 0.01), 0.0)
    p.box("team", (0, 0.59, 0), (0.48, 0.03, 0.24), 0.01, segments=1)


@part("brick_chest")
def _(p):
    # GANCHO: arca do tesouro com cintas de metal e brilho de ouro.
    brick_base(p)
    p.box("shell", (0, 0.29, 0), (0.52, 0.34, 0.27), 0.02, segments=1)
    p.tube("shell", (0, 0.47, 0), 0.135, 0.52, rot=(0, 0, 90), detail=10)
    p.box("glow", (0, 0.465, 0), (0.48, 0.02, 0.27), 0.0)
    for x in (-0.19, 0.19):
        p.box("metal", (x, 0.34, 0), (0.05, 0.46, 0.29), 0.01, segments=1)
    p.tube("metal", (-0.19, 0.47, 0), 0.142, 0.05, rot=(0, 0, 90), detail=10)
    p.tube("metal", (0.19, 0.47, 0), 0.142, 0.05, rot=(0, 0, 90), detail=10)
    p.box("team", (0, 0.6, 0), (0.1, 0.03, 0.2), 0.0)
    p.box("trim", (0, 0.4, 0.14), (0.08, 0.1, 0.02), 0.01, segments=1)


@part("brick_obelisk")
def _(p):
    # HÉLIO: obelisco curto sobre degraus, com um disco solar.
    brick_base(p)
    p.box("trim", (0, 0.16, 0), (0.46, 0.08, 0.26), 0.02, segments=1)
    p.box("team", (0, 0.21, 0), (0.42, 0.02, 0.24), 0.0)
    p.wedge("shell", (0, 0.43, 0), (0.2, 0.44, 0.18), taper=0.35)
    p.wedge("trim", (0, 0.69, 0), (0.08, 0.08, 0.07), taper=0.0)
    p.ring("glow", (0, 0.42, 0.1), 0.08, 0.018, rot=(90, 0, 0), detail=12, sides=3)
    p.tube("glow", (0, 0.42, 0.095), 0.045, 0.01, rot=(90, 0, 0), detail=10)


@part("brick_emblem")
def _(p):
    # MAGNUS: escudo de campeão com coroa de louros e estrela.
    brick_base(p)
    p.box("trim", (0, 0.17, 0), (0.44, 0.1, 0.24), 0.02, segments=1)
    p.box("team", (0, 0.23, 0), (0.4, 0.02, 0.22), 0.0)
    p.wedge("shell", (0, 0.42, 0), (0.36, 0.36, 0.1), rot=(0, 0, 180), taper=0.55)
    p.ring("metal", (0, 0.44, 0.06), 0.13, 0.02, rot=(90, 0, 0), detail=12, sides=3)
    p.wedge("glow", (0, 0.47, 0.065), (0.1, 0.1, 0.02), taper=0.0)
    p.wedge("glow", (0, 0.43, 0.065), (0.1, 0.07, 0.02), rot=(0, 0, 180), taper=0.0)


@part("bumper_body")
def _(p):
    # Pilão industrial hexagonal com faixas de perigo e anel de luz.
    p.tube("dark", (0, 0.05, 0), 0.5, 0.1, detail=6, bevel=0.02)
    p.tube("shell", (0, 0.3, 0), 0.44, 0.42, detail=6, bevel=0.035)
    for i in range(6):
        a = i * 60 + 30
        r = math.radians(a)
        p.box("trim" if i % 2 else "dark", (math.cos(r) * 0.39, 0.3, math.sin(r) * 0.39), (0.05, 0.3, 0.2), 0.01, rot=(0, -a, 18))
    p.ring("glow", (0, 0.13, 0), 0.45, 0.022, detail=6, sides=4)
    p.tube("metal", (0, 0.55, 0), 0.36, 0.08, detail=6, bevel=0.02)


@part("bumper_core")
def _(p):
    # Tampa que gira: uma estrela de três braços com luz no centro.
    p.tube("dark", (0, 0.61, 0), 0.24, 0.04, detail=18)
    for i in range(3):
        a = i * 120
        r = math.radians(a)
        p.box("trim", (math.cos(r) * 0.16, 0.64, math.sin(r) * 0.16), (0.24, 0.035, 0.08), 0.012, rot=(0, -a, 0))
    p.tube("glow", (0, 0.645, 0), 0.08, 0.03, detail=16)


@part("goal_post")
def _(p):
    p.box("dark", (0, 0.06, 0), (0.3, 0.12, 0.3), 0.03)
    p.box("shell", (0, 0.4, 0), (0.2, 0.6, 0.2), 0.05)
    p.box("trim", (0, 0.4, 0), (0.22, 0.12, 0.22), 0.02)
    p.box("dark", (0, 0.73, 0), (0.24, 0.06, 0.24), 0.02)
    p.box("team", (0, 0.8, 0), (0.16, 0.08, 0.16), 0.02)


# ======================================================================================
# Robôs v2: peças mecânicas (articulações, painéis, mãos e pés) em tools/blender/mech_kit.py
# ======================================================================================
sys.path.insert(0, str(Path(__file__).resolve().parent))
import mech_kit  # noqa: E402

mech_kit.setup(Part, part, HEADS)


# ======================================================================================
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, rgb in ROLES.items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = 0.2 if name == "screen" else 0.45
        if name in EMISSIVE:
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
            bsdf.inputs["Emission Strength"].default_value = 3.0


def build_kit():
    global DETAIL
    reset()
    objects = {}
    jobs = [(name, fn, 1.0) for name, fn in PARTS.items()] + [("lo_" + name, PARTS[name], 0.5) for name in LOW_DETAIL]
    for name, fn, detail in jobs:
        DETAIL = detail
        p = Part(name)
        fn(p)
        root = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(root)
        objects[name] = root
        for role, me in p.meshes.items():
            for poly in me.polygons:
                poly.use_smooth = True
            me.set_sharp_from_angle(angle=math.radians(40))
            me.materials.append(bpy.data.materials[role])
            obj = bpy.data.objects.new(f"{name}__{role}", me)
            bpy.context.collection.objects.link(obj)
            obj.parent = root
    return objects


def export():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_yup=True, export_texcoords=True,
                              export_materials="EXPORT", export_extras=False, export_apply=True,
                              export_vertex_color="NONE")
    tris = 0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            tris += len(obj.data.loop_triangles)
    print("ROBOT_KIT", OUTPUT.relative_to(ROOT), len(PARTS), "peças", tris, "triângulos", OUTPUT.stat().st_size, "bytes")
    print("HEADS", json.dumps(HEADS))


# ======================================================================================
# Folha do elenco (só para rever o design; o jogo monta os robôs no Godot)
# ======================================================================================
def hex_rgb(value):
    value = value.lstrip("#")
    srgb = [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def assemble(objects, recipe, palette, offset, scale):
    mats = {}
    for role in ROLES:
        mat = bpy.data.materials[role].copy()
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        color = palette.get(role) or "4fd6c4"
        bsdf.inputs["Base Color"].default_value = (*hex_rgb(color), 1) if role != "screen" else (0.02, 0.03, 0.05, 1)
        if role in EMISSIVE:
            bsdf.inputs["Emission Color"].default_value = (*hex_rgb(color), 1)
        if role == "metal":
            bsdf.inputs["Metallic"].default_value = 0.8
            bsdf.inputs["Roughness"].default_value = 0.3
        mats[role] = mat
    head = HEADS[recipe["head"]]
    lift = Vector((0, 0, head["top"] - HEAD_TOP))
    centre = Vector((0, 0, head["center"] - HEAD_CENTER))
    body = Matrix.Translation(offset) @ Matrix.Diagonal((scale[0], scale[2], scale[1], 1))

    def place(name, extra):
        for child in objects[name].children:
            copy = child.copy()
            copy.parent = None
            copy.data = child.data.copy()
            copy.data.materials[0] = mats[child.data.materials[0].name]
            copy.matrix_world = body @ extra
            bpy.context.collection.objects.link(copy)

    for slot in ("head", "torso", "shoulders", "back", "arm", "gun"):
        if recipe.get(slot):
            place(recipe[slot], Matrix.Identity(4))
    if recipe.get("top"):
        place(recipe["top"], Matrix.Translation(lift))
    if recipe.get("spin"):
        place(recipe["spin"], Matrix.Translation(centre if recipe["spin"] in ("spin_rays", "spin_halo", "spin_orbit") else lift))
    for side in (-1, 1):
        pivot = (CONVERT @ Vector((side * LEG_PIVOT.x, LEG_PIVOT.y, LEG_PIVOT.z, 1))).to_3d()
        place(recipe["legs"], Matrix.Translation(pivot))


def sheet(path):
    objects = build_kit()
    roster = json.loads(ROSTER.read_text())
    for i, entry in enumerate(roster["cast"]):
        col, row = i % 6, i // 6
        assemble(objects, entry["parts"], entry["palette"], CONVERT.to_3x3() @ Vector((col * 2.1 - 5.25, 0, row * -3.4)),
                 entry.get("scale", [1, 1, 1]))
    for obj in objects.values():
        for child in obj.children:
            child.hide_render = True
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 1400
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.09, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    scene.world = world
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 13.5
    cam.location = CONVERT.to_3x3() @ Vector((-2.5, 3.2, -18))
    target = CONVERT.to_3x3() @ Vector((0.0, 0.2, -1.7))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for loc, power, size in (((-6, 9, -8), 2500, 6), ((8, 5, 4), 1200, 6), ((0, 4, 10), 800, 8)):
        light = bpy.data.objects.new("Light", bpy.data.lights.new("Light", "AREA"))
        light.data.energy = power
        light.data.size = size
        light.location = CONVERT.to_3x3() @ Vector(loc)
        light.rotation_euler = (CONVERT.to_3x3() @ Vector((0, 1, 0)) - light.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.collection.objects.link(light)
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build_kit()
    export()
    if "--sheet" in sys.argv:
        sheet(sys.argv[sys.argv.index("--sheet") + 1])
