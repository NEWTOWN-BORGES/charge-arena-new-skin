"""Kit mecânico dos robôs v2: articulações, painéis, mãos e pés construídos como máquinas.

Importado por robot_kit.py, que lhe passa a classe Part e o registo de peças. As regras de
construção (ver docs/ROBOS-V2.md):
- três camadas: blindagem pintada (shell/trim) sobre um chassis escuro (dark), com as
  juntas em metal (metal) e vedantes e cabos em borracha (rubber);
- nenhuma blindagem cola a outra: há sempre uma fenda escura entre painéis e uma folga
  maior à volta de cada articulação, onde se vê o eixo;
- cada articulação diz como roda: rolamento com parafusos, garfo, eixo e tampas;
- os parafusos seguram duas peças (anéis à volta das juntas, cantos das tampas), nunca soltos.

Coordenadas em unidades do Godot: Y para cima, frente em -Z, direita em +X.
"""
import math

import bmesh
from mathutils import Matrix, Vector

Part = None
part = None
HEADS = None


def setup(part_class, register, heads):
    global Part, part, HEADS
    Part, part, HEADS = part_class, register, heads
    define_parts()


# ======================================================================================
# Referenciais: cada peça orientada vive num referencial local (u, v, w) = (lado, eixo, frente)
# ======================================================================================
def frame(origin, axis, front=(0, 0, -1)):
    """Matriz com o Y local ao longo de `axis` e o Z local o mais perto possível de `front`."""
    y = Vector(axis).normalized()
    f = Vector(front)
    z = f - y * f.dot(y)
    if z.length < 1e-4:
        z = Vector((1, 0, 0)) - y * y.x
    z.normalize()
    x = y.cross(z)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


def axis_frame(origin, axis):
    """Referencial para cilindros: Y local ao longo de `axis` ('x', 'y', 'z' ou vetor)."""
    named = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1), "-x": (-1, 0, 0), "-z": (0, 0, -1), "-y": (0, -1, 0)}
    a = named.get(axis, axis) if isinstance(axis, str) else axis
    front = (0, 0, -1) if abs(Vector(a).z) < 0.9 else (0, 1, 0)
    return frame(origin, a, front)


def at(m, u=0.0, v=0.0, w=0.0):
    """Ponto (u, v, w) de um referencial, em coordenadas do corpo."""
    return (m @ Vector((u, v, w, 1))).to_3d()


def sub(m, u=0.0, v=0.0, w=0.0, rot=(0, 0, 0)):
    """Referencial filho: deslocado e rodado (graus, X depois Y depois Z) dentro de `m`."""
    rx, ry, rz = (math.radians(a) for a in rot)
    r = Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")
    return m @ Matrix.Translation(Vector((u, v, w))) @ r


# ======================================================================================
# Primitivas num referencial
# ======================================================================================
def mbox(p, role, m, size, radius=0.02, segments=2, taper=None):
    """Caixa arredondada centrada em `m`. `taper` = (kx, kz) encolhe o topo (+Y local)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vert in bm.verts:
        kx, kz = taper if (taper and vert.co.y > 0) else (1.0, 1.0)
        vert.co = Vector((vert.co.x * size[0] * kx, vert.co.y * size[1], vert.co.z * size[2] * kz))
    r = min(radius, min(size) * 0.45)
    if r > 0.002:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, segments=segments, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    p.add(role, bm, m)


def mtube(p, role, m, radius, length, detail=16, radius2=None, bevel=0.0, caps=True):
    """Cilindro ao longo do Y local de `m`, centrado."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, segments=detail, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=length)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
    if bevel > 0 and caps:
        rims = [e for e in bm.edges if len(e.link_faces) == 2 and
                abs(e.link_faces[0].normal.dot(e.link_faces[1].normal)) < 0.5]
        bmesh.ops.bevel(bm, geom=rims, offset=bevel, segments=2, profile=0.5, affect="EDGES",
                        clamp_overlap=True)
    p.add(role, bm, m)


def mring(p, role, m, major, minor, detail=24, sides=6):
    """Toro à volta do Y local de `m`."""
    bm = bmesh.new()
    rows = []
    for i in range(detail):
        a = i / detail * math.tau
        row = []
        for j in range(sides):
            b = j / sides * math.tau
            r = major + minor * math.cos(b)
            row.append(bm.verts.new((r * math.cos(a), minor * math.sin(b), r * math.sin(a))))
        rows.append(row)
    for i in range(detail):
        for j in range(sides):
            a, b = rows[i][j], rows[(i + 1) % detail][j]
            c, d = rows[(i + 1) % detail][(j + 1) % sides], rows[i][(j + 1) % sides]
            bm.faces.new((a, d, c, b))
    p.add(role, bm, m)


def rod(p, role, a, b, radius, detail=10):
    """Cilindro de `a` a `b`."""
    a, b = Vector(a), Vector(b)
    mtube(p, role, frame((a + b) / 2, b - a), radius, (b - a).length, detail)


def piston(p, a, b, radius=0.022):
    """Atuador linear: corpo escuro de `a` até meio, haste de metal até `b`, olhais nas pontas."""
    a, b = Vector(a), Vector(b)
    mid = a.lerp(b, 0.55)
    rod(p, "dark", a, mid, radius, 10)
    rod(p, "metal", mid, b, radius * 0.5, 8)
    rod(p, "rubber", mid - (b - a).normalized() * 0.008, mid + (b - a).normalized() * 0.006, radius * 1.1, 10)
    for end in (a, b):
        mtube(p, "metal", axis_frame(end, "x"), radius * 0.9, radius * 1.6, 8)


