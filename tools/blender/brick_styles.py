"""OFICINA brick styles: ten wall bricks bought with bricks, worn by the player's wall.

Every style stands on the common plinth of the mechanical bricks (brick_socle: dark plate,
team band, corner screws, the side joints), keeps their footprint (0.54 x 0.29) and height
(about half a unit), and leaves the plinth's faces free for the three life lights. They are
painted in the pilot's own colours (shell, trim, dark, metal, glow) with the team's colour on
top, like the themed bricks.

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
from mech_cast import T, both_faces, brick_socle, extruded  # noqa: E402
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
    """Two standing drums with steel hoops and lids in the team's colour."""
    brick_socle(p)
    for x in (-0.13, 0.13):
        drum = T(x, 0.27, 0)
        mtube(p, "shell", drum, 0.125, 0.34, 20, bevel=0.01)
        for y in (-0.12, 0.0, 0.12):
            mring(p, "metal", sub(drum, 0, y, 0), 0.126, 0.01, 22, 4)
        mtube(p, "team", sub(drum, 0, 0.175, 0), 0.11, 0.012, 18)
        mtube(p, "dark", sub(drum, 0.05, 0.18, 0.0), 0.02, 0.012, 8)
    mbox(p, "trim", T(0, 0.27, 0), (0.06, 0.06, 0.2), 0.01, 1)


@style("cristal")
def crystals(p):
    """A cluster of lit crystal prisms out of a dark rock."""
    brick_socle(p)
    mbox(p, "dark", T(0, 0.13, 0), (0.48, 0.07, 0.25), 0.03, 1)
    shards = [(0.0, 0.0, 0.42, 0.075, 0.0), (-0.14, 0.03, 0.3, 0.06, -18), (0.14, -0.03, 0.32, 0.06, 16),
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
    for i, (w, d, h) in enumerate(((0.5, 0.27, 0.11), (0.38, 0.22, 0.1), (0.26, 0.17, 0.1))):
        mbox(p, "shell" if i % 2 == 0 else "trim", T(0, 0.15 + i * 0.105, 0), (w, h, d), 0.012, 1)
    lathe(p, "team", T(0, 0.405, 0) @ Matrix.Rotation(math.radians(45), 4, "Y"), [(0.0, 0.0), (0.11, 0.0), (0.0, 0.1)], 4)

    def face(z):
        mbox(p, "glow", T(0, 0.27, z * 0.111), (0.06, 0.025, 0.006), 0.004, 1)
        mbox(p, "dark", T(0, 0.27, z * 0.113), (0.02, 0.02, 0.006), 0.004, 1)
    both_faces(face)


@style("hexagono")
def hexagon(p):
    """A hexagonal column laid along the wall, with lit honeycomb edges and capped ends."""
    brick_socle(p)
    hexa = axis_frame((0, 0.27, 0), "x")
    mtube(p, "shell", hexa @ Matrix.Rotation(math.radians(30), 4, "Y"), 0.17, 0.46, 6)
    for x in (-0.235, 0.235):
        cap = axis_frame((x, 0.27, 0), "x" if x > 0 else "-x") @ Matrix.Rotation(math.radians(30), 4, "Y")
        mtube(p, "team", cap, 0.15, 0.02, 6)
        mtube(p, "glow", sub(cap, 0, 0.012, 0), 0.06, 0.006, 6)
    for k in range(6):
        a = math.radians(k * 60)
        y, z = 0.27 + math.sin(a) * 0.168, math.cos(a) * 0.168 * 0.84
        if abs(z) < 0.15:
            rod(p, "trim", Vector((-0.2, y, z)), Vector((0.2, y, z)), 0.007, 6)


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
    """A castle tower: stone body, battlements in the team's colour and lit arrow slits."""
    brick_socle(p)
    mbox(p, "shell", T(0, 0.25, 0), (0.48, 0.3, 0.25), 0.012, 1)
    mbox(p, "trim", T(0, 0.405, 0), (0.52, 0.03, 0.28), 0.008, 1)
    for x in (-0.2, -0.067, 0.067, 0.2):
        mbox(p, "team", T(x, 0.45, 0), (0.08, 0.06, 0.26), 0.008, 1)

    def face(z):
        for x in (-0.12, 0.12):
            mbox(p, "glow", T(x, 0.27, z * 0.126), (0.02, 0.09, 0.006), 0.002, 1)
        for y in (0.17, 0.33):
            mbox(p, "dark", T(0, y, z * 0.126), (0.46, 0.006, 0.004), 0.0, 1)
    both_faces(face)


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
    """A dark block in a cage of lit edges, the team's colour along the top edges."""
    brick_socle(p)
    mbox(p, "dark", T(0, 0.27, 0), (0.46, 0.32, 0.24), 0.02, 1)
    w, h, d = 0.48, 0.34, 0.26
    y0, y1 = 0.27 - h / 2, 0.27 + h / 2
    for x in (-w / 2, w / 2):
        for z in (-d / 2, d / 2):
            rod(p, "glow", Vector((x, y0, z)), Vector((x, y1, z)), 0.012, 6)
    for y, role in ((y0, "glow"), (y1, "team")):
        for z in (-d / 2, d / 2):
            rod(p, role, Vector((-w / 2, y, z)), Vector((w / 2, y, z)), 0.012, 6)
        for x in (-w / 2, w / 2):
            rod(p, role, Vector((x, y, -d / 2)), Vector((x, y, d / 2)), 0.012, 6)

    def face(z):
        extruded(p, "glow", T(0, 0.27, z * 0.122), [(-0.05, 0.0), (0.0, 0.08), (0.05, 0.0), (0.0, -0.08)], 0.006)
    both_faces(face)


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
