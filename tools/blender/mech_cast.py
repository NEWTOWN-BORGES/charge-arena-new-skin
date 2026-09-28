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


def salvo_torso(p, with_neck=True):
    c = S_CHEST
    R, L = 0.3, 0.62
    if with_neck:
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


def bigorna_torso(p, with_neck=True):
    c = B_CHEST
    if with_neck:
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


def batida_torso(p, with_neck=True):
    c = BA_CHEST
    ex, ey, ez = BA_EGG
    if with_neck:
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


def rosca_torso(p, with_neck=True):
    c = R_CHEST
    R, H = 0.26, 0.48
    if with_neck:
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


def broto_torso(p, with_neck=True):
    c = BR_CHEST
    H, rb, rt = 0.46, 0.21, 0.28
    if with_neck:
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


def gancho_torso(p, with_neck=True):
    c = G_CHEST
    ex, ey, ez = G_CASK
    top_y = ey * math.sin(math.radians(G_CASK_LAT))
    rim_r = ex * math.cos(math.radians(G_CASK_LAT))
    if with_neck:
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


def faisca_torso(p, with_neck=True):
    c = F_CHEST
    top, bottom = F_TORSO[-1][0], F_TORSO[0][0]
    if with_neck:
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
# ÓRBITA: astrónoma. Tronco em planeta com um anel orbital inclinado preso em dois pilares,
# cabeça em cúpula de observatório com a fenda aberta e uma parabólica, asas de painéis
# solares nos ombros, espingarda-telescópio e pés com propulsores.
# ======================================================================================
ORBITA = {
    "hip": Vector((0.2, 0.66, 0.0)),
    "shoulder_y": 1.28,
    "elbow_l": Vector((-0.48, 1.0, 0.02)),
    "wrist_l": Vector((-0.51, 0.73, -0.1)),
    "elbow_r": Vector((0.48, 1.0, -0.02)),
    "muzzle": Vector((0.44, 0.84, -1.04)),
}
O_CHEST = Vector((0.0, 1.13, 0.02))
O_PLANET = 0.25
O_HEAD = Vector((0.0, 1.72, 0.0))
O_HEAD_R = 0.18
O_SCREEN = (0.2, 0.11)


def orbita_head(p):
    c = O_HEAD
    r = O_HEAD_R
    mk.HEADS["orbita2_head"] = {"top": round(c.y + r + 0.03, 3), "center": round(c.y, 3), "aspect": round(O_SCREEN[0] / O_SCREEN[1], 3)}
    base = T(*c)
    ball(p, "dark", c, r - 0.03, 20)
    # Cúpula de observatório: dois gomos que abrem pela fenda de cima, base em tambor.
    sphere_panel(p, "shell", base, r, (0, 86), (-80, 70), 0.03, (12, 6), gap=0.01)
    sphere_panel(p, "shell", base, r, (0, 86), (110, 260), 0.03, (12, 6), gap=0.01)
    for side in (-1, 1):
        meridian_arc(p, "trim", c, r + 0.004, 90 + side * 20, 0, 84, 0.01)
    mtube(p, "dark", T(c.x, c.y + r * 0.72, c.z + 0.03), 0.03, 0.06, 12)
    cyl_panel(p, "trim", sub(base, 0, -0.07, 0), r, 0.13, (-45, 225), 0.03, (18, 2), gap=0.008)
    sphere_panel(p, "shell", base, r, (-70, -44), (-180, 180), 0.03, (18, 3), gap=0.0)
    screen_well(p, (c.x, c.y - 0.055, c.z - r + 0.012), O_SCREEN, 0.05, 0.03)
    # Parabólica na têmpora esquerda: braço, prato e alimentador.
    arm = Vector((-r - 0.01, c.y + 0.05, c.z + 0.02))
    mtube(p, "metal", axis_frame(arm, "-x"), 0.03, 0.03, 14)
    rod(p, "metal", arm + Vector((-0.015, 0, 0)), arm + Vector((-0.07, 0.07, 0.0)), 0.009, 8)
    dish = frame(arm + Vector((-0.08, 0.09, -0.01)), (-0.5, 0.6, -0.62))
    lathe(p, "trim", dish, [(0.0, 0.0), (0.05, 0.005), (0.09, 0.02), (0.1, 0.03), (0.095, 0.034), (0.05, 0.01), (0.0, 0.004)], 22)
    rod(p, "metal", at(dish, 0, 0.01, 0), at(dish, 0, 0.08, 0), 0.005, 6)
    ball(p, "glow", at(dish, 0, 0.085, 0), 0.012, 8)
    mbox(p, "glow", T(r - 0.01, c.y + 0.03, c.z - 0.06), (0.012, 0.02, 0.03), 0.004, 1)
    serial(p, plane((0.0, c.y - 0.07, c.z + r + 0.002), (0, 0, 1), (1, 0, 0)), "09", 0.032)
    mbox(p, "team", T(0, c.y + r * 0.6, c.z - r * 0.8), (0.1, 0.012, 0.03), 0.004, 1)


def orbita_torso(p, with_neck=True):
    c = O_CHEST
    R = O_PLANET
    if with_neck:
        neck(p, c.y + R * 0.9, O_HEAD.y - O_HEAD_R + 0.02, 0.065, 0.02, plate=(0.2, 0.18))
    base = T(*c)
    ball(p, "dark", c, R - 0.035, 22)
    # Planeta em gomos com faixas de latitude; o núcleo é um anel de luz na frente.
    for lat, lons in (((20, 64), ((-150, -100), (-80, -30), (-20, 60), (70, 150), (160, 200))),
                      ((-40, 16), ((-150, -104), (-76, -30), (-20, 60), (70, 150), (160, 200)))):
        for lo in lons:
            sphere_panel(p, "shell", base, R, lat, lo, 0.034, (8, 6), gap=0.01)
    sphere_panel(p, "trim", base, R, (66, 80), (-180, 180), 0.03, (24, 2), gap=0.0)
    sphere_panel(p, "trim", base, R, (-62, -42), (-180, 180), 0.03, (24, 2), gap=0.0)
    core_round(p, axis_frame((0, c.y - 0.02, c.z - R + 0.012), "-z"), 0.045)
    q, n = ell_point(c, (R, R, R), 28, -55)
    serial(p, plane(q, n, (math.sin(math.radians(-55)), 0, -math.cos(math.radians(-55)))), "09", 0.028)
    q, n = ell_point(c, (R, R, R), -10, 180)
    charging_port(p, plane(q, n, (0, 0, 1)), 0.042, 0.026)
    # Mochila de propulsão atrás: tanque em cápsula, bocal e aviso.
    pack = T(0, c.y + 0.02, c.z + R + 0.05)
    capsule(p, "trim", sub(pack, rot=(0, 0, 90)), 0.07, 0.3, 16)
    for side in (-1, 1):
        lathe(p, "dark", sub(pack, side * 0.08, -0.08, 0.0), [(0.03, 0.0), (0.045, -0.05), (0.04, -0.06), (0.02, -0.01)], 14)
        mtube(p, "glow", sub(pack, side * 0.08, -0.13, 0.0), 0.03, 0.004, 12)
    mbox(p, "dark", T(0, c.y + 0.02, c.z + R + 0.0), (0.08, 0.08, 0.06), 0.01)
    warning(p, plane((0.0, c.y + 0.05, c.z + R + 0.121), (0, 0, 1), (1, 0, 0)), 0.035)
    waist(p, 0.76, c.y - R * 0.86, 0.12)
    pelvis(p, (0, 0.68, 0.0), (0.26, 0.16, 0.25), ORBITA["hip"].x, ORBITA["hip"].y, 0.085)


def orbita_spin(p):
    """Anel orbital inclinado preso ao planeta por dois pilares com rolamentos: gira em jogo."""
    c = O_CHEST
    R = O_PLANET
    base = T(*c)
    tilt = sub(base, 0, -0.03, 0, rot=(14, 0, -8))
    arc_tube(p, "trim", tilt, R + 0.075, 0.02, -180, 180, 48, 8)
    arc_tube(p, "metal", tilt, R + 0.075, 0.006, -180, 180, 48, 6)
    for lon in (35, 215):
        a = math.radians(lon)
        out = at(tilt, math.cos(a) * (R + 0.075), 0, math.sin(a) * (R + 0.075))
        inner = at(tilt, math.cos(a) * (R - 0.02), 0, math.sin(a) * (R - 0.02))
        rod(p, "dark", inner, out, 0.02, 10)
        mtube(p, "metal", frame(out, out - inner), 0.032, 0.03, 14)


