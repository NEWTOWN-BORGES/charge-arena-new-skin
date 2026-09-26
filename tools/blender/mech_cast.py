"""O elenco v2 além do BIT: cada robô é uma máquina com a mesma engenharia (tools/blender/
mech_parts.py) e uma silhueta própria, com curvas: cúpulas, tambores, cápsulas e cones.

Coordenadas em unidades do Godot: Y para cima, frente em -Z, direita em +X.
"""
import math

import bmesh
from mathutils import Matrix, Vector

import mech_kit as mk
from mech_kit import (at, axis_frame, bearing, bolts, capsule, charging_port, connector, cyl_panel, dome,
                      foot, frame, hand, hinge, inspection_label, lathe, mbox, mring, mtube, piston, plane,
                      rod, screw, serial, servo, sphere_panel, sub, vents, warning, cable)
from mech_parts import (T, chassis, claw, core_round, leg, bird_leg, neck, pelvis, round_shin, round_thigh, shoulder,
                        upper_arm, waist, wrist)


def ball(p, role, center, radius, detail=12):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=detail, v_segments=max(4, detail // 2), radius=radius)
    p.add(role, bm, T(*center))


def on_barrel(center, radius, up_deg, x=0.0, lift=0.001):
    """Ponto e normal na superfície de um tambor deitado ao longo de X (0° = frente, 90° = cima)."""
    a = math.radians(up_deg)
    n = Vector((0.0, math.sin(a), -math.cos(a)))
    c = Vector(center)
    return Vector((x, c.y, c.z)) + n * (radius + lift), n


def cone_mark(origin, radius, radius_top, height, lon, y, lift=0.001):
    """Referencial de marcação assente num painel cónico de `cyl_panel` com eixo vertical e
    origem `origin` (centro em altura): `lon` em graus (0 = +X, -90 = frente), `y` relativo
    à origem. A normal inclina-se com o cone, para a marcação não se enterrar nem flutuar."""
    a = math.radians(lon)
    out = Vector((math.cos(a), 0.0, math.sin(a)))
    k = (y + height / 2) / height
    r = radius + (radius_top - radius) * k + lift
    normal = (out - Vector((0.0, (radius_top - radius) / height, 0.0))).normalized()
    right = Vector((math.sin(a), 0.0, -math.cos(a)))
    return plane(Vector(origin) + out * r + Vector((0.0, y, 0.0)), normal, right)


def dagged_panel(p, role, origin, radius, radius_top, height, lon, thickness=0.022, teeth=2, depth=0.06, steps=(8, 6)):
    """Placa de capa: troço de cone como `cyl_panel` (eixo vertical, origem no centro em altura,
    `lon` em graus) com a bainha recortada em `teeth` dentes de `depth` de fundo."""
    lo = (math.radians(lon[0]), math.radians(lon[1]))
    y0 = -height / 2

    def point(u, v, d):
        t = (u - lo[0]) / (lo[1] - lo[0])
        tooth = abs(((t * teeth) % 1.0) * 2.0 - 1.0) if t < 1.0 else 1.0
        hem = y0 + depth * (1.0 - tooth)
        y = hem + (height / 2 - hem) * v
        r = radius + (radius_top - radius) * (y - y0) / height - d
        return Vector((r * math.cos(u), y, r * math.sin(u)))
    mk._shell_panel(p, role, T(*origin), point, lo, (0.0, 1.0), thickness, (teeth * 4, steps[1]))


def screen_well(p, center, size, depth=0.05, recess=0.035, ring=True):
    """Ecrã do rosto recuado num poço escuro, com anel de retenção em metal à frente."""
    c = Vector(center)
    mbox(p, "dark", T(c.x, c.y, c.z + recess + depth / 2), (size[0] + 0.04, size[1] + 0.04, depth), 0.012, 1)
    if ring:
        for dy in (-1, 1):
            mbox(p, "metal", T(c.x, c.y + dy * (size[1] / 2 + 0.008), c.z + recess - 0.006), (size[0] + 0.03, 0.012, 0.012), 0.004, 1)
        for dx in (-1, 1):
            mbox(p, "metal", T(c.x + dx * (size[0] / 2 + 0.008), c.y, c.z + recess - 0.006), (0.012, size[1] + 0.03, 0.012), 0.004, 1)
    p.screen((c.x, c.y, c.z + recess - 0.002), size, bulge=0.01)


# ======================================================================================
# SALVO: artilheiro de oficina. Tanque: peito-tambor enorme, pernas curtas, cabeça-cápsula
# larga com pega, casulo de mísseis no ombro direito e canhão de cano duplo no antebraço.
# ======================================================================================
SALVO = {
    "hip": Vector((0.23, 0.58, 0.0)),
    "shoulder_y": 1.22,
    "elbow_l": Vector((-0.56, 0.95, 0.02)),
    "wrist_l": Vector((-0.6, 0.64, -0.12)),
    "elbow_r": Vector((0.56, 0.96, -0.02)),
    "muzzle": Vector((0.5, 0.78, -0.95)),
}
S_CHEST = Vector((0.0, 1.15, 0.02))
S_HEAD = Vector((0.0, 1.7, 0.0))
S_HEAD_R = 0.19
S_SCREEN = (0.4, 0.13)


def salvo_head(p):
    c = S_HEAD
    r = S_HEAD_R
    mk.HEADS["salvo2_head"] = {"top": round(c.y + r, 3), "center": round(c.y, 3), "aspect": round(S_SCREEN[0] / S_SCREEN[1], 3)}
    ax = axis_frame(c, "x")  # Y local = +X; X local = cima; Z local = frente
    # Estrutura: cápsula escura por dentro, fundo escuro.
    capsule(p, "dark", ax, r - 0.06, 0.64, 20)
    # Cascos curvos (0 = cima, 90 = frente, -90 = trás) com fendas entre eles.
    cyl_panel(p, "shell", ax, r, 0.46, (-62, 48), 0.03, (12, 2), gap=0.012)
    cyl_panel(p, "shell", ax, r, 0.46, (-178, -70), 0.03, (12, 2), gap=0.012)
    cyl_panel(p, "trim", ax, r + 0.004, 0.46, (54, 66), 0.03, (3, 2), gap=0.004)
    cyl_panel(p, "shell", ax, r, 0.46, (116, 170), 0.03, (6, 2), gap=0.012)
    for side in (-1, 1):
        cyl_panel(p, "shell", sub(ax, 0, side * (S_SCREEN[0] / 2 + 0.035), 0), r, 0.05, (60, 120), 0.03, (6, 1), gap=0.004)
    screen_well(p, (c.x, c.y - 0.005, c.z - r), S_SCREEN, 0.05, 0.035)
    # Protetores de ouvido em cúpula nas pontas, com anel de parafusos e grelha.
    for side in (-1, 1):
        cap = axis_frame((side * 0.25, c.y, c.z), "x" if side > 0 else "-x")
        mtube(p, "dark", cap, r * 0.86, 0.03, 22)
        dome(p, "trim", sub(cap, 0, 0.012, 0), r * 0.8, r * 0.42, 22, 6)
        bolts(p, sub(cap, 0, 0.016, 0), r * 0.84, 8, size=0.009, phase=0.2)
        for i in range(3):
            mbox(p, "dark", T(side * (0.262 + r * 0.4), c.y - 0.04 + i * 0.04, c.z), (0.01, 0.012, 0.09), 0.004, 1)
    # Pega de transporte no topo: dois postes e uma barra.
    for side in (-1, 1):
        mbox(p, "dark", T(side * 0.15, c.y + r + 0.03, c.z + 0.02), (0.04, 0.07, 0.05), 0.012)
        bolts(p, T(side * 0.15, c.y + r + 0.004, c.z + 0.02), 0.03, 4, size=0.007)
    rod(p, "metal", (-0.17, c.y + r + 0.07, c.z + 0.02), (0.17, c.y + r + 0.07, c.z + 0.02), 0.018, 12)
    mtube(p, "rubber", axis_frame((0, c.y + r + 0.07, c.z + 0.02), "x"), 0.024, 0.14, 12)
    # Sensores secundários: câmara pequena, infravermelho, LED de estado.
    cam = axis_frame((0.13, c.y + 0.12, c.z - r + 0.005), "-z")
    mtube(p, "dark", cam, 0.026, 0.03, 12)
    mtube(p, "screen", sub(cam, 0, 0.016, 0), 0.018, 0.004, 12)
    mtube(p, "glow", sub(cam, 0, 0.019, 0), 0.007, 0.003, 8)
    mbox(p, "glow", T(-0.14, c.y + 0.12, c.z - r + 0.012), (0.03, 0.012, 0.012), 0.004, 1)
    serial(p, plane((0.1, c.y - 0.03, c.z + r + 0.001), (0, 0, 1), (1, 0, 0)), "02", 0.04)
    inspection_label(p, plane((-0.12, c.y + 0.02, c.z + r + 0.002), (0, 0, 1), (1, 0, 0)), 0.08, 0.045)
    mbox(p, "team", T(0, c.y + r + 0.004, c.z - 0.06), (0.26, 0.01, 0.05), 0.004, 1)


def salvo_torso(p):
    c = S_CHEST
    R, L = 0.3, 0.62
    neck(p, c.y + R - 0.015, S_HEAD.y - S_HEAD_R + 0.01, 0.085, 0.02)
    ax = axis_frame(c, "x")
    # Chassis: tambor escuro com anéis de nervura e tampas de topo aparafusadas.
    mtube(p, "dark", ax, R - 0.03, L - 0.02, 28)
    for x in (-0.2, 0.0, 0.2):
        mring(p, "dark", sub(ax, 0, x, 0), R - 0.028, 0.012, 28, 4)
    for side in (-1, 1):
        end = sub(axis_frame(c, "x" if side > 0 else "-x"), 0, L / 2, 0)
        mtube(p, "dark", end, R - 0.01, 0.03, 28)
        mring(p, "trim", sub(end, 0, 0.012, 0), R - 0.02, 0.018, 28, 6)
        bolts(p, sub(end, 0, 0.018, 0), R - 0.07, 10, size=0.011)
    # Blindagem em painéis curvos: dorso, duas metades do peito à volta do núcleo, costas,
    # e uma placa de barriga; fendas escuras entre todos.
    cyl_panel(p, "shell", ax, R, L - 0.04, (-48, 42), 0.035, (14, 2), gap=0.014)
    for side in (-1, 1):
        cyl_panel(p, "shell", sub(ax, 0, side * 0.175, 0), R, 0.24, (48, 132), 0.035, (12, 2), gap=0.012)
    cyl_panel(p, "trim", ax, R + 0.002, 0.2, (138, 168), 0.035, (5, 2), gap=0.01)
    cyl_panel(p, "shell", ax, R, L - 0.04, (-140, -54), 0.035, (12, 2), gap=0.014)
    core_round(p, sub(axis_frame((0, c.y - 0.02, c.z - R), "-z"), 0, 0.0, 0), 0.052)
    pos, n = on_barrel(c, R, 22, 0.19)
    serial(p, plane(pos, n, (-1, 0, 0)), "02", 0.034)
    for side in (-1, 1):
        for deg in (-18, 26):
            pos, n = on_barrel(c, R, deg, side * 0.26, 0.0)
            screw(p, frame(pos, n), 0, 0)
    # Mochila de propulsores: caixa arredondada, dois bocais para baixo, e aviso.
    pack = T(0, c.y + 0.02, c.z + R + 0.06)
    mbox(p, "dark", pack, (0.4, 0.34, 0.12), 0.05)
    mbox(p, "trim", sub(pack, 0, 0.02, 0.05), (0.34, 0.26, 0.04), 0.03)
    for side in (-1, 1):
        noz = axis_frame((side * 0.11, c.y - 0.175, c.z + R + 0.07), "-y")
        lathe(p, "metal", noz, [(0.055, -0.03), (0.06, 0.0), (0.075, 0.07), (0.08, 0.09), (0.07, 0.092)], 18)
        mtube(p, "glow", sub(noz, 0, 0.08, 0), 0.05, 0.004, 16)
    warning(p, plane((-0.1, c.y + 0.08, c.z + R + 0.1305), (0, 0, 1), (1, 0, 0)), 0.055)
    charging_port(p, plane((0.1, c.y + 0.08, c.z + R + 0.1305), (0, 0, 1), (1, 0, 0)), 0.05, 0.03)
    waist(p, 0.69, c.y - R + 0.03, 0.15)
    pelvis(p, (0, 0.6, 0.0), (0.3, 0.18, 0.3), SALVO["hip"].x, SALVO["hip"].y, 0.095)


def salvo_shoulders(p):
    y = SALVO["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.35, y, 0.01, 0.11, 0.086, 0.09)
        if side < 0:
            # Ombreira esquerda: cúpula em dois gomos sobre o tambor, presa por um suporte.
            mbox(p, "dark", T(drum.x, y + 0.1, 0.01), (0.07, 0.06, 0.1), 0.012, 1)
            m = T(drum.x - 0.02, y + 0.03, 0.01)
            sphere_panel(p, "shell", m, 0.19, (18, 78), (100, 175), 0.035, (8, 6), gap=0.008)
            sphere_panel(p, "shell", m, 0.19, (18, 78), (185, 260), 0.035, (8, 6), gap=0.008)
            sphere_panel(p, "trim", m, 0.195, (4, 16), (100, 260), 0.03, (14, 2), gap=0.006)
            mbox(p, "team", T(drum.x - 0.07, y + 0.2, 0.01), (0.1, 0.01, 0.16), 0.004, 1)
        else:
            # Casulo de mísseis no ombro direito: calha, caixa arredondada, quatro tubos.
            mbox(p, "dark", T(drum.x, y + 0.11, 0.01), (0.08, 0.08, 0.14), 0.012)
            mbox(p, "metal", T(drum.x, y + 0.16, 0.01), (0.1, 0.02, 0.3), 0.006, 1)
            pod = T(drum.x + 0.03, y + 0.29, 0.01)
            mbox(p, "dark", pod, (0.26, 0.22, 0.36), 0.06)
            mbox(p, "shell", sub(pod, 0, 0.035, 0.01), (0.27, 0.16, 0.3), 0.06)
            mbox(p, "trim", sub(pod, 0.137, 0.0, 0.0), (0.012, 0.18, 0.28), 0.006, 1)
            for u in (-1, 1):
                for v in (-1, 1):
                    tube = axis_frame(at(pod, u * 0.06, v * 0.055, -0.17), "-z")
                    mtube(p, "dark", tube, 0.042, 0.04, 16)
                    mring(p, "trim", sub(tube, 0, 0.02, 0), 0.042, 0.008, 16, 4)
                    dome(p, "metal", sub(tube, 0, 0.006, 0), 0.03, 0.03, 12, 4)
            mbox(p, "team", sub(pod, 0, 0.11, 0.0), (0.1, 0.01, 0.22), 0.004, 1)
            warning(p, plane(at(pod, 0.137, 0.0, 0.1), (1, 0, 0), (0, 0, -1)), 0.05)
            for v in (-1, 1):
                screw(p, sub(pod, 0.137, v * 0.07, -0.1, rot=(0, 0, -90)), 0, 0)
        upper_arm(p, side, pin, SALVO["elbow_l"] if side < 0 else SALVO["elbow_r"], bone_r=0.045, elbow_w=0.085, elbow_r=0.052, armor_size=(0.15, 0.11))


def salvo_forearm_left(p):
    e, wr = SALVO["elbow_l"], SALVO["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.08, 0.07, 0.09), 0.012, 1)
    # Antebraço-barril: chassis torneado e três painéis curvos, com cintas laranja.
    lathe(p, "dark", sub(m, 0, 0.05, 0), [(0.08, 0.0), (0.12, 0.05), (0.125, length * 0.6), (0.095, length - 0.05)], 20, True, True)
    for lo in ((-60, 60), (70, 190), (200, 290)):
        cyl_panel(p, "shell", sub(m, 0, 0.05 + length * 0.4, 0), 0.14, length * 0.46, lo, 0.03, (8, 2), gap=0.012)
    for v in (0.07, length * 0.72):
        mring(p, "trim", sub(m, 0, v, 0), 0.135, 0.016, 22, 5)
    connector(p, sub(m, 0.142, length * 0.45, 0.0, rot=(0, 0, -90)), 0.016)
    mbox(p, "glow", sub(m, -0.05, length * 0.45, 0.14), (0.03, 0.03, 0.01), 0.004, 1)
    vents(p, sub(m, 0.0, length * 0.42, -0.144), 3, 0.08, depth=0.01, spacing=0.03)
    for v in (-1, 1):
        screw(p, sub(m, -0.1, length * 0.4 + v * 0.06, 0.1, rot=(-45, 0, 0)), 0, 0)
    plate = wrist(p, m, length)
    palm = sub(m, 0, length + 0.16, 0.0, rot=(0, -90, 180))
    hand(p, palm, fingers=4, scale=1.6, curl=1.15)
    cable(p, [at(m, 0.1, 0.02, -0.08), at(m, 0.15, length * 0.2, -0.1), at(m, 0.13, length * 0.4, -0.1)], 0.01)


def salvo_forearm_right(p):
    e, muzzle = SALVO["elbow_r"], SALVO["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.08, 0.08, 0.09), 0.012, 1)
    housing = sub(m, 0, 0.27, 0)
    mbox(p, "dark", housing, (0.26, 0.36, 0.2), 0.06)
    capsule(p, "shell", sub(housing, 0, -0.02, 0.05, rot=(0, 0, 0)), 0.11, 0.34, 18)
    for side in (-1, 1):
        mbox(p, "trim", sub(housing, side * 0.135, 0.03, -0.02), (0.03, 0.26, 0.12), 0.012)
    mbox(p, "team", sub(housing, 0, -0.02, 0.163), (0.05, 0.18, 0.01), 0.004, 1)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.13, 0.03, 22, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.11, 8, size=0.01)
    mbox(p, "glow", sub(housing, -0.07, -0.1, 0.16), (0.03, 0.03, 0.01), 0.004, 1)
    cable(p, [at(m, -0.12, 0.05, 0.08), at(m, -0.16, 0.18, 0.1), at(m, -0.14, 0.3, 0.08)], 0.01)


def salvo_gun(p):
    """Cano duplo: dois tubos lado a lado que recuam para dentro da caixa."""
    e, muzzle = SALVO["elbow_r"], SALVO["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.52, 0), 0.1, 0.1, 20)
    for u in (-1, 1):
        b = sub(m, u * 0.055, 0, 0)
        mtube(p, "dark", sub(b, 0, 0.7, 0), 0.05, 0.36, 16, bevel=0.006)
        mring(p, "glow", sub(b, 0, 0.62, 0), 0.052, 0.006, 16, 4)
        tip = sub(b, 0, length - 0.03, 0)
        mtube(p, "trim", tip, 0.062, 0.06, 16, bevel=0.01)
        mtube(p, "glow", sub(tip, 0, 0.026, 0), 0.034, 0.008, 12)
    mbox(p, "metal", sub(m, 0, 0.75, 0.0), (0.2, 0.04, 0.05), 0.012, 1)


def salvo_leg(p, out):
    def big_foot(q, m, o, ankle):
        foot(q, m, length=0.5, width=0.34, out=o, toes=3, armor="shell", heel="trim")
    leg(p, out, SALVO["hip"].y, knee_y=-0.21, ankle_up=0.16, width=1.3, knee_w=0.14, knee_r=0.072, foot_fn=big_foot,
        thigh_fn=round_thigh(k=1.3), shin_fn=round_shin(k=1.3, r_bottom=0.1, r_top=0.125), thigh_top=0.03, guard=False,
        shin_top=-0.16)


# ======================================================================================
# BIGORNA: pesada de estaleiro. Lutadora: capacete em cúpula baixo com visor e pirilampo,
# ombros em cúpulas gigantes, antebraços enormes (broca à direita), faixas de perigo,
# tanques às costas e lagartas de tanque nos pés.
# ======================================================================================
BIGORNA = {
    "hip": Vector((0.23, 0.6, 0.0)),
    "shoulder_y": 1.24,
    "elbow_l": Vector((-0.6, 0.94, 0.03)),
    "wrist_l": Vector((-0.65, 0.6, -0.12)),
    "elbow_r": Vector((0.6, 0.95, -0.02)),
    "muzzle": Vector((0.52, 0.74, -1.0)),
}
B_CHEST = Vector((0.0, 1.1, 0.02))
B_HEAD = Vector((0.0, 1.56, -0.03))
B_HEAD_R = 0.215
B_SCREEN = (0.34, 0.09)


def hazard_band(p, m, length, height, count=8, depth=0.006):
    """Faixa de perigo: blocos amarelos e escuros alternados ao longo do X local de `m`
    (Y local = normal)."""
    w = length / count
    for i in range(count):
        mbox(p, "hazard" if i % 2 == 0 else "dark", sub(m, -length / 2 + w * (i + 0.5), depth / 2, 0), (w, depth, height), 0.0, 1)


def bigorna_head(p):
    c = B_HEAD
    r = B_HEAD_R
    mk.HEADS["bigorna2_head"] = {"top": round(c.y + r * 0.9, 3), "center": round(c.y, 3), "aspect": round(B_SCREEN[0] / B_SCREEN[1], 3)}
    base = T(*c)
    # Estrutura: bloco arredondado escuro; capacete em quatro gomos de cúpula com juntas.
    mbox(p, "dark", sub(base, 0, -0.02, 0.02), (0.34, 0.26, 0.32), 0.1)
    for lo in ((-150, -95), (-85, -30), (-20, 60), (70, 150), (160, 210)):
        sphere_panel(p, "shell", sub(base, 0, 0.02, 0.02), r, (12, 82), lo, 0.035, (6, 5), gap=0.008)
    # Proteções laterais e da nuca, abertas à frente para o visor.
    for lo in ((-205, -122), (-58, 25), (35, 145)):
        sphere_panel(p, "shell", sub(base, 0, 0.02, 0.02), r, (-48, 8), lo, 0.035, (8, 5), gap=0.008)
    # Aba do capacete com faixa de perigo, por cima do visor.
    brim = sub(base, 0, 0.03, -r + 0.01)
    mbox(p, "trim", brim, (0.4, 0.04, 0.09), 0.02)
    hazard_band(p, plane(at(brim, 0, 0, -0.046), (0, 0, -1), (-1, 0, 0)), 0.36, 0.03, 8)
    # Visor: fenda recuada com o ecrã, queixo em placa e montantes.
    screen_well(p, (c.x, c.y - 0.05, c.z - r + 0.02), B_SCREEN, 0.05, 0.03)
    mbox(p, "trim", sub(base, 0, -0.13, -r + 0.05), (0.3, 0.07, 0.08), 0.025)
    for side in (-1, 1):
        mbox(p, "trim", sub(base, side * 0.2, -0.05, -r + 0.06), (0.05, 0.13, 0.08), 0.02)
        # Faróis laterais: lente com aro e luz.
        lamp = axis_frame(at(base, side * 0.2, -0.05, -r + 0.015), "-z")
        mtube(p, "metal", lamp, 0.026, 0.02, 14)
        mtube(p, "glow", sub(lamp, 0, 0.011, 0), 0.018, 0.004, 12)
    # Pirilampo de obra no topo: base, cúpula de luz e grade.
    top = c.y + 0.02 + r
    mtube(p, "dark", T(0, top, c.z + 0.02), 0.07, 0.04, 18, bevel=0.008)
    dome(p, "glow", T(0, top + 0.02, c.z + 0.02), 0.052, 0.07, 16, 5)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        rod(p, "metal", (math.cos(a) * 0.058, top + 0.02, c.z + 0.02 + math.sin(a) * 0.058),
            (math.cos(a) * 0.03, top + 0.1, c.z + 0.02 + math.sin(a) * 0.03), 0.006, 6)
    mring(p, "metal", T(0, top + 0.1, c.z + 0.02), 0.032, 0.007, 12, 4)
    # Sensores: câmara, infravermelho, grelha do microfone.
    cam = axis_frame((0.1, c.y + 0.12, c.z - r + 0.03), "-z")
    mtube(p, "dark", cam, 0.022, 0.03, 12)
    mtube(p, "glow", sub(cam, 0, 0.016, 0), 0.008, 0.004, 8)
    for i in range(3):
        mbox(p, "dark", T(-0.1 + i * 0.022, c.y + 0.1, c.z - r + 0.035), (0.01, 0.05, 0.01), 0.003, 1)
    serial(p, plane((0.0, c.y + 0.05, c.z + r + 0.024), (0, 0.2, 1), (1, 0, 0)), "03", 0.04)
    mbox(p, "team", T(0, top - 0.005, c.z - 0.1), (0.06, 0.012, 0.12), 0.004, 1)


def bigorna_torso(p):
    c = B_CHEST
    neck(p, 1.335, B_HEAD.y - 0.16, 0.09, 0.0, plate=(0.3, 0.26))
    chassis(p, c, (0.56, 0.48, 0.42), 3, 0.12)
    # Blindagem arredondada: peito em duas placas curvas, placa do núcleo, ilhargas, costas.
    # T: o X local é o X do mundo e o Z local é o Z do mundo, logo -90° é a frente.
    for side in (-1, 1):
        cyl_panel(p, "shell", T(side * 0.13, c.y + 0.03, c.z + 0.02), 0.26, 0.4,
                  (-138, -94) if side < 0 else (-86, -42), 0.045, (8, 2), gap=0.012)
    core = T(0, c.y - 0.05, c.z - 0.23)
    mbox(p, "trim", core, (0.2, 0.16, 0.06), 0.02)
    mbox(p, "dark", sub(core, 0, 0, -0.02), (0.15, 0.11, 0.04), 0.01, 1)
    for i in range(4):
        mbox(p, "glow", sub(core, -0.052 + i * 0.035, 0, -0.042), (0.024, 0.07, 0.008), 0.003, 1)
    for u in (-1, 1):
        for v in (-1, 1):
            screw(p, sub(core, u * 0.085, v * 0.062, -0.031, rot=(-90, 0, 0)), 0, 0)
    hazard_band(p, plane((0, c.y + 0.21, c.z - 0.235), (0, 0.25, -1), (-1, 0, 0)), 0.44, 0.04, 10)
    for side in (-1, 1):
        mbox(p, "shell", T(side * 0.3, c.y - 0.02, c.z), (0.05, 0.3, 0.3), 0.025)
    mbox(p, "shell", T(0, c.y, c.z + 0.235), (0.46, 0.38, 0.05), 0.03)
    serial(p, plane((0.15, c.y + 0.1, c.z - 0.262), (0, 0, -1), (-1, 0, 0)), "03", 0.034)
    # Tanques às costas: duas cápsulas num quadro, cintas, válvulas e aviso.
    for side in (-1, 1):
        tank = axis_frame((side * 0.11, c.y + 0.03, c.z + 0.34), "y")
        capsule(p, "trim", tank, 0.085, 0.42, 18)
        for v in (-0.1, 0.1):
            mring(p, "dark", sub(tank, 0, v, 0), 0.087, 0.012, 18, 4)
        mtube(p, "metal", sub(tank, 0, 0.23, 0), 0.02, 0.04, 10)
    mbox(p, "dark", T(0, c.y + 0.03, c.z + 0.27), (0.36, 0.34, 0.03), 0.01, 1)
    warning(p, plane((0, c.y - 0.12, c.z + 0.431), (0, 0, 1), (1, 0, 0)), 0.05)
    charging_port(p, plane((-0.3255, c.y - 0.05, c.z + 0.05), (-1, 0, 0), (0, 0, 1)), 0.05, 0.03)
    waist(p, 0.68, c.y - 0.22, 0.15)
    pelvis(p, (0, 0.61, 0.0), (0.3, 0.18, 0.3), BIGORNA["hip"].x, BIGORNA["hip"].y, 0.095)


def bigorna_shoulders(p):
    y = BIGORNA["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.32, y, 0.01, 0.12, 0.09, 0.09)
        # Cúpula gigante em três gomos, com aba de faixa de perigo e suporte interno.
        mbox(p, "dark", T(drum.x, y + 0.11, 0.01), (0.08, 0.07, 0.12), 0.012, 1)
        m = T(drum.x + side * 0.02, y + 0.02, 0.01)
        a0, a1 = (-60, 60) if side > 0 else (120, 240)
        span = (a1 - a0) / 3
        for i in range(3):
            sphere_panel(p, "shell", m, 0.25, (8, 80), (a0 - 50 + i * (span + 33), a0 - 50 + (i + 1) * (span + 33) - 2), 0.04, (6, 6), gap=0.008)
        sphere_panel(p, "trim", m, 0.255, (-6, 8), (a0 - 55, a1 + 55), 0.035, (14, 2), gap=0.006)
        top = at(m, 0, 0.25, 0)
        mbox(p, "team", T(top.x, top.y + 0.004, top.z), (0.12, 0.01, 0.12), 0.004, 1)
        upper_arm(p, side, pin, BIGORNA["elbow_l"] if side < 0 else BIGORNA["elbow_r"], bone_r=0.05, elbow_w=0.09, elbow_r=0.056, armor_size=(0.16, 0.11))


def bigorna_forearm_left(p):
    e, wr = BIGORNA["elbow_l"], BIGORNA["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.09, 0.07, 0.1), 0.012, 1)
    lathe(p, "dark", sub(m, 0, 0.05, 0), [(0.09, 0.0), (0.15, 0.06), (0.16, length * 0.55), (0.11, length - 0.05)], 20, True, True)
    for lo in ((-70, 50), (60, 180), (190, 280)):
        cyl_panel(p, "shell", sub(m, 0, 0.05 + length * 0.4, 0), 0.175, length * 0.5, lo, 0.035, (8, 2), gap=0.012, radius_top=0.165)
    hazard_band(p, plane(at(m, 0, 0.12, -0.177), at(m, 0, 0, -1) - at(m), at(m, 1, 0, 0) - at(m)), 0.2, 0.03, 6)
    mring(p, "trim", sub(m, 0, length * 0.78, 0), 0.17, 0.018, 22, 5)
    connector(p, sub(m, 0.176, length * 0.45, 0.0, rot=(0, 0, -90)), 0.016)
    mbox(p, "glow", sub(m, -0.05, length * 0.45, 0.176), (0.03, 0.03, 0.01), 0.004, 1)
    wrist(p, m, length, plate=(0.12, 0.11))
    palm = sub(m, 0, length + 0.17, 0.0, rot=(0, -90, 180))
    hand(p, palm, fingers=4, scale=1.75, curl=1.25)
    cable(p, [at(m, 0.12, 0.02, -0.09), at(m, 0.19, length * 0.2, -0.11), at(m, 0.17, length * 0.4, -0.11)], 0.011)


def bigorna_forearm_right(p):
    e, muzzle = BIGORNA["elbow_r"], BIGORNA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.09, 0.08, 0.1), 0.012, 1)
    # Caixa do motor da broca: tambor torneado, cintas, aletas de refrigeração.
    lathe(p, "shell", sub(m, 0, 0.08, 0), [(0.1, 0.0), (0.17, 0.05), (0.18, 0.3), (0.15, 0.38), (0.13, 0.4)], 22, True, True)
    for v in (0.13, 0.22, 0.31):
        mring(p, "dark", sub(m, 0, 0.08 + v, 0), 0.182, 0.01, 22, 4)
    hazard_band(p, plane(at(m, 0, 0.3, 0.182), at(m, 0, 0, 1) - at(m), at(m, 1, 0, 0) - at(m)), 0.2, 0.03, 6)
    mtube(p, "metal", sub(m, 0, 0.5, 0), 0.12, 0.04, 22, bevel=0.006)
    bolts(p, sub(m, 0, 0.522, 0), 0.1, 8, size=0.01)
    mbox(p, "glow", sub(m, -0.1, 0.2, 0.15), (0.03, 0.03, 0.012), 0.004, 1)
    cable(p, [at(m, -0.14, 0.05, 0.08), at(m, -0.19, 0.2, 0.1), at(m, -0.17, 0.34, 0.08)], 0.011)


def bigorna_gun(p):
    """A broca: bucha e broca cónica com anéis de corte; recua com o disparo."""
    e, muzzle = BIGORNA["elbow_r"], BIGORNA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.56, 0), 0.1, 0.08, 20)
    mtube(p, "trim", sub(m, 0, 0.62, 0), 0.085, 0.05, 20, bevel=0.008)
    prof = []
    n = 7
    base, tip = 0.66, length
    for i in range(n):
        y0 = base + (tip - base) * i / n
        r0 = 0.08 * (1 - i / n) + 0.012
        prof.append((r0, y0))
        prof.append((r0 * 0.78, y0 + (tip - base) / n * 0.55))
    prof.append((0.0, tip))
    lathe(p, "metal", m, [(0.0, base - 0.001)] + prof, 16)


def tread_foot(p, m, out, ankle, length=0.56, width=0.24, height=0.16, armor="shell"):
    """Lagarta: correia de borracha com garras, rodas de apoio, roda motriz e tensor, guarda-
    lamas com faixa de perigo, e o suporte que a liga ao tornozelo."""
    base = sub(m, 0, height / 2, -0.03)
    mbox(p, "rubber", base, (width, height, length), height * 0.48, 3)
    for i in range(9):
        z = -length / 2 + 0.07 + i * (length - 0.14) / 8
        mbox(p, "dark", sub(base, 0, height / 2 + 0.004, z), (width + 0.004, 0.012, 0.022), 0.003, 1)
        mbox(p, "dark", sub(base, 0, -height / 2 - 0.004, z), (width + 0.004, 0.012, 0.022), 0.003, 1)
    for side in (-1, 1):
        for i, z in enumerate((-length / 2 + height / 2, 0.0, length / 2 - height / 2)):
            wheel = axis_frame(at(base, side * (width / 2 + 0.006), 0, z), "x" if side > 0 else "-x")
            r = height * (0.42 if i != 1 else 0.36)
            mtube(p, "dark", wheel, r, 0.02, 16)
            mtube(p, "metal", sub(wheel, 0, 0.012, 0), r * 0.5, 0.01, 12)
            bolts(p, sub(wheel, 0, 0.016, 0), r * 0.32, 4, size=0.006)
    fender = sub(base, 0, height / 2 + 0.03, 0)
    mbox(p, armor, fender, (width + 0.04, 0.04, length * 0.8), 0.018)
    hazard_band(p, plane(at(fender, out * (width / 2 + 0.021), 0, 0), (out, 0, 0), (0, 0, -out)), length * 0.6, 0.026, 8)
    mbox(p, "dark", sub(fender, 0, 0.04, 0.03), (0.12, 0.05, 0.16), 0.012)


def bigorna_leg(p, out):
    def treads(q, m, o, ankle):
        tread_foot(q, m, o, ankle)
    leg(p, out, BIGORNA["hip"].y, knee_y=-0.2, ankle_up=0.25, width=1.3, knee_w=0.14, knee_r=0.072, foot_fn=treads,
        thigh_fn=round_thigh(k=1.3), shin_fn=round_shin(k=1.3, r_bottom=0.1, r_top=0.125), thigh_top=0.03, guard=False,
        shin_top=-0.15)


# ======================================================================================
# BATIDA: DJ do circuito. Artista ágil, toda em curvas: cabeça esférica com auscultadores
# gigantes, orelhas de gato e microfone de haste, tronco em ovo, colunas de som nos ombros,
# megafone no antebraço e um gira-discos às costas.
# ======================================================================================
BATIDA = {
    "hip": Vector((0.2, 0.66, 0.0)),
    "shoulder_y": 1.27,
    "elbow_l": Vector((-0.49, 0.99, 0.02)),
    "wrist_l": Vector((-0.52, 0.73, -0.1)),
    "elbow_r": Vector((0.49, 0.99, -0.02)),
    "muzzle": Vector((0.44, 0.8, -0.96)),
}
BA_CHEST = Vector((0.0, 1.12, 0.02))
BA_EGG = (0.26, 0.3, 0.235)
BA_HEAD = Vector((0.0, 1.73, 0.0))
BA_HEAD_R = 0.22
BA_SCREEN = (0.26, 0.14)


def scaled(center, sx, sy, sz):
    return T(*center) @ Matrix.Diagonal((sx, sy, sz, 1.0))


def arc_tube(p, role, m, major, minor, a0, a1, detail=24, sides=8):
    """Tubo em arco (troço de toro) à volta do Y local de `m`, de `a0` a `a1` graus."""
    prof = [(major + minor * math.cos(math.radians(360 * i / sides)), minor * math.sin(math.radians(360 * i / sides))) for i in range(sides + 1)]
    lathe(p, role, m, prof, detail, arc=(a0, a1))


def batida_head(p):
    c = BA_HEAD
    r = BA_HEAD_R
    mk.HEADS["batida2_head"] = {"top": round(c.y + r, 3), "center": round(c.y, 3), "aspect": round(BA_SCREEN[0] / BA_SCREEN[1], 3)}
    base = T(*c)
    ball(p, "dark", c, r - 0.05, 20)
    # Casco em gomos com uma janela redonda à frente para o ecrã.
    for lat, lo in (((28, 88), (-180, 180)), ((-30, 28), (-50, 20)), ((-30, 28), (30, 150)), ((-30, 28), (160, 230)),
                    ((-80, -32), (-180, 180))):
        sphere_panel(p, "shell", base, r, lat, lo, 0.032, (12, 6), gap=0.01)
    # Moldura redonda, anel de retenção e ecrã-equalizador recuado.
    face = axis_frame((c.x, c.y - 0.01, c.z - r + 0.035), "-z")
    mring(p, "trim", face, 0.165, 0.026, 32, 8)
    mring(p, "metal", sub(face, 0, -0.012, 0), 0.142, 0.008, 28, 5)
    mtube(p, "dark", sub(face, 0, -0.03, 0), 0.15, 0.04, 28)
    p.screen((c.x, c.y - 0.01, c.z - r + 0.025), BA_SCREEN, bulge=0.012)
    # Auscultadores gigantes: conchas torneadas, almofadas, tampa aparafusada, luz e arco.
    for side in (-1, 1):
        cup = axis_frame((side * (r + 0.02), c.y, c.z + 0.01), "x" if side > 0 else "-x")
        mring(p, "rubber", sub(cup, 0, 0.0, 0), 0.105, 0.03, 26, 8)
        lathe(p, "trim", sub(cup, 0, 0.02, 0), [(0.13, 0.0), (0.135, 0.03), (0.125, 0.07), (0.1, 0.09), (0.0, 0.092)], 26, True)
        mtube(p, "metal", sub(cup, 0, 0.1, 0), 0.07, 0.014, 22)
        bolts(p, sub(cup, 0, 0.106, 0), 0.055, 6, size=0.008)
        mring(p, "glow", sub(cup, 0, 0.075, 0), 0.118, 0.006, 26, 4)
        mbox(p, "dark", T(side * (r + 0.03), c.y + 0.13, c.z + 0.01), (0.04, 0.07, 0.05), 0.012)
    arc = axis_frame((0, c.y + 0.02, c.z + 0.01), "z")
    arc_tube(p, "shell", arc, r + 0.07, 0.028, 5, 175, 28, 8)
    mbox(p, "team", T(0, c.y + r + 0.097, c.z + 0.01), (0.12, 0.012, 0.05), 0.004, 1)
    # Orelhas de gato em pinos: casco rosa afunilado e face clara.
    for side in (-1, 1):
        hinge_at = Vector((side * 0.12, c.y + r * 0.84, c.z - 0.09))
        mtube(p, "metal", axis_frame(hinge_at, "z"), 0.012, 0.08, 8)
        ear = sub(T(*hinge_at), 0, 0.09, 0, rot=(0, 0, -side * 18))
        mbox(p, "shell", ear, (0.13, 0.16, 0.05), 0.02, 2, taper=(0.15, 0.5))
        mbox(p, "trim", sub(ear, 0, -0.01, -0.024), (0.08, 0.1, 0.01), 0.01, 1, taper=(0.15, 0.5))
    # Microfone de haste a partir do auscultador esquerdo; LED no direito.
    rod(p, "metal", (-(r + 0.08), c.y - 0.05, c.z - 0.02), (-0.14, c.y - 0.15, c.z - r - 0.02), 0.009, 8)
    ball(p, "rubber", (-0.13, c.y - 0.155, c.z - r - 0.035), 0.028, 12)
    mbox(p, "glow", T(r + 0.13, c.y - 0.06, c.z + 0.05), (0.012, 0.03, 0.03), 0.004, 1)
    serial(p, plane((0.0, c.y - 0.06, c.z + r + 0.001), (0, 0, 1), (1, 0, 0)), "04", 0.036)


def egg_point(center, radii, x, y_off, front=True, lift=0.001):
    """Ponto e normal na superfície do tronco em ovo (elipsoide), à frente ou atrás."""
    ex, ey, ez = radii
    k = max(0.0, 1.0 - (x / ex) ** 2 - (y_off / ey) ** 2)
    z = (-1 if front else 1) * ez * math.sqrt(k)
    n = Vector((x / ex ** 2, y_off / ey ** 2, z / ez ** 2)).normalized()
    return Vector((x, center.y + y_off, center.z + z)) + n * lift, n


def egg_side(center, radii, side, y_off, z_off, lift=0.001):
    """Ponto e normal no flanco do ovo."""
    ex, ey, ez = radii
    k = max(0.0, 1.0 - (y_off / ey) ** 2 - (z_off / ez) ** 2)
    x = side * ex * math.sqrt(k)
    n = Vector((x / ex ** 2, y_off / ey ** 2, z_off / ez ** 2)).normalized()
    return Vector((x, center.y + y_off, center.z + z_off)) + n * lift, n


def batida_torso(p):
    c = BA_CHEST
    ex, ey, ez = BA_EGG
    neck(p, c.y + ey - 0.03, BA_HEAD.y - BA_HEAD_R + 0.02, 0.07, 0.02, plate=(0.22, 0.2))
    inner = scaled(c, ex - 0.04, ey - 0.04, ez - 0.04)
    lathe(p, "dark", inner, [(0.0, -1.0)] + [(math.sin(math.radians(a)), -math.cos(math.radians(a))) for a in range(15, 180, 15)] + [(0.0, 1.0)], 22)
    egg = scaled(c, ex, ey, ez)
    # Gomos do ovo: frente em duas metades (núcleo entre elas), ilhargas, costas, faixa.
    for lat, lo in (((-20, 60), (-150, -97)), ((-20, 60), (-83, -30)), ((-20, 60), (-20, 50)), ((-20, 60), (130, 200)),
                    ((-20, 60), (60, 120)), ((62, 84), (-180, 180))):
        sphere_panel(p, "shell", egg, 1.0, lat, lo, 0.13, (8, 6), gap=0.04)
    sphere_panel(p, "trim", egg, 1.02, (-42, -24), (-180, 180), 0.12, (24, 2), gap=0.02)
    core_round(p, axis_frame((0, c.y + 0.06, c.z - ez + 0.01), "-z"), 0.05)
    for dx in (-0.02, 0.0, 0.02):
        pos, n = egg_point(c, BA_EGG, dx, -0.1, True, 0.0)
        mbox(p, "dark", frame(pos, n), (0.01, 0.006, 0.07), 0.003, 1)
    pos, n = egg_point(c, BA_EGG, 0.14, 0.12)
    serial(p, plane(pos, n, (-1, 0, 0)), "04", 0.03)
    # Gira-discos às costas: caixa redonda, prato, disco, braço e aviso.
    deck = axis_frame((0, c.y + 0.02, c.z + ez + 0.04), "z")
    lathe(p, "trim", deck, [(0.0, -0.04), (0.19, -0.04), (0.2, 0.0), (0.19, 0.03), (0.0, 0.03)], 28)
    mtube(p, "dark", sub(deck, 0, 0.04, 0), 0.16, 0.02, 28)
    mring(p, "shell", sub(deck, 0, 0.052, 0), 0.07, 0.01, 22, 4)
    mtube(p, "metal", sub(deck, 0, 0.055, 0), 0.02, 0.01, 12)
    rod(p, "metal", at(deck, 0.14, 0.06, 0.1), at(deck, 0.06, 0.06, 0.02), 0.007, 6)
    warning(p, plane(at(deck, -0.12, 0.031, 0.1), at(deck, 0, 1, 0) - at(deck), (1, 0, 0)), 0.04)
    pos, n = egg_side(c, BA_EGG, -1, -0.1, 0.03)
    charging_port(p, plane(pos, n, (0, 0, 1)), 0.045, 0.028)
    waist(p, 0.76, c.y - ey + 0.04, 0.12)
    pelvis(p, (0, 0.68, 0.0), (0.26, 0.16, 0.26), BATIDA["hip"].x, BATIDA["hip"].y, 0.085)


def batida_shoulders(p):
    y = BATIDA["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.25, y, 0.01, 0.1, 0.08, 0.08)
        # Coluna de som montada no tambor: caixa torneada, cone, suspensão e tampa.
        axis = Vector((side * 0.75, 0.35, -0.55)).normalized()
        spk = frame(Vector((drum.x + side * 0.05, y + 0.12, 0.0)), axis, front=(0, 1, 0))
        mbox(p, "dark", T(drum.x, y + 0.08, 0.0), (0.06, 0.08, 0.08), 0.012, 1)
        lathe(p, "shell", sub(spk, 0, -0.07, 0), [(0.0, 0.0), (0.12, 0.0), (0.16, 0.05), (0.165, 0.1), (0.15, 0.11)], 28, True)
        mring(p, "rubber", sub(spk, 0, 0.035, 0), 0.13, 0.016, 28, 6)
        lathe(p, "dark", sub(spk, 0, -0.025, 0), [(0.12, 0.06), (0.06, 0.02), (0.03, 0.0), (0.0, 0.0)], 24)
        dome(p, "metal", sub(spk, 0, -0.022, 0), 0.035, 0.02, 16, 4)
        mring(p, "glow", sub(spk, 0, 0.038, 0), 0.155, 0.006, 28, 4)
        bolts(p, sub(spk, 0, 0.042, 0), 0.145, 8, size=0.008)
        upper_arm(p, side, pin, BATIDA["elbow_l"] if side < 0 else BATIDA["elbow_r"], bone_r=0.035, elbow_w=0.07, elbow_r=0.045, armor_size=(0.11, 0.1))


def batida_forearm_left(p):
    e, wr = BATIDA["elbow_l"], BATIDA["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    capsule(p, "dark", sub(m, 0, length * 0.55, 0), 0.08, length * 0.8, 18)
    for lo in ((-80, 80), (100, 260)):
        cyl_panel(p, "shell", sub(m, 0, length * 0.55, 0), 0.105, length * 0.56, lo, 0.03, (10, 2), gap=0.012, radius_top=0.095)
    mring(p, "trim", sub(m, 0, length * 0.82, 0), 0.1, 0.014, 20, 5)
    mbox(p, "glow", sub(m, 0, length * 0.5, 0.107), (0.05, 0.012, 0.01), 0.003, 1)
    connector(p, sub(m, 0.107, length * 0.45, 0.0, rot=(0, 0, -90)), 0.014)
    wrist(p, m, length)
    palm = sub(m, 0, length + 0.15, 0.0, rot=(0, -90, 180))
    hand(p, palm, fingers=4, scale=1.35, curl=0.9)


def batida_forearm_right(p):
    e, muzzle = BATIDA["elbow_r"], BATIDA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    capsule(p, "shell", sub(m, 0, 0.26, 0), 0.11, 0.38, 20)
    mring(p, "trim", sub(m, 0, 0.14, 0), 0.112, 0.014, 22, 5)
    mring(p, "trim", sub(m, 0, 0.36, 0), 0.112, 0.014, 22, 5)
    for i in range(4):
        mbox(p, "glow", sub(m, -0.04 + i * 0.027, 0.26, 0.108), (0.014, 0.06 + (i % 2) * 0.03, 0.01), 0.003, 1)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.1, 0.03, 22, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.084, 6, size=0.009)


def batida_gun(p):
    """Megafone de choque: tubo, garganta e campânula torneada; recua com o disparo."""
    e, muzzle = BATIDA["elbow_r"], BATIDA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.53, 0), 0.07, 0.1, 18)
    lathe(p, "shell", m, [(0.06, 0.56), (0.065, 0.62), (0.09, 0.72), (0.15, 0.82), (0.2, length - 0.02), (0.205, length)], 26)
    mring(p, "trim", sub(m, 0, length - 0.005, 0), 0.2, 0.016, 28, 6)
    lathe(p, "dark", m, [(0.18, length - 0.03), (0.08, length - 0.1), (0.0, length - 0.13)], 22)
    mring(p, "glow", sub(m, 0, length - 0.06, 0), 0.12, 0.008, 24, 4)


def batida_leg(p, out):
    def sneaker(q, m, o, ankle):
        foot(q, m, length=0.42, width=0.27, out=o, toes=2, armor="shell", heel="trim")
    leg(p, out, BATIDA["hip"].y, knee_y=-0.25, ankle_up=0.17, width=0.95, knee_w=0.11, knee_r=0.06, foot_fn=sneaker,
        thigh_fn=round_thigh(k=0.95), shin_fn=round_shin(k=0.95, r_bottom=0.09, r_top=0.115), thigh_top=0.03, guard=False,
        shin_top=-0.2)


# ======================================================================================
# ROSCA: mecânica de bancada. Especialista assimétrica: cabeça em tambor com óculos de
# soldador na testa e lupa num braço articulado, garra à esquerda, rebitadora à direita,
# caixa de ferramentas às costas e rodas nos pés.
# ======================================================================================
ROSCA = {
    "hip": Vector((0.21, 0.66, 0.0)),
    "shoulder_y": 1.26,
    "elbow_l": Vector((-0.5, 0.98, 0.02)),
    "wrist_l": Vector((-0.53, 0.71, -0.1)),
    "elbow_r": Vector((0.5, 0.98, -0.02)),
    "muzzle": Vector((0.45, 0.78, -0.93)),
}
R_CHEST = Vector((0.0, 1.13, 0.02))
R_HEAD = Vector((0.0, 1.66, 0.0))
R_HEAD_R = 0.19
R_SCREEN = (0.22, 0.12)


def rosca_head(p):
    c = R_HEAD
    r = R_HEAD_R
    h = 0.3
    mk.HEADS["rosca2_head"] = {"top": round(c.y + h / 2 + 0.07, 3), "center": round(c.y, 3), "aspect": round(R_SCREEN[0] / R_SCREEN[1], 3)}
    base = T(*c)
    mtube(p, "dark", base, r - 0.04, h, 24)
    for lo in ((-205, -128), (-52, 25), (35, 145)):
        cyl_panel(p, "shell", base, r, h - 0.02, lo, 0.03, (10, 2), gap=0.01)
    cyl_panel(p, "trim", sub(base, 0, -h / 2 + 0.03, 0), r + 0.004, 0.05, (-128, -52), 0.03, (8, 1), gap=0.004)
    dome(p, "shell", sub(base, 0, h / 2, 0), r, 0.07, 26, 6)
    mtube(p, "dark", sub(base, 0, h / 2 + 0.07, 0), 0.05, 0.02, 14)
    screen_well(p, (c.x, c.y - 0.03, c.z - r + 0.01), R_SCREEN, 0.05, 0.03)
    # Óculos de soldador levantados na testa: correia de borracha, duas lentes com aro.
    mring(p, "rubber", sub(base, 0, 0.1, 0), r + 0.006, 0.014, 28, 5)
    for side in (-1, 1):
        g = axis_frame((side * 0.075, c.y + 0.1, c.z - r - 0.01), "-z")
        mtube(p, "trim", g, 0.058, 0.04, 20, bevel=0.006)
        mtube(p, "screen", sub(g, 0, 0.021, 0), 0.044, 0.004, 18)
        mring(p, "metal", sub(g, 0, 0.022, 0), 0.05, 0.007, 18, 4)
    rod(p, "rubber", (-0.02, c.y + 0.1, c.z - r - 0.02), (0.02, c.y + 0.1, c.z - r - 0.02), 0.012, 8)
    # Lupa num braço articulado: dobradiça no lado direito, braço, aro com a lente.
    hinge_at = Vector((r + 0.01, c.y + 0.01, c.z - 0.06))
    mtube(p, "metal", axis_frame(hinge_at, "x"), 0.028, 0.03, 14)
    bolts(p, sub(axis_frame(hinge_at, "x"), 0, 0.016, 0), 0.018, 4, size=0.005)
    lens_at = Vector((0.06, c.y - 0.035, c.z - r - 0.07))
    rod(p, "metal", hinge_at + Vector((0.015, 0, 0)), Vector((r - 0.02, c.y - 0.01, c.z - r - 0.06)), 0.01, 8)
    rod(p, "metal", Vector((r - 0.02, c.y - 0.01, c.z - r - 0.06)), lens_at + Vector((0.07, 0.0, 0.0)), 0.01, 8)
    loupe = axis_frame(lens_at, "-z")
    mring(p, "trim", loupe, 0.07, 0.014, 26, 6)
    mring(p, "metal", sub(loupe, 0, 0.004, 0), 0.058, 0.005, 24, 4)
    # Outros sensores: LED e grelha de microfone do lado esquerdo.
    mbox(p, "glow", T(-r - 0.002, c.y + 0.02, c.z - 0.05), (0.012, 0.03, 0.03), 0.004, 1)
    for i in range(3):
        mbox(p, "dark", T(-r - 0.002, c.y - 0.05 + i * 0.02, c.z + 0.04), (0.01, 0.01, 0.06), 0.003, 1)
    serial(p, plane((0.0, c.y - 0.04, c.z + r + 0.001), (0, 0, 1), (1, 0, 0)), "05", 0.036)
    mbox(p, "team", T(0, c.y + h / 2 + 0.058, c.z), (0.1, 0.012, 0.1), 0.004, 1)


def rosca_torso(p):
    c = R_CHEST
    R, H = 0.26, 0.48
    neck(p, c.y + H / 2 - 0.01, R_HEAD.y - 0.15 + 0.01, 0.075, 0.02, plate=(0.24, 0.22))
    base = T(c.x, c.y, c.z)
    mtube(p, "dark", base, R - 0.035, H, 26)
    for y in (-0.12, 0.0, 0.12):
        mring(p, "dark", sub(base, 0, y, 0), R - 0.03, 0.012, 26, 4)
    for lo in ((-155, -98), (-82, -25), (-15, 40), (50, 130), (140, 195)):
        cyl_panel(p, "shell", sub(base, 0, 0.03, 0), R, H - 0.1, lo, 0.035, (8, 2), gap=0.012)
    dome(p, "shell", sub(base, 0, H / 2 - 0.02, 0), R, 0.06, 26, 5)
    # Cinto de ferramentas em baixo, com argolas de metal.
    cyl_panel(p, "trim", sub(base, 0, -H / 2 + 0.035, 0), R + 0.006, 0.06, (-180, 180), 0.03, (26, 1), gap=0.0)
    for deg in (-140, -40, 20, 160):
        a = math.radians(deg)
        mring(p, "metal", frame((math.cos(a) * (R + 0.04), c.y - H / 2 + 0.02, c.z + math.sin(a) * (R + 0.04)), (-math.sin(a), 0, math.cos(a))), 0.022, 0.005, 12, 4)
    # Núcleo: módulo de bateria retangular com moldura, na fenda da frente.
    core = T(0, c.y + 0.04, c.z - R + 0.01)
    mbox(p, "trim", core, (0.12, 0.16, 0.05), 0.016)
    mbox(p, "dark", sub(core, 0, 0, -0.02), (0.09, 0.12, 0.03), 0.008, 1)
    for i in range(3):
        mbox(p, "glow", sub(core, 0, -0.04 + i * 0.04, -0.036), (0.06, 0.022, 0.008), 0.003, 1)
    serial(p, plane((0.14, c.y + 0.14, c.z - R * 0.86 - 0.004), (0.5, 0, -0.87), (-0.87, 0, -0.5)), "05", 0.03)
    # Caixa de ferramentas às costas: gavetas, fechos, pega, aviso e porta de carga.
    box = T(0, c.y + 0.02, c.z + R + 0.1)
    mbox(p, "dark", sub(box, 0, 0, -0.06), (0.3, 0.3, 0.04), 0.01, 1)
    mbox(p, "trim", box, (0.38, 0.34, 0.16), 0.03)
    for v in (-0.06, 0.05):
        mbox(p, "dark", sub(box, 0, v, 0.081), (0.34, 0.008, 0.004), 0.0, 1)
        mbox(p, "metal", sub(box, 0, v - 0.04, 0.084), (0.07, 0.014, 0.01), 0.004, 1)
    for u in (-1, 1):
        mbox(p, "metal", sub(box, u * 0.19, 0.08, 0.0), (0.012, 0.05, 0.04), 0.004, 1)
        mbox(p, "dark", sub(box, u * 0.1, 0.19, 0), (0.025, 0.05, 0.025), 0.006, 1)
    mbox(p, "metal", sub(box, 0, 0.22, 0), (0.24, 0.024, 0.03), 0.01, 1)
    warning(p, plane(at(box, 0.12, 0.12, 0.081), (0, 0, 1), (1, 0, 0)), 0.045)
    charging_port(p, plane((-(R + 0.001), c.y - 0.08, c.z + 0.05), (-1, 0, 0), (0, 0, 1)), 0.045, 0.028)
    waist(p, 0.76, c.y - H / 2 + 0.02, 0.13)
    pelvis(p, (0, 0.68, 0.0), (0.27, 0.17, 0.27), ROSCA["hip"].x, ROSCA["hip"].y, 0.088)


def rosca_shoulders(p):
    y = ROSCA["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.28, y, 0.01, 0.1, 0.08, 0.08)
        mbox(p, "dark", T(drum.x, y + 0.1, 0.01), (0.06, 0.06, 0.09), 0.012, 1)
        m = T(drum.x + side * 0.01, y + 0.03, 0.01)
        a0, a1 = (-80, 80) if side > 0 else (100, 260)
        sphere_panel(p, "shell", m, 0.17, (20, 82), (a0 - 30, a1 + 30), 0.03, (10, 5), gap=0.008)
        sphere_panel(p, "trim", m, 0.175, (6, 18), (a0 - 25, a1 + 25), 0.028, (12, 2), gap=0.006)
        mbox(p, "team", T(drum.x + side * 0.02, y + 0.2, 0.01), (0.08, 0.01, 0.12), 0.004, 1)
        upper_arm(p, side, pin, ROSCA["elbow_l"] if side < 0 else ROSCA["elbow_r"], bone_r=0.038, elbow_w=0.075, elbow_r=0.048, armor_size=(0.12, 0.1))


def rosca_forearm_left(p):
    e, wr = ROSCA["elbow_l"], ROSCA["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    lathe(p, "dark", sub(m, 0, 0.05, 0), [(0.07, 0.0), (0.105, 0.04), (0.11, length * 0.6), (0.085, length - 0.05)], 18, True, True)
    for lo in ((-70, 70), (90, 250)):
        cyl_panel(p, "shell", sub(m, 0, 0.05 + length * 0.42, 0), 0.125, length * 0.5, lo, 0.03, (8, 2), gap=0.012, radius_top=0.118)
    mring(p, "trim", sub(m, 0, length * 0.8, 0), 0.115, 0.014, 20, 5)
    connector(p, sub(m, 0.126, length * 0.45, 0.0, rot=(0, 0, -90)), 0.014)
    mbox(p, "glow", sub(m, 0, length * 0.5, 0.126), (0.04, 0.012, 0.01), 0.003, 1)
    wrist(p, m, length)
    palm = sub(m, 0, length + 0.13, 0.0, rot=(0, -90, 180))
    claw(p, palm, scale=1.45, curl=1.1)


def rosca_forearm_right(p):
    e, muzzle = ROSCA["elbow_r"], ROSCA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    housing = sub(m, 0, 0.26, 0)
    mbox(p, "dark", housing, (0.2, 0.34, 0.2), 0.05)
    cyl_panel(p, "shell", housing, 0.12, 0.3, (-20, 200), 0.03, (12, 2), gap=0.01)
    mbox(p, "trim", sub(housing, 0, 0.15, 0), (0.24, 0.04, 0.24), 0.02)
    # Carregador de rebites: tambor ao lado com a janela dos rebites.
    mag = axis_frame(at(housing, -0.14, 0.02, 0.0), at(housing, 0, 1, 0) - at(housing))
    mtube(p, "trim", mag, 0.05, 0.2, 16, bevel=0.008)
    for v in (-0.06, 0.0, 0.06):
        mtube(p, "metal", sub(mag, 0.0, v, -0.05), 0.012, 0.012, 8)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.09, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.075, 6, size=0.009)


def rosca_gun(p):
    """Rebitadora: bocal comprido com mola de recuo e ponta de encravar."""
    e, muzzle = ROSCA["elbow_r"], ROSCA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.53, 0), 0.06, 0.1, 16)
    for i in range(6):
        mring(p, "metal", sub(m, 0, 0.6 + i * 0.03, 0), 0.05, 0.008, 14, 4)
    mtube(p, "trim", sub(m, 0, 0.8, 0), 0.055, 0.12, 16, bevel=0.008)
    lathe(p, "metal", m, [(0.045, length - 0.07), (0.04, length - 0.02), (0.02, length)], 14)
    mtube(p, "glow", sub(m, 0, length - 0.001, 0), 0.014, 0.004, 10)


