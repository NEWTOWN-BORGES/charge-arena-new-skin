"""BATIDA 12: a combat resonance engineer, modelled in Blender for Charge Arena.

Godot coordinates: Y up, front -Z. The hip and weapon anchors remain compatible
with BATIDA 11. Geometry is registered independently of the original robot kit.
"""
import math

from mathutils import Vector

import mech_kit as mk
from mech_kit import (at, axis_frame, bearing, bolts, cable, charging_port, foot, frame,
                      hand, lathe, mbox, mring, mtube, piston, plane, rod,
                      screw, serial, sub)
from mech_parts import T, chassis, leg, neck, pelvis, shoulder, upper_arm, waist, wrist


HIP = Vector((0.2, 0.7, 0.0))
HEAD = Vector((0.0, 1.72, -0.01))
ELBOW_L = Vector((-0.48, 1.04, 0.02))
WRIST_L = Vector((-0.51, 0.77, -0.1))
ELBOW_R = Vector((0.48, 1.04, -0.02))
MUZZLE = Vector((0.44, 0.86, -1.0))
VISOR = (0.46, 0.078)

DESIGN = {
    "hip": list(HIP), "muzzle": list(MUZZLE), "scale": [0.99, 0.99, 0.99],
    "eye_style": "equalizer", "mouth": False, "wear": 0.2,
    "parts": {
        "head": "batida12_head", "top": "", "spin": "",
        "torso": "batida12_torso", "shoulders": "batida12_shoulders",
        "back": "", "arm": "batida12_arm", "legs": "batida12_leg",
        "gun": "batida12_gun",
    },
    "palette": {
        "shell": "7e164c", "trim": "293344", "dark": "101821",
        "metal": "75889b", "glow": "00dcf0", "team": "",
        "eyes": "00e5ed", "rubber": "090f17",
    },
    "design_note": (
        "Engenho de combate sonico: cabeca larga e achatada com barra equalizadora, "
        "carapaca triangular magenta e grafite, subwoofer toracico grande e inclinado "
        "com grade, dois pods sonoros circulares assimetricos suspensos em suportes, "
        "disco percussivo no braco esquerdo, canhao de ressonancia largo, hub de "
        "anca compacto sem saia em U e pernas digitigradas com amortecedores."
    ),
}


def speaker(p, m, radius, shell_role="trim", cyan=True):
    """Recessed speaker diaphragm with load-bearing guard, not a painted disk."""
    r = radius
    mtube(p, "dark", sub(m, 0, -0.028, 0), r, 0.075, 20)
    mring(p, shell_role, m, r * 0.95, r * 0.13, 20, 5)
    mring(p, "rubber", sub(m, 0, -0.008, 0), r * 0.76, r * 0.10, 20, 5)
    lathe(p, "dark", sub(m, 0, -0.008, 0),
          [(r * 0.70, 0), (r * 0.40, -r * 0.18),
           (r * 0.18, -r * 0.12), (0, -r * 0.12)], 20, True)
    mtube(p, "metal", sub(m, 0, -r * 0.065, 0), r * 0.20, r * 0.035, 12)
    if cyan:
        mring(p, "glow", sub(m, 0, 0.003, 0), r * 0.82, r * 0.028, 20, 4)
    # Three protective slats follow the circular boundary. They sit ahead of
    # the diaphragm and bridge onto the retaining frame at both ends.
    for k in (-1, 0, 1):
        z = k * r * 0.40
        span = math.sqrt((r * 0.88) ** 2 - z ** 2) * 2
        mbox(p, "metal", sub(m, 0, r * 0.12, z),
             (span, r * 0.09, r * 0.055), 0.003, 1)
    bolts(p, sub(m, 0, 0.005, 0), r * 0.97, 6, size=r * 0.065, phase=math.pi / 6)


