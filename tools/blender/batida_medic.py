"""BATIDA 13: the circuit's medic, built as a machine like HÉLIO and BIT.

BIT's friend and the pilot who signs him up for the cup, now the arena's nurse: her name is
the heartbeat. Made the way the cast is made (mech_kit.py, mech_parts.py): dark chassis under
painted plates with a gap between every panel, bearings with bolt rings, forked hinges,
pistons and cables; the knees and ankles fold forward.

The look: white and clinical with red crosses and a mint light, and a silhouette of its own.
The head is a patient monitor on an articulated arm: a rounded casing with handles, the face
on its screen behind a bezel, buttons and a heart-rate light, the nurse's cap on top. The
trunk is a two-tone capsule, red above with a white cross and white below with the heartbeat
line; a stethoscope; a medical pack with two lit vials; flat cross-shaped pads on the
shoulders; slim square sleeves (a bandage roll on the free arm); a short flared skirt of
plates; straight slim legs in nurse's shoes. Her weapon is a syringe: lit vial, graduation
rings, finger flange and the needle at the muzzle.

python3 tools/blender/batida_medic.py
Writes art/robots/batida13.glb, the head's face metrics in roster.json and the knee height
in knees.json. Coordinates: Godot units, Y up, front -Z, right +X.
"""
import json
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import robot_kit as kit  # noqa: E402  (sets up mech_kit)
import mech_kit as mk  # noqa: E402
from mech_cast import T, both_faces, brick_socle, extruded, profile_radius, rev_panel, screen_well  # noqa: E402
from mech_kit import (axis_frame, bolts, cable, frame, hand, lathe,  # noqa: E402
                      mbox, mring, mtube, plane, rod, screw, serial, sub)
from mech_parts import leg, shoulder, upper_arm, waist, wrist  # noqa: E402

OUTPUT = kit.ROOT / "art" / "robots" / "batida13.glb"
PREFIX = "batida13_"
B = {
    "hip": Vector((0.2, 0.7, 0.0)),
    "muzzle": Vector((0.44, 0.86, -1.0)),
    "shoulder_y": 1.34,
    "elbow_l": Vector((-0.48, 1.04, 0.02)),
    "wrist_l": Vector((-0.51, 0.77, -0.1)),
    "elbow_r": Vector((0.48, 1.04, -0.02)),
}
PILL = Vector((0.0, 1.17, 0.02))
PILL_R = 0.2
PILL_HALF = 0.06   # half the straight part between the two domes
PILL_FLAT = 0.86
SKIRT = [(-0.08, 0.205), (-0.03, 0.19), (0.03, 0.17), (0.08, 0.15), (0.1, 0.14)]
HEAD = Vector((0.0, 1.68, -0.02))
HEAD_SIZE = (0.38, 0.3, 0.17)
SCREEN = (0.3, 0.17)


def side_plane(x, y, z):
    """Local XY is the side view (local X forward, -Z world; Y up); thickness along world X."""
    return T(x, y, z) @ Matrix.Rotation(math.radians(90), 4, "Y")


def cross(p, m, size, depth=0.008, role="trim"):
    """A cross on a surface: `m` has local Y out of the surface."""
    mbox(p, role, sub(m, 0, depth / 2, 0), (size, depth, size * 0.32), 0.002, 1)
    mbox(p, role, sub(m, 0, depth / 2, 0), (size * 0.32, depth, size), 0.002, 1)


def pill_radius(y):
    """Radius of the capsule trunk at a height above its centre."""
    d = abs(y) - PILL_HALF
    return PILL_R if d <= 0 else math.sqrt(max(PILL_R * PILL_R - d * d, 0.0))


def on_pill(lon, y, lift=0.002):
    """A frame on the capsule's surface (local Y out, local Z up)."""
    a = math.radians(lon)
    r = pill_radius(y) + lift
    q = Vector((PILL.x + r * math.cos(a), PILL.y + y, PILL.z + r * math.sin(a) * PILL_FLAT))
    d = abs(y) - PILL_HALF
    ny = 0.0 if d <= 0 else math.copysign(d, y) / PILL_R
    n = Vector((math.cos(a), ny, math.sin(a) / PILL_FLAT)).normalized()
    return frame(q, n, front=(0, 1, 0))