def wheel_foot(p, m, out, ankle, length=0.44, width=0.26, armor="shell", heel="trim"):
    """Pé de rodas: chassis com quatro rodas (pneu, jante, parafusos), guarda-lamas, biqueira
    de borracha, calcanhar e estabilizadores."""
    base = sub(m, 0, 0.1, -0.03)
    mbox(p, "dark", base, (width - 0.04, 0.05, length), 0.015)
    for side in (-1, 1):
        for z in (-length / 2 + 0.08, length / 2 - 0.08):
            wheel = axis_frame(at(m, side * (width / 2 - 0.01), 0.072, -0.03 + z), "x" if side > 0 else "-x")
            mring(p, "rubber", wheel, 0.05, 0.022, 22, 8)
            mtube(p, "metal", sub(wheel, 0, 0.0, 0), 0.04, 0.03, 16)
            bolts(p, sub(wheel, 0, 0.016, 0), 0.022, 4, size=0.006)
            mtube(p, "dark", sub(wheel, 0, -0.03, 0), 0.02, 0.04, 10)
    mbox(p, armor, sub(base, 0, 0.055, 0.02), (width - 0.02, 0.05, length * 0.62), 0.024)
    mbox(p, heel, sub(base, 0, 0.05, length / 2 - 0.04), (width * 0.7, 0.07, 0.07), 0.02)
    mbox(p, "rubber", sub(base, 0, -0.005, -length / 2 - 0.01), (width * 0.8, 0.07, 0.05), 0.02)
    for side, k in ((out, 1.0), (-out, 0.7)):
        mbox(p, "dark", sub(base, side * (width / 2 + 0.02), 0.03, 0.0), (0.025, 0.04 * k, length * 0.3 * k), 0.01)


