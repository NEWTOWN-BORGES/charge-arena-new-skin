"""Montagens mecânicas genéricas dos robôs v2, para o elenco inteiro cumprir o prompt de design
ponto por ponto (docs/ROBOS-V2.md): pescoço, tronco com chassis de nervuras, núcleo, cintura,
bacia e ancas, ombros, braços, cotovelos, pulsos, pernas, joelhos e tornozelos. Cada robô só
escolhe as medidas e desenha a sua blindagem por cima (curvas, cúpulas, painéis).

Coordenadas em unidades do Godot: Y para cima, frente em -Z, direita em +X.
"""
import math

from mathutils import Matrix, Vector

from mech_kit import (at, axis_frame, bearing, bolts, boot, cable, capsule, charging_port, connector,
                      dome, frame, hand, hinge, lathe, mbox, mring, mtube, piston, plane, rod, screw,
                      serial, servo, sub, vents, warning, finger)


def T(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


# ======================================================================================
# Pescoço: placas de montagem, veio, rolamento, vedante de pó, conduta, batente de rotação
# ======================================================================================
def neck(p, y0, y1, radius=0.078, z=0.02, plate=(0.27, 0.24), cable_x=0.08):
    mbox(p, "dark", T(0, y0 + 0.012, z), (plate[0], 0.024, plate[1]), 0.01, 1)
    mbox(p, "dark", T(0, y1, z), (plate[0] + 0.01, 0.02, plate[1] + 0.01), 0.01, 1)
    mtube(p, "metal", T(0, (y0 + y1) / 2, z), radius * 0.64, y1 - y0, 14)
    mring(p, "metal", T(0, y0 + (y1 - y0) * 0.68, z), radius * 1.09, 0.015, 22, 5)
    mtube(p, "rubber", T(0, y0 + (y1 - y0) * 0.43, z), radius, 0.036, 18)
    bolts(p, T(0, y0 + 0.024, z), radius * 1.35, 6, size=0.012)
    mbox(p, "dark", T(radius * 0.95, y0 + 0.04, z - radius * 0.95), (0.025, 0.03, 0.025), 0.005, 1)
    cable(p, [(cable_x, y0 + 0.02, z + 0.1), (cable_x + 0.02, (y0 + y1) / 2, z + 0.12), (cable_x + 0.01, y1 - 0.005, z + 0.11)], 0.012)


# ======================================================================================
# Tronco: chassis escuro com nervuras e calhas à vista entre os painéis
# ======================================================================================
def chassis(p, center, size, ribs=3, radius=0.05):
    c = Vector(center)
    mbox(p, "dark", T(*c), size, radius)
    # Nervuras verticais nas ilhargas e uma calha horizontal atrás: a estrutura que carrega o
    # peso aparece nas fendas entre a blindagem.
    for side in (-1, 1):
        for i in range(ribs):
            z = c.z + (i - (ribs - 1) / 2) * size[2] * 0.28
            mbox(p, "dark", T(c.x + side * (size[0] / 2 + 0.008), c.y, z), (0.018, size[1] * 0.86, 0.022), 0.006, 1)
    mbox(p, "metal", T(c.x, c.y + size[1] * 0.3, c.z + size[2] / 2 + 0.008), (size[0] * 0.7, 0.02, 0.016), 0.006, 1)


def core_round(p, m, radius=0.056, frame_role="trim"):
    """Núcleo redondo recuado: moldura de proteção, anel de retenção, célula com luz.
    `m` com o Y local a sair do peito."""
    mring(p, frame_role, sub(m, 0, -0.004, 0), radius * 1.35, radius * 0.28, 24, 6)
    mtube(p, "dark", sub(m, 0, -0.03, 0), radius * 1.25, 0.05, 20)
    mring(p, "metal", sub(m, 0, -0.008, 0), radius, radius * 0.18, 20, 5)
    mtube(p, "glow", sub(m, 0, -0.014, 0), radius * 0.82, 0.012, 18)
    mtube(p, "dark", sub(m, 0, -0.008, 0), radius * 0.34, 0.012, 10)
    bolts(p, sub(m, 0, 0.004, 0), radius * 1.35, 6, size=0.009)


# ======================================================================================
# Cintura: coluna, rolamento de guinada, fole de borracha, estabilizadores, feixe de cabos
# ======================================================================================
def waist(p, y0, y1, radius, z=0.02, stabilizers=2):
    mid = (y0 + y1) / 2
    mtube(p, "dark", T(0, mid, z), radius, y1 - y0, 20)
    mring(p, "metal", T(0, y1 - 0.015, z), radius * 1.25, 0.018, 26, 5)
    bolts(p, T(0, y1 - 0.005, z), radius * 1.25, 8, size=0.011, phase=0.2)
    n = 3
    for i in range(n):
        mring(p, "rubber", T(0, y0 + (y1 - y0) * (0.2 + i * 0.25), z), radius * 1.01, 0.016, 22, 5)
    for i in range(stabilizers):
        side = -1 if i % 2 == 0 else 1
        piston(p, (side * radius * 0.85, y0, z + radius * 0.85), (side * radius * 1.05, y1, z + radius * 0.95), 0.018)
    for dx in (-0.025, 0.025):
        cable(p, [(dx, y0, z + radius * 0.8), (dx * 1.4, mid, z + radius * 1.35), (dx, y1, z + radius * 1.25)], 0.01)


# ======================================================================================
# Bacia: chassis de distribuição, placas da frente e de trás, alojamentos das ancas
# (bacia → rolamento com parafusos → eixo; o garfo da coxa está na perna)
# ======================================================================================
def pelvis(p, center, size, hip_x, hip_y, house_r=0.09, team=True, front_role="trim", back_role="shell"):
    c = Vector(center)
    base = T(*c)
    mbox(p, "dark", base, size, 0.035)
    mbox(p, front_role, sub(base, 0, -0.01, -size[2] / 2 - 0.02, rot=(10, 0, 0)), (size[0] * 0.86, size[1] * 0.83, 0.05), 0.022)
    if team:
        mbox(p, "team", sub(base, 0, 0.03, -size[2] / 2 - 0.048, rot=(10, 0, 0)), (size[0] * 0.43, 0.028, 0.01), 0.004, 1)
    mbox(p, back_role, sub(base, 0, 0.0, size[2] / 2 + 0.02), (size[0] * 0.8, size[1] * 0.72, 0.05), 0.02)
    for side in (-1, 1):
        x0 = size[0] / 2 + 0.012
        house = axis_frame((side * x0, hip_y, 0.0), "x" if side > 0 else "-x")
        mtube(p, "dark", house, house_r, 0.04, 20, bevel=0.006)
        bolts(p, sub(house, 0, 0.022, 0), house_r * 0.83, 6, size=0.01)
        mtube(p, "metal", sub(house, 0, 0.02 + (hip_x - x0) / 2 + 0.03, 0), 0.04, hip_x - x0 + 0.07, 12)


# ======================================================================================
# Ombro: suporte → rolamento → tambor → garfo → pino → braço, com batente de rotação
# ======================================================================================
def shoulder(p, side, bracket_x, y, z=0.01, bearing_r=0.105, drum_r=0.082, drum_len=0.08, drum_role="trim", pin_drop=0.12):
    """Devolve a posição do pino de abdução, onde o braço se pendura."""
    mbox(p, "dark", T(side * bracket_x, y, z), (0.07, 0.17, 0.19), 0.018)
    bx = bracket_x + 0.05
    bearing(p, axis_frame((side * bx, y, z), "x" if side > 0 else "-x"), bearing_r, 0.035, 6)
    dx = bx + 0.0175 + drum_len / 2 + 0.008
    drum = axis_frame((side * dx, y, z), "x")
    mtube(p, drum_role, drum, drum_r, drum_len, 18, bevel=0.01)
    mring(p, "dark", sub(drum, 0, side * drum_len * 0.38, 0), drum_r + 0.001, 0.008, 18, 4)
    mbox(p, "dark", T(side * (bx - 0.005), y + drum_r + 0.018, z + 0.075), (0.03, 0.035, 0.03), 0.006, 1)
    mtube(p, "metal", axis_frame((side * (bx + 0.03), y + drum_r + 0.008, z + 0.075), "x"), 0.008, 0.04, 8)
    pin = Vector((side * dx, y - pin_drop, z))
    for dz in (-1, 1):
        mbox(p, "dark", T(pin.x, pin.y + pin_drop * 0.46, z + dz * 0.052), (0.07, pin_drop + 0.01, 0.022), 0.01)
    mtube(p, "metal", axis_frame(pin, "z"), 0.016, 0.14, 8)
    for dz in (-1, 1):
        mtube(p, "metal", axis_frame(pin + Vector((0, 0, dz * 0.068)), "z" if dz > 0 else "-z"), 0.026, 0.01, 10)
    return pin, Vector((side * dx, y, z))


def upper_arm(p, side, pin, elbow, armor="shell", side_role="trim", bone_r=0.04, elbow_w=0.075, elbow_r=0.048, armor_size=(0.13, 0.11)):
    """Olhal no garfo do ombro, osso escuro, motor, calha de cabos, blindagem, cotovelo
    (dobradiça com garfo, eixo e tampas), atuador, fole e cabo."""
    mtube(p, "dark", axis_frame(pin, "z"), 0.032, 0.075, 12)
    rod(p, "dark", pin, elbow + Vector((0, 0.06, 0)), bone_r, 10)
    servo(p, axis_frame(pin.lerp(elbow, 0.45) + Vector((0, 0, 0.05)), "x"), 0.032, 0.05)
    arm = frame(pin.lerp(elbow, 0.5), elbow - pin)
    if armor:
        mbox(p, armor, sub(arm, 0, 0.0, 0.058), (armor_size[0], armor_size[1], 0.035), 0.014)
        mbox(p, side_role, sub(arm, side * 0.07, 0.0, 0.005), (0.032, armor_size[1], 0.12), 0.012)
    mbox(p, "dark", sub(arm, -side * 0.045, 0.0, -0.05), (0.022, 0.12, 0.018), 0.004, 1)
    hinge(p, axis_frame(elbow, "y"), elbow_w, elbow_r, fork_len=0.09)
    piston(p, pin.lerp(elbow, 0.3) + Vector((0, 0, 0.06)), elbow + Vector((0, -0.08, 0.07)), 0.016)
    boot(p, axis_frame(elbow + Vector((-side * 0.045, -0.01, 0.055)), "y"), 0.016, 0.06)
    cable(p, [pin.lerp(elbow, 0.4) + Vector((-side * 0.045, 0, -0.05)), elbow + Vector((-side * 0.045, 0.03, 0.055)),
              elbow + Vector((-side * 0.045, -0.05, 0.055))], 0.009)


def wrist(p, m, length, plate=(0.1, 0.09)):
    """Pulso no fim de um antebraço (referencial `m`, Y ao longo do braço): placa de fim,
    rolamento, pulso estreito, colar de borracha e placa da mão com patilhas aparafusadas.
    Devolve o referencial da placa da mão."""
    w = sub(m, 0, length, 0)
    mtube(p, "dark", sub(w, 0, -0.005, 0), 0.07, 0.02, 16)
    mring(p, "metal", sub(w, 0, 0.012, 0), 0.052, 0.012, 16, 5)
    mtube(p, "dark", sub(w, 0, 0.04, 0), 0.036, 0.06, 12)
    mring(p, "rubber", sub(w, 0, 0.032, 0), 0.04, 0.012, 14, 5)
    plate_m = sub(w, 0, 0.074, 0)
    mbox(p, "dark", plate_m, (plate[0], 0.02, plate[1]), 0.008, 1)
    for u in (-1, 1):
        for wv in (-1, 1):
            mtube(p, "metal", sub(plate_m, u * plate[0] * 0.4, 0.012, wv * plate[1] * 0.38), 0.007, 0.008, 6)
    return plate_m


def claw(p, m, scale=1.0, fingers=3, curl=1.0, role="metal"):
    """Garra: palma escura e três dedos compridos de pontas afiadas, com pinos nas juntas."""
    s = scale
    mbox(p, "dark", m, (0.1 * s, 0.07 * s, 0.07 * s), 0.014)
    mbox(p, "trim", sub(m, 0, 0.004, -0.042 * s), (0.1 * s, 0.065 * s, 0.02 * s), 0.01)
    for i in range(fingers):
        a = (i - (fingers - 1) / 2) * 32
        base = sub(m, 0, -0.035 * s, 0.0, rot=(0, a, 0))
        base = sub(base, 0, 0, -0.03 * s)
        finger(p, base, (0.05 * s, 0.045 * s, 0.045 * s), (10 * curl, 28 * curl, 34 * curl), width=0.028 * s, role="dark", tip=role)


# ======================================================================================
# Pernas: anca (cubo entre o garfo da coxa), coxa, joelho, canela, tornozelo (arfagem e
# inclinação lateral), amortecedor e pé
# ======================================================================================
def leg(p, out, hip_y, knee_y=-0.24, ankle_up=0.17, knee_z=-0.01, thigh="shell", thigh_side="trim",
        shin="shell", guard_role="trim", calf="shell", width=1.0, knee_w=0.12, knee_r=0.064,
        foot_fn=None, thigh_fn=None, shin_fn=None, hub_r=0.07, fork_gap=0.047, thigh_top=-0.05, guard=True,
        shin_top=None):
    """Perna no espaço da perna (pivô da anca na origem, chão em y = -hip_y). Sem `guard`, a
    caneleira sobe à frente do joelho (`shin_top`) e faz de joelheira; as tampas das juntas
    ficam à vista dos lados."""
    ground = -hip_y
    knee = Vector((0, knee_y, knee_z))
    ankle = Vector((0, ground + ankle_up, 0.0))
    k = width
    ox = "x" if out > 0 else "-x"
    hub = axis_frame((0.03 * out, 0, 0), ox)
    mtube(p, "dark", hub, hub_r, 0.07, 18, bevel=0.008)
    for s in (-1, 1):
        mbox(p, "dark", T((0.03 + s * fork_gap) * out, -0.04, 0.0), (0.02, 0.17, 0.15), 0.01)
    cap = sub(hub, 0, fork_gap + 0.019, 0)
    mtube(p, "metal", cap, hub_r * 0.83, 0.018, 18)
    bolts(p, sub(cap, 0, 0.01, 0), hub_r * 0.63, 6, size=0.01)
    mtube(p, "metal", sub(cap, 0, 0.016, 0), 0.022, 0.02, 6)
    top = -0.08
    beam_h = top - (knee_y + 0.075)
    mbox(p, "dark", T(0, top - beam_h / 2, 0.0), (0.13 * k, beam_h, 0.15 * k), 0.02)
    servo(p, axis_frame((-0.078 * k * out, top - beam_h * 0.45, 0.0), "-x" if out > 0 else "x"), 0.034, 0.03)
    piston(p, (0, -0.04, 0.1 * k), (0, knee_y + 0.02, 0.09 * k), 0.022)
    thigh_bottom = knee_y + knee_r + 0.012
    if thigh_fn:
        thigh_fn(p, out, thigh_top, thigh_bottom)
    else:
        h = -0.06 - thigh_bottom
        mbox(p, thigh, sub(T(0, -0.06 - h / 2, -0.1 * k), rot=(-4, 0, 0)), (0.24 * k, h, 0.06), 0.025)
        mbox(p, thigh_side, T(0.118 * k * out, -0.06 - h / 2 - 0.005, 0.0), (0.035, h - 0.01, 0.2 * k), 0.014)
        for v in (-1, 1):
            screw(p, sub(T(0.136 * k * out, -0.06 - h / 2, 0.0), rot=(0, 0, -90 * out)), 0.0, v * 0.06 * k)
        mbox(p, thigh, T(0, -0.06 - h / 2 + 0.01, 0.135 * k), (0.12 * k, h * 0.66, 0.022), 0.01)
    hinge(p, axis_frame(knee, "y"), knee_w, knee_r, fork_len=0.08, fork_thick=0.026)
    if guard:
        guard_m = sub(T(knee.x, knee.y - 0.035, knee.z - 0.085 - knee_r * 0.15), rot=(18, 0, 0))
        mbox(p, guard_role, guard_m, (0.17 * k, 0.08, 0.05), 0.02)
        mbox(p, "dark", T(knee.x, knee.y - 0.03, knee.z - 0.05), (0.05, 0.05, 0.05), 0.008, 1)
    cable(p, [(-0.035 * out, knee_y + 0.05, 0.08), (-0.04 * out, knee_y - 0.01, 0.11), (-0.035 * out, knee_y - 0.07, 0.08)], 0.01)
    mid = (knee_y + ankle.y) / 2
    mbox(p, "dark", T(0, mid, 0.01), (0.12 * k, knee_y - ankle.y, 0.12 * k), 0.018)
    shin_top = knee_y - 0.085 if shin_top is None else shin_top
    if shin_fn:
        shin_fn(p, out, shin_top, ankle.y + 0.035, mid)
    else:
        h = shin_top - (ankle.y + 0.035)
        mbox(p, shin, sub(T(0, shin_top - h / 2, -0.068 * k), rot=(0, 0, 180)), (0.22 * k, h, 0.08), 0.026, taper=(0.8, 0.86))
        for u in (-1, 1):
            screw(p, sub(T(u * 0.07 * k, shin_top - 0.04, -0.108 * k), rot=(-90, 0, 0)), 0, 0)
        side = T(0.1 * k * out, mid, 0.035)
        mbox(p, thigh_side, side, (0.03, min(0.15, h), 0.12 * k), 0.01)
        vents(p, sub(side, 0.016 * out, 0.02, 0.0), 3, 0.012, depth=0.08 * k, spacing=0.028)
        warning(p, plane((0.1155 * k * out, mid - 0.05, 0.035), (out, 0, 0), (0, 0, -out)), 0.03, 0.003)
    calf_m = T(0, mid + 0.01, 0.085 * k)
    mbox(p, calf, calf_m, (0.16 * k, min(0.13, knee_y - ankle.y - 0.08), 0.05), 0.018)
    mbox(p, "dark", sub(calf_m, 0, 0, 0.027), (0.08, 0.06, 0.006), 0.004, 1)
    for u in (-1, 1):
        for v in (-1, 1):
            screw(p, sub(calf_m, u * 0.03, v * 0.022, 0.031, rot=(90, 0, 0)), 0, 0, 0.006)
    mring(p, "rubber", T(0, ankle.y + 0.05, 0.01), 0.058 * k, 0.014, 16, 5)
    hinge(p, axis_frame(ankle, "y"), 0.075, 0.034, fork_len=0.06, fork_thick=0.02, bolt_count=3)
    mbox(p, "dark", T(0, ankle.y - 0.045, 0.0), (0.05, 0.026, 0.09), 0.006, 1)
    mtube(p, "metal", axis_frame(ankle + Vector((0, -0.045, 0.0)), "z"), 0.011, 0.14, 8)
    for dz in (-1, 1):
        mbox(p, "dark", T(0, ankle.y - 0.05, dz * 0.058), (0.045, 0.036, 0.016), 0.005, 1)
    piston(p, ankle + Vector((0, 0.08, 0.07)), ankle + Vector((0, -0.07, 0.11)), 0.014)
    mbox(p, "dark", T(0, ankle.y - 0.068, 0.0), (0.11, 0.018, 0.13), 0.008, 1)
    if foot_fn:
        foot_fn(p, T(0, ground, 0.0), out, ankle)


def bird_leg(p, out, hip_y, knee=(-0.16, -0.1), heel=(-0.36, 0.1), ankle_up=0.11, shell="shell", trim="trim", foot_fn=None, k=1.0):
    """Perna digitígrada (joelho à frente, calcanhar atrás, como uma ave): anca com garfo,
    coxa curta, joelho, canela para trás, calcanhar com segunda dobradiça, metatarso e pé.
    `knee` e `heel` são (y, z) no espaço da perna."""
    ground = -hip_y
    ox = "x" if out > 0 else "-x"
    hub = axis_frame((0.03 * out, 0, 0), ox)
    mtube(p, "dark", hub, 0.066, 0.07, 18, bevel=0.008)
    for s in (-1, 1):
        mbox(p, "dark", T((0.03 + s * 0.047) * out, -0.04, 0.0), (0.02, 0.16, 0.14), 0.01)
    cap = sub(hub, 0, 0.066, 0)
    mtube(p, "metal", cap, 0.055, 0.018, 18)
    bolts(p, sub(cap, 0, 0.01, 0), 0.042, 6, size=0.01)
    kn = Vector((0, knee[0], knee[1]))
    he = Vector((0, heel[0], heel[1]))
    an = Vector((0, ground + ankle_up, -0.02))
    # Coxa: viga da anca ao joelho, blindagem curva à frente, atuador atrás.
    rod(p, "dark", Vector((0, -0.04, 0)), kn, 0.045 * k, 12)
    tm = frame(Vector((0, -0.04, 0)).lerp(kn, 0.5), kn - Vector((0, -0.04, 0)), front=(0, 0, -1))
    mbox(p, shell, sub(tm, 0, 0, 0.05), (0.2 * k, (kn - Vector((0, -0.04, 0))).length * 0.8, 0.06), 0.028)
    mbox(p, trim, sub(tm, 0.1 * k * out, 0, 0.0), (0.03, (kn - Vector((0, -0.04, 0))).length * 0.7, 0.12 * k), 0.012)
    servo(p, axis_frame((-0.07 * out, -0.07, 0.0), "-x" if out > 0 else "x"), 0.03, 0.03)
    piston(p, Vector((0, -0.03, 0.07)), kn + Vector((0, 0.03, 0.06)), 0.018)
    hinge(p, axis_frame(kn, "y"), 0.11 * k, 0.058, fork_len=0.07, fork_thick=0.024)
    mbox(p, trim, sub(T(0, kn.y - 0.01, kn.z - 0.07), rot=(10, 0, 0)), (0.15 * k, 0.08, 0.045), 0.02)
    # Canela: do joelho ao calcanhar, para trás, com blindagem e ventilação.
    rod(p, "dark", kn, he, 0.04 * k, 12)
    sm = frame(kn.lerp(he, 0.5), he - kn, front=(0, 0, -1))
    mbox(p, shell, sub(sm, 0, 0, 0.045), (0.16 * k, (he - kn).length * 0.72, 0.05), 0.022)
    vents(p, sub(sm, 0.085 * k * out, 0.0, 0.0), 3, 0.012, depth=0.06, spacing=0.026)
    mbox(p, trim, sub(sm, 0.075 * k * out, 0.0, -0.01), (0.022, (he - kn).length * 0.6, 0.09), 0.008)
    cable(p, [kn + Vector((-0.035 * out, 0.04, 0.06)), kn + Vector((-0.04 * out, -0.02, 0.09)), kn.lerp(he, 0.4) + Vector((-0.035 * out, 0, 0.05))], 0.009)
    # Calcanhar: dobradiça com parafusos, amortecedor ao longo do metatarso.
    hinge(p, axis_frame(he, "y"), 0.08 * k, 0.045, fork_len=0.06, fork_thick=0.02, bolt_count=3)
    rod(p, "dark", he, an, 0.03 * k, 10)
    piston(p, he + Vector((0, 0.05, 0.05)), an + Vector((0, 0.02, 0.06)), 0.014)
    mbox(p, shell, sub(frame(he.lerp(an, 0.5), an - he), 0, 0, 0.035), (0.1 * k, (an - he).length * 0.6, 0.03), 0.012)
    # Tornozelo com arfagem e inclinação, e o pé.
    mring(p, "rubber", T(0, an.y + 0.045, an.z), 0.045, 0.012, 14, 5)
    hinge(p, axis_frame(an, "y"), 0.065, 0.03, fork_len=0.05, fork_thick=0.018, bolt_count=3)
    mbox(p, "dark", T(0, an.y - 0.04, an.z), (0.045, 0.024, 0.08), 0.006, 1)
    mtube(p, "metal", axis_frame(an + Vector((0, -0.04, 0)), "z"), 0.01, 0.12, 8)
    mbox(p, "dark", T(0, an.y - 0.06, an.z), (0.1, 0.016, 0.12), 0.008, 1)
    if foot_fn:
        foot_fn(p, T(0, ground, an.z), out, an)


# ======================================================================================
# Blindagem curva das pernas (para robôs de linhas redondas)
# ======================================================================================
def round_thigh(role="shell", side_role="trim", k=1.0, radius=0.125):
    """Coxa em cascos curvos: frente larga, placa do lado de fora com parafusos, proteção atrás
    afastada do atuador. O lado de dentro fica aberto e mostra o motor."""
    from mech_kit import cyl_panel

    def fn(p, out, top, bottom):
        h = top - bottom
        c = T(0, bottom + h / 2, 0.0)
        r = radius * k
        cyl_panel(p, role, c, r, h, (-150, -38), 0.035, (10, 2), gap=0.01)
        lo = (-30, 28) if out > 0 else (152, 210)
        cyl_panel(p, side_role, c, r + 0.004, h * 0.86, lo, 0.03, (6, 2), gap=0.01)
        cyl_panel(p, role, c, r + 0.035, h * 0.62, (58, 122), 0.025, (6, 2), gap=0.01)
        for v in (-1, 1):
            screw(p, frame((out * (r + 0.006), bottom + h / 2 + v * h * 0.28, 0.0), (out, 0, 0)), 0, 0)
    return fn


def round_shin(role="shell", side_role="trim", k=1.0, r_bottom=0.1, r_top=0.12):
    """Canela em cone: casco da frente que afunila para o tornozelo e placa do lado de fora
    com ventilação e aviso."""
    from mech_kit import cyl_panel

    def fn(p, out, top, bottom, mid):
        h = top - bottom
        c = T(0, bottom + h / 2, 0.0)
        cyl_panel(p, role, c, r_bottom * k, h, (-150, -36), 0.035, (10, 2), gap=0.01, radius_top=r_top * k)
        lo = (-30, 26) if out > 0 else (154, 210)
        cyl_panel(p, side_role, c, r_bottom * k + 0.004, h * 0.82, lo, 0.03, (6, 2), gap=0.01, radius_top=r_top * k + 0.004)
        rx = out * ((r_bottom + r_top) * 0.5 * k + 0.006)
        vents(p, T(rx, bottom + h * 0.62, 0.0), 3, 0.012, depth=0.07, spacing=0.026)
        warning(p, plane((rx + out * 0.001, bottom + h * 0.25, 0.0), (out, 0, 0), (0, 0, -out)), 0.03, 0.003)
        for deg in (-120, -66):
            a = math.radians(deg)
            rr = r_top * k + 0.002
            screw(p, frame((rr * math.cos(a), top - 0.035, rr * math.sin(a)), (math.cos(a), 0, math.sin(a))), 0, 0)
    return fn
