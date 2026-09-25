"""Kit de peças dos robôs do Charge Arena, modelado em Blender.

    python3 tools/blender/robot_kit.py              # escreve art/robots/kit.glb
    python3 tools/blender/robot_kit.py --sheet a.png  # e renderiza o elenco (Cycles)

Cada peça é um nó vazio na raiz do .glb com uma malha por material; o nome do material é o
papel da cor (ver ROLES). As peças já estão na posição final:
- peças "body"/"head"/"top"/"back"/"shoulders"/"arm" no espaço do nó Body;
- peças "leg" no espaço de uma perna (pivô na anca), simétricas, servem às duas;
- peças "gun" no espaço do nó Gun (origem igual à do Body), boca do cano em (0.29, 0.70, -0.86);
- peças com nome começado por "spin_" giram no jogo (nó Spin).
As receitas de cada robô (que peças e que cores) estão em art/robots/roster.json.

Coordenadas escritas em unidades do Godot: Y para cima, frente em -Z, direita em +X.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh  # depois do bpy: é o módulo bpy que o regista
from mathutils import Euler, Matrix, Vector

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
}
EMISSIVE = {"glow"}
LEG_PIVOT = Vector((0.19, 0.40, 0.0))
MUZZLE = Vector((0.29, 0.70, -0.86))

CONVERT = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # Godot -> Blender


def xform(at=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Transformação em espaço Godot: escala, depois rotação X, Y, Z (graus), depois posição."""
    rx, ry, rz = (math.radians(a) for a in rot)
    r = Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")
    s = Matrix.Diagonal((*scale, 1))
    return Matrix.Translation(Vector(at)) @ r @ s


