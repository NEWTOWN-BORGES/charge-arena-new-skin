"""BATIDA 13: the circuit's medic, built as a machine like HÉLIO and BIT.

BIT's friend and the pilot who signs him up for the cup, now the arena's nurse: her name is
the heartbeat. Made the way the cast is made (mech_kit.py, mech_parts.py): dark chassis under
painted plates with a gap between every panel, bearings with bolt rings, forked hinges,
pistons and cables; the knees and ankles fold forward.

The look: white and clinical with red crosses and a mint light. A rounded helmet with a
nurse's cap and a head mirror, a wide visor; a slim trunk turned on a lathe with a red cross
on the chest and a heartbeat line across the belly; a stethoscope round the neck; a medical
pack on the back with two lit vials; small domed pauldrons with crosses; a short flared
skirt of plates over the hips; slim round legs in rounded clogs. Her weapon is a syringe:
lit vial, graduation rings, finger flange and the needle at the muzzle.

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
from mech_cast import T, both_faces, brick_socle, extruded, profile_radius, rev_panel, rev_point, scaled, screen_well  # noqa: E402
from mech_kit import (axis_frame, bolts, cable, capsule, cyl_panel, frame, hand, lathe,  # noqa: E402
                      mbox, mring, mtube, plane, rod, screw, serial, sphere_panel, sub)
from mech_parts import leg, neck, round_shin, round_thigh, shoulder, upper_arm, waist, wrist  # noqa: E402

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
CHEST = Vector((0.0, 1.18, 0.02))
FLAT = 0.82
TRUNK = [(-0.22, 0.13), (-0.16, 0.135), (-0.08, 0.17), (0.0, 0.2), (0.08, 0.215), (0.14, 0.205), (0.19, 0.17), (0.22, 0.12)]
SKIRT = [(-0.08, 0.205), (-0.03, 0.19), (0.03, 0.17), (0.08, 0.15), (0.1, 0.14)]
HEAD = Vector((0.0, 1.67, 0.0))
HEAD_RADII = (0.165, 0.16, 0.15)
SCREEN = (0.22, 0.1)


def side_plane(x, y, z):
    """Local XY is the side view (local X forward, -Z world; Y up); thickness along world X."""
    return T(x, y, z) @ Matrix.Rotation(math.radians(90), 4, "Y")


def cross(p, m, size, depth=0.008, role="trim"):
    """A red cross on a surface: `m` has local Y out of the surface."""
    mbox(p, role, sub(m, 0, depth / 2, 0), (size, depth, size * 0.32), 0.002, 1)
    mbox(p, role, sub(m, 0, depth / 2, 0), (size * 0.32, depth, size), 0.002, 1)


def on_trunk(lon, y, lift=0.002):
    """A frame on the trunk's surface (local Y out, local Z up)."""
    q, n = rev_point(CHEST, TRUNK, FLAT, lon, y, lift)
    return frame(q, n, front=(0, 1, 0))