def cable(p, points, radius=0.011):
    """Cabo de borracha que entra num conector em cada ponta."""
    pts = [Vector(q) for q in points]
    for a, b in zip(pts, pts[1:]):
        rod(p, "rubber", a, b, radius, 8)
    for q in pts[1:-1]:
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=4, radius=radius)
        p.add("rubber", bm, Matrix.Translation(q))
    for end, nxt in ((pts[0], pts[1]), (pts[-1], pts[-2])):
        mtube(p, "metal", frame(end, nxt - end), radius * 1.6, 0.02, 8)


def bolts(p, m, radius, count, size=0.013, role="metal", phase=0.0, proud=0.004):
    """Anel de parafusos sextavados à volta do Y local de `m`, virados para +Y local."""
    for i in range(count):
        a = phase + i / count * math.tau
        pos = at(m, math.cos(a) * radius, proud, math.sin(a) * radius)
        axis = at(m, 0, 1, 0) - at(m)
        mtube(p, role, frame(pos, axis), size, size * 0.9, 6)


def screw(p, m, u, w, size=0.009):
    """Parafuso escareado num painel: `m` com o Y local a sair da superfície."""
    mtube(p, "metal", sub(m, u, 0.0, w), size, 0.006, 6)


def vents(p, m, count, width, depth=0.012, spacing=0.03, height=0.012):
    """Ranhuras de ventilação escuras ao longo do V local de `m` (Z local = normal)."""
    for i in range(count):
        mbox(p, "dark", sub(m, 0, (i - (count - 1) / 2) * spacing, 0), (width, height, depth), 0.004, 1)


# ======================================================================================
# Articulações
# ======================================================================================
def hinge(p, m, width, radius, fork_len=0.1, fork_thick=0.024, bolt_count=4, fork_role="dark", cap=True):
    """Dobradiça ao longo do X local de `m`: garfo de duas faces, cilindro central, eixo e
    tampas de rolamento com parafusos. O garfo pendura para +Y local (para o membro de cima)."""
    x = sub(m, rot=(0, 0, -90))  # Y local do cilindro = X de `m`
    mtube(p, "dark", x, radius, width, 16, bevel=0.006)
    mtube(p, "metal", x, radius * 0.34, width + fork_thick * 2 + 0.03, 10)
    for side in (-1, 1):
        cheek_x = side * (width / 2 + fork_thick / 2 + 0.004)
        mbox(p, fork_role, sub(m, cheek_x, fork_len * 0.45, 0), (fork_thick, fork_len + radius, radius * 2.0), 0.012)
        if cap:
            face = sub(m, cheek_x + side * (fork_thick / 2 + 0.006), 0, 0, rot=(0, 0, -90 * side))
            mtube(p, "metal", face, radius * 0.62, 0.012, 14)
            if bolt_count:
                bolts(p, face, radius * 0.42, bolt_count, size=radius * 0.1, proud=0.008)


def bearing(p, m, radius, width, bolt_count=6, seal=True):
    """Rolamento ao longo do Y local de `m`: anel escuro, tampa, parafusos e vedante."""
    mtube(p, "dark", m, radius, width, 20, bevel=0.006)
    mtube(p, "metal", sub(m, 0, width / 2 + 0.004, 0), radius * 0.72, 0.012, 18)
    bolts(p, sub(m, 0, width / 2 + 0.008, 0), radius * 0.86, bolt_count, size=max(0.009, radius * 0.1))
    mtube(p, "metal", sub(m, 0, width / 2 + 0.012, 0), radius * 0.3, 0.02, 6)
    if seal:
        mring(p, "rubber", sub(m, 0, -width / 2 - 0.004, 0), radius * 0.94, 0.012, 20, 5)


# ======================================================================================
# Mãos e pés
# ======================================================================================
def finger(p, m, lengths, bends, width=0.03, role="dark", tip="metal"):
    """Dedo de três falanges ao longo de -Y local, dobrando à volta do X local para +Z local.
    Cada junta tem o seu pino."""
    cur = m
    for i, (length, bend) in enumerate(zip(lengths, bends)):
        cur = sub(cur, rot=(-bend, 0, 0))
        mtube(p, "metal", sub(cur, rot=(0, 0, 90)), width * 0.34, width * 1.25, 8)
        mbox(p, tip if i == len(lengths) - 1 else role, sub(cur, 0, -length / 2, 0), (width, length * 0.92, width * 0.95), 0.008, 1)
        cur = sub(cur, 0, -length, 0)


