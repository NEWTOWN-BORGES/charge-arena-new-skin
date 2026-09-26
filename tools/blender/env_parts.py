"""Peças de cenário dos cinco mapas (chão, subaquático, espaço e cidade; o céu usa
arena_parts.py). Tudo estático e sólido: formas angulosas com biséis pequenos, pintadas pelos
papéis de cor como os robôs, para o jogo as juntar em poucas chamadas de desenho.

Papéis usados: shell (cor principal), trim (segunda cor), dark (estrutura), metal, glow
(luzes), team, rubber, hazard e label (terceira cor). Origem no chão, Y para cima.
"""
import math
import random

from mathutils import Matrix, Vector

from mech_kit import at, axis_frame, bolts, dome, frame, lathe, mbox, mring, mtube, piston, rod, sub, vents
from mech_parts import T
from mech_cast import arc_tube, ball


# ======================================================================================
# Chão: rochas facetadas, pinheiros, painéis solares, turbina, radar, rover, tubagens,
# silos, hangar, vedação e poste de alta tensão
# ======================================================================================
def rock(p, seed, size=1.0):
    """Rocha facetada: prismas de arestas quase vivas empilhados e inclinados, com a face de
    cima num tom mais claro (papel trim)."""
    rng = random.Random(seed)
    for k in range(rng.randint(3, 5)):
        w = size * rng.uniform(0.45, 0.9)
        h = size * rng.uniform(0.5, 1.5)
        d = size * rng.uniform(0.45, 0.8)
        x, z = rng.uniform(-0.45, 0.45) * size, rng.uniform(-0.45, 0.45) * size
        m = sub(T(x, h / 2 - 0.05, z), rot=(rng.uniform(-8, 8), rng.uniform(0, 90), rng.uniform(-8, 8)))
        mbox(p, "shell", m, (w, h, d), min(w, d) * 0.08, 1, taper=(rng.uniform(0.6, 0.9), rng.uniform(0.6, 0.9)))
        mbox(p, "trim", sub(m, 0, h / 2 - 0.02, 0), (w * 0.8, 0.05, d * 0.8), 0.02, 1)


def pine(p, seed, size=1.0):
    """Pinheiro facetado: tronco e três cones de seis faces (sem ar de balão)."""
    rng = random.Random(seed)
    mtube(p, "trim", T(0, 0.3 * size, 0), 0.08 * size, 0.6 * size, 6)
    for k, (y, r, h) in enumerate(((0.45, 0.55, 0.7), (0.85, 0.44, 0.6), (1.2, 0.3, 0.5))):
        lathe(p, "shell" if k % 2 == 0 else "label", sub(T(0, y * size, 0), rot=(0, rng.uniform(0, 60), 0)),
              [(0.0, 0.0), (r * size, 0.0), (0.0, h * size)], 6, cap_bottom=True)


def cactus(p, seed, size=1.0):
    rng = random.Random(seed)
    mtube(p, "shell", T(0, 0.6 * size, 0), 0.14 * size, 1.2 * size, 8, bevel=0.03)
    for side in (-1, 1):
        y = rng.uniform(0.45, 0.8) * size
        rod(p, "shell", (0, y, 0), (side * 0.32 * size, y, 0), 0.1 * size, 8)
        mtube(p, "shell", T(side * 0.32 * size, y + 0.22 * size, 0), 0.1 * size, 0.44 * size, 8, bevel=0.03)
    ball(p, "label", (0, 1.22 * size, 0), 0.08 * size, 8)


def solar(p):
    """Mesa de painéis solares: pés, viga e quatro painéis inclinados com as células escuras."""
    for x in (-1.2, 0, 1.2):
        rod(p, "dark", (x, 0, 0.3), (x, 0.7, 0.3), 0.04, 8)
        rod(p, "dark", (x, 0, -0.3), (x, 0.45, -0.3), 0.04, 8)
    frame_m = sub(T(0, 0.6, 0), rot=(-25, 0, 0))
    mbox(p, "metal", sub(frame_m, 0, -0.03, 0), (3.2, 0.04, 1.3), 0.01, 1)
    for i in range(4):
        cell = sub(frame_m, -1.2 + i * 0.8, 0.0, 0)
        mbox(p, "label", cell, (0.74, 0.03, 1.2), 0.01, 1)
        for k in range(1, 4):
            mbox(p, "metal", sub(cell, 0, 0.018, -0.6 + k * 0.3), (0.72, 0.005, 0.015), 0.0, 1)