class Part:
    """Acumula geometria de uma peça, separada por papel de material."""

    def __init__(self, name, mirror_x=False):
        self.name = name
        self.meshes = {}

    def add(self, role, bm, matrix):
        for v in bm.verts:
            v.co = (CONVERT @ matrix).to_3x3() @ v.co + (CONVERT @ matrix).translation
        # Uma escala negativa (espelho) inverte as faces.
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
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, segments=segments, profile=0.5,
                            affect="EDGES", clamp_overlap=True)
        self.add(role, bm, xform(at, rot))

    def ball(self, role, at, size, rot=(0, 0, 0), detail=16):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=detail, v_segments=max(6, detail // 2), radius=0.5)
        self.add(role, bm, xform(at, rot, size))

    def tube(self, role, at, radius, length, rot=(0, 0, 0), detail=16, radius2=None, bevel=0.0, caps=True):
        """Cilindro ao longo do Y local (roda-o com `rot`)."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=caps, segments=detail, radius1=radius,
                              radius2=radius if radius2 is None else radius2, depth=length)
        # create_cone nasce em Z; passa a Y.
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
        if bevel > 0 and caps:
            rims = [e for e in bm.edges if not e.is_manifold or len(e.link_faces) == 2 and
                    abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.5]
            bmesh.ops.bevel(bm, geom=rims, offset=bevel, segments=2, profile=0.5, affect="EDGES",
                            clamp_overlap=True)
        self.add(role, bm, xform(at, rot))

    def strut(self, role, a, b, radius, detail=12):
        """Cilindro de `a` a `b` (juntas, cabos, braços)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        q = Vector((0, 1, 0)).rotation_difference(d.normalized())
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=detail, radius1=radius, radius2=radius, depth=d.length)
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
        self.add(role, bm, Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())

    def ring(self, role, at, major, minor, rot=(0, 0, 0), detail=24, sides=6):
        """Toro deitado no plano XZ local (eixo Y)."""
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
        """Caixa cujo topo encolhe para `taper` (0 = aresta): cunhas, dentes, bicos."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            k = taper if v.co.y > 0 else 1.0
            v.co = Vector((v.co.x * size[0] * k, v.co.y * size[1], v.co.z * size[2]))
        if radius > 0:
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=radius, segments=2, profile=0.5,
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

    def mirrored(self, fn, *args, **kw):
        """Chama `fn(side, ...)` para os dois lados."""
        for side in (-1, 1):
            fn(side, *args, **kw)


PARTS = {}


def part(name):
    def register(fn):
        PARTS[name] = fn
        return fn
    return register


# ======================================================================================
# CABEÇAS: caixa com ecrã, moldura, parafusos e auscultadores.
# ======================================================================================
def head_common(p, center, size, radius, screen_size, ear=0.15, ear_y=0.0, screws=True, vents=3):
    cx, cy, cz = center
    w, h, d = size
    p.box("shell", center, size, radius, segments=4)
    front = cz - d / 2
    sw, sh = screen_size
    # Moldura em relevo à volta do ecrã e o próprio ecrã, um pouco mais à frente.
    p.box("dark", (cx, cy - 0.01, front + 0.005), (sw + 0.1, sh + 0.1, 0.05), 0.045, segments=3)
    p.screen((cx, cy - 0.01, front - 0.024), (sw, sh), bulge=0.018)
    if screws:
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.tube("metal", (cx + sx * (sw / 2 + 0.012), cy - 0.01 + sy * (sh / 2 + 0.012), front - 0.022),
                       0.018, 0.012, rot=(90, 0, 0), detail=10)
    # Auscultadores: disco escuro, anel luminoso, tampa metálica.
    if ear > 0:
        for side in (-1, 1):
            x = cx + side * (w / 2 + 0.02)
            p.tube("dark", (x, cy + ear_y, cz + 0.02), ear, 0.09, rot=(0, 0, 90), detail=24, bevel=0.02)
            p.ring("glow", (x + side * 0.047, cy + ear_y, cz + 0.02), ear * 0.72, 0.016, rot=(0, 0, 90), detail=28)
            p.tube("metal", (x + side * 0.05, cy + ear_y, cz + 0.02), ear * 0.5, 0.03, rot=(0, 0, 90), detail=20, bevel=0.008)
    # Grelha de ventilação no topo e uma placa na nuca.
    for i in range(vents):
        p.box("dark", (cx - (vents - 1) * 0.06 + i * 0.12, cy + h / 2 + 0.004, cz + 0.05), (0.07, 0.02, 0.2), 0.008)
    p.box("dark", (cx, cy + 0.02, cz + d / 2 + 0.004), (w * 0.44, h * 0.34, 0.03), 0.012)
    p.box("trim", (cx, cy + 0.02 + h * 0.12, cz + d / 2 + 0.022), (w * 0.3, 0.035, 0.012), 0.005)


@part("head_box")
def _(p):
    head_common(p, (0, 1.39, 0), (0.92, 0.70, 0.76), 0.12, (0.70, 0.48))


@part("head_wide")
def _(p):
    head_common(p, (0, 1.36, 0), (1.08, 0.62, 0.74), 0.11, (0.86, 0.42), ear=0.13, vents=4)


@part("head_tall")
def _(p):
    head_common(p, (0, 1.45, 0), (0.80, 0.84, 0.74), 0.13, (0.60, 0.60), ear=0.14)


@part("head_round")
def _(p):
    head_common(p, (0, 1.39, 0), (0.94, 0.72, 0.78), 0.26, (0.66, 0.44), ear=0.14, screws=False, vents=0)


@part("head_slant")
def _(p):
    # Cabeça em cunha: testa inclinada para a frente, lê-se "agressiva" de lado.
    head_common(p, (0, 1.39, 0.02), (0.88, 0.68, 0.80), 0.10, (0.66, 0.40), ear=0.13)
    p.wedge("shell", (0, 1.76, -0.08), (0.8, 0.12, 0.5), rot=(-8, 0, 0), taper=0.6, radius=0.03)


# ======================================================================================
# TOPO DA CABEÇA: antenas, orelhas, chifres, cristas.
# ======================================================================================
@part("top_antenna")
def _(p):
    p.tube("dark", (0.22, 1.86, 0.08), 0.018, 0.26, detail=8)
    p.ball("glow", (0.22, 2.0, 0.08), (0.075, 0.075, 0.075))
    p.tube("metal", (0.22, 1.745, 0.08), 0.05, 0.03, detail=14)


@part("top_fins")
def _(p):
    # Duas barbatanas inclinadas para trás: a silhueta de "orelhas" sem serem orelhas.
    for side in (-1, 1):
        p.wedge("shell", (side * 0.3, 1.86, 0.1), (0.1, 0.34, 0.26), rot=(-22, 0, side * -14), taper=0.35, radius=0.03)
        p.wedge("team", (side * 0.3, 1.87, 0.02), (0.04, 0.24, 0.12), rot=(-22, 0, side * -14), taper=0.3, radius=0.01)


@part("top_handle")
def _(p):
    # Pega de transporte, como uma câmara ou um rádio antigo.
    for side in (-1, 1):
        p.tube("dark", (side * 0.34, 1.8, 0.05), 0.03, 0.12, detail=10)
    p.strut("dark", (-0.34, 1.86, 0.05), (0.34, 1.86, 0.05), 0.03)
    p.box("metal", (0, 1.865, 0.05), (0.26, 0.07, 0.08), 0.03)


@part("top_horns")
def _(p):
    for side in (-1, 1):
        p.tube("dark", (side * 0.3, 1.78, 0.05), 0.07, 0.08, detail=14)
        p.tube("shell", (side * 0.38, 1.98, 0.14), 0.07, 0.42, rot=(-35, 0, side * -30), detail=12, radius2=0.012)


@part("top_dish")
def _(p):
    # Parabólica de lado, apontada para o céu.
    p.tube("dark", (-0.3, 1.82, 0.12), 0.02, 0.18, detail=8)
    p.tube("metal", (-0.3, 1.97, 0.12), 0.2, 0.05, rot=(0, 0, 25), detail=24, radius2=0.08)
    p.ball("glow", (-0.33, 2.03, 0.12), (0.06, 0.06, 0.06))


@part("top_sprout")
def _(p):
    p.tube("team", (0, 1.83, 0.05), 0.02, 0.22, rot=(0, 0, 8), detail=8)
    for side, lift in ((-1, 1.95), (1, 1.99)):
        p.ball("glow", (side * 0.1, lift, 0.05), (0.2, 0.05, 0.12), rot=(0, 0, side * -25))


@part("top_rods")
def _(p):
    # Para-raios em zigue-zague.
    for side in (-1, 1):
        x = side * 0.3
        pts = [(x, 1.74, 0.05), (x + side * 0.04, 1.86, 0.05), (x - side * 0.02, 1.93, 0.05), (x + side * 0.05, 2.06, 0.05)]
        for a, b in zip(pts, pts[1:]):
            p.strut("metal", a, b, 0.022, detail=8)
        p.ball("glow", pts[-1], (0.06, 0.06, 0.06))


@part("top_mohawk")
def _(p):
    for i in range(4):
        p.wedge("team", (0, 1.8 + (i % 2) * 0.01, -0.22 + i * 0.15), (0.06, 0.2 - i * 0.02, 0.14), rot=(-15, 0, 0), taper=0.3, radius=0.012)


@part("top_hood")
def _(p):
    # Capuz de lona sobre a cabeça, aberto à frente para mostrar o ecrã.
    p.box("trim", (0, 1.52, 0.08), (1.04, 0.66, 0.78), 0.2, segments=4)
    p.box("trim", (0, 1.07, 0.3), (0.9, 0.3, 0.28), 0.1)
    p.wedge("trim", (0, 1.62, 0.5), (0.3, 0.3, 0.2), rot=(60, 0, 0), taper=0.2, radius=0.03)


@part("spin_rays")
def _(p):
    # Coroa de raios solares por trás da cabeça (gira).
    p.ring("metal", (0, 1.45, 0.42), 0.5, 0.025, rot=(90, 0, 0), detail=40)
    for i in range(12):
        a = i / 12 * 360
        r = math.radians(a)
        p.wedge("glow", (math.cos(r) * 0.6, 1.45 + math.sin(r) * 0.6, 0.42), (0.07, 0.2, 0.03), rot=(0, 0, a - 90), taper=0.1, radius=0.0)


@part("spin_laurel")
def _(p):
    # Coroa de louros dourada a flutuar sobre a cabeça (gira).
    p.ring("metal", (0, 1.9, 0), 0.34, 0.03, detail=36)
    for i in range(10):
        r = i / 10 * math.tau
        p.ball("metal", (math.cos(r) * 0.36, 1.93, math.sin(r) * 0.36), (0.13, 0.05, 0.07), rot=(0, -math.degrees(r), 20))


@part("spin_orbit")
def _(p):
    # Anel planetário inclinado com duas luas.
    p.ring("glow", (0, 1.42, 0), 0.62, 0.014, rot=(0, 0, 18), detail=48)
    for a in (40, 220):
        r = math.radians(a)
        x, z = math.cos(r) * 0.62, math.sin(r) * 0.62
        p.ball("metal", (x, 1.42 + x * math.tan(math.radians(18)), z), (0.1, 0.1, 0.1))


@part("spin_halo")
def _(p):
    # Anel de eclipse atrás da cabeça.
    p.ring("dark", (0, 1.5, 0.44), 0.38, 0.045, rot=(90, 0, 0), detail=40)
    p.ring("glow", (0, 1.5, 0.47), 0.38, 0.018, rot=(90, 0, 0), detail=40)


# ======================================================================================
# TRONCOS
# ======================================================================================
def torso_common(p, width=0.62, height=0.36, depth=0.46, chest_y=0.76):
    p.box("dark", (0, 0.47, 0), (0.44, 0.12, 0.32), 0.04)           # bacia
    p.tube("dark", (0, 0.56, 0), 0.17, 0.12, detail=18)              # abdómen articulado
    for y in (0.53, 0.59):
        p.ring("metal", (0, y, 0), 0.175, 0.008, detail=24, sides=4)
    p.box("shell", (0, chest_y, 0), (width, height, depth), 0.1, segments=4)
    p.tube("dark", (0, chest_y + height / 2 + 0.04, 0), 0.2, 0.07, detail=20)  # gola
    p.tube("dark", (0, 1.0, 0), 0.085, 0.1, detail=12)               # pescoço
    for side in (-1, 1):
        p.ball("dark", (side * (width / 2 + 0.05), 0.87, 0), (0.18, 0.18, 0.18))  # ombros


@part("torso_std")
def _(p):
    torso_common(p)
    p.box("trim", (0, 0.77, -0.235), (0.38, 0.22, 0.05), 0.03)
    p.wedge("glow", (0, 0.77, -0.265), (0.12, 0.1, 0.02), rot=(0, 0, 180), taper=0.0, radius=0.0)
    p.box("team", (0, 0.47, -0.165), (0.2, 0.06, 0.02), 0.008)
    p.box("trim", (0, 0.78, 0.235), (0.34, 0.2, 0.04), 0.02)


@part("torso_heavy")
def _(p):
    torso_common(p, width=0.78, height=0.42, depth=0.52, chest_y=0.77)
    for side in (-1, 1):
        for i in range(3):
            p.box("dark", (side * 0.2, 0.84 - i * 0.06, -0.265), (0.18, 0.025, 0.02), 0.006)
    # Faixa de perigo em diagonal.
    for i in range(4):
        p.box("trim" if i % 2 else "dark", (-0.12 + i * 0.08, 0.64, -0.262), (0.07, 0.07, 0.02), 0.005, rot=(0, 0, 35))
    p.box("team", (0, 0.47, -0.165), (0.26, 0.06, 0.02), 0.008)


@part("torso_slim")
def _(p):
    torso_common(p, width=0.54, height=0.34, depth=0.42)
    for i in range(3):
        p.box("trim", (0, 0.86 - i * 0.075, -0.215), (0.34 - i * 0.05, 0.045, 0.04), 0.015)
    p.ball("glow", (0, 0.65, -0.21), (0.08, 0.08, 0.04))
    p.box("team", (0, 0.47, -0.165), (0.18, 0.06, 0.02), 0.008)


# ======================================================================================
# OMBREIRAS
# ======================================================================================
@part("shoulders_round")
def _(p):
    for side in (-1, 1):
        p.box("shell", (side * 0.43, 0.93, 0), (0.24, 0.2, 0.3), 0.09, segments=4)
        p.box("team", (side * 0.43, 0.93, -0.155), (0.14, 0.05, 0.02), 0.008)


@part("shoulders_block")
def _(p):
    for side in (-1, 1):
        p.box("shell", (side * 0.48, 0.95, 0), (0.3, 0.26, 0.36), 0.06)
        p.box("trim", (side * 0.48, 1.085, 0), (0.24, 0.03, 0.3), 0.01)
        for i in range(3):
            p.box("team", (side * (0.48 + side * 0.152), 0.99 - i * 0.05, -0.05 + i * 0.05), (0.02, 0.025, 0.1), 0.006, rot=(0, 0, 0))


@part("shoulders_speaker")
def _(p):
    for side in (-1, 1):
        p.box("dark", (side * 0.46, 0.94, 0), (0.24, 0.26, 0.26), 0.06)
        p.tube("metal", (side * 0.585, 0.94, 0), 0.1, 0.02, rot=(0, 0, 90), detail=20)
        p.tube("dark", (side * 0.59, 0.94, 0), 0.08, 0.03, rot=(0, 0, 90), detail=20, radius2=0.03)
        p.ring("glow", (side * 0.595, 0.94, 0), 0.1, 0.01, rot=(0, 0, 90), detail=24)


@part("shoulders_pod")
def _(p):
    # Lança-mísseis de quatro tubos no ombro esquerdo; ombreira simples no direito.
    p.box("shell", (-0.5, 1.02, 0.02), (0.3, 0.26, 0.36), 0.05)
    for i in range(2):
        for j in range(2):
            p.tube("dark", (-0.57 + i * 0.13, 0.96 + j * 0.11, -0.16), 0.045, 0.04, rot=(90, 0, 0), detail=12)
            p.ball("glow", (-0.57 + i * 0.13, 0.96 + j * 0.11, -0.18), (0.05, 0.05, 0.02))
    p.box("trim", (-0.5, 1.16, 0.02), (0.24, 0.03, 0.3), 0.01)
    p.box("shell", (0.43, 0.93, 0), (0.24, 0.2, 0.3), 0.09, segments=4)
    p.box("team", (0.43, 0.93, -0.155), (0.14, 0.05, 0.02), 0.008)


# ======================================================================================
# COSTAS
# ======================================================================================
@part("back_pack")
def _(p):
    p.box("dark", (0, 0.78, 0.3), (0.42, 0.36, 0.16), 0.05)
    p.box("trim", (0, 0.86, 0.39), (0.3, 0.06, 0.03), 0.01)
    for x in (-0.12, 0.12):
        p.tube("metal", (x, 0.64, 0.33), 0.05, 0.08, detail=14, radius2=0.065)


@part("back_tanks")
def _(p):
    p.box("dark", (0, 0.8, 0.27), (0.4, 0.3, 0.1), 0.03)
    for x in (-0.12, 0.12):
        p.tube("metal", (x, 0.78, 0.35), 0.075, 0.38, detail=18, bevel=0.025)
        p.ring("team", (x, 0.86, 0.35), 0.078, 0.01, detail=18, sides=4)


@part("back_planter")
def _(p):
    p.tube("trim", (0, 0.82, 0.34), 0.16, 0.24, detail=20, radius2=0.19, bevel=0.02)
    p.tube("dark", (0, 0.95, 0.34), 0.17, 0.03, detail=20)
    for i in range(5):
        r = i / 5 * math.tau
        p.ball("glow", (math.cos(r) * 0.08, 1.02, 0.34 + math.sin(r) * 0.08), (0.12, 0.05, 0.08), rot=(0, -math.degrees(r), 35))


@part("back_toolbox")
def _(p):
    p.box("trim", (0, 0.78, 0.33), (0.44, 0.28, 0.2), 0.03)
    p.box("dark", (0, 0.93, 0.33), (0.46, 0.03, 0.22), 0.01)
    p.strut("metal", (-0.12, 0.96, 0.33), (0.12, 0.96, 0.33), 0.018)
    # Chave de boca espetada na caixa.
    p.box("metal", (0.2, 1.1, 0.33), (0.05, 0.32, 0.02), 0.01, rot=(0, 0, -20))
    p.ring("metal", (0.26, 1.26, 0.33), 0.05, 0.018, rot=(90, 0, 0), detail=16)


@part("back_coil")
def _(p):
    p.box("dark", (0, 0.76, 0.28), (0.38, 0.32, 0.12), 0.04)
    p.tube("metal", (0, 1.0, 0.33), 0.04, 0.42, detail=10)
    for i in range(4):
        p.ring("glow", (0, 0.86 + i * 0.08, 0.33), 0.09 - i * 0.012, 0.012, detail=18)
    p.ball("glow", (0, 1.23, 0.33), (0.1, 0.1, 0.1))


@part("back_cape")
def _(p):
    # Capa em painéis rígidos, a descer das costas.
    for i, x in enumerate((-0.2, 0.0, 0.2)):
        p.box("trim", (x, 0.62, 0.3 + abs(x) * 0.1), (0.21, 0.66, 0.03), 0.01, rot=(-8, x * 30, 0))
    p.box("metal", (0, 0.95, 0.27), (0.5, 0.05, 0.06), 0.015)


@part("back_thruster")
def _(p):
    p.box("dark", (0, 0.8, 0.28), (0.44, 0.3, 0.12), 0.04)
    for x in (-0.14, 0.14):
        p.tube("metal", (x, 0.7, 0.36), 0.08, 0.3, detail=16, bevel=0.02)
        p.tube("dark", (x, 0.52, 0.36), 0.07, 0.08, detail=16, radius2=0.09)
        p.tube("glow", (x, 0.475, 0.36), 0.06, 0.01, detail=16)


# ======================================================================================
# BRAÇOS: o esquerdo com punho; o direito só até ao cotovelo (a arma faz de antebraço).
# ======================================================================================
def arm_right(p, shoulder_x=0.36):
    p.strut("dark", (shoulder_x, 0.86, 0), (0.3, 0.72, -0.14), 0.06)
    p.ball("dark", (0.3, 0.71, -0.15), (0.13, 0.13, 0.13))


@part("arm_std")
def _(p):
    p.strut("dark", (-0.37, 0.86, 0), (-0.42, 0.66, -0.02), 0.06)
    p.ball("dark", (-0.42, 0.65, -0.02), (0.12, 0.12, 0.12))
    p.box("shell", (-0.43, 0.54, -0.04), (0.17, 0.22, 0.19), 0.06)
    p.box("team", (-0.43, 0.54, -0.137), (0.1, 0.04, 0.015), 0.006)
    p.box("dark", (-0.43, 0.39, -0.05), (0.13, 0.12, 0.14), 0.04)
    for i in range(3):
        p.box("metal", (-0.43 - 0.035 + i * 0.035, 0.36, -0.12), (0.025, 0.05, 0.02), 0.008)
    arm_right(p)


@part("arm_heavy")
def _(p):
    p.strut("dark", (-0.44, 0.9, 0), (-0.5, 0.66, -0.02), 0.075)
    p.ball("dark", (-0.5, 0.65, -0.02), (0.15, 0.15, 0.15))
    p.box("shell", (-0.52, 0.52, -0.04), (0.24, 0.26, 0.25), 0.06)
    p.box("dark", (-0.52, 0.35, -0.05), (0.18, 0.15, 0.18), 0.05)
    for i in range(3):
        p.box("metal", (-0.52 - 0.05 + i * 0.05, 0.31, -0.14), (0.035, 0.06, 0.025), 0.01)
    arm_right(p, 0.42)


# ======================================================================================
# PERNAS (espaço da perna: pivô da anca na origem, pé em y = -0.40)
# ======================================================================================
def leg_core(p, shin=(0.2, 0.2, 0.22)):
    p.ball("dark", (0, 0, 0), (0.18, 0.18, 0.18))
    p.strut("dark", (0, 0, 0), (0, -0.16, -0.01), 0.07)
    p.ball("dark", (0, -0.16, -0.01), (0.16, 0.16, 0.16))
    p.box("shell", (0, -0.25, 0.0), shin, 0.06, segments=3)
    p.box("trim", (0, -0.17, -0.1), (0.13, 0.08, 0.06), 0.025)   # joelheira
    p.strut("dark", (0, -0.3, 0), (0, -0.35, -0.02), 0.06)


@part("leg_std")
def _(p):
    leg_core(p)
    p.box("dark", (0, -0.375, -0.05), (0.24, 0.05, 0.36), 0.02)
    p.box("trim", (0, -0.35, -0.17), (0.22, 0.07, 0.12), 0.03)
    p.box("metal", (0, -0.35, 0.1), (0.16, 0.06, 0.08), 0.02)


@part("leg_heavy")
def _(p):
    leg_core(p, shin=(0.27, 0.24, 0.28))
    p.box("dark", (0, -0.37, -0.05), (0.32, 0.06, 0.42), 0.02)
    for x in (-0.08, 0.08):
        p.wedge("trim", (x, -0.345, -0.24), (0.12, 0.08, 0.1), rot=(-90, 0, 0), taper=0.5, radius=0.015)
    p.box("metal", (0, -0.34, 0.13), (0.22, 0.08, 0.1), 0.02)


@part("leg_slim")
def _(p):
    p.ball("dark", (0, 0, 0), (0.16, 0.16, 0.16))
    p.strut("dark", (0, 0, 0), (0, -0.3, 0.02), 0.05)
    p.box("shell", (0, -0.12, -0.02), (0.16, 0.18, 0.18), 0.05)
    p.box("dark", (0, -0.375, -0.04), (0.2, 0.05, 0.3), 0.02)
    p.wedge("trim", (0, -0.35, -0.2), (0.16, 0.06, 0.1), rot=(-90, 0, 0), taper=0.3, radius=0.012)


@part("leg_wheel")
def _(p):
    leg_core(p)
    p.box("dark", (0, -0.37, -0.05), (0.22, 0.06, 0.34), 0.02)
    p.box("trim", (0, -0.35, -0.17), (0.2, 0.07, 0.1), 0.03)
    # Roda de lado, como os robôs de oficina.
    p.tube("dark", (0.13, -0.33, 0.06), 0.075, 0.05, rot=(0, 0, 90), detail=18, bevel=0.012)
    p.tube("metal", (0.16, -0.33, 0.06), 0.035, 0.02, rot=(0, 0, 90), detail=12)


# ======================================================================================
# ARMAS (espaço do Gun; boca em MUZZLE)
# ======================================================================================
def gun_base(p, casing=(0.24, 0.24, 0.4), z=-0.36):
    p.box("shell", (0.29, 0.70, z), casing, 0.07, segments=3)
    p.box("team", (0.29, 0.70 + casing[1] / 2 + 0.004, z), (0.06, 0.012, casing[2] * 0.7), 0.004)


@part("gun_cannon")
def _(p):
    gun_base(p)
    p.tube("dark", (0.29, 0.70, -0.65), 0.1, 0.2, rot=(90, 0, 0), detail=20, bevel=0.015)
    p.ring("trim", (0.29, 0.70, -0.76), 0.1, 0.025, rot=(90, 0, 0), detail=24)
    p.tube("glow", (0.29, 0.70, -0.785), 0.07, 0.01, rot=(90, 0, 0), detail=20)
    p.box("glow", (0.415, 0.70, -0.36), (0.012, 0.05, 0.22), 0.004)


@part("gun_twin")
def _(p):
    gun_base(p, (0.28, 0.22, 0.38))
    for dx in (-0.065, 0.065):
        p.tube("dark", (0.29 + dx, 0.70, -0.66), 0.055, 0.28, rot=(90, 0, 0), detail=14)
        p.ring("trim", (0.29 + dx, 0.70, -0.79), 0.055, 0.014, rot=(90, 0, 0), detail=16)
        p.tube("glow", (0.29 + dx, 0.70, -0.8), 0.035, 0.01, rot=(90, 0, 0), detail=12)
    p.box("metal", (0.29, 0.83, -0.38), (0.08, 0.06, 0.2), 0.02)


@part("gun_scope")
def _(p):
    gun_base(p, (0.2, 0.2, 0.36))
    p.tube("dark", (0.29, 0.70, -0.68), 0.06, 0.36, rot=(90, 0, 0), detail=16, radius2=0.075)
    p.ring("metal", (0.29, 0.70, -0.86 + 0.05), 0.08, 0.014, rot=(90, 0, 0), detail=20)
    p.tube("glow", (0.29, 0.70, -0.855), 0.055, 0.01, rot=(90, 0, 0), detail=16)
    # Luneta por cima com lente luminosa.
    p.tube("metal", (0.29, 0.86, -0.42), 0.04, 0.3, rot=(90, 0, 0), detail=14)
    p.ball("glow", (0.29, 0.86, -0.575), (0.06, 0.06, 0.02))


@part("gun_seed")
def _(p):
    p.ball("shell", (0.29, 0.70, -0.4), (0.3, 0.28, 0.46))
    p.tube("dark", (0.29, 0.70, -0.66), 0.07, 0.12, rot=(90, 0, 0), detail=16, radius2=0.1)
    p.ball("glow", (0.29, 0.70, -0.74), (0.12, 0.12, 0.08))
    for i in range(3):
        r = i / 3 * math.tau
        p.ball("glow", (0.29 + math.cos(r) * 0.12, 0.70 + math.sin(r) * 0.12, -0.3), (0.14, 0.05, 0.08), rot=(0, 0, math.degrees(r)))


@part("gun_drill")
def _(p):
    gun_base(p, (0.3, 0.3, 0.42), -0.34)
    p.tube("metal", (0.29, 0.70, -0.6), 0.12, 0.1, rot=(90, 0, 0), detail=20)
    p.tube("trim", (0.29, 0.70, -0.76), 0.11, 0.26, rot=(90, 0, 0), detail=16, radius2=0.015)
    for i in range(3):
        p.ring("dark", (0.29, 0.70, -0.68 - i * 0.06), 0.085 - i * 0.025, 0.012, rot=(90, 0, 0), detail=16, sides=4)


@part("gun_lance")
def _(p):
    gun_base(p, (0.2, 0.2, 0.34))
    p.tube("dark", (0.29, 0.70, -0.62), 0.035, 0.3, rot=(90, 0, 0), detail=10)
    p.ring("glow", (0.29, 0.70, -0.72), 0.1, 0.018, rot=(90, 0, 0), detail=24)
    p.tube("metal", (0.29, 0.70, -0.82), 0.05, 0.12, rot=(90, 0, 0), detail=10, radius2=0.0)


@part("gun_wrench")
def _(p):
    gun_base(p, (0.24, 0.26, 0.36))
    for i in range(4):
        p.ring("metal", (0.29, 0.70, -0.56 - i * 0.05), 0.075, 0.016, rot=(90, 0, 0), detail=16)
    p.tube("dark", (0.29, 0.70, -0.72), 0.06, 0.16, rot=(90, 0, 0), detail=14)
    p.tube("glow", (0.29, 0.70, -0.805), 0.045, 0.01, rot=(90, 0, 0), detail=14)
    p.box("trim", (0.29, 0.87, -0.3), (0.12, 0.08, 0.12), 0.02)
    p.ring("metal", (0.29, 0.93, -0.3), 0.05, 0.014, rot=(90, 0, 0), detail=14)


@part("gun_tesla")
def _(p):
    gun_base(p, (0.22, 0.22, 0.34))
    p.tube("metal", (0.29, 0.70, -0.66), 0.035, 0.34, rot=(90, 0, 0), detail=10)
    for i in range(4):
        p.ring("glow", (0.29, 0.70, -0.56 - i * 0.07), 0.07 - i * 0.006, 0.013, rot=(90, 0, 0), detail=18)
    p.ball("glow", (0.29, 0.70, -0.84), (0.1, 0.1, 0.1))


@part("gun_horn")
def _(p):
    gun_base(p, (0.24, 0.24, 0.34))
    p.tube("dark", (0.29, 0.70, -0.66), 0.06, 0.24, rot=(90, 0, 0), detail=20, radius2=0.16)
    p.ring("trim", (0.29, 0.70, -0.78), 0.16, 0.018, rot=(90, 0, 0), detail=28)
    p.tube("glow", (0.29, 0.70, -0.77), 0.12, 0.01, rot=(90, 0, 0), detail=24)


@part("gun_blunder")
def _(p):
    p.box("trim", (0.29, 0.66, -0.3), (0.16, 0.2, 0.3), 0.04)
    p.tube("metal", (0.29, 0.70, -0.6), 0.06, 0.34, rot=(90, 0, 0), detail=16, radius2=0.13)
    p.ring("metal", (0.29, 0.70, -0.78), 0.13, 0.02, rot=(90, 0, 0), detail=24)
    p.tube("glow", (0.29, 0.70, -0.775), 0.1, 0.01, rot=(90, 0, 0), detail=20)
    # Gancho pendurado por baixo.
    p.ring("metal", (0.29, 0.52, -0.42), 0.07, 0.016, rot=(0, 0, 90), detail=16)


@part("gun_scepter")
def _(p):
    gun_base(p, (0.2, 0.2, 0.32))
    p.tube("metal", (0.29, 0.70, -0.62), 0.03, 0.32, rot=(90, 0, 0), detail=10)
    p.ball("glow", (0.29, 0.70, -0.8), (0.16, 0.16, 0.16))
    for i in range(8):
        a = i / 8 * 360
        r = math.radians(a)
        p.wedge("metal", (0.29 + math.cos(r) * 0.13, 0.70 + math.sin(r) * 0.13, -0.8), (0.03, 0.08, 0.02), rot=(0, 0, a - 90), taper=0.1, radius=0.0)


@part("gun_gauntlet")
def _(p):
    gun_base(p, (0.28, 0.28, 0.44))
    p.box("metal", (0.29, 0.70, -0.62), (0.24, 0.24, 0.1), 0.04)
    for dy in (-0.07, 0.0, 0.07):
        p.box("metal", (0.29 + 0.13, 0.70 + dy, -0.44), (0.02, 0.04, 0.26), 0.008)
    p.tube("glow", (0.29, 0.70, -0.675), 0.08, 0.02, rot=(90, 0, 0), detail=20)
    p.ring("trim", (0.29, 0.70, -0.68), 0.1, 0.02, rot=(90, 0, 0), detail=24)


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
    reset()
    objects = {}
    for name, fn in PARTS.items():
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
                              export_materials="EXPORT", export_extras=False, export_apply=True)
    tris = 0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            tris += len(obj.data.loop_triangles)
    print("ROBOT_KIT", OUTPUT.relative_to(ROOT), len(PARTS), "peças", tris, "triângulos", OUTPUT.stat().st_size, "bytes")


# ======================================================================================
# Folha do elenco (só para rever o design; o jogo monta os robôs no Godot)
# ======================================================================================
def hex_rgb(value):
    value = value.lstrip("#")
    srgb = [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def assemble(objects, recipe, palette, offset):
    """Copia as peças de um robô para `offset`, com materiais próprios."""
    mats = {}
    for role in ROLES:
        mat = bpy.data.materials[role].copy()
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        color = palette.get(role)
        if color:
            bsdf.inputs["Base Color"].default_value = (*hex_rgb(color), 1)
            if role in EMISSIVE:
                bsdf.inputs["Emission Color"].default_value = (*hex_rgb(color), 1)
        if role == "metal":
            bsdf.inputs["Metallic"].default_value = 0.8
            bsdf.inputs["Roughness"].default_value = 0.3
        mats[role] = mat
    names = [recipe[k] for k in ("head", "top", "spin", "torso", "shoulders", "back", "arm", "gun") if recipe.get(k)]
    placed = []
    for name in names:
        for child in objects[name].children:
            copy = child.copy()
            copy.parent = None
            copy.data = child.data.copy()
            copy.data.materials[0] = mats[child.data.materials[0].name]
            copy.matrix_world = Matrix.Translation(offset)
            bpy.context.collection.objects.link(copy)
            placed.append(copy)
    for side in (-1, 1):
        pivot = CONVERT @ Vector((side * LEG_PIVOT.x, LEG_PIVOT.y, LEG_PIVOT.z, 1))
        for child in objects[recipe["legs"]].children:
            copy = child.copy()
            copy.parent = None
            copy.data = child.data.copy()
            copy.data.materials[0] = mats[child.data.materials[0].name]
            copy.matrix_world = Matrix.Translation(offset + pivot.to_3d())
            bpy.context.collection.objects.link(copy)
    # Olhos desenhados no ecrã (o jogo usa um shader; aqui bastam duas pílulas).
    eye = hex_rgb(palette.get("eyes") or "7ff6ff")
    emat = bpy.data.materials.new("eyes")
    emat.use_nodes = True
    bsdf = emat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Emission Color"].default_value = (*eye, 1)
    bsdf.inputs["Emission Strength"].default_value = 6
    head = objects[recipe["head"]]
    screen = next(c for c in head.children if c.name.endswith("__screen"))
    bb = [screen.matrix_world @ Vector(c) for c in screen.bound_box]
    cx = sum(v.x for v in bb) / 8
    cz = sum(v.z for v in bb) / 8
    front = min(v.y for v in bb) - 0.005
    for side in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=offset + Vector((cx + side * 0.13, front, cz)))
        e = bpy.context.active_object
        e.scale = (0.9, 0.3, 1.5)
        e.data.materials.append(emat)


def sheet(path):
    objects = build_kit()
    roster = json.loads(ROSTER.read_text())
    cast = roster["cast"]
    for i, entry in enumerate(cast):
        col, row = i % 6, i // 6
        assemble(objects, entry["parts"], entry["palette"], CONVERT.to_3x3() @ Vector((col * 1.9 - 4.75, 0, row * -3.2)))
    for obj in objects.values():
        for child in obj.children:
            child.hide_render = True
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 1500
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.09, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    floor = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.1, 0.14, 1)
    floor.data.materials.append(fm)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 12.6
    cam.location = CONVERT.to_3x3() @ Vector((1.5, 5.0, -18))
    target = CONVERT.to_3x3() @ Vector((0.0, -0.6, -1.6))
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
    scene.view_settings.look = "AgX - Punchy"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build_kit()
    export()
    if "--sheet" in sys.argv:
        sheet(sys.argv[sys.argv.index("--sheet") + 1])