def orbita_shoulders(p):
    y = ORBITA["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.24, y, 0.01, 0.095, 0.075, 0.075)
        mbox(p, "dark", T(drum.x, y + 0.1, 0.01), (0.05, 0.06, 0.08), 0.01, 1)
        m = T(drum.x + side * 0.01, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        sphere_panel(p, "shell", m, 0.14, (24, 88), (a0 - 20, a1 + 20), 0.028, (12, 5), gap=0.008)
        # Asa de painéis solares: longarina, três painéis em leque e dobradiça.
        root = at(m, side * 0.05, 0.1, 0.06)
        mtube(p, "metal", axis_frame(root, "z"), 0.02, 0.05, 10)
        for i, ang in enumerate((25, 45, 65)):
            wing = sub(T(*root), rot=(0, 0, -side * ang))
            wing = sub(wing, rot=(-18, 0, 0))
            rod(p, "dark", at(wing, 0, 0.0, 0.03), at(wing, 0, 0.2 - i * 0.02, 0.06), 0.008, 6)
            mbox(p, "trim", sub(wing, 0, 0.11 - i * 0.01, 0.05), (0.06, 0.17 - i * 0.02, 0.008), 0.004, 1)
            mbox(p, "glow", sub(wing, 0, 0.11 - i * 0.01, 0.055), (0.05, 0.15 - i * 0.02, 0.002), 0.0, 1)
        mbox(p, "team", T(drum.x + side * 0.01, y + 0.16, 0.01), (0.06, 0.01, 0.08), 0.004, 1)
        upper_arm(p, side, pin, ORBITA["elbow_l"] if side < 0 else ORBITA["elbow_r"], bone_r=0.035, elbow_w=0.072, elbow_r=0.046, armor_size=(0.11, 0.1))


def orbita_forearm_left(p):
    e, wr = ORBITA["elbow_l"], ORBITA["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    capsule(p, "dark", sub(m, 0, length * 0.55, 0), 0.08, length * 0.8, 18)
    for lo in ((-75, 75), (105, 255)):
        cyl_panel(p, "shell", sub(m, 0, length * 0.5, 0), 0.106, length * 0.62, lo, 0.03, (10, 2), gap=0.012, radius_top=0.094)
    mring(p, "trim", sub(m, 0, length * 0.85, 0), 0.095, 0.014, 20, 5)
    mbox(p, "glow", sub(m, 0, length * 0.5, 0.106), (0.04, 0.012, 0.01), 0.003, 1)
    connector(p, sub(m, 0.106, length * 0.45, 0.0, rot=(0, 0, -90)), 0.014)
    wrist(p, m, length)
    hand(p, sub(m, 0, length + 0.14, 0.0, rot=(0, -90, 180)), fingers=4, scale=1.3, curl=0.9)


def orbita_forearm_right(p):
    e, muzzle = ORBITA["elbow_r"], ORBITA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    capsule(p, "shell", sub(m, 0, 0.26, 0), 0.1, 0.38, 18)
    for v in (0.12, 0.4):
        mring(p, "trim", sub(m, 0, v, 0), 0.102, 0.014, 22, 5)
    # Luneta de pontaria em cima, com a objetiva virada para a frente.
    scope = sub(m, 0, 0.3, 0.13)
    mbox(p, "dark", sub(m, 0, 0.3, 0.1), (0.03, 0.08, 0.04), 0.008, 1)
    mtube(p, "metal", scope, 0.025, 0.16, 14)
    mtube(p, "glow", sub(scope, 0, 0.081, 0), 0.018, 0.004, 12)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.09, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.075, 6, size=0.009)


def orbita_gun(p):
    """Espingarda-telescópio: tubo em troços que abrem, anéis de focagem e objetiva de luz."""
    e, muzzle = ORBITA["elbow_r"], ORBITA["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.53, 0), 0.06, 0.1, 16)
    lathe(p, "trim", m, [(0.05, 0.56), (0.052, 0.72), (0.06, 0.73), (0.062, 0.86), (0.072, 0.87), (0.075, length - 0.03), (0.08, length)], 20)
    for v in (0.7, 0.85, length - 0.06):
        mring(p, "metal", sub(m, 0, v, 0), 0.066 if v < 0.8 else 0.078, 0.01, 18, 5)
    mtube(p, "glow", sub(m, 0, length - 0.01, 0), 0.06, 0.006, 18)


def thruster_foot(p, m, out, ankle, length=0.4, width=0.25, armor="shell"):
    """Pé de propulsão: sola em casco arredondado sobre almofadas de borracha, dois bocais
    por baixo com anel de luz e tampa do calcanhar."""
    mbox(p, "dark", sub(m, 0, 0.07, -0.03), (width - 0.05, 0.05, length - 0.04), 0.02)
    for z in (-length / 2 + 0.07, length / 2 - 0.09):
        for side in (-1, 1):
            mbox(p, "rubber", sub(m, side * (width / 2 - 0.05), 0.018, -0.03 + z), (0.07, 0.036, 0.08), 0.014)
    for z in (-0.1, 0.06):
        lathe(p, "metal", sub(m, 0, 0.05, -0.03 + z), [(0.035, 0.0), (0.05, -0.03), (0.046, -0.034), (0.03, -0.004)], 16)
        mtube(p, "glow", sub(m, 0, 0.018, -0.03 + z), 0.036, 0.004, 14)
    dome(p, armor, sub(m, 0, 0.09, -0.04) @ Matrix.Diagonal((1.0, 1.0, 1.55, 1.0)), 0.12, 0.07, 22, 6)
    mbox(p, "trim", sub(m, 0, 0.1, length / 2 - 0.06), (width * 0.6, 0.07, 0.06), 0.02)


def orbita_leg(p, out):
    def thrusters(q, m, o, ankle):
        thruster_foot(q, m, o, ankle)
    leg(p, out, ORBITA["hip"].y, knee_y=-0.23, ankle_up=0.24, width=0.95, knee_w=0.11, knee_r=0.06, foot_fn=thrusters,
        thigh_fn=round_thigh(k=0.95), shin_fn=round_shin(k=0.95, r_bottom=0.09, r_top=0.115), thigh_top=0.03, guard=False,
        shin_top=-0.18)


# ======================================================================================
# ECLIPSE: guarda de elite. Alto e sombrio: elmo alto com visor em crescente, chifres curvos
# em pinos, halo de eclipse numa haste às costas, ombros com espigões, núcleo de sol negro,
# garra à esquerda, lança de anel à direita e pernas de ave com esporões.
# ======================================================================================
ECLIPSE = {
    "hip": Vector((0.19, 0.74, 0.0)),
    "shoulder_y": 1.34,
    "elbow_l": Vector((-0.5, 1.06, 0.02)),
    "wrist_l": Vector((-0.53, 0.78, -0.1)),
    "elbow_r": Vector((0.5, 1.06, -0.02)),
    "muzzle": Vector((0.44, 0.92, -1.12)),
}
E_CHEST = Vector((0.0, 1.2, 0.02))
E_TORSO = [(-0.24, 0.11), (-0.18, 0.16), (-0.08, 0.2), (0.04, 0.235), (0.13, 0.245), (0.19, 0.22), (0.23, 0.14)]
E_HEAD = Vector((0.0, 1.8, 0.0))
E_HEAD_RADII = (0.15, 0.19, 0.16)
E_SCREEN = (0.19, 0.08)


def eclipse_head(p):
    c = E_HEAD
    ex, ey, ez = E_HEAD_RADII
    mk.HEADS["eclipse2_head"] = {"top": round(c.y + ey + 0.03, 3), "center": round(c.y, 3), "aspect": round(E_SCREEN[0] / E_SCREEN[1], 3)}
    hs = scaled(c, ex, ey, ez)
    lathe(p, "dark", scaled(c, ex - 0.03, ey - 0.03, ez - 0.03), [(0.0, -1.0)] + [(math.sin(math.radians(a)), -math.cos(math.radians(a))) for a in range(15, 180, 15)] + [(0.0, 1.0)], 22)
    # Elmo alto: crista, faces, nuca e queixo, com a fenda do visor em crescente à frente.
    sphere_panel(p, "shell", hs, 1.0, (26, 88), (-88, 88), 0.2, (10, 6), gap=0.05)
    sphere_panel(p, "shell", hs, 1.0, (26, 88), (92, 268), 0.2, (10, 6), gap=0.05)
    sphere_panel(p, "shell", hs, 1.0, (-60, 24), (-26, 206), 0.2, (16, 6), gap=0.05)
    sphere_panel(p, "trim", hs, 1.0, (-66, -20), (-150, -30), 0.2, (10, 4), gap=0.05)
    p.screen((c.x, c.y + 0.0, c.z - ez + 0.035), E_SCREEN, bulge=0.012)
    for dy in (-1, 1):
        mbox(p, "metal", T(c.x, c.y + dy * 0.047, c.z - ez + 0.032), (0.19, 0.012, 0.014), 0.004, 1)
    # Chifres curvos em pinos com rolamento, a subir para trás.
    for side in (-1, 1):
        pivot = Vector((side * (ex - 0.01), c.y + 0.08, c.z + 0.01))
        mtube(p, "metal", axis_frame(pivot, "x" if side > 0 else "-x"), 0.035, 0.03, 16)
        bolts(p, sub(axis_frame(pivot, "x" if side > 0 else "-x"), 0, 0.016, 0), 0.024, 4, size=0.006)
        # Chifre liso e comprido: sobe e abre para fora, recua e volta a apontar em frente,
        # com um colar de metal na base e a ponta em brasa.
        mring(p, "metal", axis_frame(pivot + Vector((side * 0.03, 0, 0)), "x"), 0.04, 0.012, 16, 5)
        prev = None
        steps = 14
        for i in range(steps + 1):
            t = i / steps
            q = pivot + Vector((side * (0.03 + 0.15 * math.sin(t * 1.4)), 0.38 * math.sin(t * 1.35), 0.11 * math.sin(t * 2.6) - 0.09 * t))
            r = 0.044 * (1.0 - t) + 0.007
            ball(p, "trim", q, r, 12)
            if prev is not None:
                rod(p, "trim", prev, q, r, 12)
            prev = q
        ball(p, "glow", prev, 0.013, 8)
    # Sobrancelha em V sobre o visor: duas lâminas que descem para o centro (cara de poucos
    # amigos), aparafusadas à testa.
    for side in (-1, 1):
        brow = sub(T(side * 0.058, c.y + 0.072, c.z - ez + 0.018), rot=(-12, 0, side * 20))
        mbox(p, "trim", brow, (0.12, 0.03, 0.034), 0.01)
        screw(p, sub(brow, side * 0.035, 0.0, -0.018, rot=(-90, 0, 0)), 0, 0, 0.006)
    mbox(p, "glow", T(0, c.y + 0.12, c.z - ez + 0.02), (0.02, 0.05, 0.01), 0.004, 1)
    serial(p, plane((0.0, c.y - 0.02, c.z + ez * 1.0 + 0.004), (0, 0, 1), (1, 0, 0)), "10", 0.032)
    mbox(p, "team", T(0, c.y + ey - 0.004, c.z), (0.03, 0.012, 0.12), 0.004, 1)


def eclipse_torso(p, with_neck=True):
    c = E_CHEST
    top, bottom = E_TORSO[-1][0], E_TORSO[0][0]
    if with_neck:
        neck(p, c.y + top - 0.005, E_HEAD.y - E_HEAD_RADII[1] + 0.02, 0.064, 0.0, plate=(0.2, 0.18))
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, 0.82, 1.0))
    lathe(p, "dark", flat, [(0.0, bottom)] + [(r - 0.035, y) for y, r in E_TORSO] + [(0.0, top)], 26)
    for lo, yr in (((-150, -102), (-0.22, 0.2)), ((-78, -30), (-0.22, 0.2)), ((-26, 26), (-0.22, -0.01)),
                   ((154, 206), (-0.22, -0.01)), ((30, 84), (-0.22, 0.2)), ((96, 150), (-0.22, 0.2))):
        rev_panel(p, "shell", flat, E_TORSO, yr, lo, 0.034, (8, 8), gap=0.012)
    for lo in ((-150, -102), (-78, -30)):
        rev_panel(p, "trim", flat, [(y, r + 0.006) for y, r in E_TORSO], (-0.22, -0.16), lo, 0.02, (8, 2), gap=0.012)
    # Frisos de luz vermelha nas juntas da frente, a descer do peito.
    for lon in (-106, -74):
        for y in (0.12, 0.0, -0.12):
            q, n = rev_point(c, E_TORSO, 0.82, lon, y, 0.0)
            mbox(p, "glow", frame(q, n), (0.012, 0.01, 0.07), 0.003, 1)
    # Núcleo de sol negro: disco escuro com a coroa de luz à volta, recuado na fenda.
    core = axis_frame((0, c.y + 0.06, c.z - 0.235 * 0.82 + 0.012), "-z")
    mring(p, "metal", sub(core, 0, -0.004, 0), 0.07, 0.014, 26, 6)
    mring(p, "glow", sub(core, 0, -0.012, 0), 0.056, 0.01, 26, 5)
    mtube(p, "dark", sub(core, 0, -0.012, 0), 0.05, 0.02, 22)
    mtube(p, "dark", sub(core, 0, -0.04, 0), 0.08, 0.05, 22)
    bolts(p, sub(core, 0, 0.004, 0), 0.07, 6, size=0.008)
    q, n = rev_point(c, E_TORSO, 0.82, -52, 0.12)
    serial(p, plane(q, n, (math.sin(math.radians(-52)), 0, -math.cos(math.radians(-52)))), "10", 0.028)
    q, n = rev_point(c, E_TORSO, 0.82, 180, -0.1)
    charging_port(p, plane(q, n, (0, 0, 1)), 0.042, 0.026)
    # Halo de eclipse: haste pela fenda de trás, disco escuro com anel vermelho e coroa.
    mbox(p, "dark", T(0, c.y + 0.12, 0.25), (0.06, 0.07, 0.14), 0.012)
    rod(p, "dark", (0, c.y + 0.12, 0.3), (0, E_HEAD.y + 0.02, 0.32), 0.022, 12)
    halo = axis_frame((0, E_HEAD.y + 0.1, 0.34), "z")
    mtube(p, "dark", halo, 0.19, 0.02, 32)
    mring(p, "trim", halo, 0.205, 0.018, 40, 8)
    mring(p, "glow", sub(halo, 0, -0.012, 0), 0.228, 0.008, 40, 5)
    # Coroa de espinhos à volta do eclipse, alternando compridos e curtos.
    for i in range(14):
        a = math.radians(i * 360 / 14 + 90)
        d = at(halo, math.cos(a), 0, math.sin(a)) - at(halo)
        base = at(halo, 0.23 * math.cos(a), 0, 0.23 * math.sin(a))
        lathe(p, "trim" if i % 2 else "dark", frame(base, d), [(0.0, 0.0), (0.024, 0.0), (0.0, 0.16 if i % 2 == 0 else 0.09)], 6)
    bolts(p, sub(halo, 0, -0.012, 0), 0.05, 4, size=0.01)
    warning(p, plane((0.0, E_HEAD.y - 0.08, 0.331), (0, 0, 1), (1, 0, 0)), 0.04)
    waist(p, 0.84, c.y + bottom + 0.02, 0.115)
    pelvis(p, (0, 0.76, 0.0), (0.25, 0.15, 0.24), ECLIPSE["hip"].x, ECLIPSE["hip"].y, 0.08)


def eclipse_shoulders(p):
    y = ECLIPSE["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.27, y, 0.01, 0.1, 0.08, 0.08)
        mbox(p, "dark", T(drum.x, y + 0.11, 0.01), (0.05, 0.08, 0.08), 0.01, 1)
        m = T(drum.x + side * 0.012, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        sphere_panel(p, "shell", m, 0.17, (18, 88), (a0 - 25, a1 + 25), 0.03, (12, 6), gap=0.008)
        sphere_panel(p, "trim", m, 0.176, (4, 16), (a0 - 20, a1 + 20), 0.028, (12, 2), gap=0.006)
        # Espigões aparafusados: três cones a sair da ombreira em leque.
        for i, (la, lo) in enumerate(((62, 0), (40, -38), (40, 38), (22, -70), (22, 70))):
            lat, lon = math.radians(la), math.radians((0 if side > 0 else 180) + lo * side)
            d = Vector((math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)))
            q = at(m, *(d * 0.165))
            mtube(p, "dark", frame(q, d), 0.034, 0.02, 12)
            lathe(p, "metal", frame(q + d * 0.01, d), [(0.0, -0.01), (0.034, 0.0), (0.022, 0.07), (0.0, (0.2, 0.15, 0.15, 0.1, 0.1)[i])], 12)
        mbox(p, "team", T(drum.x - side * 0.05, y + 0.16, 0.01), (0.05, 0.01, 0.08), 0.004, 1)
        upper_arm(p, side, pin, ECLIPSE["elbow_l"] if side < 0 else ECLIPSE["elbow_r"], bone_r=0.036, elbow_w=0.072, elbow_r=0.046, armor_size=(0.11, 0.1))


def eclipse_forearm_left(p):
    e, wr = ECLIPSE["elbow_l"], ECLIPSE["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    lathe(p, "dark", sub(m, 0, 0.05, 0), [(0.07, 0.0), (0.105, 0.04), (0.11, length * 0.6), (0.085, length - 0.05)], 18, True, True)
    for lo in ((-70, 70), (90, 250)):
        cyl_panel(p, "shell", sub(m, 0, 0.05 + length * 0.42, 0), 0.124, length * 0.5, lo, 0.03, (8, 2), gap=0.012, radius_top=0.112)
    mring(p, "trim", sub(m, 0, length * 0.82, 0), 0.113, 0.014, 20, 5)
    connector(p, sub(m, 0.125, length * 0.45, 0.0, rot=(0, 0, -90)), 0.014)
    mbox(p, "glow", sub(m, 0, length * 0.5, 0.125), (0.04, 0.012, 0.01), 0.003, 1)
    wrist(p, m, length)
    claw(p, sub(m, 0, length + 0.13, 0.0, rot=(0, -90, 180)), scale=1.55, curl=1.2)


def eclipse_forearm_right(p):
    e, muzzle = ECLIPSE["elbow_r"], ECLIPSE["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    lathe(p, "shell", m, [(0.0, 0.07), (0.07, 0.08), (0.11, 0.13), (0.115, 0.3), (0.095, 0.43), (0.0, 0.44)], 22)
    for v in (0.16, 0.36):
        mring(p, "trim", sub(m, 0, v, 0), 0.113, 0.012, 22, 5)
    vents(p, sub(m, 0, 0.25, 0.112), 3, 0.05, depth=0.014, spacing=0.024, height=0.01)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.085, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.07, 6, size=0.009)


def eclipse_gun(p):
    """Lança de anel: haste comprida, anel de eclipse a meio e ponta em lâmina; recua."""
    e, muzzle = ECLIPSE["elbow_r"], ECLIPSE["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.52, 0), 0.055, 0.08, 16)
    rod(p, "dark", at(m, 0, 0.55, 0), at(m, 0, length - 0.12, 0), 0.03, 12)
    ring = sub(m, 0, length - 0.28, 0)
    mring(p, "trim", ring, 0.11, 0.02, 32, 8)
    mring(p, "glow", ring, 0.09, 0.008, 32, 5)
    for k in range(3):
        a = math.radians(90 + k * 120)
        rod(p, "dark", at(ring, 0, 0, 0), at(ring, 0.1 * math.cos(a), 0, 0.1 * math.sin(a)), 0.01, 6)
    lathe(p, "metal", sub(m, 0, length - 0.13, 0), [(0.0, 0.0), (0.045, 0.02), (0.035, 0.08), (0.0, 0.14)], 4)
    ball(p, "glow", at(m, 0, length - 0.1, 0), 0.02, 8)


def eclipse_leg(p, out):
    def talons(q, m, o, ankle):
        claw_foot(q, m, o, ankle, toe_len=0.11, tip_len=0.08, spread=28, width=0.066)
    bird_leg(p, out, ECLIPSE["hip"].y, knee=(-0.2, -0.13), heel=(-0.45, 0.13), ankle_up=0.11, foot_fn=talons, k=1.05)


# ======================================================================================
# HÉLIO: senhor do circuito. Alto e nobre: cabeça em ogiva com a coroa de raios num anel
# com rolamento, tronco em ânfora com o núcleo solar num disco de raios, asas de penas de
# latão nos ombros, cetro com um sol na ponta e pernas esguias.
# ======================================================================================
HELIO = {
    "hip": Vector((0.2, 0.7, 0.0)),
    "shoulder_y": 1.34,
    "elbow_l": Vector((-0.48, 1.06, 0.02)),
    "wrist_l": Vector((-0.51, 0.79, -0.1)),
    "elbow_r": Vector((0.48, 1.06, -0.02)),
    "muzzle": Vector((0.44, 0.92, -1.08)),
}
H_CHEST = Vector((0.0, 1.2, 0.02))
H_TORSO = [(-0.24, 0.12), (-0.18, 0.17), (-0.08, 0.215), (0.04, 0.24), (0.12, 0.235), (0.18, 0.2), (0.23, 0.13)]
H_HEAD = Vector((0.0, 1.8, 0.0))
H_HEAD_RADII = (0.16, 0.2, 0.16)
H_SCREEN = (0.16, 0.11)


def sun_disc(p, m, radius, rays=12, ray_len=0.08, core_role="glow"):
    """Sol: disco com moldura e raios em cunha à volta, no plano XZ local de `m`."""
    mtube(p, "dark", m, radius, 0.03, 26)
    mring(p, "metal", m, radius, radius * 0.16, 30, 6)
    mtube(p, core_role, sub(m, 0, 0.012, 0), radius * 0.72, 0.012, 24)
    for i in range(rays):
        a = i * 360.0 / rays
        ray = sub(m, 0, 0, 0, rot=(0, -a, 0))
        lathe(p, "trim" if i % 2 else "metal", sub(ray, radius * 1.05 + ray_len * 0.5, 0, 0, rot=(0, 0, -90)),
              [(0.0, -ray_len * 0.5), (radius * 0.14, -ray_len * 0.5), (0.0, ray_len * (0.5 if i % 2 else 0.9))], 4)


def helio_head(p):
    c = H_HEAD
    ex, ey, ez = H_HEAD_RADII
    mk.HEADS["helio2_head"] = {"top": round(c.y + ey + 0.1, 3), "center": round(c.y, 3), "aspect": round(H_SCREEN[0] / H_SCREEN[1], 3)}
    hs = scaled(c, ex, ey, ez)
    lathe(p, "dark", scaled(c, ex - 0.03, ey - 0.03, ez - 0.03), [(0.0, -1.0)] + [(math.sin(math.radians(a)), -math.cos(math.radians(a))) for a in range(15, 180, 15)] + [(0.0, 1.0)], 22)
    sphere_panel(p, "shell", hs, 1.0, (30, 88), (-180, 180), 0.2, (24, 6), gap=0.0)
    sphere_panel(p, "shell", hs, 1.0, (-62, 26), (-24, 204), 0.2, (16, 6), gap=0.05)
    sphere_panel(p, "trim", hs, 1.0, (-68, -26), (-150, -30), 0.2, (10, 4), gap=0.05)
    screen_well(p, (c.x, c.y + 0.0, c.z - ez + 0.02), H_SCREEN, 0.05, 0.03)
    mring(p, "dark", T(c.x, c.y + ey * 0.62 - 0.02, c.z), ex * 0.8 - 0.01, 0.01, 32, 4)
    for side in (-1, 1):
        mtube(p, "metal", axis_frame((side * (ex - 0.005), c.y + 0.0, c.z), "x" if side > 0 else "-x"), 0.03, 0.02, 14)
        mbox(p, "glow", T(side * (ex - 0.01), c.y - 0.05, c.z - 0.04), (0.01, 0.02, 0.03), 0.003, 1)
    serial(p, plane((0.0, c.y - 0.03, c.z + ez * 1.0 + 0.004), (0, 0, 1), (1, 0, 0)), "11", 0.03)
    mbox(p, "team", T(0, c.y + ey - 0.005, c.z + 0.02), (0.03, 0.012, 0.1), 0.004, 1)


def helio_spin(p):
    """Coroa de raios sobre o anel com rolamento da testa: gira em jogo."""
    c = H_HEAD
    ex, ey, ez = H_HEAD_RADII
    # Coroa de raios num anel com rolamento sobre a testa (a coroa gira no ultimate).
    ring_y = c.y + ey * 0.62
    rr = ex * 0.8
    mring(p, "metal", T(c.x, ring_y, c.z), rr, 0.016, 32, 6)
    for i in range(9):
        a = math.radians(-90 + (i - 4) * 26)
        base = Vector((c.x + math.cos(a) * rr, ring_y + 0.01, c.z + math.sin(a) * rr))
        d = Vector((math.cos(a) * 0.35, 1.0, math.sin(a) * 0.35)).normalized()
        h = 0.14 if i == 4 else 0.1 - abs(i - 4) * 0.008
        lathe(p, "trim", frame(base, d), [(0.0, 0.0), (0.024, 0.0), (0.012, h * 0.6), (0.0, h)], 5)
    ball(p, "glow", (c.x, ring_y + 0.02, c.z - rr - 0.02), 0.02, 10)


def helio_torso(p, with_neck=True):
    c = H_CHEST
    top, bottom = H_TORSO[-1][0], H_TORSO[0][0]
    if with_neck:
        neck(p, c.y + top - 0.005, H_HEAD.y - H_HEAD_RADII[1] + 0.02, 0.064, 0.0, plate=(0.2, 0.18))
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, 0.84, 1.0))
    lathe(p, "dark", flat, [(0.0, bottom)] + [(r - 0.035, y) for y, r in H_TORSO] + [(0.0, top)], 26)
    for lo, yr in (((-150, -110), (-0.22, 0.21)), ((-70, -30), (-0.22, 0.21)), ((-26, 26), (-0.22, -0.01)),
                   ((154, 206), (-0.22, -0.01)), ((30, 150), (-0.22, 0.21))):
        rev_panel(p, "shell", flat, H_TORSO, yr, lo, 0.034, (10, 8), gap=0.012)
    mring(p, "trim", sub(flat, 0, bottom + 0.03, 0), profile_radius(H_TORSO, bottom + 0.03) + 0.004, 0.016, 26, 5)
    mring(p, "trim", sub(flat, 0, top - 0.03, 0), profile_radius(H_TORSO, top - 0.03) + 0.004, 0.014, 26, 5)
    # Núcleo solar: um sol recuado na fenda larga do peito.
    sun_disc(p, axis_frame((0, c.y + 0.04, c.z - 0.24 * 0.84 + 0.01), "-z"), 0.065, 12, 0.045)
    q, n = rev_point(c, H_TORSO, 0.84, -50, 0.13)
    serial(p, plane(q, n, (math.sin(math.radians(-50)), 0, -math.cos(math.radians(-50)))), "11", 0.028)
    q, n = rev_point(c, H_TORSO, 0.84, 180, -0.1)
    charging_port(p, plane(q, n, (0, 0, 1)), 0.042, 0.026)
    q, n = rev_point(c, H_TORSO, 0.84, 90, -0.12)
    warning(p, plane(q, n, (1, 0, 0)), 0.04)
    waist(p, 0.8, c.y + bottom + 0.02, 0.12)
    pelvis(p, (0, 0.72, 0.0), (0.26, 0.15, 0.25), HELIO["hip"].x, HELIO["hip"].y, 0.084)


def helio_shoulders(p):
    y = HELIO["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.26, y, 0.01, 0.1, 0.08, 0.08)
        mbox(p, "dark", T(drum.x, y + 0.1, 0.01), (0.05, 0.06, 0.08), 0.01, 1)
        m = T(drum.x + side * 0.012, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        sphere_panel(p, "shell", m, 0.15, (22, 88), (a0 - 25, a1 + 25), 0.028, (12, 5), gap=0.008)
        sphere_panel(p, "trim", m, 0.155, (8, 20), (a0 - 20, a1 + 20), 0.026, (12, 2), gap=0.006)
        mbox(p, "team", T(drum.x + side * 0.012, y + 0.172, 0.01), (0.06, 0.01, 0.09), 0.004, 1)
        upper_arm(p, side, pin, HELIO["elbow_l"] if side < 0 else HELIO["elbow_r"], bone_r=0.035, elbow_w=0.072, elbow_r=0.046, armor_size=(0.11, 0.1))


def helio_forearm_left(p):
    e, wr = HELIO["elbow_l"], HELIO["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    capsule(p, "dark", sub(m, 0, length * 0.55, 0), 0.08, length * 0.8, 18)
    for lo in ((-75, 75), (105, 255)):
        cyl_panel(p, "shell", sub(m, 0, length * 0.45, 0), 0.105, length * 0.55, lo, 0.03, (10, 2), gap=0.012, radius_top=0.1)
    cuff = sub(m, 0, length * 0.74, 0)
    lathe(p, "trim", cuff, [(0.09, 0.0), (0.108, 0.0), (0.13, 0.07), (0.125, 0.08), (0.075, 0.08), (0.09, 0.0)], 22)
    mbox(p, "glow", sub(m, 0, length * 0.45, 0.106), (0.04, 0.012, 0.01), 0.003, 1)
    connector(p, sub(m, 0.106, length * 0.4, 0.0, rot=(0, 0, -90)), 0.014)
    wrist(p, m, length)
    hand(p, sub(m, 0, length + 0.14, 0.0, rot=(0, -90, 180)), fingers=4, scale=1.3, curl=0.9)


def helio_forearm_right(p):
    e, muzzle = HELIO["elbow_r"], HELIO["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    lathe(p, "shell", m, [(0.0, 0.07), (0.07, 0.08), (0.105, 0.14), (0.112, 0.3), (0.1, 0.42), (0.0, 0.44)], 24)
    for v in (0.15, 0.37):
        mring(p, "trim", sub(m, 0, v, 0), 0.11, 0.013, 24, 5)
    for i in range(3):
        mbox(p, "glow", sub(m, -0.03 + i * 0.03, 0.26, 0.108), (0.016, 0.05, 0.008), 0.003, 1)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.085, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.07, 6, size=0.009)


def helio_gun(p):
    """Cetro solar: haste de latão com anéis e um sol de raios na ponta; recua."""
    e, muzzle = HELIO["elbow_r"], HELIO["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.52, 0), 0.055, 0.08, 16)
    lathe(p, "metal", m, [(0.035, 0.56), (0.03, 0.7), (0.034, length - 0.2), (0.05, length - 0.14)], 16)
    for v in (0.62, 0.78):
        mring(p, "trim", sub(m, 0, v, 0), 0.04, 0.012, 16, 5)
    sun = frame(at(m, 0, length - 0.07, 0), at(m, 0, 1, 0) - at(m), front=at(m, 0, 0, 1) - at(m))
    sun_disc(p, sun, 0.06, 10, 0.05)
    ball(p, "glow", at(m, 0, length - 0.05, 0), 0.04, 14)


def helio_leg(p, out):
    def sandals(q, m, o, ankle):
        foot(q, m, length=0.42, width=0.25, out=o, toes=2, armor="shell", heel="trim")
    leg(p, out, HELIO["hip"].y, knee_y=-0.27, ankle_up=0.17, width=0.92, knee_w=0.108, knee_r=0.058, foot_fn=sandals,
        thigh_fn=round_thigh(k=0.92), shin_fn=round_shin(k=0.92, r_bottom=0.085, r_top=0.112), thigh_top=0.03, guard=False,
        shin_top=-0.22)


# ======================================================================================
# MAGNUS: o campeão. O maior de todos: elmo largo com crista e coroa de louros, peito enorme
# com a estrela do Penta numa moldura, ombreiras em lamelas com debrum de ouro, capa real de
# placas numa verga, manopla imperial no braço direito e pernas pesadas.
# ======================================================================================
MAGNUS = {
    "hip": Vector((0.24, 0.64, 0.0)),
    "shoulder_y": 1.26,
    "elbow_l": Vector((-0.58, 0.98, 0.02)),
    "wrist_l": Vector((-0.62, 0.68, -0.12)),
    "elbow_r": Vector((0.58, 0.98, -0.02)),
    "muzzle": Vector((0.52, 0.8, -1.02)),
}
M_CHEST = Vector((0.0, 1.14, 0.02))
M_TORSO = [(-0.24, 0.16), (-0.18, 0.22), (-0.08, 0.27), (0.04, 0.3), (0.12, 0.305), (0.19, 0.27), (0.24, 0.17)]
M_HEAD = Vector((0.0, 1.7, -0.01))
M_HEAD_RADII = (0.2, 0.16, 0.17)
M_SCREEN = (0.24, 0.11)


def star_points(r_out, r_in, n=5):
    return [((r_out if i % 2 == 0 else r_in) * math.sin(math.pi * i / n), (r_out if i % 2 == 0 else r_in) * math.cos(math.pi * i / n)) for i in range(2 * n)]


def laurel(p, center, radius, side, leaves=7, role="metal"):
    """Ramo de louros num arco atrás da cabeça: haste e folhas em amêndoa."""
    c = Vector(center)
    prev = None
    for i in range(leaves):
        a = math.radians(-20 + i * (150 / (leaves - 1)))
        q = c + Vector((side * radius * math.cos(math.radians(90) - a) , radius * 0.25 * math.sin(a * 1.2), radius * math.sin(math.radians(90) - a) * 0.9))
        if prev is not None:
            rod(p, role, prev, q, 0.007, 6)
        d = (q - c).normalized()
        leaf(p, role, frame(q, (d + Vector((0, 0.8, 0))).normalized(), front=d), 0.07, 0.04, vein="dark")
        prev = q


def magnus_head(p):
    c = M_HEAD
    ex, ey, ez = M_HEAD_RADII
    mk.HEADS["magnus2_head"] = {"top": round(c.y + ey + 0.1, 3), "center": round(c.y, 3), "aspect": round(M_SCREEN[0] / M_SCREEN[1], 3)}
    hs = scaled(c, ex, ey, ez)
    lathe(p, "dark", scaled(c, ex - 0.03, ey - 0.03, ez - 0.03), [(0.0, -1.0)] + [(math.sin(math.radians(a)), -math.cos(math.radians(a))) for a in range(15, 180, 15)] + [(0.0, 1.0)], 22)
    sphere_panel(p, "shell", hs, 1.0, (24, 88), (-88, 88), 0.2, (10, 6), gap=0.05)
    sphere_panel(p, "shell", hs, 1.0, (24, 88), (92, 268), 0.2, (10, 6), gap=0.05)
    sphere_panel(p, "shell", hs, 1.0, (-60, 22), (-28, 208), 0.2, (18, 6), gap=0.05)
    sphere_panel(p, "trim", hs, 1.0, (-66, -26), (-150, -30), 0.2, (10, 4), gap=0.05)
    screen_well(p, (c.x, c.y - 0.01, c.z - ez + 0.02), M_SCREEN, 0.05, 0.03)
    # Crista em leque sobre a costura do elmo.
    crest = [(-0.1, 0.0), (0.1, 0.0), (0.08, 0.05), (0.02, 0.1), (-0.06, 0.09), (-0.1, 0.04)]
    extruded(p, "trim", sub(T(0, c.y + ey - 0.01, c.z + 0.01), rot=(0, 90, 0)), crest, 0.024)
    mbox(p, "dark", T(0, c.y + ey - 0.005, c.z + 0.01), (0.04, 0.02, 0.2), 0.006, 1)
    # Coroa de louros presa às fontes por cubos com parafusos.
    for side in (-1, 1):
        hub = axis_frame((side * (ex - 0.01), c.y + 0.03, c.z + 0.02), "x" if side > 0 else "-x")
        mtube(p, "metal", hub, 0.036, 0.03, 16)
        bolts(p, sub(hub, 0, 0.016, 0), 0.024, 4, size=0.006)
    for side in (-1, 1):
        mbox(p, "glow", T(side * 0.13, c.y + 0.08, c.z - ez * 0.8), (0.03, 0.012, 0.01), 0.003, 1)
    serial(p, plane((0.0, c.y - 0.04, c.z + ez + 0.004), (0, 0, 1), (1, 0, 0)), "12", 0.032)
    mbox(p, "team", T(0, c.y + ey * 0.55, c.z - ez * 0.84), (0.1, 0.012, 0.03), 0.004, 1)


def magnus_spin(p):
    """Coroa de louros à volta do elmo, presa aos cubos das fontes: gira em jogo."""
    c = M_HEAD
    ex = M_HEAD_RADII[0]
    for side in (-1, 1):
        laurel(p, (0, c.y + 0.03, 0.0), ex + 0.03, side)


def magnus_torso(p, with_neck=True):
    c = M_CHEST
    top, bottom = M_TORSO[-1][0], M_TORSO[0][0]
    if with_neck:
        neck(p, c.y + top - 0.005, M_HEAD.y - M_HEAD_RADII[1] + 0.02, 0.075, 0.0, plate=(0.24, 0.22))
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, 0.82, 1.0))
    lathe(p, "dark", flat, [(0.0, bottom)] + [(r - 0.035, y) for y, r in M_TORSO] + [(0.0, top)], 28)
    for lo, yr in (((-150, -106), (-0.22, 0.22)), ((-74, -30), (-0.22, 0.22)), ((-24, 24), (-0.22, 0.0)),
                   ((156, 204), (-0.22, 0.0)), ((30, 86), (-0.22, 0.22)), ((94, 150), (-0.22, 0.22))):
        rev_panel(p, "shell", flat, M_TORSO, yr, lo, 0.036, (10, 8), gap=0.012)
    for yy in (bottom + 0.03, top - 0.035):
        mring(p, "trim", sub(flat, 0, yy, 0), profile_radius(M_TORSO, yy) + 0.004, 0.018, 30, 6)
    # A estrela do Penta: moldura redonda de ouro, fundo escuro e estrela com luz.
    core = axis_frame((0, c.y + 0.05, c.z - 0.3 * 0.82 + 0.01), "-z")
    mring(p, "trim", sub(core, 0, -0.004, 0), 0.095, 0.018, 32, 6)
    mtube(p, "dark", sub(core, 0, -0.03, 0), 0.09, 0.05, 28)
    extruded(p, "glow", sub(core, 0, -0.004, 0, rot=(-90, 0, 0)), star_points(0.07, 0.03), 0.014)
    bolts(p, sub(core, 0, 0.006, 0), 0.095, 8, size=0.009)
    q, n = rev_point(c, M_TORSO, 0.82, -52, 0.14)
    serial(p, plane(q, n, (math.sin(math.radians(-52)), 0, -math.cos(math.radians(-52)))), "12", 0.03)
    q, n = rev_point(c, M_TORSO, 0.82, 180, -0.1)
    charging_port(p, plane(q, n, (0, 0, 1)), 0.045, 0.028)
    # Capa real: verga de ouro às costas por três suportes, quatro placas largas e a correia.
    cy, cr = c.y + 0.16, 0.36
    for lon in (50, 90, 130):
        a = math.radians(lon)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        mbox(p, "dark", frame(Vector((0.0, cy, c.z)) + d * 0.3, d), (0.05, 0.12, 0.05), 0.01)
    arc_tube(p, "metal", T(0.0, cy, c.z), cr, 0.02, 38, 142, 26, 8)
    for lon in (38, 142):
        a = math.radians(lon)
        ball(p, "metal", (cr * math.cos(a), cy, c.z + cr * math.sin(a)), 0.03, 12)
    topy = cy - 0.035
    for lo, bottom_y in (((44, 68), 0.5), ((70, 89), 0.46), ((91, 110), 0.46), ((112, 136), 0.5)):
        h = topy - bottom_y
        origin = (0.0, (topy + bottom_y) / 2, c.z)
        cyl_panel(p, "shell", T(*origin), cr + 0.1, h, lo, 0.024, (6, 6), gap=0.0, radius_top=cr + 0.004)
        cyl_panel(p, "trim", T(0.0, bottom_y + 0.03, c.z), cr + 0.1 - 0.1 * 0.03 / h + 0.006, 0.05, lo, 0.012, (6, 1), gap=0.0, radius_top=cr + 0.1 - 0.1 * 0.08 / h + 0.006)
        a = math.radians((lo[0] + lo[1]) / 2)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        eye = Vector((0.0, cy, c.z)) + d * cr
        mring(p, "dark", frame(eye, Vector((-d.z, 0.0, d.x))), 0.03, 0.008, 14, 4)
    warning(p, cone_mark((0.0, (topy + 0.46) / 2, c.z), cr + 0.1, cr + 0.004, topy - 0.46, 80, 0.0, 0.002), 0.045)
    waist(p, 0.76, c.y + bottom + 0.02, 0.15)
    pelvis(p, (0, 0.67, 0.0), (0.32, 0.17, 0.28), MAGNUS["hip"].x, MAGNUS["hip"].y, 0.1)


def magnus_shoulders(p):
    y = MAGNUS["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.33, y, 0.01, 0.11, 0.09, 0.09)
        mbox(p, "dark", T(drum.x, y + 0.14, 0.01), (0.07, 0.12, 0.1), 0.012, 1)
        m = T(drum.x + side * 0.015, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        for i, (lat, rad, role) in enumerate((((56, 88), 0.22, "shell"), ((32, 60), 0.212, "shell"), ((8, 36), 0.204, "shell"))):
            sphere_panel(p, role, m, rad, lat, (a0 - 18 - i * 7, a1 + 18 + i * 7), 0.03, (14, 3), gap=0.004)
            sphere_panel(p, "trim", m, rad + 0.004, (lat[0], lat[0] + 5), (a0 - 18 - i * 7, a1 + 18 + i * 7), 0.012, (14, 1), gap=0.004)
            for end in (a0 - 14 - i * 7, a1 + 14 + i * 7):
                la, lo = math.radians((lat[0] + lat[1]) / 2), math.radians(end)
                q = at(m, rad * math.cos(la) * math.cos(lo), rad * math.sin(la), rad * math.cos(la) * math.sin(lo))
                screw(p, frame(q, q - at(m)), 0.0, 0.0, 0.01)
        mbox(p, "team", T(drum.x + side * 0.015, y + 0.238, 0.01), (0.08, 0.01, 0.12), 0.004, 1)
        upper_arm(p, side, pin, MAGNUS["elbow_l"] if side < 0 else MAGNUS["elbow_r"], bone_r=0.045, elbow_w=0.085, elbow_r=0.055, armor_size=(0.14, 0.12))


def magnus_forearm_left(p):
    e, wr = MAGNUS["elbow_l"], MAGNUS["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.08, 0.08, 0.09), 0.012, 1)
    lathe(p, "dark", sub(m, 0, 0.05, 0), [(0.08, 0.0), (0.12, 0.04), (0.125, length * 0.6), (0.095, length - 0.05)], 20, True, True)
    for lo in ((-70, 70), (90, 250)):
        cyl_panel(p, "shell", sub(m, 0, 0.05 + length * 0.36, 0), 0.14, length * 0.46, lo, 0.03, (8, 2), gap=0.012, radius_top=0.13)
    cuff = sub(m, 0, length * 0.62, 0)
    span = length - length * 0.62 + 0.005
    lathe(p, "trim", cuff, [(0.118, 0.0), (0.142, 0.0), (0.168, span - 0.016), (0.162, span), (0.095, span), (0.118, 0.0)], 24)
    connector(p, sub(m, 0.14, length * 0.4, 0.0, rot=(0, 0, -90)), 0.015)
    mbox(p, "glow", sub(m, 0, length * 0.42, 0.14), (0.05, 0.012, 0.01), 0.003, 1)
    wrist(p, m, length, plate=(0.12, 0.1))
    hand(p, sub(m, 0, length + 0.16, 0.0, rot=(0, -90, 180)), fingers=4, scale=1.6, curl=1.0)


def magnus_forearm_right(p):
    e, muzzle = MAGNUS["elbow_r"], MAGNUS["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.08, 0.09, 0.09), 0.012, 1)
    lathe(p, "shell", m, [(0.0, 0.07), (0.08, 0.08), (0.14, 0.14), (0.15, 0.3), (0.135, 0.42), (0.0, 0.44)], 26)
    for v in (0.16, 0.38):
        mring(p, "trim", sub(m, 0, v, 0), 0.148, 0.016, 26, 6)
    vents(p, sub(m, 0, 0.27, 0.15), 4, 0.06, depth=0.014, spacing=0.024, height=0.01)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.11, 0.03, 22, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.092, 8, size=0.01)


def magnus_gun(p):
    """Manopla imperial: um punho blindado de ouro com quatro nós e o cano no meio; recua."""
    e, muzzle = MAGNUS["elbow_r"], MAGNUS["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.53, 0), 0.08, 0.1, 18)
    mtube(p, "metal", sub(m, 0, (0.58 + length - 0.26) / 2, 0), 0.055, length - 0.84, 18)
    for v in (0.66, length - 0.34):
        mring(p, "trim", sub(m, 0, v, 0), 0.06, 0.014, 20, 5)
    fist = sub(m, 0, length - 0.16, 0)
    mbox(p, "shell", fist, (0.26, 0.24, 0.22), 0.07)
    mbox(p, "trim", sub(fist, 0, -0.1, 0), (0.28, 0.05, 0.24), 0.02)
    for k in range(4):
        u = -0.09 + k * 0.06
        mbox(p, "metal", sub(fist, u, 0.12, 0.05), (0.052, 0.06, 0.07), 0.022)
        mbox(p, "metal", sub(fist, u, 0.12, -0.04), (0.052, 0.05, 0.06), 0.02)
    mtube(p, "dark", sub(m, 0, length - 0.01, 0), 0.05, 0.05, 18)
    mring(p, "trim", sub(m, 0, length + 0.01, 0), 0.055, 0.012, 20, 5)
    mtube(p, "glow", sub(m, 0, length + 0.012, 0), 0.036, 0.006, 16)


def magnus_leg(p, out):
    def boots(q, m, o, ankle):
        foot(q, m, length=0.5, width=0.32, out=o, toes=3, armor="shell", heel="trim")
    leg(p, out, MAGNUS["hip"].y, knee_y=-0.22, ankle_up=0.2, width=1.3, knee_w=0.14, knee_r=0.072, foot_fn=boots,
        thigh_fn=round_thigh(k=1.3), shin_fn=boot_shin(k=1.25, r_bottom=0.1, r_top=0.125, cuff=0.16), thigh_top=0.03, guard=False,
        shin_top=-0.16)



# ======================================================================================
# Cascos: tronco e cabeça numa só peça, sem pescoço (a cabeça não roda: o corpo todo olha).
# Sem ecrã de rosto: rasgos para os olhos, um só olho, ou nenhum.
# ======================================================================================
BH_TOP = 1.34          # topo do chassis da BIGORNA
BH_SLIT = (0.3, 0.06)  # rasgo dos olhos


def bigorna_hull(p):
    """BIGORNA blindada: um bloco de tanque assente no peito, pala com faixa de perigo por cima
    de um rasgo escuro onde brilham os olhos, faces laterais com faróis, pirilampo no topo."""
    bigorna_torso(p, with_neck=False)
    c = B_CHEST
    y = BH_TOP + 0.11
    mk.HEADS["bigorna3_hull"] = {"top": round(y + 0.2, 3), "center": round(y, 3), "aspect": round(BH_SLIT[0] / BH_SLIT[1], 3)}
    # Estrutura escura e a carapaça: dorso e topo numa placa só, que desce para as costas.
    mbox(p, "dark", T(0, y - 0.02, c.z + 0.01), (0.4, 0.24, 0.36), 0.06)
    mbox(p, "shell", T(0, y + 0.05, c.z + 0.05), (0.44, 0.16, 0.36), 0.07)
    mbox(p, "shell", T(0, y - 0.06, c.z + 0.16), (0.42, 0.14, 0.14), 0.05)
    # Pala por cima dos olhos, com a faixa de perigo na testa.
    brow = T(0, y + 0.03, c.z - 0.18)
    mbox(p, "trim", brow, (0.44, 0.08, 0.14), 0.03)
    hazard_band(p, plane(at(brow, 0, 0, -0.071), (0, 0, -1), (-1, 0, 0)), 0.38, 0.03, 8)
    # O rasgo: poço escuro com o vidro dos olhos, sem aro.
    screen_well(p, (0, y - 0.045, c.z - 0.225), BH_SLIT, 0.06, 0.02, ring=False)
    # Queixo e faces: a pala fecha-se em baixo e dos lados; faróis nas faces.
    mbox(p, "shell", T(0, y - 0.115, c.z - 0.16), (0.42, 0.07, 0.16), 0.03)
    for side in (-1, 1):
        mbox(p, "trim", T(side * 0.205, y - 0.045, c.z - 0.16), (0.05, 0.19, 0.17), 0.02)
        lamp = axis_frame((side * 0.205, y - 0.05, c.z - 0.25), "-z")
        mtube(p, "metal", lamp, 0.022, 0.02, 14)
        mtube(p, "glow", sub(lamp, 0, 0.011, 0), 0.015, 0.004, 12)
        vents(p, sub(T(side * 0.222, y + 0.02, c.z + 0.06), rot=(0, 90 * side, 0)), 3, 0.1, depth=0.01, spacing=0.03)
    # Pirilampo de obra no topo, sobre a faixa da equipa.
    top = y + 0.13
    mbox(p, "team", T(0, top + 0.001, c.z + 0.12), (0.06, 0.012, 0.14), 0.004, 1)
    mtube(p, "dark", T(0, top + 0.01, c.z - 0.02), 0.07, 0.04, 18, bevel=0.008)
    dome(p, "glow", T(0, top + 0.03, c.z - 0.02), 0.052, 0.07, 16, 5)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        rod(p, "metal", (math.cos(a) * 0.058, top + 0.03, c.z - 0.02 + math.sin(a) * 0.058),
            (math.cos(a) * 0.03, top + 0.11, c.z - 0.02 + math.sin(a) * 0.03), 0.006, 6)
    mring(p, "metal", T(0, top + 0.11, c.z - 0.02), 0.032, 0.007, 12, 4)


SH_Y = 1.53  # centro do bloco da cabeça fundida do SALVO


def salvo_hull(p):
    """SALVO sem rosto: uma caixa de cantos redondos encaixada no tambor do peito, com a marca
    da unidade pintada onde estaria a cara, um sensor pequeno e a pega de transporte."""
    salvo_torso(p, with_neck=False)
    c = S_CHEST
    y = SH_Y
    mk.HEADS["salvo3_hull"] = {"top": round(y + 0.15, 3), "center": round(y, 3), "aspect": 1.0}
    box = T(0, y, c.z - 0.03)
    mbox(p, "dark", sub(box, 0, -0.06, 0.03), (0.4, 0.2, 0.34), 0.06)
    mbox(p, "shell", box, (0.44, 0.28, 0.4), 0.1, 3)
    # A placa da cara, lisa, com a marca em losango e duas riscas: nada de olhos.
    face = sub(box, 0, 0.0, -0.2)
    mbox(p, "trim", face, (0.3, 0.19, 0.02), 0.012, 1)
    mark = sub(face, 0, 0.01, -0.012)
    for k in range(4):
        a = k * 90 + 45
        d = (math.cos(math.radians(a)), math.sin(math.radians(a)))
        mbox(p, "team", sub(mark, d[0] * 0.03, d[1] * 0.03, 0, rot=(0, 0, a + 90)), (0.05, 0.014, 0.006), 0.003, 1)
    for u in (-1, 1):
        mbox(p, "dark", sub(face, u * 0.11, -0.06, -0.012), (0.04, 0.008, 0.006), 0.002, 1)
    # Um só sensor, pequeno, no canto: a máquina vê sem precisar de cara.
    cam = axis_frame(at(box, 0.13, 0.09, -0.205), "-z")
    mtube(p, "dark", cam, 0.02, 0.02, 12)
    mtube(p, "glow", sub(cam, 0, 0.011, 0), 0.008, 0.004, 8)
    # Protetores laterais em cúpula e a pega no topo.
    for side in (-1, 1):
        cap = axis_frame((side * 0.22, y - 0.01, c.z - 0.02), "x" if side > 0 else "-x")
        mtube(p, "dark", cap, 0.1, 0.03, 20)
        dome(p, "trim", sub(cap, 0, 0.012, 0), 0.09, 0.05, 20, 5)
        bolts(p, sub(cap, 0, 0.016, 0), 0.094, 6, size=0.008)
        mbox(p, "dark", T(side * 0.14, y + 0.17, c.z), (0.04, 0.07, 0.05), 0.012)
    rod(p, "metal", (-0.16, y + 0.21, c.z), (0.16, y + 0.21, c.z), 0.018, 12)
    mtube(p, "rubber", axis_frame((0, y + 0.21, c.z), "x"), 0.024, 0.14, 12)
    mbox(p, "team", T(0, y + 0.141, c.z + 0.08), (0.24, 0.01, 0.06), 0.004, 1)
    serial(p, plane((0.1, y - 0.02, c.z + 0.171), (0, 0, 1), (1, 0, 0)), "02", 0.04)
    inspection_label(p, plane((-0.12, y + 0.03, c.z + 0.172), (0, 0, 1), (1, 0, 0)), 0.08, 0.045)


GH_C = Vector((0.0, 1.31, 0.0))  # centro da cúpula do GANCHO
GH_R = 0.25
GH_EYE = (0.12, 0.12)


def gancho_hull(p, peak=True, name="gancho3_hull"):
    """GANCHO de um olho só: a pipa do tronco fecha-se numa cúpula de chapa com uma vigia
    redonda à frente, onde está o olho; a luneta presa ao lado direito. `peak=False`: sem o
    bico de trás (o GANCHO NEGRO usa um tricórnio por cima)."""
    gancho_torso(p, with_neck=False)
    c = GH_C
    r = GH_R
    eye_y = c.y + 0.1
    eye_z = -math.sqrt(r * r - 0.1 * 0.1) + 0.012
    mk.HEADS[name] = {"top": round(c.y + r + 0.04, 3), "center": round(eye_y, 3), "aspect": 1.0}
    base = T(*c)
    ball(p, "dark", c, r - 0.03, 22)
    # A cúpula em gomos, aberta à frente para a vigia do olho.
    for lo in ((-60, 20), (24, 96), (100, 176), (180, 238)):
        sphere_panel(p, "trim", base, r, (4, 86), lo, 0.03, (8, 6), gap=0.008)
    sphere_panel(p, "trim", base, r, (50, 86), (-124, -56), 0.03, (6, 3), gap=0.008)
    sphere_panel(p, "trim", base, r, (4, 8), (-124, -56), 0.03, (6, 2), gap=0.004)
    arc_tube(p, "rubber", sub(base, 0, r * math.sin(math.radians(6)), 0), r * math.cos(math.radians(6)) + 0.004, 0.009, -150, -30, 18, 6)
    # O olho: vigia funda com aro de metal aparafusado e o vidro redondo.
    eye = axis_frame((0, eye_y, eye_z), "-z")
    mtube(p, "dark", sub(eye, 0, -0.03, 0), 0.085, 0.07, 24, caps=False)
    mring(p, "metal", sub(eye, 0, 0.008, 0), 0.082, 0.014, 28, 6)
    bolts(p, sub(eye, 0, 0.018, 0), 0.082, 6, size=0.007, phase=0.3)
    screen_well(p, (0, eye_y, eye_z + 0.012), GH_EYE, 0.04, 0.012, ring=False)
    # Bico atrás com luz de estado, cubos de articulação e a luneta à direita.
    tip = Vector((0.0, math.cos(math.radians(40)), math.sin(math.radians(40))))
    if peak:
        top = frame(c + Vector((0, r * math.sin(math.radians(68)), r * math.cos(math.radians(68)))), tip)
        lathe(p, "trim", top, [(0.0, -0.04), (0.075, -0.04), (0.062, 0.02), (0.036, 0.07), (0.014, 0.098), (0.0, 0.104)], 18)
        ball(p, "glow", at(top, 0, 0.1, 0), 0.013, 10)
    for side in (-1, 1):
        hub = axis_frame((side * (r - 0.004), c.y + 0.06, c.z), "x" if side > 0 else "-x")
        mtube(p, "metal", hub, 0.045, 0.024, 18, bevel=0.004)
        bolts(p, sub(hub, 0, 0.013, 0), 0.032, 4, size=0.006)
    mbox(p, "dark", T(r + 0.03, c.y + 0.06, c.z - 0.055), (0.05, 0.036, 0.1), 0.008, 1)
    scope = axis_frame((r + 0.052, c.y + 0.07, c.z - 0.13), "-z")
    mtube(p, "metal", scope, 0.03, 0.15, 16, bevel=0.004)
    mring(p, "dark", sub(scope, 0, -0.03, 0), 0.031, 0.006, 16, 4)
    mtube(p, "metal", sub(scope, 0, 0.1, 0), 0.024, 0.06, 14)
    mtube(p, "dark", sub(scope, 0, 0.14, 0), 0.029, 0.024, 16)
    mtube(p, "glow", sub(scope, 0, 0.153, 0), 0.02, 0.004, 12)
    sphere_panel(p, "team", base, r + 0.004, (60, 80), (-97, -83), 0.008, (2, 4), gap=0.0)


class Sunk:
    """Uma peça modelada noutro sítio, descida: a cabeça que perde o pescoço e se enterra no
    tronco. Encaminha a geometria para a peça real, deslocada."""

    def __init__(self, p, drop):
        self.p = p
        self.move = Matrix.Translation((0.0, -drop, 0.0))

    def add(self, role, bm, matrix):
        self.p.add(role, bm, self.move @ matrix)

    def __getattr__(self, name):
        # Os métodos da peça (screen, box...) chamam self.add: ligados a este objeto, descem.
        return getattr(type(self.p), name).__get__(self)


def sunk_hull(p, torso, head, head_name, hull_name, drop):
    """Tronco sem pescoço com a cabeça enterrada nele: uma só peça, o rosto no tronco."""
    torso(p, with_neck=False)
    head(Sunk(p, drop))
    shape = mk.HEADS[head_name]
    mk.HEADS[hull_name] = {"top": round(shape["top"] - drop, 3), "center": round(shape["center"] - drop, 3), "aspect": shape["aspect"]}


def rosca_hull(p):
    sunk_hull(p, rosca_torso, rosca_head, "rosca2_head", "rosca3_hull", 0.19)



# --------------------------------------------------------------------------------------
# BATIDA sem pescoço: um ovo só, alto, com o rosto-equalizador na frente e os auscultadores
# pousados no topo do ovo como protetores, orelhas de gato no arco.
# --------------------------------------------------------------------------------------
BH_C = Vector((0.0, 1.2, 0.02))
BH_EGG = (0.29, 0.42, 0.25)
BH_FACE_Y = 0.17
BH_SCREEN = (0.2, 0.18)


def batida_hull(p):
    c = BH_C
    ex, ey, ez = BH_EGG
    face_y = c.y + BH_FACE_Y
    mk.HEADS["batida3_hull"] = {"top": round(c.y + ey + 0.12, 3), "center": round(face_y, 3), "aspect": round(BH_SCREEN[0] / BH_SCREEN[1], 3)}
    inner = scaled(c, ex - 0.04, ey - 0.04, ez - 0.04)
    lathe(p, "dark", inner, [(0.0, -1.0)] + [(math.sin(math.radians(a)), -math.cos(math.radians(a))) for a in range(15, 180, 15)] + [(0.0, 1.0)], 24)
    egg = scaled(c, ex, ey, ez)
    # Gomos: coroa, a faixa do rosto (aberta à frente), a barriga em quatro, a cinta clara.
    sphere_panel(p, "shell", egg, 1.0, (58, 88), (-180, 180), 0.12, (24, 4), gap=0.02)
    for lo in ((-150, -118), (-62, -30), (-20, 60), (70, 200)):
        sphere_panel(p, "shell", egg, 1.0, (-4, 54), lo, 0.12, (8, 6), gap=0.03)
    for lo in ((-150, -95), (-85, -30), (-20, 60), (70, 200)):
        sphere_panel(p, "shell", egg, 1.0, (-52, -12), lo, 0.12, (8, 5), gap=0.03)
    sphere_panel(p, "trim", egg, 1.02, (-10, -5), (-180, 180), 0.1, (28, 1), gap=0.0)
    sphere_panel(p, "trim", egg, 1.02, (-70, -56), (-180, 180), 0.1, (24, 2), gap=0.0)
    # O rosto: moldura redonda grossa, anel de metal, poço aberto e o ecrã-equalizador.
    fz = c.z - ez * math.sqrt(1.0 - (BH_FACE_Y / ey) ** 2)
    face = axis_frame((0.0, face_y, fz + 0.02), "-z")
    mring(p, "trim", face, 0.15, 0.03, 32, 8)
    mring(p, "metal", sub(face, 0, -0.014, 0), 0.126, 0.009, 28, 5)
    mtube(p, "dark", sub(face, 0, -0.035, 0), 0.13, 0.05, 28, caps=False)
    p.screen((0.0, face_y, fz + 0.035), BH_SCREEN, bulge=0.012)
    # Bochechas: dois LEDs rosados por baixo do rosto.
    for side in (-1, 1):
        pos, n = egg_point(c, BH_EGG, side * 0.12, BH_FACE_Y - 0.13, True, 0.0)
        mtube(p, "glow", frame(pos, n), 0.02, 0.006, 12)
    # Auscultadores pousados no alto do ovo, inclinados para fora, e o arco por cima.
    for side in (-1, 1):
        a = math.radians(58)
        spot = Vector((side * ex * math.cos(a) * 1.02, c.y + ey * math.sin(a), c.z + 0.02))
        axis = Vector((side * 0.8, 0.6, 0.0)).normalized()
        cup = frame(spot, axis, front=(0, 0, -1))
        mring(p, "rubber", cup, 0.09, 0.026, 26, 8)
        lathe(p, "trim", sub(cup, 0, 0.018, 0), [(0.11, 0.0), (0.115, 0.025), (0.105, 0.06), (0.085, 0.075), (0.0, 0.077)], 26, True)
        mtube(p, "metal", sub(cup, 0, 0.085, 0), 0.058, 0.012, 22)
        bolts(p, sub(cup, 0, 0.09, 0), 0.045, 6, size=0.007)
        mring(p, "glow", sub(cup, 0, 0.065, 0), 0.1, 0.006, 26, 4)
    band = axis_frame((0.0, c.y + ey * 0.62, c.z + 0.02), "z")
    arc_tube(p, "shell", band, 0.3, 0.03, 12, 168, 30, 8)
    mbox(p, "team", T(0, c.y + ey * 0.62 + 0.332, c.z + 0.02), (0.12, 0.012, 0.05), 0.004, 1)
    # Orelhas de gato no arco.
    for side in (-1, 1):
        a = math.radians(90 - side * 34)
        root = Vector((math.cos(a) * 0.3, c.y + ey * 0.62 + math.sin(a) * 0.3, c.z + 0.02))
        ear = sub(T(*root), 0, 0.06, 0, rot=(0, 0, -side * 24))
        mbox(p, "shell", ear, (0.12, 0.15, 0.05), 0.02, 2, taper=(0.15, 0.5))
        mbox(p, "trim", sub(ear, 0, -0.01, -0.024), (0.07, 0.09, 0.01), 0.01, 1, taper=(0.15, 0.5))
    # Microfone de haste a sair do auscultador esquerdo até ao lado do rosto.
    rod(p, "metal", (-0.24, c.y + 0.33, c.z - 0.05), (-0.17, face_y - 0.1, fz - 0.03), 0.009, 8)
    ball(p, "rubber", (-0.165, face_y - 0.105, fz - 0.04), 0.026, 12)
    # Núcleo e ventilação na barriga, série de lado.
    core_round(p, axis_frame((0, c.y - 0.16, c.z - ez * 0.9), "-z"), 0.045)
    pos, n = egg_point(c, BH_EGG, 0.17, -0.02)
    serial(p, plane(pos, n, (-1, 0, 0)), "04", 0.03)
    # Gira-discos às costas.
    deck = axis_frame((0, c.y + 0.02, c.z + ez + 0.04), "z")
    lathe(p, "trim", deck, [(0.0, -0.04), (0.19, -0.04), (0.2, 0.0), (0.19, 0.03), (0.0, 0.03)], 28)
    mtube(p, "dark", sub(deck, 0, 0.04, 0), 0.16, 0.02, 28)
    mring(p, "shell", sub(deck, 0, 0.052, 0), 0.07, 0.01, 22, 4)
    mtube(p, "metal", sub(deck, 0, 0.055, 0), 0.02, 0.01, 12)
    rod(p, "metal", at(deck, 0.14, 0.06, 0.1), at(deck, 0.06, 0.06, 0.02), 0.007, 6)
    warning(p, plane(at(deck, -0.12, 0.031, 0.1), at(deck, 0, 1, 0) - at(deck), (1, 0, 0)), 0.04)
    pos, n = egg_side(c, BH_EGG, -1, -0.12, 0.03)
    charging_port(p, plane(pos, n, (0, 0, 1)), 0.045, 0.028)
    waist(p, 0.76, c.y - ey + 0.05, 0.12)
    pelvis(p, (0, 0.68, 0.0), (0.26, 0.16, 0.26), BATIDA["hip"].x, BATIDA["hip"].y, 0.085)


# --------------------------------------------------------------------------------------
# BROTO sem pescoço: um vaso que anda. O rosto está no próprio vaso, por baixo do aro;
# da terra nascem as duas folhas-orelha e o rebento com o botão de luz.
# --------------------------------------------------------------------------------------
PH_C = Vector((0.0, 1.16, 0.02))
PH_H, PH_RB, PH_RT = 0.66, 0.21, 0.31
PH_FACE_Y = 0.14
PH_SCREEN = (0.26, 0.14)


def pot_radius(y):
    """Raio do vaso a uma altura relativa ao centro."""
    return PH_RB + (PH_RT - PH_RB) * (y + PH_H / 2) / PH_H


def broto_hull(p):
    c = PH_C
    H, rb, rt = PH_H, PH_RB, PH_RT
    face_y = c.y + PH_FACE_Y
    top = c.y + H / 2
    mk.HEADS["broto3_hull"] = {"top": round(top + 0.3, 3), "center": round(face_y, 3), "aspect": round(PH_SCREEN[0] / PH_SCREEN[1], 3)}
    base = T(c.x, c.y, c.z)
    lathe(p, "dark", base, [(0.0, -H / 2), (rb - 0.03, -H / 2), (rt - 0.03, H / 2), (0.0, H / 2)], 28)
    # Barriga do vaso em gomos verdes; a faixa do rosto em creme, aberta à frente.
    lo_y0, lo_y1 = -H / 2 + 0.03, 0.0
    mid = (lo_y0 + lo_y1) / 2
    for lo in ((-155, -98), (-82, -25), (-15, 45), (55, 125), (135, 195)):
        cyl_panel(p, "shell", sub(base, 0, mid, 0), pot_radius(lo_y0), lo_y1 - lo_y0, lo, 0.035, (8, 2), gap=0.012, radius_top=pot_radius(lo_y1))
    mring(p, "trim", sub(base, 0, 0.012, 0), pot_radius(0.012) + 0.006, 0.014, 30, 5)
    up_y0, up_y1 = 0.03, H / 2 - 0.05
    mid = (up_y0 + up_y1) / 2
    for lo in ((-60, 60), (70, 180), (190, 238)):
        cyl_panel(p, "trim", sub(base, 0, mid, 0), pot_radius(up_y0), up_y1 - up_y0, lo, 0.035, (10, 2), gap=0.012, radius_top=pot_radius(up_y1))
    # O aro grosso do vaso, a terra e a planta.
    mring(p, "trim", sub(base, 0, H / 2 - 0.02, 0), rt + 0.02, 0.04, 34, 8)
    dome(p, "rubber", sub(base, 0, H / 2 - 0.03, 0), rt - 0.02, 0.05, 26, 4)
    # O rosto, cravado na faixa creme: poço, ecrã e duas bochechas verdes que o seguram.
    fz = c.z - pot_radius(PH_FACE_Y) + 0.012
    screen_well(p, (0.0, face_y, fz), PH_SCREEN, 0.05, 0.028)
    for side in (-1, 1):
        mbox(p, "shell", T(side * (PH_SCREEN[0] / 2 + 0.04), face_y, fz + 0.02), (0.05, 0.19, 0.06), 0.02)
    mbox(p, "shell", T(0, face_y + PH_SCREEN[1] / 2 + 0.035, fz + 0.022), (PH_SCREEN[0] + 0.12, 0.04, 0.06), 0.02)
    mbox(p, "shell", T(0, face_y - PH_SCREEN[1] / 2 - 0.03, fz + 0.022), (PH_SCREEN[0] + 0.12, 0.035, 0.06), 0.02)
    # As folhas-orelha nascem da terra, abertas para os lados, e o rebento ao meio.
    soil = top + 0.01
    for side in (-1, 1):
        stem = sub(T(side * 0.1, soil, c.z + 0.02), rot=(0, 0, -side * 48))
        rod(p, "trim", (side * 0.04, soil, c.z + 0.02), at(stem, 0, 0.02, 0), 0.012, 8)
        leaf(p, "shell", stem, 0.34, 0.22)
    rod(p, "trim", (0.0, soil, c.z), (0.02, soil + 0.2, c.z - 0.02), 0.011, 8)
    for side in (-1, 1):
        leaf(p, "shell", sub(T(0.012, soil + 0.12, c.z - 0.01), rot=(0, 0, -side * 55)), 0.1, 0.07)
    ball(p, "glow", (0.022, soil + 0.215, c.z - 0.02), 0.03, 12)
    # Sensores no aro, núcleo e série na barriga, regador às costas.
    cam = axis_frame((0.16, top - 0.03, c.z - rt + 0.0), "-z")
    mtube(p, "dark", cam, 0.018, 0.03, 12)
    mtube(p, "glow", sub(cam, 0, 0.016, 0), 0.007, 0.004, 8)
    core_round(p, axis_frame((0, c.y - 0.16, c.z - pot_radius(-0.16) + 0.004), "-z"), 0.045)
    serial(p, cone_mark((c.x, c.y + mid, c.z), pot_radius(up_y0), pot_radius(up_y1), up_y1 - up_y0, -30, -0.02), "06", 0.03)
    mbox(p, "team", T(0, top + 0.023, c.z + rt - 0.03), (0.1, 0.012, 0.05), 0.004, 1)
    can = axis_frame((0.0, c.y + 0.02, c.z + rt + 0.1), "y")
    mbox(p, "dark", T(0, c.y + 0.02, c.z + rt + 0.01), (0.16, 0.2, 0.05), 0.012)
    capsule(p, "trim", can, 0.09, 0.3, 20)
    for v in (-0.07, 0.07):
        mring(p, "dark", sub(can, 0, v, 0), 0.092, 0.01, 20, 4)
    rod(p, "metal", (0.06, c.y + 0.1, c.z + rt + 0.14), (0.2, c.y + 0.22, c.z + rt + 0.2), 0.014, 8)
    lathe(p, "metal", frame(Vector((0.2, c.y + 0.22, c.z + rt + 0.2)), Vector((0.6, 0.6, 0.3)).normalized()), [(0.0, 0.0), (0.03, 0.0), (0.045, 0.04), (0.0, 0.045)], 14)
    warning(p, plane((0.0, c.y + 0.02, c.z + rt + 0.19), (0, 0, 1), (1, 0, 0)), 0.045)
    charging_port(p, plane((-pot_radius(-0.06) - 0.004, c.y - 0.06, c.z + 0.05), (-1, 0, 0), (0, 0, 1)), 0.045, 0.028)
    waist(p, 0.74, c.y - H / 2 + 0.02, 0.12)
    pelvis(p, (0, 0.66, 0.0), (0.26, 0.16, 0.26), BROTO["hip"].x, BROTO["hip"].y, 0.085)


# ======================================================================================
# Propostas: os restantes sem pescoço. A cabeça cresce do próprio tronco, no mesmo contorno
# (um sólido de revolução que continua o perfil do peito para cima), com o rosto na frente.
# ======================================================================================
def dome_hull(p, c, depth, profile, window, face_y, screen, crown_role="shell", front_role="trim"):
    """Continua o tronco para cima num só casco: estrutura escura, coroa em duas metades,
    faces à volta e, à frente, a janela do rosto com o ecrã recuado. `window` =
    (lon0, lon1, y0, y1) relativo a `c`. Devolve o referencial achatado e a frente do ecrã."""
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, depth, 1.0))
    y_start, y_top = profile[0][0], profile[-1][0]
    lathe(p, "dark", flat, [(0.0, y_start)] + [(r - 0.035, y) for y, r in profile] + [(0.0, y_top)], 26)
    lon0, lon1, wy0, wy1 = window
    rev_panel(p, crown_role, flat, profile, (wy1, y_top), (-88, 88), 0.034, (10, 8), gap=0.012)
    rev_panel(p, crown_role, flat, profile, (wy1, y_top), (92, 268), 0.034, (10, 8), gap=0.012)
    rev_panel(p, "shell", flat, profile, (y_start, wy1), (lon1, lon0 + 360), 0.034, (16, 8), gap=0.012)
    rev_panel(p, front_role, flat, profile, (y_start, wy0), (lon0, lon1), 0.034, (8, 4), gap=0.012)
    front = c.z - profile_radius(profile, face_y) * depth
    # The glass sits just inside the shell, in front of the dark structure.
    screen_well(p, (c.x, c.y + face_y, front + 0.006), screen, 0.05, 0.01)
    return flat, front


EH_PROFILE = [(0.12, 0.245), (0.2, 0.24), (0.28, 0.22), (0.36, 0.18), (0.44, 0.12), (0.5, 0.06), (0.53, 0.0)]
EH_SCREEN = (0.21, 0.075)


def eclipse_hull(p):
    """ECLIPSE em grande elmo: a couraça sobe num elmo de cavaleiro com a fenda do visor sob
    a sobrancelha em V; os chifres nascem dos lados do casco e o halo fica atrás."""
    eclipse_torso(p, with_neck=False)
    c = E_CHEST
    face_y = 0.3
    mk.HEADS["eclipse3_hull"] = {"top": round(c.y + 0.56, 3), "center": round(c.y + face_y, 3), "aspect": round(EH_SCREEN[0] / EH_SCREEN[1], 3)}
    flat, front = dome_hull(p, c, 0.82, EH_PROFILE, (-126, -54, 0.26, 0.34), face_y, EH_SCREEN)
    for dy in (-1, 1):
        mbox(p, "metal", T(0, c.y + face_y + dy * 0.047, front + 0.012), (0.21, 0.012, 0.014), 0.004, 1)
    for side in (-1, 1):
        brow = sub(T(side * 0.062, c.y + face_y + 0.072, front + 0.004), rot=(-12, 0, side * 20))
        mbox(p, "trim", brow, (0.13, 0.032, 0.036), 0.01)
        screw(p, sub(brow, side * 0.038, 0.0, -0.019, rot=(-90, 0, 0)), 0, 0, 0.006)
    mbox(p, "glow", T(0, c.y + face_y + 0.13, front + 0.03), (0.022, 0.055, 0.01), 0.004, 1)
    # Crista do elmo: uma lâmina a correr do alto para trás.
    rev_panel(p, "trim", flat, [(y, r + 0.008) for y, r in EH_PROFILE], (0.3, 0.53), (86, 94), 0.03, (2, 8))
    for side in (-1, 1):
        r = profile_radius(EH_PROFILE, 0.36)
        pivot = Vector((side * (r - 0.01), c.y + 0.36, c.z + 0.01))
        mtube(p, "metal", axis_frame(pivot, "x" if side > 0 else "-x"), 0.04, 0.03, 16)
        bolts(p, sub(axis_frame(pivot, "x" if side > 0 else "-x"), 0, 0.016, 0), 0.028, 4, size=0.006)
        mring(p, "metal", axis_frame(pivot + Vector((side * 0.03, 0, 0)), "x"), 0.045, 0.013, 16, 5)
        prev = None
        steps = 14
        for i in range(steps + 1):
            t = i / steps
            q = pivot + Vector((side * (0.03 + 0.17 * math.sin(t * 1.4)), 0.42 * math.sin(t * 1.35), 0.12 * math.sin(t * 2.6) - 0.1 * t))
            rr = 0.05 * (1.0 - t) + 0.008
            ball(p, "trim", q, rr, 12)
            if prev is not None:
                rod(p, "trim", prev, q, rr, 12)
            prev = q
        ball(p, "glow", prev, 0.015, 8)


HH_PROFILE = [(0.12, 0.235), (0.2, 0.21), (0.27, 0.165), (0.33, 0.142), (0.39, 0.142), (0.44, 0.16), (0.47, 0.18), (0.49, 0.18)]
HH_SCREEN = (0.15, 0.1)


def helio_hull(p):
    """HÉLIO em ânfora: o tronco estreita num gargalo onde está o rosto e abre-se numa boca de
    onde nasce um sol, rodeado pela coroa de raios."""
    helio_torso(p, with_neck=False)
    c = H_CHEST
    face_y = 0.35
    mk.HEADS["helio3_hull"] = {"top": round(c.y + 0.75, 3), "center": round(c.y + face_y, 3), "aspect": round(HH_SCREEN[0] / HH_SCREEN[1], 3)}
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, 0.84, 1.0))
    y0, y1 = HH_PROFILE[0][0], HH_PROFILE[-1][0]
    lathe(p, "dark", flat, [(0.0, y0)] + [(r - 0.03, y) for y, r in HH_PROFILE] + [(0.0, y1 - 0.03)], 26)
    rev_panel(p, "shell", flat, HH_PROFILE, (y0, 0.29), (-180, 180), 0.03, (24, 6), gap=0.0)
    rev_panel(p, "shell", flat, HH_PROFILE, (0.29, 0.43), (-50, 230), 0.03, (16, 6), gap=0.012)
    rev_panel(p, "trim", flat, HH_PROFILE, (0.43, y1), (-180, 180), 0.03, (24, 3), gap=0.0)
    front = c.z - profile_radius(HH_PROFILE, face_y) * 0.84
    screen_well(p, (0, c.y + face_y, front + 0.006), HH_SCREEN, 0.05, 0.01)
    mring(p, "metal", sub(flat, 0, 0.29, 0), profile_radius(HH_PROFILE, 0.29) + 0.004, 0.012, 30, 5)
    mring(p, "trim", sub(flat, 0, y1, 0), 0.185, 0.022, 32, 8)
    # O sol a nascer da boca da ânfora; a coroa de raios à volta gira (helio_crown).
    ball(p, "glow", (0, c.y + y1 + 0.07, c.z), 0.11, 20)
    # Asas da ânfora: duas pegas curvas do gargalo ao bojo.
    for side in (-1, 1):
        pts = [Vector((side * 0.15, c.y + 0.42, c.z)), Vector((side * 0.27, c.y + 0.4, c.z)), Vector((side * 0.29, c.y + 0.3, c.z)), Vector((side * 0.22, c.y + 0.2, c.z))]
        for a, b in zip(pts, pts[1:]):
            rod(p, "trim", a, b, 0.018, 10)
            ball(p, "trim", b, 0.018, 10)
    for side in (-1, 1):
        mbox(p, "glow", T(side * 0.1, c.y + face_y - 0.075, front + 0.02), (0.02, 0.01, 0.01), 0.003, 1)


def helio_crown(p):
    """A coroa de raios na boca da ânfora do HÉLIO: gira em jogo à volta do sol."""
    c = H_CHEST
    y1 = HH_PROFILE[-1][0]
    mring(p, "metal", T(0, c.y + y1 + 0.02, 0.0), 0.15, 0.012, 30, 5)
    for i in range(12):
        a = math.radians(i * 30 + 15)
        base = Vector((math.cos(a) * 0.17, c.y + y1 + 0.01, math.sin(a) * 0.17))
        d = Vector((math.cos(a) * 0.5, 1.0, math.sin(a) * 0.5)).normalized()
        h = 0.16 if i % 2 == 0 else 0.1
        lathe(p, "trim" if i % 2 == 0 else "metal", frame(base, d), [(0.0, 0.0), (0.026, 0.0), (0.012, h * 0.6), (0.0, h)], 5)



FH_PROFILE = [(0.2, 0.2), (0.27, 0.205), (0.34, 0.2), (0.4, 0.175), (0.44, 0.145), (0.5, 0.125), (0.56, 0.1), (0.6, 0.07)]
FH_SCREEN = (0.22, 0.07)


def faisca_hull(p):
    """FAÍSCA vela de ignição: sobre o peito, a porca sextavada; por cima, o isolador branco
    com os anéis, o visor que varre na barriga do isolador, e no topo o elétrodo onde salta a
    faísca."""
    faisca_torso(p, with_neck=False)
    c = F_CHEST
    face_y = 0.3
    mk.HEADS["faisca3_hull"] = {"top": round(c.y + 0.78, 3), "center": round(c.y + face_y, 3), "aspect": round(FH_SCREEN[0] / FH_SCREEN[1], 3)}
    # A porca: sextavado de metal com chanfros, a ligar o peito ao isolador.
    mtube(p, "metal", T(0, c.y + 0.2, c.z), 0.235, 0.09, 6, bevel=0.012)
    mring(p, "dark", T(0, c.y + 0.155, c.z), 0.2, 0.012, 24, 4)
    mring(p, "trim", T(0, c.y + 0.25, c.z), 0.205, 0.014, 26, 5)
    flat, front = dome_hull(p, c, 1.0, FH_PROFILE, (-126, -54, 0.27, 0.34), face_y, FH_SCREEN)
    for dy in (-1, 1):
        mbox(p, "metal", T(0, c.y + face_y + dy * 0.045, front + 0.012), (0.22, 0.012, 0.014), 0.004, 1)
    # Os anéis do isolador, em azul.
    for y in (0.43, 0.48, 0.53):
        mring(p, "trim", T(0, c.y + y, c.z), profile_radius(FH_PROFILE, y) + 0.008, 0.016, 26, 6)
    # O terminal, o elétrodo em gancho e a faísca a saltar entre os dois.
    top = c.y + 0.6
    mtube(p, "metal", T(0, top + 0.03, c.z), 0.055, 0.06, 16, bevel=0.008)
    mtube(p, "metal", T(0, top + 0.075, c.z), 0.035, 0.03, 6, bevel=0.004)
    rod(p, "metal", (0.05, top + 0.04, c.z), (0.1, top + 0.1, c.z), 0.014, 8)
    rod(p, "metal", (0.1, top + 0.1, c.z), (0.1, top + 0.2, c.z), 0.014, 8)
    rod(p, "metal", (0.1, top + 0.2, c.z), (0.02, top + 0.2, c.z), 0.014, 8)
    extruded(p, "glow", sub(T(0.01, top + 0.09, c.z), rot=(0, 90, 0)) @ Matrix.Diagonal((0.55, 0.55, 0.55, 1.0)), BOLT, 0.016)
    ball(p, "glow", (0.015, top + 0.16, c.z), 0.02, 10)
    for side in (-1, 1):
        q, n = rev_point(c, FH_PROFILE, 1.0, 90 + side * 75, face_y)
        mbox(p, "glow", frame(q, n), (0.012, 0.03, 0.03), 0.004, 1)
    mbox(p, "team", T(0, c.y + 0.2455, c.z - 0.12), (0.1, 0.012, 0.03), 0.004, 1)


MH_PROFILE = [(0.22, 0.2), (0.28, 0.27), (0.34, 0.31), (0.42, 0.335), (0.5, 0.345), (0.54, 0.345)]
MH_SCREEN = (0.28, 0.1)


def magnus_hull(p):
    """MAGNUS taça de campeão: o peito é o pé da taça e a cabeça é o bojo, com o rosto numa
    máscara, asas douradas dos lados, o bordo dourado e uma estrela a sair lá de dentro."""
    magnus_torso(p, with_neck=False)
    c = M_CHEST
    depth = 0.9
    face_y = 0.38
    mk.HEADS["magnus3_hull"] = {"top": round(c.y + 0.85, 3), "center": round(c.y + face_y, 3), "aspect": round(MH_SCREEN[0] / MH_SCREEN[1], 3)}
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, depth, 1.0))
    y0, y1 = MH_PROFILE[0][0], MH_PROFILE[-1][0]
    lathe(p, "dark", flat, [(0.0, y0)] + [(r - 0.035, y) for y, r in MH_PROFILE] + [(0.0, y1 - 0.02)], 28)
    # O pé da taça: gargalo dourado entre o peito e o bojo.
    lathe(p, "trim", flat, [(0.16, 0.16), (0.2, 0.18), (0.14, 0.2), (0.16, 0.23), (0.0, 0.23)], 26)
    lon0, lon1 = -130, -50
    rev_panel(p, "shell", flat, MH_PROFILE, (y0, 0.33), (-180, 180), 0.034, (24, 6), gap=0.0)
    rev_panel(p, "shell", flat, MH_PROFILE, (0.33, 0.45), (lon1, lon0 + 360), 0.034, (18, 6), gap=0.012)
    rev_panel(p, "trim", flat, MH_PROFILE, (0.45, y1), (-180, 180), 0.034, (24, 3), gap=0.0)
    mring(p, "trim", sub(flat, 0, 0.33, 0), profile_radius(MH_PROFILE, 0.33) + 0.006, 0.014, 32, 5)
    mring(p, "trim", sub(flat, 0, y1, 0), 0.35, 0.026, 36, 8)
    front = c.z - profile_radius(MH_PROFILE, face_y) * depth
    screen_well(p, (0, c.y + face_y, front + 0.006), MH_SCREEN, 0.05, 0.01)
    for dy in (-1, 1):
        mbox(p, "trim", T(0, c.y + face_y + dy * 0.066, front + 0.004), (0.34, 0.026, 0.03), 0.01)
    # O fundo da taça e a estrela do Penta a erguer-se lá de dentro.
    mtube(p, "dark", T(0, c.y + y1 - 0.02, c.z), 0.32, 0.02, 30)
    star = sub(T(0, c.y + y1 + 0.13, c.z), rot=(0, 0, 0))
    extruded(p, "trim", star, star_points(0.15, 0.065), 0.05)
    extruded(p, "glow", sub(star, 0, 0, -0.027), star_points(0.1, 0.043), 0.012)
    mtube(p, "metal", T(0, c.y + y1 + 0.0, c.z), 0.03, 0.06, 12)
    # As asas da taça: duas pegas douradas em C.
    for side in (-1, 1):
        pts = [Vector((side * 0.31, c.y + 0.48, c.z)), Vector((side * 0.44, c.y + 0.5, c.z)), Vector((side * 0.47, c.y + 0.41, c.z)),
               Vector((side * 0.41, c.y + 0.33, c.z)), Vector((side * 0.3, c.y + 0.31, c.z))]
        for a, b in zip(pts, pts[1:]):
            rod(p, "trim", a, b, 0.024, 12)
            ball(p, "trim", b, 0.024, 12)
    for side in (-1, 1):
        mbox(p, "glow", T(side * 0.16, c.y + face_y + 0.1, front + 0.02), (0.04, 0.012, 0.01), 0.003, 1)
    mbox(p, "team", T(0, c.y + y1 + 0.03, c.z + 0.2), (0.1, 0.012, 0.03), 0.004, 1)


OH_C = Vector((0.0, 1.17, 0.02))
OH_R = 0.27


def orbita_hull(p):
    """ÓRBITA observatório: a cúpula grande assenta no planeta e é a cabeça; pela fenda aberta
    sai o telescópio, e a lente dele é o olho. A parabólica ao lado, o anel continua a girar."""
    orbita_torso(p, with_neck=False)
    c = OH_C
    r = OH_R
    tilt = math.radians(19)
    axis = Vector((0.0, math.sin(tilt), -math.cos(tilt)))
    eye = c + Vector((0.0, 0.1, 0.0)) + axis * (r + 0.178)
    mk.HEADS["orbita3_hull"] = {"top": round(c.y + r + 0.05, 3), "center": round(eye.y, 3), "aspect": 1.0}
    d = T(*c)
    ball(p, "dark", c, r - 0.03, 22)
    sphere_panel(p, "shell", d, r, (2, 86), (-78, 98), 0.032, (14, 7), gap=0.01)
    sphere_panel(p, "shell", d, r, (2, 86), (102, 258), 0.032, (14, 7), gap=0.01)
    for lon in (-102, -78):
        meridian_arc(p, "trim", c, r + 0.004, lon, 2, 84, 0.012)
    mring(p, "trim", sub(d, 0, 0.005, 0), r + 0.006, 0.022, 36, 6)
    bolts(p, sub(d, 0, 0.03, 0), r + 0.004, 16, size=0.008)
    # O telescópio: tubo, anéis, para-sol e a lente redonda que é o olho.
    base = c + Vector((0.0, 0.1, 0.0))
    tube = frame(base + axis * (r - 0.04), axis)
    mtube(p, "trim", sub(tube, 0, 0.05, 0), 0.095, 0.3, 22, bevel=0.008)
    for v in (-0.05, 0.06, 0.14):
        mring(p, "metal", sub(tube, 0, v, 0), 0.098, 0.012, 22, 5)
    mtube(p, "dark", sub(tube, 0, 0.2, 0), 0.115, 0.05, 24, caps=False)
    mring(p, "trim", sub(tube, 0, 0.225, 0), 0.114, 0.018, 26, 6)
    bolts(p, sub(tube, 0, 0.232, 0), 0.114, 6, size=0.008)
    p.screen(tuple(base + axis * (r + 0.178)), (0.13, 0.13), bulge=0.012, rot=(19, 0, 0))
    # A parabólica no lado esquerdo da cúpula.
    arm = Vector((-r - 0.005, c.y + 0.1, c.z + 0.02))
    mtube(p, "metal", axis_frame(arm, "-x"), 0.03, 0.03, 14)
    rod(p, "metal", arm + Vector((-0.015, 0, 0)), arm + Vector((-0.08, 0.09, 0.0)), 0.01, 8)
    dish = frame(arm + Vector((-0.09, 0.11, -0.01)), (-0.5, 0.6, -0.62))
    lathe(p, "trim", dish, [(0.0, 0.0), (0.06, 0.006), (0.11, 0.024), (0.12, 0.036), (0.114, 0.04), (0.06, 0.012), (0.0, 0.005)], 22)
    rod(p, "metal", at(dish, 0, 0.01, 0), at(dish, 0, 0.1, 0), 0.006, 6)
    ball(p, "glow", at(dish, 0, 0.105, 0), 0.014, 8)
    mtube(p, "dark", T(0, c.y + r - 0.005, c.z + 0.02), 0.035, 0.05, 12)
    ball(p, "glow", (0, c.y + r + 0.03, c.z + 0.02), 0.02, 10)
    mbox(p, "team", T(0, c.y + r * 0.7, c.z + r * 0.72), (0.1, 0.012, 0.03), 0.004, 1)


# ======================================================================================
# Quarta geração: corpos novos de raiz, cada um com a sua cintura, anca e pernas.
# ======================================================================================
def helix(p, role, center, radius, y0, y1, turns, wire, detail=10):
    """Mola: fio em hélice à volta do eixo vertical, de y0 a y1."""
    c = Vector(center)
    steps = int(turns * detail)
    prev = None
    for i in range(steps + 1):
        t = i / steps
        a = t * turns * math.tau
        q = c + Vector((radius * math.cos(a), y0 + (y1 - y0) * t, radius * math.sin(a)))
        if prev is not None:
            rod(p, role, prev, q, wire, 6)
        prev = q


def hip_axles(p, y, x0, hip_x, house_r=0.075, role="dark"):
    """Alojamentos das ancas: rolamento de cada lado e o eixo até ao pivô da perna."""
    for side in (-1, 1):
        house = axis_frame((side * x0, y, 0.0), "x" if side > 0 else "-x")
        mtube(p, role, house, house_r, 0.04, 20, bevel=0.006)
        bolts(p, sub(house, 0, 0.022, 0), house_r * 0.8, 6, size=0.009)
        mtube(p, "metal", sub(house, 0, 0.02 + (hip_x - x0) / 2 + 0.03, 0), 0.036, hip_x - x0 + 0.07, 12)


def leg_hub(p, out, r=0.062):
    ox = "x" if out > 0 else "-x"
    hub = axis_frame((0.03 * out, 0, 0), ox)
    mtube(p, "dark", hub, r, 0.07, 18, bevel=0.008)
    cap = sub(hub, 0, 0.05, 0)
    mtube(p, "metal", cap, r * 0.8, 0.018, 18)
    bolts(p, sub(cap, 0, 0.01, 0), r * 0.6, 6, size=0.009)


def limb(p, role, a, b, radius, detail=16):
    """Membro em cápsula de `a` a `b`."""
    a, b = Vector(a), Vector(b)
    capsule(p, role, frame(a.lerp(b, 0.5), b - a), radius, (b - a).length + radius * 2, detail)


# --------------------------------------------------------------------------------------
# ECLIPSE 4: monólito sextavado; o rosto é o próprio eclipse. Coluna de discos, saia de
# placas, pernas de gafanhoto com lâmina na canela, espigão no joelho e garras.
# --------------------------------------------------------------------------------------
E4_PROFILE = [(0.14, 0.86), (0.2, 0.95), (0.245, 1.08), (0.26, 1.3), (0.245, 1.46), (0.2, 1.6), (0.11, 1.72), (0.0, 1.82)]
E4_FACE = 1.5
E4_SCREEN = (0.16, 0.07)


def e4_r(y):
    pts = [(yy, r) for r, yy in E4_PROFILE]
    return profile_radius(pts, y)


def eclipse4_hull(p):
    z = 0.02
    mk.HEADS["eclipse4_hull"] = {"top": 1.82, "center": E4_FACE, "aspect": round(E4_SCREEN[0] / E4_SCREEN[1], 3)}
    base = T(0, 0, z)
    lower = [(r, y) for r, y in E4_PROFILE if y <= 1.42]
    upper = [(r, y) for r, y in E4_PROFILE if y >= 1.44]
    lathe(p, "dark", base, [(0.0, 0.86)] + [(r - 0.03, y) for r, y in E4_PROFILE] + [(0.0, 1.82)], 6)
    lathe(p, "shell", base, [(0.0, 0.86)] + lower + [(e4_r(1.42), 1.42), (0.0, 1.42)], 6)
    lathe(p, "shell", base, [(0.0, 1.44), (e4_r(1.44), 1.44)] + upper, 6)
    lathe(p, "trim", base, [(e4_r(1.4) - 0.02, 1.4), (e4_r(1.4) + 0.012, 1.4), (e4_r(1.46) + 0.012, 1.46), (e4_r(1.46) - 0.02, 1.46)], 6)
    lathe(p, "trim", base, [(e4_r(0.9) - 0.02, 0.88), (e4_r(0.9) + 0.012, 0.88), (e4_r(0.96) + 0.012, 0.96), (e4_r(0.96) - 0.02, 0.96)], 6)
    # O rosto: o eclipse - disco negro, coroa de luz vermelha, espinhos, olhos em fenda.
    front = z - e4_r(E4_FACE) * math.cos(math.radians(30))
    face = axis_frame((0, E4_FACE, front - 0.01), "-z")
    mtube(p, "dark", face, 0.125, 0.03, 30)
    mring(p, "glow", sub(face, 0, 0.01, 0), 0.13, 0.012, 32, 5)
    mring(p, "trim", sub(face, 0, 0.0, 0), 0.148, 0.018, 36, 6)
    for i in range(12):
        a = math.radians(i * 30 + 15)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        tip = 0.12 if i % 2 == 0 else 0.065
        lathe(p, "trim" if i % 2 == 0 else "dark", frame(Vector((0, E4_FACE, front - 0.012)) + d * 0.15, d), [(0.0, 0.0), (0.024, 0.0), (0.0, tip)], 6)
    p.screen((0, E4_FACE, front - 0.032), E4_SCREEN, bulge=0.006)
    # Frisos de luz nas arestas da frente e a divisa no peito.
    for side in (-1, 1):
        for y in (1.02, 1.14, 1.26):
            ang = math.radians(-90 + side * 30)
            q = Vector((e4_r(y) * math.cos(ang) * 0.96, y, z + e4_r(y) * math.sin(ang) * 0.96))
            mbox(p, "glow", sub(T(*q), rot=(0, -side * 30, 0)), (0.012, 0.07, 0.012), 0.003, 1)
    for side in (-1, 1):
        mbox(p, "glow", sub(T(side * 0.05, 1.23, z - e4_r(1.23) * 0.866 - 0.004), rot=(0, 0, side * 35)), (0.11, 0.018, 0.01), 0.004, 1)
    serial(p, plane((0.1, 1.08, z - e4_r(1.08) * 0.866 - 0.003), (0, 0, -1), (-1, 0, 0)), "10", 0.03)
    mbox(p, "team", T(0, 1.73, z - 0.03), (0.06, 0.012, 0.08), 0.004, 1)
    charging_port(p, plane((-(e4_r(1.1) - 0.01), 1.1, z), (-1, 0, 0), (0, 0, 1)), 0.042, 0.026)
    # Coluna de discos e a bacia sextavada com a saia de placas.
    mtube(p, "dark", T(0, 0.82, z), 0.08, 0.12, 16)
    for y in (0.78, 0.82, 0.86):
        mring(p, "metal", T(0, y, z), 0.1, 0.014, 20, 5)
    lathe(p, "dark", T(0, 0.74, 0.0), [(0.0, -0.06), (0.15, -0.06), (0.17, 0.0), (0.15, 0.05), (0.0, 0.05)], 6)
    hip_axles(p, 0.74, 0.14, ECLIPSE["hip"].x, 0.07)
    for i, lon in enumerate((-150, -115, -90, -65, -30)):
        a = math.radians(lon)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        plate = frame(Vector((0, 0.66, 0.0)) + d * 0.17, Vector((0, -1, 0)) + d * 0.25, front=d)
        mbox(p, "shell" if i % 2 == 0 else "trim", plate, (0.11, 0.18, 0.025), 0.01)
        screw(p, sub(plate, 0, 0.07, 0.016, rot=(90, 0, 0)), 0, 0, 0.006)


def eclipse4_leg(p, out):
    hip_y = ECLIPSE["hip"].y

    def talons(q, m, o, ankle):
        mbox(q, "dark", sub(m, 0, 0.035, 0.0), (0.12, 0.05, 0.12), 0.015)
        for a in (-22, 0, 22):
            d = Vector((math.sin(math.radians(a)), -0.12, -math.cos(math.radians(a)))).normalized()
            lathe(q, "metal", frame(at(m, 0, 0.035, -0.04), d), [(0.0, 0.0), (0.032, 0.0), (0.02, 0.12), (0.0, 0.2)], 8)
        lathe(q, "trim", frame(at(m, 0, 0.04, 0.05), Vector((0, -0.2, 1)).normalized()), [(0.0, 0.0), (0.028, 0.0), (0.0, 0.12)], 8)
    bird_leg(p, out, hip_y, knee=(-0.19, -0.13), heel=(-0.47, 0.13), ankle_up=0.1, foot_fn=talons, k=1.05)
    # Espigão no joelho e lâmina ao longo da canela.
    kn = Vector((0, -0.19, -0.13))
    he = Vector((0, -0.47, 0.13))
    lathe(p, "trim", frame(kn + Vector((0, 0.02, -0.06)), Vector((0, 0.55, -1)).normalized()), [(0.0, 0.0), (0.04, 0.0), (0.0, 0.16)], 8)
    blade = [(0.0, 0.0), (0.04, 0.02), (0.05, 0.28), (0.0, 0.34), (-0.015, 0.2)]
    mid = kn.lerp(he, 0.5)
    extruded(p, "trim", frame(kn + Vector((0, -0.02, 0.06)), he - kn, front=(1, 0, 0)), blade, 0.014)


# --------------------------------------------------------------------------------------
# BATIDA 4: boombox que anda. Os dois altifalantes são os olhos, o equalizador a boca;
# pega com orelhas de gato. Cintura em mola, pernas de mola, ténis de plataforma.
# --------------------------------------------------------------------------------------
B4_C = Vector((0.0, 1.28, 0.02))
B4_SIZE = (0.48, 0.5, 0.36)
B4_MOUTH = (0.28, 0.07)


def batida4_hull(p):
    c = B4_C
    w, h, d = B4_SIZE
    front = c.z - d / 2
    mouth_y = c.y - 0.12
    mk.HEADS["batida4_hull"] = {"top": round(c.y + h / 2 + 0.2, 3), "center": round(c.y + 0.05, 3), "aspect": round(B4_MOUTH[0] / B4_MOUTH[1], 3)}
    mbox(p, "dark", T(*c), (w - 0.04, h - 0.04, d - 0.04), 0.08)
    # A caixa em painéis: tampo, fundo, ilhargas, costas e a moldura da frente.
    mbox(p, "shell", T(c.x, c.y + h / 2 - 0.03, c.z), (w, 0.07, d), 0.03)
    mbox(p, "shell", T(c.x, c.y - h / 2 + 0.03, c.z), (w, 0.07, d), 0.03)
    for side in (-1, 1):
        mbox(p, "shell", T(side * (w / 2 - 0.025), c.y, c.z), (0.05, h - 0.1, d - 0.02), 0.02)
    mbox(p, "shell", T(c.x, c.y, c.z + d / 2 - 0.02), (w - 0.08, h - 0.1, 0.04), 0.02)
    mbox(p, "trim", T(c.x, c.y + 0.05, front + 0.012), (w - 0.07, 0.27, 0.02), 0.02)
    # Os olhos: dois altifalantes grandes com cone, cúpula e anel de luz.
    for side in (-1, 1):
        spk = axis_frame((side * 0.115, c.y + 0.07, front), "-z")
        mtube(p, "dark", sub(spk, 0, 0.004, 0), 0.105, 0.03, 30)
        mring(p, "shell", sub(spk, 0, 0.02, 0), 0.104, 0.014, 32, 6)
        lathe(p, "dark", sub(spk, 0, 0.0, 0), [(0.09, 0.02), (0.05, 0.005), (0.0, 0.0)], 26)
        dome(p, "trim", sub(spk, 0, 0.012, 0), 0.036, 0.03, 18, 4)
        ball(p, "glow", at(spk, 0.0, 0.04, 0.0), 0.014, 10)
        mring(p, "glow", sub(spk, 0, 0.022, 0), 0.088, 0.005, 30, 4)
        bolts(p, sub(spk, 0, 0.02, 0), 0.098, 6, size=0.006)
    # A boca: o ecrã-equalizador por baixo, numa grelha.
    screen_well(p, (0, mouth_y, front + 0.004), B4_MOUTH, 0.04, 0.008)
    for i in range(5):
        mbox(p, "dark", T(0, mouth_y - 0.06 - i * 0.014, front + 0.006), (0.3, 0.006, 0.006), 0.002, 1)
    # Botões no tampo, a pega e as orelhas de gato nas pontas da pega.
    top = c.y + h / 2
    for i, role in enumerate(("glow", "trim", "trim", "dark", "trim")):
        mbox(p, role, T(-0.14 + i * 0.07, top + 0.012, front + 0.06), (0.05, 0.024, 0.05), 0.01)
    for side in (-1, 1):
        mbox(p, "dark", T(side * 0.19, top + 0.04, c.z + 0.03), (0.04, 0.08, 0.06), 0.012)
    arc_tube(p, "shell", axis_frame((0, top + 0.07, c.z + 0.03), "z"), 0.19, 0.022, 0, 180, 24, 8)
    mtube(p, "rubber", axis_frame((0, top + 0.26, c.z + 0.03), "x"), 0.028, 0.16, 12)
    for side in (-1, 1):
        ear = sub(T(side * 0.17, top + 0.24, c.z + 0.03), 0, 0.06, 0, rot=(0, 0, -side * 20))
        mbox(p, "shell", ear, (0.12, 0.15, 0.05), 0.02, 2, taper=(0.15, 0.5))
        mbox(p, "trim", sub(ear, 0, -0.01, -0.024), (0.07, 0.09, 0.01), 0.01, 1, taper=(0.15, 0.5))
    # Botões de volume dos lados e uma antena telescópica.
    for side in (-1, 1):
        knob = axis_frame((side * (w / 2 + 0.005), c.y + 0.1, c.z - 0.05), "x" if side > 0 else "-x")
        mtube(p, "metal", knob, 0.035, 0.03, 16, bevel=0.004)
        mbox(p, "dark", sub(knob, 0, 0.016, 0.02), (0.006, 0.006, 0.03), 0.002, 1)
    rod(p, "metal", (0.2, top + 0.02, c.z + 0.12), (0.26, top + 0.3, c.z + 0.16), 0.008, 6)
    ball(p, "glow", (0.26, top + 0.31, c.z + 0.16), 0.016, 8)
    serial(p, plane((0.15, c.y - 0.19, front + 0.001), (0, 0, -1), (-1, 0, 0)), "04", 0.03)
    mbox(p, "team", T(0, top + 0.001, c.z + 0.1), (0.14, 0.012, 0.05), 0.004, 1)
    # Cintura em mola e bacia em disco (um prato de gira-discos).
    hip = BATIDA["hip"]
    mtube(p, "metal", T(0, 0.9, c.z), 0.03, 0.3, 10)
    mtube(p, "dark", T(0, c.y - h / 2 - 0.01, c.z), 0.1, 0.03, 18)
    helix(p, "trim", (0, 0, c.z), 0.085, 0.76, c.y - h / 2 - 0.02, 5, 0.014)
    lathe(p, "shell", T(0, 0.7, 0.0), [(0.0, -0.05), (0.17, -0.05), (0.18, 0.0), (0.17, 0.05), (0.0, 0.05)], 28)
    mring(p, "trim", T(0, 0.75, 0.0), 0.15, 0.01, 28, 4)
    mtube(p, "metal", T(0, 0.755, 0.0), 0.03, 0.01, 12)
    hip_axles(p, hip.y, 0.13, hip.x, 0.065)


def batida4_leg(p, out):
    hip_y = BATIDA["hip"].y
    ground = -hip_y
    leg_hub(p, out, 0.058)
    knee = Vector((0, -0.26, -0.01))
    ankle = Vector((0, ground + 0.17, 0.0))
    limb(p, "shell", (0, -0.05, 0), knee + Vector((0, 0.05, 0)), 0.062)
    mring(p, "trim", T(0, -0.16, -0.005), 0.066, 0.01, 18, 4)
    ball(p, "metal", knee, 0.058, 16)
    # A mola da canela à volta de um amortecedor.
    mtube(p, "dark", T(0, knee.y - 0.06, 0.0), 0.065, 0.03, 18)
    mtube(p, "dark", T(0, ankle.y + 0.04, 0.0), 0.065, 0.03, 18)
    mtube(p, "metal", T(0, (knee.y + ankle.y) / 2, 0.0), 0.018, knee.y - ankle.y, 10)
    helix(p, "trim", (0, 0, 0), 0.052, ankle.y + 0.05, knee.y - 0.07, 4.5, 0.012)
    ball(p, "metal", ankle, 0.04, 12)
    # Ténis de plataforma: sola grossa, entressola clara, cano com atacadores, biqueira.
    g = ground
    mbox(p, "rubber", T(0, g + 0.035, -0.05), (0.2, 0.07, 0.38), 0.03)
    mbox(p, "trim", T(0, g + 0.085, -0.05), (0.205, 0.035, 0.37), 0.015)
    mbox(p, "glow", T(out * 0.103, g + 0.045, -0.05), (0.006, 0.012, 0.28), 0.003, 1)
    mbox(p, "shell", T(0, g + 0.15, -0.03), (0.17, 0.1, 0.3), 0.045, 2, taper=(0.85, 0.7))
    mbox(p, "trim", T(0, g + 0.13, -0.19), (0.16, 0.06, 0.06), 0.03)
    for i in range(3):
        mbox(p, "dark", T(0, g + 0.2 - i * 0.012, -0.09 + i * 0.04), (0.1, 0.008, 0.012), 0.003, 1)
    mbox(p, "shell", T(0, g + 0.22, 0.03), (0.14, 0.1, 0.12), 0.04)


# --------------------------------------------------------------------------------------
# ÓRBITA 4: planeta-astronauta. O corpo é um planeta com um visor de vidro na frente e um
# anel grande que gira; anca em cardã; pernas curtas em cápsula com botas-propulsor.
# --------------------------------------------------------------------------------------
O4_C = Vector((0.0, 1.22, 0.02))
O4_R = 0.26
O4_SCREEN = (0.17, 0.1)


def orbita4_hull(p):
    c = O4_C
    r = O4_R
    mk.HEADS["orbita4_hull"] = {"top": round(c.y + r + 0.18, 3), "center": round(c.y + 0.07, 3), "aspect": round(O4_SCREEN[0] / O4_SCREEN[1], 3)}
    base = T(*c)
    ball(p, "dark", c, r - 0.03, 24)
    for lat, lo in (((10, 86), (-180, 180)), ((-86, -10), (-180, 180))):
        sphere_panel(p, "shell", base, r, lat, lo, 0.03, (24, 6), gap=0.0)
    for lo in ((-60, 60), (120, 240)):
        sphere_panel(p, "shell", base, r, (-8, 8), lo, 0.03, (10, 2), gap=0.01)
    sphere_panel(p, "trim", base, r + 0.006, (-10, -7), (-180, 180), 0.02, (30, 1), gap=0.0)
    sphere_panel(p, "trim", base, r + 0.006, (7, 10), (-180, 180), 0.02, (30, 1), gap=0.0)
    # O visor de astronauta: cúpula de vidro escuro com aro, o rosto lá dentro.
    tilt = math.radians(14)
    n = Vector((0.0, math.sin(tilt), -math.cos(tilt)))
    pos = c + n * (r - 0.03)
    vf = frame(pos, n)
    mring(p, "trim", sub(vf, 0, 0.02, 0), 0.155, 0.024, 36, 8)
    bolts(p, sub(vf, 0, 0.04, 0), 0.155, 8, size=0.008)
    dome(p, "dark", sub(vf, 0, 0.02, 0), 0.14, 0.06, 28, 6)
    p.screen(tuple(pos + n * 0.085), O4_SCREEN, bulge=0.014, rot=(14, 0, 0))
    # Antena com uma lua no topo, e o jato de manobra atrás.
    rod(p, "metal", c + Vector((0.06, r - 0.02, 0.03)), c + Vector((0.09, r + 0.14, 0.05)), 0.009, 6)
    ball(p, "trim", c + Vector((0.09, r + 0.16, 0.05)), 0.03, 12)
    ball(p, "glow", c + Vector((0.12, r + 0.18, 0.04)), 0.012, 8)
    for side in (-1, 1):
        noz = frame(c + Vector((side * 0.1, -0.08, r - 0.02)), Vector((side * 0.2, -0.5, 1)).normalized())
        lathe(p, "metal", noz, [(0.03, 0.0), (0.04, 0.05), (0.055, 0.09), (0.05, 0.095)], 14)
        mtube(p, "glow", sub(noz, 0, 0.085, 0), 0.04, 0.004, 12)
    serial(p, plane((0.13, c.y - 0.13, c.z - r * 0.87), (0, -0.4, -1), (-1, 0, 0)), "09", 0.03)
    mbox(p, "team", T(0, c.y + r * 0.72, c.z + r * 0.68), (0.1, 0.012, 0.03), 0.004, 1)
    # Cintura curta e a anca em cardã: esfera escura dentro de um anel de metal.
    hip = ORBITA["hip"]
    mtube(p, "dark", T(0, 0.9, c.z), 0.07, 0.12, 16)
    mring(p, "metal", T(0, 0.93, c.z), 0.09, 0.012, 18, 4)
    ball(p, "dark", (0, 0.72, 0.0), 0.13, 20)
    mring(p, "metal", axis_frame((0, 0.72, 0.0), "x"), 0.155, 0.016, 32, 6)
    mring(p, "trim", T(0, 0.72, 0.0), 0.15, 0.012, 32, 5)
    hip_axles(p, hip.y, 0.12, hip.x, 0.06)


def orbita4_spin(p):
    """O anel do planeta, grande e inclinado, com duas luas: gira em jogo."""
    c = O4_C
    tilt = sub(T(0, c.y, 0.0), rot=(22, 0, 12))
    mring(p, "trim", tilt, 0.44, 0.024, 64, 6)
    mring(p, "glow", tilt, 0.47, 0.008, 64, 4)
    mring(p, "shell", tilt, 0.405, 0.012, 60, 4)
    for a, rr in ((30, 0.035), (200, 0.025)):
        q = at(tilt, 0.44 * math.cos(math.radians(a)), 0.0, 0.44 * math.sin(math.radians(a)))
        ball(p, "metal", q, rr, 12)


def orbita4_leg(p, out):
    hip_y = ORBITA["hip"].y
    ground = -hip_y
    leg_hub(p, out, 0.055)
    knee = Vector((0, -0.24, -0.02))
    ankle = Vector((0, ground + 0.2, 0.0))
    ball(p, "metal", (0, -0.02, 0), 0.06, 14)
    limb(p, "trim", (0, -0.05, 0), knee, 0.055)
    ball(p, "metal", knee, 0.065, 16)
    mring(p, "dark", axis_frame(knee, "x"), 0.066, 0.012, 20, 4)
    limb(p, "shell", knee, ankle, 0.058)
    mring(p, "trim", T(0, (knee.y + ankle.y) / 2, -0.01), 0.062, 0.01, 18, 4)
    # Bota-propulsor: sino arredondado, aletas e o bocal com luz por baixo.
    g = ground
    lathe(p, "shell", T(0, g + 0.035, -0.02), [(0.0, 0.0), (0.1, 0.0), (0.13, 0.04), (0.125, 0.12), (0.09, 0.18), (0.05, 0.2), (0.0, 0.2)], 24)
    mring(p, "trim", T(0, g + 0.09, -0.02), 0.132, 0.014, 26, 5)
    mtube(p, "metal", T(0, g + 0.02, -0.02), 0.085, 0.04, 20)
    mtube(p, "glow", T(0, g + 0.001, -0.02), 0.06, 0.004, 18)
    for a in (0, 120, 240):
        d = Vector((math.cos(math.radians(a + 90)), 0.0, math.sin(math.radians(a + 90))))
        mbox(p, "trim", frame(Vector((0, g + 0.1, -0.02)) + d * 0.14, Vector((0, 1, 0)), front=d), (0.012, 0.12, 0.05), 0.006)
    mbox(p, "rubber", T(0, g + 0.012, -0.08), (0.14, 0.024, 0.12), 0.01)


# --------------------------------------------------------------------------------------
# MAGNUS 4: rei-cavaleiro. Couraça que sobe num elmo com o visor em T e a coroa de pontas;
# estrela no peito, capa às costas. Saia de placas pesada e pernas com grevas e escarpes.
# --------------------------------------------------------------------------------------
M4_PROFILE = [(-0.26, 0.2), (-0.18, 0.26), (-0.06, 0.3), (0.06, 0.315), (0.16, 0.31), (0.24, 0.28), (0.32, 0.23), (0.38, 0.17), (0.42, 0.1), (0.44, 0.0)]
M4_SCREEN = (0.26, 0.06)


def magnus4_hull(p):
    c = M_CHEST
    face_y = 0.275
    mk.HEADS["magnus4_hull"] = {"top": round(c.y + 0.62, 3), "center": round(c.y + face_y, 3), "aspect": round(M4_SCREEN[0] / M4_SCREEN[1], 3)}
    flat, front = dome_hull(p, c, 0.82, M4_PROFILE, (-128, -52, 0.245, 0.305), face_y, M4_SCREEN)
    # O T do visor: a fenda dos olhos já está; a do nariz desce escura, com debrum dourado.
    mbox(p, "dark", T(0, c.y + face_y - 0.08, front + 0.01), (0.05, 0.12, 0.03), 0.01)
    for side in (-1, 1):
        mbox(p, "trim", T(side * 0.04, c.y + face_y - 0.08, front + 0.002), (0.018, 0.13, 0.03), 0.006)
    mbox(p, "trim", T(0, c.y + face_y + 0.05, front + 0.002), (0.3, 0.025, 0.03), 0.01)
    # A estrela no peito.
    core = axis_frame((0, c.y + 0.02, c.z - profile_radius(M4_PROFILE, 0.02) * 0.82 - 0.004), "-z")
    mring(p, "trim", sub(core, 0, -0.004, 0), 0.1, 0.018, 32, 6)
    mtube(p, "dark", sub(core, 0, -0.02, 0), 0.095, 0.03, 28)
    extruded(p, "glow", sub(core, 0, 0.004, 0, rot=(-90, 0, 0)), star_points(0.075, 0.032), 0.014)
    # A coroa: aro dourado com pontas e pedras de luz.
    top = c.y + 0.42
    mring(p, "trim", T(0, top - 0.02, c.z), 0.12, 0.025, 30, 6)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        q = Vector((math.cos(a) * 0.12, top, c.z + math.sin(a) * 0.12 * 0.82))
        hh = 0.13 if i % 2 == 0 else 0.09
        lathe(p, "trim", frame(q, Vector((math.cos(a) * 0.25, 1, math.sin(a) * 0.25)).normalized()), [(0.0, 0.0), (0.03, 0.0), (0.0, hh)], 6)
        if i % 2 == 0:
            ball(p, "glow", q + Vector((math.cos(a) * 0.03, hh + 0.01, math.sin(a) * 0.03)), 0.016, 8)
    # A capa real às costas, dos ombros aos joelhos, com a bainha recortada.
    dagged_panel(p, "shell", (0.0, 0.98, c.z + 0.02), 0.42, 0.3, 0.84, (40, 140), 0.025, teeth=3, depth=0.08)
    arc_tube(p, "trim", T(0, 1.38, c.z + 0.02), 0.3, 0.02, 40, 140, 20, 6)
    for lon in (40, 140):
        a = math.radians(lon)
        ball(p, "trim", (0.3 * math.cos(a), 1.38, c.z + 0.02 + 0.3 * math.sin(a)), 0.035, 12)
    mbox(p, "team", T(0, top + 0.001, c.z - 0.12), (0.1, 0.012, 0.03), 0.004, 1)
    # Cintura e bacia pesadas, com a saia de placas debruadas a ouro.
    hip = MAGNUS["hip"]
    mtube(p, "dark", T(0, 0.8, c.z), 0.14, 0.12, 20)
    mring(p, "trim", T(0, 0.86, c.z), 0.17, 0.02, 26, 5)
    mbox(p, "dark", T(0, 0.66, 0.0), (0.34, 0.18, 0.3), 0.04)
    hip_axles(p, hip.y, 0.18, hip.x, 0.085)
    for i, lon in enumerate((-160, -125, -90, -55, -20, 20, 160)):
        a = math.radians(lon)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        plate = frame(Vector((0, 0.62, 0.0)) + d * 0.22, Vector((0, -1, 0)) + d * 0.2, front=d)
        mbox(p, "shell", plate, (0.15, 0.22, 0.03), 0.012)
        mbox(p, "trim", sub(plate, 0, -0.11, 0.0), (0.155, 0.025, 0.035), 0.008)


def magnus4_leg(p, out):
    def sabaton(q, m, o, ankle):
        for i in range(4):
            mbox(q, "shell", sub(m, 0, 0.05 + i * 0.012, -0.05 - i * 0.07), (0.24 - i * 0.02, 0.07 - i * 0.008, 0.1), 0.025)
        mbox(q, "rubber", sub(m, 0, 0.015, -0.08), (0.24, 0.03, 0.42), 0.012)
        lathe(q, "trim", frame(at(m, 0, 0.05, -0.33), Vector((0, 0.2, -1)).normalized()) @ Matrix.Diagonal((1.0, 1.0, 0.6, 1.0)), [(0.0, 0.0), (0.07, 0.0), (0.0, 0.1)], 12)
        mbox(q, "trim", sub(m, 0, 0.08, 0.1), (0.2, 0.08, 0.1), 0.03)

    def greave(q, o, top, bottom, mid):
        h = top - bottom
        cyl_panel(q, "shell", T(0, bottom + h / 2, 0.0), 0.12, h, (-160, -20), 0.04, (10, 2), gap=0.008, radius_top=0.15)
        cyl_panel(q, "trim", T(0, bottom + h / 2, 0.0), 0.124, h * 0.9, (-95, -85), 0.03, (2, 2), radius_top=0.154)
        mring(q, "trim", T(0, top - 0.01, 0.0), 0.15, 0.014, 24, 5)
    leg(p, out, MAGNUS["hip"].y, knee_y=-0.22, ankle_up=0.2, width=1.35, knee_w=0.15, knee_r=0.075, foot_fn=sabaton,
        thigh_fn=round_thigh(k=1.4), shin_fn=greave, thigh_top=0.03, guard=False, shin_top=-0.2)
    # A joelheira: cúpula dourada com uma aba.
    dome(p, "trim", sub(T(0, -0.22, -0.08), rot=(-80, 0, 0)), 0.085, 0.05, 20, 5)


# --------------------------------------------------------------------------------------
# FAÍSCA 4: capacete de corrida. Visor envolvente, crista em raio, asas-spoiler atrás,
# bobina às costas; cintura em amortecedor e bacia estreita com baterias. Pernas de
# gafanhoto (as de sempre).
# --------------------------------------------------------------------------------------
F4_PROFILE = [(-0.28, 0.1), (-0.22, 0.15), (-0.12, 0.2), (0.0, 0.22), (0.12, 0.225), (0.22, 0.23), (0.3, 0.225), (0.38, 0.2), (0.45, 0.15), (0.5, 0.08), (0.52, 0.0)]
F4_SCREEN = (0.3, 0.075)


def faisca4_hull(p):
    c = F_CHEST
    face_y = 0.305
    depth = 0.85
    mk.HEADS["faisca4_hull"] = {"top": round(c.y + 0.75, 3), "center": round(c.y + face_y, 3), "aspect": round(F4_SCREEN[0] / F4_SCREEN[1], 3)}
    flat, front = dome_hull(p, c, depth, F4_PROFILE, (-162, -18, 0.25, 0.36), face_y, F4_SCREEN, front_role="shell")
    rev_panel(p, "trim", flat, [(y, r + 0.005) for y, r in F4_PROFILE], (-0.2, 0.245), (-97, -83), 0.012, (2, 8))
    # Vidro fumado do visor envolvente, recuado na janela.
    rev_panel(p, "dark", flat, [(y, r - 0.012) for y, r in F4_PROFILE], (0.25, 0.36), (-162, -18), 0.01, (16, 3))
    for side in (-1, 1):
        q, n = rev_point(c, F4_PROFILE, depth, -90 + side * 70, face_y)
        mbox(p, "glow", frame(q, n), (0.012, 0.09, 0.014), 0.004, 1)
    # Faixas de corrida e a crista em raio por cima.
    for dx in (-0.06, 0.06):
        rev_panel(p, "trim", flat, [(y, r + 0.004) for y, r in F4_PROFILE], (0.37, 0.5), (-90 + dx * 90, -90 + dx * 90 + 8), 0.01, (2, 6))
    extruded(p, "trim", sub(T(0, c.y + 0.42, c.z + 0.06), rot=(0, 90, 0)) @ Matrix.Diagonal((2.6, 2.6, 2.6, 1.0)), BOLT, 0.04)
    extruded(p, "glow", sub(T(0, c.y + 0.42, c.z + 0.06), rot=(0, 90, 0)) @ Matrix.Diagonal((1.9, 1.9, 1.9, 1.0)) @ Matrix.Translation((0.004, 0.03, 0.0)), BOLT, 0.046)
    # Asas-spoiler atrás e a bobina compacta.
    for side in (-1, 1):
        mbox(p, "trim", sub(T(side * 0.14, c.y + 0.42, c.z + 0.2), rot=(-20, side * 25, side * 20)), (0.2, 0.02, 0.08), 0.01)
    coil = T(0, c.y + 0.05, c.z + 0.26)
    mtube(p, "dark", coil, 0.06, 0.05, 18, bevel=0.006)
    mtube(p, "trim", sub(coil, 0, 0.16, 0), 0.035, 0.26, 14, bevel=0.005)
    for i in range(8):
        mring(p, "metal", sub(coil, 0, 0.06 + i * 0.03, 0), 0.038, 0.004, 14, 4)
    mring(p, "metal", sub(coil, 0, 0.31, 0), 0.075, 0.03, 26, 10)
    ball(p, "glow", at(coil, 0.08, 0.34, 0), 0.014, 8)
    mbox(p, "dark", T(0, c.y + 0.05, c.z + 0.2), (0.06, 0.08, 0.06), 0.01)
    # Banco de condensadores no peito e número.
    core = T(0, c.y + 0.02, c.z - 0.2 * depth + 0.012)
    mbox(p, "dark", core, (0.1, 0.16, 0.04), 0.01)
    for dx in (-0.03, 0.0, 0.03):
        capsule(p, "glow", sub(core, dx, 0, -0.018), 0.011, 0.11, 10)
    q, n = rev_point(c, F4_PROFILE, depth, -50, 0.12)
    serial(p, plane(q, n, (math.sin(math.radians(-50)), 0, -math.cos(math.radians(-50)))), "08", 0.028)
    mbox(p, "team", T(0, c.y + 0.515, c.z - 0.02), (0.02, 0.012, 0.08), 0.004, 1)
    # Cintura em amortecedor e bacia estreita com duas baterias de lado.
    hip = FAISCA["hip"]
    piston(p, (0, 0.78, c.z), (0, c.y - 0.27, c.z), 0.03)
    mring(p, "trim", T(0, 0.86, c.z), 0.06, 0.012, 16, 4)
    mbox(p, "dark", T(0, 0.76, 0.0), (0.18, 0.1, 0.2), 0.03)
    mbox(p, "shell", T(0, 0.76, -0.105), (0.16, 0.08, 0.02), 0.01)
    for side in (-1, 1):
        capsule(p, "trim", sub(T(side * 0.1, 0.8, 0.07), rot=(90, 0, 0)), 0.03, 0.14, 12)
        mring(p, "glow", sub(T(side * 0.1, 0.8, 0.07), rot=(90, 0, 0)), 0.031, 0.005, 14, 4)
    hip_axles(p, hip.y, 0.1, hip.x, 0.058)


# ======================================================================================
# Quinta geração: recriações fiéis das referências do jogador - blocos grossos de arestas
# chanfradas, poucas formas grandes, antebraços enormes, pernas curtas e fortes.
# ======================================================================================
def cbox(p, role, at_, size, chamfer=0.03, rot=(0, 0, 0), taper=None):
    """Bloco de arestas chanfradas (bisel plano), o traço das referências."""
    m = sub(T(*at_), rot=rot) if not isinstance(at_, Matrix) else at_
    mbox(p, role, m, size, chamfer * (1.6 if SOFT[0] else 1.0), 3 if SOFT[0] else 1, taper)


# Arestas arredondadas em vez de chanfradas (a BATIDA): liga-se à volta das suas peças.
SOFT = [False]


def softened(fn):
    def build(p, *args):
        SOFT[0] = True
        try:
            fn(p, *args)
        finally:
            SOFT[0] = False
    return build


def beam(p, role, a, b, width, depth, chamfer=0.03, pad=0.0, front=(0, 0, -1)):
    """Bloco chanfrado de `a` a `b` (o comprimento ao longo do Y local)."""
    a, b = Vector(a), Vector(b)
    m = frame(a.lerp(b, 0.5), b - a, front=front)
    mbox(p, role, m, (width, (b - a).length + pad, depth), chamfer, 1)
    return m


def fist(p, m, scale=1.0, role="dark"):
    """Punho de blocos: palma, quatro dedos dobrados e o polegar, num referencial com o Y local
    ao longo do antebraço."""
    k = scale
    mbox(p, role, sub(m, 0, 0.0, 0.0), (0.2 * k, 0.14 * k, 0.2 * k), 0.025 * k, 1)
    for i in range(4):
        mbox(p, role, sub(m, -0.075 * k + i * 0.05 * k, 0.1 * k, -0.02 * k), (0.045 * k, 0.08 * k, 0.16 * k), 0.012 * k, 1)
    mbox(p, role, sub(m, 0.12 * k, 0.02 * k, -0.06 * k, rot=(0, 0, -30)), (0.06 * k, 0.1 * k, 0.07 * k), 0.012 * k, 1)


def block_claw_foot(p, ground, role="shell", toe_role="dark", k=1.0, z=0.0):
    """Pé de garras: calcanhar, dois dedos à frente e um atrás, em blocos chanfrados."""
    mbox(p, role, T(0, ground + 0.07 * k, z + 0.02), (0.18 * k, 0.1 * k, 0.16 * k), 0.025, 1)
    for side in (-1, 1):
        cbox(p, toe_role, (side * 0.055 * k, ground + 0.035 * k, z - 0.12 * k), (0.07 * k, 0.07 * k, 0.2 * k), 0.02, rot=(0, side * 12, 0))
        cbox(p, role, (side * 0.055 * k, ground + 0.075 * k, z - 0.1 * k), (0.075 * k, 0.03 * k, 0.12 * k), 0.012, rot=(0, side * 12, 0))
    cbox(p, toe_role, (0, ground + 0.035 * k, z + 0.13 * k), (0.07 * k, 0.07 * k, 0.12 * k), 0.02)


# --------------------------------------------------------------------------------------
# ECLIPSE 5 (referência: o tanque verde "08"): tronco largo e curvado, a cabeça enterrada à
# frente dos ombros com a fenda dos olhos sob uma pala, ombreiras em bloco, punhos enormes,
# pernas curtas e grossas com botas pesadas.
# --------------------------------------------------------------------------------------
E5 = {"elbow_l": Vector((-0.6, 1.08, 0.02)), "wrist_l": Vector((-0.64, 0.78, -0.12)), "elbow_r": Vector((0.6, 1.08, -0.02))}


def eclipse5_torso(p):
    mk.HEADS["eclipse5_torso"] = {"top": 1.7, "center": 1.53, "aspect": round(0.38 / 0.062, 3)}
    cbox(p, "dark", (0, 0.86, 0.02), (0.36, 0.12, 0.28), 0.03)
    cbox(p, "shell", (0, 0.99, 0.03), (0.6, 0.22, 0.46), 0.05)
    mbox(p, "dark", T(0, 1.1, 0.03), (0.62, 0.03, 0.48), 0.01, 1)
    cbox(p, "shell", (0, 1.27, 0.06), (0.82, 0.38, 0.58), 0.08)
    for side in (-1, 1):
        cbox(p, "shell", (side * 0.2, 1.24, -0.245), (0.36, 0.26, 0.07), 0.03, rot=(0, -side * 8, 0))
    mbox(p, "dark", T(0, 1.24, -0.25), (0.02, 0.24, 0.06), 0.004, 1)
    cbox(p, "trim", (0, 1.12, -0.24), (0.3, 0.035, 0.05), 0.01)
    serial(p, plane((0.2, 1.22, -0.288), (0, 0, -1), (-1, 0, 0)), "10", 0.07, role="label")
    # A cabeça enterrada à frente, entre os ombros: núcleo escuro, faces, tampo e a pala.
    cbox(p, "dark", (0, 1.53, -0.02), (0.52, 0.28, 0.44), 0.04)
    for side in (-1, 1):
        cbox(p, "shell", (side * 0.265, 1.53, -0.02), (0.06, 0.29, 0.46), 0.018)
    cbox(p, "shell", (0, 1.675, -0.02), (0.58, 0.06, 0.48), 0.025)
    cbox(p, "shell", (0, 1.625, -0.2), (0.6, 0.1, 0.2), 0.03)
    cbox(p, "shell", (0, 1.435, -0.19), (0.54, 0.11, 0.18), 0.03)
    p.screen((0, 1.535, -0.245), (0.38, 0.062), bulge=0.004)
    arc_tube(p, "dark", axis_frame((0.12, 1.705, 0.1), "z"), 0.11, 0.02, 0, 180, 18, 6)
    mtube(p, "dark", axis_frame((-0.12, 1.715, -0.1), "y"), 0.025, 0.025, 10)
    # Mochila com respiradouros e dois espigões curtos.
    cbox(p, "shell", (0, 1.3, 0.4), (0.5, 0.32, 0.16), 0.04)
    vents(p, sub(T(0, 1.3, 0.482), rot=(90, 0, 0)), 4, 0.34, depth=0.01, spacing=0.05)
    for side in (-1, 1):
        lathe(p, "trim", frame(Vector((side * 0.16, 1.46, 0.42)), Vector((side * 0.3, 1, 0.4)).normalized()), [(0.0, 0.0), (0.04, 0.0), (0.0, 0.16)], 6)
    for side in (-1, 1):
        cbox(p, "dark", (side * 0.42, 1.38, 0.02), (0.08, 0.2, 0.22), 0.02)
    cbox(p, "dark", (0, 0.76, 0.0), (0.32, 0.14, 0.28), 0.03)
    hip_axles(p, ECLIPSE["hip"].y, 0.15, ECLIPSE["hip"].x, 0.08)


def eclipse5_shoulders(p):
    for side in (-1, 1):
        e = E5["elbow_l"] if side < 0 else E5["elbow_r"]
        cbox(p, "shell", (side * 0.58, 1.5, 0.02), (0.38, 0.34, 0.46), 0.06)
        cbox(p, "trim", (side * 0.58, 1.675, 0.02), (0.26, 0.03, 0.36), 0.01)
        cbox(p, "trim", (side * 0.775, 1.5, 0.02), (0.02, 0.2, 0.3), 0.006)
        cbox(p, "dark", (side * 0.58, 1.3, 0.02), (0.22, 0.1, 0.26), 0.02)
        rod(p, "dark", (side * 0.59, 1.28, 0.02), e, 0.075, 12)
        ball(p, "dark", e, 0.095, 14)


def eclipse5_arm(p):
    e, w = E5["elbow_l"], E5["wrist_l"]
    m = beam(p, "shell", e, w, 0.33, 0.34, 0.05, pad=0.08)
    cbox(p, "trim", sub(m, 0, (w - e).length * 0.3, 0), (0.34, 0.05, 0.35), 0.012)
    fist(p, sub(frame(w, w - e, front=(0.3, 0, -1)), 0, 0.12, 0), 1.5)
    e = E5["elbow_r"]
    muzzle = ECLIPSE["muzzle"]
    d = (muzzle - e).normalized()
    m = beam(p, "shell", e, e + d * 0.48, 0.34, 0.35, 0.05, pad=0.04, front=(0, 1, 0))
    cbox(p, "trim", sub(m, 0, 0.12, 0), (0.35, 0.05, 0.36), 0.012)
    cbox(p, "dark", sub(m, 0, 0.26, 0), (0.26, 0.05, 0.26), 0.02)


def eclipse5_gun(p):
    e = E5["elbow_r"]
    muzzle = ECLIPSE["muzzle"]
    d = (muzzle - e).normalized()
    m = frame(e, d, front=(0, 1, 0))
    L = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, (0.5 + L) / 2, 0), 0.075, L - 0.5, 18, bevel=0.006)
    cbox(p, "dark", sub(m, 0, L - 0.05, 0), (0.18, 0.1, 0.18), 0.03)
    mring(p, "glow", sub(m, 0, L - 0.11, 0), 0.08, 0.008, 18, 4)


