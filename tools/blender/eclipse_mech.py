"""ECLIPSE 16: the executor, tall and muscular, built as a machine like HÉLIO and BIT.

Made the way the cast is made (mech_kit.py, mech_parts.py): a dark chassis under painted
plates with a gap between every panel, bearings with bolt rings, forked hinges on an axle,
pistons, cables, boots, screws holding two parts together. Every joint shows how it turns:
hips on bolted bearings, knees and ankles on hinges that fold forward, so the stride reads as
a walk.

The body is HÉLIO's technique turned to a brute: a trunk turned on a lathe, broad at the chest
and narrow at the waist, its plates laid out as pectorals, abdominals, flanks and back; a
trapezius either side of the neck; huge domed pauldrons with spikes; biceps and forearms in
round shells; thick round thighs and flared calves. The head is an armoured dome with two
swept fins on bolted bearings, a narrow red visor under a V brow and a silver mask. On the
chest the eclipse core (black disc, violet corona, bolt ring); exhaust stacks on the back;
a three-talon hand with back-swept blades and a long cannon with the eclipse ring at the
muzzle.

python3 tools/blender/eclipse_mech.py
Writes art/robots/eclipse16.glb, the head's face metrics in roster.json and the knee height
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
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import robot_kit as kit  # noqa: E402  (sets up mech_kit)
import mech_kit as mk  # noqa: E402
from mech_cast import T, extruded, profile_radius, rev_panel, rev_point, scaled, screen_well  # noqa: E402
from mech_kit import (axis_frame, bearing, bolts, cable, capsule, cyl_panel, frame, hand, lathe,  # noqa: E402
                      mbox, mring, mtube, plane, screw, serial, sphere_panel, sub)
from mech_parts import leg, neck, pelvis, round_shin, round_thigh, shoulder, upper_arm, waist, wrist  # noqa: E402

OUTPUT = kit.ROOT / "art" / "robots" / "eclipse16.glb"
PREFIX = "eclipse16_"
E = {
    "hip": Vector((0.24, 0.86, 0.0)),
    "muzzle": Vector((0.5, 1.04, -1.12)),
    "shoulder_y": 1.6,
    "elbow_l": Vector((-0.5, 1.16, 0.02)),
    "wrist_l": Vector((-0.54, 0.86, -0.1)),
    # The game hangs the gun from (muzzle.x, 1.2, 0): the cannon arm's elbow is there.
    "elbow_r": Vector((0.5, 1.2, -0.02)),
}
CHEST = Vector((0.0, 1.42, 0.02))
FLAT = 0.78
# The trunk's profile (height, radius) from the waist up: a V, broad at the pectorals.
TRUNK = [(-0.32, 0.15), (-0.24, 0.16), (-0.18, 0.175), (-0.08, 0.22), (0.02, 0.28), (0.1, 0.31), (0.17, 0.305), (0.22, 0.26), (0.26, 0.17)]
HEAD = Vector((0.0, 1.88, 0.0))
HEAD_RADII = (0.15, 0.16, 0.15)
SCREEN = (0.2, 0.07)


def side_plane(x, y, z):
    """Local XY is the side view (local X forward, -Z world; Y up); thickness along world X."""
    return T(x, y, z) @ Matrix.Rotation(math.radians(90), 4, "Y")


def trunk_frame():
    return T(*CHEST) @ Matrix.Diagonal((1.0, 1.0, FLAT, 1.0))


def front_z(y):
    """The trunk's front surface at a height above the chest centre."""
    return CHEST.z - profile_radius(TRUNK, y) * FLAT