def hand(p, m, fingers=3, scale=1.0, curl=1.0, armor="shell"):
    """Mão industrial em `m` (Y local para o pulso, -Y para os dedos, +Z local para a palma):
    placa de palma, blocos de dedo, atuadores, blindagem nas costas e um polegar oposto."""
    s = scale
    mbox(p, "dark", m, (0.1 * s, 0.075 * s, 0.07 * s), 0.014)
    mbox(p, armor, sub(m, 0, 0.004, -0.043 * s), (0.105 * s, 0.07 * s, 0.022 * s), 0.01)
    screw(p, sub(m, 0, 0.004, -0.055 * s, rot=(-90, 0, 0)), 0.03 * s, 0.018 * s, 0.006)
    screw(p, sub(m, 0, 0.004, -0.055 * s, rot=(-90, 0, 0)), -0.03 * s, 0.018 * s, 0.006)
    span = 0.1 * s
    for i in range(fingers):
        u = (i - (fingers - 1) / 2) * span / fingers
        base = sub(m, u, -0.04 * s, 0.006 * s)
        mbox(p, "metal", base, (span / fingers * 0.8, 0.018 * s, 0.05 * s), 0.006, 1)
        finger(p, sub(base, 0, -0.008 * s, 0), (0.042 * s, 0.034 * s, 0.028 * s),
               (18 * curl, 32 * curl, 28 * curl), width=span / fingers * 0.78)
    thumb = sub(m, -0.04 * s, -0.012 * s, 0.04 * s, rot=(0, 0, 38))
    mbox(p, "metal", thumb, (0.03 * s, 0.022 * s, 0.03 * s), 0.006, 1)
    finger(p, sub(thumb, 0, -0.01 * s, 0.005 * s, rot=(-25, 0, 0)), (0.034 * s, 0.028 * s), (10 * curl, 30 * curl), width=0.03 * s)


def foot(p, m, length=0.42, width=0.26, out=1, toes=2, armor="shell", heel="trim"):
    """Pé em camadas em `m` (origem no chão, sob o tornozelo): sola de borracha, chapa de metal,
    blindagem de cor, calcanhar, dedos articulados e estabilizadores."""
    front = -length * 0.62
    back = length * 0.38
    cz = (front + back) / 2
    mbox(p, "rubber", sub(m, 0, 0.016, cz), (width, 0.032, length), 0.012, 2)
    mbox(p, "metal", sub(m, 0, 0.044, cz + 0.01), (width * 0.94, 0.024, length * 0.9), 0.008, 1)
    mbox(p, armor, sub(m, 0, 0.082, cz + 0.05), (width * 0.76, 0.056, length * 0.5), 0.026)
    mbox(p, heel, sub(m, 0, 0.075, back - 0.05), (width * 0.72, 0.07, 0.085), 0.024)
    mbox(p, "dark", sub(m, 0, 0.115, cz + 0.04), (width * 0.4, 0.024, length * 0.3), 0.008, 1)
    toe_w = width * 0.9 / toes
    hinge_z = front + 0.13
    mtube(p, "metal", sub(m, 0, 0.06, hinge_z, rot=(0, 0, 90)), 0.013, width * 0.92, 8)
    for i in range(toes):
        u = (i - (toes - 1) / 2) * (toe_w + 0.008)
        mbox(p, armor, sub(m, u, 0.062, front + 0.065, rot=(6, 0, 0)), (toe_w, 0.048, 0.12), 0.018)
    for side, k in ((out, 1.0), (-out, 0.7)):
        mbox(p, "dark", sub(m, side * (width / 2 + 0.012), 0.05, cz), (0.03, 0.05 * k, length * 0.46 * k), 0.012)
        screw(p, sub(m, side * (width / 2 + 0.028), 0.05, cz, rot=(0, 0, -90 * side)), 0, 0, 0.007)


# ======================================================================================
# BIT v2: o robô de série do circuito, reconstruído como máquina.
# Silhueta: cabeça-sensor larga e horizontal, ombros baixos e fortes, antebraço esquerdo
# grande com mão de três dedos, canhão integrado no antebraço direito, pernas curtas e pés
# largos. 4,7 cabeças de altura.
# ======================================================================================
BIT = {
    "hip": Vector((0.215, 0.64, 0.0)),
    "muzzle": Vector((0.44, 0.76, -0.9)),
    "elbow_r": Vector((0.49, 0.99, -0.02)),
    "elbow_l": Vector((-0.5, 0.99, 0.0)),
    "wrist_l": Vector((-0.53, 0.72, -0.1)),
    "shoulder_y": 1.27,
}
HEAD_C = Vector((0.0, 1.725, 0.0))
HEAD_SIZE = (0.64, 0.36, 0.5)
SCREEN = (0.44, 0.19)