def eclipse5_leg(p, out):
    g = -ECLIPSE["hip"].y
    leg_hub(p, out, 0.08)
    cbox(p, "dark", (0, -0.1, 0), (0.14, 0.12, 0.16), 0.02)
    cbox(p, "shell", (0, -0.2, 0.0), (0.3, 0.26, 0.32), 0.045)
    mtube(p, "dark", axis_frame((0, -0.36, -0.01), "x"), 0.085, 0.26, 16)
    cbox(p, "trim", (0, -0.37, -0.14), (0.2, 0.12, 0.08), 0.02)
    cbox(p, "shell", (0, -0.52, 0.0), (0.34, 0.24, 0.36), 0.05, taper=(0.86, 0.86))
    mbox(p, "dark", T(out * 0.171, -0.52, 0.02), (0.01, 0.03, 0.16), 0.004, 1)
    cbox(p, "dark", (0, g + 0.07, -0.05), (0.38, 0.14, 0.5), 0.04)
    cbox(p, "dark", (0, g + 0.055, -0.32), (0.34, 0.11, 0.12), 0.03)


# --------------------------------------------------------------------------------------
# MAGNUS 5 (referência: o laranja de braços em cápsula): tronco pequeno, cabeça em cubo com
# uma face lisa e um olho só, orelha com antena; braços enormes em cápsula até aos joelhos com
# faixas e discos, punhos de pedra; pernas finas com faixas.
# --------------------------------------------------------------------------------------
M5_HEAD = Vector((0.0, 1.62, -0.02))