def turbine(p):
    """Turbina eólica: mastro afunilado, gôndola, cubo e três pás paradas."""
    lathe(p, "shell", T(0, 0, 0), [(0.0, 0.0), (0.22, 0.0), (0.12, 4.6), (0.0, 4.6)], 12)
    mring(p, "hazard", T(0, 0.5, 0), 0.21, 0.03, 12, 4)
    mbox(p, "shell", T(0, 4.75, -0.1), (0.36, 0.34, 0.9), 0.08, 2)
    hub = T(0, 4.75, -0.6)
    lathe(p, "trim", sub(hub, rot=(-90, 0, 0)), [(0.0, 0.0), (0.16, 0.0), (0.0, 0.3)], 12, cap_bottom=True)
    for k in range(3):
        blade = sub(hub, 0, 0, 0, rot=(0, 0, k * 120 + 15))
        mbox(p, "shell", sub(blade, 0, 1.3, 0), (0.22, 2.4, 0.05), 0.02, 1, taper=(0.35, 1.0))


def radar(p):
    mbox(p, "dark", T(0, 0.3, 0), (0.9, 0.6, 0.9), 0.06, 2)
    mtube(p, "metal", T(0, 0.75, 0), 0.12, 0.4, 10)
    dish = sub(T(0, 1.2, 0), rot=(-50, 0, 0))
    lathe(p, "shell", dish, [(0.0, 0.0), (0.4, 0.05), (0.75, 0.2), (0.78, 0.24), (0.72, 0.24), (0.38, 0.1), (0.0, 0.05)], 20)
    rod(p, "metal", at(dish, 0, 0.05, 0), at(dish, 0, 0.6, 0), 0.02, 6)
    ball(p, "glow", at(dish, 0, 0.62, 0), 0.05, 8)
    mbox(p, "hazard", T(0, 0.3, -0.46), (0.5, 0.12, 0.02), 0.0, 1)


def rover(p):
    """Rover de seis rodas: chassis, cabine com vidro aceso, antena e caixa de carga."""
    mbox(p, "dark", T(0, 0.42, 0), (0.9, 0.16, 1.7), 0.04, 1)
    mbox(p, "shell", T(0, 0.64, -0.35), (0.84, 0.36, 0.8), 0.1, 2)
    mbox(p, "glow", T(0, 0.72, -0.76), (0.62, 0.16, 0.02), 0.02, 1)
    mbox(p, "trim", T(0, 0.6, 0.45), (0.8, 0.28, 0.7), 0.05, 2)
    rod(p, "metal", (0.3, 0.8, -0.1), (0.3, 1.4, -0.1), 0.015, 6)
    ball(p, "glow", (0.3, 1.42, -0.1), 0.04, 6)
    for side in (-1, 1):
        for z in (-0.6, 0.0, 0.6):
            w = axis_frame((side * 0.5, 0.24, z), "x")
            mring(p, "rubber", w, 0.18, 0.07, 14, 5)
            mtube(p, "metal", w, 0.12, 0.1, 10)


def pipes(p):
    """Tubagem: dois tubos paralelos em suportes, com flanges e uma válvula de volante."""
    for y in (0.35, 0.65):
        rod(p, "trim" if y < 0.5 else "shell", (-1.6, y, 0), (1.6, y, 0), 0.12, 12)
        for x in (-1.0, 0.0, 1.0):
            mring(p, "metal", axis_frame((x, y, 0), "x"), 0.14, 0.025, 12, 4)
    for x in (-1.3, 0.5):
        mbox(p, "dark", T(x, 0.3, 0), (0.12, 0.6, 0.4), 0.02, 1)
        mbox(p, "dark", T(x, 0.78, 0), (0.14, 0.06, 0.42), 0.02, 1)
    mtube(p, "dark", T(-0.4, 0.8, 0), 0.03, 0.3, 6)
    mring(p, "hazard", sub(T(-0.4, 0.97, 0), rot=(0, 0, 0)), 0.14, 0.025, 12, 4)


def silo(p):
    """Dois silos com cúpula, escada e passadiço."""
    for x, h, role in ((-0.7, 2.6, "shell"), (0.7, 2.0, "trim")):
        mtube(p, role, T(x, h / 2, 0), 0.6, h, 16, bevel=0.03)
        for y in (0.4, h - 0.4):
            mring(p, "dark", T(x, y, 0), 0.61, 0.03, 16, 4)
        dome(p, "metal", T(x, h, 0), 0.6, 0.25, 16, 4)
        for k in range(int(h / 0.3)):
            mbox(p, "dark", T(x, 0.2 + k * 0.3, -0.64), (0.2, 0.02, 0.04), 0.0, 1)
    mbox(p, "dark", T(0, 1.9, -0.3), (0.6, 0.06, 0.3), 0.01, 1)


