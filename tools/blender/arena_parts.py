"""Peças da arena flutuante para o kit (art/robots/kit.glb): muralha modular, torres com
holofote, pilares das balizas e adereços do convés (sucata, caixas, barris, contentor, grua,
drone, placar, antena, plataforma de aterragem, nuvem, propulsor, cabeça de robô, roda
dentada). O jogo pinta-as como os robôs (papéis de cor nos vértices) e espalha-as à volta do
contorno de cada mapa (scripts/arena_sky.gd).

Coordenadas em unidades do Godot: Y para cima, origem no chão. A muralha tem 1 m ao longo de
X com a face de dentro para +Z; as torres apontam o holofote para +Z.
"""
import math
import random

from mathutils import Vector

from mech_kit import at, axis_frame, bolts, dome, frame, lathe, mbox, mring, mtube, piston, rod, sub, vents
from mech_parts import T
from mech_cast import arc_tube, ball


def wall(p):
    """Módulo de muralha: viga escura, sapata de borracha, blindagem nas duas faces com a faixa
    da equipa, parafusos nas pontas, tampa, luz na aresta de dentro e ventilação por fora."""
    mbox(p, "dark", T(0, 0.2, 0), (1.04, 0.4, 0.3), 0.04, 1)
    mbox(p, "rubber", T(0, 0.02, 0), (1.02, 0.05, 0.36), 0.02, 1)
    for s in (-1, 1):
        mbox(p, "shell", T(0, 0.3, s * 0.17), (0.94, 0.46, 0.06), 0.028, 1)
        mbox(p, "team", T(0, 0.2, s * 0.205), (0.86, 0.07, 0.02), 0.0, 1)
    for v in (-1, 1):
        mtube(p, "metal", sub(T(v * 0.39, 0.46, 0.202), rot=(90, 0, 0)), 0.014, 0.012, 6, caps=True)
    mbox(p, "shell", T(0, 0.57, 0), (0.96, 0.06, 0.4), 0.025, 1)
    mbox(p, "glow", T(0, 0.52, 0.212), (0.98, 0.025, 0.02), 0.0, 1)
    vents(p, T(0, 0.36, -0.2), 2, 0.34, depth=0.02, spacing=0.06, height=0.015)


def pylon(p):
    """Torre de canto: tambor escuro, cintas de blindagem, faixa de perigo, rolamento com
    parafusos, cúpula e holofote numa haste, virado para +Z e para baixo."""
    mtube(p, "dark", T(0, 0.55, 0), 0.26, 1.1, 14)
    for y in (0.25, 0.75):
        mtube(p, "shell", T(0, y, 0), 0.3, 0.32, 16, bevel=0.03)
    mring(p, "hazard", T(0, 0.47, 0), 0.3, 0.03, 16, 4)
    mring(p, "metal", T(0, 1.0, 0), 0.27, 0.025, 16, 4)
    bolts(p, T(0, 1.03, 0), 0.22, 6, size=0.02)
    dome(p, "trim", T(0, 1.1, 0), 0.24, 0.16, 14, 4)
    head = Vector((0, 1.45, 0.05))
    rod(p, "dark", (0, 1.2, 0), head, 0.04, 10)
    lamp = frame(head, Vector((0, -0.55, 1.0)), front=(0, 1, 0))
    mtube(p, "dark", lamp, 0.13, 0.16, 12)
    mtube(p, "glow", sub(lamp, 0, 0.085, 0), 0.105, 0.01, 12)
    mring(p, "metal", sub(lamp, 0, 0.08, 0), 0.12, 0.012, 12, 4)
    mtube(p, "metal", axis_frame(head, "x"), 0.03, 0.3, 10)