def bit_head(p):
    c = HEAD_C
    w, h, d = HEAD_SIZE
    top = c.y + h / 2
    HEADS["bit2_head"] = {"top": round(top + 0.03, 3), "center": round(c.y, 3), "aspect": round(SCREEN[0] / SCREEN[1], 3)}
    base = Matrix.Translation(c)
    # Estrutura interna escura, visível nas fendas entre painéis.
    mbox(p, "dark", sub(base, 0, 0, 0.02), (w - 0.07, h - 0.05, d - 0.11), 0.05, 2)
    # Painéis exteriores separados.
    mbox(p, "shell", sub(base, 0, h / 2 - 0.012, 0.03), (w - 0.02, 0.05, d - 0.1), 0.03)          # tampo
    for side in (-1, 1):
        mbox(p, "shell", sub(base, side * (w / 2 - 0.022), -0.005, 0.04), (0.045, h - 0.07, d - 0.14), 0.025)  # ilhargas
    mbox(p, "shell", sub(base, 0, 0.0, d / 2 - 0.02), (w - 0.1, h - 0.08, 0.045), 0.025)            # nuca
    mbox(p, "dark", sub(base, 0, -h / 2 + 0.018, 0.02), (w - 0.1, 0.03, d - 0.12), 0.012, 1)       # fundo
    # Frente: pala por cima do ecrã, queixo e montantes, em volta de um ecrã recuado.
    front = c.z - d / 2
    mbox(p, "trim", sub(base, 0, h / 2 - 0.045, -d / 2 + 0.045, rot=(-8, 0, 0)), (w + 0.02, 0.075, 0.1), 0.03)
    mbox(p, "shell", sub(base, 0, -h / 2 + 0.042, -d / 2 + 0.05), (w - 0.04, 0.06, 0.08), 0.026)
    for side in (-1, 1):
        mbox(p, "shell", sub(base, side * (SCREEN[0] / 2 + 0.05), -0.012, -d / 2 + 0.05), (0.07, h - 0.14, 0.08), 0.022)
    # Poço do ecrã, anel de retenção e o ecrã 4 cm atrás da moldura.
    mbox(p, "dark", sub(base, 0, -0.012, -d / 2 + 0.085), (SCREEN[0] + 0.04, SCREEN[1] + 0.04, 0.05), 0.012, 1)
    ring_m = sub(base, 0, -0.012, -d / 2 + 0.045)
    for dy in (-1, 1):
        mbox(p, "metal", sub(ring_m, 0, dy * (SCREEN[1] / 2 + 0.008), 0), (SCREEN[0] + 0.03, 0.012, 0.012), 0.004, 1)
    for dx in (-1, 1):
        mbox(p, "metal", sub(ring_m, dx * (SCREEN[0] / 2 + 0.008), 0, 0), (0.012, SCREEN[1] + 0.03, 0.012), 0.004, 1)
    p.screen((c.x, c.y - 0.012, front + 0.055), SCREEN, bulge=0.012)
    # Parafusos: cantos do tampo e das ilhargas.
    top_m = sub(base, 0, h / 2 + 0.014, 0.03)
    for u in (-1, 1):
        for wv in (-1, 1):
            screw(p, top_m, u * (w / 2 - 0.06), wv * ((d - 0.1) / 2 - 0.04))
    for side in (-1, 1):
        side_m = sub(base, side * (w / 2 + 0.002), -0.005, 0.04, rot=(0, 0, -90 * side))
        for wv in (-1, 1):
            screw(p, side_m, 0.0, wv * 0.15)
    # Faixa de equipa no tampo: lê-se de cima, no meio da arena.
    mbox(p, "team", sub(base, 0, h / 2 + 0.016, 0.0), (0.09, 0.012, d - 0.2), 0.004, 1)
    # Telémetro no lado direito: suporte, tubo da lente, aro e lente com luz.
    mount = sub(base, w / 2 + 0.03, 0.03, -0.06)
    mbox(p, "dark", mount, (0.05, 0.11, 0.13), 0.014)
    screw(p, sub(mount, 0.028, 0, 0, rot=(0, 0, -90)), 0.03, 0.03, 0.007)
    screw(p, sub(mount, 0.028, 0, 0, rot=(0, 0, -90)), -0.03, -0.03, 0.007)
    lens = sub(base, w / 2 + 0.06, 0.04, -0.13, rot=(-90, 0, 0))
    mtube(p, "trim", lens, 0.042, 0.1, 16, bevel=0.006)
    mtube(p, "metal", sub(lens, 0, 0.053, 0), 0.034, 0.012, 16)
    mtube(p, "glow", sub(lens, 0, 0.058, 0), 0.022, 0.006, 14)
    # Lidar no tampo, à esquerda, e antena de sinal atrás à direita.
    lid = sub(base, -0.15, h / 2 + 0.035, 0.07)
    mtube(p, "dark", lid, 0.07, 0.045, 18, bevel=0.008)
    mring(p, "glow", sub(lid, 0, 0.0, 0), 0.071, 0.006, 22, 4)
    mtube(p, "metal", sub(lid, 0, 0.03, 0), 0.052, 0.018, 16, bevel=0.004)
    ant = Vector((0.19, top + 0.01, 0.15))
    mtube(p, "metal", Matrix.Translation(ant + Vector((0, 0.012, 0))), 0.028, 0.03, 10, bevel=0.005)
    rod(p, "dark", ant + Vector((0, 0.02, 0)), ant + Vector((0.02, 0.22, 0.02)), 0.008, 6)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=5, radius=0.022)
    p.add("glow", bm, Matrix.Translation(ant + Vector((0.02, 0.235, 0.02))))
    # LED de estado e microfone no lado esquerdo.
    left = sub(base, -w / 2 - 0.004, 0.06, -0.1, rot=(0, 0, 90))
    mbox(p, "glow", left, (0.03, 0.012, 0.018), 0.004, 1)
    for i in range(3):
        mbox(p, "dark", sub(base, -w / 2 - 0.002, -0.06 + i * 0.022, 0.05), (0.012, 0.01, 0.06), 0.003, 1)