def hangar(p):
    """Hangar: telhado em meia-lua com espessura e nervuras, paredes de topo, portão com
    faixas de perigo e luz. Frente em -Z."""
    lathe(p, "shell", sub(T(0, 0, 0), rot=(-90, 0, 0)), [(1.3, -1.2), (1.3, 1.2), (1.2, 1.2), (1.2, -1.2), (1.3, -1.2)], 20, arc=(0, 180))
    for z in (-1.14, 1.2):
        lathe(p, "trim", sub(T(0, 0, z), rot=(-90, 0, 0)), [(0.0, 0.0), (1.2, 0.0), (1.2, 0.06), (0.0, 0.06)], 20, arc=(0, 180))
    for z in (-1.2, -0.4, 0.4, 1.2):
        arc_tube(p, "dark", sub(T(0, 0, z), rot=(-90, 0, 0)), 1.32, 0.04, 0, 180, 20, 4)
    mbox(p, "label", T(0, 0.5, -1.22), (1.4, 1.0, 0.05), 0.02, 1)
    for k in range(5):
        mbox(p, "hazard" if k % 2 == 0 else "dark", T(-0.56 + k * 0.28, 0.08, -1.26), (0.26, 0.1, 0.02), 0.0, 1)
    mbox(p, "glow", T(0, 1.08, -1.27), (0.4, 0.06, 0.02), 0.01, 1)


def fence(p):
    for x in (-1.0, 0.0, 1.0):
        mtube(p, "dark", T(x, 0.35, 0), 0.04, 0.7, 6)
    for y in (0.3, 0.6):
        rod(p, "metal", (-1.0, y, 0), (1.0, y, 0), 0.02, 6)
    mbox(p, "hazard", T(0, 0.45, 0.02), (0.4, 0.12, 0.01), 0.0, 1)


def power(p):
    """Poste de alta tensão em treliça com braços e isoladores."""
    for sx in (-1, 1):
        for sz in (-1, 1):
            rod(p, "dark", (sx * 0.4, 0, sz * 0.4), (sx * 0.1, 3.4, sz * 0.1), 0.04, 6)
    for k in range(1, 6):
        y = k * 0.6
        w = 0.4 - y * 0.088
        for a, b in (((-w, -w), (w, w)), ((w, -w), (-w, w))):
            rod(p, "metal", (a[0], y - 0.3, a[1]), (b[0], y, b[1]), 0.015, 4)
    for y, arm in ((2.6, 1.0), (3.2, 0.7)):
        rod(p, "dark", (-arm, y, 0), (arm, y, 0), 0.04, 6)
        for x in (-arm, arm):
            for k in range(3):
                mtube(p, "label", T(x, y - 0.08 - k * 0.06, 0), 0.05, 0.03, 8)


# ======================================================================================
# Subaquático: corais, algas, submarino, bolhas, âncora e sonar
# ======================================================================================
def coral_tubes(p, seed):
    rng = random.Random(seed)
    for k in range(rng.randint(5, 8)):
        h = rng.uniform(0.3, 1.1)
        x, z = rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35)
        tilt = (rng.uniform(-12, 12), 0, rng.uniform(-12, 12))
        m = sub(T(x, 0, z), rot=tilt)
        r = rng.uniform(0.07, 0.12)
        lathe(p, "shell", m, [(0.0, 0.0), (r, 0.0), (r * 0.85, h), (r * 1.1, h + 0.03), (r * 0.7, h + 0.03), (r * 0.6, h - 0.08)], 8)
        mtube(p, "trim", sub(m, 0, h - 0.02, 0), r * 0.6, 0.02, 8)


def coral_fan(p, seed):
    """Leque de coral: tronco curto e cinco ramos que se abrem em leque, cada um com dois
    raminhos de pontas redondas (sem placa, que vista de cima parecia um papagaio de papel)."""
    rng = random.Random(seed)
    mtube(p, "trim", T(0, 0.1, 0), 0.05, 0.2, 6)
    base = Vector((0, 0.2, 0))
    for k in range(5):
        a = math.radians(-50 + k * 25 + rng.uniform(-6, 6))
        length = rng.uniform(0.45, 0.65)
        mid = base + Vector((math.sin(a) * length, math.cos(a) * length, rng.uniform(-0.04, 0.04)))
        rod(p, "shell", base, mid, 0.035, 6)
        ball(p, "shell", mid, 0.04, 6)
        for s in (-1, 1):
            b = a + math.radians(s * rng.uniform(14, 24))
            twig = rng.uniform(0.25, 0.4)
            tip = mid + Vector((math.sin(b) * twig, math.cos(b) * twig, rng.uniform(-0.05, 0.05)))
            rod(p, "shell", mid, tip, 0.025, 5)
            ball(p, "label", tip, 0.045, 6)