def rosca_leg(p, out):
    def wheels(q, m, o, ankle):
        wheel_foot(q, m, o, ankle)
    leg(p, out, ROSCA["hip"].y, knee_y=-0.24, ankle_up=0.26, width=1.0, knee_w=0.115, knee_r=0.062, foot_fn=wheels,
        thigh_fn=round_thigh(k=1.0), shin_fn=round_shin(k=1.0, r_bottom=0.09, r_top=0.115), thigh_top=0.03, guard=False,
        shin_top=-0.19)


# ======================================================================================
# BROTO: jardineiro de estufa. Amigável e redondo: tronco em vaso, cabeça em cápsula com
# folhas-orelha em pinos e um rebento no topo, vaso com planta às costas, semeador com
# funil no braço direito e pés-triciclo (roda grande no calcanhar, rodízios à frente).
# ======================================================================================
BROTO = {
    "hip": Vector((0.2, 0.64, 0.0)),
    "shoulder_y": 1.25,
    "elbow_l": Vector((-0.48, 0.98, 0.02)),
    "wrist_l": Vector((-0.51, 0.72, -0.1)),
    "elbow_r": Vector((0.48, 0.98, -0.02)),
    "muzzle": Vector((0.43, 0.8, -0.93)),
}
BR_CHEST = Vector((0.0, 1.1, 0.02))
BR_HEAD = Vector((0.0, 1.68, 0.0))
BR_HEAD_R = 0.2
BR_SCREEN = (0.24, 0.13)


