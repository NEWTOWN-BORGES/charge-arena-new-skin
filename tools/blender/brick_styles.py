"""OFICINA brick styles: ten wall bricks bought with bricks, worn by the player's wall.

Every style stands on the common plinth of the mechanical bricks (brick_socle: dark plate,
team band, corner screws, the side joints), keeps their footprint (0.54 x 0.29) and height
(from under half a unit to over it), and leaves the plinth's faces free for the three life
lights. Each style has colours of its own (scripts/progression/cosmetics.gd, "palette"); the
team's colour stays on top, as on the themed bricks.

python3 tools/blender/brick_styles.py
Writes art/robots/bricks13.glb: parts "brickstyle_<id>" and their half-detail "lo_" copies.
Coordinates: Godot units, Y up, front -Z, right +X.
"""
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import robot_kit as kit  # noqa: E402  (sets up mech_kit)
from mech_cast import T, ball, both_faces, brick_socle, extruded  # noqa: E402
from mech_kit import axis_frame, bolts, lathe, mbox, mring, mtube, rod, screw, sub  # noqa: E402

OUTPUT = kit.ROOT / "art" / "robots" / "bricks13.glb"
PREFIX = "brickstyle_"
DETAIL = 1.0  # mech_kit.lod reads the running script's DETAIL: the "lo_" copies are half.
STYLES = {}


def style(name):
    def register(fn):
        STYLES[name] = fn
        return fn
    return register


@style("cofre")
def safe(p):
    """A strongbox: steel body, a door on each face with a dial, a handle and two hinges."""
    brick_socle(p)
    mbox(p, "shell", T(0, 0.27, 0), (0.5, 0.33, 0.27), 0.03, 1)
    mbox(p, "team", T(0, 0.445, 0), (0.48, 0.025, 0.25), 0.01, 1)

    def face(z):
        door = T(0.0, 0.27, z * 0.136)
        mbox(p, "trim", door, (0.38, 0.25, 0.012), 0.01, 1)
        dial = axis_frame((-0.06, 0.28, z * 0.146), "z" if z > 0 else "-z")
        mtube(p, "metal", dial, 0.055, 0.016, 18, bevel=0.004)
        mtube(p, "dark", sub(dial, 0, 0.009, 0), 0.035, 0.004, 16)
        mbox(p, "glow", T(-0.06, 0.315, z * 0.156), (0.008, 0.02, 0.004), 0.0, 1)
        rod(p, "metal", Vector((0.08, 0.32, z * 0.148)), Vector((0.08, 0.22, z * 0.148)), 0.012, 8)
        for y in (0.2, 0.34):
            mtube(p, "metal", T(-0.19, y, z * 0.144), 0.014, 0.05, 8)
    both_faces(face)


@style("barril")
def barrels(p):
    """A big drum lying along the wall in a cradle, a small one standing at its end."""
    brick_socle(p)
    for x in (-0.15, 0.08):
        mbox(p, "dark", T(x, 0.12, 0), (0.05, 0.05, 0.24), 0.01, 1)
    drum = axis_frame((-0.05, 0.25, 0), "x")
    mtube(p, "shell", drum, 0.14, 0.36, 22, bevel=0.012)
    for y in (-0.12, 0.0, 0.12):
        mring(p, "metal", sub(drum, 0, y, 0), 0.141, 0.01, 22, 4)
    mtube(p, "trim", sub(drum, 0, -0.18, 0), 0.12, 0.012, 20)
    mtube(p, "dark", sub(drum, 0.0, -0.186, 0.06), 0.022, 0.012, 8)
    small = T(0.2, 0.2, 0)
    mtube(p, "trim", small, 0.07, 0.2, 16, bevel=0.008)
    for y in (-0.06, 0.06):
        mring(p, "metal", sub(small, 0, y, 0), 0.071, 0.008, 16, 4)
    mtube(p, "team", sub(small, 0, 0.102, 0), 0.06, 0.01, 14)