# --- Head: a patient monitor on an articulated arm ----------------------------------------
def batida13_head(p):
    c = HEAD
    w, h, d = HEAD_SIZE
    front = c.z - d / 2
    mk.HEADS[PREFIX + "head"] = {"top": round(c.y + h / 2 + 0.11, 3), "center": round(c.y + 0.01, 3),
                                 "aspect": round(SCREEN[0] / SCREEN[1], 3)}
    base = T(*c)
    # Casing: a rounded bezel in front, a tapered dark back with vents, handles at the sides.
    mbox(p, "shell", sub(base, 0, 0, 0.025), (w, h, d - 0.07), 0.05, 2)
    # Bezel: four bars round the screen, standing proud of the casing.
    sw, sh = SCREEN[0] + 0.04, SCREEN[1] + 0.04
    bz = front + 0.03
    side_w = (w - sw) / 2
    for side in (-1, 1):
        mbox(p, "shell", T(c.x + side * (sw / 2 + side_w / 2), c.y, bz), (side_w, h, 0.07), 0.03, 2)
    top_h = h / 2 - (0.02 + sh / 2)
    bottom_h = h / 2 - (sh / 2 - 0.02)
    mbox(p, "shell", T(c.x, c.y + h / 2 - top_h / 2, bz), (sw + 0.01, top_h, 0.07), 0.02, 2)
    mbox(p, "shell", T(c.x, c.y - h / 2 + bottom_h / 2, bz), (sw + 0.01, bottom_h, 0.07), 0.02, 2)
    mbox(p, "dark", sub(base, 0, 0, d / 2 - 0.01), (w - 0.08, h - 0.06, 0.06), 0.03, 2, taper=(0.85, 0.85))
    for i in range(4):
        mbox(p, "dark", T(c.x, c.y - 0.06 + i * 0.03, c.z + d / 2 + 0.022), (0.18, 0.01, 0.01), 0.003, 1)
    for side in (-1, 1):
        a = Vector((side * (w / 2 + 0.005), c.y + 0.07, c.z))
        b = Vector((side * (w / 2 + 0.005), c.y - 0.07, c.z))
        rod(p, "metal", a + Vector((side * 0.03, 0, 0)), b + Vector((side * 0.03, 0, 0)), 0.012, 8)
        for q in (a, b):
            rod(p, "metal", q, q + Vector((side * 0.035, 0, 0)), 0.01, 8)
    # The screen in its well, a red stripe under it with buttons and a heart-rate light.
    screen_well(p, (c.x, c.y + 0.02, front - 0.003), SCREEN, 0.04, 0.025)
    mbox(p, "trim", T(c.x, c.y - h / 2 + 0.035, front - 0.006), (w - 0.06, 0.03, 0.012), 0.004, 1)
    for i in range(3):
        mtube(p, "metal", sub(T(c.x - 0.1 + i * 0.035, c.y - h / 2 + 0.035, front - 0.014), rot=(90, 0, 0)), 0.008, 0.008, 8)
    mbox(p, "glow", T(c.x + 0.12, c.y - h / 2 + 0.035, front - 0.014), (0.05, 0.012, 0.006), 0.002, 1)
    # Nurse's cap on top of the monitor.
    cap = sub(T(0, c.y + h / 2 - 0.005, c.z + 0.0), rot=(-10, 0, 0))
    extruded(p, "shell", cap, [(-0.12, 0.0), (0.12, 0.0), (0.09, 0.09), (-0.09, 0.09)], 0.08)
    mbox(p, "trim", sub(cap, 0, 0.012, 0), (0.245, 0.018, 0.084), 0.004, 1)
    cross(p, sub(cap, 0, 0.055, -0.041, rot=(-90, 0, 0)), 0.05)
    serial(p, plane((0.1, c.y + 0.07, c.z + d / 2 + 0.023), (0, 0, 1), (1, 0, 0)), "08", 0.03)