def leaf(p, role, m, length, width, vein="trim"):
    """Folha: amêndoa achatada ao longo do Y local de `m` (a partir da origem), com nervura."""
    prof = [(0.0, 0.0), (0.3, 0.12), (0.45, 0.4), (0.4, 0.7), (0.2, 0.92), (0.0, 1.0)]
    lathe(p, role, m @ Matrix.Diagonal((width, length, width * 0.16, 1.0)), prof, 14)
    mbox(p, vein, sub(m, 0, length * 0.48, 0.0), (0.008, length * 0.8, width * 0.18), 0.002, 1)


def broto_head(p):
    c = BR_HEAD
    r = BR_HEAD_R
    mk.HEADS["broto2_head"] = {"top": round(c.y + 0.2, 3), "center": round(c.y, 3), "aspect": round(BR_SCREEN[0] / BR_SCREEN[1], 3)}
    base = T(*c)
    capsule(p, "dark", base, r - 0.04, 0.4, 22)
    for lo in ((-205, -125), (-55, 25), (35, 145)):
        cyl_panel(p, "shell", base, r, 0.14, lo, 0.03, (10, 2), gap=0.01)
    dome(p, "shell", sub(base, 0, 0.07, 0), r, r * 0.8, 26, 7)
    dome(p, "shell", sub(base, 0, -0.07, 0, rot=(180, 0, 0)), r, r * 0.7, 26, 6)
    mring(p, "trim", sub(base, 0, 0.075, 0), r + 0.004, 0.012, 28, 5)
    screen_well(p, (c.x, c.y - 0.01, c.z - r + 0.015), BR_SCREEN, 0.05, 0.03)
    for side in (-1, 1):
        mbox(p, "shell", T(side * (BR_SCREEN[0] / 2 + 0.045), c.y - 0.01, c.z - r + 0.03), (0.05, 0.16, 0.05), 0.02)
    # Folhas-orelha em pinos: cubo, pino, e a folha que também é painel solar.
    for side in (-1, 1):
        hub = axis_frame((side * (r + 0.01), c.y + 0.04, c.z), "x" if side > 0 else "-x")
        mtube(p, "metal", hub, 0.035, 0.03, 16)
        bolts(p, sub(hub, 0, 0.016, 0), 0.024, 4, size=0.006)
        stem = sub(T(side * (r + 0.03), c.y + 0.04, c.z), rot=(0, 0, -side * 62))
        leaf(p, "shell", stem, 0.3, 0.2)
    # Rebento no topo: caule, duas folhinhas e um botão de luz.
    top = c.y + 0.07 + r * 0.8
    mtube(p, "dark", T(0, top + 0.01, c.z), 0.03, 0.02, 12)
    rod(p, "trim", (0, top + 0.01, c.z), (0.02, top + 0.12, c.z), 0.008, 6)
    for side in (-1, 1):
        leaf(p, "shell", sub(T(0.015, top + 0.08, c.z), rot=(0, 0, -side * 55)), 0.08, 0.06)
    ball(p, "glow", (0.022, top + 0.13, c.z), 0.022, 10)
    # Sensores: câmara pequena, LED, microfone.
    cam = axis_frame((0.11, c.y + 0.1, c.z - r + 0.01), "-z")
    mtube(p, "dark", cam, 0.02, 0.03, 12)
    mtube(p, "glow", sub(cam, 0, 0.016, 0), 0.007, 0.004, 8)
    mbox(p, "glow", T(-0.11, c.y + 0.1, c.z - r + 0.02), (0.03, 0.012, 0.012), 0.004, 1)
    serial(p, plane((0.0, c.y - 0.03, c.z + r + 0.001), (0, 0, 1), (1, 0, 0)), "06", 0.036)
    mbox(p, "team", T(0, top - 0.004, c.z - 0.08), (0.1, 0.012, 0.06), 0.004, 1)