@style("cristal")
def crystals(p):
    """A cluster of lit crystal prisms out of a dark rock."""
    brick_socle(p)
    mbox(p, "dark", T(0, 0.13, 0), (0.48, 0.07, 0.25), 0.03, 1)
    shards = [(0.0, 0.0, 0.52, 0.08, 0.0), (-0.14, 0.03, 0.3, 0.06, -18), (0.14, -0.03, 0.32, 0.06, 16),
              (-0.06, -0.06, 0.24, 0.045, -8), (0.07, 0.07, 0.22, 0.045, 10), (-0.21, -0.04, 0.16, 0.04, -30),
              (0.21, 0.05, 0.18, 0.04, 28)]
    for i, (x, z, h, r, tilt) in enumerate(shards):
        m = T(x, 0.15, z) @ Matrix.Rotation(math.radians(tilt), 4, "Z")
        lathe(p, "glow" if i % 2 == 0 else "trim", m, [(0.0, 0.0), (r, 0.0), (r, h * 0.72), (0.0, h)], 6)
    mbox(p, "team", T(0, 0.1, 0), (0.5, 0.02, 0.27), 0.006, 1)


@style("piramide")
def pyramid(p):
    """A stepped pyramid with a lit eye on each face and a cap in the team's colour."""
    brick_socle(p)
    for i, (w, d, h) in enumerate(((0.5, 0.27, 0.11), (0.4, 0.23, 0.1), (0.3, 0.19, 0.1), (0.2, 0.15, 0.1))):
        mbox(p, "shell" if i % 2 == 0 else "trim", T(0, 0.15 + i * 0.105, 0), (w, h, d), 0.012, 1)
    lathe(p, "team", T(0, 0.51, 0) @ Matrix.Rotation(math.radians(45), 4, "Y"), [(0.0, 0.0), (0.1, 0.0), (0.0, 0.12)], 4)

    def face(z):
        mbox(p, "glow", T(0, 0.27, z * 0.111), (0.06, 0.025, 0.006), 0.004, 1)
        mbox(p, "dark", T(0, 0.27, z * 0.113), (0.02, 0.02, 0.006), 0.004, 1)
    both_faces(face)


@style("hexagono")
def hexagon(p):
    """A honeycomb: hexagonal columns of three heights, each capped and lit."""
    brick_socle(p)
    cells = [(-0.15, -0.05, 0.42), (0.0, 0.04, 0.3), (0.15, -0.05, 0.36), (-0.07, 0.07, 0.22), (0.08, -0.07, 0.26), (0.21, 0.06, 0.18), (-0.21, 0.06, 0.2)]
    for x, z, h in cells:
        col = T(x, 0.09 + h / 2, z) @ Matrix.Rotation(math.radians(30), 4, "Y")
        mtube(p, "shell", col, 0.075, h, 6)
        mtube(p, "team" if h > 0.35 else "trim", sub(col, 0, h / 2 + 0.006, 0), 0.07, 0.012, 6)
        mtube(p, "glow", sub(col, 0, h / 2 + 0.014, 0), 0.03, 0.006, 6)

@style("iglu")
def igloo(p):
    """A dome of blocks with an arched doorway on each face and a lit window on top."""
    brick_socle(p)
    m = T(0, 0.1, 0) @ Matrix.Diagonal((1.0, 1.0, 0.56, 1.0))
    prof = [(0.25, 0.0)] + [(0.25 * math.cos(math.radians(a)), 0.33 * math.sin(math.radians(a))) for a in range(15, 90, 15)] + [(0.0, 0.33)]
    lathe(p, "shell", m, prof, 24, cap_bottom=True)
    for y in (0.07, 0.15, 0.23):
        r = 0.25 * math.cos(math.asin(min(y / 0.33, 1.0)))
        mring(p, "trim", sub(m, 0, y, 0), r + 0.004, 0.008, 24, 4)
    mtube(p, "team", T(0, 0.43, 0), 0.06, 0.02, 12)
    mtube(p, "glow", T(0, 0.443, 0), 0.04, 0.008, 12)

    def face(z):
        arch = axis_frame((0, 0.16, z * 0.12), "z" if z > 0 else "-z")
        mtube(p, "dark", arch, 0.06, 0.05, 14)
        mbox(p, "dark", T(0, 0.12, z * 0.125), (0.12, 0.08, 0.05), 0.005, 1)
    both_faces(face)


@style("pneus")
def tyres(p):
    """Two stacks of tyres with steel rims, the top ones in the team's colour."""
    brick_socle(p)
    for x in (-0.13, 0.13):
        for i in range(3):
            c = T(x, 0.15 + i * 0.105, 0)
            lathe(p, "team" if i == 2 else "rubber", c, [(0.06, -0.05), (0.11, -0.05), (0.13, -0.025), (0.13, 0.025),
                                                         (0.11, 0.05), (0.06, 0.05), (0.06, -0.05)], 20)
            mtube(p, "metal", c, 0.062, 0.07, 16)
            mtube(p, "dark", sub(c, 0, 0.036, 0), 0.03, 0.004, 10)
    mbox(p, "trim", T(0, 0.27, 0), (0.03, 0.3, 0.2), 0.008, 1)