def kelp(p, seed):
    rng = random.Random(seed)
    for k in range(3):
        x, z = rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)
        y = 0.0
        sway = rng.uniform(0, math.tau)
        for s in range(6):
            h = 0.35
            ang = math.sin(sway + s * 0.9) * 18
            mbox(p, "shell" if s % 2 == 0 else "trim", sub(T(x + math.sin(sway + s) * 0.08, y + h / 2, z), rot=(0, rng.uniform(0, 180), ang)), (0.14, h, 0.03), 0.0, 1, taper=(0.8, 1.0))
            y += h * 0.95
        ball(p, "label", (x, y + 0.05, z), 0.06, 6)


def submarine(p):
    """Submarino atracado: casco em cápsula, torre, janelas acesas, lemes e hélice."""
    hull = sub(T(0, 0.75, 0), rot=(90, 0, 0))
    lathe(p, "shell", hull, [(0.0, -1.8), (0.4, -1.6), (0.62, -1.0), (0.66, 0.6), (0.5, 1.5), (0.2, 1.9), (0.0, 1.95)], 16)
    mring(p, "trim", sub(hull, 0, 0.2, 0), 0.665, 0.04, 16, 4)
    mbox(p, "trim", T(0, 1.55, -0.2), (0.34, 0.6, 0.9), 0.1, 2)
    mbox(p, "glow", T(0, 1.65, -0.66), (0.24, 0.12, 0.02), 0.02, 1)
    for z in (-0.9, -0.4, 0.1, 0.6):
        for side in (-1, 1):
            mtube(p, "glow", axis_frame((side * 0.64, 0.85, z), "x"), 0.08, 0.02, 10)
    for side in (-1, 1):
        mbox(p, "trim", T(side * 0.55, 0.75, 1.5), (0.5, 0.04, 0.3), 0.02, 1)
    mbox(p, "trim", T(0, 1.15, 1.6), (0.04, 0.5, 0.3), 0.02, 1)
    prop = T(0, 0.75, 1.98)
    for k in range(4):
        mbox(p, "metal", sub(prop, 0, 0, 0, rot=(0, 0, k * 90 + 20)), (0.07, 0.5, 0.03), 0.01, 1)
    for x in (-0.5, 0.5):
        mbox(p, "dark", T(x, 0.12, 0), (0.12, 0.24, 1.4), 0.02, 1)


def fish(p, at, scale=1.0):
    """Peixe estilizado, frente em -Z: corpo torneado e achatado dos lados, faixa, cauda em
    V, barbatana dorsal e olhos."""
    body = at @ Matrix.Diagonal((scale, scale, scale, 1.0)) @ sub(T(0, 0, 0), rot=(-90, 0, 0))
    lathe(p, "shell", body @ Matrix.Diagonal((0.55, 1.0, 1.0, 1.0)), [(0.0, -0.32), (0.06, -0.26), (0.13, -0.08), (0.14, 0.05), (0.1, 0.2), (0.04, 0.29), (0.0, 0.31)], 10)
    lathe(p, "label", body @ Matrix.Diagonal((0.55, 1.0, 1.0, 1.0)), [(0.139, -0.05), (0.146, -0.04), (0.146, 0.04), (0.139, 0.05)], 10)
    fin = at @ Matrix.Diagonal((scale, scale, scale, 1.0))
    for s in (-1, 1):
        mbox(p, "trim", sub(fin, 0, s * 0.06, 0.36, rot=(s * 35, 0, 0)), (0.02, 0.18, 0.1), 0.008, 1)
        ball(p, "dark", (fin @ Vector((s * 0.068, 0.035, -0.19, 1.0))).to_3d(), 0.024 * scale, 6)
    mbox(p, "trim", sub(fin, 0, 0.14, 0.03, rot=(-25, 0, 0)), (0.02, 0.12, 0.16), 0.008, 1, taper=(1.0, 0.3))


def school(p, seed):
    """Cardume de seis a oito peixes a nadar juntos para -Z."""
    rng = random.Random(seed)
    for k in range(rng.randint(6, 8)):
        pos = (rng.uniform(-0.9, 0.9), rng.uniform(-0.45, 0.45), rng.uniform(-0.8, 0.8))
        fish(p, sub(T(*pos), rot=(rng.uniform(-6, 6), rng.uniform(-12, 12), 0)), rng.uniform(0.8, 1.15))


def bubbles(p, seed):
    rng = random.Random(seed)
    y = 0.2
    for k in range(9):
        r = rng.uniform(0.04, 0.12)
        ball(p, "label", (rng.uniform(-0.2, 0.2), y, rng.uniform(-0.2, 0.2)), r, 8)
        y += rng.uniform(0.25, 0.45)