def bit_torso(p):
    # --- pescoço: placas de montagem, veio, rolamento, vedante, conduta e batente ---
    neck_y0, neck_y1 = 1.39, 1.535
    mbox(p, "dark", Matrix.Translation((0, neck_y0 + 0.012, 0.02)), (0.27, 0.024, 0.24), 0.01, 1)
    mbox(p, "dark", Matrix.Translation((0, neck_y1, 0.02)), (0.28, 0.02, 0.25), 0.01, 1)
    mtube(p, "metal", Matrix.Translation((0, (neck_y0 + neck_y1) / 2, 0.02)), 0.05, neck_y1 - neck_y0, 14)
    mring(p, "metal", Matrix.Translation((0, 1.49, 0.02)), 0.085, 0.015, 22, 5)
    mtube(p, "rubber", Matrix.Translation((0, 1.452, 0.02)), 0.078, 0.036, 18)
    bolts(p, Matrix.Translation((0, neck_y0 + 0.024, 0.02)), 0.105, 6, size=0.012)
    mbox(p, "dark", Matrix.Translation((0.075, neck_y0 + 0.04, -0.055)), (0.025, 0.03, 0.025), 0.005, 1)
    cable(p, [(0.08, 1.41, 0.12), (0.1, 1.47, 0.14), (0.09, 1.53, 0.13)], 0.012)
    # --- chassis do tronco ---
    chest = Vector((0, 1.16, 0.02))
    mbox(p, "dark", Matrix.Translation(chest), (0.58, 0.46, 0.42), 0.05)
    # Blindagem: peito superior, duas placas centrais à volta do núcleo, abdómen, ilhargas, costas.
    mbox(p, "shell", sub(Matrix.Translation((0, 1.325, -0.2)), rot=(-10, 0, 0)), (0.64, 0.15, 0.08), 0.035)
    for side in (-1, 1):
        plate = Matrix.Translation((side * 0.19, 1.13, -0.215))
        mbox(p, "shell", plate, (0.2, 0.2, 0.07), 0.028)
        screw(p, sub(plate, 0, 0, -0.037, rot=(-90, 0, 0)), side * 0.06, 0.07)
        screw(p, sub(plate, 0, 0, -0.037, rot=(-90, 0, 0)), side * 0.06, -0.07)
    mbox(p, "trim", sub(Matrix.Translation((0, 0.975, -0.19)), rot=(8, 0, 0)), (0.46, 0.1, 0.07), 0.03)
    for side in (-1, 1):
        mbox(p, "shell", Matrix.Translation((side * 0.315, 1.08, 0.02)), (0.05, 0.2, 0.34), 0.022)
    vents(p, Matrix.Translation((0.342, 1.085, 0.06)), 4, 0.012, depth=0.1, spacing=0.035)
    back = Matrix.Translation((0, 1.16, 0.255))
    mbox(p, "shell", back, (0.5, 0.36, 0.06), 0.03)
    # --- núcleo no peito: moldura de proteção, anel de retenção e a célula de energia ---
    core = Matrix.Translation((0, 1.13, -0.2))
    mbox(p, "dark", core, (0.16, 0.18, 0.06), 0.012, 1)
    for dy in (-1, 1):
        mbox(p, "trim", sub(core, 0, dy * 0.098, -0.03), (0.17, 0.022, 0.04), 0.008)
    cell = sub(core, 0, 0, -0.03, rot=(90, 0, 0))
    mring(p, "metal", cell, 0.056, 0.01, 20, 5)
    mtube(p, "glow", sub(cell, 0, -0.004, 0), 0.046, 0.012, 18)
    mtube(p, "dark", sub(cell, 0, -0.012, 0), 0.02, 0.012, 10)
    # --- mochila: célula de reserva num quadro, com tampa de manutenção ---
    pack = Matrix.Translation((0, 1.18, 0.34))
    mbox(p, "dark", pack, (0.36, 0.3, 0.1), 0.02)
    mbox(p, "trim", sub(pack, 0, 0.0, 0.055), (0.3, 0.24, 0.035), 0.016)
    for u in (-1, 1):
        for v in (-1, 1):
            screw(p, sub(pack, u * 0.125, v * 0.095, 0.074, rot=(90, 0, 0)), 0, 0)
    mbox(p, "glow", sub(pack, 0.1, 0.13, 0.03), (0.05, 0.018, 0.03), 0.005, 1)
    for u in (-1, 1):
        mbox(p, "dark", sub(pack, u * 0.2, 0, -0.01), (0.03, 0.26, 0.07), 0.01)
        mbox(p, "dark", sub(pack, u * 0.11, 0.18, 0.02), (0.025, 0.06, 0.025), 0.006, 1)
    mbox(p, "metal", sub(pack, 0, 0.21, 0.02), (0.25, 0.024, 0.03), 0.01, 1)
    # --- cintura: coluna, rolamento de guinada, fole e estabilizadores ---
    mtube(p, "dark", Matrix.Translation((0, 0.85, 0.02)), 0.11, 0.16, 18)
    mring(p, "metal", Matrix.Translation((0, 0.915, 0.02)), 0.15, 0.018, 24, 5)
    bolts(p, Matrix.Translation((0, 0.925, 0.02)), 0.15, 8, size=0.011, phase=0.2)
    for y in (0.8, 0.83, 0.86):
        mring(p, "rubber", Matrix.Translation((0, y, 0.02)), 0.112, 0.016, 20, 5)
    for side in (-1, 1):
        piston(p, (side * 0.13, 0.76, 0.1), (side * 0.17, 0.93, 0.1), 0.02)
    # --- bacia: chassis de distribuição, placa da frente e de trás, alojamentos das ancas ---
    pelvis = Matrix.Translation((0, 0.67, 0.0))
    mbox(p, "dark", pelvis, (0.28, 0.18, 0.28), 0.035)
    mbox(p, "trim", sub(pelvis, 0, -0.01, -0.16, rot=(10, 0, 0)), (0.24, 0.15, 0.05), 0.022)
    mbox(p, "team", sub(pelvis, 0, 0.03, -0.188, rot=(10, 0, 0)), (0.12, 0.028, 0.01), 0.004, 1)
    mbox(p, "shell", sub(pelvis, 0, 0.0, 0.16), (0.22, 0.13, 0.05), 0.02)
    for side in (-1, 1):
        house = axis_frame((side * 0.152, 0.64, 0.0), "x" if side > 0 else "-x")
        mtube(p, "dark", house, 0.09, 0.04, 20, bevel=0.006)
        bolts(p, sub(house, 0, 0.022, 0), 0.075, 6, size=0.01)
        mtube(p, "metal", sub(house, 0, 0.06, 0), 0.04, 0.1, 12)
    # --- suportes dos ombros no tronco ---
    for side in (-1, 1):
        mbox(p, "dark", Matrix.Translation((side * 0.35, BIT["shoulder_y"], 0.01)), (0.07, 0.17, 0.19), 0.018)
    # Cabos dos ombros: do tronco ao braço, com folga.
    for side in (-1, 1):
        cable(p, [(side * 0.3, 1.36, 0.14), (side * 0.4, 1.4, 0.15), (side * 0.47, 1.2, 0.09)], 0.011)