def magnus5_torso(p):
    cbox(p, "shell", (0, 1.2, 0.02), (0.36, 0.34, 0.3), 0.05)
    cbox(p, "trim", (0, 1.2, -0.13), (0.22, 0.2, 0.04), 0.03)
    cbox(p, "dark", (0, 1.4, 0.02), (0.18, 0.08, 0.16), 0.02)
    for side in (-1, 1):
        cbox(p, "dark", (side * 0.24, 1.3, 0.02), (0.14, 0.18, 0.2), 0.03)
    cbox(p, "dark", (0, 0.96, 0.02), (0.22, 0.16, 0.2), 0.03)
    cbox(p, "shell", (0, 0.82, 0.0), (0.34, 0.14, 0.26), 0.04)
    cbox(p, "trim", (0, 0.82, -0.135), (0.2, 0.08, 0.02), 0.01)
    hip_axles(p, MAGNUS["hip"].y, 0.17, MAGNUS["hip"].x, 0.07)


def magnus5_head(p):
    c = M5_HEAD
    mk.HEADS["magnus5_head"] = {"top": round(c.y + 0.22, 3), "center": round(c.y, 3), "aspect": 1.0}
    mbox(p, "shell", T(*c), (0.38, 0.42, 0.38), 0.07, 3)
    # A faixa do cimo e a face lisa amarela com o olho.
    cbox(p, "trim", (c.x, c.y + 0.12, c.z), (0.1, 0.2, 0.39), 0.015)
    mbox(p, "trim", T(c.x, c.y - 0.02, c.z - 0.18), (0.3, 0.3, 0.04), 0.05, 3)
    mtube(p, "metal", axis_frame((0, c.y - 0.02, c.z - 0.2), "-z"), 0.04, 0.02, 18)
    p.screen((0, c.y - 0.02, c.z - 0.212), (0.06, 0.06), bulge=0.004)
    # A orelha com a antena, do lado esquerdo.
    ear = T(c.x - 0.21, c.y + 0.02, c.z + 0.04)
    mbox(p, "shell", ear, (0.08, 0.16, 0.14), 0.03, 2)
    mtube(p, "dark", axis_frame((c.x - 0.255, c.y + 0.05, c.z + 0.02), "-x"), 0.02, 0.02, 10)
    rod(p, "dark", (c.x - 0.22, c.y + 0.1, c.z + 0.07), (c.x - 0.24, c.y + 0.36, c.z + 0.06), 0.008, 6)
    ball(p, "trim", (c.x - 0.24, c.y + 0.37, c.z + 0.06), 0.018, 8)
    mbox(p, "team", T(c.x + 0.1, c.y + 0.211, c.z), (0.08, 0.012, 0.2), 0.004, 1)


def magnus5_shoulders(p):
    for side in (-1, 1):
        mtube(p, "dark", axis_frame((side * 0.3, 1.36, 0.02), "x" if side > 0 else "-x"), 0.09, 0.14, 16)


def pill_arm(p, side, top, bottom, r=0.2):
    x = side * 0.5
    capsule(p, "shell", T(x, (top + bottom) / 2, 0.02), r, top - bottom, 22)
    for y, role, h in ((bottom + 0.2, "trim", 0.05), (bottom + 0.12, "label", 0.03)):
        mtube(p, role, T(x, y, 0.02), r + 0.004, h, 22)
    mtube(p, "label", axis_frame((x + side * 0.004, top - 0.18, 0.02 - r + 0.002), "-z"), 0.06, 0.006, 20)
    mring(p, "dark", axis_frame((x, top - 0.36, 0.02 - r + 0.002), "-z"), 0.07, 0.008, 22, 4)
    mtube(p, "trim", axis_frame((x, top - 0.36, 0.02 - r + 0.004), "-z"), 0.066, 0.006, 20)
    mbox(p, "dark", T(x, top - 0.02, 0.02), (0.06, 0.012, 0.16), 0.004, 1)
    # O punho de pedra.
    for dx, dy, dz, s in ((0, -0.02, 0, 0.2), (side * 0.05, -0.1, -0.05, 0.14), (-side * 0.06, -0.09, 0.05, 0.13)):
        cbox(p, "dark", (x + dx * 1.3, bottom + dy * 1.3, 0.02 + dz * 1.3), (s * 1.35, s * 1.1, s * 1.35), 0.035, rot=(dz * 60, 0, dx * 90))


def magnus5_arm(p):
    pill_arm(p, -1, 1.5, 0.52)
    pill_arm(p, 1, 1.5, 0.52)


def magnus5_gun(p):
    m = axis_frame((0.5, 0.46, -0.2), "-z")
    mtube(p, "dark", sub(m, 0, 0.12, 0), 0.05, 0.28, 16, bevel=0.005)
    mring(p, "trim", sub(m, 0, 0.24, 0), 0.055, 0.012, 16, 4)
    mtube(p, "glow", sub(m, 0, 0.262, 0), 0.03, 0.004, 12)


def magnus5_leg(p, out):
    g = -MAGNUS["hip"].y
    leg_hub(p, out, 0.06)
    cbox(p, "shell", (0, -0.14, 0.0), (0.16, 0.22, 0.16), 0.03)
    cbox(p, "trim", (0, -0.22, 0.0), (0.165, 0.05, 0.165), 0.012)
    mtube(p, "dark", axis_frame((0, -0.29, 0.0), "x"), 0.06, 0.16, 14)
    cbox(p, "shell", (0, -0.34, -0.02), (0.15, 0.08, 0.14), 0.03)
    mtube(p, "label", axis_frame((0, -0.34, -0.092), "-z"), 0.035, 0.005, 16)
    cbox(p, "trim", (0, -0.45, 0.0), (0.15, 0.16, 0.15), 0.03)
    cbox(p, "label", (0, -0.535, 0.0), (0.155, 0.03, 0.155), 0.01)
    cbox(p, "shell", (0, g + 0.04, -0.02), (0.15, 0.08, 0.2), 0.035)