def batida12_head(p):
    c = HEAD
    mk.HEADS["batida12_head"] = {
        "top": 1.826, "center": c.y, "aspect": round(VISOR[0] / VISOR[1], 3)
    }
    # The low horizontal soundbar silhouette reads differently from a helmet.
    # Its equalizer is integrated into the whole front face, without cheeks.
    mbox(p, "dark", T(*c), (0.54, 0.155, 0.255), 0.025, 1)
    mbox(p, "shell", sub(T(*c), 0, 0.072, 0.006),
         (0.585, 0.058, 0.28), 0.017, 1, taper=(0.91, 0.88))
    mbox(p, "trim", sub(T(*c), 0, -0.069, 0.009),
         (0.55, 0.037, 0.27), 0.012, 1)
    p.screen((c.x, c.y, c.z - 0.136), VISOR, bulge=0.004)
    for side in (-1, 1):
        mbox(p, "shell", sub(T(*c), side * 0.265, 0, 0.0),
             (0.033, 0.126, 0.25), 0.010, 1)
        ear = axis_frame((side * 0.285, c.y, c.z + 0.015),
                         "x" if side > 0 else "-x")
        mtube(p, "dark", ear, 0.042, 0.012, 12)
        mring(p, "metal", sub(ear, 0, 0.008, 0), 0.031, 0.004, 12, 4)
        mbox(p, "glow", sub(ear, 0, 0.012, 0), (0.025, 0.003, 0.010), 0.002, 1)
        screw(p, plane((side * 0.252, c.y, c.z - 0.136),
                       (0, 0, -1), (1, 0, 0)), 0, 0, 0.008)
    # A recessed rear connector and two heat exhausts complete the helmet.
    for side in (-1, 1):
        for y in (-0.029, 0.006, 0.035):
            mbox(p, "rubber", sub(T(*c), side * 0.155, y, 0.134),
                 (0.08, 0.012, 0.01), 0.002, 1)
    charging_port(p, plane((0, c.y - 0.005, c.z + 0.134), (0, 0, 1), (1, 0, 0)), 0.045, 0.026)


def batida12_torso(p):
    neck(p, 1.475, 1.625, 0.055, 0.02, plate=(0.17, 0.15))
    # Taper the lower half almost to a point: the giant round chest driver is
    # the main shape, surrounded by an inverted triangular armor carrier.
    mbox(p, "dark", sub(T(0, 1.205, 0.025), rot=(0, 0, 180)),
         (0.62, 0.53, 0.34), 0.025, 1, taper=(0.29, 0.70))
    for side in (-1, 1):
        mbox(p, "shell", sub(T(side * 0.21, 1.23, -0.047),
                             rot=(0, -side * 10, -side * 25)),
             (0.13, 0.45, 0.30), 0.025, 1)
        mbox(p, "trim", sub(T(side * 0.22, 1.25, 0.17), rot=(0, 0, -side * 22)),
             (0.06, 0.35, 0.07), 0.012, 1)
        mbox(p, "shell", T(side * 0.14, 1.445, -0.08), (0.28, 0.07, 0.27), 0.017, 1)
        mbox(p, "glow", T(side * 0.15, 1.477, -0.115), (0.095, 0.008, 0.05), 0.003, 1)
    woofer = sub(axis_frame((0, 1.235, -0.225), "-z"), rot=(9, 0, 0))
    speaker(p, woofer, 0.235, shell_role="shell")
    # Backplate is a mechanical DJ controller: a protected flywheel, not an
    # ornamental turntable sticking out of the body.
    mbox(p, "trim", T(0, 1.255, 0.21), (0.32, 0.32, 0.08), 0.025, 1)
    rear = axis_frame((0, 1.26, 0.281), "z")
    mtube(p, "dark", rear, 0.105, 0.024, 20)
    mring(p, "metal", sub(rear, 0, 0.012, 0), 0.084, 0.007, 20, 4)
    mtube(p, "trim", sub(rear, 0, 0.018, 0), 0.062, 0.014, 18)
    mtube(p, "metal", sub(rear, 0, 0.03, 0), 0.018, 0.012, 8)
    for side in (-1, 1):
        for i in range(3):
            mbox(p, "rubber", T(side * 0.116, 1.075 + i * 0.028, 0.28),
                 (0.055, 0.011, 0.009), 0.002, 1)
        cable(p, [(side * 0.24, 1.28, 0.14), (side * 0.20, 1.05, 0.17),
                  (side * 0.09, 0.91, 0.08)], 0.012)
    # The waist is one compact spherical oscillator rather than an accordion
    # bellows or a pelvis skirt. Its lower width is only 0.178 units.
    p.ball("dark", (0, 0.843, 0.035), (0.19, 0.20, 0.20), detail=12)
    hub = axis_frame((0, 0.847, -0.065), "-z")
    mring(p, "trim", hub, 0.070, 0.013, 16, 4)
    mtube(p, "metal", sub(hub, 0, 0.011, 0), 0.033, 0.010, 12)
    mring(p, "glow", sub(hub, 0, 0.015, 0), 0.05, 0.004, 16, 4)
    mbox(p, "dark", T(0, 0.734, 0.06), (0.15, 0.065, 0.13), 0.018, 1)
    for side in (-1, 1):
        a = Vector((side * 0.06, 0.84, 0.09))
        b = Vector((side * HIP.x, HIP.y, 0.025))
        rod(p, "dark", a, b, 0.027, 10)
        rod(p, "metal", a.lerp(b, 0.45), b, 0.017, 10)
        bearing(p, axis_frame((side * HIP.x, HIP.y, 0),
                             "x" if side > 0 else "-x"), 0.059, 0.025, 4)