def broto_torso(p):
    c = BR_CHEST
    H, rb, rt = 0.46, 0.21, 0.28
    neck(p, c.y + H / 2 - 0.01, BR_HEAD.y - 0.2 + 0.01, 0.075, 0.02, plate=(0.24, 0.22))
    base = T(c.x, c.y, c.z)
    lathe(p, "dark", base, [(0.0, -H / 2), (rb - 0.03, -H / 2), (rt - 0.03, H / 2), (0.0, H / 2)], 26)
    for y in (-0.1, 0.05):
        mring(p, "dark", sub(base, 0, y, 0), rb - 0.02 + (rt - rb) * (y + H / 2) / H, 0.012, 26, 4)
    # Vaso: gomos cónicos (mais largos em cima), aro de terracota clara, núcleo verde.
    for lo in ((-155, -98), (-82, -25), (-15, 45), (55, 125), (135, 195)):
        cyl_panel(p, "shell", sub(base, 0, -0.02, 0), rb, H - 0.08, lo, 0.035, (8, 2), gap=0.012, radius_top=rt - 0.01)
    mring(p, "trim", sub(base, 0, H / 2 - 0.02, 0), rt + 0.01, 0.03, 30, 8)
    core_round(p, axis_frame((0, c.y + 0.02, c.z - (rb + rt) / 2 + 0.005), "-z"), 0.05)
    for dx in (-0.08, 0.08):
        mtube(p, "dark", axis_frame((dx, c.y - 0.15, c.z - rb - 0.01), "-z"), 0.012, 0.02, 10)
    serial(p, cone_mark((c.x, c.y - 0.02, c.z), rb, rt - 0.01, H - 0.08, -56, 0.13), "06", 0.03)
    # Vaso às costas com terra e planta, preso num suporte.
    mbox(p, "dark", T(0, c.y + 0.02, c.z + rt + 0.02), (0.2, 0.22, 0.06), 0.012)
    pot = T(0, c.y - 0.06, c.z + rt + 0.14)
    lathe(p, "trim", pot, [(0.0, 0.0), (0.1, 0.0), (0.14, 0.2), (0.155, 0.22), (0.15, 0.24), (0.13, 0.24), (0.12, 0.2), (0.0, 0.2)], 24)
    dome(p, "rubber", sub(pot, 0, 0.2, 0), 0.125, 0.02, 20, 3)
    for i in range(5):
        a = math.radians(i * 72 + 15)
        leaf(p, "shell", sub(pot, math.cos(a) * 0.02, 0.21, math.sin(a) * 0.02, rot=(math.sin(a) * 40, 0, -math.cos(a) * 40)), 0.22, 0.12)
    warning(p, cone_mark(at(pot, 0, 0.1, 0), 0.1, 0.14, 0.2, 90, -0.01, 0.002), 0.045)
    charging_port(p, plane((-(rb + rt) / 2 - 0.004, c.y - 0.06, c.z + 0.05), (-1, 0, 0), (0, 0, 1)), 0.045, 0.028)
    waist(p, 0.74, c.y - H / 2 + 0.02, 0.12)
    pelvis(p, (0, 0.66, 0.0), (0.26, 0.16, 0.26), BROTO["hip"].x, BROTO["hip"].y, 0.085)