# --------------------------------------------------------------------------------------
# ÓRBITA 5 (referência: a cabeça-TV creme e laranja): cabeça em caixa com a janela do olho,
# a lente-telescópio de lado e uma escotilha no tampo; tronco pequeno; braços finos com
# antebraços grandes em bloco; coxas claras, canelas grandes e pés de garras.
# --------------------------------------------------------------------------------------
O5_HEAD = Vector((0.0, 1.7, -0.02))
O5 = {"elbow_l": Vector((-0.4, 1.12, 0.02)), "wrist_l": Vector((-0.42, 0.84, -0.06)), "elbow_r": Vector((0.4, 1.12, -0.02))}


def orbita5_torso(p):
    mtube(p, "dark", T(0, 1.42, 0.02), 0.07, 0.12, 14)
    for y in (1.37, 1.4, 1.43, 1.46):
        mring(p, "dark", T(0, y, 0.02), 0.08, 0.012, 16, 4)
    cbox(p, "trim", (0, 1.24, 0.02), (0.4, 0.2, 0.32), 0.04)
    cbox(p, "shell", (0, 1.13, 0.02), (0.36, 0.06, 0.3), 0.02)
    cbox(p, "dark", (0, 1.02, 0.02), (0.3, 0.14, 0.24), 0.03)
    cbox(p, "trim", (0, 0.92, -0.01), (0.36, 0.14, 0.28), 0.035)
    mbox(p, "dark", T(0.08, 0.93, -0.152), (0.08, 0.05, 0.01), 0.004, 1)
    warning(p, plane((-0.08, 0.93, -0.152), (0, 0, -1), (-1, 0, 0)), 0.04)
    for side in (-1, 1):
        cbox(p, "dark", (side * 0.26, 1.28, 0.02), (0.1, 0.14, 0.16), 0.02)
    cbox(p, "dark", (0, 0.76, 0.0), (0.26, 0.12, 0.22), 0.03)
    hip_axles(p, ORBITA["hip"].y, 0.13, ORBITA["hip"].x, 0.065)


def orbita5_head(p):
    c = O5_HEAD
    mk.HEADS["orbita5_head"] = {"top": round(c.y + 0.3, 3), "center": round(c.y, 3), "aspect": round(0.3 / 0.26, 3)}
    mbox(p, "trim", T(c.x, c.y + 0.04, c.z), (0.58, 0.46, 0.52), 0.08, 3)
    mbox(p, "shell", T(c.x, c.y - 0.2, c.z), (0.56, 0.07, 0.5), 0.03, 2)
    # A janela do olho: vidro escuro com moldura, o olho lá dentro.
    mbox(p, "dark", T(c.x - 0.03, c.y + 0.04, c.z - 0.25), (0.36, 0.32, 0.04), 0.05, 2)
    p.screen((c.x - 0.03, c.y + 0.04, c.z - 0.272), (0.3, 0.26), bulge=0.012)
    mbox(p, "metal", T(c.x - 0.03, c.y + 0.04, c.z - 0.247), (0.4, 0.36, 0.02), 0.055, 2)
    # A lente-telescópio no lado direito: tambores, anel e a lente.
    side = axis_frame((c.x + 0.29, c.y + 0.0, c.z + 0.02), "x")
    mtube(p, "dark", sub(side, 0, 0.02, 0), 0.13, 0.04, 26)
    mtube(p, "trim", sub(side, 0, 0.07, 0), 0.1, 0.07, 24, bevel=0.01)
    mtube(p, "shell", sub(side, 0, 0.13, 0), 0.07, 0.07, 22, bevel=0.008)
    mtube(p, "metal", sub(side, 0, 0.175, 0), 0.05, 0.03, 20)
    mtube(p, "glow", sub(side, 0, 0.192, 0), 0.03, 0.004, 16)
    mring(p, "dark", sub(side, 0, 0.19, 0), 0.036, 0.006, 16, 4)
    # A escotilha no tampo e o bloco da antena atrás.
    mbox(p, "metal", T(c.x - 0.04, c.y + 0.275, c.z - 0.02), (0.28, 0.02, 0.18), 0.01, 1)
    cbox(p, "shell", (c.x + 0.2, c.y + 0.25, c.z + 0.14), (0.12, 0.14, 0.1), 0.02)
    mbox(p, "team", T(c.x - 0.04, c.y + 0.287, c.z + 0.12), (0.1, 0.01, 0.05), 0.004, 1)


def orbita5_shoulders(p):
    for side in (-1, 1):
        e = O5["elbow_l"] if side < 0 else O5["elbow_r"]
        mtube(p, "dark", axis_frame((side * 0.3, 1.3, 0.02), "x" if side > 0 else "-x"), 0.06, 0.08, 14)
        rod(p, "dark", (side * 0.34, 1.3, 0.02), e, 0.03, 10)
        ball(p, "dark", e, 0.05, 12)


def orbita5_arm(p):
    e, w = O5["elbow_l"], O5["wrist_l"]
    m = beam(p, "shell", e, w, 0.19, 0.2, 0.03, pad=0.08)
    warning(p, plane(at(m, 0, 0.0, -0.101), at(m, 0, 0, -1) - at(m), at(m, -1, 0, 0) - at(m)), 0.05)
    mtube(p, "metal", frame(at(m, -0.096, 0.02, 0), at(m, -1, 0, 0) - at(m)), 0.04, 0.01, 18)
    fist(p, sub(frame(w, w - e, front=(0.3, 0, -1)), 0, 0.08, 0), 0.9)
    e = O5["elbow_r"]
    muzzle = ORBITA["muzzle"]
    d = (muzzle - e).normalized()
    m = beam(p, "shell", e, e + d * 0.4, 0.2, 0.21, 0.03, pad=0.04, front=(0, 1, 0))
    warning(p, plane(at(m, 0, 0.0, 0.106), at(m, 0, 0, 1) - at(m), at(m, 1, 0, 0) - at(m)), 0.05)


def orbita5_gun(p):
    e = O5["elbow_r"]
    muzzle = ORBITA["muzzle"]
    d = (muzzle - e).normalized()
    m = frame(e, d, front=(0, 1, 0))
    L = (muzzle - e).length
    mtube(p, "trim", sub(m, 0, (0.44 + L) / 2, 0), 0.05, L - 0.44, 16, bevel=0.005)
    mtube(p, "dark", sub(m, 0, L - 0.03, 0), 0.065, 0.06, 18)
    mtube(p, "glow", sub(m, 0, L, 0), 0.04, 0.004, 14)


def orbita5_leg(p, out):
    g = -ORBITA["hip"].y
    leg_hub(p, out, 0.06)
    cbox(p, "trim", (0, -0.13, -0.01), (0.2, 0.22, 0.2), 0.035)
    cbox(p, "dark", (0, -0.26, 0.0), (0.12, 0.08, 0.12), 0.02)
    mtube(p, "dark", axis_frame((0, -0.3, 0.0), "x"), 0.07, 0.2, 16)
    cbox(p, "shell", (0, -0.43, 0.0), (0.22, 0.24, 0.24), 0.04)
    mtube(p, "dark", axis_frame((out * 0.12, -0.46, 0.02), "x" if out > 0 else "-x"), 0.045, 0.03, 14)
    cbox(p, "dark", (0, g + 0.13, 0.0), (0.1, 0.06, 0.1), 0.02)
    block_claw_foot(p, g, "shell", "shell", 1.1)


# --------------------------------------------------------------------------------------
# BATIDA 5 (referência: o branco de cabeça em cubo): cabeça em cubo grande com o losango e
# marcas de canto, sensores de lado e o cano-antena atrás; peito em V com a vareta; mochila;
# antebraços grandes com punhos coloridos; pernas com faixas e pés de garras.
# --------------------------------------------------------------------------------------
B5_HEAD = Vector((-0.02, 1.72, -0.04))
B5 = {"elbow_l": Vector((-0.42, 1.08, 0.02)), "wrist_l": Vector((-0.44, 0.76, -0.08)), "elbow_r": Vector((0.42, 1.08, -0.02))}


def batida5_torso(p):
    cbox(p, "dark", (0, 1.25, 0.04), (0.44, 0.3, 0.34), 0.04)
    # Peito em V: uma couraça branca larga, com o bico para baixo e as juntas cinzentas.
    cbox(p, "trim", (0, 1.3, -0.1), (0.52, 0.22, 0.14), 0.04, rot=(6, 0, 0))
    cbox(p, "trim", (0, 1.17, -0.12), (0.2, 0.16, 0.1), 0.03, rot=(6, 0, 45))
    for side in (-1, 1):
        cbox(p, "metal", (side * 0.2, 1.16, -0.02), (0.1, 0.12, 0.16), 0.02)
    rod(p, "dark", (-0.1, 1.36, -0.16), (-0.13, 1.52, -0.2), 0.012, 6)
    cbox(p, "dark", (0, 1.08, 0.02), (0.26, 0.12, 0.22), 0.03)
    cbox(p, "trim", (0, 0.96, 0.0), (0.3, 0.12, 0.24), 0.035)
    for side in (-1, 1):
        cbox(p, "dark", (side * 0.28, 1.3, 0.02), (0.1, 0.16, 0.18), 0.02)
    # A mochila do lado direito com o cabo.
    cbox(p, "metal", (0.12, 1.36, 0.28), (0.24, 0.3, 0.14), 0.03)
    cbox(p, "dark", (0.12, 1.36, 0.36), (0.14, 0.18, 0.02), 0.01)
    cable(p, [(0.22, 1.25, 0.3), (0.3, 1.12, 0.24), (0.3, 1.02, 0.12)], 0.012)
    cbox(p, "dark", (0, 0.8, 0.0), (0.26, 0.12, 0.22), 0.03)
    hip_axles(p, BATIDA["hip"].y, 0.13, BATIDA["hip"].x, 0.065)


def batida5_head(p):
    c = B5_HEAD
    mk.HEADS["batida5_head"] = {"top": round(c.y + 0.27, 3), "center": round(c.y, 3), "aspect": 1.0}
    cbox(p, "trim", (c.x, c.y, c.z), (0.6, 0.5, 0.54), 0.08)
    # O losango na face, cor da equipa do piloto, e as marcas de canto.
    face = c.z - 0.271
    for k in range(4):
        a = k * 90 + 45
        d = (math.cos(math.radians(a)), math.sin(math.radians(a)))
        mbox(p, "shell", sub(T(c.x - 0.03 + d[0] * 0.045, c.y + d[1] * 0.045, face), rot=(0, 0, a + 90)), (0.07, 0.022, 0.008), 0.004, 1)
        mbox(p, "glow", sub(T(c.x - 0.03 + d[0] * 0.022, c.y + d[1] * 0.022, face), rot=(0, 0, a + 90)), (0.03, 0.012, 0.009), 0.003, 1)
    for u, v, rot in ((-0.23, 0.19, 45), (0.23, 0.19, -45), (-0.23, -0.19, -45), (0.23, -0.19, 45)):
        mbox(p, "shell", sub(T(c.x + u, c.y + v, face), rot=(0, 0, rot)), (0.035, 0.012, 0.006), 0.003, 1)
    # Os sensores do lado direito e o cano-antena atrás.
    for dy, rr in ((0.1, 0.045), (-0.02, 0.035)):
        mtube(p, "metal", axis_frame((c.x + 0.305, c.y + dy, c.z - 0.06), "x"), rr, 0.02, 18)
        mtube(p, "dark", axis_frame((c.x + 0.315, c.y + dy, c.z - 0.06), "x"), rr * 0.5, 0.012, 14)
    cbox(p, "metal", (c.x + 0.31, c.y - 0.12, c.z + 0.02), (0.03, 0.06, 0.14), 0.01)
    pipe = Vector((c.x + 0.25, c.y + 0.0, c.z + 0.22))
    mtube(p, "trim", T(pipe.x, pipe.y + 0.2, pipe.z), 0.03, 0.4, 14, bevel=0.004)
    mtube(p, "shell", T(pipe.x, pipe.y + 0.05, pipe.z), 0.032, 0.08, 14)
    mtube(p, "dark", T(pipe.x, pipe.y + 0.41, pipe.z), 0.034, 0.04, 14)
    mbox(p, "team", T(c.x, c.y + 0.231, c.z + 0.05), (0.1, 0.012, 0.2), 0.004, 1)


def batida5_shoulders(p):
    for side in (-1, 1):
        e = B5["elbow_l"] if side < 0 else B5["elbow_r"]
        mbox(p, "trim", T(side * 0.36, 1.36, 0.02), (0.22, 0.2, 0.26), 0.07, 2)
        cbox(p, "trim", (side * 0.41, 1.2, 0.02), (0.16, 0.24, 0.18), 0.035)
        ball(p, "metal", e, 0.06, 12)


def batida5_arm(p):
    e, w = B5["elbow_l"], B5["wrist_l"]
    m = beam(p, "trim", e, w, 0.25, 0.27, 0.04, pad=0.08)
    cbox(p, "shell", sub(m, 0, (w - e).length * 0.36, 0), (0.26, 0.11, 0.28), 0.02)
    warning(p, plane(at(m, 0, (w - e).length * 0.36, -0.141), at(m, 0, 0, -1) - at(m), at(m, -1, 0, 0) - at(m)), 0.04)
    fist(p, sub(frame(w, w - e, front=(0.3, 0, -1)), 0, 0.1, 0), 1.1, "metal")
    e = B5["elbow_r"]
    muzzle = BATIDA["muzzle"]
    d = (muzzle - e).normalized()
    m = beam(p, "trim", e, e + d * 0.44, 0.26, 0.28, 0.04, pad=0.04, front=(0, 1, 0))
    cbox(p, "shell", sub(m, 0, 0.12, 0), (0.27, 0.11, 0.29), 0.02)
    for k in range(4):
        a = k * 90 + 45
        dd = (math.cos(math.radians(a)), math.sin(math.radians(a)))
        mbox(p, "dark", sub(m, dd[0] * 0.03, 0.12 + dd[1] * 0.03, 0.146, rot=(0, 0, a + 90)), (0.045, 0.012, 0.006), 0.003, 1)


def batida5_gun(p):
    e = B5["elbow_r"]
    muzzle = BATIDA["muzzle"]
    d = (muzzle - e).normalized()
    m = frame(e, d, front=(0, 1, 0))
    L = (muzzle - e).length
    mtube(p, "metal", sub(m, 0, (0.46 + L) / 2, 0), 0.05, L - 0.46, 16, bevel=0.005)
    mtube(p, "shell", sub(m, 0, L - 0.04, 0), 0.062, 0.07, 18)
    mtube(p, "glow", sub(m, 0, L, 0), 0.036, 0.004, 14)


def batida5_leg(p, out):
    g = -BATIDA["hip"].y
    leg_hub(p, out, 0.058)
    cbox(p, "trim", (0, -0.15, -0.01), (0.22, 0.26, 0.24), 0.04)
    for i in range(2):
        mbox(p, "shell", T(0, -0.14 - i * 0.02, -0.112), (0.06, 0.008, 0.006), 0.002, 1)
    mtube(p, "metal", axis_frame((out * 0.1, -0.3, 0.0), "x" if out > 0 else "-x"), 0.04, 0.02, 14)
    cbox(p, "trim", (0, -0.42, 0.0), (0.22, 0.22, 0.24), 0.04)
    cbox(p, "shell", (0, -0.52, 0.0), (0.225, 0.07, 0.245), 0.015)
    cbox(p, "metal", (0, g + 0.12, 0.0), (0.1, 0.06, 0.1), 0.02)
    block_claw_foot(p, g, "metal", "dark", 1.0)


# --------------------------------------------------------------------------------------
# ÓRBITA 6 (referência: a cabeça-TV creme e laranja), segunda tentativa: formas redondas,
# cabeça grande com ecrã escuro e um olho em ponto, conjunto redondo da lente do lado direito,
# pescoço mecânico, tronco pequeno, antebraços laranja arredondados, pés de três dedos.
# --------------------------------------------------------------------------------------
O6_HEAD = Vector((0.0, 1.66, -0.02))
O6 = {"elbow_l": Vector((-0.38, 1.1, 0.02)), "wrist_l": Vector((-0.4, 0.8, -0.04)), "elbow_r": Vector((0.38, 1.1, -0.02))}


def soft(p, role, at_, size, r=0.05, rot=(0, 0, 0)):
    """Bloco de cantos redondos (o traço macio desta referência)."""
    mbox(p, role, sub(T(*at_), rot=rot), size, r, 3)


def orbita6_torso(p):
    # Pescoço mecânico: coluna escura, dois pistões e o colar sob a cabeça.
    mtube(p, "dark", T(0, 1.4, 0.02), 0.06, 0.16, 14)
    for side in (-1, 1):
        piston(p, (side * 0.08, 1.33, 0.06), (side * 0.1, 1.47, 0.04), 0.016)
    mtube(p, "dark", T(0, 1.47, 0.0), 0.15, 0.04, 22, bevel=0.008)
    # Tronco pequeno creme, cinta escura e bacia creme de rebordo laranja.
    soft(p, "trim", (0, 1.24, 0.03), (0.36, 0.2, 0.28), 0.06)
    soft(p, "shell", (0, 1.24, -0.115), (0.2, 0.1, 0.03), 0.015)
    cbox(p, "dark", (0, 1.1, 0.03), (0.26, 0.1, 0.22), 0.03)
    for side in (-1, 1):
        mtube(p, "dark", axis_frame((side * 0.1, 1.08, -0.06), "-z"), 0.03, 0.04, 12)
    soft(p, "trim", (0, 0.96, 0.0), (0.34, 0.14, 0.26), 0.05)
    soft(p, "shell", (0, 0.9, -0.01), (0.36, 0.04, 0.28), 0.015)
    warning(p, plane((0.0, 0.97, -0.131), (0, 0, -1), (-1, 0, 0)), 0.045)
    for side in (-1, 1):
        cbox(p, "dark", (side * 0.24, 1.28, 0.03), (0.08, 0.12, 0.14), 0.02)
    cbox(p, "dark", (0, 0.78, 0.0), (0.24, 0.1, 0.2), 0.03)
    hip_axles(p, ORBITA["hip"].y, 0.13, ORBITA["hip"].x, 0.065)


def orbita6_head(p):
    c = O6_HEAD
    mk.HEADS["orbita6_head"] = {"top": round(c.y + 0.3, 3), "center": round(c.y + 0.03, 3), "aspect": round(0.3 / 0.26, 3)}
    # A caixa grande: creme em cima e à frente, faixa laranja em baixo.
    soft(p, "trim", (c.x, c.y + 0.05, c.z), (0.6, 0.46, 0.52), 0.1)
    soft(p, "shell", (c.x, c.y - 0.19, c.z), (0.6, 0.1, 0.52), 0.05)
    mbox(p, "dark", T(c.x, c.y - 0.135, c.z), (0.61, 0.012, 0.53), 0.004, 1)
    # O ecrã grande e escuro, recuado numa moldura creme, com o olho em ponto.
    soft(p, "dark", (c.x - 0.05, c.y + 0.04, c.z - 0.24), (0.38, 0.34, 0.06), 0.06)
    p.screen((c.x - 0.05, c.y + 0.04, c.z - 0.272), (0.32, 0.28), bulge=0.014)
    for dx, dy, w, h in ((0, 0.19, 0.44, 0.04), (0, -0.11, 0.44, 0.04), (-0.215, 0.04, 0.04, 0.34), (0.115, 0.04, 0.04, 0.34)):
        soft(p, "trim", (c.x - 0.05 + dx, c.y + dy, c.z - 0.262), (w, h, 0.04), 0.018)
    # O conjunto redondo do lado direito: disco escuro, tambor creme, anel laranja e a lente.
    side = axis_frame((c.x + 0.3, c.y + 0.01, c.z + 0.03), "x")
    mtube(p, "dark", sub(side, 0, 0.02, 0), 0.2, 0.05, 32, bevel=0.012)
    mring(p, "metal", sub(side, 0, 0.045, 0), 0.18, 0.014, 32, 5)
    mtube(p, "trim", sub(side, 0, 0.11, 0), 0.13, 0.12, 28, bevel=0.02)
    mtube(p, "shell", sub(side, 0, 0.19, 0), 0.105, 0.06, 26, bevel=0.012)
    mtube(p, "trim", sub(side, 0, 0.25, 0), 0.085, 0.07, 24, bevel=0.012)
    mtube(p, "metal", sub(side, 0, 0.3, 0), 0.06, 0.04, 22)
    mtube(p, "label", sub(side, 0, 0.322, 0), 0.042, 0.006, 20)
    mring(p, "dark", sub(side, 0, 0.326, 0), 0.024, 0.006, 14, 4)
    for dz in (-1, 1):
        cbox(p, "dark", (c.x + 0.33, c.y - 0.2, c.z + 0.03 + dz * 0.07), (0.05, 0.12, 0.04), 0.01)
    # O tampo: placa cinzenta-azulada e o bloco laranja no canto de trás, à direita.
    soft(p, "metal", (c.x - 0.03, c.y + 0.285, c.z + 0.0), (0.34, 0.03, 0.28), 0.012)
    soft(p, "shell", (c.x + 0.22, c.y + 0.26, c.z + 0.14), (0.12, 0.12, 0.12), 0.03)
    soft(p, "shell", (c.x + 0.28, c.y + 0.29, c.z + 0.16), (0.06, 0.1, 0.06), 0.02)
    mbox(p, "team", T(c.x - 0.03, c.y + 0.302, c.z + 0.1), (0.12, 0.01, 0.04), 0.004, 1)
    for u in (-1, 1):
        screw(p, T(c.x + u * 0.2, c.y + 0.281, c.z - 0.2), 0, 0, 0.008)


def orbita6_shoulders(p):
    for side in (-1, 1):
        e = O6["elbow_l"] if side < 0 else O6["elbow_r"]
        mtube(p, "dark", axis_frame((side * 0.29, 1.3, 0.03), "x" if side > 0 else "-x"), 0.06, 0.08, 14)
        piston(p, (side * 0.33, 1.3, 0.03), e, 0.022)
        rod(p, "dark", (side * 0.33, 1.3, 0.07), e + Vector((0, 0.02, 0.04)), 0.012, 8)
        ball(p, "dark", e, 0.05, 12)


def orbita6_arm(p):
    e, w = O6["elbow_l"], O6["wrist_l"]
    m = frame(e.lerp(w, 0.5), w - e, front=(0.3, 0, -1))
    L = (w - e).length
    mbox(p, "shell", m, (0.25, L + 0.16, 0.27), 0.07, 3)
    warning(p, plane(at(m, 0, 0.02, -0.137), at(m, 0, 0, -1) - at(m), at(m, -1, 0, 0) - at(m)), 0.05)
    mtube(p, "metal", frame(at(m, -0.126, 0.0, 0), at(m, -1, 0, 0) - at(m)), 0.055, 0.014, 18)
    hand(p, sub(frame(w, w - e, front=(0.3, 0, -1)), 0, 0.12, 0.0, rot=(0, -90, 180)), fingers=4, scale=1.3, curl=0.5)
    e = O6["elbow_r"]
    muzzle = ORBITA["muzzle"]
    d = (muzzle - e).normalized()
    m = frame(e + d * 0.2, d, front=(0, 1, 0))
    mbox(p, "shell", m, (0.25, 0.48, 0.27), 0.07, 3)
    warning(p, plane(at(m, 0, 0.0, 0.137), at(m, 0, 0, 1) - at(m), at(m, 1, 0, 0) - at(m)), 0.05)


def orbita6_gun(p):
    e = O6["elbow_r"]
    muzzle = ORBITA["muzzle"]
    d = (muzzle - e).normalized()
    m = frame(e, d, front=(0, 1, 0))
    L = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, (0.42 + L) / 2, 0), 0.045, L - 0.42, 16, bevel=0.005)
    mtube(p, "trim", sub(m, 0, L - 0.04, 0), 0.06, 0.07, 18, bevel=0.008)
    mtube(p, "glow", sub(m, 0, L, 0), 0.035, 0.004, 14)


def orbita6_leg(p, out):
    g = -ORBITA["hip"].y
    leg_hub(p, out, 0.06)
    soft(p, "trim", (0, -0.15, -0.03), (0.26, 0.28, 0.16), 0.05)
    soft(p, "trim", (out * 0.12, -0.15, 0.03), (0.04, 0.24, 0.16), 0.015)
    cbox(p, "dark", (0, -0.13, 0.06), (0.12, 0.22, 0.1), 0.02)
    for v in (-1, 1):
        screw(p, sub(T(out * 0.07, -0.15 + v * 0.08, -0.112), rot=(-90, 0, 0)), 0, 0, 0.008)
    mtube(p, "dark", axis_frame((0, -0.31, 0.0), "x"), 0.07, 0.24, 16)
    soft(p, "shell", (0, -0.45, 0.0), (0.27, 0.28, 0.29), 0.07)
    soft(p, "shell", (0, -0.36, -0.13), (0.2, 0.08, 0.06), 0.02)
    mtube(p, "dark", axis_frame((out * 0.14, -0.46, 0.02), "x" if out > 0 else "-x"), 0.06, 0.035, 16)
    mtube(p, "dark", axis_frame((0, g + 0.12, 0.0), "x"), 0.045, 0.14, 14)
    # Pé de três dedos abertos, laranja.
    soft(p, "shell", (0, g + 0.06, 0.02), (0.2, 0.09, 0.18), 0.035)
    for a in (-30, 30):
        soft(p, "shell", (math.sin(math.radians(a)) * 0.13, g + 0.035, -0.15), (0.1, 0.07, 0.28), 0.03, rot=(0, -a, 0))
    soft(p, "shell", (0, g + 0.035, 0.17), (0.1, 0.07, 0.18), 0.03)


# ======================================================================================
# Sétima geração: recriação exata a partir da planta do jogador (o robô branco de cabeça em
# cubo). Medidas tiradas do desenho (1800 mm de altura = a escala), cores da tabela.
# --------------------------------------------------------------------------------------
BP_HEAD = Vector((0.02, 1.5, 0.0))
# A anca da planta: as pernas ocupam quase metade da altura.
BP_HIP = 0.76
BP_HEAD_SIZE = (0.76, 0.56, 0.46)
BP = {"elbow_l": Vector((-0.52, 0.95, 0.0)), "wrist_l": Vector((-0.53, 0.55, -0.02)), "elbow_r": Vector((0.52, 0.95, 0.0))}
BP_MUZZLE = Vector((0.52, 0.5, -0.2))


def bp_diamond(p, role, center, half, bar=0.024, depth=0.008):
    """O losango da planta: quatro traços com uma folga nos cantos."""
    c = Vector(center)
    for k in range(4):
        a = math.radians(k * 90 + 45)
        mid = c + Vector((math.cos(a) * half * 0.5, math.sin(a) * half * 0.5, 0.0))
        mbox(p, role, sub(T(*mid), rot=(0, 0, k * 90 + 135)), (half * 0.62, bar, depth), 0.003, 1)


def bp_triangle(p, role, m, size, depth=0.006):
    """Triângulo de aviso escuro, pintado numa face (Y local = normal da face)."""
    pts = [(-size / 2, -size * 0.4), (size / 2, -size * 0.4), (0.0, size * 0.48)]
    extruded(p, role, m @ Matrix.Rotation(math.radians(-90), 4, "X"), pts, depth)


def batida7_head(p):
    c = BP_HEAD
    w, h, d = BP_HEAD_SIZE
    front = c.z - d / 2
    mk.HEADS["batida7_head"] = {"top": round(c.y + h / 2, 3), "center": round(c.y, 3), "aspect": 1.0}
    cbox(p, "trim", (c.x, c.y, c.z), (w, h, d), 0.08)
    cbox(p, "trim", (c.x, c.y, front + 0.012), (w - 0.1, h - 0.1, 0.03), 0.02)
    # Juntas dos painéis: a face da frente e o tampo são placas encaixadas.
    for dy in (h / 2 - 0.07, -h / 2 + 0.07):
        mbox(p, "metal", T(c.x, c.y + dy, front - 0.001), (w - 0.14, 0.004, 0.003), 0.001, 1)
    cbox(p, "dark", (c.x, c.y - h / 2 + 0.01, c.z), (w - 0.1, 0.03, d - 0.08), 0.01)
    # O losango vermelho e as quatro marcas de canto.
    # O losango: quatro quadrados rodados, com a cruz de folga entre eles.
    # No meio, o ecrã do rosto em losango: o olho do jogo acende-se dentro dele.
    for dx, dy in ((0.07, 0.0), (-0.07, 0.0), (0.0, 0.07), (0.0, -0.07)):
        mbox(p, "hazard", sub(T(c.x - 0.02 + dx, c.y + 0.01 + dy, front - 0.006), rot=(0, 0, 45)), (0.05, 0.05, 0.008), 0.003, 1)
    p.screen((c.x - 0.02, c.y + 0.01, front - 0.004), (0.1, 0.1), bulge=0.002, rot=(0, 0, 45))
    for u, v in ((-1, 1), (1, 1), (-1, -1), (1, -1)):
        mbox(p, "hazard", sub(T(c.x + u * (w / 2 - 0.08), c.y + v * (h / 2 - 0.08), front - 0.006), rot=(0, 0, 45 * u * v)), (0.05, 0.014, 0.006), 0.002, 1)
    # O distintivo laranja no canto de baixo, à esquerda de quem vê.
    cbox(p, "shell", (c.x + 0.25, c.y - 0.17, front - 0.006), (0.07, 0.045, 0.012), 0.008)
    for i in range(2):
        mbox(p, "dark", T(c.x + 0.25, c.y - 0.165 - i * 0.012, front - 0.013), (0.04, 0.005, 0.003), 0.001, 1)
    # Os sensores redondos dos dois lados: aro laranja, anel claro e centro escuro.
    for side in (-1, 1):
        for dy, dz, rr in ((0.1, -0.08, 0.055), (-0.03, -0.1, 0.035)):
            s = axis_frame((c.x + side * (w / 2 + 0.004), c.y + dy, c.z + dz), "x" if side > 0 else "-x")
            mtube(p, "shell", s, rr, 0.012, 22)
            mtube(p, "trim", sub(s, 0, 0.006, 0), rr * 0.7, 0.01, 20)
            mtube(p, "dark", sub(s, 0, 0.012, 0), rr * 0.35, 0.008, 16)
        mbox(p, "dark", T(c.x + side * (w / 2 + 0.002), c.y - 0.12, c.z + 0.06), (0.004, 0.14, 0.025), 0.002, 1)
    # O cano-antena atrás, à esquerda do robô: tubo branco, faixa laranja, tampa escura, braçadeira.
    pipe = Vector((-0.42, 0.0, c.z + 0.08))
    mtube(p, "trim", T(pipe.x, 1.58, pipe.z), 0.032, 0.64, 16, bevel=0.004)
    mtube(p, "shell", T(pipe.x, 1.44, pipe.z), 0.034, 0.08, 16)
    mtube(p, "dark", T(pipe.x, 1.91, pipe.z), 0.034, 0.03, 16)
    for y in (1.36, 1.66):
        cbox(p, "dark", (pipe.x + 0.03, y, pipe.z), (0.06, 0.035, 0.05), 0.008)
    # A nuca: três ranhuras de ventilação e duas pegas laranja.
    back = c.z + d / 2 + 0.002
    for i in range(3):
        mbox(p, "dark", T(c.x + 0.02, c.y + 0.03 - i * 0.045, back), (0.2, 0.018, 0.006), 0.004, 1)
    for u in (-1, 1):
        cbox(p, "shell", (c.x + 0.02 + u * 0.19, c.y + 0.0, back + 0.006), (0.03, 0.1, 0.02), 0.008)


def batida7_torso(p):
    cbox(p, "dark", (0, 1.2, 0.0), (0.34, 0.05, 0.28), 0.015)
    # O peito: a couraça de cima e o V de duas placas por baixo, a vareta à direita do robô.
    # A couraça do peito: um trapézio mais estreito em baixo, a placa branca de baixo e a
    # mecânica cinzenta à vista entre eles.
    cbox(p, "trim", (0, 1.05, -0.03), (0.56, 0.3, 0.38), 0.05, rot=(0, 0, 180), taper=(0.62, 0.9))
    cbox(p, "trim", (0, 0.86, -0.06), (0.24, 0.08, 0.24), 0.03)
    for side in (-1, 1):
        cbox(p, "metal", (side * 0.2, 0.84, 0.0), (0.12, 0.14, 0.2), 0.03)
    for a, b in (((-0.12, 1.14), (-0.08, 1.08)), ((-0.08, 1.08), (-0.1, 1.02)), ((-0.08, 1.08), (-0.03, 1.05))):
        rod(p, "dark", (a[0], a[1], -0.222), (b[0], b[1], -0.222), 0.004, 4)
    rod(p, "dark", (0.12, 1.12, -0.22), (0.16, 1.28, -0.25), 0.014, 8)
    cbox(p, "dark", (0, 0.92, 0.05), (0.36, 0.3, 0.3), 0.03)
    # A barriga: placa hexagonal branca com traços laranja.
    lathe(p, "trim", sub(T(0, 0.8, -0.1), rot=(90, 0, 0)), [(0.0, -0.035), (0.09, -0.035), (0.09, 0.035), (0.0, 0.035)], 6)
    for u in (-1, 1):
        mbox(p, "shell", T(u * 0.035, 0.805, -0.137), (0.025, 0.01, 0.004), 0.002, 1)
    cbox(p, "dark", (0, 0.76, 0.0), (0.3, 0.12, 0.26), 0.03)
    mtube(p, "metal", T(0, 0.84, 0.0), 0.09, 0.05, 18)
    for side in (-1, 1):
        piston(p, (side * 0.09, 0.8, -0.08), (side * 0.12, 0.9, -0.1), 0.016)
    for side in (-1, 1):
        mtube(p, "dark", axis_frame((side * 0.28, 1.1, 0.0), "x" if side > 0 else "-x"), 0.08, 0.08, 18, bevel=0.008)
    # A mochila cinzenta atrás, com ranhuras, o cabo laranja e um autocolante vermelho.
    # A mochila: um bloco branco alto, até ao meio da cabeça, com a ranhura escura e a base
    # cinzenta.
    cbox(p, "trim", (-0.04, 1.03, 0.3), (0.3, 0.38, 0.22), 0.045)
    cbox(p, "metal", (-0.04, 0.84, 0.3), (0.26, 0.08, 0.2), 0.03)
    for side in (-1, 1):
        cbox(p, "dark", (-0.04 + side * 0.151, 1.02, 0.3), (0.012, 0.16, 0.08), 0.004)
        cbox(p, "metal", (-0.04 + side * 0.151, 0.92, 0.3), (0.012, 0.06, 0.08), 0.004)
    cbox(p, "dark", (-0.04, 1.03, 0.412), (0.12, 0.2, 0.01), 0.004)
    rod(p, "shell", (-0.16, 1.15, 0.28), (-0.24, 1.05, 0.16), 0.018, 10)
    rod(p, "shell", (-0.24, 1.05, 0.16), (-0.27, 0.95, 0.05), 0.018, 10)
    cbox(p, "shell", (0.06, 1.16, 0.412), (0.06, 0.035, 0.006), 0.006)
    hip_axles(p, BP_HIP, 0.13, BATIDA["hip"].x, 0.065)


def batida7_shoulders(p):
    # Ombro: rolamento cinzento à vista, e o braço de cima como uma carapaça branca por fora e
    # à frente de uma estrutura escura, com a etiqueta laranja e as rachas da pintura.
    for side in (-1, 1):
        x = side * 0.45
        mtube(p, "metal", axis_frame((side * 0.3, 1.12, 0.0), "x" if side > 0 else "-x"), 0.075, 0.08, 20, bevel=0.01)
        cbox(p, "dark", (x - side * 0.02, 1.03, 0.02), (0.18, 0.3, 0.22), 0.02)
        cbox(p, "trim", (x + side * 0.02, 1.08, -0.01), (0.25, 0.24, 0.3), 0.05)
        cbox(p, "trim", (x + side * 0.03, 0.95, -0.02), (0.2, 0.05, 0.26), 0.02)
        cbox(p, "shell", (x + side * 0.05, 1.17, -0.162), (0.07, 0.045, 0.006), 0.006)
        for a_, b_ in (((0.0, 1.13), (0.03, 1.09)), ((0.03, 1.09), (0.065, 1.11)), ((0.03, 1.09), (0.035, 1.04))):
            rod(p, "dark", (x - side * a_[0], a_[1], -0.162), (x - side * b_[0], b_[1], -0.162), 0.004, 4)
        # O cotovelo: garfo escuro e tambor cinzento bem à vista.
        cbox(p, "dark", (x, 0.9, 0.0), (0.16, 0.06, 0.16), 0.015)
        mtube(p, "metal", axis_frame((x, 0.87, 0.0), "x"), 0.058, 0.2, 18, bevel=0.008)
        mtube(p, "dark", axis_frame((x + side * 0.105, 0.87, 0.0), "x"), 0.03, 0.02, 12)