def batida12_shoulders(p):
    for side in (-1, 1):
        y = 1.49 if side < 0 else 1.42
        r = 0.153 if side < 0 else 0.134
        center = Vector((side * 0.445, y, -0.015))
        ax = axis_frame(center, "-z")
        # Two asymmetrical suspended circular pods, with an open triangular
        # support arc. Their load-bearing struts remain visible from behind.
        for z in (-0.015, 0.12):
            rod(p, "trim", (side * 0.255, 1.435, z),
                (side * 0.37, y + 0.15, z), 0.028, 10)
            rod(p, "trim", (side * 0.37, y + 0.15, z),
                (side * 0.54, y + 0.08, z), 0.025, 10)
        lathe(p, "shell", ax,
              [(r * 0.87, -0.09), (r * 1.06, -0.06),
               (r * 1.06, 0.055), (r * 0.91, 0.074)], 18, True)
        speaker(p, sub(ax, 0, 0.079, 0), r * 0.85)
        pin = Vector((side * 0.435, 1.27, 0.005))
        elbow = ELBOW_L if side < 0 else ELBOW_R
        bearing(p, axis_frame(pin, "x" if side > 0 else "-x"), 0.067, 0.038, 4)
        rod(p, "dark", pin, elbow, 0.036, 10)
        a = frame(pin.lerp(elbow, 0.47), elbow - pin)
        mbox(p, "shell", sub(a, 0, 0, 0.045), (0.105, 0.155, 0.055), 0.012, 1)
        piston(p, pin + Vector((side * 0.03, -0.03, 0.07)),
               elbow + Vector((side * 0.03, 0.035, 0.07)), 0.014)
        bearing(p, axis_frame(elbow, "x" if side > 0 else "-x"), 0.048, 0.056, 3)