def broto_shoulders(p):
    y = BROTO["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.27, y, 0.01, 0.1, 0.08, 0.08)
        mbox(p, "dark", T(drum.x, y + 0.1, 0.01), (0.06, 0.06, 0.09), 0.012, 1)
        m = T(drum.x + side * 0.01, y + 0.04, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        sphere_panel(p, "shell", m, 0.16, (15, 85), (a0 - 25, a1 + 25), 0.03, (10, 5), gap=0.008)
        sphere_panel(p, "trim", m, 0.165, (2, 14), (a0 - 20, a1 + 20), 0.028, (12, 2), gap=0.006)
        mbox(p, "team", T(drum.x + side * 0.01, y + 0.2, 0.01), (0.08, 0.01, 0.1), 0.004, 1)
        upper_arm(p, side, pin, BROTO["elbow_l"] if side < 0 else BROTO["elbow_r"], bone_r=0.036, elbow_w=0.072, elbow_r=0.046, armor_size=(0.12, 0.1))


def broto_forearm_left(p):
    e, wr = BROTO["elbow_l"], BROTO["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    lathe(p, "dark", sub(m, 0, 0.05, 0), [(0.07, 0.0), (0.1, 0.04), (0.105, length * 0.6), (0.08, length - 0.05)], 18, True, True)
    for lo in ((-70, 70), (90, 250)):
        cyl_panel(p, "shell", sub(m, 0, 0.05 + length * 0.42, 0), 0.12, length * 0.5, lo, 0.03, (8, 2), gap=0.012, radius_top=0.112)
    mring(p, "trim", sub(m, 0, length * 0.8, 0), 0.11, 0.014, 20, 5)
    connector(p, sub(m, 0.121, length * 0.45, 0.0, rot=(0, 0, -90)), 0.014)
    mbox(p, "glow", sub(m, 0, length * 0.5, 0.121), (0.04, 0.012, 0.01), 0.003, 1)
    wrist(p, m, length)
    palm = sub(m, 0, length + 0.14, 0.0, rot=(0, -90, 180))
    hand(p, palm, fingers=3, scale=1.4, curl=1.0)


def broto_forearm_right(p):
    e, muzzle = BROTO["elbow_r"], BROTO["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    capsule(p, "shell", sub(m, 0, 0.26, 0), 0.105, 0.36, 18)
    mring(p, "trim", sub(m, 0, 0.16, 0), 0.107, 0.013, 20, 5)
    # Funil de sementes por cima, com tampa e janela de nível.
    hopper = frame(at(m, 0, 0.26, 0.1), at(m, 0, 0, 1) - at(m), front=(0, 0, -1))
    lathe(p, "trim", hopper, [(0.04, 0.0), (0.05, 0.04), (0.09, 0.12), (0.095, 0.14), (0.0, 0.14)], 18)
    mtube(p, "glow", sub(hopper, 0, 0.09, -0.07), 0.018, 0.006, 10)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.09, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.075, 6, size=0.009)


def broto_gun(p):
    """Semeador: cano com um difusor em flor na ponta; recua com o disparo."""
    e, muzzle = BROTO["elbow_r"], BROTO["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.53, 0), 0.06, 0.1, 16)
    mtube(p, "shell", sub(m, 0, 0.7, 0), 0.05, 0.26, 16, bevel=0.006)
    for i in range(6):
        a = i * 60
        petal = sub(m, 0, length - 0.05, 0, rot=(0, a, 0))
        mbox(p, "trim", sub(petal, 0.0, 0.0, 0.06, rot=(-35, 0, 0)), (0.05, 0.02, 0.08), 0.01, 1)
    mtube(p, "glow", sub(m, 0, length - 0.02, 0), 0.03, 0.02, 12)


def roller_foot(p, m, out, ankle, length=0.42, width=0.26, armor="shell"):
    """Pé-triciclo: roda grande no calcanhar (pneu, jante, parafusos, eixo), dois rodízios
    esféricos à frente, casco arredondado e biqueira de borracha."""
    base = sub(m, 0, 0.1, -0.03)
    mbox(p, "dark", base, (width - 0.06, 0.05, length), 0.015)
    rear = at(m, 0, 0.09, -0.03 + length / 2 - 0.08)
    for side in (-1, 1):
        wheel = axis_frame(rear + Vector((side * (width / 2 - 0.01), 0, 0)), "x" if side > 0 else "-x")
        mring(p, "rubber", wheel, 0.065, 0.026, 24, 8)
        mtube(p, "metal", wheel, 0.05, 0.03, 18)
        bolts(p, sub(wheel, 0, 0.016, 0), 0.028, 5, size=0.006)
    mtube(p, "metal", axis_frame(rear, "x"), 0.014, width + 0.04, 10)
    for side in (-1, 1):
        caster = at(m, side * 0.07, 0.035, -0.03 - length / 2 + 0.08)
        mtube(p, "dark", T(caster.x, caster.y + 0.04, caster.z), 0.03, 0.03, 12)
        ball(p, "rubber", caster, 0.035, 12)
    shell_m = sub(base, 0, 0.03, -0.05)
    dome(p, armor, shell_m @ Matrix.Diagonal((1.0, 1.0, 1.6, 1.0)), 0.12, 0.08, 22, 6)
    mbox(p, "rubber", sub(base, 0, 0.0, -length / 2 - 0.01), (width * 0.7, 0.06, 0.04), 0.02)


def broto_leg(p, out):
    def rollers(q, m, o, ankle):
        roller_foot(q, m, o, ankle)
    leg(p, out, BROTO["hip"].y, knee_y=-0.23, ankle_up=0.26, width=1.0, knee_w=0.115, knee_r=0.062, foot_fn=rollers,
        thigh_fn=round_thigh(k=1.0), shin_fn=round_shin(k=1.0, r_bottom=0.09, r_top=0.115), thigh_top=0.03, guard=False,
        shin_top=-0.18)


# ======================================================================================
# GANCHO: corsário das rotas. Esguio em cima e largo no meio: cabeça-sensor dentro de um capuz
# de chapa com um só olho (o outro sensor está tapado por uma tampa aparafusada) e luneta de
# pontaria, tronco em pipa com aduelas e arcos, ombreiras em lamelas, capa de placas numa verga
# curva às costas, bacamarte de sino com gancho de abordagem e botas de canhão largo.
# ======================================================================================
GANCHO = {
    "hip": Vector((0.21, 0.64, 0.0)),
    "shoulder_y": 1.2,
    "elbow_l": Vector((-0.5, 0.93, 0.02)),
    "wrist_l": Vector((-0.53, 0.65, -0.1)),
    "elbow_r": Vector((0.5, 0.93, -0.02)),
    "muzzle": Vector((0.45, 0.8, -1.02)),
}
G_CHEST = Vector((0.0, 1.1, 0.02))
G_CASK = (0.29, 0.34, 0.27)
G_CASK_LAT = 40
G_HEAD = Vector((0.0, 1.66, -0.02))
G_HEAD_R = 0.17
G_HOOD_R = 0.215
G_SCREEN = (0.15, 0.12)
G_CAPE_Y = 1.26
G_CAPE_R = 0.34


def ell_point(center, radii, lat, lon, lift=0.001):
    """Ponto e normal num elipsoide (pipa, ovo), com `lat`/`lon` em graus como nos painéis
    (lon 0 = +X, -90 = frente, 90 = costas)."""
    ex, ey, ez = radii
    la, lo = math.radians(lat), math.radians(lon)
    q = Vector((ex * math.cos(la) * math.cos(lo), ey * math.sin(la), ez * math.cos(la) * math.sin(lo)))
    n = Vector((q.x / ex ** 2, q.y / ey ** 2, q.z / ez ** 2)).normalized()
    return Vector(center) + q + n * lift, n


def meridian_arc(p, role, center, radius, lon, lat0, lat1, minor=0.012, detail=16):
    """Debrum ao longo de um meridiano de uma esfera (de `lat0` a `lat1`, em graus)."""
    lo = math.radians(lon)
    d = Vector((math.cos(lo), 0.0, math.sin(lo)))
    n = Vector((-math.sin(lo), 0.0, math.cos(lo)))
    arc_tube(p, role, frame(Vector(center), n, front=d), radius, minor, 90 - lat1, 90 - lat0, detail, 6)


def gancho_head(p):
    c = G_HEAD
    r = G_HEAD_R
    rh = G_HOOD_R
    mk.HEADS["gancho2_head"] = {"top": round(c.y + rh + 0.03, 3), "center": round(c.y, 3), "aspect": round(G_SCREEN[0] / G_SCREEN[1], 3)}
    base = T(*c)
    # Caixa de sensores: esfera escura de estrutura e três placas à volta do rosto.
    ball(p, "dark", c, r - 0.03, 20)
    for lat, lo in (((-46, 30), (-148, -108)), ((-46, 30), (-47, -34)), ((-54, -30), (-104, -50))):
        sphere_panel(p, "shell", base, r, lat, lo, 0.03, (8, 5), gap=0.008)
    # Olho único recuado à direita; o sensor da esquerda leva uma tampa aparafusada.
    screen_well(p, (c.x + 0.035, c.y - 0.005, c.z - r + 0.012), G_SCREEN, 0.05, 0.03)
    pos, n = ell_point(c, (r, r, r), 2, -124, 0.0)
    patch = frame(pos, n)
    mtube(p, "dark", sub(patch, 0, 0.006, 0), 0.044, 0.02, 20, bevel=0.004)
    mring(p, "metal", sub(patch, 0, 0.016, 0), 0.044, 0.006, 20, 4)
    bolts(p, sub(patch, 0, 0.016, 0), 0.03, 4, size=0.006, phase=math.radians(45))
    # Capuz de chapa: coroa sobre a testa, três peças à volta (abertas à frente), debrum de
    # borracha na abertura, bico atrás com luz de estado e cubos de articulação nas fontes.
    hood_c = Vector((c.x, c.y + 0.005, c.z + 0.012))
    hood = T(*hood_c)
    sphere_panel(p, "trim", hood, rh, (36, 88), (-180, 180), 0.03, (28, 4), gap=0.0)
    for lo in ((-40, 58), (62, 118), (122, 220)):
        sphere_panel(p, "trim", hood, rh, (-32, 33), lo, 0.03, (12, 6), gap=0.004)
    arc_tube(p, "rubber", sub(hood, 0, rh * math.sin(math.radians(36)), 0), rh * math.cos(math.radians(36)) + 0.004, 0.009, -142, -38, 18, 6)
    for lon in (-40, 220):
        meridian_arc(p, "rubber", hood_c, rh + 0.004, lon, -32, 36, 0.009)
    tip = Vector((0.0, math.cos(math.radians(40)), math.sin(math.radians(40))))
    peak = frame(hood_c + Vector((0, rh * math.sin(math.radians(68)), rh * math.cos(math.radians(68)))), tip)
    lathe(p, "trim", peak, [(0.0, -0.04), (0.075, -0.04), (0.062, 0.02), (0.036, 0.07), (0.014, 0.098), (0.0, 0.104)], 18)
    ball(p, "glow", at(peak, 0, 0.1, 0), 0.013, 10)
    for side in (-1, 1):
        hub = axis_frame((side * (rh - 0.004), hood_c.y + 0.015, hood_c.z), "x" if side > 0 else "-x")
        mtube(p, "metal", hub, 0.042, 0.024, 18, bevel=0.004)
        bolts(p, sub(hub, 0, 0.013, 0), 0.03, 4, size=0.006)
    # Luneta de pontaria (telémetro) presa ao cubo direito: tubo, tubo de tiragem, objetiva.
    mbox(p, "dark", T(rh + 0.03, hood_c.y + 0.015, hood_c.z - 0.055), (0.05, 0.036, 0.1), 0.008, 1)
    scope = axis_frame((rh + 0.052, hood_c.y + 0.025, hood_c.z - 0.13), "-z")
    mtube(p, "metal", scope, 0.03, 0.15, 16, bevel=0.004)
    mring(p, "dark", sub(scope, 0, -0.03, 0), 0.031, 0.006, 16, 4)
    mtube(p, "metal", sub(scope, 0, 0.1, 0), 0.024, 0.06, 14)
    mtube(p, "dark", sub(scope, 0, 0.14, 0), 0.029, 0.024, 16)
    mtube(p, "glow", sub(scope, 0, 0.153, 0), 0.02, 0.004, 12)
    # Microfone sob a tampa, número de série atrás e a faixa da equipa na coroa.
    for i in range(3):
        q, nq = ell_point(c, (r, r, r), -24 - i * 7, -124, 0.0)
        mbox(p, "dark", plane(q, nq, (math.sin(math.radians(-124)), 0, -math.cos(math.radians(-124)))), (0.03, 0.006, 0.008), 0.002, 1)
    serial(p, plane((0.0, hood_c.y, hood_c.z + rh + 0.001), (0, 0, 1), (1, 0, 0)), "07", 0.036)
    sphere_panel(p, "team", hood, rh + 0.004, (42, 74), (-97, -83), 0.008, (2, 4), gap=0.0)


def gancho_torso(p):
    c = G_CHEST
    ex, ey, ez = G_CASK
    top_y = ey * math.sin(math.radians(G_CASK_LAT))
    rim_r = ex * math.cos(math.radians(G_CASK_LAT))
    neck(p, c.y + top_y + 0.012, G_HEAD.y - G_HEAD_R + 0.025, 0.07, 0.0, plate=(0.22, 0.2))
    flat = scaled(c, 1.0, 1.0, ez / ex)
    cask = scaled(c, ex, ey, ez)
    # Chassis: o corpo escuro da pipa, tampos em cima e em baixo e os arcos de latão.
    prof = [(0.0, -top_y)]
    for a in range(-G_CASK_LAT, G_CASK_LAT + 1, 10):
        prof.append(((ex - 0.035) * math.cos(math.radians(a)), ey * math.sin(math.radians(a))))
    lathe(p, "dark", flat, prof + [(0.0, top_y)], 26)
    for s in (-1, 1):
        lid = sub(flat, 0, s * top_y, 0)
        mtube(p, "dark", lid, rim_r - 0.012, 0.03, 26)
        mring(p, "metal", lid, rim_r + 0.002, 0.016, 32, 6)
    # Aduelas: oito placas curvas, com fendas mais largas à frente (núcleo), nas ilhargas
    # (suportes dos ombros) e atrás (suporte da verga).
    staves = ((-70, -40), (-36, -8), (8, 40), (44, 84), (96, 136), (140, 172), (188, 218), (222, 250))
    for lo in staves:
        sphere_panel(p, "shell", cask, 1.0, (-38, 38), lo, 0.11, (6, 8), gap=0.0)
    hoop_y = -0.1
    hoop_r = ex * math.sqrt(1.0 - (hoop_y / ey) ** 2) + 0.012
    mring(p, "metal", sub(flat, 0, hoop_y, 0), hoop_r, 0.012, 36, 6)
    for lo in staves:
        a = math.radians((lo[0] + lo[1]) / 2)
        q = Vector((c.x + math.cos(a) * (hoop_r + 0.01), c.y + hoop_y, c.z + math.sin(a) * (hoop_r + 0.01) * ez / ex))
        mtube(p, "metal", frame(q, (math.cos(a), 0, math.sin(a) * ex / ez)), 0.009, 0.01, 6)
    # Núcleo: vigia redonda recuada entre as aduelas da frente, com dobradiça e fecho.
    pos, n = ell_point(c, G_CASK, 3, -90, 0.0)
    core = axis_frame(pos, "-z")
    core_round(p, core, 0.052, frame_role="metal")
    mtube(p, "dark", sub(core, -0.082, 0.0, 0.0, rot=(90, 0, 0)), 0.01, 0.045, 8)
    mbox(p, "metal", sub(core, 0.082, 0.006, 0.0), (0.02, 0.016, 0.03), 0.004, 1)
    q, nq = ell_point(c, G_CASK, 20, -55)
    serial(p, plane(q, nq, (math.sin(math.radians(-55)), 0, -math.cos(math.radians(-55)))), "07", 0.03)
    q, nq = ell_point(c, G_CASK, -12, 203)
    charging_port(p, plane(q, nq, (math.sin(math.radians(203)), 0, -math.cos(math.radians(203)))), 0.045, 0.028)
    q, nq = ell_point(c, G_CASK, -20, 24)
    inspection_label(p, plane(q, nq, (math.sin(math.radians(24)), 0, -math.cos(math.radians(24)))), 0.06, 0.035)
    # Verga curva às costas (três suportes pelas fendas até ao chassis) e a capa de placas
    # penduradas em olhais: protege as costas e as ancas e baloiça com o passo.
    for lon in (42, 90, 138):
        a = math.radians(lon)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        mbox(p, "dark", frame(Vector((0.0, G_CAPE_Y, c.z)) + d * 0.285, d), (0.05, 0.12, 0.05), 0.01)
        mring(p, "dark", frame(Vector((0.0, G_CAPE_Y, c.z)) + d * G_CAPE_R, Vector((-d.z, 0.0, d.x))), 0.026, 0.009, 14, 4)
    arc_tube(p, "metal", T(0.0, G_CAPE_Y, c.z), G_CAPE_R, 0.018, 34, 146, 26, 8)
    for lon in (34, 146):
        a = math.radians(lon)
        ball(p, "metal", (G_CAPE_R * math.cos(a), G_CAPE_Y, c.z + G_CAPE_R * math.sin(a)), 0.026, 12)
    top = G_CAPE_Y - 0.035
    flare = G_CAPE_R + 0.11
    for lo, bottom in (((44, 74), 0.53), ((77, 103), 0.47), ((106, 136), 0.55)):
        h = top - bottom
        origin = (0.0, (top + bottom) / 2, c.z)
        dagged_panel(p, "trim", origin, flare, G_CAPE_R + 0.004, h, lo, 0.022, teeth=2, depth=0.07)
        strap_r = G_CAPE_R + 0.004 + (flare - G_CAPE_R - 0.004) * 0.09 + 0.012
        cyl_panel(p, "shell", T(0.0, top - 0.045, c.z), strap_r, 0.06, (lo[0] - 1, lo[1] + 1), 0.014, (10, 1), gap=0.0,
                  radius_top=strap_r - (flare - G_CAPE_R - 0.004) * 0.06 / h)
        for t in (0.25, 0.75):
            lon = lo[0] + (lo[1] - lo[0]) * t
            a = math.radians(lon)
            d = Vector((math.cos(a), 0.0, math.sin(a)))
            eye = Vector((0.0, G_CAPE_Y, c.z)) + d * G_CAPE_R
            mring(p, "dark", frame(eye, Vector((-d.z, 0.0, d.x))), 0.029, 0.007, 14, 4)
            mbox(p, "dark", frame(eye + Vector((0, -0.04, 0)) + d * 0.004, d), (0.032, 0.006, 0.03), 0.004, 1)
            for u in (-1, 1):
                q = cone_mark((0.0, top - 0.045, c.z), strap_r, strap_r - (flare - G_CAPE_R - 0.004) * 0.06 / h, 0.06, lon + u * 2.6, 0.0, 0.0)
                screw(p, q, 0.0, 0.0, 0.007)
    mid_h = top - 0.47
    warning(p, cone_mark((0.0, (top + 0.47) / 2, c.z), flare, G_CAPE_R + 0.004, mid_h, 90, -mid_h / 2 + 0.16, 0.002), 0.05)
    waist(p, 0.74, c.y - top_y + 0.02, 0.135)
    pelvis(p, (0, 0.66, 0.0), (0.27, 0.16, 0.26), GANCHO["hip"].x, GANCHO["hip"].y, 0.088)


def gancho_shoulders(p):
    y = GANCHO["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.29, y, 0.01, 0.1, 0.08, 0.08)
        mbox(p, "dark", T(drum.x, y + 0.1275, 0.01), (0.06, 0.095, 0.09), 0.012, 1)
        m = T(drum.x + side * 0.012, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        # Ombreira em três lamelas sobrepostas (a de cima por fora), presas por rebites nas
        # pontas, como as dobras de um casaco de oficial.
        for i, (lat, rad, role) in enumerate((((56, 88), 0.18, "shell"), ((33, 60), 0.172, "shell"), ((10, 37), 0.164, "trim"))):
            sphere_panel(p, role, m, rad, lat, (a0 - 18 - i * 7, a1 + 18 + i * 7), 0.026, (12, 3), gap=0.004)
            for end in (a0 - 14 - i * 7, a1 + 14 + i * 7):
                la, lo = math.radians((lat[0] + lat[1]) / 2), math.radians(end)
                q = at(m, rad * math.cos(la) * math.cos(lo), rad * math.sin(la), rad * math.cos(la) * math.sin(lo))
                screw(p, frame(q, q - at(m)), 0.0, 0.0, 0.008)
        mbox(p, "team", T(drum.x + side * 0.012, y + 0.197, 0.01), (0.07, 0.01, 0.1), 0.004, 1)
        upper_arm(p, side, pin, GANCHO["elbow_l"] if side < 0 else GANCHO["elbow_r"], bone_r=0.038, elbow_w=0.075, elbow_r=0.048, armor_size=(0.12, 0.1))


def gancho_forearm_left(p):
    e, wr = GANCHO["elbow_l"], GANCHO["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    lathe(p, "dark", sub(m, 0, 0.05, 0), [(0.07, 0.0), (0.1, 0.04), (0.1, length * 0.6), (0.08, length - 0.05)], 18, True, True)
    cuff_at = length * 0.6
    for lo in ((-70, 70), (90, 250)):
        cyl_panel(p, "shell", sub(m, 0, (0.06 + cuff_at - 0.008) / 2, 0), 0.118, cuff_at - 0.068, lo, 0.03, (8, 2), gap=0.012, radius_top=0.112)
    # Canhão da manga: aro largo de lona que abre para o pulso, aparafusado ao alojamento.
    cuff = sub(m, 0, cuff_at, 0)
    span = length - cuff_at + 0.005
    lathe(p, "trim", cuff, [(0.098, 0.0), (0.122, 0.0), (0.15, span - 0.016), (0.145, span), (0.082, span), (0.098, 0.0)], 24)
    for deg in (-50, 0, 50):
        a = math.radians(deg)
        q = at(cuff, 0.136 * math.cos(a), span * 0.55, 0.136 * math.sin(a))
        screw(p, frame(q, q - at(cuff, 0, span * 0.55, 0)), 0.0, 0.0, 0.008)
    connector(p, sub(m, 0.118, cuff_at * 0.55, 0.0, rot=(0, 0, -90)), 0.014)
    mbox(p, "glow", sub(m, 0, cuff_at * 0.6, 0.118), (0.04, 0.012, 0.01), 0.003, 1)
    wrist(p, m, length)
    palm = sub(m, 0, length + 0.14, 0.0, rot=(0, -90, 180))
    hand(p, palm, fingers=3, scale=1.4, curl=1.0)


def gancho_forearm_right(p):
    e, muzzle = GANCHO["elbow_r"], GANCHO["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    # Culatra de canhão naval: traseira redonda, reforços de latão, afunila para a boca.
    lathe(p, "shell", m, [(0.0, 0.07), (0.06, 0.075), (0.11, 0.1), (0.132, 0.15), (0.13, 0.25), (0.12, 0.36), (0.106, 0.43), (0.09, 0.45), (0.0, 0.45)], 26)
    for v, rr in ((0.16, 0.134), (0.28, 0.13), (0.39, 0.118)):
        mring(p, "metal", sub(m, 0, v, 0), rr, 0.012, 26, 5)
    vents(p, sub(m, 0, 0.335, 0.122), 3, 0.05, depth=0.014, spacing=0.024, height=0.01)
    # Guincho do gancho no flanco de fora: tambor com o cabo enrolado, motor e suporte.
    side = at(m, 1, 0, 0) - at(m)
    drum_at = at(m, 0.168, 0.22, 0.0)
    mbox(p, "dark", frame(at(m, 0.123, 0.22, 0.0), side), (0.05, 0.03, 0.07), 0.008)
    spool = frame(drum_at, side, front=at(m, 0, 0, 1) - at(m))
    mtube(p, "dark", spool, 0.036, 0.07, 16)
    for v in (-0.034, 0.034):
        mtube(p, "metal", sub(spool, 0, v, 0), 0.056, 0.008, 20)
    for v in (-0.018, 0.0, 0.018):
        mring(p, "rubber", sub(spool, 0, v, 0), 0.042, 0.008, 18, 5)
    servo(p, sub(spool, 0, 0.052, 0), 0.03, 0.03)
    cable(p, [at(m, 0.168, 0.26, 0.04), at(m, 0.12, 0.34, 0.1), at(m, 0.07, 0.445, 0.07)], 0.009)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.09, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.075, 6, size=0.009)


def gancho_gun(p):
    """Bacamarte de sino com um gancho de abordagem de três pontas pronto a sair da boca;
    recua com o disparo."""
    e, muzzle = GANCHO["elbow_r"], GANCHO["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.53, 0), 0.06, 0.1, 16)
    lathe(p, "metal", m, [(0.048, 0.56), (0.056, 0.6), (0.052, 0.64), (0.046, 0.72), (0.05, 0.8), (0.07, 0.87),
                          (0.11, 0.94), (0.148, length - 0.018), (0.156, length - 0.004), (0.15, length)], 26)
    lathe(p, "dark", m, [(0.144, length), (0.1, length - 0.05), (0.05, length - 0.12), (0.0, length - 0.13)], 24)
    for v in (0.6, 0.8):
        mring(p, "dark", sub(m, 0, v, 0), 0.056 if v < 0.7 else 0.05, 0.01, 18, 5)
    mring(p, "glow", sub(m, 0, length - 0.05, 0), 0.1, 0.007, 24, 4)
    # Gancho: haste que sai do fundo do sino e três pontas curvas viradas para trás.
    y0 = length + 0.07
    rod(p, "metal", at(m, 0, length - 0.12, 0), at(m, 0, y0 + 0.01, 0), 0.022, 12)
    ball(p, "metal", at(m, 0, y0 + 0.014, 0), 0.032, 14)
    axis = (at(m, 0, 1, 0) - at(m)).normalized()
    rho = 0.064
    for k in range(3):
        t = math.radians(90 + k * 120)
        d = (at(m, math.cos(t), 0, math.sin(t)) - at(m)).normalized()
        centre = at(m, 0, y0, 0) + d * rho
        arc_tube(p, "metal", frame(centre, axis.cross(d), front=axis), rho, 0.016, -32, 180, 18, 8)
        a = math.radians(-32)
        tip = centre + d * rho * math.cos(a) + axis * rho * math.sin(a)
        back = (d * math.sin(a) - axis * math.cos(a)).normalized()
        lathe(p, "metal", frame(tip, back), [(0.0, -0.006), (0.026, 0.0), (0.0, 0.042)], 12)


def boot_shin(k=1.0, r_bottom=0.095, r_top=0.12, cuff=0.158):
    """Canela em bota: casco em cone à frente e dos lados (aberto atrás para a barriga da perna
    e os cabos), ventilação e aviso no flanco de fora e um canhão largo de lona à frente do
    joelho, aparafusado ao casco. Os lados do joelho ficam à vista."""
    def fn(p, out, top, bottom, mid):
        h = top - bottom

        def radius_at(y):
            return (r_bottom + (r_top - r_bottom) * (y - bottom) / h) * k
        cyl_panel(p, "shell", T(0, bottom + h / 2, 0.0), r_bottom * k, h, (-196, 16), 0.035, (16, 2), gap=0.01, radius_top=r_top * k)
        hc = 0.09
        y0 = top + 0.01 - hc
        cyl_panel(p, "trim", T(0, y0 + hc / 2, 0.0), radius_at(y0) + 0.02, hc, (-158, -22), 0.026, (12, 2), gap=0.0, radius_top=cuff * k)
        for deg in (-125, -55):
            q = cone_mark((0, y0 + hc / 2, 0.0), radius_at(y0) + 0.02, cuff * k, hc, deg, -hc / 2 + 0.028, 0.0)
            screw(p, q, 0.0, 0.0, 0.008)
        yv = bottom + h * 0.42
        vents(p, T(out * (radius_at(yv) + 0.002), yv, 0.0), 3, 0.012, depth=0.06, spacing=0.024)
        warning(p, cone_mark((0, bottom + h / 2, 0.0), r_bottom * k, r_top * k, h, 0 if out > 0 else 180, -h / 2 + 0.05, 0.001), 0.03, 0.003)
    return fn


def gancho_leg(p, out):
    def boots(q, m, o, ankle):
        foot(q, m, length=0.44, width=0.27, out=o, toes=2, armor="shell", heel="trim")
    leg(p, out, GANCHO["hip"].y, knee_y=-0.24, ankle_up=0.17, width=1.0, knee_w=0.115, knee_r=0.062, foot_fn=boots,
        thigh_fn=round_thigh(k=1.0), shin_fn=boot_shin(k=1.0), thigh_top=0.03, guard=False, shin_top=-0.19)


# ======================================================================================
# FAÍSCA: caçadora de tempestades. Corredora ágil: cabeça larga com a fenda do visor que
# varre, dois para-raios em ziguezague sobre isoladores, tronco em gota invertida com banco
# de condensadores, bobina de Tesla às costas com o toro atrás do pescoço, emissor-bobina no
# braço direito e pernas de ave com pés de três dedos e esporão.
# ======================================================================================
FAISCA = {
    "hip": Vector((0.19, 0.74, 0.0)),
    "shoulder_y": 1.32,
    "elbow_l": Vector((-0.46, 1.05, 0.02)),
    "wrist_l": Vector((-0.49, 0.78, -0.1)),
    "elbow_r": Vector((0.46, 1.05, -0.02)),
    "muzzle": Vector((0.42, 0.9, -0.98)),
}
F_CHEST = Vector((0.0, 1.2, 0.02))
F_TORSO = [(-0.26, 0.1), (-0.22, 0.14), (-0.14, 0.185), (-0.04, 0.215), (0.06, 0.225), (0.13, 0.212), (0.18, 0.175), (0.21, 0.12)]
F_DEPTH = 0.85
F_HEAD = Vector((0.0, 1.77, -0.01))
F_HEAD_RADII = (0.19, 0.155, 0.16)
F_SCREEN = (0.2, 0.066)
F_COIL = Vector((0.0, 1.12, 0.37))


def profile_radius(profile, y):
    """Raio de um perfil [(y, r), ...] (y a subir) por interpolação linear."""
    if y <= profile[0][0]:
        return profile[0][1]
    for (y0, r0), (y1, r1) in zip(profile, profile[1:]):
        if y <= y1:
            return r0 + (r1 - r0) * ((y - y0) / (y1 - y0) if y1 > y0 else 0.0)
    return profile[-1][1]


def rev_panel(p, role, m, profile, y_range, lon, thickness=0.03, steps=(10, 8), gap=0.0):
    """Painel de um sólido de revolução com perfil livre à volta do Y local de `m` (lon em
    graus, 0 = +X local, -90 = -Z local)."""
    rmax = max(r for _, r in profile)
    g = math.degrees(gap / rmax)
    lo = (math.radians(lon[0] + g), math.radians(lon[1] - g))

    def point(u, v, d):
        r = profile_radius(profile, v) - d
        return Vector((r * math.cos(u), v, r * math.sin(u)))
    mk._shell_panel(p, role, m, point, lo, (y_range[0] + gap / 2, y_range[1] - gap / 2), thickness, steps)


def rev_point(center, profile, depth, lon, y, lift=0.001):
    """Ponto e normal na superfície do tronco de revolução (achatado em Z por `depth`)."""
    a = math.radians(lon)
    r = profile_radius(profile, y)
    slope = (profile_radius(profile, y + 0.005) - profile_radius(profile, y - 0.005)) / 0.01
    n = Vector((math.cos(a), -slope, math.sin(a) / depth)).normalized()
    return Vector(center) + Vector((r * math.cos(a), y, r * math.sin(a) * depth)) + n * lift, n


def extruded(p, role, m, pts, thickness):
    """Placa plana com o contorno `pts` (x, y) no plano XY local de `m`, espessura em Z."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y, -thickness / 2)) for x, y in pts]
    back = [bm.verts.new((x, y, thickness / 2)) for x, y in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    p.add(role, bm, m)


BOLT = [(-0.02, 0.0), (0.025, 0.0), (0.01, 0.07), (0.045, 0.07), (-0.01, 0.19), (0.0, 0.1), (-0.035, 0.1)]


def faisca_head(p):
    c = F_HEAD
    ex, ey, ez = F_HEAD_RADII
    mk.HEADS["faisca2_head"] = {"top": round(c.y + ey + 0.05, 3), "center": round(c.y, 3), "aspect": round(F_SCREEN[0] / F_SCREEN[1], 3)}
    hs = scaled(c, ex, ey, ez)
    lathe(p, "dark", scaled(c, ex - 0.035, ey - 0.03, ez - 0.035), [(0.0, -1.0)] + [(math.sin(math.radians(a)), -math.cos(math.radians(a))) for a in range(15, 180, 15)] + [(0.0, 1.0)], 22)
    # Calota em duas metades (a crista dos para-raios entre elas), faixa azul à volta com a
    # fenda do visor aberta à frente, queixo e nuca.
    sphere_panel(p, "shell", hs, 1.0, (17, 88), (-88, 88), 0.2, (10, 6), gap=0.05)
    sphere_panel(p, "shell", hs, 1.0, (17, 88), (92, 268), 0.2, (10, 6), gap=0.05)
    sphere_panel(p, "trim", hs, 1.02, (-15, 15), (-26, 206), 0.2, (20, 2), gap=0.04)
    sphere_panel(p, "shell", hs, 1.0, (-70, -17), (-150, -30), 0.2, (10, 4), gap=0.05)
    sphere_panel(p, "shell", hs, 1.0, (-65, -17), (-26, 206), 0.2, (16, 4), gap=0.05)
    # Visor que varre: ecrã largo recuado na fenda, barras de retenção em metal.
    p.screen((c.x, c.y, c.z - ez + 0.04), F_SCREEN, bulge=0.01)
    for dy in (-1, 1):
        mbox(p, "metal", T(c.x, c.y + dy * 0.041, c.z - ez + 0.036), (0.2, 0.012, 0.014), 0.004, 1)
    # Para-raios: ziguezagues sobre pilhas de isoladores, inclinados para trás.
    for side in (-1, 1):
        base = T(side * 0.05, c.y + ey * 0.93, c.z + 0.03)
        lean = sub(base, rot=(28, 0, -side * 12))
        for i, rr in enumerate((0.026, 0.022, 0.018)):
            mtube(p, "shell" if i % 2 == 0 else "trim", sub(lean, 0, 0.012 + i * 0.018, 0), rr, 0.014, 14, bevel=0.003)
        mtube(p, "dark", sub(lean, 0, 0.03, 0), 0.008, 0.07, 8)
        extruded(p, "trim", sub(sub(lean, 0, 0.062, 0), rot=(0, 90, 0)), BOLT, 0.018)
        ball(p, "glow", at(lean, 0, 0.062 + 0.19, 0.0), 0.013, 8)
    # Sensores: LED de estado e grelha de microfone de lado, número atrás.
    mbox(p, "glow", T(ex - 0.004, c.y + 0.02, c.z - 0.03), (0.012, 0.024, 0.03), 0.004, 1)
    for i in range(3):
        mbox(p, "dark", T(-ex + 0.006, c.y - 0.05 - i * 0.018, c.z), (0.01, 0.008, 0.05), 0.002, 1)
    serial(p, plane((0.0, c.y, c.z + ez * 1.02 + 0.002), (0, 0, 1), (1, 0, 0)), "08", 0.03)
    mbox(p, "team", T(0, c.y + ey + 0.002, c.z - 0.04), (0.02, 0.01, 0.1), 0.004, 1)


def faisca_torso(p):
    c = F_CHEST
    top, bottom = F_TORSO[-1][0], F_TORSO[0][0]
    neck(p, c.y + top - 0.005, F_HEAD.y - F_HEAD_RADII[1] + 0.02, 0.062, 0.0, plate=(0.2, 0.18))
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, F_DEPTH, 1.0))
    inner = [(y, r - 0.035) for y, r in F_TORSO]
    lathe(p, "dark", flat, [(0.0, bottom)] + [(r, y) for y, r in inner] + [(0.0, top)], 26)
    # Blindagem: dois painéis à frente (condensadores entre eles), ilhargas baixas (em cima
    # entram os suportes dos ombros), duas costas com a fenda do suporte da bobina.
    for lo, yr in (((-150, -104), (-0.24, 0.19)), ((-76, -30), (-0.24, 0.19)), ((-28, 28), (-0.24, -0.02)),
                   ((152, 208), (-0.24, -0.02)), ((32, 84), (-0.24, 0.19)), ((96, 148), (-0.24, 0.19))):
        rev_panel(p, "shell", flat, F_TORSO, yr, lo, 0.034, (8, 8), gap=0.012)
    mring(p, "trim", sub(flat, 0, bottom + 0.035, 0), profile_radius(F_TORSO, bottom + 0.035) + 0.004, 0.014, 26, 5)
    # Banco de condensadores recuado: caixa escura, três garrafas de luz, moldura azul.
    core = T(0, c.y + 0.02, c.z - 0.215 * F_DEPTH + 0.02)
    mbox(p, "dark", sub(core, 0, 0, 0.01), (0.1, 0.17, 0.05), 0.01)
    for dx in (-0.03, 0.0, 0.03):
        capsule(p, "glow", sub(core, dx, 0, -0.012), 0.011, 0.12, 10)
        for dy in (-1, 1):
            mtube(p, "metal", sub(core, dx, dy * 0.062, -0.012), 0.014, 0.012, 10)
    for dy in (-1, 1):
        mbox(p, "trim", sub(core, 0, dy * 0.092, -0.016), (0.12, 0.016, 0.02), 0.006, 1)
    for dx in (-1, 1):
        mbox(p, "trim", sub(core, dx * 0.058, 0, -0.016), (0.016, 0.2, 0.02), 0.006, 1)
    q, n = rev_point(c, F_TORSO, F_DEPTH, -50, 0.1)
    serial(p, plane(q, n, (math.sin(math.radians(-50)), 0, -math.cos(math.radians(-50)))), "08", 0.028)
    q, n = rev_point(c, F_TORSO, F_DEPTH, 180, -0.12)
    charging_port(p, plane(q, n, (0, 0, 1)), 0.042, 0.026)
    # Bobina de Tesla às costas: suporte pela fenda, base com parafusos, primário, forma
    # azul enrolada, toro no topo e ponto de descarga.
    b = F_COIL
    mbox(p, "dark", T(0, b.y + 0.02, (0.17 + b.z) / 2 - 0.02), (0.08, 0.08, b.z - 0.15), 0.012)
    mtube(p, "dark", T(b.x, b.y, b.z), 0.075, 0.05, 20, bevel=0.006)
    bolts(p, T(b.x, b.y + 0.026, b.z), 0.06, 6, size=0.008)
    for i in range(3):
        mring(p, "metal", T(b.x, b.y + 0.045 + i * 0.022, b.z), 0.085, 0.009, 22, 5)
    mtube(p, "trim", T(b.x, b.y + 0.25, b.z), 0.045, 0.38, 16, bevel=0.006)
    for i in range(11):
        mring(p, "metal", T(b.x, b.y + 0.1 + i * 0.03, b.z), 0.048, 0.004, 16, 4)
    mring(p, "metal", T(b.x, b.y + 0.46, b.z), 0.1, 0.042, 32, 12)
    mtube(p, "dark", T(b.x, b.y + 0.46, b.z), 0.05, 0.03, 16)
    rod(p, "metal", (b.x + 0.1, b.y + 0.49, b.z), (b.x + 0.11, b.y + 0.54, b.z), 0.006, 6)
    ball(p, "glow", (b.x + 0.11, b.y + 0.55, b.z), 0.016, 10)
    warning(p, plane((b.x, b.y + 0.005, b.z - 0.0755), (0, 0, -1), (-1, 0, 0)), 0.032)
    cable(p, [(0.06, b.y, b.z - 0.05), (0.09, b.y - 0.04, 0.26), (0.06, b.y - 0.02, 0.19)], 0.01)
    waist(p, 0.84, c.y + bottom + 0.02, 0.11)
    pelvis(p, (0, 0.76, 0.0), (0.24, 0.15, 0.24), FAISCA["hip"].x, FAISCA["hip"].y, 0.08)


def faisca_shoulders(p):
    y = FAISCA["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.25, y, 0.01, 0.095, 0.075, 0.075)
        mbox(p, "dark", T(drum.x, y + 0.11, 0.01), (0.05, 0.08, 0.08), 0.01, 1)
        m = T(drum.x + side * 0.01, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        sphere_panel(p, "shell", m, 0.15, (22, 88), (a0 - 25, a1 + 25), 0.028, (12, 5), gap=0.008)
        sphere_panel(p, "trim", m, 0.155, (8, 20), (a0 - 20, a1 + 20), 0.026, (12, 2), gap=0.006)
        la, lo = math.radians(52), math.radians(0 if side > 0 else 180)
        q = at(m, 0.152 * math.cos(la) * math.cos(lo), 0.152 * math.sin(la), 0.0)
        mbox(p, "glow", frame(q, q - at(m)), (0.012, 0.004, 0.06), 0.002, 1)
        mbox(p, "team", T(drum.x + side * 0.01, y + 0.172, 0.01), (0.06, 0.01, 0.09), 0.004, 1)
        upper_arm(p, side, pin, FAISCA["elbow_l"] if side < 0 else FAISCA["elbow_r"], bone_r=0.034, elbow_w=0.07, elbow_r=0.045, armor_size=(0.1, 0.09))


def faisca_forearm_left(p):
    e, wr = FAISCA["elbow_l"], FAISCA["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.065, 0.065, 0.075), 0.012, 1)
    capsule(p, "dark", sub(m, 0, length * 0.55, 0), 0.075, length * 0.8, 18)
    for lo in ((-80, 80), (100, 260)):
        cyl_panel(p, "shell", sub(m, 0, length * 0.5, 0), 0.1, length * 0.6, lo, 0.03, (10, 2), gap=0.012, radius_top=0.088)
    for v in (0.2, 0.8):
        mring(p, "trim", sub(m, 0, length * v, 0), 0.1 - 0.012 * v, 0.012, 20, 5)
    mbox(p, "glow", sub(m, 0, length * 0.5, 0.1), (0.05, 0.01, 0.01), 0.003, 1)
    connector(p, sub(m, 0.1, length * 0.45, 0.0, rot=(0, 0, -90)), 0.013)
    wrist(p, m, length)
    hand(p, sub(m, 0, length + 0.14, 0.0, rot=(0, -90, 180)), fingers=3, scale=1.3, curl=1.0)


def faisca_forearm_right(p):
    e, muzzle = FAISCA["elbow_r"], FAISCA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    # Alojamento dos condensadores: cápsula com uma cinta de aletas de arrefecimento a meio.
    capsule(p, "shell", sub(m, 0, 0.16, 0), 0.1, 0.18, 18)
    capsule(p, "shell", sub(m, 0, 0.39, 0), 0.095, 0.14, 18)
    mtube(p, "dark", sub(m, 0, 0.28, 0), 0.075, 0.12, 16)
    for i in range(5):
        mtube(p, "metal", sub(m, 0, 0.235 + i * 0.022, 0), 0.105, 0.008, 22)
    for i in range(3):
        mbox(p, "glow", sub(m, -0.03 + i * 0.03, 0.16, 0.098), (0.018, 0.04, 0.008), 0.003, 1)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.085, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.07, 6, size=0.009)


def faisca_gun(p):
    """Emissor-bobina: uma pequena bobina de Tesla deitada, com o toro na boca e o elétrodo
    de luz no centro; recua com o disparo."""
    e, muzzle = FAISCA["elbow_r"], FAISCA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.52, 0), 0.055, 0.08, 16)
    mtube(p, "trim", sub(m, 0, 0.72, 0), 0.04, 0.34, 16, bevel=0.005)
    for i in range(9):
        mring(p, "metal", sub(m, 0, 0.58 + i * 0.032, 0), 0.043, 0.004, 14, 4)
    mring(p, "metal", sub(m, 0, length - 0.04, 0), 0.07, 0.03, 26, 10)
    ball(p, "glow", at(m, 0, length - 0.03, 0), 0.028, 12)


def claw_foot(p, m, out, ankle, toe_len=0.12, tip_len=0.07, spread=30, width=0.07, armor="shell", trim="trim"):
    """Pé de ave largo: bloco da sola debaixo do tornozelo, três dedos grossos à frente e um
    esporão atrás; cada dedo com almofada de borracha, falanges escuras com pinos nas juntas,
    cobertura pintada e unha de metal."""
    mbox(p, "rubber", sub(m, 0, 0.012, 0.0), (0.15, 0.024, 0.15), 0.012)
    mbox(p, "dark", sub(m, 0, 0.042, 0.0), (0.16, 0.04, 0.16), 0.02)
    for a, length, tip in ((-spread, toe_len, tip_len), (0, toe_len * 1.1, tip_len), (spread, toe_len, tip_len), (180, toe_len * 0.55, tip_len * 0.8)):
        toe = sub(m, 0, 0, 0, rot=(0, a, 0))
        across = at(toe, 1, 0, 0) - at(toe)
        z0 = -0.07
        mtube(p, "metal", axis_frame(at(toe, 0, 0.04, z0), across), 0.016, width + 0.012, 10)
        seg = sub(toe, 0, 0.034, z0 - length / 2)
        mbox(p, "dark", seg, (width, 0.034, length), 0.01)
        mbox(p, "rubber", sub(seg, 0, -0.024, 0), (width * 0.92, 0.016, length * 0.9), 0.007)
        mbox(p, armor if a != 180 else trim, sub(seg, 0, 0.026, 0.004), (width + 0.008, 0.022, length * 0.82), 0.011)
        z1 = z0 - length
        mtube(p, "metal", axis_frame(at(toe, 0, 0.034, z1), across), 0.013, width * 0.9, 10)
        tipm = sub(toe, 0, 0.028, z1 - tip / 2)
        mbox(p, "dark", tipm, (width * 0.8, 0.03, tip), 0.009)
        mbox(p, "rubber", sub(tipm, 0, -0.019, 0), (width * 0.74, 0.012, tip * 0.85), 0.005)
        lathe(p, "metal", frame(at(tipm, 0, 0.0, -tip / 2), at(toe, 0, -0.35, -1) - at(toe)), [(0.0, -0.005), (width * 0.3, 0.0), (width * 0.22, 0.02), (0.0, 0.05)], 10)


def faisca_leg(p, out):
    bird_leg(p, out, FAISCA["hip"].y, knee=(-0.2, -0.12), heel=(-0.44, 0.12), ankle_up=0.11, foot_fn=claw_foot, k=1.0)


# ======================================================================================
def define(part):
    part("salvo2_head")(salvo_head)
    part("salvo2_torso")(salvo_torso)
    part("salvo2_shoulders")(salvo_shoulders)

    @part("salvo2_arm")
    def _(p):
        salvo_forearm_left(p)
        salvo_forearm_right(p)

    part("salvo2_gun")(salvo_gun)

    @part("salvo2_leg_l")
    def _(p):
        salvo_leg(p, -1)

    @part("salvo2_leg_r")
    def _(p):
        salvo_leg(p, 1)

    part("bigorna2_head")(bigorna_head)
    part("bigorna2_torso")(bigorna_torso)
    part("bigorna2_shoulders")(bigorna_shoulders)

    @part("bigorna2_arm")
    def _(p):
        bigorna_forearm_left(p)
        bigorna_forearm_right(p)

    part("bigorna2_gun")(bigorna_gun)

    @part("bigorna2_leg_l")
    def _(p):
        bigorna_leg(p, -1)

    @part("bigorna2_leg_r")
    def _(p):
        bigorna_leg(p, 1)

    part("batida2_head")(batida_head)
    part("batida2_torso")(batida_torso)
    part("batida2_shoulders")(batida_shoulders)

    @part("batida2_arm")
    def _(p):
        batida_forearm_left(p)
        batida_forearm_right(p)

    part("batida2_gun")(batida_gun)

    @part("batida2_leg_l")
    def _(p):
        batida_leg(p, -1)

    @part("batida2_leg_r")
    def _(p):
        batida_leg(p, 1)

    part("rosca2_head")(rosca_head)
    part("rosca2_torso")(rosca_torso)
    part("rosca2_shoulders")(rosca_shoulders)

    @part("rosca2_arm")
    def _(p):
        rosca_forearm_left(p)
        rosca_forearm_right(p)

    part("rosca2_gun")(rosca_gun)

    @part("rosca2_leg_l")
    def _(p):
        rosca_leg(p, -1)

    @part("rosca2_leg_r")
    def _(p):
        rosca_leg(p, 1)

    part("broto2_head")(broto_head)
    part("broto2_torso")(broto_torso)
    part("broto2_shoulders")(broto_shoulders)

    @part("broto2_arm")
    def _(p):
        broto_forearm_left(p)
        broto_forearm_right(p)

    part("broto2_gun")(broto_gun)

    @part("broto2_leg_l")
    def _(p):
        broto_leg(p, -1)

    @part("broto2_leg_r")
    def _(p):
        broto_leg(p, 1)

    part("gancho2_head")(gancho_head)
    part("gancho2_torso")(gancho_torso)
    part("gancho2_shoulders")(gancho_shoulders)

    @part("gancho2_arm")
    def _(p):
        gancho_forearm_left(p)
        gancho_forearm_right(p)

    part("gancho2_gun")(gancho_gun)

    @part("gancho2_leg_l")
    def _(p):
        gancho_leg(p, -1)

    @part("gancho2_leg_r")
    def _(p):
        gancho_leg(p, 1)

    part("faisca2_head")(faisca_head)
    part("faisca2_torso")(faisca_torso)
    part("faisca2_shoulders")(faisca_shoulders)

    @part("faisca2_arm")
    def _(p):
        faisca_forearm_left(p)
        faisca_forearm_right(p)

    part("faisca2_gun")(faisca_gun)

    @part("faisca2_leg_l")
    def _(p):
        faisca_leg(p, -1)

    @part("faisca2_leg_r")
    def _(p):
        faisca_leg(p, 1)