def batida7_arm(p):
    # Antebraço: estrutura escura, carapaça branca, punho laranja com o triângulo, o pulso
    # cinzento e a mão mecânica cinzenta; o cotovelo dobra um pouco para a frente.
    for side in (-1, 1):
        x = side * 0.45
        elbow = T(x, 0.87, 0.0) @ Matrix.Rotation(math.radians(10), 4, "X")
        cbox(p, "dark", sub(elbow, 0, -0.2, 0.02), (0.16, 0.34, 0.18), 0.02)
        cbox(p, "trim", sub(elbow, 0, -0.15, -0.01), (0.23, 0.24, 0.26), 0.035)
        for i in range(2):
            mbox(p, "shell", sub(elbow, side * 0.06, -0.09 - i * 0.03, -0.157), (0.012, 0.012, 0.004), 0.002, 1)
        cbox(p, "shell", sub(elbow, 0, -0.33, -0.01), (0.24, 0.13, 0.27), 0.03)
        bp_triangle(p, "dark", sub(elbow, 0, -0.33, -0.147), 0.055)
        if side > 0:
            bp_diamond(p, "dark", tuple(at(elbow, side * 0.121, -0.33, -0.01)), 0.075, bar=0.012)
        mtube(p, "metal", sub(elbow, 0, -0.42, -0.01), 0.05, 0.05, 14)
        fist(p, sub(elbow, 0, -0.48, -0.02) @ Matrix.Rotation(math.radians(180), 4, "X"), 0.95, "dark")


def batida7_gun(p):
    m = axis_frame((0.45, 0.38, -0.2), "-z")
    mtube(p, "dark", sub(m, 0, 0.03, 0), 0.03, 0.12, 12)
    mtube(p, "glow", sub(m, 0, 0.092, 0), 0.02, 0.004, 10)


def batida7_leg(p, out):
    # Perna: estrutura escura com carapaças brancas à frente e por fora; o joelho, o tornozelo
    # e a anca são mecânica cinzenta à vista. Faixa laranja na canela, pé de três dedos.
    hip = BP_HIP
    g = -hip
    y = lambda h: h - hip
    leg_hub(p, out, 0.05)
    # Coxa: placa branca alta e estreita sobre a estrutura escura.
    cbox(p, "dark", (0, y(0.6), 0.02), (0.12, 0.26, 0.14), 0.015)
    cbox(p, "trim", (0, y(0.61), -0.035), (0.23, 0.25, 0.17), 0.03)
    cbox(p, "trim", (out * 0.105, y(0.6), 0.03), (0.035, 0.2, 0.13), 0.01)
    for i in range(2):
        mbox(p, "hazard", T(0, y(0.66) - i * 0.025, -0.122), (0.06, 0.01, 0.004), 0.002, 1)
    # Joelho: mecânica escura à vista, tambor cinzento e rótula pequena.
    mtube(p, "metal", axis_frame((0, y(0.455), 0.0), "x"), 0.05, 0.17, 18, bevel=0.008)
    cbox(p, "dark", (0, y(0.455), 0.03), (0.1, 0.09, 0.1), 0.012)
    cbox(p, "trim", (0, y(0.46), -0.075), (0.11, 0.07, 0.05), 0.018)
    mtube(p, "dark", axis_frame((out * 0.09, y(0.455), 0.0), "x" if out > 0 else "-x"), 0.028, 0.012, 14)
    for dz in (-0.03, 0.04):
        rod(p, "dark", Vector((out * 0.05, y(0.52), dz)), Vector((out * 0.05, y(0.4), dz)), 0.012)
    # Canela: carapaça branca alta, faixa laranja em baixo junto ao tornozelo.
    cbox(p, "dark", (0, y(0.28), 0.02), (0.11, 0.26, 0.13), 0.015)
    cbox(p, "trim", (0, y(0.33), -0.03), (0.22, 0.17, 0.18), 0.028)
    cbox(p, "shell", (0, y(0.2), -0.03), (0.225, 0.09, 0.185), 0.022)
    mbox(p, "trim", T(0, y(0.34), -0.122), (0.07, 0.01, 0.004), 0.002, 1)
    # Tornozelo e pé de garras escuras.
    mtube(p, "metal", axis_frame((0, y(0.12), 0.0), "x"), 0.035, 0.12, 14)
    cbox(p, "dark", (0, y(0.12), 0.0), (0.08, 0.07, 0.08), 0.01)
    cbox(p, "metal", (0, y(0.06), -0.01), (0.17, 0.05, 0.16), 0.018)
    for dx, rz in ((-0.06, 10), (0.0, 0), (0.06, -10)):
        cbox(p, "dark", (dx, y(0.03), -0.13), (0.05, 0.06, 0.13), 0.015, rot=(0, rz, 0))
        cbox(p, "dark", (dx * 1.1, y(0.02), -0.2), (0.04, 0.04, 0.05), 0.012, rot=(-20, rz, 0))
    cbox(p, "dark", (0, y(0.03), 0.09), (0.1, 0.06, 0.08), 0.015)

# --------------------------------------------------------------------------------------
# Asas às costas (slot "back"): HÉLIO, o anjo, com penas; ECLIPSE, o anjo caído, com
# membrana de morcego. As duas partem do mesmo esqueleto (ombro, cotovelo, pulso) num plano
# varrido para trás, e o desenho de cada asa é feito em 2D nesse plano (u para fora, v para
# cima), por isso fica fina de lado e inteira de frente.
# --------------------------------------------------------------------------------------
def wing_plane(side, root, sweep=28):
    s = math.radians(sweep)
    u = Vector((side * math.cos(s), 0.0, math.sin(s)))
    v = Vector((0.0, 1.0, 0.0))
    n = u.cross(v).normalized()
    def to3(pt, lift=0.0):
        return root + u * pt[0] + v * pt[1] + n * lift
    basis = Matrix((u, v, n)).transposed().to_4x4()
    basis.translation = root
    return to3, basis


def feather(p, role, basis, base, angle, length, width, lift=0.0, thickness=0.016):
    """Pena achatada em ponta, no plano da asa: nasce em `base` e aponta para `angle` graus."""
    w = width / 2
    pts = [(-w, 0.0), (w, 0.0), (w * 0.95, length * 0.8), (0.0, length), (-w * 0.95, length * 0.8)]
    m = basis @ Matrix.Translation((base[0], base[1], lift)) @ Matrix.Rotation(math.radians(angle - 90), 4, "Z")
    extruded(p, role, m, pts, thickness)


def lerp2(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def helio6_wings(p):
    for side in (-1, 1):
        root = Vector((side * 0.12, 1.4, 0.24))
        to3, basis = wing_plane(side, root)
        elbow, wrist = (0.24, 0.32), (0.5, 0.46)
        # Osso de latão com a charneira na raiz e a articulação do pulso.
        mtube(p, "metal", axis_frame(root, "z"), 0.035, 0.07, 14)
        rod(p, "metal", to3((0, 0)), to3(elbow), 0.026, 12)
        rod(p, "metal", to3(elbow), to3(wrist), 0.022, 12)
        for q in (elbow, wrist):
            ball(p, "trim", to3(q), 0.034)
        # Primárias douradas em leque a partir do pulso, as secundárias creme ao longo do
        # antebraço e as terciárias junto ao corpo; as coberturas curtas por cima, de cada
        # lado do plano.
        for i, (ang, ln) in enumerate(((-4, 0.46), (-22, 0.52), (-40, 0.52), (-56, 0.5), (-70, 0.47))):
            feather(p, "trim", basis, lerp2(wrist, elbow, i * 0.05), ang, ln, 0.1)
        for i in range(5):
            t = 0.28 + i * 0.18
            base = lerp2(wrist, elbow, t) if t <= 1 else lerp2(elbow, (0.0, 0.0), t - 1)
            feather(p, "shell", basis, base, -80 - i * 4, 0.46 - i * 0.04, 0.1, lift=0.006)
        for i in range(7):
            t = i / 6
            base = lerp2((0.04, 0.04), elbow, t * 1.0) if t < 0.5 else lerp2(elbow, wrist, (t - 0.5) * 2)
            for lift in (-0.014, 0.014):
                feather(p, "metal", basis, (base[0], base[1] + 0.02), -80 + t * 30, 0.17, 0.085, lift=lift, thickness=0.012)
        # Pena-sol na ponta do osso.
        mtube(p, "glow", frame(to3(wrist, 0.0), basis.to_3x3() @ Vector((0, 0, 1))), 0.018, 0.05, 12)


def eclipse6_wings(p):
    for side in (-1, 1):
        root = Vector((side * 0.13, 1.42, 0.26))
        to3, basis = wing_plane(side, root, sweep=24)
        elbow, wrist = (0.28, 0.3), (0.52, 0.42)
        mtube(p, "dark", axis_frame(root, "z"), 0.038, 0.08, 14)
        rod(p, "metal", to3((0, 0)), to3(elbow), 0.03, 10)
        rod(p, "metal", to3(elbow), to3(wrist), 0.026, 10)
        ball(p, "dark", to3(elbow), 0.04)
        ball(p, "dark", to3(wrist), 0.036)
        # Garra do pulso virada para cima.
        claw_dir = (basis.to_3x3() @ Vector((0.25, 1.0, 0.0))).normalized()
        lathe(p, "metal", frame(to3(wrist), claw_dir), [(0.0, 0.0), (0.03, 0.01), (0.018, 0.08), (0.0, 0.17)], 10)
        # Dedos da membrana: quatro varetas do pulso até às pontas, com espigões.
        tips = [(0.98, 0.18), (0.9, -0.16), (0.68, -0.4), (0.4, -0.5)]
        for tip in tips:
            rod(p, "metal", to3(wrist), to3(tip), 0.017, 8)
            rod(p, "glow", to3(wrist, 0.012), to3(lerp2(wrist, tip, 0.9), 0.012), 0.006, 6)
            d = (to3(tip) - to3(wrist)).normalized()
            lathe(p, "metal", frame(to3(tip), d), [(0.0, -0.01), (0.018, 0.0), (0.0, 0.08)], 8)
        # Membrana escura em recortes entre as pontas, em leque a partir do pulso.
        ring = []
        for i, tip in enumerate(tips):
            ring.append(tip)
            nxt = tips[i + 1] if i + 1 < len(tips) else (0.06, -0.2)
            mid = lerp2(tip, nxt, 0.5)
            ring.append(lerp2(mid, wrist, 0.22))
        ring += [(0.06, -0.2), (0.0, 0.0), elbow]
        for i in range(len(ring) - 1):
            extruded(p, "dark", basis, [wrist, ring[i], ring[i + 1]], 0.012)


# --------------------------------------------------------------------------------------
# ECLIPSE 8: o executor. Alto e anguloso, sem ovo, sem asas, sem chifres: elmo pequeno e
# afiado enterrado numa gola alta, visor em V sob uma sobrancelha carregada, peito em cunha
# (largo em cima, cintura estreita) com o núcleo do eclipse (disco negro e coroa acesa),
# ombreiras em lâminas sobrepostas, garra comprida, canhão com o anel do eclipse na boca e
# pernas altas com joelheiras em bico e grevas largas.
# --------------------------------------------------------------------------------------
E8 = {"hip": Vector((0.2, 0.88, 0.0)), "elbow_l": Vector((-0.6, 1.2, 0.02)), "wrist_l": Vector((-0.64, 0.88, -0.1)),
      "elbow_r": Vector((0.6, 1.2, -0.02)), "muzzle": Vector((0.52, 1.0, -1.12)), "head": Vector((0.0, 1.84, -0.03))}


def eclipse8_head(p):
    c = E8["head"]
    mk.HEADS["eclipse8_head"] = {"top": round(c.y + 0.17, 3), "center": round(c.y, 3), "aspect": round(0.26 / 0.05, 3)}
    # Crânio escuro, faces laterais inclinadas e o tampo em bico para a frente.
    cbox(p, "dark", (c.x, c.y, c.z + 0.02), (0.28, 0.26, 0.32), 0.03)
    for side in (-1, 1):
        cbox(p, "shell", (side * 0.15, c.y + 0.01, c.z + 0.02), (0.04, 0.27, 0.34), 0.012, rot=(0, 0, side * 6))
    cbox(p, "shell", (0, c.y + 0.14, c.z + 0.02), (0.3, 0.05, 0.36), 0.015, taper=(0.7, 1.0))
    extruded(p, "shell", T(0, c.y + 0.155, c.z - 0.17) @ Matrix.Rotation(math.radians(-90), 4, "X"), [(-0.1, 0.0), (0.1, 0.0), (0.0, -0.1)], 0.03)
    # Sobrancelha em V carregada sobre o visor.
    for side in (-1, 1):
        cbox(p, "shell", (side * 0.07, c.y + 0.065, c.z - 0.16), (0.16, 0.045, 0.06), 0.01, rot=(0, 0, side * 16))
    p.screen((0, c.y + 0.015, c.z - 0.152), (0.26, 0.05), bulge=0.003)
    # Máscara em cunha até ao queixo em bico.
    for side in (-1, 1):
        cbox(p, "shell", (side * 0.075, c.y - 0.07, c.z - 0.14), (0.14, 0.1, 0.06), 0.012, rot=(0, side * 18, -side * 12))
    for side in (-1, 1):
        mbox(p, "glow", T(side * 0.04, c.y - 0.075, c.z - 0.176), (0.012, 0.05, 0.004), 0.002, 1)


def eclipse8_torso(p, with_neck=True):
    hip = E8["hip"]
    # Cintura estreita, pistões e o abdómen em cintas que alargam para cima.
    cbox(p, "dark", (0, 0.9, 0.0), (0.3, 0.12, 0.26), 0.03)
    hip_axles(p, hip.y, 0.14, hip.x, 0.07)
    for side in (-1, 1):
        piston(p, Vector((side * 0.1, 0.94, 0.08)), Vector((side * 0.14, 1.14, 0.08)))
    mtube(p, "metal", axis_frame((0, 0.97, 0.0), "y"), 0.1, 0.12, 16)
    for i, w in enumerate((0.3, 0.36, 0.42)):
        cbox(p, "shell" if i % 2 == 0 else "dark", (0, 1.02 + i * 0.07, -0.02), (w, 0.06, 0.28 + i * 0.03), 0.015)
    # Peito em cunha: largo nos ombros, estreito em baixo.
    cbox(p, "dark", (0, 1.4, 0.03), (0.66, 0.36, 0.42), 0.04, taper=(1.25, 1.05))
    for side in (-1, 1):
        cbox(p, "shell", (side * 0.17, 1.43, -0.17), (0.3, 0.3, 0.08), 0.02, rot=(8, side * 14, side * -8), taper=(1.3, 1.0))
        cbox(p, "trim", (side * 0.3, 1.55, -0.14), (0.14, 0.03, 0.06), 0.006, rot=(0, side * 14, side * -8))
    cbox(p, "shell", (0, 1.62, 0.0), (0.86, 0.1, 0.46), 0.03, taper=(0.9, 0.95))
    # O núcleo do eclipse: disco negro, coroa acesa e raios curtos à volta.
    core = T(0, 1.37, -0.235) @ Matrix.Rotation(math.radians(90), 4, "X")
    mtube(p, "dark", core, 0.095, 0.03, 24)
    mring(p, "glow", sub(core, 0, -0.012, 0), 0.105, 0.009, 28, 6)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        q = (math.cos(a) * 0.14, 1.37 + math.sin(a) * 0.14, -0.232)
        cbox(p, "trim", q, (0.018, 0.05, 0.012), 0.004, rot=(0, 0, math.degrees(a) - 90))
    # Gola alta dos lados da cabeça: o elmo fica enterrado nela.
    for side in (-1, 1):
        cbox(p, "shell", (side * 0.22, 1.76, 0.02), (0.1, 0.24, 0.36), 0.02, rot=(0, 0, -side * 12), taper=(0.7, 0.85))
    cbox(p, "shell", (0, 1.74, 0.17), (0.36, 0.2, 0.08), 0.02, rot=(-12, 0, 0))
    cbox(p, "dark", (0, 1.7, 0.0), (0.2, 0.08, 0.2), 0.02)
    # Costas: espinha em lâminas e dois escapes.
    for i in range(4):
        cbox(p, "shell", (0, 1.58 - i * 0.12, 0.27 - i * 0.015), (0.08, 0.1, 0.06), 0.01, rot=(-10, 0, 0))
    for side in (-1, 1):
        cbox(p, "dark", (side * 0.18, 1.42, 0.26), (0.14, 0.26, 0.1), 0.02)
        vents(p, sub(T(side * 0.18, 1.42, 0.312), rot=(90, 0, 0)), 3, 0.1, depth=0.008, spacing=0.06)


def eclipse8_shoulders(p):
    for side in (-1, 1):
        e = E8["elbow_l"] if side < 0 else E8["elbow_r"]
        ball(p, "dark", Vector((side * 0.45, 1.52, 0.02)), 0.1, 14)
        # Ombreira em três lâminas sobrepostas, a descer para fora.
        # Ombreira maciça, inclinada para fora, com a aba de baixo e a aresta clara.
        cbox(p, "dark", (side * 0.52, 1.58, 0.02), (0.26, 0.22, 0.34), 0.03)
        cbox(p, "shell", (side * 0.6, 1.66, 0.02), (0.38, 0.26, 0.46), 0.05, rot=(0, 0, -side * 12), taper=(0.78, 0.86))
        cbox(p, "shell", (side * 0.66, 1.49, 0.02), (0.32, 0.08, 0.42), 0.02, rot=(0, 0, -side * 18))
        cbox(p, "trim", (side * 0.66, 1.448, 0.02), (0.3, 0.012, 0.4), 0.004, rot=(0, 0, -side * 18))
        cbox(p, "trim", (side * 0.6, 1.66, -0.235), (0.24, 0.02, 0.012), 0.004, rot=(0, 0, -side * 12))
        mbox(p, "glow", T(side * 0.6, 1.62, -0.236), (0.1, 0.012, 0.004), 0.002, 1)
        # Braço de cima: estrutura escura e placa exterior.
        rod(p, "dark", Vector((side * 0.52, 1.46, 0.02)), e, 0.065, 12)
        beam(p, "shell", Vector((side * 0.56, 1.44, 0.02)), e + Vector((0, 0.08, 0)), 0.1, 0.16, 0.02)
        ball(p, "metal", e, 0.075, 14)


def eclipse8_arm(p):
    # Braço livre: antebraço em lâmina e a garra comprida de três dedos.
    e, w = E8["elbow_l"], E8["wrist_l"]
    m = beam(p, "dark", e, w, 0.12, 0.13, 0.02, pad=0.04)
    beam(p, "shell", e + Vector((-0.02, -0.04, 0)), w + Vector((-0.02, 0.06, 0)), 0.16, 0.18, 0.03)
    L = (w - e).length
    extruded(p, "trim", m @ Matrix.Translation((-0.09, 0, 0)) @ Matrix.Rotation(math.radians(90), 4, "Y"), [(0.05, -L * 0.4), (0.05, L * 0.3), (-0.02, L * 0.55)], 0.015)
    cbox(p, "glow", sub(m, 0, -L * 0.1, -0.092), (0.03, 0.12, 0.006), 0.003)
    eclipse8_claw(p)
    # Antebraço do canhão.
    e = E8["elbow_r"]
    d = (E8["muzzle"] - e).normalized()
    m = beam(p, "shell", e, e + d * 0.42, 0.2, 0.2, 0.03, pad=0.04, front=(0, 1, 0))
    cbox(p, "trim", sub(m, 0, 0.1, 0), (0.21, 0.03, 0.21), 0.008)


def eclipse8_gun(p):
    e = E8["elbow_r"]
    muzzle = E8["muzzle"]
    d = (muzzle - e).normalized()
    m = frame(e, d, front=(0, 1, 0))
    L = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, (0.4 + L) / 2, 0), 0.06, L - 0.4, 16, bevel=0.005)
    cbox(p, "shell", sub(m, 0, 0.5, 0), (0.16, 0.2, 0.16), 0.02, taper=(0.8, 0.8))
    # A boca do canhão é um pequeno eclipse: disco negro e a coroa acesa.
    mtube(p, "dark", sub(m, 0, L - 0.04, 0), 0.1, 0.05, 20)
    mring(p, "glow", sub(m, 0, L - 0.012, 0), 0.105, 0.01, 24, 6)


def eclipse8_leg(p, out):
    g = -E8["hip"].y
    leg_hub(p, out, 0.07)
    # Coxa: estrutura escura e placa angulosa à frente.
    beam(p, "dark", (0, -0.04, 0), (0, -0.36, -0.02), 0.14, 0.16, 0.02)
    cbox(p, "shell", (0, -0.2, -0.05), (0.22, 0.3, 0.14), 0.025, taper=(1.15, 1.1))
    cbox(p, "shell", (out * 0.12, -0.18, 0.0), (0.04, 0.26, 0.2), 0.01)
    cbox(p, "trim", (out * 0.143, -0.18, 0.0), (0.008, 0.2, 0.14), 0.003)
    # Joelho: tambor e joelheira em bico para a frente.
    mtube(p, "metal", axis_frame((0, -0.4, -0.02), "x"), 0.06, 0.18, 16)
    extruded(p, "shell", T(0, -0.4, -0.12) @ Matrix.Rotation(math.radians(90), 4, "Y"), [(-0.04, 0.09), (-0.04, -0.09), (0.13, 0.0)], 0.17)
    # Greva larga em baixo, a abrir para o pé.
    beam(p, "dark", (0, -0.44, 0.0), (0, -0.76, 0.02), 0.12, 0.13, 0.02)
    cbox(p, "shell", (0, -0.6, -0.04), (0.23, 0.3, 0.18), 0.025, taper=(0.8, 0.8), rot=(180, 0, 0))
    cbox(p, "trim", (0, -0.72, -0.12), (0.22, 0.03, 0.03), 0.006)
    mbox(p, "glow", T(0, -0.56, -0.123), (0.05, 0.012, 0.004), 0.002, 1)
    # Tornozelo e o pé em cunha, com calcanhar.
    mtube(p, "metal", axis_frame((0, g + 0.11, 0.02), "x"), 0.045, 0.14, 14)
    cbox(p, "dark", (0, g + 0.03, -0.02), (0.22, 0.06, 0.32), 0.015)
    extruded(p, "shell", T(0, g + 0.04, 0) @ Matrix.Rotation(math.radians(90), 4, "Y"), [(-0.13, 0.0), (0.26, 0.0), (0.26, 0.03), (0.04, 0.12), (-0.13, 0.12)], 0.2)
    cbox(p, "trim", (0, g + 0.1, -0.12), (0.21, 0.01, 0.12), 0.003, rot=(-24, 0, 0))


# --------------------------------------------------------------------------------------
# FAÍSCA 9: corredora esguia e alta. Cabeça estreita e alta com o visor em fenda, para-raios
# em ziguezague no alto e isoladores nas orelhas; peito estreito com o raio aceso, cintura em
# bobina, bobina de Tesla às costas, braços finos e o emissor-bobina. Mantém as pernas de
# gafanhoto (faisca2_leg).
# --------------------------------------------------------------------------------------
F9 = {"elbow_l": Vector((-0.4, 1.12, 0.02)), "wrist_l": Vector((-0.43, 0.86, -0.08)), "elbow_r": Vector((0.4, 1.12, -0.02)),
      "muzzle": Vector((0.42, 0.95, -0.98)), "head": Vector((0.0, 1.8, -0.02))}


def faisca9_head(p):
    c = F9["head"]
    mk.HEADS["faisca9_head"] = {"top": round(c.y + 0.2, 3), "center": round(c.y, 3), "aspect": round(0.18 / 0.055, 3)}
    cbox(p, "dark", (c.x, c.y, c.z + 0.01), (0.2, 0.32, 0.24), 0.03)
    cbox(p, "shell", (c.x, c.y + 0.06, c.z), (0.24, 0.24, 0.27), 0.05)
    cbox(p, "shell", (c.x, c.y - 0.12, c.z - 0.01), (0.2, 0.08, 0.24), 0.03, taper=(1.15, 1.05))
    cbox(p, "trim", (c.x, c.y + 0.0, c.z - 0.13), (0.22, 0.09, 0.03), 0.012)
    p.screen((c.x, c.y + 0.0, c.z - 0.147), (0.18, 0.055), bulge=0.003)
    cbox(p, "trim", (c.x, c.y + 0.185, c.z), (0.08, 0.02, 0.2), 0.006)
    for side in (-1, 1):
        for i in range(3):
            mtube(p, "metal" if i % 2 else "shell", axis_frame((side * (0.13 + i * 0.022), c.y + 0.04, c.z), "x" if side > 0 else "-x"), 0.05 - i * 0.01, 0.02, 14)
    # Para-raios em ziguezague no alto da cabeça.
    extruded(p, "trim", T(c.x + 0.02, c.y + 0.19, c.z) @ Matrix.Diagonal((0.9, 0.9, 1.0, 1.0)), BOLT, 0.02)
    ball(p, "glow", Vector((c.x + 0.02, c.y + 0.37, c.z)), 0.022, 10)


def faisca9_torso(p, with_neck=True):
    hip = FAISCA["hip"]
    cbox(p, "dark", (0, 0.84, 0.0), (0.3, 0.14, 0.24), 0.03)
    hip_axles(p, hip.y, 0.13, hip.x, 0.07)
    cbox(p, "shell", (0, 0.9, -0.03), (0.26, 0.1, 0.2), 0.03, taper=(1.2, 1.0))
    # Cintura em bobina.
    mtube(p, "dark", axis_frame((0, 1.04, 0.0), "y"), 0.075, 0.24, 14)
    for i in range(5):
        mring(p, "trim", axis_frame((0, 0.95 + i * 0.045, 0.0), "y"), 0.085, 0.012, 18, 6)
    # Peito estreito em escudo, com o raio aceso.
    cbox(p, "dark", (0, 1.36, 0.02), (0.42, 0.3, 0.3), 0.04)
    cbox(p, "shell", (0, 1.38, -0.02), (0.46, 0.3, 0.26), 0.06, taper=(1.12, 1.0))
    cbox(p, "shell", (0, 1.19, -0.02), (0.3, 0.1, 0.22), 0.03, taper=(1.4, 1.0))
    extruded(p, "glow", T(0.015, 1.27, -0.155) @ Matrix.Diagonal((0.9, 0.9, 1.0, 1.0)), BOLT, 0.012)
    cbox(p, "trim", (0, 1.53, -0.02), (0.4, 0.03, 0.26), 0.008)
    cbox(p, "dark", (0, 1.6, 0.0), (0.12, 0.08, 0.12), 0.015)
    # Bobina de Tesla às costas.
    mtube(p, "dark", axis_frame((0, 1.34, 0.19), "y"), 0.06, 0.34, 14)
    for i in range(4):
        mring(p, "glow" if i == 3 else "trim", axis_frame((0, 1.22 + i * 0.07, 0.19), "y"), 0.07 + (i == 3) * 0.02, 0.012, 18, 6)
    lathe(p, "metal", axis_frame((0, 1.51, 0.19), "y"), [(0.0, 0.0), (0.05, 0.0), (0.0, 0.1)], 12)


def faisca9_shoulders(p):
    for side in (-1, 1):
        e = F9["elbow_l"] if side < 0 else F9["elbow_r"]
        top = Vector((side * 0.3, 1.46, 0.02))
        ball(p, "dark", top, 0.07, 12)
        cbox(p, "shell", (side * 0.33, 1.52, 0.02), (0.16, 0.08, 0.2), 0.03, rot=(0, 0, -side * 18))
        cbox(p, "trim", (side * 0.4, 1.49, 0.02), (0.02, 0.06, 0.18), 0.005, rot=(0, 0, -side * 18))
        beam(p, "dark", top, e, 0.07, 0.08, 0.015)
        beam(p, "shell", top.lerp(e, 0.2), top.lerp(e, 0.8), 0.1, 0.11, 0.025)
        ball(p, "metal", e, 0.055, 12)


def faisca9_arm(p):
    e, w = F9["elbow_l"], F9["wrist_l"]
    m = beam(p, "shell", e, w, 0.11, 0.12, 0.03, pad=0.02)
    L = (w - e).length
    for i in range(2):
        mbox(p, "glow", sub(m, 0, -L * 0.1 + i * 0.06, -0.062), (0.05, 0.012, 0.004), 0.002, 1)
    cbox(p, "trim", sub(m, 0, L * 0.4, 0), (0.12, 0.03, 0.13), 0.006)
    fist(p, sub(frame(w, w - e, front=(0.3, 0, -1)), 0, 0.08, 0), 0.75)
    e = F9["elbow_r"]
    d = (F9["muzzle"] - e).normalized()
    m = beam(p, "shell", e, e + d * 0.36, 0.13, 0.13, 0.03, pad=0.03, front=(0, 1, 0))
    cbox(p, "trim", sub(m, 0, 0.1, 0), (0.14, 0.025, 0.14), 0.006)


def faisca9_gun(p):
    e = F9["elbow_r"]
    muzzle = F9["muzzle"]
    d = (muzzle - e).normalized()
    m = frame(e, d, front=(0, 1, 0))
    L = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, (0.36 + L) / 2, 0), 0.04, L - 0.36, 14)
    for i in range(4):
        mring(p, "glow" if i % 2 else "trim", sub(m, 0, 0.45 + i * 0.08, 0), 0.06, 0.012, 16, 6)
    lathe(p, "metal", sub(m, 0, L - 0.08, 0), [(0.03, 0.0), (0.06, 0.06), (0.05, 0.08)], 14)


# --------------------------------------------------------------------------------------
# ÓRBITA 9: astronauta. Capacete redondo com o rosto num vidro largo, antena e discos de
# ouvido; peito em caixa arredondada com mostradores, um anel orbital inclinado à volta da
# cintura com duas luas, ombros em esfera com o seu anel, mochila-propulsor, braço-telescópio
# e pernas robustas com botas lunares.
# --------------------------------------------------------------------------------------
O9 = {"hip": Vector((0.2, 0.7, 0.0)), "elbow_l": Vector((-0.5, 1.12, 0.02)), "wrist_l": Vector((-0.53, 0.84, -0.1)),
      "elbow_r": Vector((0.5, 1.12, -0.02)), "muzzle": Vector((0.46, 0.95, -1.04)), "head": Vector((0.0, 1.76, -0.01))}


def orbita9_head(p):
    c = O9["head"]
    r = 0.21
    mk.HEADS["orbita9_head"] = {"top": round(c.y + r + 0.1, 3), "center": round(c.y, 3), "aspect": round(0.26 / 0.18, 3)}
    ball(p, "shell", c, r, 24)
    cbox(p, "dark", (c.x, c.y, c.z - 0.12), (0.3, 0.22, 0.14), 0.07)
    p.screen((c.x, c.y, c.z - 0.195), (0.26, 0.18), bulge=0.03)
    mring(p, "trim", T(c.x, c.y, c.z - 0.19) @ Matrix.Rotation(math.radians(90), 4, "X"), 0.16, 0.014, 28, 6)
    mtube(p, "trim", axis_frame((c.x, c.y - r + 0.02, c.z), "y"), r * 0.8, 0.05, 22)
    for side in (-1, 1):
        mtube(p, "trim", axis_frame((side * (r - 0.01), c.y, c.z), "x" if side > 0 else "-x"), 0.075, 0.05, 18)
        mtube(p, "glow", axis_frame((side * (r + 0.04), c.y, c.z), "x" if side > 0 else "-x"), 0.03, 0.01, 12)
    rod(p, "metal", Vector((c.x + 0.08, c.y + r - 0.03, c.z + 0.04)), Vector((c.x + 0.12, c.y + r + 0.1, c.z + 0.06)), 0.01, 6)
    ball(p, "glow", Vector((c.x + 0.12, c.y + r + 0.11, c.z + 0.06)), 0.024, 10)


def orbita9_torso(p, with_neck=True):
    hip = O9["hip"]
    cbox(p, "dark", (0, 0.78, 0.0), (0.34, 0.14, 0.28), 0.04)
    hip_axles(p, hip.y, 0.14, hip.x, 0.075)
    cbox(p, "dark", (0, 0.96, 0.02), (0.36, 0.2, 0.3), 0.05)
    cbox(p, "shell", (0, 1.3, 0.02), (0.62, 0.42, 0.44), 0.1)
    cbox(p, "trim", (0, 1.3, -0.205), (0.36, 0.24, 0.03), 0.03)
    for i, x in enumerate((-0.09, 0.0, 0.09)):
        mtube(p, "glow" if i == 1 else "dark", T(x, 1.34, -0.225) @ Matrix.Rotation(math.radians(90), 4, "X"), 0.03, 0.014, 14)
    for i in range(3):
        mbox(p, "dark", T(0, 1.24 - i * 0.03, -0.224), (0.2, 0.01, 0.004), 0.002, 1)
    cbox(p, "dark", (0, 1.54, 0.0), (0.2, 0.06, 0.2), 0.02)
    # Mochila-propulsor.
    cbox(p, "shell", (0, 1.32, 0.3), (0.44, 0.34, 0.16), 0.05)
    for side in (-1, 1):
        mtube(p, "dark", axis_frame((side * 0.13, 1.1, 0.32), "-y"), 0.06, 0.1, 16)
        mtube(p, "glow", axis_frame((side * 0.13, 1.04, 0.32), "-y"), 0.04, 0.01, 14)


def orbita9_spin(p):
    # O anel orbital inclinado à volta da cintura, com duas luas.
    ring = T(0, 1.02, 0.02) @ Matrix.Rotation(math.radians(16), 4, "Z") @ Matrix.Rotation(math.radians(8), 4, "X")
    mring(p, "trim", ring, 0.36, 0.02, 40, 8)
    for ang, role, rad in ((200, "glow", 0.045), (330, "metal", 0.035)):
        a = math.radians(ang)
        ball(p, role, (ring @ Vector((math.cos(a) * 0.36, 0.0, math.sin(a) * 0.36, 1.0))).to_3d(), rad, 12)


def orbita9_shoulders(p):
    for side in (-1, 1):
        e = O9["elbow_l"] if side < 0 else O9["elbow_r"]
        c = Vector((side * 0.44, 1.42, 0.02))
        ball(p, "shell", c, 0.15, 20)
        mring(p, "trim", axis_frame(c, "x"), 0.155, 0.014, 26, 6)
        rod(p, "dark", c, e, 0.05, 10)
        ball(p, "dark", e, 0.07, 14)


def orbita9_arm(p):
    e, w = O9["elbow_l"], O9["wrist_l"]
    m = beam(p, "shell", e, w, 0.17, 0.18, 0.07, pad=0.04)
    cbox(p, "trim", sub(m, 0, (w - e).length * 0.35, 0), (0.18, 0.03, 0.19), 0.01)
    fist(p, sub(frame(w, w - e, front=(0.3, 0, -1)), 0, 0.1, 0), 0.95)
    e = O9["elbow_r"]
    d = (O9["muzzle"] - e).normalized()
    m = beam(p, "shell", e, e + d * 0.38, 0.18, 0.18, 0.07, pad=0.03, front=(0, 1, 0))
    cbox(p, "trim", sub(m, 0, 0.12, 0), (0.19, 0.03, 0.19), 0.01)


def orbita9_gun(p):
    # Telescópio em três troços, lente acesa na boca.
    e = O9["elbow_r"]
    muzzle = O9["muzzle"]
    d = (muzzle - e).normalized()
    m = frame(e, d, front=(0, 1, 0))
    L = (muzzle - e).length
    for i, (r, a, b) in enumerate(((0.075, 0.38, 0.6), (0.062, 0.6, 0.8), (0.05, 0.8, L - 0.02))):
        mtube(p, "trim" if i % 2 else "dark", sub(m, 0, (a + b) / 2, 0), r, b - a, 18)
    mtube(p, "glow", sub(m, 0, L - 0.012, 0), 0.042, 0.01, 16)


def orbita9_leg(p, out):
    g = -O9["hip"].y
    leg_hub(p, out, 0.07)
    cbox(p, "dark", (0, -0.12, 0.0), (0.14, 0.2, 0.16), 0.03)
    cbox(p, "shell", (0, -0.14, -0.02), (0.22, 0.2, 0.22), 0.07)
    ball(p, "dark", Vector((0, -0.28, 0.0)), 0.08, 14)
    mtube(p, "trim", axis_frame((0, -0.28, 0.0), "x"), 0.07, 0.2, 16)
    mtube(p, "shell", axis_frame((0, -0.43, 0.0), "y"), 0.12, 0.22, 20, radius2=0.1, bevel=0.02)
    mring(p, "trim", axis_frame((0, -0.48, 0.0), "y"), 0.125, 0.012, 22, 6)
    # Bota lunar: cano largo, biqueira redonda e a sola escura.
    cbox(p, "shell", (0, g + 0.1, -0.04), (0.24, 0.14, 0.34), 0.07)
    cbox(p, "trim", (0, g + 0.13, -0.16), (0.2, 0.04, 0.1), 0.02)
    cbox(p, "dark", (0, g + 0.025, -0.04), (0.26, 0.05, 0.36), 0.02)


# --------------------------------------------------------------------------------------
# Detalhe mecânico dos robôs novos: a silhueta em blocos da planta com a mecânica peça a peça
# dos v2 - rolamentos aparafusados nas juntas, pistões, cabos, parafusos nos painéis,
# números de série e avisos. Cada função junta-se à peça com o mesmo nome (ver define).
# --------------------------------------------------------------------------------------
def joint(p, c, side, r=0.07, w=0.05):
    bearing(p, axis_frame(Vector(c), "x" if side > 0 else "-x"), r, w)


def front_screws(p, c, half_w, half_h, z, size=0.008):
    m = plane((c[0], c[1], z), (0, 0, -1), (1, 0, 0))
    for u in (-half_w, half_w):
        for v in (-half_h, half_h):
            screw(p, m, u, v, size)


def label(p, c, text, h=0.045, normal=(0, 0, -1), right=(-1, 0, 0)):
    serial(p, plane(c, normal, right), text, h, role="label")