@style("torre")
def tower(p):
    """A tall round castle tower: stone body, a corbelled top, battlements in the team's
    colour, a pointed roof and lit arrow slits."""
    brick_socle(p)
    body = T(0, 0.3, 0)
    mtube(p, "shell", body, 0.13, 0.42, 18)
    for y in (-0.12, 0.04):
        mring(p, "dark", sub(body, 0, y, 0), 0.131, 0.004, 18, 3)
    mtube(p, "trim", T(0, 0.535, 0), 0.155, 0.05, 18)
    for k in range(8):
        a = math.radians(k * 45)
        mbox(p, "team", T(math.cos(a) * 0.14, 0.58, math.sin(a) * 0.14), (0.045, 0.05, 0.045), 0.006, 1)
    lathe(p, "trim", T(0, 0.56, 0), [(0.0, 0.0), (0.11, 0.0), (0.0, 0.2)], 12)
    for a in (-90, 90, 0, 180):
        r = math.radians(a)
        mbox(p, "glow", T(math.cos(r) * 0.131, 0.33, math.sin(r) * 0.131), (0.02, 0.08, 0.02), 0.002, 1)
    for x in (-0.2, 0.2):
        mbox(p, "shell", T(x, 0.17, 0), (0.1, 0.15, 0.22), 0.01, 1)
        mbox(p, "team", T(x, 0.255, 0), (0.1, 0.02, 0.22), 0.004, 1)

@style("bateria")
def battery(p):
    """A charge cell lying along the wall: terminal cap, a band and lit charge bars."""
    brick_socle(p)
    cell = axis_frame((0, 0.26, 0), "x")
    mtube(p, "shell", cell, 0.14, 0.42, 22, bevel=0.012)
    mtube(p, "team", sub(cell, 0, -0.13, 0), 0.142, 0.08, 22)
    mtube(p, "metal", sub(cell, 0, 0.225, 0), 0.06, 0.03, 16, bevel=0.004)
    mtube(p, "metal", sub(cell, 0, -0.218, 0), 0.1, 0.016, 18)
    mring(p, "trim", sub(cell, 0, 0.17, 0), 0.142, 0.012, 22, 4)

    def face(z):
        for i in range(4):
            mbox(p, "glow", T(-0.06 + i * 0.055, 0.26, z * 0.122), (0.04, 0.09, 0.008), 0.004, 1)
    both_faces(face)
    for y in (0.17, 0.35):
        mbox(p, "dark", T(-0.205, y, 0), (0.03, 0.03, 0.14), 0.006, 1)


@style("neon")
def neon(p):
    """A lit orb held in three rings on a dark stand, the team's colour on the stand's rim."""
    brick_socle(p)
    lathe(p, "dark", T(0, 0.09, 0), [(0.16, 0.0), (0.12, 0.05), (0.06, 0.09), (0.0, 0.1)], 18)
    mring(p, "team", T(0, 0.1, 0), 0.15, 0.012, 22, 4)
    bm_center = (0, 0.32, 0)
    ball(p, "glow", bm_center, 0.13, 18)
    for k, rot in enumerate(((0, 0, 0), (90, 0, 0), (0, 0, 90))):
        mring(p, "trim", sub(T(*bm_center), rot=rot), 0.17, 0.01, 28, 4)
    rod(p, "metal", Vector((0, 0.18, 0)), Vector((0, 0.2, 0)), 0.03, 10)

def define():
    kit.PARTS.clear()

    def build_with_detail(fn):
        def run(q):
            global DETAIL
            DETAIL = kit.DETAIL
            fn(q)
            DETAIL = 1.0
        return run
    for name, fn in STYLES.items():
        kit.part(PREFIX + name)(build_with_detail(fn))
    kit.LOW_DETAIL[:] = [PREFIX + name for name in STYLES]


def build():
    define()
    objects = kit.build_kit()
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_yup=True, export_texcoords=True,
                              export_materials="EXPORT", export_extras=False, export_apply=True,
                              export_vertex_color="NONE")
    tris = {}
    for name, root in objects.items():
        count = 0
        for child in root.children:
            child.data.calc_loop_triangles()
            count += len(child.data.loop_triangles)
        tris[name] = count
    print("BRICKS13", tris, "bytes", OUTPUT.stat().st_size)


if __name__ == "__main__":
    build()