def batida12_arm(p):
    e, w = ELBOW_L, WRIST_L
    length = (w - e).length
    m = frame(e, w - e, front=(0.15, 0, -1))
    rod(p, "dark", e, w, 0.041, 10)
    mbox(p, "trim", sub(m, 0, length * 0.46, 0), (0.15, length * 0.65, 0.15), 0.020, 2)
    mbox(p, "shell", sub(m, 0, length * 0.47, 0.087),
         (0.17, length * 0.58, 0.048), 0.018, 2, taper=(0.9, 0.9))
    for k in (-1, 0, 1):
        mbox(p, "glow", sub(m, k * 0.04, length * 0.46, 0.114),
             (0.017, 0.055 + 0.026 * (k == 0), 0.006), 0.002, 1)
    # A percussion disk is built into the left wrist as an asymmetric visual
    # signature. The articulated hand remains visible underneath it.
    disk = axis_frame(at(m, -0.11, length * 0.64, 0), "-x")
    mtube(p, "dark", disk, 0.142, 0.022, 18)
    mtube(p, "shell", sub(disk, 0, 0.014, 0), 0.128, 0.012, 18)
    mring(p, "metal", sub(disk, 0, 0.023, 0), 0.092, 0.006, 18, 4)
    mring(p, "glow", sub(disk, 0, 0.024, 0), 0.132, 0.004, 18, 4)
    cable(p, [at(m, -0.078, 0.02, 0), at(m, -0.082, length * 0.46, -0.044),
              at(m, -0.048, length * 0.83, -0.044)], 0.010)
    palm = wrist(p, m, length * 0.8, plate=(0.105, 0.1))
    hand(p, sub(palm, 0, 0.075, 0, rot=(180, 0, 0)), fingers=3,
         scale=1.12, curl=0.65, armor="trim")
    # The right forearm houses the resonance capacitor; its ring coupling
    # ends at the start of the separately animated weapon assembly.
    m = frame(ELBOW_R, MUZZLE - ELBOW_R, front=(0, 1, 0))
    mtube(p, "dark", sub(m, 0, 0.195, 0), 0.085, 0.32, 18)
    mbox(p, "shell", sub(m, 0, 0.20, 0.066), (0.20, 0.26, 0.055), 0.020, 2)
    mbox(p, "trim", sub(m, 0, 0.20, -0.066), (0.18, 0.24, 0.042), 0.012, 1)
    for pos in (0.105, 0.325):
        mring(p, "metal", sub(m, 0, pos, 0), 0.086, 0.012, 18, 5)
    mring(p, "rubber", sub(m, 0, 0.376, 0), 0.072, 0.012, 18, 4)
    mring(p, "glow", sub(m, 0, 0.344, 0), 0.082, 0.004, 18, 4)


def batida12_gun(p):
    m = frame(ELBOW_R, MUZZLE - ELBOW_R, front=(0, 1, 0))
    length = (MUZZLE - ELBOW_R).length
    # A compact pressure chamber and reinforced aperture replace the toy
    # megaphone. Parallel rails show the actual load path of the weapon.
    lathe(p, "dark", m, [(0.065, 0.38), (0.095, 0.44), (0.097, length - 0.14),
                          (0.14, length - 0.075), (0.14, length),
                          (0.109, length), (0.090, length - 0.095)], 20)
    for pos in (0.445, 0.53, 0.615):
        mring(p, "trim", sub(m, 0, pos, 0), 0.102, 0.016, 20, 5)
    for x in (-1, 1):
        rod(p, "metal", at(m, x * 0.114, 0.405, 0),
            at(m, x * 0.114, length - 0.07, 0), 0.015, 10)
        mbox(p, "shell", sub(m, x * 0.105, 0.527, 0.005),
             (0.029, 0.20, 0.095), 0.008, 1)
    mring(p, "shell", sub(m, 0, length - 0.024, 0), 0.136, 0.017, 20, 5)
    mring(p, "metal", sub(m, 0, length + 0.001, 0), 0.116, 0.009, 20, 4)
    # The diaphragm remains visibly recessed behind the muzzle lip.
    mtube(p, "glow", sub(m, 0, length - 0.087, 0), 0.074, 0.007, 18)
    mtube(p, "dark", sub(m, 0, length - 0.08, 0), 0.022, 0.010, 10)
    bolts(p, sub(m, 0, length + 0.006, 0), 0.132, 6, size=0.009)