def eclipse8_torso_detail(p):
    for side in (-1, 1):
        joint(p, (side * 0.4, 1.52, 0.02), side, 0.075, 0.05)
        piston(p, (side * 0.24, 1.26, 0.14), (side * 0.15, 0.97, 0.1), 0.018)
        cable(p, [(side * 0.08, 1.7, 0.14), (side * 0.14, 1.62, 0.26), (side * 0.2, 1.52, 0.3), (side * 0.22, 1.3, 0.3)])
        front_screws(p, (side * 0.17, 1.43), 0.1, 0.1, -0.215)
        vents(p, plane((side * 0.225, 1.08, 0.0), (side, 0, 0), (0, 0, 1)) @ Matrix.Rotation(math.radians(90), 4, "X"), 3, 0.12, depth=0.008, spacing=0.035)
    label(p, (-0.26, 1.33, -0.214), "08")
    warning(p, plane((0, 1.2, 0.292), (0, 0, 1), (1, 0, 0)), 0.06)


def eclipse8_shoulders_detail(p):
    for side in (-1, 1):
        e = E8["elbow_l"] if side < 0 else E8["elbow_r"]
        piston(p, (side * 0.5, 1.44, 0.12), e + Vector((0, 0.12, 0.1)), 0.018)
        cable(p, [(side * 0.46, 1.5, -0.06), (side * 0.56, 1.36, -0.08), e + Vector((0, 0.1, -0.08))])
        for i in range(3):
            screw(p, plane((side * (0.5 + i * 0.07), 1.66 + (0.02 if side > 0 else 0.02) - i * 0.015 * 1.0, -0.232), (0, 0, -1), (1, 0, 0)), 0, 0, 0.009)
        joint(p, e, side, 0.06, 0.08)


def eclipse8_arm_detail(p):
    e, w = E8["elbow_l"], E8["wrist_l"]
    d = (w - e).normalized()
    bearing(p, frame(w, d), 0.07, 0.03)
    piston(p, e + Vector((0.0, -0.04, 0.1)), w + Vector((0.0, 0.08, 0.08)), 0.016)
    cable(p, [e + Vector((0.07, -0.05, 0.02)), e.lerp(w, 0.5) + Vector((0.1, 0, 0.0)), w + Vector((0.07, 0.06, 0.0))])
    e = E8["elbow_r"]
    d = (E8["muzzle"] - e).normalized()
    bearing(p, frame(e + d * 0.44, d), 0.1, 0.04)
    cable(p, [e + Vector((0.1, 0.0, 0.05)), e + d * 0.3 + Vector((0.12, 0.02, 0.0)), e + d * 0.52 + Vector((0.07, 0.04, 0.0))])


def eclipse8_leg_detail(p, out):
    for side in (-1, 1):
        joint(p, (side * 0.1, -0.4, -0.02), side, 0.055, 0.03)
    piston(p, (0, -0.1, 0.1), (0, -0.62, 0.1), 0.02)
    cable(p, [(out * 0.08, -0.04, 0.06), (out * 0.12, -0.2, 0.08), (out * 0.1, -0.38, 0.06)])
    front_screws(p, (0, -0.2), 0.07, 0.1, -0.125)
    bolts(p, axis_frame((out * 0.075, E8["hip"].y * -1 + 0.11, 0.02), "x" if out > 0 else "-x"), 0.03, 5, size=0.008)


def faisca9_torso_detail(p):
    for side in (-1, 1):
        joint(p, (side * 0.25, 1.46, 0.02), side, 0.06, 0.04)
        piston(p, (side * 0.14, 1.22, 0.1), (side * 0.12, 0.9, 0.08), 0.014)
        front_screws(p, (side * 0.14, 1.38), 0.05, 0.09, -0.155, 0.007)
    cable(p, [(0.05, 1.62, 0.06), (0.1, 1.55, 0.14), (0.06, 1.48, 0.18)])
    cable(p, [(-0.05, 1.62, 0.06), (-0.1, 1.55, 0.14), (-0.06, 1.48, 0.18)])
    label(p, (-0.13, 1.26, -0.145), "07", 0.04)


def faisca9_shoulders_detail(p):
    for side in (-1, 1):
        e = F9["elbow_l"] if side < 0 else F9["elbow_r"]
        piston(p, (side * 0.3, 1.4, 0.08), e + Vector((0, 0.1, 0.07)), 0.013)
        joint(p, e, side, 0.045, 0.07)


def faisca9_arm_detail(p):
    e, w = F9["elbow_l"], F9["wrist_l"]
    bearing(p, frame(w, (w - e).normalized()), 0.05, 0.025)
    cable(p, [e + Vector((0.05, -0.04, 0.05)), e.lerp(w, 0.6) + Vector((0.07, 0, 0.04)), w + Vector((0.05, 0.05, 0.02))], 0.008)


def orbita9_torso_detail(p):
    for side in (-1, 1):
        joint(p, (side * 0.3, 1.42, 0.02), side, 0.07, 0.05)
        piston(p, (side * 0.16, 1.1, -0.12), (side * 0.13, 0.86, -0.1), 0.016)
        cable(p, [(side * 0.12, 1.56, 0.05), (side * 0.16, 1.5, 0.2), (side * 0.14, 1.44, 0.3)])
        vents(p, plane((side * 0.312, 1.3, 0.02), (side, 0, 0), (0, 0, 1)) @ Matrix.Rotation(math.radians(90), 4, "X"), 3, 0.2, depth=0.008, spacing=0.04)
    front_screws(p, (0, 1.3), 0.16, 0.1, -0.222, 0.008)
    label(p, (0.22, 1.42, -0.223), "02", 0.045)
    warning(p, plane((0.12, 1.4, 0.382), (0, 0, 1), (1, 0, 0)), 0.05)


def orbita9_shoulders_detail(p):
    for side in (-1, 1):
        e = O9["elbow_l"] if side < 0 else O9["elbow_r"]
        piston(p, (side * 0.44, 1.3, 0.1), e + Vector((0, 0.1, 0.08)), 0.016)
        bolts(p, axis_frame((side * 0.44, 1.42, 0.02), "x" if side > 0 else "-x"), 0.1, 6, size=0.01, proud=0.12)


def orbita9_arm_detail(p):
    e, w = O9["elbow_l"], O9["wrist_l"]
    bearing(p, frame(w, (w - e).normalized()), 0.075, 0.03)
    cable(p, [e + Vector((0.09, -0.04, 0.05)), e.lerp(w, 0.55) + Vector((0.11, 0, 0.03)), w + Vector((0.08, 0.05, 0.02))])


def orbita9_leg_detail(p, out):
    for side in (-1, 1):
        joint(p, (side * 0.1, -0.28, 0.0), side, 0.05, 0.03)
    piston(p, (0, -0.1, 0.11), (0, -0.46, 0.12), 0.018)
    cable(p, [(out * 0.1, -0.06, 0.05), (out * 0.13, -0.2, 0.06), (out * 0.12, -0.36, 0.04)])
    front_screws(p, (0, -0.14), 0.07, 0.06, -0.132)


def batida7_torso_detail(p):
    for side in (-1, 1):
        bolts(p, axis_frame((side * 0.32, 1.1, 0.0), "x" if side > 0 else "-x"), 0.06, 6, size=0.009)
        cable(p, [(side * 0.1, 1.22, 0.1), (side * 0.2, 1.2, 0.22), (side * 0.12, 1.12, 0.3)])
        front_screws(p, (side * 0.14, 1.05), 0.06, 0.09, -0.225, 0.008)
    label(p, (0.18, 0.99, -0.222), "07", 0.04)


def batida7_leg_detail(p, out):
    y = lambda h: h - BP_HIP
    for side in (-1, 1):
        bolts(p, axis_frame((side * 0.085, y(0.455), 0.0), "x" if side > 0 else "-x"), 0.035, 5, size=0.008)
    piston(p, (0, y(0.64), 0.09), (0, y(0.3), 0.1), 0.016)
    cable(p, [(out * 0.1, y(0.7), 0.06), (out * 0.13, y(0.55), 0.07), (out * 0.1, y(0.4), 0.05)], 0.009)
    front_screws(p, (0, y(0.61)), 0.08, 0.1, -0.124, 0.007)
    front_screws(p, (0, y(0.33)), 0.07, 0.06, -0.122, 0.007)


def batida7_shoulders_detail(p):
    for side in (-1, 1):
        x = side * 0.45
        piston(p, (x, 1.05, 0.13), (x, 0.9, 0.1), 0.014)
        cable(p, [(side * 0.34, 1.16, 0.08), (x + side * 0.03, 1.0, 0.14), (x, 0.88, 0.1)], 0.009)


def eclipse5_torso_detail(p):
    for side in (-1, 1):
        joint(p, (side * 0.47, 1.38, 0.02), side, 0.09, 0.05)
        piston(p, (side * 0.2, 1.08, 0.14), (side * 0.14, 0.8, 0.1), 0.02)
        cable(p, [(side * 0.2, 1.7, 0.12), (side * 0.22, 1.6, 0.3), (side * 0.2, 1.46, 0.38)])
        front_screws(p, (side * 0.2, 1.24), 0.13, 0.09, -0.283)
    warning(p, plane((0.15, 1.3, 0.482), (0, 0, 1), (1, 0, 0)), 0.06)


def eclipse5_leg_detail(p, out):
    for side in (-1, 1):
        joint(p, (side * 0.13, -0.36, -0.01), side, 0.06, 0.03)
    piston(p, (0, -0.12, 0.17), (0, -0.5, 0.19), 0.022)
    front_screws(p, (0, -0.2), 0.1, 0.08, -0.162)
    front_screws(p, (0, -0.52), 0.11, 0.08, -0.182)


def with_detail(fn, extra):
    def build(p, *args):
        fn(p, *args)
        extra(p, *args)
    return build


# --------------------------------------------------------------------------------------
# Versão 10: as silhuetas novas montadas sobre o esqueleto v2 peça a peça - ombro com
# suporte, rolamento, tambor e garfo; braço com osso, servo, pistão, cotovelo em dobradiça e
# cabo; pulso com rolamento e colar; mão com dedos de três falanges e pinos; perna com anca
# em garfo, joelho e tornozelo em dobradiça, amortecedores e pé em camadas. A blindagem de
# cada robô assenta por cima.
# --------------------------------------------------------------------------------------
def v10_shoulders(p, spec):
    for side in (-1, 1):
        elbow = spec["elbow_l"] if side < 0 else spec["elbow_r"]
        pin, drum = shoulder(p, side, spec["bracket"], spec["shoulder_y"], 0.01, spec.get("bearing", 0.1), spec.get("drum", 0.08), 0.08, pin_drop=spec.get("drop", 0.12))
        upper_arm(p, side, pin, elbow, armor=spec.get("arm_armor", "shell"), bone_r=spec.get("bone", 0.04), elbow_w=spec.get("elbow_w", 0.08),
                  elbow_r=spec.get("elbow_rad", 0.05), armor_size=spec.get("armor_size", (0.13, 0.11)))
        spec["pauldron"](p, side, drum, pin, elbow)


def v10_forearm(p, spec, armor):
    e, w = spec["elbow_l"], spec["wrist_l"]
    m = frame(e, w - e, front=(0.3, 0, -1))
    length = (w - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    capsule(p, "dark", sub(m, 0, length * 0.55, 0), spec.get("core", 0.07), length * 0.8, 16)
    piston(p, at(m, 0.0, 0.06, -0.06), at(m, 0.0, length - 0.04, -0.06), 0.014)
    cable(p, [at(m, -0.06, 0.04, 0.03), at(m, -0.08, length * 0.5, 0.04), at(m, -0.05, length - 0.02, 0.03)], 0.009)
    armor(p, m, length)
    wrist(p, m, length, plate=spec.get("plate", (0.1, 0.09)))
    hand(p, sub(m, 0, length + 0.14 * spec.get("hand", 1.3) / 1.3, 0.0, rot=(0, -90, 180)), fingers=spec.get("fingers", 4), scale=spec.get("hand", 1.3), curl=0.9, armor=spec.get("hand_armor", "shell"))


def v10_gun_forearm(p, spec, armor):
    e, muzzle = spec["elbow_r"], spec["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    capsule(p, "dark", sub(m, 0, 0.22, 0), spec.get("core", 0.07), 0.36, 16)
    armor(p, m)
    ring = sub(m, 0, spec.get("ring_at", 0.44), 0)
    mtube(p, "metal", ring, spec.get("ring_r", 0.08), 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), spec.get("ring_r", 0.08) * 0.8, 6, size=0.009)


# ---- BATIDA 10 ------------------------------------------------------------------------
B10 = {"shoulder_y": 1.12, "bracket": 0.24, "elbow_l": Vector((-0.46, 0.84, 0.02)), "wrist_l": Vector((-0.49, 0.56, -0.08)),
       "elbow_r": Vector((0.46, 0.84, -0.02)), "muzzle": Vector((0.45, 0.72, -0.92)), "bearing": 0.085, "drum": 0.07,
       "armor_size": (0.15, 0.13), "hand": 1.25, "fingers": 4, "hand_armor": "trim"}


def b10_pauldron(p, side, drum, pin, elbow):
    cbox(p, "trim", (drum.x + side * 0.03, drum.y + 0.02, 0.01), (0.22, 0.2, 0.28), 0.05)
    cbox(p, "shell", (drum.x + side * 0.06, drum.y + 0.08, -0.13), (0.07, 0.04, 0.012), 0.008)
    for i in range(3):
        screw(p, plane((drum.x + side * (0.0 + i * 0.05), drum.y - 0.05, -0.132), (0, 0, -1), (1, 0, 0)), 0, 0, 0.008)


B10["pauldron"] = b10_pauldron


def batida10_shoulders(p):
    v10_shoulders(p, B10)


def batida10_arm(p):
    def armor(q, m, length):
        cbox(q, "trim", sub(m, 0, length * 0.38, -0.01), (0.2, length * 0.5, 0.2), 0.05)
        cbox(q, "shell", sub(m, 0, length * 0.76, -0.01), (0.21, 0.1, 0.21), 0.04)
        bp_triangle(q, "dark", sub(m, 0, length * 0.76, -0.111), 0.05)
    v10_forearm(p, B10, armor)

    def gun_armor(q, m):
        cbox(q, "trim", sub(m, 0, 0.2, 0), (0.2, 0.3, 0.2), 0.05)
        cbox(q, "shell", sub(m, 0, 0.36, 0), (0.21, 0.08, 0.21), 0.04)
        bp_diamond(q, "dark", tuple(at(m, 0.101, 0.2, 0.0)), 0.07, bar=0.011)
    v10_gun_forearm(p, dict(B10, ring_at=0.43, ring_r=0.07), gun_armor)


def batida10_gun(p):
    e, muzzle = B10["elbow_r"], B10["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    L = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, (0.46 + L) / 2, 0), 0.045, L - 0.46, 16)
    for i in range(3):
        mring(p, "shell", sub(m, 0, 0.52 + i * 0.07, 0), 0.058, 0.012, 16, 6)
    mtube(p, "glow", sub(m, 0, L - 0.01, 0), 0.03, 0.01, 12)


def batida10_leg(p, out):
    def thigh(q, o, top, bottom):
        h = top - bottom
        cbox(q, "trim", (0, top - h / 2, -0.03), (0.23, h, 0.19), 0.05)
        for i in range(2):
            mbox(q, "hazard", T(0, top - 0.05 - i * 0.025, -0.126), (0.06, 0.01, 0.004), 0.002, 1)

    def shin(q, o, top, bottom, mid):
        h = top - bottom
        cbox(q, "trim", (0, top - h * 0.35, -0.04), (0.2, h * 0.7, 0.17), 0.045)
        cbox(q, "shell", (0, bottom + 0.05, -0.03), (0.21, 0.09, 0.19), 0.04)

    def feet(q, m, o, ankle):
        foot(q, m, length=0.36, width=0.22, out=o, toes=3, armor="trim", heel="shell")
    leg(p, out, BP_HIP, knee_y=-0.3, ankle_up=0.16, width=0.95, knee_w=0.11, knee_r=0.055, foot_fn=feet, thigh_fn=thigh, shin_fn=shin, guard=True, guard_role="trim")


# ---- MAGNUS 10 (o tanque negro) ---------------------------------------------------------
M10 = {"shoulder_y": 1.42, "bracket": 0.36, "elbow_l": E5["elbow_l"], "wrist_l": Vector((-0.66, 0.74, -0.14)),
       "elbow_r": E5["elbow_r"], "muzzle": ECLIPSE["muzzle"], "bearing": 0.12, "drum": 0.1, "bone": 0.055, "elbow_w": 0.11, "elbow_rad": 0.07,
       "armor_size": (0.2, 0.16), "hand": 1.6, "fingers": 4, "core": 0.1, "plate": (0.14, 0.12)}


def m10_pauldron(p, side, drum, pin, elbow):
    cbox(p, "shell", (side * 0.6, 1.52, 0.02), (0.38, 0.32, 0.46), 0.06)
    cbox(p, "trim", (side * 0.6, 1.69, 0.02), (0.26, 0.03, 0.36), 0.01)
    cbox(p, "trim", (side * 0.795, 1.52, 0.02), (0.02, 0.2, 0.3), 0.006)
    front_screws(p, (side * 0.6, 1.52), 0.13, 0.1, -0.212, 0.01)


M10["pauldron"] = m10_pauldron


def magnus10_shoulders(p):
    v10_shoulders(p, M10)


def magnus10_arm(p):
    def armor(q, m, length):
        cbox(q, "shell", sub(m, 0, length * 0.5, 0), (0.3, length * 0.86, 0.3), 0.05)
        cbox(q, "trim", sub(m, 0, length * 0.2, 0), (0.31, 0.04, 0.31), 0.012)
        cbox(q, "trim", sub(m, 0, length * 0.86, 0), (0.31, 0.04, 0.31), 0.012)
        front_screws(q, tuple(at(m, 0, length * 0.5, 0))[:2], 0.1, 0.1, at(m, 0, length * 0.5, 0).z - 0.152, 0.009)
    v10_forearm(p, M10, armor)

    def gun_armor(q, m):
        cbox(q, "shell", sub(m, 0, 0.24, 0), (0.33, 0.4, 0.33), 0.05)
        cbox(q, "trim", sub(m, 0, 0.1, 0), (0.34, 0.04, 0.34), 0.012)
        cbox(q, "dark", sub(m, 0, 0.46, 0), (0.24, 0.06, 0.24), 0.02)
    v10_gun_forearm(p, dict(M10, ring_at=0.5, ring_r=0.1), gun_armor)


def magnus10_leg(p, out):
    def thigh(q, o, top, bottom):
        h = top - bottom
        cbox(q, "shell", (0, top - h / 2, -0.02), (0.32, h, 0.32), 0.05)
        cbox(q, "dark", (o * 0.165, top - h / 2, 0.0), (0.012, h * 0.7, 0.16), 0.004)

    def shin(q, o, top, bottom, mid):
        h = top - bottom
        cbox(q, "shell", (0, top - h / 2, -0.02), (0.34, h, 0.34), 0.05, taper=(0.88, 0.88))
        cbox(q, "trim", (0, top - 0.03, -0.16), (0.2, 0.1, 0.06), 0.02)

    def boots(q, m, o, ankle):
        foot(q, m, length=0.5, width=0.36, out=o, toes=2, armor="shell", heel="dark")
    leg(p, out, ECLIPSE["hip"].y, knee_y=-0.34, ankle_up=0.2, width=1.35, knee_w=0.14, knee_r=0.075, foot_fn=boots, thigh_fn=thigh, shin_fn=shin, guard=True, guard_role="trim", hub_r=0.09)


# ---- FAÍSCA 10 ------------------------------------------------------------------------
F10 = {"shoulder_y": 1.47, "bracket": 0.2, "elbow_l": F9["elbow_l"], "wrist_l": Vector((-0.43, 0.84, -0.08)),
       "elbow_r": F9["elbow_r"], "muzzle": F9["muzzle"], "bearing": 0.075, "drum": 0.06, "bone": 0.03, "elbow_w": 0.065, "elbow_rad": 0.04,
       "armor_size": (0.1, 0.09), "hand": 1.0, "fingers": 3, "core": 0.05, "plate": (0.08, 0.07), "drop": 0.1}


def f10_pauldron(p, side, drum, pin, elbow):
    cbox(p, "shell", (drum.x + side * 0.02, drum.y + 0.05, 0.01), (0.16, 0.08, 0.2), 0.03, rot=(0, 0, -side * 18))
    cbox(p, "trim", (drum.x + side * 0.08, drum.y + 0.03, 0.01), (0.02, 0.06, 0.18), 0.005, rot=(0, 0, -side * 18))


F10["pauldron"] = f10_pauldron


def faisca10_shoulders(p):
    v10_shoulders(p, F10)


def faisca10_arm(p):
    def armor(q, m, length):
        cbox(q, "shell", sub(m, 0, length * 0.42, -0.01), (0.12, length * 0.6, 0.12), 0.03)
        for i in range(2):
            mbox(q, "glow", sub(m, 0, length * 0.32 + i * 0.06, -0.072), (0.05, 0.012, 0.004), 0.002, 1)
        cbox(q, "trim", sub(m, 0, length * 0.78, 0), (0.13, 0.03, 0.13), 0.006)
    v10_forearm(p, F10, armor)

    def gun_armor(q, m):
        cbox(q, "shell", sub(m, 0, 0.22, 0), (0.13, 0.3, 0.13), 0.03)
        cbox(q, "trim", sub(m, 0, 0.08, 0), (0.14, 0.025, 0.14), 0.006)
    v10_gun_forearm(p, dict(F10, ring_at=0.38, ring_r=0.06), gun_armor)


# ---- ÓRBITA 10 ------------------------------------------------------------------------
O10 = {"shoulder_y": 1.44, "bracket": 0.26, "elbow_l": O9["elbow_l"], "wrist_l": O9["wrist_l"],
       "elbow_r": O9["elbow_r"], "muzzle": O9["muzzle"], "bearing": 0.09, "drum": 0.075, "armor_size": (0.13, 0.12),
       "hand": 1.3, "fingers": 3, "core": 0.07}


def o10_pauldron(p, side, drum, pin, elbow):
    c = Vector((drum.x + side * 0.03, drum.y + 0.02, 0.01))
    a0, a1 = (-90, 90) if side > 0 else (90, 270)
    sphere_panel(p, "shell", T(*c), 0.15, (-10, 88), (a0 - 40, a1 + 40), 0.03, (12, 6), gap=0.01)
    mring(p, "trim", axis_frame(c, "x"), 0.155, 0.014, 26, 6)
    bolts(p, axis_frame(c + Vector((side * 0.12, 0, 0)), "x" if side > 0 else "-x"), 0.05, 6, size=0.009)


O10["pauldron"] = o10_pauldron


def orbita10_shoulders(p):
    v10_shoulders(p, O10)


def orbita10_arm(p):
    def armor(q, m, length):
        cyl_panel(q, "shell", sub(m, 0, length * 0.42, 0), 0.1, length * 0.55, (-80, 80), 0.03, (10, 2), gap=0.012, radius_top=0.095)
        cyl_panel(q, "shell", sub(m, 0, length * 0.42, 0), 0.1, length * 0.55, (100, 260), 0.03, (10, 2), gap=0.012, radius_top=0.095)
        mring(q, "trim", sub(m, 0, length * 0.74, 0), 0.105, 0.014, 22, 6)
    v10_forearm(p, O10, armor)

    def gun_armor(q, m):
        lathe(q, "shell", m, [(0.0, 0.07), (0.08, 0.08), (0.11, 0.14), (0.115, 0.3), (0.1, 0.4), (0.0, 0.42)], 24)
        mring(q, "trim", sub(m, 0, 0.2, 0), 0.117, 0.013, 24, 5)
    v10_gun_forearm(p, dict(O10, ring_at=0.44, ring_r=0.085), gun_armor)


def orbita10_leg(p, out):
    def boots(q, m, o, ankle):
        foot(q, m, length=0.42, width=0.28, out=o, toes=2, armor="shell", heel="trim")
        mbox(q, "shell", sub(m, 0, 0.16, 0.0), (0.2, 0.1, 0.22), 0.05)
        mring(q, "trim", axis_frame(at(m, 0, 0.21, 0.0), "y"), 0.1, 0.012, 20, 6)
    leg(p, out, O9["hip"].y, knee_y=-0.26, ankle_up=0.2, width=1.05, knee_w=0.11, knee_r=0.058, foot_fn=boots,
        thigh_fn=round_thigh(k=1.05), shin_fn=round_shin(k=1.05, r_bottom=0.1, r_top=0.12), thigh_top=0.02, guard=False, shin_top=-0.2)


# ---- ECLIPSE: a garra passa a ter dedos de três falanges com pinos ----------------------
def eclipse8_claw(p):
    e, w = E8["elbow_l"], E8["wrist_l"]
    m = frame(e, w - e, front=(0.3, 0, -1))
    L = (w - e).length
    plate = wrist(p, m, L - 0.05, plate=(0.12, 0.1))
    palm = sub(m, 0, L + 0.08, 0)
    mbox(p, "dark", palm, (0.14, 0.09, 0.12), 0.015)
    mbox(p, "shell", sub(palm, 0, 0.0, -0.065), (0.15, 0.08, 0.025), 0.01)
    for u in (-1, 1):
        screw(p, sub(palm, u * 0.045, 0.0, -0.08, rot=(-90, 0, 0)), 0, 0, 0.007)
    for i in (-1, 0, 1):
        base = sub(palm, i * 0.045, 0.05, 0.0, rot=(180, 0, -i * 8))
        mbox(p, "metal", base, (0.035, 0.02, 0.05), 0.006, 1)
        mk.finger(p, sub(base, 0, -0.01, 0), (0.09, 0.08, 0.07), (10, 24, 30), width=0.034, role="dark", tip="metal")
    thumb = sub(palm, 0.075, 0.02, 0.03, rot=(180, 0, 40))
    mk.finger(p, thumb, (0.06, 0.05), (10, 30), width=0.03, role="dark", tip="metal")


# --------------------------------------------------------------------------------------
# BATIDA 11: a DJ, feita como os doze v2 - cascos curvos em gomos com juntas, torneados e a
# mecânica à vista. Cabeça em tambor deitado (um rádio-leitor): ecrã à frente numa moldura,
# colunas de som torneadas nas duas pontas, pega em arco e antena. Tronco em pipo com a coluna
# de som no peito, pescoço, cintura e bacia v2; ombreiras-coluna com grelha; antebraço
# esquerdo em cascos com mão de quatro dedos; megafone no direito; pernas redondas.
# --------------------------------------------------------------------------------------
B11 = {"hip": Vector((0.2, 0.7, 0.0)), "shoulder_y": 1.34, "bracket": 0.25, "elbow_l": Vector((-0.48, 1.04, 0.02)),
       "wrist_l": Vector((-0.51, 0.77, -0.1)), "elbow_r": Vector((0.48, 1.04, -0.02)), "muzzle": Vector((0.44, 0.86, -1.0)),
       "bearing": 0.095, "drum": 0.075, "armor_size": (0.12, 0.11), "hand": 1.3, "fingers": 4}
B11_CHEST = Vector((0.0, 1.18, 0.02))
B11_TORSO = [(-0.24, 0.15), (-0.18, 0.2), (-0.08, 0.245), (0.04, 0.265), (0.14, 0.26), (0.21, 0.225), (0.26, 0.15)]
B11_HEAD = Vector((0.0, 1.72, -0.01))
B11_HEAD_R = 0.16
B11_SCREEN = (0.26, 0.14)


def batida11_head(p):
    c, r = B11_HEAD, B11_HEAD_R
    mk.HEADS["batida11_head"] = {"top": round(c.y + r + 0.12, 3), "center": round(c.y, 3), "aspect": round(B11_SCREEN[0] / B11_SCREEN[1], 3)}
    drum = axis_frame(c, "x")
    mtube(p, "dark", drum, r - 0.03, 0.4, 24)
    # Casco do tambor em gomos, com a janela da frente aberta para o ecrã.
    for lo in ((-60, 20), (25, 115), (120, 200), (205, 240)):
        cyl_panel(p, "shell", drum, r, 0.36, lo, 0.03, (10, 2), gap=0.012)
    for dx in (-0.17, 0.17):
        mring(p, "trim", axis_frame((c.x + dx, c.y, c.z), "x"), r + 0.004, 0.014, 28, 6)
    # Moldura, vidro recuado e o ecrã.
    face = T(c.x, c.y, c.z - r + 0.03)
    mbox(p, "dark", face, (0.32, 0.2, 0.06), 0.02)
    mbox(p, "trim", sub(face, 0, 0, -0.022), (0.33, 0.21, 0.02), 0.02, 2)
    p.screen((c.x, c.y, c.z - r - 0.004), B11_SCREEN, bulge=0.01)
    for u in (-1, 1):
        for v in (-1, 1):
            screw(p, plane((c.x + u * 0.15, c.y + v * 0.09, c.z - r - 0.012), (0, 0, -1), (1, 0, 0)), 0, 0, 0.007)
    # Colunas de som nas pontas: cone torneado, anel de borracha, grelha e parafusos.
    for side in (-1, 1):
        end = axis_frame((side * 0.2, c.y, c.z), "x" if side > 0 else "-x")
        lathe(p, "trim", end, [(r - 0.005, 0.0), (r + 0.01, 0.02), (r - 0.01, 0.05), (0.0, 0.052)], 28, True)
        mring(p, "rubber", sub(end, 0, 0.05, 0), 0.11, 0.014, 26, 6)
        lathe(p, "dark", sub(end, 0, 0.03, 0), [(0.1, 0.02), (0.05, 0.0), (0.02, 0.012), (0.0, 0.012)], 22, True)
        ball(p, "metal", at(end, 0, 0.045, 0), 0.028, 12)
        bolts(p, sub(end, 0, 0.05, 0), 0.13, 6, size=0.008)
        mring(p, "glow", sub(end, 0, 0.056, 0), 0.085, 0.006, 24, 4)
    # Pega em arco com as charneiras, antena e o autocolante.
    for side in (-1, 1):
        mbox(p, "dark", T(side * 0.13, c.y + r + 0.01, c.z + 0.02), (0.05, 0.05, 0.06), 0.012)
        mtube(p, "metal", axis_frame((side * 0.13, c.y + r + 0.02, c.z + 0.02), "x"), 0.012, 0.07, 8)
    arc_tube(p, "trim", axis_frame((0, c.y + r + 0.02, c.z + 0.02), "z"), 0.13, 0.018, 0, 180, 24, 8)
    rod(p, "metal", (0.1, c.y + r - 0.02, c.z + 0.1), (0.13, c.y + r + 0.16, c.z + 0.12), 0.008, 6)
    ball(p, "glow", (0.13, c.y + r + 0.17, c.z + 0.12), 0.018, 10)
    serial(p, plane((0.0, c.y - 0.06, c.z + r + 0.001), (0, 0, 1), (1, 0, 0)), "04", 0.036)


def batida11_torso(p, with_neck=True):
    c = B11_CHEST
    top, bottom = B11_TORSO[-1][0], B11_TORSO[0][0]
    if with_neck:
        neck(p, c.y + top - 0.005, B11_HEAD.y - B11_HEAD_R + 0.01, 0.06, 0.0, plate=(0.2, 0.18))
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, 0.86, 1.0))
    lathe(p, "dark", flat, [(0.0, bottom)] + [(r - 0.035, y) for y, r in B11_TORSO] + [(0.0, top)], 26)
    for lo, yr in (((-150, -115), (-0.22, 0.23)), ((-65, -30), (-0.22, 0.23)), ((-112, -68), (-0.22, -0.06)),
                   ((-112, -68), (0.19, 0.23)), ((-26, 30), (-0.22, 0.23)), ((34, 146), (-0.22, 0.23)), ((150, 206), (-0.22, 0.23))):
        rev_panel(p, "shell", flat, B11_TORSO, yr, lo, 0.034, (10, 8), gap=0.012)
    mring(p, "trim", sub(flat, 0, bottom + 0.03, 0), profile_radius(B11_TORSO, bottom + 0.03) + 0.004, 0.016, 26, 5)
    mring(p, "trim", sub(flat, 0, top - 0.03, 0), profile_radius(B11_TORSO, top - 0.03) + 0.004, 0.014, 26, 5)
    # A coluna de som no peito: cone escuro, suspensão, cúpula e o anel aceso.
    spk = axis_frame((0, c.y + 0.065, c.z - 0.265 * 0.86 + 0.02), "-z")
    mtube(p, "trim", spk, 0.13, 0.03, 28, bevel=0.006)
    lathe(p, "dark", sub(spk, 0, 0.012, 0), [(0.115, 0.0), (0.06, -0.035), (0.03, -0.03), (0.0, -0.03)], 26, True)
    mring(p, "rubber", sub(spk, 0, 0.016, 0), 0.105, 0.012, 26, 6)
    ball(p, "metal", at(spk, 0, -0.01, 0), 0.03, 12)
    mring(p, "glow", sub(spk, 0, 0.018, 0), 0.122, 0.005, 28, 4)
    bolts(p, sub(spk, 0, 0.016, 0), 0.122, 8, size=0.008)
    q, n = rev_point(c, B11_TORSO, 0.86, -130, 0.12)
    serial(p, plane(q, n, (math.sin(math.radians(-130)), 0, -math.cos(math.radians(-130)))), "04", 0.028)
    q, n = rev_point(c, B11_TORSO, 0.86, 90, -0.1)
    charging_port(p, plane(q, n, (0, 0, 1)), 0.042, 0.026)
    q, n = rev_point(c, B11_TORSO, 0.86, 90, 0.1)
    warning(p, plane(q, n, (1, 0, 0)), 0.04)
    # Gira-discos às costas: prato, braço e a agulha.
    deck = axis_frame((0, c.y + 0.04, c.z + 0.265 * 0.86 + 0.02), "z")
    mtube(p, "dark", deck, 0.14, 0.03, 26)
    mtube(p, "trim", sub(deck, 0, 0.02, 0), 0.125, 0.008, 26)
    mtube(p, "metal", sub(deck, 0, 0.03, 0), 0.02, 0.02, 10)
    rod(p, "metal", at(deck, 0.1, 0.03, 0.1), at(deck, -0.03, 0.03, 0.06), 0.006, 6)
    waist(p, 0.8, c.y + bottom + 0.02, 0.115)
    pelvis(p, (0, 0.72, 0.0), (0.26, 0.15, 0.25), B11["hip"].x, B11["hip"].y, 0.084)


def b11_pauldron(p, side, drum, pin, elbow):
    m = T(drum.x + side * 0.012, drum.y + 0.02, 0.01)
    a0, a1 = (-90, 90) if side > 0 else (90, 270)
    sphere_panel(p, "shell", m, 0.15, (18, 88), (a0 - 30, a1 + 30), 0.03, (12, 5), gap=0.01)
    sphere_panel(p, "trim", m, 0.155, (2, 16), (a0 - 25, a1 + 25), 0.026, (12, 2), gap=0.006)
    grille = axis_frame(drum + Vector((side * 0.13, 0.03, 0.0)), "x" if side > 0 else "-x")
    mtube(p, "dark", grille, 0.07, 0.02, 20)
    for k in range(3):
        mring(p, "metal", sub(grille, 0, 0.012, 0), 0.02 + k * 0.02, 0.004, 18, 4)
    bolts(p, sub(grille, 0, 0.01, 0), 0.075, 6, size=0.007)


B11["pauldron"] = b11_pauldron


def batida11_shoulders(p):
    v10_shoulders(p, B11)


def batida11_arm(p):
    def armor(q, m, length):
        for lo in ((-80, 80), (100, 260)):
            cyl_panel(q, "shell", sub(m, 0, length * 0.42, 0), 0.1, length * 0.55, lo, 0.03, (10, 2), gap=0.012, radius_top=0.095)
        lathe(q, "trim", sub(m, 0, length * 0.72, 0), [(0.09, 0.0), (0.108, 0.0), (0.125, 0.06), (0.12, 0.07), (0.075, 0.07), (0.09, 0.0)], 22)
        mbox(q, "glow", sub(m, 0, length * 0.45, 0.103), (0.04, 0.012, 0.01), 0.003, 1)
    v10_forearm(p, B11, armor)

    def gun_armor(q, m):
        lathe(q, "shell", m, [(0.0, 0.07), (0.07, 0.08), (0.1, 0.14), (0.105, 0.3), (0.095, 0.4), (0.0, 0.42)], 24)
        for v in (0.15, 0.36):
            mring(q, "trim", sub(m, 0, v, 0), 0.104, 0.013, 24, 5)
    v10_gun_forearm(p, dict(B11, ring_at=0.44, ring_r=0.08), gun_armor)