# --- Head ---------------------------------------------------------------------------------
def batida13_head(p):
    c = HEAD
    ex, ey, ez = HEAD_RADII
    mk.HEADS[PREFIX + "head"] = {"top": round(c.y + ey + 0.1, 3), "center": round(c.y, 3),
                                 "aspect": round(SCREEN[0] / SCREEN[1], 3)}
    hs = scaled(c, ex, ey, ez)
    lathe(p, "dark", scaled(c, ex - 0.03, ey - 0.03, ez - 0.03),
          [(0.0, -1.0)] + [(math.sin(math.radians(a)), -math.cos(math.radians(a))) for a in range(15, 180, 15)] + [(0.0, 1.0)], 22)
    sphere_panel(p, "shell", hs, 1.0, (32, 88), (-180, 180), 0.2, (24, 6))
    sphere_panel(p, "shell", hs, 1.0, (-58, 28), (-28, 208), 0.2, (16, 6), gap=0.05)
    sphere_panel(p, "shell", hs, 1.0, (-74, -30), (-145, -35), 0.2, (10, 4), gap=0.05)
    sphere_panel(p, "trim", hs, 1.02, (28, 36), (-150, -30), 0.18, (12, 2), gap=0.02)
    screen_well(p, (c.x, c.y + 0.0, c.z - ez - 0.012), SCREEN, 0.05, 0.03)
    # Nurse's cap: a folded white band on the crown with a red cross in front.
    cap = sub(T(0, c.y + ey - 0.02, c.z - 0.02), rot=(-18, 0, 0))
    extruded(p, "shell", cap, [(-0.12, 0.0), (0.12, 0.0), (0.09, 0.09), (-0.09, 0.09)], 0.08)
    mbox(p, "trim", sub(cap, 0, 0.012, 0), (0.245, 0.018, 0.084), 0.004, 1)
    cross(p, sub(cap, 0, 0.055, -0.041, rot=(-90, 0, 0)), 0.05)
    # Head mirror on a band over the left brow, and earpieces either side.
    mirror = sub(T(-0.075, c.y + 0.1, c.z - ez + 0.01), rot=(-80, 0, 0))
    mtube(p, "metal", mirror, 0.042, 0.012, 20, bevel=0.003)
    mtube(p, "glow", sub(mirror, 0, -0.007, 0), 0.03, 0.004, 18)
    mtube(p, "dark", sub(mirror, 0, -0.009, 0), 0.008, 0.004, 8)
    for side in (-1, 1):
        mtube(p, "metal", axis_frame((side * (ex - 0.005), c.y, c.z), "x" if side > 0 else "-x"), 0.035, 0.03, 14)
        mtube(p, "glow", axis_frame((side * (ex + 0.012), c.y, c.z), "x" if side > 0 else "-x"), 0.018, 0.006, 12)
    serial(p, plane((0.0, c.y - 0.03, c.z + ez + 0.004), (0, 0, 1), (1, 0, 0)), "08", 0.03)


# --- Trunk --------------------------------------------------------------------------------
def heartbeat(p, y):
    """The heartbeat line across the belly: flat, a small rise, the spike, the dip, flat."""
    pts = [(-0.1, 0.0), (-0.045, 0.0), (-0.03, 0.015), (-0.015, 0.0), (0.0, 0.0), (0.012, 0.05),
           (0.028, -0.035), (0.04, 0.0), (0.1, 0.0)]
    r = profile_radius(TRUNK, y)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        z = CHEST.z - math.sqrt(max(r * r - mx * mx, 0.0)) * FLAT - 0.004
        length = math.hypot(x1 - x0, y1 - y0)
        angle = math.degrees(math.atan2(y1 - y0, x1 - x0))
        mbox(p, "glow", sub(T(mx, CHEST.y + y + my, z), rot=(0, 0, angle)), (length + 0.008, 0.01, 0.01), 0.002, 1)


