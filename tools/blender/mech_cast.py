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