def anchor(p):
    """Âncora de pé, meio enterrada: haste, cruzeta, braços em U com unhas e argola com
    corrente caída para o lado."""
    mtube(p, "dark", T(0, 0.85, 0), 0.07, 1.5, 8)
    arc_tube(p, "dark", sub(T(0, 0.62, 0), rot=(90, 0, 0)), 0.5, 0.07, 0, 180, 16, 6)
    for side in (-1, 1):
        mbox(p, "dark", sub(T(side * 0.5, 0.72, 0), rot=(0, 0, -side * 20)), (0.2, 0.26, 0.08), 0.02, 1, taper=(0.2, 1.0))
    mbox(p, "dark", T(0, 1.42, 0), (0.62, 0.08, 0.1), 0.02, 1)
    mring(p, "metal", sub(T(0, 1.72, 0), rot=(90, 0, 0)), 0.12, 0.03, 12, 4)
    for k in range(6):
        mring(p, "metal", sub(T(0.18 + k * 0.16, 1.62 - k * 0.27, 0), rot=(90 if k % 2 == 0 else 0, 0, 30)), 0.09, 0.025, 10, 4)


def sonar(p):
    for a in (0, 120, 240):
        d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
        rod(p, "dark", d * 0.6, Vector((0, 1.0, 0)), 0.04, 6)
    mtube(p, "metal", T(0, 1.05, 0), 0.12, 0.2, 10)
    dish = sub(T(0, 1.3, 0), rot=(-60, 0, 0))
    lathe(p, "shell", dish, [(0.0, 0.0), (0.35, 0.05), (0.6, 0.18), (0.55, 0.2), (0.3, 0.08), (0.0, 0.05)], 16)
    ball(p, "glow", at(dish, 0, 0.3, 0), 0.07, 8)


# ======================================================================================
# Espaço: treliça, asas solares, módulo, vaivém, satélite e planeta
# ======================================================================================
def truss(p, length=4.0):
    """Viga de treliça de secção quadrada, com nós em metal (ao longo de X)."""
    h = 0.35
    for dy in (-h, h):
        for dz in (-h, h):
            rod(p, "dark", (-length / 2, dy, dz), (length / 2, dy, dz), 0.04, 6)
    n = int(length / 0.7)
    for k in range(n + 1):
        x = -length / 2 + k * length / n
        for (a, b) in (((-h, -h), (h, -h)), ((h, -h), (h, h)), ((h, h), (-h, h)), ((-h, h), (-h, -h))):
            rod(p, "metal", (x, a[0], a[1]), (x, b[0], b[1]), 0.025, 4)
        if k < n:
            x2 = x + length / n
            rod(p, "metal", (x, -h, -h), (x2, h, -h), 0.02, 4)
            rod(p, "metal", (x, -h, h), (x2, h, h), 0.02, 4)


def solar_wing(p):
    """Asa solar: longarina e uma grelha de painéis azuis com as juntas em metal."""
    rod(p, "dark", (0, 0, 0), (5.2, 0, 0), 0.06, 8)
    for k in range(6):
        x = 0.6 + k * 0.78
        mbox(p, "label", T(x, 0, 0), (0.72, 0.03, 1.8), 0.01, 1)
        for j in (-0.45, 0.0, 0.45):
            mbox(p, "metal", T(x, 0.018, j), (0.7, 0.006, 0.02), 0.0, 1)
    mtube(p, "metal", axis_frame((0, 0, 0), "x"), 0.12, 0.2, 10)


def module(p):
    """Módulo habitável: cilindro com cintas, janelas acesas e anéis de acoplagem."""
    body = axis_frame((0, 0.8, 0), "x")
    mtube(p, "shell", body, 0.7, 2.6, 16, bevel=0.05)
    for v in (-1.0, 0.0, 1.0):
        mring(p, "trim", sub(body, 0, v, 0), 0.71, 0.04, 16, 4)
    for v in (-0.5, 0.5):
        for a in (-40, 0, 40):
            q = at(body, 0.7 * math.sin(math.radians(a)), v, -0.7 * math.cos(math.radians(a)))
            mtube(p, "glow", frame(q, q - at(body, 0, v, 0)), 0.09, 0.02, 10)
    for v in (-1.35, 1.35):
        mtube(p, "metal", sub(body, 0, v, 0), 0.45, 0.14, 14)
        mtube(p, "dark", sub(body, 0, v * 1.03, 0), 0.35, 0.06, 14)
    for x in (-0.9, 0.9):
        mbox(p, "dark", T(x, 0.12, 0), (0.2, 0.24, 1.0), 0.02, 1)