# --- Trunk: a two-tone capsule ------------------------------------------------------------
def heartbeat(p, y):
    """The heartbeat line across the belly: flat, a small rise, the spike, the dip, flat."""
    pts = [(-0.1, 0.0), (-0.045, 0.0), (-0.03, 0.015), (-0.015, 0.0), (0.0, 0.0), (0.012, 0.05),
           (0.028, -0.035), (0.04, 0.0), (0.1, 0.0)]
    r = pill_radius(y)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        z = PILL.z - math.sqrt(max(r * r - mx * mx, 0.0)) * PILL_FLAT - 0.004
        length = math.hypot(x1 - x0, y1 - y0)
        angle = math.degrees(math.atan2(y1 - y0, x1 - x0))
        mbox(p, "glow", sub(T(mx, PILL.y + y + my, z), rot=(0, 0, angle)), (length + 0.008, 0.01, 0.01), 0.002, 1)


def capsule_profile(y0, y1, inset=0.0, steps=8):
    """(radius, height) pairs of the capsule between two heights, poles closed."""
    pts = []
    total = PILL_HALF + PILL_R
    for i in range(steps + 1):
        y = y0 + (y1 - y0) * i / steps
        r = max(pill_radius(y) - inset, 0.0)
        if abs(abs(y) - total) < 1e-6:
            r = 0.0
        pts.append((r, y))
    return pts


def batida13_torso(p):
    c = PILL
    m = T(*c) @ Matrix.Diagonal((1.0, 1.0, PILL_FLAT, 1.0))
    total = PILL_HALF + PILL_R
    # Neck: the monitor's arm, two links on hinges from the top of the capsule.
    root = Vector((0, c.y + total - 0.03, 0.05))
    knee = Vector((0, root.y + 0.13, 0.13))
    mount = Vector((0, HEAD.y - 0.02, HEAD.z + HEAD_SIZE[2] / 2 + 0.02))
    mtube(p, "metal", T(*root), 0.06, 0.04, 16)
    bolts(p, T(*(root + Vector((0, 0.02, 0)))), 0.045, 5, size=0.008)
    rod(p, "dark", root, knee, 0.026, 10)
    mk.hinge(p, axis_frame(knee, "y"), 0.05, 0.03, fork_len=0.05, fork_thick=0.016, bolt_count=3)
    rod(p, "dark", knee, mount, 0.022, 10)
    mbox(p, "metal", T(*mount), (0.1, 0.1, 0.02), 0.01, 1)
    cable(p, [root + Vector((0.04, 0.0, 0.03)), knee + Vector((0.04, 0.0, 0.03)), mount + Vector((0.04, -0.04, 0.0))], 0.008)
    # The capsule: red cap on top, white below, a metal seam between them.
    lathe(p, "dark", m, capsule_profile(-total, total, 0.03, 16), 26)
    lathe(p, "trim", m, capsule_profile(0.005, total, 0.0, 10), 28)
    lathe(p, "shell", m, capsule_profile(-total, -0.005, 0.0, 10), 28)
    mring(p, "metal", m, PILL_R + 0.002, 0.014, 28, 5)
    cross(p, on_pill(-90, 0.12, 0.002), 0.11, role="shell")
    heartbeat(p, -0.11)
    # Stethoscope round the arm's root, the chest piece hanging on the left.
    ny = c.y + total - 0.04
    cable(p, [(0.1, ny - 0.14, -0.15), (0.11, ny + 0.01, -0.06), (0.06, ny + 0.05, 0.06), (-0.06, ny + 0.05, 0.06),
              (-0.11, ny + 0.01, -0.06), (-0.1, ny - 0.16, -0.16)], 0.01)
    bell = on_pill(-114, 0.0, 0.012)
    mtube(p, "metal", bell, 0.03, 0.016, 16, bevel=0.003)
    mtube(p, "dark", sub(bell, 0, 0.009, 0), 0.022, 0.004, 14)
    # Medical pack on the back with a cross and two lit vials on top.
    pack = T(0, c.y + 0.02, 0.24)
    mbox(p, "shell", pack, (0.28, 0.28, 0.1), 0.03)
    mbox(p, "trim", sub(pack, 0, 0.12, 0.0), (0.29, 0.03, 0.11), 0.01, 1)
    cross(p, sub(pack, 0, 0, 0.05, rot=(90, 0, 0)), 0.1)
    for u in (-1, 1):
        for v in (-1, 1):
            screw(p, sub(pack, u * 0.11, v * 0.11, 0.051, rot=(90, 0, 0)), 0, 0, 0.007)
        vial = T(u * 0.08, c.y + 0.24, 0.26)
        mtube(p, "metal", sub(vial, 0, -0.075, 0), 0.034, 0.02, 14)
        mtube(p, "glow", vial, 0.026, 0.13, 14)
        for k in (-1, 1):
            mring(p, "metal", sub(vial, 0, k * 0.04, 0), 0.027, 0.004, 14, 4)
        mtube(p, "metal", sub(vial, 0, 0.075, 0), 0.03, 0.02, 14)
    cable(p, [(-0.08, c.y + 0.32, 0.26), (-0.18, c.y + 0.3, 0.2), (-0.3, c.y + 0.1, 0.12), (-0.46, B["elbow_l"].y + 0.05, 0.07)], 0.008)
    waist(p, 0.84, c.y - total + 0.03, 0.09)
    hips(p)
    for side in (-1, 1):
        cable(p, [(side * 0.16, c.y + 0.16, 0.14), (side * 0.26, c.y + 0.19, 0.15), (side * 0.34, c.y + 0.04, 0.09)], 0.01)