def batida12_leg(p, out):
    import mech_parts
    mech_parts.LAST_KNEE = -0.235
    knee = Vector((0, -0.235, -0.075))
    heel = Vector((0, -0.485, 0.08))
    ankle = Vector((0, -HIP.y + 0.135, -0.06))
    ox = "x" if out > 0 else "-x"
    # Digitigrade links create an athletic rhythm and open negative space.
    # Every joint is built about its actual axis, preserving knee splitting.
    for center, r in ((Vector((0, 0, 0)), 0.065), (knee, 0.058),
                      (heel, 0.042), (ankle, 0.033)):
        bearing(p, axis_frame(center + Vector((out * 0.02, 0, 0)), ox),
                r, 0.068 if r > 0.05 else 0.052, 3)
    thigh_start = Vector((0, -0.035, 0))
    for a, b, width, role in ((thigh_start, knee, 0.17, "shell"),
                              (knee, heel, 0.12, "trim"),
                              (heel, ankle, 0.08, "shell")):
        rod(p, "dark", a, b, 0.033 if width > 0.1 else 0.024, 10)
        m = frame(a.lerp(b, 0.47), b - a)
        mbox(p, role, sub(m, 0, 0, 0.043),
             (width, (b - a).length * 0.72, 0.055), 0.012, 1,
             taper=(0.85, 0.8))
        mbox(p, "metal", sub(m, out * width * 0.38, 0, -0.025),
             (0.018, (b - a).length * 0.68, 0.032), 0.004, 1)
    piston(p, (out * 0.045, -0.03, 0.065),
           knee + Vector((out * 0.045, 0.03, 0.07)), 0.021)
    piston(p, knee + Vector((out * 0.058, -0.035, 0.06)),
           heel + Vector((out * 0.058, 0.025, 0.055)), 0.024)
    piston(p, heel + Vector((-out * 0.035, 0.05, 0.01)),
           ankle + Vector((-out * 0.035, 0.035, 0.08)), 0.015)
    cable(p, [knee + Vector((-out * 0.04, 0.028, 0.035)),
              knee + Vector((-out * 0.053, -0.03, 0.08)),
              heel + Vector((-out * 0.035, 0.035, 0.055))], 0.009)
    m = T(0, -HIP.y, -0.06)
    # A broad toe pad and raised heel damping unit replace conventional boots.
    mbox(p, "rubber", sub(m, 0, 0.023, -0.028), (0.205, 0.046, 0.31), 0.011, 1)
    mbox(p, "metal", sub(m, 0, 0.051, -0.022), (0.193, 0.014, 0.295), 0.007, 1)
    for side in (-1, 1):
        mbox(p, "trim", sub(m, side * 0.055, 0.076, -0.086, rot=(7, 0, 0)),
             (0.10, 0.045, 0.18), 0.012, 1)
    mbox(p, "shell", sub(m, 0, 0.084, 0.063), (0.14, 0.069, 0.098), 0.015, 1)
    rod(p, "metal", at(m, -0.08, 0.106, 0.058), at(m, 0.08, 0.106, 0.058), 0.011, 8)
    for z in (-0.142, -0.067, 0.008):
        mbox(p, "rubber", sub(m, 0, 0.03, z), (0.216, 0.025, 0.012), 0.002, 1)
    mbox(p, "glow", sub(m, out * 0.105, 0.073, -0.04),
         (0.006, 0.010, 0.055), 0.002, 1)


def define(part):
    for slot in ("head", "torso", "shoulders", "arm", "gun"):
        part("batida12_" + slot)(globals()["batida12_" + slot])
    part("batida12_leg")(lambda p: batida12_leg(p, 1))
    part("batida12_leg_l")(lambda p: batida12_leg(p, -1))
    part("batida12_leg_r")(lambda p: batida12_leg(p, 1))