# --- Head ---------------------------------------------------------------------------------
def eclipse16_head(p):
    c = HEAD
    ex, ey, ez = HEAD_RADII
    mk.HEADS[PREFIX + "head"] = {"top": round(c.y + ey + 0.08, 3), "center": round(c.y + 0.01, 3),
                                 "aspect": round(SCREEN[0] / SCREEN[1], 3)}
    hs = scaled(c, ex, ey, ez)
    lathe(p, "dark", scaled(c, ex - 0.03, ey - 0.03, ez - 0.03),
          [(0.0, -1.0)] + [(math.sin(math.radians(a)), -math.cos(math.radians(a))) for a in range(15, 180, 15)] + [(0.0, 1.0)], 22)
    # Helmet dome, side and back guards, and the silver mask over the jaw.
    sphere_panel(p, "shell", hs, 1.0, (30, 88), (-180, 180), 0.2, (24, 6))
    sphere_panel(p, "shell", hs, 1.0, (-58, 26), (-30, 210), 0.2, (16, 6), gap=0.05)
    sphere_panel(p, "metal", hs, 1.04, (-72, -18), (-140, -40), 0.2, (10, 4), gap=0.04)
    for i in (-1, 0, 1):
        mbox(p, "dark", T(i * 0.026, c.y - 0.09, c.z - ez - 0.0), (0.01, 0.045, 0.012), 0.002, 1)
    # Visor in its well, under a heavy V brow.
    screen_well(p, (c.x, c.y + 0.01, c.z - ez + 0.01), SCREEN, 0.05, 0.03)
    for side in (-1, 1):
        mbox(p, "shell", sub(T(side * 0.065, c.y + 0.075, c.z - ez + 0.0), rot=(-8, 0, side * 16)), (0.15, 0.045, 0.08), 0.018)
    # Crest along the dome and two fins swept back from bolted bearings at the temples.
    extruded(p, "shell", side_plane(0, c.y + ey - 0.03, c.z), [(-0.16, 0.0), (0.12, 0.0), (0.2, 0.03), (0.06, 0.1), (-0.12, 0.07)], 0.04)
    for side in (-1, 1):
        axle = axis_frame((side * (ex - 0.005), c.y + 0.03, c.z + 0.01), "x" if side > 0 else "-x")
        bearing(p, axle, 0.05, 0.03, 5, seal=False)
        fin = side_plane(side * (ex + 0.035), c.y + 0.01, c.z + 0.01)
        extruded(p, "shell", fin, [(0.06, -0.03), (-0.03, -0.06), (-0.14, 0.09), (-0.18, 0.27), (-0.06, 0.14), (0.05, 0.05)], 0.03)
        extruded(p, "trim", fin @ Matrix.Translation((0, 0, side * 0.017)),
                 [(-0.04, 0.02), (-0.13, 0.12), (-0.16, 0.23), (-0.08, 0.13), (0.0, 0.04)], 0.006)
        mbox(p, "glow", T(side * (ex - 0.01), c.y - 0.05, c.z - 0.06), (0.01, 0.02, 0.03), 0.003, 1)
    serial(p, plane((0.0, c.y - 0.02, c.z + ez + 0.004), (0, 0, 1), (1, 0, 0)), "05", 0.03)


# --- Trunk --------------------------------------------------------------------------------
def eclipse16_torso(p):
    c = CHEST
    flat = trunk_frame()
    bottom, top = TRUNK[0][0], TRUNK[-1][0]
    neck(p, c.y + top - 0.005, HEAD.y - HEAD_RADII[1] + 0.02, 0.07, 0.0, plate=(0.22, 0.2))
    lathe(p, "dark", flat, [(0.0, bottom)] + [(r - 0.035, y) for y, r in TRUNK] + [(0.0, top)], 28)
    # Pectorals, abdominals in two rows, flanks and the back.
    for lon in ((-152, -95), (-85, -28)):
        rev_panel(p, "shell", flat, TRUNK, (-0.01, 0.24), lon, 0.04, (10, 8), gap=0.014)
    for yr in ((-0.31, -0.2), (-0.195, -0.105), (-0.1, -0.015)):
        for lon in ((-128, -91), (-89, -52)):
            rev_panel(p, "shell", flat, TRUNK, yr, lon, 0.032, (6, 4), gap=0.014)
    for lon in ((-24, 24), (156, 204)):
        rev_panel(p, "trim", flat, TRUNK, (-0.26, 0.16), lon, 0.03, (6, 6), gap=0.014)
    rev_panel(p, "shell", flat, TRUNK, (-0.3, 0.24), (30, 150), 0.034, (10, 8), gap=0.014)
    mring(p, "trim", sub(flat, 0, bottom + 0.025, 0), profile_radius(TRUNK, bottom + 0.025) + 0.004, 0.016, 28, 5)
    mring(p, "trim", sub(flat, 0, top - 0.03, 0), profile_radius(TRUNK, top - 0.03) + 0.004, 0.014, 28, 5)
    # Glow seams under the pectorals.
    for side in (-1, 1):
        q, n = rev_point(c, TRUNK, FLAT, -90 + side * 34, -0.02)
        mbox(p, "glow", frame(q, n, front=(0, 1, 0)), (0.1, 0.006, 0.012), 0.002, 1)
    # The eclipse core in the sternum: bolt ring, violet corona, black disc.
    core = axis_frame((0, c.y + 0.11, front_z(0.11) + 0.015), "-z")
    mtube(p, "metal", core, 0.085, 0.03, 24)
    bolts(p, sub(core, 0, 0.015, 0), 0.074, 8, size=0.009, phase=0.2)
    mring(p, "glow", sub(core, 0, 0.02, 0), 0.056, 0.011, 24, 5)
    mtube(p, "dark", sub(core, 0, 0.028, 0), 0.05, 0.014, 20)
    # Trapezius either side of the neck, sloping down to the pauldrons.
    for side in (-1, 1):
        trap = sub(T(side * 0.17, c.y + top - 0.02, 0.04), rot=(0, 0, -side * 24))
        mbox(p, "shell", trap, (0.2, 0.08, 0.24), 0.035)
        screw(p, sub(trap, 0, 0.042, 0), side * 0.05, 0.08)
        screw(p, sub(trap, 0, 0.042, 0), side * 0.05, -0.08)
    # Back: two exhaust stacks lit inside.
    for u in (-1, 1):
        stack = T(u * 0.12, c.y + 0.16, 0.25)
        mtube(p, "dark", stack, 0.048, 0.3, 14, bevel=0.006)
        mring(p, "metal", sub(stack, 0, 0.15, 0), 0.048, 0.01, 14, 4)
        mtube(p, "glow", sub(stack, 0, 0.14, 0), 0.034, 0.02, 12)
        bolts(p, sub(stack, 0, -0.12, 0), 0.056, 4, size=0.009)
    waist(p, 0.97, c.y + bottom + 0.02, 0.12)
    pelvis(p, (0, 0.88, 0.0), (0.3, 0.16, 0.27), E["hip"].x, E["hip"].y, 0.09)
    for side in (-1, 1):
        cable(p, [(side * 0.24, c.y + 0.2, 0.18), (side * 0.36, c.y + 0.22, 0.17), (side * 0.43, c.y + 0.04, 0.1)], 0.011)