def bit_shoulder(p, side):
    y = BIT["shoulder_y"]
    # Rolamento no suporte do tronco (eixo X), tambor que roda, e o garfo do braço por baixo.
    bearing(p, axis_frame((side * 0.4, y, 0.01), "x" if side > 0 else "-x"), 0.105, 0.035, 6)
    drum = axis_frame((side * 0.465, y, 0.01), "x")
    mtube(p, "trim", drum, 0.082, 0.08, 18, bevel=0.01)
    mring(p, "dark", sub(drum, 0, side * 0.03, 0), 0.083, 0.008, 18, 4)
    # Garfo de abdução (pino ao longo de Z), duas faces à frente e atrás do olhal do braço.
    pin = Vector((side * 0.47, y - 0.12, 0.01))
    for dz in (-1, 1):
        mbox(p, "dark", Matrix.Translation(pin + Vector((0, 0.055, dz * 0.052))), (0.07, 0.13, 0.022), 0.01)
    mtube(p, "metal", axis_frame(pin, "z"), 0.016, 0.14, 8)
    for dz in (-1, 1):
        mtube(p, "metal", axis_frame(pin + Vector((0, 0, dz * 0.068)), "z" if dz > 0 else "-z"), 0.026, 0.01, 10)
    # Ombreira em duas placas (tampo e aba de fora), presas ao tambor por suportes internos:
    # tapa o rolamento por cima e por fora, e deixa-o à vista de frente e de trás.
    mbox(p, "dark", Matrix.Translation((side * 0.47, y + 0.1, 0.01)), (0.06, 0.07, 0.1), 0.01, 1)
    mbox(p, "dark", Matrix.Translation((side * 0.55, y, 0.01)), (0.09, 0.05, 0.06), 0.01, 1)
    cap = sub(Matrix.Translation((side * 0.5, y + 0.155, 0.01)), rot=(0, 0, -side * 10))
    mbox(p, "shell", cap, (0.27, 0.07, 0.33), 0.035)
    mbox(p, "team", sub(cap, 0, 0.038, 0), (0.08, 0.01, 0.22), 0.004, 1)
    for wv in (-1, 1):
        screw(p, sub(cap, 0, 0.036, 0), -side * 0.08, wv * 0.12)
    flap = sub(Matrix.Translation((side * 0.625, y + 0.035, 0.01)), rot=(0, 0, -side * 16))
    mbox(p, "shell", flap, (0.06, 0.19, 0.31), 0.03)
    mbox(p, "trim", sub(flap, 0, -0.105, 0), (0.07, 0.035, 0.32), 0.014)
    for wv in (-1, 1):
        screw(p, sub(flap, side * 0.031, 0.03, 0, rot=(0, 0, -90 * side)), 0.0, wv * 0.1)


def bit_upper_arm(p, side, elbow):
    y = BIT["shoulder_y"]
    pin = Vector((side * 0.47, y - 0.12, 0.01))
    # Olhal no garfo do ombro, osso escuro, servo e duas placas de blindagem.
    mtube(p, "dark", axis_frame(pin, "z"), 0.032, 0.075, 12)
    rod(p, "dark", pin, elbow + Vector((0, 0.06, 0)), 0.04, 10)
    servo = axis_frame(pin.lerp(elbow, 0.45) + Vector((0, 0, 0.05)), "x")
    mtube(p, "dark", servo, 0.034, 0.06, 12)
    mtube(p, "metal", sub(servo, 0, 0.034, 0), 0.02, 0.01, 10)
    arm = frame(pin.lerp(elbow, 0.5), elbow - pin)
    mbox(p, "shell", sub(arm, 0, 0.0, 0.058), (0.13, 0.11, 0.035), 0.014)
    mbox(p, "trim", sub(arm, side * 0.07, 0.0, 0.005), (0.032, 0.11, 0.12), 0.012)
    # Cotovelo: dobradiça com garfo, eixo e tampas; atuador por trás.
    hinge(p, axis_frame(elbow, "y"), 0.075, 0.048, fork_len=0.09)
    piston(p, pin.lerp(elbow, 0.3) + Vector((0, 0, 0.06)), elbow + Vector((0, -0.08, 0.07)), 0.016)