def shuttle(p):
    """Vaivém pousado: fuselagem, cabine acesa, asas em delta, deriva e três motores."""
    body = sub(T(0, 0.7, 0), rot=(90, 0, 0))
    lathe(p, "shell", body, [(0.0, -1.6), (0.3, -1.4), (0.46, -0.8), (0.5, 0.9), (0.44, 1.3), (0.0, 1.35)], 14)
    mbox(p, "glow", T(0, 1.02, -1.0), (0.4, 0.14, 0.4), 0.06, 1)
    for side in (-1, 1):
        mbox(p, "trim", sub(T(side * 0.9, 0.55, 0.5), rot=(0, 0, -side * 6)), (1.2, 0.06, 1.2), 0.03, 1, taper=(0.3, 1.0))
    mbox(p, "trim", T(0, 1.4, 1.0), (0.06, 0.8, 0.6), 0.03, 1, taper=(1.0, 0.4))
    for x in (-0.22, 0.22, 0.0):
        y = 0.8 if x == 0 else 0.6
        lathe(p, "dark", sub(T(x, y, 1.35), rot=(90, 0, 0)), [(0.12, 0.0), (0.18, 0.25), (0.14, 0.26)], 10)
        mtube(p, "glow", sub(T(x, y, 1.61), rot=(90, 0, 0)), 0.12, 0.01, 10)
    for x in (-0.5, 0.5):
        rod(p, "dark", (x, 0.45, 0.2), (x * 1.2, 0.0, 0.2), 0.04, 6)
    rod(p, "dark", (0, 0.4, -1.0), (0, 0.0, -1.1), 0.04, 6)


def satellite(p):
    mbox(p, "trim", T(0, 1.4, 0), (0.6, 0.6, 0.6), 0.05, 2)
    for side in (-1, 1):
        rod(p, "metal", (side * 0.3, 1.4, 0), (side * 0.9, 1.4, 0), 0.03, 6)
        mbox(p, "label", T(side * 1.6, 1.4, 0), (1.3, 0.03, 0.6), 0.01, 1)
    dish = sub(T(0, 1.75, 0), rot=(-30, 0, 0))
    lathe(p, "shell", dish, [(0.0, 0.0), (0.3, 0.05), (0.45, 0.16), (0.4, 0.17), (0.25, 0.07), (0.0, 0.05)], 16)
    rod(p, "dark", (0, 0, 0), (0, 1.1, 0), 0.05, 8)
    mbox(p, "dark", T(0, 0.1, 0), (0.6, 0.2, 0.6), 0.03, 1)


def planet(p):
    """Planeta com anel, para o horizonte do mapa do espaço."""
    ball(p, "shell", (0, 0, 0), 1.0, 24)
    for lat, role in ((0.35, "trim"), (-0.25, "label")):
        mring(p, role, sub(T(0, lat, 0)), math.sqrt(1 - lat * lat) + 0.004, 0.05, 32, 4)
    arc_tube(p, "trim", sub(T(0, 0, 0), rot=(18, 0, 10)) @ Matrix.Diagonal((1.0, 0.04, 1.0, 1.0)), 1.6, 0.18, -180, 180, 48, 6)