def batida11_gun(p):
    # Megafone: garganta escura, campânula torneada a abrir, aro e o diafragma aceso.
    e, muzzle = B11["elbow_r"], B11["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    L = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.5, 0), 0.05, 0.08, 16)
    lathe(p, "trim", m, [(0.04, 0.54), (0.045, 0.62), (0.07, L - 0.2), (0.12, L - 0.04), (0.125, L)], 24)
    mring(p, "shell", sub(m, 0, L - 0.005, 0), 0.125, 0.014, 26, 6)
    mtube(p, "glow", sub(m, 0, L - 0.12, 0), 0.06, 0.008, 18)
    bolts(p, sub(m, 0, 0.6, 0), 0.05, 5, size=0.007)


def batida11_leg(p, out):
    def shoes(q, m, o, ankle):
        foot(q, m, length=0.4, width=0.25, out=o, toes=2, armor="shell", heel="trim")
    leg(p, out, B11["hip"].y, knee_y=-0.26, ankle_up=0.17, width=0.95, knee_w=0.108, knee_r=0.058, foot_fn=shoes,
        thigh_fn=round_thigh(k=0.95), shin_fn=round_shin(k=0.95, r_bottom=0.09, r_top=0.115), thigh_top=0.03, guard=False, shin_top=-0.21)


# ======================================================================================
# Skins do modo DIFÍCIL: o mesmo robô, outra cor (no roster) e alguns adereços, modelados no
# lugar. "_x_extra" vai no tronco (não roda com a cabeça); "_x_hat" vai na cabeça.
# ======================================================================================
def leaf_to(p, role, origin, direction, length, width, front=(0, 0, -1)):
    leaf(p, role, frame(Vector(origin), Vector(direction), front=front), length, width)


def broto_x_hat(p):
    c = BR_HEAD
    top = c.y + 0.07 + BR_HEAD_R * 0.8
    # Duas folhas grandes a abrir do topo da cabeça, uma terceira para trás e uma flor.
    for side in (-1, 1):
        leaf_to(p, "shell", (side * 0.05, top - 0.02, 0.0), (side * 0.75, 1.0, 0.1), 0.44, 0.26)
        leaf_to(p, "trim", (side * 0.04, top - 0.03, 0.02), (side * 0.35, 1.0, 0.5), 0.26, 0.14)
    leaf_to(p, "shell", (0.0, top - 0.02, 0.05), (0.0, 0.8, 1.0), 0.36, 0.22, front=(0, 1, 0))
    flower = Vector((0.0, top + 0.12, -0.02))
    rod(p, "dark", (0.0, top - 0.02, 0.0), flower, 0.012, 8)
    for i in range(6):
        a = math.radians(i * 60)
        leaf_to(p, "trim", flower, (math.cos(a), 0.25, math.sin(a)), 0.1, 0.07, front=(0, 1, 0))
    ball(p, "glow", flower + Vector((0, 0.02, 0)), 0.035, 12)
    # Trepadeira à volta da cabeça: folhinhas no aro.
    for i in range(7):
        a = math.radians(-150 + i * 50)
        at_ring = Vector((math.cos(a) * (BR_HEAD_R + 0.01), c.y + 0.075, math.sin(a) * (BR_HEAD_R + 0.01)))
        leaf_to(p, "shell", at_ring, (math.cos(a), 0.6, math.sin(a)), 0.09, 0.06, front=(0, 1, 0))


def broto_x_extra(p):
    # O vaso das costas vira um arbusto: três caules com folhas grandes e rebentos acesos,
    # e duas trepadeiras que descem pelos ombros.
    pot = Vector((0.0, BR_CHEST.y + 0.15, BR_CHEST.z + 0.28 + 0.14))
    for k, (dx, dz, h) in enumerate(((-0.07, 0.0, 0.55), (0.06, 0.03, 0.7), (0.0, -0.04, 0.45))):
        base = pot + Vector((dx, 0.0, dz))
        tip = base + Vector((dx * 2.2, h, 0.06))
        rod(p, "dark", base, tip, 0.016, 8)
        for j in range(3):
            t = 0.4 + j * 0.25
            q = base.lerp(tip, t)
            side = 1 if (j + k) % 2 else -1
            leaf_to(p, "shell", q, (side * 1.0, 0.7, 0.35), 0.3 - j * 0.04, 0.18 - j * 0.02)
        ball(p, "glow", tip, 0.03, 10)
    for side in (-1, 1):
        prev = pot + Vector((side * 0.1, 0.05, -0.05))
        for i in range(6):
            t = (i + 1) / 6
            q = Vector((side * (0.1 + 0.3 * t), BR_CHEST.y + 0.2 + 0.1 * math.sin(t * 3.0), pot.z - 0.45 * t))
            rod(p, "dark", prev, q, 0.009, 6)
            leaf_to(p, "shell", q, (side * 0.4, -0.3 if i % 2 else 0.5, 0.6 - t), 0.1, 0.07, front=(0, 1, 0))
            prev = q


def salvo_x_extra(p):
    # Segundo casulo de mísseis no ombro esquerdo e uma cartucheira pelas costas.
    pod = T(-0.5, 1.52, -0.02)
    mbox(p, "shell", pod, (0.26, 0.2, 0.36), 0.03)
    mbox(p, "trim", sub(pod, 0, 0.105, 0), (0.24, 0.02, 0.3), 0.008, 1)
    for ix in (-0.06, 0.06):
        for iy in (-0.045, 0.045):
            tube = axis_frame((-0.5 + ix, 1.52 + iy, -0.2), "-z")
            mtube(p, "dark", tube, 0.042, 0.05, 14)
            mtube(p, "glow", sub(tube, 0, 0.02, 0), 0.028, 0.02, 12)
    mbox(p, "dark", T(-0.5, 1.4, 0.0), (0.08, 0.06, 0.2), 0.01)
    bolts(p, sub(pod, 0, 0.11, 0), 0.08, 4, size=0.008)
    for i in range(9):
        t = i / 8
        q = Vector((-0.3 + 0.6 * t, 1.42 - 0.5 * t, 0.36 + 0.04 * math.sin(t * math.pi)))
        shell = frame(q, (0.35, 0.6, 0.0), front=(0, 0, 1))
        mtube(p, "metal", shell, 0.022, 0.09, 10)
        mtube(p, "glow", sub(shell, 0, 0.055, 0), 0.016, 0.02, 10)
    rod(p, "dark", (-0.32, 1.44, 0.33), (0.32, 0.9, 0.33), 0.018, 8)
    rod(p, "dark", (0.22, 1.5, 0.3), (0.28, 2.2, 0.34), 0.008, 6)
    ball(p, "glow", (0.28, 2.21, 0.34), 0.02, 8)

    # Radar de tiro às costas, a varrer, com o emissor aceso.
    mast = Vector((-0.16, 1.5, 0.4))
    rod(p, "metal", mast, mast + Vector((0, 0.28, 0.02)), 0.018, 8)
    dish = frame(mast + Vector((0, 0.3, 0.03)), (0.0, 0.5, 1.0))
    lathe(p, "shell", dish, [(0.0, 0.0), (0.06, 0.005), (0.12, 0.03), (0.13, 0.045), (0.12, 0.05), (0.0, 0.01)], 20)
    rod(p, "metal", at(dish, 0, 0.02, 0), at(dish, 0, 0.11, 0), 0.008, 6)
    ball(p, "glow", at(dish, 0, 0.115, 0), 0.02, 8)
    # Placas de blindagem aparafusadas nos ombros e faróis de combate no peito.
    for side in (-1, 1):
        plate = T(side * 0.56, 1.4, 0.0) @ Matrix.Rotation(math.radians(-side * 18), 4, "Z")
        mbox(p, "trim", plate, (0.2, 0.05, 0.3), 0.012)
        bolts(p, sub(plate, 0, 0.026, 0), 0.08, 4, size=0.008)
        lamp = axis_frame((side * 0.17, 1.52, -0.3), "-z")
        mtube(p, "dark", lamp, 0.045, 0.05, 14)
        mtube(p, "glow", sub(lamp, 0, 0.026, 0), 0.034, 0.01, 14)
        mring(p, "metal", sub(lamp, 0, 0.028, 0), 0.046, 0.007, 14, 4)
    # Dois escapes de motor diesel com a boca em brasa.
    for side in (-1, 1):
        pipe = T(side * 0.26, 1.05, 0.4)
        mtube(p, "metal", sub(pipe, 0, 0.25, 0), 0.03, 0.5, 12)
        lathe(p, "dark", sub(pipe, 0, 0.5, 0), [(0.03, 0.0), (0.04, 0.06), (0.03, 0.06)], 12)
        mtube(p, "glow", sub(pipe, 0, 0.555, 0), 0.026, 0.01, 12)


def bigorna_x_extra(p):
    # Duas chaminés de forja às costas, a arder por dentro, e faróis nos ombros.
    for side in (-1, 1):
        base = T(side * 0.16, 1.22, 0.42)
        mtube(p, "metal", sub(base, 0, 0.32, 0), 0.06, 0.66, 18)
        for v in (0.12, 0.4):
            mring(p, "trim", sub(base, 0, v, 0), 0.066, 0.012, 20, 5)
        lathe(p, "dark", sub(base, 0, 0.64, 0), [(0.06, 0.0), (0.085, 0.06), (0.095, 0.1), (0.075, 0.1), (0.05, 0.02)], 20)
        mtube(p, "glow", sub(base, 0, 0.7, 0), 0.05, 0.02, 16)
        mbox(p, "dark", T(side * 0.16, 1.2, 0.38), (0.12, 0.1, 0.08), 0.015)
        dome(p, "glow", T(side * 0.6, 1.53, 0.0), 0.06, 0.07, 14, 4)
        mring(p, "dark", T(side * 0.6, 1.53, 0.0), 0.064, 0.012, 16, 4)
    rod(p, "dark", (-0.16, 1.55, 0.42), (0.16, 1.55, 0.42), 0.02, 8)


def batida_x_extra(p):
    # Torre de colunas às costas: duas colunas viradas para trás e néon em arco por cima.
    box = T(0.0, 1.18, 0.44)
    mbox(p, "dark", box, (0.42, 0.56, 0.16), 0.03)
    mbox(p, "trim", sub(box, 0, 0.29, 0), (0.44, 0.03, 0.18), 0.01, 1)
    for v in (-0.13, 0.13):
        cone = axis_frame((0.0, 1.18 + v, 0.52), "z")
        mring(p, "trim", cone, 0.11, 0.014, 24, 5)
        lathe(p, "shell", cone, [(0.1, 0.0), (0.05, -0.03), (0.02, -0.04), (0.0, -0.04)], 20)
        mtube(p, "glow", sub(cone, 0, 0.005, 0), 0.03, 0.01, 14)
    arc_tube(p, "glow", T(0.0, 1.46, 0.44) @ Matrix.Rotation(math.radians(90), 4, "X"), 0.2, 0.012, 200, 340, 20, 6)
    for side in (-1, 1):
        rod(p, "metal", (side * 0.18, 1.46, 0.44), (side * 0.22, 1.8, 0.44), 0.01, 6)
        ball(p, "glow", (side * 0.22, 1.82, 0.44), 0.025, 10)

    # Anéis de néon à volta das colunas dos ombros e um gira-discos aceso em cima da torre.
    for side in (-1, 1):
        ring = axis_frame((side * 0.5, 1.3, 0.0), "x")
        mring(p, "glow", ring, 0.13, 0.014, 26, 5)
        mring(p, "trim", sub(ring, 0, side * 0.01, 0), 0.155, 0.008, 26, 4)
    deck = T(0.0, 1.49, 0.44)
    mtube(p, "dark", deck, 0.17, 0.03, 26)
    mtube(p, "glow", sub(deck, 0, 0.018, 0), 0.14, 0.008, 26)
    mtube(p, "dark", sub(deck, 0, 0.025, 0), 0.05, 0.012, 16)
    rod(p, "metal", (0.13, 1.52, 0.36), (0.02, 1.53, 0.48), 0.008, 6)
    # Barras de equalizador acesas pelos lados da torre.
    for side in (-1, 1):
        for k, h in enumerate((0.12, 0.22, 0.16, 0.28, 0.1)):
            mbox(p, "glow", T(side * 0.22, 0.97 + h / 2, 0.36 + k * 0.035), (0.012, h, 0.022), 0.003, 1)


def batida_x_hat(p):
    # Crista de néon: cinco barbatanas acesas ao longo do topo da cabeça.
    for i in range(5):
        z = -0.12 + i * 0.06
        h = 0.08 + 0.05 * math.sin(i / 4 * math.pi)
        extruded(p, "glow", T(0.0, 2.02, z) @ Matrix.Rotation(math.radians(90), 4, "Y"),
                 [(-0.025, 0.0), (0.025, 0.0), (0.0, h)], 0.02)

    # Auscultadores de néon: aros acesos dos dois lados da cabeça e um microfone.
    for side in (-1, 1):
        ear = axis_frame((side * 0.285, 1.72, 0.0), "x")
        mring(p, "glow", ear, 0.1, 0.016, 24, 5)
        mtube(p, "dark", ear, 0.08, 0.03, 20)
    rod(p, "metal", (0.29, 1.66, -0.02), (0.18, 1.58, -0.2), 0.008, 6)
    ball(p, "glow", (0.17, 1.575, -0.21), 0.022, 8)


def rosca_x_extra(p):
    # Chave inglesa gigante e chave de fendas cruzadas às costas, e um pirilampo no topo.
    back = 0.5
    a, b = Vector((-0.3, 0.8, back)), Vector((0.3, 1.6, back))
    rod(p, "metal", a, b, 0.03, 10)
    for end, d in ((b, (b - a).normalized()), (a, (a - b).normalized())):
        jaw = frame(end, d, front=(0, 0, 1))
        extruded(p, "metal", jaw, [(-0.09, -0.03), (0.09, -0.03), (0.09, 0.1), (0.035, 0.1), (0.035, 0.03), (-0.035, 0.03), (-0.035, 0.1), (-0.09, 0.1)], 0.05)
    c, d2 = Vector((0.28, 0.85, back + 0.04)), Vector((-0.2, 1.5, back + 0.04))
    rod(p, "trim", c, c.lerp(d2, 0.4), 0.04, 12)
    rod(p, "metal", c.lerp(d2, 0.4), d2, 0.016, 8)
    mbox(p, "dark", T(0.0, 1.2, back - 0.05), (0.14, 0.12, 0.06), 0.015)
    gauge = axis_frame((0.0, 1.2, back - 0.015), "z")
    mtube(p, "glow", gauge, 0.035, 0.012, 16)
    mring(p, "trim", gauge, 0.038, 0.008, 16, 4)
    for t in (0.3, 0.7):
        q = a.lerp(b, t)
        mring(p, "glow", frame(q, b - a), 0.034, 0.008, 12, 4)
    dome(p, "glow", T(0.0, 1.71, 0.0), 0.05, 0.06, 14, 4)
    mring(p, "dark", T(0.0, 1.71, 0.0), 0.054, 0.012, 16, 4)

    # Dois turbos às costas com as hélices acesas e uma asa de corrida por cima.
    for side in (-1, 1):
        turbo = axis_frame((side * 0.2, 1.0, 0.52), "z")
        mtube(p, "metal", turbo, 0.1, 0.12, 22)
        mring(p, "trim", sub(turbo, 0, 0.06, 0), 0.1, 0.012, 22, 5)
        for k in range(6):
            a = math.radians(k * 60 + 15)
            blade = sub(turbo, 0, 0.065, 0, rot=(0, math.degrees(a), 0))
            mbox(p, "glow", sub(blade, 0.045, 0, 0), (0.07, 0.008, 0.02), 0.004, 1)
        ball(p, "dark", at(turbo, 0, 0.07, 0), 0.025, 10)
    for side in (-1, 1):
        rod(p, "dark", (side * 0.18, 1.5, 0.46), (side * 0.2, 1.8, 0.6), 0.016, 8)
    wing = T(0.0, 1.82, 0.62)
    mbox(p, "trim", wing, (0.7, 0.035, 0.18), 0.012)
    for side in (-1, 1):
        mbox(p, "shell", T(side * 0.35, 1.76, 0.62), (0.02, 0.14, 0.2), 0.006)
    mbox(p, "glow", sub(wing, 0, 0.02, 0.06), (0.6, 0.008, 0.02), 0.003, 1)
    # Faixas de corrida pelo casco, à frente.
    for dx in (-0.06, 0.06):
        mbox(p, "trim", T(dx, 1.12, -0.28), (0.04, 0.5, 0.012), 0.004, 1)


def gancho_x_extra(p):
    # Mastro com bandeira negra às costas e um tricórnio no casco.
    base = Vector((0.18, 0.9, 0.46))
    top = Vector((0.18, 2.35, 0.46))
    rod(p, "metal", base, top, 0.02, 10)
    ball(p, "trim", top + Vector((0, 0.03, 0)), 0.03, 10)
    rod(p, "metal", (0.18, 2.2, 0.46), (0.18, 2.2, 0.8), 0.012, 8)
    flag = T(0.18, 1.9, 0.63) @ Matrix.Rotation(math.radians(90), 4, "Y")
    extruded(p, "dark", flag, [(-0.17, -0.28), (0.17, -0.28), (0.14, 0.0), (0.17, 0.28), (-0.17, 0.28)], 0.01)
    ball(p, "glow", (0.19, 1.93, 0.63), 0.05, 12)
    # Lanterna acesa pendurada na verga.
    rod(p, "metal", (0.18, 2.2, 0.72), (0.18, 2.08, 0.72), 0.006, 6)
    lantern = T(0.18, 2.02, 0.72)
    mtube(p, "glow", lantern, 0.035, 0.08, 12)
    lathe(p, "dark", sub(lantern, 0, 0.04, 0), [(0.045, 0.0), (0.0, 0.035)], 12)
    mring(p, "dark", sub(lantern, 0, -0.04, 0), 0.04, 0.008, 12, 4)
    for tilt in (-1, 1):
        extruded(p, "trim", T(0.19, 1.84, 0.63) @ Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Rotation(math.radians(tilt * 40), 4, "Z"),
                 [(-0.012, -0.08), (0.012, -0.08), (0.012, 0.08), (-0.012, 0.08)], 0.016)
    hat = T(0.0, 1.5, -0.01) @ Matrix.Rotation(math.radians(14), 4, "X")
    lathe(p, "dark", hat, [(0.0, 0.0), (0.33, 0.0), (0.345, 0.02), (0.32, 0.036), (0.0, 0.036)], 32)
    dome(p, "dark", sub(hat, 0, 0.03, 0), 0.25, 0.2, 28, 7)
    mring(p, "trim", sub(hat, 0, 0.055, 0), 0.252, 0.016, 28, 5)
    for i in range(3):
        a = math.radians(-90 + i * 120)
        lathe(p, "dark", sub(hat, math.cos(a) * 0.25, 0.02, math.sin(a) * 0.25), [(0.085, 0.0), (0.09, 0.08), (0.0, 0.1)], 12)
    gem = at(hat, 0.0, 0.12, -0.245)
    ball(p, "glow", gem, 0.034, 10)
    mring(p, "trim", frame(Vector(gem), (0, 0.3, -1.0)), 0.038, 0.007, 14, 4)
    for tilt in (-1, 1):
        rod(p, "trim", at(hat, -0.05 * tilt, 0.07, -0.245), at(hat, 0.05 * tilt, 0.17, -0.235), 0.008, 6)
    # Lanterna à anca, pendurada de um gancho.
    hook = Vector((-0.34, 0.86, 0.02))
    rod(p, "metal", hook, hook + Vector((-0.02, -0.08, 0.0)), 0.007, 6)
    hip_lamp = T(*(hook + Vector((-0.02, -0.14, 0.0))))
    mtube(p, "glow", hip_lamp, 0.04, 0.09, 12)
    lathe(p, "dark", sub(hip_lamp, 0, 0.045, 0), [(0.05, 0.0), (0.0, 0.04)], 12)
    mring(p, "dark", sub(hip_lamp, 0, -0.045, 0), 0.045, 0.009, 12, 4)
    for k in range(4):
        a = math.radians(k * 90 + 45)
        rod(p, "dark", at(hip_lamp, math.cos(a) * 0.042, -0.045, math.sin(a) * 0.042), at(hip_lamp, math.cos(a) * 0.042, 0.045, math.sin(a) * 0.042), 0.005, 4)


def bit_x_extra(p):
    # BIT de elite: bateria às costas com três células acesas, escapes e luzes nos ombros.
    pack = T(0.0, 1.12, 0.52)
    mbox(p, "dark", pack, (0.36, 0.42, 0.16), 0.03)
    mbox(p, "trim", sub(pack, 0, 0.225, 0), (0.38, 0.03, 0.18), 0.01, 1)
    for dx in (-0.1, 0.0, 0.1):
        cell = axis_frame((dx, 1.12, 0.605), "y")
        mtube(p, "glow", cell, 0.03, 0.3, 12)
        mring(p, "metal", sub(cell, 0, 0.15, 0), 0.034, 0.008, 12, 4)
        mring(p, "metal", sub(cell, 0, -0.15, 0), 0.034, 0.008, 12, 4)
    for side in (-1, 1):
        pipe = axis_frame((side * 0.22, 1.22, 0.5), "y")
        mtube(p, "metal", pipe, 0.035, 0.34, 12)
        mtube(p, "glow", sub(pipe, 0, 0.18, 0), 0.026, 0.02, 12)
        dome(p, "glow", T(side * 0.56, 1.46, 0.0), 0.05, 0.05, 12, 4)
        mring(p, "dark", T(side * 0.56, 1.46, 0.0), 0.054, 0.01, 14, 4)
    rod(p, "glow", (-0.15, 0.95, 0.605), (0.15, 0.95, 0.605), 0.01, 6)


def bit_x_hat(p):
    # Aletas acesas dos dois lados do ecrã e uma antena alta com um farol.
    for side in (-1, 1):
        extruded(p, "glow", T(side * 0.3, 1.86, 0.0) @ Matrix.Rotation(math.radians(90), 4, "Y"),
                 [(-0.12, -0.04), (0.1, -0.02), (0.14, 0.1), (-0.06, 0.05)], 0.02)
    rod(p, "metal", (-0.12, 2.05, 0.05), (-0.16, 2.4, 0.08), 0.01, 6)
    ball(p, "glow", (-0.16, 2.42, 0.08), 0.03, 10)


def magnus_x_extra(p):
    # MAGNUS imperador: coroa de ouro com gemas acesas, dois estandartes às costas e a
    # estrela do Penta acesa entre eles.
    crown = T(0.0, 1.74, 0.02)
    mring(p, "trim", crown, 0.17, 0.02, 32, 6)
    for i in range(5):
        a = math.radians(-90 + i * 72)
        base = Vector((math.cos(a) * 0.17, 1.74, math.sin(a) * 0.17 + 0.02))
        lathe(p, "trim", frame(base, (0, 1, 0)), [(0.035, 0.0), (0.02, 0.07), (0.0, 0.13)], 8)
        ball(p, "glow", base + Vector((0, 0.03, 0)), 0.02, 8)
    star = T(0.0, 1.35, 0.6)
    pts = []
    for i in range(10):
        a = math.radians(90 + i * 36)
        r = 0.16 if i % 2 == 0 else 0.07
        pts.append((math.cos(a) * r, math.sin(a) * r))
    extruded(p, "glow", star, pts, 0.04)
    mring(p, "trim", axis_frame((0.0, 1.35, 0.6), "z"), 0.2, 0.014, 36, 5)
    rod(p, "metal", (0.0, 1.35, 0.56), (0.0, 1.35, 0.45), 0.02, 8)
    for side in (-1, 1):
        pole_a, pole_b = Vector((side * 0.36, 0.95, 0.42)), Vector((side * 0.42, 2.25, 0.45))
        rod(p, "trim", pole_a, pole_b, 0.018, 8)
        ball(p, "glow", pole_b + Vector((0, 0.03, 0)), 0.035, 10)
        banner = T(side * 0.42, 1.92, 0.47) @ Matrix.Rotation(math.radians(90), 4, "Y")
        extruded(p, "dark", banner, [(-0.02, -0.24), (0.2, -0.3), (0.2, 0.24), (-0.02, 0.24)] if side > 0 else [(0.02, -0.24), (-0.2, -0.3), (-0.2, 0.24), (0.02, 0.24)], 0.012)
        mbox(p, "glow", T(side * 0.42, 1.74, 0.57), (0.03, 0.03, 0.2), 0.008, 1)


def faisca_x_extra(p):
    # Dois para-raios gigantes às costas, em ziguezague aceso sobre uma base de cobre.
    for side in (-1, 1):
        base = Vector((side * 0.16, 1.3, 0.34))
        mtube(p, "metal", axis_frame(base, "y"), 0.05, 0.14, 14)
        mring(p, "trim", axis_frame(base + Vector((0, 0.07, 0)), "y"), 0.054, 0.012, 16, 4)
        bolt = T(*(base + Vector((0, 0.07, 0.0)))) @ Matrix.Rotation(math.radians(-side * 14), 4, "Z") @ Matrix.Diagonal((3.2, 3.4, 1.0, 1.0))
        extruded(p, "glow", bolt, BOLT, 0.03)
    rod(p, "dark", (-0.16, 1.3, 0.34), (0.16, 1.3, 0.34), 0.02, 8)


def faisca_x_hat(p):
    # Coroa de três raios pequenos no alto da cabeça.
    for i, side in enumerate((-1, 0, 1)):
        m = T(side * 0.08, 2.1, -0.02 + abs(side) * 0.03) @ Matrix.Rotation(math.radians(-side * 20), 4, "Z") @ Matrix.Diagonal((1.3, 1.1 if side else 1.4, 1.0, 1.0))
        extruded(p, "glow", m, BOLT, 0.02)


def orbita_x_extra(p):
    # Anel orbital dourado às costas com três satélites e uma estrela no topo.
    m = T(0.0, 1.38, 0.5) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Rotation(math.radians(18), 4, "Z")
    mring(p, "trim", m, 0.44, 0.022, 48, 6)
    mring(p, "metal", m, 0.36, 0.01, 40, 5)
    for i, role in enumerate(("glow", "shell", "trim")):
        a = math.radians(30 + i * 120)
        ball(p, role, at(m, math.cos(a) * 0.44, 0.0, math.sin(a) * 0.44), 0.05 if role == "glow" else 0.04, 12)
    mbox(p, "dark", T(0.0, 1.38, 0.4), (0.16, 0.16, 0.1), 0.02)
    star = T(0.0, 1.9, 0.5)
    pts = []
    for i in range(10):
        a = math.radians(90 + i * 36)
        r = 0.09 if i % 2 == 0 else 0.04
        pts.append((math.cos(a) * r, math.sin(a) * r))
    extruded(p, "glow", star, pts, 0.03)
    rod(p, "metal", (0.0, 1.8, 0.5), (0.0, 1.47, 0.5), 0.01, 6)


def eclipse_x_extra(p):
    # Um eclipse às costas: disco negro com a coroa rubra acesa à volta, lâminas em
    # crescente com as pontas em brasa, veias de luz pelas costas e crescentes nos ombros.
    m = T(0.0, 1.62, 0.48) @ Matrix.Rotation(math.radians(90), 4, "X")
    lathe(p, "dark", m, [(0.0, -0.02), (0.36, -0.02), (0.36, 0.02), (0.0, 0.02)], 40)
    mring(p, "glow", m, 0.4, 0.034, 48, 6)
    mring(p, "glow", m, 0.22, 0.012, 40, 5)
    mring(p, "trim", m, 0.46, 0.014, 48, 5)
    ball(p, "glow", at(m, 0.0, -0.03, 0.0), 0.05, 12)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        tip = at(m, math.cos(a) * 0.62, 0.0, math.sin(a) * 0.62)
        root = at(m, math.cos(a) * 0.44, 0.0, math.sin(a) * 0.44)
        d = (Vector(tip) - Vector(root)).normalized()
        lathe(p, "metal", frame(Vector(root), d, front=(0, 0, 1)), [(0.035, 0.0), (0.02, 0.12), (0.0, 0.19)], 8)
        ball(p, "glow", Vector(root) + d * 0.15, 0.016, 8)
    mbox(p, "dark", T(0.0, 1.5, 0.4), (0.14, 0.2, 0.1), 0.02)
    for side in (-1, 1):
        rod(p, "glow", (side * 0.12, 0.98, 0.39), (side * 0.16, 1.4, 0.4), 0.012, 6)
        rod(p, "glow", (side * 0.16, 1.4, 0.4), (side * 0.08, 1.52, 0.42), 0.012, 6)
        # Crescente a pairar sobre o ombro, preso por um espigão.
        c = Vector((side * 0.6, 1.93, 0.0))
        rod(p, "dark", (side * 0.6, 1.8, 0.0), c, 0.018, 8)
        arc_tube(p, "glow", T(*c) @ Matrix.Rotation(math.radians(90), 4, "X"), 0.13, 0.02, 200, 340, 18, 6)
        arc_tube(p, "dark", T(*(c + Vector((0, 0, 0.01)))) @ Matrix.Rotation(math.radians(90), 4, "X"), 0.155, 0.012, 205, 335, 18, 5)
        for k in (-1, 1):
            base = Vector((side * (0.6 + k * 0.12), 1.79, 0.0))
            lathe(p, "dark", frame(base, (side * 0.3 + k * 0.3, 1.0, 0.0)), [(0.026, 0.0), (0.012, 0.09), (0.0, 0.13)], 8)
            ball(p, "glow", base + Vector((side * 0.3 + k * 0.3, 1.0, 0.0)).normalized() * 0.12, 0.012, 8)


def eclipse_x_hat(p):
    # Coroa de espigões por cima do elmo, com as pontas acesas.
    for i in range(5):
        a = math.radians(-90 + (i - 2) * 30)
        base = Vector((math.cos(a) * 0.1, 1.97, math.sin(a) * 0.1 + 0.02))
        d = Vector((math.cos(a) * 0.35, 1.0, math.sin(a) * 0.35)).normalized()
        lathe(p, "dark", frame(base, d), [(0.028, 0.0), (0.016, 0.1), (0.0, 0.16 if i == 2 else 0.12)], 10)
        ball(p, "glow", base + d * (0.15 if i == 2 else 0.11), 0.014, 8)


def helio_x_extra(p):
    # Um sol poente atrás das asas: disco vermelho com o núcleo aceso e coroas de luz, doze
    # raios alternados em luz e ouro, um halo aceso sobre a coroa e sóis nos ombros.
    m = T(0.0, 1.72, 0.78) @ Matrix.Rotation(math.radians(90), 4, "X")
    lathe(p, "shell", m, [(0.0, -0.014), (0.46, -0.014), (0.46, 0.014), (0.0, 0.014)], 48)
    lathe(p, "glow", m, [(0.0, 0.014), (0.34, 0.014), (0.34, 0.026), (0.0, 0.026)], 40)
    lathe(p, "glow", m, [(0.0, -0.026), (0.34, -0.026), (0.34, -0.014), (0.0, -0.014)], 40)
    mring(p, "trim", m, 0.36, 0.012, 48, 5)
    mring(p, "glow", m, 0.41, 0.02, 52, 5)
    mring(p, "trim", m, 0.5, 0.03, 56, 6)
    mring(p, "glow", m, 0.56, 0.012, 60, 5)
    for i in range(12):
        a = math.radians(i * 30)
        root = Vector(at(m, math.cos(a) * 0.52, 0.0, math.sin(a) * 0.52))
        d = (root - Vector(at(m, 0, 0, 0))).normalized()
        lathe(p, "glow", frame(root, d, front=(0, 0, 1)), [(0.045 if i % 2 == 0 else 0.035, 0.0), (0.0, 0.26 if i % 2 == 0 else 0.16)], 8)
    rod(p, "metal", (0.0, 1.5, 0.22), (0.0, 1.62, 0.76), 0.02, 8)
    halo = T(0.0, 2.06, 0.02) @ Matrix.Rotation(math.radians(-12), 4, "X")
    mring(p, "glow", halo, 0.2, 0.018, 36, 6)
    mring(p, "trim", halo, 0.225, 0.008, 36, 4)
    for side in (-1, 1):
        orb = Vector((side * 0.44, 1.6, 0.0))
        ball(p, "glow", orb, 0.06, 14)
        mring(p, "trim", axis_frame(orb, "y"), 0.085, 0.01, 20, 4)
        for i in range(6):
            a = math.radians(i * 60)
            d = Vector((math.cos(a), 0.0, math.sin(a)))
            lathe(p, "trim", frame(orb + d * 0.09, d), [(0.014, 0.0), (0.0, 0.06)], 6)


# ======================================================================================
def define(part):
    part("bigorna3_hull")(bigorna_hull)
    part("salvo3_hull")(salvo_hull)
    part("gancho3_hull")(gancho_hull)
    part("gancho3x_hull")(lambda q: gancho_hull(q, peak=False, name="gancho3x_hull"))
    part("batida3_hull")(batida_hull)
    part("rosca3_hull")(rosca_hull)
    part("broto3_hull")(broto_hull)
    part("faisca3_hull")(faisca_hull)
    part("eclipse3_hull")(eclipse_hull)
    part("helio3_hull")(helio_hull)
    part("helio3_spin")(helio_crown)
    part("helio6_wings")(helio6_wings)
    part("orbita9_3_spin")(orbita9_spin)
    for name in ("broto", "salvo", "bigorna", "batida", "rosca", "gancho", "faisca", "orbita", "eclipse", "helio", "bit", "magnus"):
        for slot in ("extra", "hat"):
            fn = globals().get(name + "_x_" + slot)
            if fn is not None:
                part(name + "_x_" + slot)(fn)
    for slot in ("head", "torso", "shoulders", "arm", "gun"):
        part("batida11_" + slot)(globals()["batida11_" + slot])
    part("batida11_leg_l")(lambda q: batida11_leg(q, -1))
    part("batida11_leg_r")(lambda q: batida11_leg(q, 1))
    for robot in ("batida10", "magnus10", "faisca10", "orbita10"):
        for slot in ("shoulders", "arm", "gun"):
            fn = globals().get(robot + "_" + slot)
            if fn is not None:
                part(robot + "_" + slot)(softened(fn) if robot == "batida10" else fn)
        legfn = globals().get(robot + "_leg")
        if legfn is not None:
            legfn = softened(legfn) if robot == "batida10" else legfn
            part(robot + "_leg_l")(lambda q, fn=legfn: fn(q, -1))
            part(robot + "_leg_r")(lambda q, fn=legfn: fn(q, 1))
    part("eclipse6_wings")(eclipse6_wings)
    part("magnus3_hull")(magnus_hull)
    part("orbita3_hull")(orbita_hull)
    for slot in ("torso", "head", "shoulders", "arm", "gun"):
        extra = globals().get("faisca9_" + slot + "_detail")
        fn = globals()["faisca9_" + slot]
        part("faisca9_" + slot)(with_detail(fn, extra) if extra else fn)
    for robot in ("eclipse5", "magnus5", "orbita5", "batida5", "orbita6", "batida7", "eclipse8", "orbita9"):
        for slot in ("torso", "head", "shoulders", "arm", "gun"):
            fn = globals().get(robot + "_" + slot)
            if fn is not None:
                extra = globals().get(robot + "_" + slot + "_detail")
                built = with_detail(fn, extra) if extra else fn
                part(robot + "_" + slot)(softened(built) if robot == "batida7" and slot in ("head", "torso") else built)
        legfn = globals().get(robot + "_leg")
        if legfn is not None and globals().get(robot + "_leg_detail"):
            legfn = with_detail(legfn, globals()[robot + "_leg_detail"])
        if legfn is None:
            continue
        part(robot + "_leg_l")(lambda q, fn=legfn: fn(q, -1))
        part(robot + "_leg_r")(lambda q, fn=legfn: fn(q, 1))
    part("eclipse4_hull")(eclipse4_hull)
    part("batida4_hull")(batida4_hull)
    part("orbita4_hull")(orbita4_hull)
    part("orbita4_spin")(orbita4_spin)
    part("magnus4_hull")(magnus4_hull)
    part("faisca4_hull")(faisca4_hull)
    for name, fn in (("eclipse4_leg", eclipse4_leg), ("batida4_leg", batida4_leg), ("orbita4_leg", orbita4_leg), ("magnus4_leg", magnus4_leg)):
        part(name + "_l")(lambda q, fn=fn: fn(q, -1))
        part(name + "_r")(lambda q, fn=fn: fn(q, 1))
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

    part("orbita2_head")(orbita_head)
    part("orbita2_torso")(orbita_torso)
    part("orbita2_shoulders")(orbita_shoulders)

    @part("orbita2_arm")
    def _(p):
        orbita_forearm_left(p)
        orbita_forearm_right(p)

    part("orbita2_gun")(orbita_gun)

    @part("orbita2_leg_l")
    def _(p):
        orbita_leg(p, -1)

    @part("orbita2_leg_r")
    def _(p):
        orbita_leg(p, 1)

    part("eclipse2_head")(eclipse_head)
    part("eclipse2_torso")(eclipse_torso)
    part("eclipse2_shoulders")(eclipse_shoulders)

    @part("eclipse2_arm")
    def _(p):
        eclipse_forearm_left(p)
        eclipse_forearm_right(p)

    part("eclipse2_gun")(eclipse_gun)

    @part("eclipse2_leg_l")
    def _(p):
        eclipse_leg(p, -1)

    @part("eclipse2_leg_r")
    def _(p):
        eclipse_leg(p, 1)

    part("helio2_head")(helio_head)
    part("helio2_torso")(helio_torso)
    part("helio2_shoulders")(helio_shoulders)

    @part("helio2_arm")
    def _(p):
        helio_forearm_left(p)
        helio_forearm_right(p)

    part("helio2_gun")(helio_gun)

    @part("helio2_leg_l")
    def _(p):
        helio_leg(p, -1)

    @part("helio2_leg_r")
    def _(p):
        helio_leg(p, 1)

    part("magnus2_head")(magnus_head)
    part("magnus2_torso")(magnus_torso)
    part("magnus2_shoulders")(magnus_shoulders)

    @part("magnus2_arm")
    def _(p):
        magnus_forearm_left(p)
        magnus_forearm_right(p)

    part("magnus2_gun")(magnus_gun)

    @part("magnus2_leg_l")
    def _(p):
        magnus_leg(p, -1)

    @part("magnus2_leg_r")
    def _(p):
        magnus_leg(p, 1)
    part("orbita2_spin")(orbita_spin)
    part("helio2_spin")(helio_spin)
    part("magnus2_spin")(magnus_spin)