def bit_forearm_left(p):
    e, wr = BIT["elbow_l"], BIT["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    # Olhal do cotovelo e caixa de equipamento do antebraço, grande de propósito.
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    housing = sub(m, 0, length * 0.56, 0.01)
    mbox(p, "dark", housing, (0.2, length * 0.72, 0.21), 0.03)
    mbox(p, "shell", sub(housing, 0, 0.0, 0.035), (0.24, length * 0.66, 0.17), 0.04)
    mbox(p, "trim", sub(housing, 0, length * 0.3, 0.02), (0.25, 0.05, 0.25), 0.02)
    # Tampa de manutenção no lado de fora, ventilação na frente e luz de estado.
    hatch = sub(housing, -0.121, -0.02, 0.02, rot=(0, 0, 90))
    mbox(p, "dark", hatch, (0.1, 0.012, 0.1), 0.01, 1)
    for u in (-1, 1):
        for wv in (-1, 1):
            screw(p, sub(hatch, 0, 0.008, 0), u * 0.036, wv * 0.036, 0.007)
    vents(p, sub(housing, 0.02, -0.03, 0.123), 3, 0.1, depth=0.01, spacing=0.03)
    mbox(p, "glow", sub(housing, 0.06, 0.08, 0.124), (0.03, 0.03, 0.01), 0.004, 1)
    # Pulso: placa de fim, rolamento, pulso estreito, colar de borracha e placa da mão.
    wrist = sub(m, 0, length, 0)
    mtube(p, "dark", sub(wrist, 0, -0.005, 0), 0.07, 0.02, 16)
    mring(p, "metal", sub(wrist, 0, 0.012, 0), 0.052, 0.012, 16, 5)
    mtube(p, "dark", sub(wrist, 0, 0.04, 0), 0.036, 0.06, 12)
    mring(p, "rubber", sub(wrist, 0, 0.032, 0), 0.04, 0.012, 14, 5)
    plate = sub(wrist, 0, 0.074, 0)
    mbox(p, "dark", plate, (0.1, 0.02, 0.09), 0.008, 1)
    for u in (-1, 1):
        for wv in (-1, 1):
            mtube(p, "metal", sub(plate, u * 0.04, 0.012, wv * 0.034), 0.007, 0.008, 6)
    # Mão de três dedos, palma virada para o corpo.
    palm = sub(m, 0, length + 0.15, 0.0, rot=(0, -90, 180))
    hand(p, palm, fingers=3, scale=1.5, curl=1.2)
    cable(p, [at(m, 0.08, 0.02, -0.06), at(m, 0.12, length * 0.2, -0.09), at(m, 0.1, length * 0.4, -0.08)], 0.01)


def bit_forearm_right(p):
    e, muzzle = BIT["elbow_r"], BIT["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    # Caixa do canhão: chassis, blindagem em três placas, anel de interface na frente.
    housing = sub(m, 0, 0.27, 0)
    mbox(p, "dark", housing, (0.22, 0.36, 0.22), 0.03)
    mbox(p, "shell", sub(housing, 0, -0.02, 0.045), (0.26, 0.28, 0.14), 0.04)
    for side in (-1, 1):
        mbox(p, "shell", sub(housing, side * 0.118, 0.02, -0.07), (0.035, 0.26, 0.07), 0.014)
    mbox(p, "trim", sub(housing, 0, 0.16, 0.0), (0.27, 0.05, 0.27), 0.02)
    mbox(p, "team", sub(housing, 0, -0.03, 0.118), (0.06, 0.2, 0.01), 0.004, 1)
    for i in range(3):
        mbox(p, "dark", sub(housing, 0.131, -0.03, 0.02 + (i - 1) * 0.03), (0.012, 0.12, 0.012), 0.004, 1)
    mbox(p, "glow", sub(housing, -0.07, -0.09, 0.117), (0.03, 0.03, 0.01), 0.004, 1)
    for v in (-1, 1):
        screw(p, sub(housing, 0.0, v * 0.1, 0.116, rot=(90, 0, 0)), 0.08, 0)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.1, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.084, 6, size=0.01)
    cable(p, [at(m, -0.1, 0.05, 0.08), at(m, -0.14, 0.18, 0.1), at(m, -0.12, 0.3, 0.08)], 0.01)


def bit_gun(p):
    """Só o cano: é o que recua para dentro da caixa do antebraço quando dispara."""
    e, muzzle = BIT["elbow_r"], BIT["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.5, 0), 0.07, 0.12, 16)
    mtube(p, "dark", sub(m, 0, 0.68, 0), 0.085, 0.3, 18, bevel=0.008)
    for v in (0.6, 0.66, 0.72):
        mring(p, "glow", sub(m, 0, v, 0), 0.088, 0.008, 18, 4)
    brake = sub(m, 0, length - 0.035, 0)
    mtube(p, "trim", brake, 0.1, 0.07, 18, bevel=0.012)
    for u in (-1, 1):
        mbox(p, "dark", sub(brake, u * 0.1, 0, 0), (0.025, 0.04, 0.05), 0.006, 1)
    mtube(p, "dark", sub(brake, 0, 0.036, 0), 0.062, 0.004, 16)
    mtube(p, "glow", sub(brake, 0, 0.03, 0), 0.05, 0.008, 16)


def bit_leg(p, out):
    """Perna no espaço da perna (pivô da anca na origem, chão em y = -hip.y). `out` é o sinal
    do lado de fora: +1 na perna direita, -1 na esquerda."""
    ground = -BIT["hip"].y
    knee = Vector((0, -0.24, -0.01))
    ankle = Vector((0, ground + 0.14, 0.0))
    # Tambor da anca à volta do eixo que sai da bacia, tampa de fora com parafusos e porca.
    drum = axis_frame((0.022 * out, 0, 0), "x" if out > 0 else "-x")
    mtube(p, "dark", drum, 0.082, 0.11, 18, bevel=0.01)
    cap = sub(drum, 0, 0.064, 0)
    mtube(p, "metal", cap, 0.06, 0.018, 18)
    bolts(p, sub(cap, 0, 0.01, 0), 0.045, 6, size=0.01)
    mtube(p, "metal", sub(cap, 0, 0.016, 0), 0.022, 0.02, 6)
    # Coxa: viga, atuador linear atrás, blindagem da frente e do lado de fora.
    mbox(p, "dark", Matrix.Translation((0, -0.13, 0.0)), (0.13, 0.18, 0.15), 0.02)
    piston(p, (0, -0.04, 0.1), (0, knee.y + 0.02, 0.09), 0.022)
    mbox(p, "shell", sub(Matrix.Translation((0, -0.14, -0.1)), rot=(-4, 0, 0)), (0.24, 0.17, 0.06), 0.025)
    mbox(p, "trim", Matrix.Translation((0.118 * out, -0.14, 0.0)), (0.035, 0.15, 0.2), 0.014)
    screw(p, sub(Matrix.Translation((0.136 * out, -0.14, 0.0)), rot=(0, 0, -90 * out)), 0.0, 0.06)
    screw(p, sub(Matrix.Translation((0.136 * out, -0.14, 0.0)), rot=(0, 0, -90 * out)), 0.0, -0.06)
    # Joelho: garfo da coxa, cilindro, eixo, discos com parafusos; joelheira presa à canela.
    hinge(p, axis_frame(knee, "y"), 0.12, 0.064, fork_len=0.08, fork_thick=0.026)
    guard = sub(Matrix.Translation(knee + Vector((0, 0.005, -0.095))), rot=(18, 0, 0))
    mbox(p, "trim", guard, (0.17, 0.11, 0.05), 0.02)
    mbox(p, "dark", Matrix.Translation(knee + Vector((0, -0.02, -0.045))), (0.05, 0.05, 0.04), 0.008, 1)
    # Canela: quadro, blindagem que afunila, placa com ventilação no lado de fora, barriga atrás.
    mbox(p, "dark", Matrix.Translation((0, (knee.y + ankle.y) / 2, 0.01)), (0.12, knee.y - ankle.y, 0.12), 0.018)
    shin = Matrix.Translation((0, (knee.y + ankle.y) / 2 - 0.015, -0.068))
    mbox(p, "shell", sub(shin, rot=(0, 0, 180)), (0.22, 0.17, 0.08), 0.026, taper=(0.8, 0.86))
    side = Matrix.Translation((0.1 * out, (knee.y + ankle.y) / 2, 0.035))
    mbox(p, "trim", side, (0.03, 0.15, 0.12), 0.01)
    vents(p, sub(side, 0.016 * out, 0.0, 0.0), 3, 0.012, depth=0.08, spacing=0.03)
    mbox(p, "shell", Matrix.Translation((0, (knee.y + ankle.y) / 2 + 0.01, 0.085)), (0.16, 0.13, 0.05), 0.018)
    # Tornozelo: garfo da canela, eixo horizontal, discos, amortecedor e colar de borracha.
    mring(p, "rubber", Matrix.Translation(ankle + Vector((0, 0.05, 0.01))), 0.058, 0.014, 16, 5)
    hinge(p, axis_frame(ankle, "y"), 0.075, 0.034, fork_len=0.06, fork_thick=0.02, bolt_count=0)
    piston(p, ankle + Vector((0, 0.1, 0.07)), ankle + Vector((0, -0.05, 0.1)), 0.014)
    mbox(p, "dark", Matrix.Translation(ankle + Vector((0, -0.04, 0.0))), (0.11, 0.024, 0.13), 0.008, 1)
    foot(p, Matrix.Translation((0, ground, 0.0)), length=0.46, width=0.3, out=out)


def define_parts():
    part("bit2_head")(bit_head)
    part("bit2_torso")(bit_torso)

    @part("bit2_shoulders")
    def _(p):
        for side in (-1, 1):
            bit_shoulder(p, side)

    @part("bit2_arm")
    def _(p):
        bit_upper_arm(p, -1, BIT["elbow_l"])
        bit_upper_arm(p, 1, BIT["elbow_r"])
        bit_forearm_left(p)
        bit_forearm_right(p)

    part("bit2_gun")(bit_gun)

    @part("bit2_leg_l")
    def _(p):
        bit_leg(p, -1)

    @part("bit2_leg_r")
    def _(p):
        bit_leg(p, 1)