def goalposts(p):
    """Pilares das balizas: blindados, com anel da equipa, eixo com parafusos e pistão."""
    for x in (-1.95, 1.95):
        mbox(p, "dark", T(x, 0.7, 0), (0.36, 1.4, 0.4), 0.05)
        mbox(p, "shell", T(x, 0.55, 0.05), (0.42, 0.9, 0.44), 0.06)
        mbox(p, "team", T(x, 1.08, 0.05), (0.43, 0.08, 0.45), 0.02, 1)
        mtube(p, "metal", axis_frame((x, 1.45, 0), "z"), 0.14, 0.46, 16)
        bolts(p, axis_frame((x, 1.45, 0.23), "z"), 0.1, 6, size=0.02)
        dome(p, "trim", T(x, 1.4, 0), 0.2, 0.12, 16, 4)
        piston(p, (x * 0.85, 0.15, 0.45), (x * 0.9, 1.1, 0.2), 0.05)


def scrap_pile(p, seed):
    rng = random.Random(seed)
    for k in range(6):
        mbox(p, rng.choice(["label", "trim", "shell", "dark"]),
             sub(T(rng.uniform(-0.6, 0.6), 0.08 + k * 0.06, rng.uniform(-0.6, 0.6)), rot=(rng.uniform(-25, 25), rng.uniform(0, 180), rng.uniform(-25, 25))),
             (rng.uniform(0.4, 0.9), 0.05, rng.uniform(0.3, 0.6)), 0.02, 1)
    for k in range(3):
        a = Vector((rng.uniform(-0.7, 0.7), rng.uniform(0.1, 0.4), rng.uniform(-0.7, 0.7)))
        b = a + Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.1, 0.3), rng.uniform(-0.8, 0.8)))
        rod(p, rng.choice(["metal", "trim"]), a, b, 0.05, 10)
    gear(p, (0.4, 0.3, -0.3), 0.3, rng.uniform(0, 90))
    tire(p, (-0.5, 0.0, 0.4))
    robot_head(p, (0.1, 0.35, 0.2), rng.uniform(0, 360))


def gear(p, pos, radius, yaw, role="label"):
    m = sub(T(pos[0], pos[1] + 0.05, pos[2]), rot=(12, yaw, -8))
    mtube(p, role, m, radius, 0.08, 14)
    mtube(p, "dark", m, radius * 0.3, 0.1, 8)
    for k in range(8):
        mbox(p, role, sub(m, 0, 0, 0, rot=(0, k * 45, 0)) @ T(radius + 0.04, 0, 0), (0.1, 0.08, 0.08), 0.0, 1)


def tire(p, pos):
    m = sub(T(pos[0], pos[1] + 0.08, pos[2]), rot=(6, 0, -8))
    mring(p, "rubber", m, 0.26, 0.1, 14, 6)
    mtube(p, "metal", m, 0.17, 0.08, 10)


def robot_head(p, pos, yaw):
    m = sub(T(pos[0], pos[1] + 0.2, pos[2]), rot=(18, yaw, -22))
    mbox(p, "shell", m, (0.5, 0.36, 0.38), 0.07, 3)
    mbox(p, "dark", sub(m, 0, 0, -0.19), (0.36, 0.2, 0.02), 0.02, 1)
    mbox(p, "glow", sub(m, -0.08, 0.02, -0.2), (0.05, 0.08, 0.01), 0.01, 1)
    mtube(p, "dark", sub(m, 0, -0.24, 0), 0.08, 0.12, 12)
    rod(p, "metal", at(m, 0.12, 0.18, 0), at(m, 0.16, 0.42, 0.05), 0.012)


def crate(p, pos, size, yaw, role):
    m = sub(T(pos[0], pos[1] + size / 2, pos[2]), rot=(0, yaw, 0))
    mbox(p, role, m, (size, size, size), 0.04, 2)
    for u in (-1, 1):
        mbox(p, "dark", sub(m, u * size * 0.36, 0, 0), (size * 0.1, size * 1.01, size * 1.01), 0.01, 1)
    mbox(p, "dark", m, (size * 1.01, size * 0.1, size * 1.01), 0.01, 1)


def crates(p):
    crate(p, (0, 0, 0), 0.62, 12, "shell")
    crate(p, (0.55, 0, 0.2), 0.48, -20, "trim")
    crate(p, (0.08, 0.62, 0.02), 0.42, 40, "trim")