# ======================================================================================
# Cidade: prédios com janelas acesas, ar condicionado, depósito de água, painel publicitário
# ======================================================================================
def tower(p, height, seed):
    """Prédio de 3 x 3 m: corpo, cantos escuros, faixas de janelas acesas em três faces,
    platibanda e equipamento no telhado."""
    rng = random.Random(seed)
    mbox(p, "shell", T(0, height / 2, 0), (3.0, height, 3.0), 0.04, 1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            mbox(p, "dark", T(sx * 1.49, height / 2, sz * 1.49), (0.12, height, 0.12), 0.0, 1)
    floors = int((height - 0.6) / 0.7)
    for k in range(floors):
        y = 0.6 + k * 0.7
        role = "glow" if rng.random() < 0.55 else "label"
        mbox(p, role, T(0, y, -1.51), (2.5, 0.3, 0.02), 0.0, 1)
        mbox(p, "label" if role == "glow" else "glow", T(1.51, y, 0), (0.02, 0.3, 2.5), 0.0, 1)
        mbox(p, role, T(-1.51, y, 0), (0.02, 0.3, 2.5), 0.0, 1)
    mbox(p, "trim", T(0, height + 0.1, 0), (3.1, 0.2, 3.1), 0.03, 1)
    mbox(p, "dark", T(0.6, height + 0.35, 0.5), (0.8, 0.5, 0.8), 0.05, 1)
    rod(p, "metal", (-0.9, height, -0.9), (-0.9, height + 1.2, -0.9), 0.03, 6)
    ball(p, "glow", (-0.9, height + 1.24, -0.9), 0.06, 6)


def ac_unit(p):
    mbox(p, "shell", T(0, 0.3, 0), (0.9, 0.6, 0.6), 0.04, 2)
    mtube(p, "dark", sub(T(0, 0.61, 0)), 0.22, 0.02, 14)
    for k in range(4):
        mbox(p, "metal", sub(T(0, 0.625, 0), rot=(0, k * 45, 0)), (0.4, 0.01, 0.04), 0.0, 1)
    vents(p, sub(T(0, 0.3, -0.305), rot=(0, 0, 0)), 4, 0.7, depth=0.01, spacing=0.1, height=0.03)


def water_tank(p):
    for sx in (-1, 1):
        for sz in (-1, 1):
            rod(p, "dark", (sx * 0.4, 0, sz * 0.4), (sx * 0.35, 1.0, sz * 0.35), 0.04, 6)
    mtube(p, "trim", T(0, 1.5, 0), 0.6, 1.0, 16, bevel=0.03)
    for y in (1.2, 1.8):
        mring(p, "dark", T(0, y, 0), 0.61, 0.025, 16, 4)
    lathe(p, "trim", T(0, 2.0, 0), [(0.62, 0.0), (0.0, 0.35)], 16)


def billboard(p):
    """Painel publicitário no telhado: dois pés, moldura escura e ecrã aceso a duas cores."""
    for x in (-1.1, 1.1):
        rod(p, "dark", (x, 0, 0), (x, 1.6, 0), 0.06, 8)
    mbox(p, "dark", T(0, 2.3, 0), (3.0, 1.5, 0.14), 0.04, 1)
    mbox(p, "glow", T(-0.7, 2.3, -0.08), (1.4, 1.3, 0.02), 0.02, 1)
    mbox(p, "label", T(0.7, 2.3, -0.08), (1.4, 1.3, 0.02), 0.02, 1)
    for k in range(5):
        mbox(p, "hazard", T(-1.2 + k * 0.6, 3.1, -0.04), (0.2, 0.08, 0.06), 0.02, 1)


def skybridge(p):
    """Ponte entre prédios (4 m ao longo de X): tabuleiro, guardas e faixa de luz."""
    mbox(p, "shell", T(0, 0, 0), (4.0, 0.3, 1.2), 0.03, 1)
    for z in (-0.55, 0.55):
        rod(p, "metal", (-2.0, 0.45, z), (2.0, 0.45, z), 0.03, 6)
        for x in (-1.5, -0.5, 0.5, 1.5):
            rod(p, "dark", (x, 0.15, z), (x, 0.45, z), 0.02, 4)
    mbox(p, "glow", T(0, -0.16, 0), (3.8, 0.03, 0.1), 0.0, 1)


# ======================================================================================
# Peças comuns: cúpula submarina, holofote e prédios da cidade vistos de cima
# ======================================================================================
def habitat(p):
    """Habitat submarino: sapata, cúpula achatada com cinta e janelas acesas, farol no topo e
    túnel de acesso com anéis (ao longo de +X)."""
    mtube(p, "dark", T(0, 0.15, 0), 1.25, 0.3, 24, bevel=0.03)
    dome(p, "shell", T(0, 0.3, 0), 1.15, 0.95, 24, 6)
    mring(p, "trim", T(0, 0.3, 0), 1.16, 0.07, 24, 5)
    for k in range(9):
        a = math.radians(-160 + k * 40)
        e = math.radians(28)
        pos = Vector((math.cos(a) * 1.15 * math.cos(e), 0.3 + 0.95 * math.sin(e), math.sin(a) * 1.15 * math.cos(e)))
        n = Vector((pos.x / 1.15 ** 2, (pos.y - 0.3) / 0.95 ** 2, pos.z / 1.15 ** 2)).normalized()
        mbox(p, "glow", frame(pos, n, front=(0, 1, 0)), (0.3, 0.05, 0.18), 0.03, 1)
    mtube(p, "metal", T(0, 1.3, 0), 0.12, 0.2, 10)
    ball(p, "glow", (0, 1.45, 0), 0.1, 10)
    mtube(p, "shell", axis_frame((1.75, 0.38, 0), "x"), 0.3, 1.3, 14)
    for x in (1.25, 1.75, 2.25):
        mring(p, "trim", axis_frame((x, 0.38, 0), "x"), 0.31, 0.045, 14, 4)
    mtube(p, "dark", axis_frame((2.42, 0.38, 0), "x"), 0.24, 0.06, 14)


def lamp(p):
    """Holofote num poste: base, poste, cabeça inclinada para a frente (-Z) e lente acesa."""
    mbox(p, "dark", T(0, 0.1, 0), (0.4, 0.2, 0.4), 0.03, 1)
    rod(p, "metal", (0, 0.2, 0), (0, 2.2, 0), 0.05, 8)
    head = frame((0, 2.3, -0.1), (0, 0.5, 1.0), front=(0, 1, 0))
    mbox(p, "shell", head, (0.5, 0.16, 0.3), 0.04, 1)
    mbox(p, "glow", sub(head, 0, -0.085, 0), (0.42, 0.02, 0.22), 0.01, 1)


def block(p, w, d, h, seed):
    """Prédio visto de cima, com a origem no telhado e o corpo a descer `h` m: pilares nos
    cantos, faixas de janelas (acesas ou escuras) nas faces que a câmara vê (+Z, +X e -X),
    platibanda e a laje do telhado num tom mais claro."""
    rng = random.Random(seed)
    mbox(p, "shell", T(0, -h / 2, 0), (w, h, d), 0.05, 1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            mbox(p, "trim", T(sx * (w / 2 - 0.1), -h / 2, sz * (d / 2 - 0.1)), (0.32, h, 0.32), 0.03, 1)
    # Windows on the upper floors only: lower down, the street haze and the other roofs hide
    # the facade, and the triangles are better spent elsewhere.
    for k in range(min(13, int((h - 0.6) / 1.1))):
        y = -0.9 - k * 1.1
        lit = rng.random() < 0.55
        mbox(p, "glow" if lit else "label", T(0, y, d / 2 + 0.01), (w - 0.8, 0.5, 0.04), 0.0, 1)
        side = rng.random() < 0.5
        mbox(p, "glow" if side else "label", T(w / 2 + 0.01, y, 0), (0.04, 0.5, d - 0.8), 0.0, 1)
        mbox(p, "label" if side else "glow", T(-w / 2 - 0.01, y, 0), (0.04, 0.5, d - 0.8), 0.0, 1)
    mbox(p, "rubber", T(0, 0.02, 0), (w - 0.5, 0.04, d - 0.5), 0.0, 1)
    for sx in (-1, 1):
        mbox(p, "trim", T(sx * (w / 2 - 0.08), 0.18, 0), (0.16, 0.36, d), 0.03, 1)
    for sz in (-1, 1):
        mbox(p, "trim", T(0, 0.18, sz * (d / 2 - 0.08)), (w - 0.3, 0.36, 0.16), 0.03, 1)


def define(part):
    for i in range(3):
        part("env_rock_%d" % i)(lambda p, s=i: rock(p, 11 + s * 7, 1.0 + s * 0.25))
        part("env_pine_%d" % i)(lambda p, s=i: pine(p, 3 + s, 1.3 + s * 0.35))
    part("env_cactus")(lambda p: cactus(p, 4, 1.2))
    part("env_solar")(solar)
    part("env_turbine")(turbine)
    part("env_radar")(radar)
    part("env_rover")(rover)
    part("env_pipes")(pipes)
    part("env_silo")(silo)
    part("env_hangar")(hangar)
    part("env_fence")(fence)
    part("env_power")(power)
    for i in range(2):
        part("env_coral_tubes_%d" % i)(lambda p, s=i: coral_tubes(p, 5 + s * 9))
        part("env_coral_fan_%d" % i)(lambda p, s=i: coral_fan(p, 2 + s * 5))
        part("env_kelp_%d" % i)(lambda p, s=i: kelp(p, 8 + s * 3))
        part("env_bubbles_%d" % i)(lambda p, s=i: bubbles(p, 1 + s * 4))
        part("env_school_%d" % i)(lambda p, s=i: school(p, 30 + s * 11))
    part("env_submarine")(submarine)
    part("env_anchor")(anchor)
    part("env_sonar")(sonar)
    part("env_truss")(truss)
    part("env_solar_wing")(solar_wing)
    part("env_module")(module)
    part("env_shuttle")(shuttle)
    part("env_satellite")(satellite)
    part("env_planet")(planet)
    for i, h in enumerate((3.0, 5.5, 8.0)):
        part("env_tower_%d" % i)(lambda p, hh=h, s=i: tower(p, hh, 20 + s))
    part("env_ac")(ac_unit)
    part("env_water_tank")(water_tank)
    part("env_billboard")(billboard)
    part("env_skybridge")(skybridge)
    part("env_habitat")(habitat)
    part("env_lamp")(lamp)
    for i, (w, d) in enumerate(((6.0, 6.0), (5.0, 8.0), (4.0, 4.5))):
        part("env_block_%d" % i)(lambda p, ww=w, dd=d, s=i: block(p, ww, dd, 26.0, 40 + s))