def hips(p):
    """Pelvis under a short flared skirt of plates, open at the sides for the hip bearings."""
    hip = B["hip"]
    centre = Vector((0, 0.77, 0.0))
    m = T(*centre) @ Matrix.Diagonal((1.0, 1.0, 0.85, 1.0))
    lathe(p, "dark", m, [(0.0, SKIRT[0][0])] + [(r - 0.04, y) for y, r in SKIRT] + [(0.0, SKIRT[-1][0])], 22)
    for lon in ((-150, -95), (-85, -30), (30, 85), (95, 150)):
        rev_panel(p, "shell", m, SKIRT, (-0.08, 0.08), lon, 0.026, (8, 5), gap=0.012)
    mring(p, "trim", sub(m, 0, -0.07, 0), profile_radius(SKIRT, -0.07) + 0.003, 0.012, 24, 4)
    mring(p, "metal", sub(m, 0, 0.085, 0), profile_radius(SKIRT, 0.085) + 0.003, 0.01, 24, 4)
    for side in (-1, 1):
        x0 = 0.15
        house = axis_frame((side * x0, hip.y, 0.0), "x" if side > 0 else "-x")
        mtube(p, "dark", house, 0.08, 0.04, 20, bevel=0.006)
        bolts(p, sub(house, 0, 0.022, 0), 0.065, 6, size=0.009)
        mtube(p, "metal", sub(house, 0, 0.02 + (hip.x - x0) / 2 + 0.03, 0), 0.036, hip.x - x0 + 0.07, 12)


# --- Shoulders and arms -------------------------------------------------------------------
PLUS = [(-0.04, -0.12), (0.04, -0.12), (0.04, -0.04), (0.12, -0.04), (0.12, 0.04), (0.04, 0.04),
        (0.04, 0.12), (-0.04, 0.12), (-0.04, 0.04), (-0.12, 0.04), (-0.12, -0.04), (-0.04, -0.04)]