# --- Shoulders and arms -------------------------------------------------------------------
def eclipse16_shoulders(p):
    y = E["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.3, y, 0.01, 0.11, 0.09, 0.08)
        mbox(p, "dark", T(drum.x, y + 0.11, 0.01), (0.05, 0.06, 0.08), 0.01, 1)
        m = T(drum.x + side * 0.02, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        sphere_panel(p, "shell", m, 0.2, (20, 88), (a0 - 30, a1 + 30), 0.032, (14, 6), gap=0.008)
        sphere_panel(p, "trim", m, 0.205, (6, 18), (a0 - 25, a1 + 25), 0.028, (14, 2), gap=0.006)
        mbox(p, "team", T(drum.x + side * 0.02, y + 0.222, 0.01), (0.07, 0.01, 0.11), 0.004, 1)
        # Two spikes off the dome, up and out.
        for dz, h in ((-0.07, 0.17), (0.08, 0.12)):
            base = Vector((drum.x + side * 0.1, y + 0.17, 0.01 + dz))
            lathe(p, "trim", frame(base, (side * 0.6, 1.0, 0.0)), [(0.0, 0.0), (0.04, 0.0), (0.02, h * 0.55), (0.0, h)], 6)
        upper_arm(p, side, pin, E["elbow_l"] if side < 0 else E["elbow_r"], bone_r=0.045, elbow_w=0.085, elbow_r=0.055, armor_size=(0.15, 0.14))
        # The biceps: a round shell over the front of the upper arm.
        elbow = E["elbow_l"] if side < 0 else E["elbow_r"]
        arm = frame(pin.lerp(elbow, 0.5), elbow - pin)
        capsule(p, "shell", sub(arm, side * 0.02, -0.01, -0.045), 0.1, (elbow - pin).length * 0.78, 18)
        mring(p, "trim", sub(arm, side * 0.02, (elbow - pin).length * 0.3, -0.045), 0.096, 0.012, 18, 4)


def eclipse16_arm(p):
    # Free arm: a heavy round gauntlet with back-swept blades and a three-talon hand.
    e, wr = E["elbow_l"], E["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.08, 0.08, 0.09), 0.012, 1)
    capsule(p, "dark", sub(m, 0, length * 0.55, 0), 0.095, length * 0.8, 18)
    for lo in ((-75, 75), (105, 255)):
        cyl_panel(p, "shell", sub(m, 0, length * 0.45, 0), 0.12, length * 0.55, lo, 0.035, (10, 2), gap=0.012, radius_top=0.135)
    cuff = sub(m, 0, length * 0.74, 0)
    lathe(p, "trim", cuff, [(0.105, 0.0), (0.125, 0.0), (0.15, 0.07), (0.145, 0.085), (0.09, 0.085), (0.105, 0.0)], 22)
    for k, (u, scale) in enumerate(((-0.13, 1.0), (-0.11, 0.7))):
        blade = sub(m, u, length * 0.5, 0.03 + k * 0.06) @ Matrix.Rotation(math.radians(90), 4, "Y")
        extruded(p, "trim", blade, [(-0.04, 0.3 * length * scale), (0.03, 0.26 * length * scale),
                                    (0.14 * scale, -0.62 * length * scale), (-0.02, -0.12 * length)], 0.018)
    mbox(p, "glow", sub(m, 0, length * 0.45, 0.122), (0.05, 0.012, 0.01), 0.003, 1)
    wrist(p, m, length, plate=(0.11, 0.1))
    hand(p, sub(m, 0, length + 0.16, 0.0, rot=(0, -90, 180)), fingers=3, scale=1.65, curl=1.3)
    # Cannon arm: a flared round housing with rings and the barrel's bolted collar.
    e, muzzle = E["elbow_r"], E["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.08, 0.08, 0.09), 0.012, 1)
    lathe(p, "shell", m, [(0.0, 0.07), (0.08, 0.08), (0.125, 0.14), (0.135, 0.3), (0.12, 0.42), (0.0, 0.44)], 24)
    for v in (0.15, 0.37):
        mring(p, "trim", sub(m, 0, v, 0), 0.132, 0.014, 24, 5)
    for i in range(3):
        mbox(p, "glow", sub(m, -0.03 + i * 0.03, 0.26, 0.132), (0.016, 0.05, 0.008), 0.003, 1)
    fin = sub(m, 0, 0.26, 0.13) @ Matrix.Rotation(math.radians(90), 4, "Y")
    extruded(p, "trim", fin, [(0.0, 0.12), (0.0, -0.12), (-0.1, -0.18)], 0.025)
    ring = sub(m, 0, 0.47, 0)
    mtube(p, "metal", ring, 0.1, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.084, 6, size=0.009)


def eclipse16_gun(p):
    """The barrel only: it recoils into the forearm housing."""
    e, muzzle = E["elbow_r"], E["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.52, 0), 0.07, 0.12, 16)
    mtube(p, "dark", sub(m, 0, 0.76, 0), 0.066, 0.42, 18, bevel=0.008)
    for v in (0.62, 0.7, 0.78, 0.86):
        mring(p, "trim", sub(m, 0, v, 0), 0.07, 0.012, 18, 4)
    # The muzzle is a small eclipse: bolted ring, violet corona, black disc.
    brake = sub(m, 0, length - 0.04, 0)
    mtube(p, "metal", brake, 0.105, 0.07, 20, bevel=0.01)
    bolts(p, sub(brake, 0, 0.036, 0), 0.09, 6, size=0.009)
    mring(p, "glow", sub(brake, 0, 0.04, 0), 0.066, 0.012, 20, 5)
    mtube(p, "dark", sub(brake, 0, 0.044, 0), 0.056, 0.006, 18)


# --- Legs: thick round thighs, flared calves, knees folding forward -----------------------
def eclipse16_leg(p, out):
    def boots(q, m, o, ankle):
        mk.foot(q, m, length=0.5, width=0.3, out=o, toes=3, armor="shell", heel="trim")
        extruded(q, "metal", side_plane(0, m.translation.y + 0.03, 0.17), [(0.0, 0.0), (0.0, 0.07), (-0.12, 0.0)], 0.06)
    leg(p, out, E["hip"].y, knee_y=-0.36, ankle_up=0.18, width=1.2, knee_w=0.14, knee_r=0.074, foot_fn=boots,
        thigh_fn=round_thigh(k=1.25, radius=0.135), shin_fn=round_shin(k=1.15, r_bottom=0.095, r_top=0.14), thigh_top=0.02)


def define():
    kit.PARTS.clear()
    for slot in ("head", "torso", "shoulders", "arm", "gun"):
        kit.part(PREFIX + slot)(globals()[PREFIX + slot])
    kit.part(PREFIX + "leg_l")(lambda q: eclipse16_leg(q, -1))
    kit.part(PREFIX + "leg_r")(lambda q: eclipse16_leg(q, 1))


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
    print("ECLIPSE16", sorted(objects), "tris", tris, "bytes", OUTPUT.stat().st_size)


if __name__ == "__main__":
    build()