def barrel(p, pos, role, lying=False, yaw=0.0):
    m = sub(T(pos[0], pos[1] + (0.2 if lying else 0.3), pos[2]), rot=(90 if lying else 0, yaw, 0))
    mtube(p, role, m, 0.2, 0.58, 12, bevel=0.02)
    for v in (-0.18, 0.18):
        mring(p, "dark", sub(m, 0, v, 0), 0.205, 0.018, 12, 4)
    mtube(p, "metal", sub(m, 0, 0.29, 0), 0.05, 0.02, 8)


def barrels(p):
    barrel(p, (0, 0, 0), "shell")
    barrel(p, (0.44, 0, 0.1), "trim")
    barrel(p, (0.2, 0, 0.55), "shell", lying=True, yaw=70)


def container(p):
    m = T(0, 0.45, 0)
    mbox(p, "shell", m, (2.2, 0.9, 0.95), 0.04, 2)
    for k in range(9):
        mbox(p, "shell", sub(m, -0.98 + k * 0.245, 0, 0), (0.06, 0.86, 0.99), 0.01, 1)
    for u in (-1.1, 1.1):
        mbox(p, "dark", sub(m, u, 0, 0), (0.04, 0.92, 0.97), 0.01, 1)
    mbox(p, "hazard", sub(m, 0.6, 0.28, -0.49), (0.3, 0.1, 0.01), 0.0, 1)


def crane(p):
    """Grua robótica: torre giratória com faixa de perigo, dois braços com eixos e pistões,
    garra de três dedos e um bloco de sucata preso."""
    mtube(p, "dark", T(0, 0.2, 0), 0.6, 0.4, 24, bevel=0.03)
    mring(p, "hazard", T(0, 0.4, 0), 0.6, 0.04, 24, 5)
    mtube(p, "shell", T(0, 0.7, 0), 0.4, 0.6, 20, bevel=0.05)
    bolts(p, T(0, 1.0, 0), 0.32, 8, size=0.03)
    shoulder = Vector((0, 1.1, 0))
    reach = Vector((-1.5, 0, 2.8))
    elbow = shoulder.lerp(reach, 0.5) + Vector((0, 2.2, 0))
    wrist = reach + Vector((0, 0.9, 0))
    for a0, a1, w in ((shoulder, elbow, 0.2), (elbow, wrist, 0.15)):
        rod(p, "trim", a0, a1, w, 14)
        mtube(p, "metal", axis_frame(a0, "x"), w * 1.2, w * 2.4, 16)
        piston(p, a0 + (a1 - a0) * 0.1 + Vector((0, -0.2, 0)), a0 + (a1 - a0) * 0.6 + Vector((0, -0.1, 0)), 0.06)
    mtube(p, "dark", T(wrist.x, wrist.y, wrist.z), 0.16, 0.2, 14)
    for k in range(3):
        a = math.radians(k * 120)
        d = Vector((math.cos(a), 0, math.sin(a)))
        rod(p, "metal", wrist, wrist + d * 0.3 + Vector((0, -0.3, 0)), 0.04)
        rod(p, "metal", wrist + d * 0.3 + Vector((0, -0.3, 0)), wrist + d * 0.15 + Vector((0, -0.55, 0)), 0.035)
    mbox(p, "label", T(reach.x, reach.y + 0.2, reach.z), (0.4, 0.3, 0.4), 0.03)


def drone(p):
    mbox(p, "shell", T(0, 0, 0), (0.36, 0.14, 0.36), 0.06, 3)
    mbox(p, "glow", T(0, -0.08, 0), (0.14, 0.02, 0.14), 0.02, 1)
    for dx, dz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        rod(p, "dark", (0, 0, 0), (dx * 0.32, 0.04, dz * 0.32), 0.02)
        mring(p, "dark", T(dx * 0.32, 0.06, dz * 0.32), 0.14, 0.012, 10, 3)
        mtube(p, "metal", T(dx * 0.32, 0.07, dz * 0.32), 0.02, 0.03, 8)


