"""ROSCA 13: the workshop engineer who builds the minigun sentries, made like HÉLIO and BIT.

The circuit's fastest mechanic, now an engineer: stocky and low, in overalls. Built the way
the cast is built (mech_kit.py, mech_parts.py): dark chassis under painted plates, bearings
with bolt rings, forked hinges, pistons and cables; knees and ankles fold forward.

The look: a yellow hard hat with a ridge, a brim, a headlamp and welding goggles pushed up;
a square head with a wide visor. A barrel trunk in overalls (bib, straps with buckles, a
pocket) with reflective bands; a tool belt with pouches and a hammer; a sentry folded on
the back, its six-barrel gun and tripod legs packed; rounded shoulder pads with hazard
stripes and a warning light. A wrench in the free hand and a six-barrel minigun on the
other arm. Short round legs in steel-toe work boots.

python3 tools/blender/rosca_engineer.py
Writes art/robots/rosca13.glb, the head's face metrics in roster.json and the knee height
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
from mech_cast import T, extruded, hazard_band, profile_radius, rev_panel, rev_point, scaled, screen_well  # noqa: E402
from mech_kit import (axis_frame, bolts, cable, capsule, cyl_panel, frame, hand, lathe,  # noqa: E402
                      mbox, mring, mtube, plane, rod, screw, serial, sphere_panel, sub)
from mech_parts import leg, neck, round_shin, round_thigh, shoulder, upper_arm, waist, wrist  # noqa: E402

OUTPUT = kit.ROOT / "art" / "robots" / "rosca13.glb"
PREFIX = "rosca13_"
R = {
    "hip": Vector((0.22, 0.6, 0.0)),
    "muzzle": Vector((0.47, 0.81, -1.01)),
    "shoulder_y": 1.22,
    "elbow_l": Vector((-0.52, 0.94, 0.02)),
    "wrist_l": Vector((-0.55, 0.68, -0.1)),
    "elbow_r": Vector((0.47, 0.95, -0.02)),
}
CHEST = Vector((0.0, 1.06, 0.02))
FLAT = 0.86
TRUNK = [(-0.22, 0.2), (-0.14, 0.235), (-0.04, 0.265), (0.06, 0.28), (0.13, 0.27), (0.19, 0.23), (0.23, 0.16)]
HEAD = Vector((0.0, 1.45, 0.0))
HEAD_SIZE = (0.3, 0.22, 0.26)
SCREEN = (0.22, 0.08)


def side_plane(x, y, z):
    """Local XY is the side view (local X forward, -Z world; Y up); thickness along world X."""
    return T(x, y, z) @ Matrix.Rotation(math.radians(90), 4, "Y")


def on_trunk(lon, y, lift=0.002):
    q, n = rev_point(CHEST, TRUNK, FLAT, lon, y, lift)
    return frame(q, n, front=(0, 1, 0))


def at3(m, u, v, w):
    return (m @ Vector((u, v, w, 1.0))).to_3d()


# --- Head ---------------------------------------------------------------------------------
def rosca13_head(p):
    c = HEAD
    w, h, d = HEAD_SIZE
    front = c.z - d / 2
    mk.HEADS[PREFIX + "head"] = {"top": round(c.y + h / 2 + 0.16, 3), "center": round(c.y - 0.01, 3),
                                 "aspect": round(SCREEN[0] / SCREEN[1], 3)}
    base = T(*c)
    mbox(p, "dark", base, (w - 0.04, h - 0.03, d - 0.04), 0.04, 2)
    for side in (-1, 1):
        cheek = sub(base, side * (w / 2 - 0.02), -0.01, 0.0)
        mbox(p, "shell", cheek, (0.04, h - 0.06, d - 0.06), 0.015)
        screw(p, sub(cheek, side * 0.021, 0.04, 0.0, rot=(0, 0, -90 * side)), 0, 0.07, 0.007)
        screw(p, sub(cheek, side * 0.021, 0.04, 0.0, rot=(0, 0, -90 * side)), 0, -0.07, 0.007)
        # Ear protectors on bearings at the sides.
        ear = axis_frame((side * (w / 2 + 0.015), c.y - 0.01, 0.0), "x" if side > 0 else "-x")
        mtube(p, "trim", ear, 0.055, 0.035, 18, bevel=0.008)
        mtube(p, "dark", mk.sub(ear, 0, 0.019, 0), 0.035, 0.006, 14)
    mbox(p, "shell", sub(base, 0, -h / 2 + 0.03, front + 0.04), (w - 0.06, 0.05, 0.07), 0.015)
    for i in range(4):
        mbox(p, "dark", T((i - 1.5) * 0.04, c.y - h / 2 + 0.03, front - 0.0), (0.012, 0.03, 0.01), 0.002, 1)
    mbox(p, "shell", sub(base, 0, 0.0, d / 2 - 0.02), (w - 0.08, h - 0.06, 0.04), 0.015)
    screen_well(p, (c.x, c.y + 0.015, front - 0.005), SCREEN, 0.05, 0.03)
    # Hard hat: dome, brim, ridge, headlamp and the goggles pushed up on it.
    hat_c = Vector((0.0, c.y + h / 2 - 0.01, 0.0))
    dome = scaled(hat_c, 0.19, 0.14, 0.18)
    sphere_panel(p, "trim", dome, 1.0, (2, 90), (-180, 180), 0.12, (24, 6))
    mring(p, "trim", T(*hat_c) @ Matrix.Diagonal((1.0, 1.0, 0.95, 1.0)), 0.2, 0.016, 28, 5)
    lathe(p, "trim", T(*hat_c) @ Matrix.Diagonal((1.0, 1.0, 0.95, 1.0)), [(0.17, 0.0), (0.235, -0.01), (0.24, 0.005), (0.18, 0.012)], 28)
    extruded(p, "trim", side_plane(0, hat_c.y + 0.02, hat_c.z), [(-0.17, 0.0), (0.17, 0.0), (0.12, 0.13), (-0.12, 0.13)], 0.045)
    lamp = sub(T(0, hat_c.y + 0.06, hat_c.z - 0.175), rot=(-78, 0, 0))
    mbox(p, "dark", sub(lamp, 0, -0.01, 0), (0.09, 0.03, 0.06), 0.01, 1)
    mtube(p, "metal", lamp, 0.032, 0.035, 16, bevel=0.004)
    mtube(p, "glow", sub(lamp, 0, 0.018, 0), 0.025, 0.006, 14)
    for side in (-1, 1):
        g = sub(T(side * 0.06, hat_c.y + 0.015, hat_c.z - 0.18), rot=(-70, 0, 0))
        mtube(p, "metal", g, 0.036, 0.03, 14, bevel=0.004)
        mtube(p, "glow", sub(g, 0, 0.016, 0), 0.026, 0.004, 12)
    rod(p, "rubber", Vector((-0.024, hat_c.y + 0.02, hat_c.z - 0.19)), Vector((0.024, hat_c.y + 0.02, hat_c.z - 0.19)), 0.008, 6)
    serial(p, plane((0.0, c.y - 0.02, c.z + d / 2 + 0.004), (0, 0, 1), (1, 0, 0)), "06", 0.035)


# --- Trunk --------------------------------------------------------------------------------
def rosca13_torso(p):
    c = CHEST
    flat = T(*c) @ Matrix.Diagonal((1.0, 1.0, FLAT, 1.0))
    bottom, top = TRUNK[0][0], TRUNK[-1][0]
    neck(p, c.y + top - 0.005, HEAD.y - HEAD_SIZE[1] / 2 + 0.02, 0.07, 0.0, plate=(0.24, 0.2))
    lathe(p, "dark", flat, [(0.0, bottom)] + [(r - 0.035, y) for y, r in TRUNK] + [(0.0, top)], 26)
    # Overalls: bib in front, sides and back, reflective bands round the chest and belly.
    rev_panel(p, "shell", flat, TRUNK, (-0.21, 0.2), (-140, -40), 0.036, (12, 8), gap=0.012)
    for lon in ((-34, 34), (146, 214)):
        rev_panel(p, "shell", flat, TRUNK, (-0.21, 0.17), lon, 0.032, (6, 6), gap=0.012)
    rev_panel(p, "shell", flat, TRUNK, (-0.21, 0.21), (40, 140), 0.034, (10, 8), gap=0.012)
    for y in (0.06, -0.1):
        mring(p, "trim", sub(flat, 0, y, 0), profile_radius(TRUNK, y) + 0.004, 0.014, 28, 4)
    mring(p, "metal", sub(flat, 0, top - 0.03, 0), profile_radius(TRUNK, top - 0.03) + 0.004, 0.012, 26, 5)
    pocket = on_trunk(-90, -0.02, 0.004)
    mbox(p, "shell", sub(pocket, 0, 0.008, 0), (0.14, 0.016, 0.09), 0.006, 1)
    mbox(p, "trim", sub(pocket, 0, 0.018, 0.035), (0.14, 0.006, 0.016), 0.002, 1)
    for side in (-1, 1):
        strap = on_trunk(-90 + side * 30, 0.15, 0.006)
        mbox(p, "shell", strap, (0.05, 0.012, 0.14), 0.004, 1)
        mbox(p, "metal", sub(strap, 0, 0.008, -0.03), (0.05, 0.01, 0.035), 0.004, 1)
    # Tool belt: dark band, buckle, pouches and a hammer.
    by = c.y + bottom + 0.035
    mring(p, "dark", T(0, by, c.z) @ Matrix.Diagonal((1.0, 1.0, FLAT, 1.0)), profile_radius(TRUNK, bottom + 0.035) + 0.01, 0.026, 28, 6)
    mbox(p, "metal", T(0, by, c.z - profile_radius(TRUNK, bottom + 0.035) * FLAT - 0.03), (0.07, 0.05, 0.016), 0.006, 1)
    for lon in (-130, -50, 20, 160):
        q, n = rev_point(Vector((0, by, c.z)), TRUNK[:2], FLAT, lon, by - c.y, 0.02)
        mbox(p, "dark", frame(q, n, front=(0, 1, 0)), (0.075, 0.05, 0.08), 0.01, 1)
    hammer = Vector((-0.24, by - 0.03, -0.08))
    rod(p, "dark", hammer, hammer + Vector((0.0, -0.17, 0.0)), 0.012, 8)
    mbox(p, "metal", T(*(hammer + Vector((0.0, 0.02, 0.0)))), (0.03, 0.035, 0.12), 0.006, 1)
    # Folded sentry on the back: body, six barrels, tripod legs.
    sentry = T(0, c.y + 0.03, 0.3)
    mbox(p, "dark", sentry, (0.26, 0.26, 0.1), 0.02)
    mbox(p, "trim", sub(sentry, 0, 0.0, 0.055), (0.22, 0.2, 0.02), 0.01, 1)
    hazard_band(p, sub(sentry, 0, -0.1, 0.066, rot=(90, 0, 0)), 0.2, 0.03, 6)
    gun = axis_frame((0, c.y + 0.03, 0.42), "y")
    for k in range(6):
        a = math.radians(k * 60)
        rod(p, "metal", at3(gun, math.cos(a) * 0.028, -0.12, math.sin(a) * 0.028), at3(gun, math.cos(a) * 0.028, 0.14, math.sin(a) * 0.028), 0.009, 6)
    for v in (-0.1, 0.1):
        mtube(p, "dark", sub(gun, 0, v, 0), 0.045, 0.02, 14)
    for side in (-1, 1):
        rod(p, "metal", Vector((side * 0.1, c.y + 0.15, 0.35)), Vector((side * 0.13, c.y - 0.15, 0.37)), 0.01, 6)
    mbox(p, "glow", T(0.1, c.y + 0.15, 0.36), (0.03, 0.02, 0.01), 0.003, 1)
    waist(p, 0.7, c.y + bottom + 0.02, 0.12)
    hips(p)
    for side in (-1, 1):
        cable(p, [(side * 0.2, c.y + 0.18, 0.18), (side * 0.32, c.y + 0.2, 0.17), (side * 0.4, c.y + 0.03, 0.1)], 0.011)


def hips(p):
    hip = R["hip"]
    c = Vector((0, 0.63, 0.0))
    mbox(p, "dark", T(*c), (0.3, 0.14, 0.26), 0.035)
    mbox(p, "shell", sub(T(0, c.y + 0.0, -0.15), rot=(8, 0, 0)), (0.26, 0.12, 0.05), 0.022)
    mbox(p, "shell", T(0, c.y, 0.15), (0.24, 0.11, 0.05), 0.02)
    mbox(p, "team", sub(T(0, c.y + 0.02, -0.178), rot=(8, 0, 0)), (0.12, 0.024, 0.01), 0.004, 1)
    for side in (-1, 1):
        x0 = 0.16
        house = axis_frame((side * x0, hip.y, 0.0), "x" if side > 0 else "-x")
        mtube(p, "dark", house, 0.085, 0.04, 20, bevel=0.006)
        bolts(p, sub(house, 0, 0.022, 0), 0.07, 6, size=0.01)
        mtube(p, "metal", sub(house, 0, 0.02 + (hip.x - x0) / 2 + 0.03, 0), 0.04, hip.x - x0 + 0.07, 12)


# --- Shoulders and arms -------------------------------------------------------------------
def rosca13_shoulders(p):
    y = R["shoulder_y"]
    for side in (-1, 1):
        pin, drum = shoulder(p, side, 0.28, y, 0.01, 0.1, 0.085, 0.08)
        mbox(p, "dark", T(drum.x, y + 0.1, 0.01), (0.05, 0.06, 0.08), 0.01, 1)
        m = T(drum.x + side * 0.015, y + 0.02, 0.01)
        a0, a1 = (-90, 90) if side > 0 else (90, 270)
        sphere_panel(p, "shell", m, 0.16, (22, 88), (a0 - 28, a1 + 28), 0.03, (12, 5), gap=0.008)
        hazard_band(p, sub(T(drum.x + side * 0.015, y + 0.07, -0.135), rot=(-90, 0, 0)), 0.16, 0.03, 6)
        if side > 0:
            beacon = T(drum.x + side * 0.03, y + 0.19, 0.04)
            mtube(p, "dark", beacon, 0.035, 0.02, 14)
            capsule(p, "glow", sub(beacon, 0, 0.035, 0), 0.028, 0.06, 12)
        elbow = R["elbow_l"] if side < 0 else R["elbow_r"]
        upper_arm(p, side, pin, elbow, bone_r=0.045, elbow_w=0.085, elbow_r=0.054, armor_size=(0.14, 0.12))
        arm = frame(pin.lerp(elbow, 0.5), elbow - pin)
        capsule(p, "shell", sub(arm, side * 0.015, 0.0, -0.04), 0.085, (elbow - pin).length * 0.7, 16)


def wrench(p, m, length=0.34):
    """An open-ended wrench along local Y of `m`, the jaw at +Y."""
    mbox(p, "metal", sub(m, 0, length / 2, 0), (0.035, length, 0.018), 0.006, 1)
    jaw = m @ Matrix.Translation((0, length + 0.03, 0))
    extruded(p, "metal", jaw, [(-0.06, -0.04), (0.06, -0.04), (0.07, 0.03), (0.03, 0.07), (0.022, 0.0), (-0.022, 0.0), (-0.03, 0.07), (-0.07, 0.03)], 0.02)
    mtube(p, "metal", sub(m, 0, -0.01, 0, rot=(90, 0, 0)), 0.035, 0.02, 14)


def rosca13_arm(p):
    # Free arm: work gauntlet with a red-and-yellow cuff, a four-finger hand and a wrench.
    e, wr = R["elbow_l"], R["wrist_l"]
    m = frame(e, wr - e, front=(0.3, 0, -1))
    length = (wr - e).length
    mbox(p, "dark", sub(m, 0, 0.02, 0), (0.08, 0.08, 0.09), 0.012, 1)
    capsule(p, "dark", sub(m, 0, length * 0.55, 0), 0.085, length * 0.8, 18)
    for lo in ((-75, 75), (105, 255)):
        cyl_panel(p, "shell", sub(m, 0, length * 0.45, 0), 0.11, length * 0.55, lo, 0.032, (10, 2), gap=0.012, radius_top=0.12)
    lathe(p, "trim", sub(m, 0, length * 0.74, 0), [(0.095, 0.0), (0.115, 0.0), (0.135, 0.065), (0.13, 0.078), (0.085, 0.078), (0.095, 0.0)], 22)
    mbox(p, "glow", sub(m, 0, length * 0.42, 0.112), (0.04, 0.012, 0.01), 0.003, 1)
    wrist(p, m, length, plate=(0.11, 0.1))
    palm = sub(m, 0, length + 0.15, 0.0, rot=(0, -90, 180))
    hand(p, palm, fingers=4, scale=1.4, curl=1.5)
    wrench(p, frame(at3(m, 0.0, length + 0.14, 0.0), (0.0, 0.25, -1.0), front=(1, 0, 0)), 0.36)
    # Gun arm: a square housing with the minigun's motor and a bolted collar.
    e, muzzle = R["elbow_r"], R["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    mbox(p, "dark", sub(m, 0, 0.03, 0), (0.08, 0.08, 0.09), 0.012, 1)
    housing = sub(m, 0, 0.25, 0)
    mbox(p, "dark", housing, (0.22, 0.34, 0.22), 0.03)
    mbox(p, "shell", sub(housing, 0, -0.02, 0.045), (0.26, 0.26, 0.14), 0.04)
    hazard_band(p, sub(housing, 0, 0.12, 0.117), 0.22, 0.04, 6)
    for side in (-1, 1):
        mbox(p, "trim", sub(housing, side * 0.118, 0.02, -0.04), (0.035, 0.24, 0.1), 0.014)
    mtube(p, "dark", sub(housing, -0.13, -0.04, 0.0, rot=(0, 0, 90)), 0.05, 0.05, 14)
    ring = sub(m, 0, 0.45, 0)
    mtube(p, "metal", ring, 0.1, 0.03, 20, bevel=0.006)
    bolts(p, sub(ring, 0, 0.017, 0), 0.084, 6, size=0.009)


def rosca13_gun(p):
    """The minigun: six barrels round a spindle, two clamps and a muzzle ring; it recoils."""
    e, muzzle = R["elbow_r"], R["muzzle"]
    m = frame(e, muzzle - e, front=(0, 1, 0))
    length = (muzzle - e).length
    mtube(p, "dark", sub(m, 0, 0.5, 0), 0.075, 0.08, 18)
    mtube(p, "metal", sub(m, 0, (0.5 + length) / 2, 0), 0.016, length - 0.5, 8)
    for k in range(6):
        a = math.radians(k * 60)
        u, w = math.cos(a) * 0.045, math.sin(a) * 0.045
        rod(p, "metal", at3(m, u, 0.52, w), at3(m, u, length - 0.01, w), 0.014, 8)
    for v in (0.62, length - 0.14):
        mtube(p, "dark", sub(m, 0, v, 0), 0.07, 0.03, 18)
    mtube(p, "trim", sub(m, 0, length - 0.03, 0), 0.072, 0.03, 18, bevel=0.004)
    mtube(p, "glow", sub(m, 0, length - 0.012, 0), 0.02, 0.006, 10)


# --- Legs ---------------------------------------------------------------------------------
def rosca13_leg(p, out):
    def boots(q, m, o, ankle):
        mk.foot(q, m, length=0.46, width=0.32, out=o, toes=2, armor="shell", heel="trim")
        toe = T(0, m.translation.y + 0.07, -0.22) @ Matrix.Diagonal((0.15, 0.07, 0.09, 1.0))
        sphere_panel(q, "trim", toe, 1.0, (0, 88), (-180, 0), 0.25, (12, 4))
    leg(p, out, R["hip"].y, knee_y=-0.2, ankle_up=0.16, width=1.15, knee_w=0.13, knee_r=0.066, foot_fn=boots,
        thigh_fn=round_thigh(k=1.15, radius=0.13), shin_fn=round_shin(k=1.15, r_bottom=0.1, r_top=0.13), thigh_top=0.0,
        guard=False, shin_top=-0.16)


# --- Hard skin (ROSCA TURBO) --------------------------------------------------------------
def rosca13_x_extra(p):
    """A giant wrench slung across the back and a second beacon on the left pad."""
    c = CHEST
    wrench(p, frame(Vector((0.18, c.y - 0.2, 0.38)), (-0.5, 1.0, 0.0), front=(0, 0, 1)), 0.62)
    y = R["shoulder_y"]
    beacon = T(-0.38, y + 0.19, 0.04)
    mtube(p, "dark", beacon, 0.035, 0.02, 14)
    capsule(p, "glow", sub(beacon, 0, 0.035, 0), 0.028, 0.06, 12)


def define():
    kit.PARTS.clear()
    for slot in ("head", "torso", "shoulders", "arm", "gun"):
        kit.part(PREFIX + slot)(globals()[PREFIX + slot])
    kit.part(PREFIX + "leg_l")(lambda q: rosca13_leg(q, -1))
    kit.part(PREFIX + "leg_r")(lambda q: rosca13_leg(q, 1))
    kit.part(PREFIX + "x_extra")(rosca13_x_extra)


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
    print("ROSCA13", sorted(objects), "tris", tris, "bytes", OUTPUT.stat().st_size)


if __name__ == "__main__":
    build()