def batida13_shoulders(p):
    y = B["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.2, y, 0.01, 0.09, 0.07, 0.07)
        # A flat cross for a pad, tipped outward, on a dark bracket over the drum.
        mbox(p, "dark", T(drum.x, y + 0.085, 0.01), (0.05, 0.05, 0.07), 0.01, 1)
        pad = T(drum.x + side * 0.02, y + 0.12, 0.01) @ Matrix.Rotation(math.radians(-side * 16), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X")
        extruded(p, "shell", pad, [(u * 1.05, v * 1.05) for u, v in PLUS], 0.04)
        extruded(p, "trim", pad @ Matrix.Translation((0, 0, -0.024)), [(u * 0.7, v * 0.7) for u, v in PLUS], 0.01)
        elbow = B["elbow_l"] if side < 0 else B["elbow_r"]
        upper_arm(p, side, pin, elbow, bone_r=0.03, elbow_w=0.065, elbow_r=0.04, armor_size=(0.09, 0.1))


def batida13_arm(p):
    # Free arm: a slim square sleeve with a bandage roll, a red stripe and a four-finger hand.
    e, wr = B["elbow_l"], B["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    sleeve = sub(m, 0, length * 0.55, 0.0)
    mbox(p, "dark", sleeve, (0.12, length * 0.7, 0.13), 0.02)
    mbox(p, "shell", sub(sleeve, 0, 0.0, 0.02), (0.15, length * 0.62, 0.12), 0.03, 2, taper=(1.1, 1.1))
    mbox(p, "trim", sub(sleeve, 0, length * 0.24, 0.02), (0.16, 0.03, 0.13), 0.01, 1)
    roll = sub(sleeve, -0.09, -0.02, 0.02, rot=(0, 0, 0))
    mtube(p, "shell", roll, 0.04, 0.1, 16, bevel=0.005)
    mtube(p, "metal", roll, 0.012, 0.12, 8)
    mbox(p, "glow", sub(sleeve, 0.0, -length * 0.1, 0.082), (0.05, 0.05, 0.006), 0.003, 1)
    wrist(p, m, length)
    hand(p, sub(m, 0, length + 0.14, 0.0, rot=(0, -90, 180)), fingers=4, scale=1.2, curl=0.8)
    # Syringe arm: a square white sleeve with a cross; the barrel slides in it.
    e, muzzle = B["elbow_r"], B["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    housing = sub(m, 0, 0.25, 0)
    mbox(p, "dark", housing, (0.17, 0.34, 0.17), 0.03)
    mbox(p, "shell", sub(housing, 0, -0.01, 0.02), (0.19, 0.3, 0.16), 0.04, 2)
    for v in (-0.12, 0.12):
        mbox(p, "trim", sub(housing, 0, v, 0.02), (0.2, 0.025, 0.17), 0.008, 1)
    cross(p, sub(housing, 0, 0.0, 0.1, rot=(90, 0, 0)), 0.07)
    ring = sub(m, 0, 0.45, 0)
    mtube(p, "metal", ring, 0.085, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.07, 6, size=0.008)


def batida13_gun(p):
    """The syringe: lit vial in a frame of rails, graduation rings, the finger flange, the
    hub and the needle at the muzzle. It recoils into the arm."""
    e, muzzle = B["elbow_r"], B["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    flange = sub(m, 0, 0.48, 0)
    mbox(p, "trim", flange, (0.2, 0.025, 0.07), 0.01)
    mtube(p, "metal", sub(m, 0, 0.51, 0), 0.07, 0.03, 18)
    mtube(p, "glow", sub(m, 0, 0.67, 0), 0.052, 0.3, 18)
    for i in range(6):
        mring(p, "dark", sub(m, 0, 0.55 + i * 0.045, 0), 0.054, 0.004, 18, 4)
    for k in range(3):
        a = math.radians(90 + k * 120)
        rod(p, "metal", at3(m, math.cos(a) * 0.062, 0.51, math.sin(a) * 0.062), at3(m, math.cos(a) * 0.062, 0.83, math.sin(a) * 0.062), 0.008, 6)
    mtube(p, "metal", sub(m, 0, 0.835, 0), 0.068, 0.024, 18)
    lathe(p, "trim", sub(m, 0, 0.845, 0), [(0.05, 0.0), (0.03, 0.05), (0.014, 0.07), (0.0, 0.075)], 14)
    rod(p, "metal", at3(m, 0, 0.9, 0), at3(m, 0, length, 0), 0.007, 6)


def at3(m, u, v, w):
    return (m @ Vector((u, v, w, 1.0))).to_3d()


# --- Legs ---------------------------------------------------------------------------------
def clog(p, m, out):
    """Nurse's shoe: a thick rubber sole with a raised heel, a soft white upper and a red strap."""
    g = m.translation.y
    mbox(p, "rubber", T(0, g + 0.02, -0.04), (0.22, 0.04, 0.4), 0.016, 2)
    mbox(p, "rubber", T(0, g + 0.05, 0.1), (0.2, 0.03, 0.12), 0.012, 1)
    mbox(p, "shell", T(0, g + 0.08, -0.07), (0.2, 0.08, 0.3), 0.04, 3, taper=(0.86, 0.8))
    mbox(p, "shell", T(0, g + 0.1, 0.08), (0.19, 0.08, 0.13), 0.035, 2)
    mbox(p, "trim", T(0, g + 0.115, -0.02), (0.205, 0.024, 0.05), 0.008, 1)
    for side in (-1, 1):
        mtube(p, "metal", axis_frame((side * 0.103, g + 0.115, -0.02), "x"), 0.012, 0.008, 8)


def batida13_leg(p, out):
    def clogs(q, m, o, ankle):
        clog(q, m, o)
    leg(p, out, B["hip"].y, knee_y=-0.27, ankle_up=0.17, width=0.85, knee_w=0.1, knee_r=0.052, foot_fn=clogs,
        thigh="shell", thigh_side="trim", shin="shell", guard_role="trim", calf="shell", thigh_top=-0.02)


# --- Hard skin (BATIDA NEON): the night shift ----------------------------------------------
def batida13_x_hat(p):
    """A tall night-shift cap over the nurse's cap, its cross lit, two antennae with lights."""
    c = HEAD
    ey = HEAD_SIZE[1] / 2 + 0.03
    cap = sub(T(0, c.y + ey + 0.04, c.z + 0.01), rot=(-10, 0, 0))
    extruded(p, "shell", cap, [(-0.1, 0.0), (0.1, 0.0), (0.075, 0.1), (-0.075, 0.1)], 0.07)
    cross(p, sub(cap, 0, 0.05, -0.036, rot=(-90, 0, 0)), 0.05, role="glow")
    for side in (-1, 1):
        base = Vector((side * 0.07, c.y + ey + 0.1, c.z + 0.04))
        rod(p, "metal", base, base + Vector((side * 0.05, 0.14, 0.03)), 0.006, 6)
        mtube(p, "glow", T(*(base + Vector((side * 0.05, 0.15, 0.03)))), 0.016, 0.03, 10)


def batida13_x_extra(p):
    """An IV pole on the back with a lit drip bag, its line running to the free arm, and the
    defibrillator paddles holstered at the hips."""
    c = PILL
    foot = Vector((-0.1, c.y + 0.16, 0.3))
    top = Vector((-0.1, HEAD.y + 0.36, 0.3))
    mtube(p, "metal", T(*(foot + Vector((0, -0.02, 0)))), 0.03, 0.04, 12)
    rod(p, "metal", foot, top, 0.012, 8)
    rod(p, "metal", top, top + Vector((-0.14, 0.0, 0.0)), 0.009, 6)
    bag = T(*(top + Vector((-0.14, -0.12, 0.0))))
    mbox(p, "glow", bag, (0.1, 0.16, 0.04), 0.03, 2)
    mbox(p, "shell", sub(bag, 0, 0.09, 0), (0.06, 0.03, 0.03), 0.008, 1)
    cross(p, sub(bag, 0, 0.0, -0.022, rot=(-90, 0, 0)), 0.045)
    cable(p, [top + Vector((-0.14, -0.21, 0.0)), top + Vector((-0.3, -0.4, -0.05)), B["elbow_l"] + Vector((-0.04, 0.08, 0.07))], 0.007)
    for side in (-1, 1):
        holster = T(side * 0.24, 0.84, -0.02)
        mbox(p, "dark", holster, (0.05, 0.14, 0.12), 0.012, 1)
        paddle = sub(holster, side * 0.035, 0.0, 0.0, rot=(0, 0, -side * 6))
        mbox(p, "trim", paddle, (0.03, 0.12, 0.11), 0.01, 1)
        mbox(p, "glow", sub(paddle, side * 0.017, 0.0, 0.0), (0.004, 0.08, 0.07), 0.002, 1)
        mbox(p, "metal", sub(holster, 0, 0.1, 0), (0.03, 0.06, 0.04), 0.008, 1)


# --- Wall brick: a first-aid case ----------------------------------------------------------
def batida13_brick(p):
    """BATIDA's brick: a white first-aid case with a red cross on both faces, metal latches, a
    heartbeat light on the side and a handle on the lid in the team's colour."""
    brick_socle(p)
    mbox(p, "shell", T(0.0, 0.25, 0.0), (0.5, 0.3, 0.26), 0.04, 1)
    mbox(p, "trim", T(0.0, 0.4, 0.0), (0.51, 0.025, 0.27), 0.01, 1)

    def face(z):
        cross(p, sub(T(0.0, 0.26, z * 0.13), rot=(90 * z, 0, 0)), 0.15, 0.01)
        for x in (-0.19, 0.19):
            mbox(p, "metal", T(x, 0.37, z * 0.133), (0.04, 0.05, 0.012), 0.004, 1)
    both_faces(face)
    for x in (-1, 1):
        mbox(p, "glow", T(x * 0.252, 0.27, 0.0), (0.006, 0.012, 0.16), 0.002, 1)
        mbox(p, "glow", T(x * 0.252, 0.29, 0.02), (0.006, 0.05, 0.012), 0.002, 1)
    mbox(p, "team", T(0.0, 0.425, 0.0), (0.4, 0.03, 0.2), 0.01, 1)
    for x in (-0.09, 0.09):
        mtube(p, "metal", T(x, 0.46, 0.0), 0.012, 0.05, 8)
    mbox(p, "dark", T(0.0, 0.49, 0.0), (0.22, 0.026, 0.035), 0.01, 1)


DETAIL = 1.0  # mech_kit.lod reads the running script's DETAIL: the brick's "lo_" copy is half.


def define():
    kit.PARTS.clear()
    for slot in ("head", "torso", "shoulders", "arm", "gun"):
        kit.part(PREFIX + slot)(globals()[PREFIX + slot])
    kit.part(PREFIX + "leg_l")(lambda q: batida13_leg(q, -1))
    kit.part(PREFIX + "leg_r")(lambda q: batida13_leg(q, 1))

    def brick(q):
        global DETAIL
        DETAIL = kit.DETAIL
        batida13_brick(q)
        DETAIL = 1.0
    kit.part(PREFIX + "brick")(brick)
    kit.part(PREFIX + "x_hat")(batida13_x_hat)
    kit.part(PREFIX + "x_extra")(batida13_x_extra)
    kit.LOW_DETAIL[:] = [PREFIX + "brick"]


def write_metrics():
    text = kit.ROSTER.read_text(encoding="utf-8")
    for name, values in kit.HEADS.items():
        if not name.startswith(PREFIX):
            continue
        entry = '"' + name + '": ' + json.dumps(values)
        pattern = r'"' + re.escape(name) + r'"\s*:\s*\{[^}]+\}'
        if re.search(pattern, text):
            text = re.sub(pattern, entry, text, count=1)
        else:
            start = text.index('"heads": {') + len('"heads": {')
            text = text[:start] + "\n\t\t" + entry + "," + text[start:]
    kit.ROSTER.write_text(text, encoding="utf-8", newline="\n")
    knees_path = OUTPUT.parent / "knees.json"
    knees = json.loads(knees_path.read_text(encoding="utf-8"))
    knees.update({k: v for k, v in kit.KNEES.items() if k.startswith(PREFIX)})
    knees_path.write_text(json.dumps(knees, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def build():
    define()
    objects = kit.build_kit()
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_yup=True, export_texcoords=True,
                              export_materials="EXPORT", export_extras=False, export_apply=True,
                              export_vertex_color="NONE")
    tris = 0
    for root in objects.values():
        for child in root.children:
            child.data.calc_loop_triangles()
            tris += len(child.data.loop_triangles)
    write_metrics()
    print("BATIDA13", sorted(objects), "tris", tris, "bytes", OUTPUT.stat().st_size)


if __name__ == "__main__":
    build()