def batida13_torso(p):
    c = CHEST
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, FLAT, 1.0))
    bottom, top = TRUNK[0][0], TRUNK[-1][0]
    neck(p, c.y + top - 0.005, HEAD.y - HEAD_RADII[1] + 0.02, 0.064, 0.0, plate=(0.2, 0.18))
    lathe(p, "dark", flat, [(0.0, bottom)] + [(r - 0.035, y) for y, r in TRUNK] + [(0.0, top)], 26)
    rev_panel(p, "shell", flat, TRUNK, (-0.02, 0.2), (-150, -30), 0.034, (12, 8), gap=0.012)
    rev_panel(p, "shell", flat, TRUNK, (-0.21, -0.03), (-140, -40), 0.03, (10, 6), gap=0.012)
    for lon in ((-26, 26), (154, 206)):
        rev_panel(p, "trim", flat, TRUNK, (-0.2, 0.18), lon, 0.03, (6, 6), gap=0.012)
    rev_panel(p, "shell", flat, TRUNK, (-0.21, 0.21), (30, 150), 0.034, (10, 8), gap=0.012)
    mring(p, "trim", sub(flat, 0, bottom + 0.025, 0), profile_radius(TRUNK, bottom + 0.025) + 0.004, 0.014, 26, 5)
    mring(p, "metal", sub(flat, 0, top - 0.03, 0), profile_radius(TRUNK, top - 0.03) + 0.004, 0.012, 26, 5)
    # Red cross on the chest and the heartbeat on the belly.
    cross(p, on_trunk(-90, 0.1), 0.1)
    heartbeat(p, -0.12)
    # Stethoscope: tubing round the neck, earpieces tucked behind, the chest piece hanging left.
    ny = c.y + top
    cable(p, [(0.12, ny - 0.1, -0.15), (0.13, ny + 0.02, -0.05), (0.08, ny + 0.06, 0.08), (-0.08, ny + 0.06, 0.08),
              (-0.13, ny + 0.02, -0.05), (-0.11, ny - 0.12, -0.17)], 0.01)
    bell = on_trunk(-112, 0.02, 0.012)
    mtube(p, "metal", bell, 0.03, 0.016, 16, bevel=0.003)
    mtube(p, "dark", sub(bell, 0, 0.009, 0), 0.022, 0.004, 14)
    mtube(p, "metal", on_trunk(-68, 0.09, 0.008), 0.012, 0.012, 8)
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
    waist(p, 0.84, c.y + bottom + 0.02, 0.1)
    hips(p)
    for side in (-1, 1):
        cable(p, [(side * 0.18, c.y + 0.17, 0.14), (side * 0.28, c.y + 0.19, 0.15), (side * 0.34, c.y + 0.04, 0.09)], 0.01)


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
def batida13_shoulders(p):
    y = B["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.24, y, 0.01, 0.095, 0.075, 0.07)
        mbox(p, "dark", T(drum.x, y + 0.09, 0.01), (0.05, 0.05, 0.07), 0.01, 1)
        m = T(drum.x + side * 0.012, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        sphere_panel(p, "shell", m, 0.14, (22, 88), (a0 - 25, a1 + 25), 0.026, (12, 5), gap=0.008)
        sphere_panel(p, "trim", m, 0.145, (8, 20), (a0 - 20, a1 + 20), 0.024, (12, 2), gap=0.006)
        top = T(drum.x + side * 0.012, y + 0.162, 0.01)
        cross(p, top, 0.07)
        elbow = B["elbow_l"] if side < 0 else B["elbow_r"]
        upper_arm(p, side, pin, elbow, bone_r=0.034, elbow_w=0.07, elbow_r=0.044, armor_size=(0.1, 0.1))
        arm = frame(pin.lerp(elbow, 0.5), elbow - pin)
        capsule(p, "shell", sub(arm, side * 0.01, 0.0, -0.03), 0.065, (elbow - pin).length * 0.7, 16)
        mring(p, "trim", sub(arm, side * 0.01, (elbow - pin).length * 0.28, -0.03), 0.062, 0.009, 16, 4)


def batida13_arm(p):
    # Free arm: a slim gauntlet with a red cuff, a scanner light and a four-finger hand.
    e, wr = B["elbow_l"], B["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.07, 0.07, 0.08), 0.012, 1)
    capsule(p, "dark", sub(m, 0, length * 0.55, 0), 0.075, length * 0.8, 18)
    for lo in ((-75, 75), (105, 255)):
        cyl_panel(p, "shell", sub(m, 0, length * 0.45, 0), 0.098, length * 0.55, lo, 0.03, (10, 2), gap=0.012, radius_top=0.09)
    cuff = sub(m, 0, length * 0.74, 0)
    lathe(p, "trim", cuff, [(0.082, 0.0), (0.1, 0.0), (0.118, 0.06), (0.112, 0.072), (0.07, 0.072), (0.082, 0.0)], 22)
    scan = sub(m, 0, length * 0.42, 0.1)
    mbox(p, "dark", scan, (0.07, 0.09, 0.012), 0.004, 1)
    mbox(p, "glow", sub(scan, 0, 0, 0.006), (0.055, 0.07, 0.004), 0.002, 1)
    wrist(p, m, length)
    hand(p, sub(m, 0, length + 0.14, 0.0, rot=(0, -90, 180)), fingers=4, scale=1.25, curl=0.8)
    # Syringe arm: a white housing with red rings; the barrel slides in it.
    e, muzzle = B["elbow_r"], B["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.07, 0.08, 0.08), 0.012, 1)
    lathe(p, "shell", m, [(0.0, 0.07), (0.07, 0.08), (0.1, 0.14), (0.106, 0.3), (0.096, 0.4), (0.0, 0.42)], 24)
    for v in (0.15, 0.35):
        mring(p, "trim", sub(m, 0, v, 0), 0.105, 0.012, 24, 5)
    cross(p, sub(m, 0, 0.25, 0.104, rot=(90, 0, 0)), 0.06)
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
    """Rounded clog: rubber sole, metal plate, a domed toe and heel, a red strap."""
    g = m.translation.y
    mbox(p, "rubber", T(0, g + 0.016, -0.04), (0.24, 0.032, 0.42), 0.014, 2)
    mbox(p, "metal", T(0, g + 0.04, -0.036), (0.22, 0.02, 0.38), 0.01, 1)
    toe = T(0, g + 0.05, -0.1) @ Matrix.Diagonal((0.12, 0.09, 0.18, 1.0))
    lathe(p, "dark", toe @ Matrix.Diagonal((0.92, 0.92, 0.92, 1.0)), [(1.0, 0.0), (0.92, 0.4), (0.7, 0.72), (0.35, 0.94), (0.0, 1.0)], 18, cap_bottom=True)
    sphere_panel(p, "shell", toe, 1.0, (4, 88), (-170, -10), 0.18, (12, 5))
    sphere_panel(p, "trim", toe, 1.03, (40, 56), (-150, -30), 0.15, (12, 2), gap=0.01)
    heel = T(0, g + 0.05, 0.09) @ Matrix.Diagonal((0.11, 0.09, 0.08, 1.0))
    sphere_panel(p, "shell", heel, 1.0, (4, 88), (10, 170), 0.2, (10, 5))


def batida13_leg(p, out):
    def clogs(q, m, o, ankle):
        clog(q, m, o)
        lathe(q, "trim", T(0, ankle.y - 0.02, 0.0), [(0.08, 0.0), (0.1, 0.0), (0.115, 0.05), (0.11, 0.06), (0.075, 0.06), (0.08, 0.0)], 20)
    leg(p, out, B["hip"].y, knee_y=-0.27, ankle_up=0.17, width=0.92, knee_w=0.108, knee_r=0.058, foot_fn=clogs,
        thigh_fn=round_thigh(k=0.92), shin_fn=round_shin(k=0.92, r_bottom=0.085, r_top=0.112), thigh_top=0.0, guard=False,
        shin_top=-0.22)


# --- Hard skin (BATIDA NEON): the night shift ----------------------------------------------
def batida13_x_hat(p):
    """A tall night-shift cap over the nurse's cap, its cross lit, two antennae with lights."""
    c = HEAD
    ey = HEAD_RADII[1]
    cap = sub(T(0, c.y + ey + 0.04, c.z + 0.01), rot=(-18, 0, 0))
    extruded(p, "shell", cap, [(-0.1, 0.0), (0.1, 0.0), (0.075, 0.1), (-0.075, 0.1)], 0.07)
    cross(p, sub(cap, 0, 0.05, -0.036, rot=(-90, 0, 0)), 0.05, role="glow")
    for side in (-1, 1):
        base = Vector((side * 0.07, c.y + ey + 0.1, c.z + 0.04))
        rod(p, "metal", base, base + Vector((side * 0.05, 0.14, 0.03)), 0.006, 6)
        mtube(p, "glow", T(*(base + Vector((side * 0.05, 0.15, 0.03)))), 0.016, 0.03, 10)


def batida13_x_extra(p):
    """An IV pole on the back with a lit drip bag, its line running to the free arm, and the
    defibrillator paddles holstered at the hips."""
    c = CHEST
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