def scoreboard(p):
    """Placar num mastro de treliça: moldura, ecrã escuro com as duas cores e luz em cima.
    O ecrã olha para +Z."""
    y = 3.6
    for dx in (-1.6, 1.6):
        rod(p, "dark", (dx, 0, 0), (dx, y, 0), 0.12)
        for k in range(1, 5):
            rod(p, "metal", (dx, y * k / 5, 0), (dx * 0.8, y * (k + 0.5) / 5, 0), 0.03)
    mbox(p, "shell", T(0, y + 0.9, 0), (3.8, 1.9, 0.3), 0.1, 3)
    mbox(p, "dark", T(0, y + 0.9, 0.16), (3.4, 1.5, 0.02), 0.04, 1)
    mbox(p, "team", T(-0.9, y + 0.9, 0.18), (1.2, 0.8, 0.01), 0.04, 1)
    mbox(p, "trim", T(0.9, y + 0.9, 0.18), (1.2, 0.8, 0.01), 0.04, 1)
    mbox(p, "glow", T(0, y + 1.9, 0), (3.8, 0.05, 0.32), 0.02, 1)


def antenna(p):
    mbox(p, "hazard", T(0, 0.3, 0), (0.3, 0.6, 0.3), 0.04)
    rod(p, "dark", (0, 0.6, 0), (0, 2.2, 0), 0.05)
    ball(p, "glow", (0, 2.25, 0), 0.08, 10)


def pad(p):
    """Plataforma de aterragem: disco escuro, anel e H pintados, luzes à volta."""
    mtube(p, "dark", T(0, 0.02, 0), 0.95, 0.04, 32)
    mring(p, "hazard", T(0, 0.045, 0), 0.8, 0.04, 32, 4)
    for x in (-0.2, 0.2):
        mbox(p, "hazard", T(x, 0.045, 0), (0.08, 0.01, 0.6), 0.0, 1)
    mbox(p, "hazard", T(0, 0.045, 0), (0.4, 0.01, 0.08), 0.0, 1)
    for k in range(8):
        a = math.radians(k * 45)
        ball(p, "glow", (math.cos(a) * 0.95, 0.05, math.sin(a) * 0.95), 0.05, 8)


def cloud(p):
    for dx, dy, r in ((-0.5, 0, 0.45), (0, 0.15, 0.6), (0.55, 0.02, 0.42), (0.2, -0.1, 0.4)):
        ball(p, "shell", (dx, dy, 0), r, 12)


def thruster(p):
    """Propulsor debaixo do casco: tubeira escura, anel de metal e boca acesa (para baixo)."""
    lathe(p, "dark", T(0, 0, 0), [(0.55, 0.3), (0.7, 0.0), (0.8, -0.5), (0.6, -0.55), (0.45, -0.1)], 24)
    mtube(p, "glow", T(0, -0.5, 0), 0.62, 0.02, 24)
    mring(p, "metal", T(0, 0.1, 0), 0.72, 0.05, 24, 5)


def define(part):
    part("arena_wall")(wall)
    part("arena_pylon")(pylon)
    part("arena_goalposts")(goalposts)
    part("prop_scrap_a")(lambda p: scrap_pile(p, 3))
    part("prop_scrap_b")(lambda p: scrap_pile(p, 8))
    part("prop_crates")(crates)
    part("prop_barrels")(barrels)
    part("prop_container")(container)
    part("prop_crane")(crane)
    part("prop_drone")(drone)
    part("prop_scoreboard")(scoreboard)
    part("prop_antenna")(antenna)
    part("prop_pad")(pad)
    part("prop_cloud")(cloud)
    part("prop_thruster")(thruster)

    @part("prop_scrap_bits")
    def _(p):
        robot_head(p, (0, 0, 0), 30)
        gear(p, (0.5, 0.0, 0.1), 0.35, 10)
