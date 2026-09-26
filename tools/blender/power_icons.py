"""Os ícones dos poderes, modelados e renderizados no Blender, com o mesmo aspeto de borracha
dos robôs e da Ilha Jardim: cada poder é um objeto (uma bomba, um íman, um floco de gelo...)
em creme e cor, pousado num disco gordo na cor do poder, com a luz suave do render.

    python3 tools/blender/power_icons.py [amostras] [ids...]   # escreve art/ui/powers/<id>.png

Coordenadas como no kit dos robôs (tools/blender/robot_kit.py): unidades do Godot, Y para
cima, a câmara olha de -Z (a frente do objeto). O disco tem raio 1.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import robot_kit as rk  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "ui" / "powers"
SIZE = 256
CREAM = "fff4e2"
DARK = "2a3140"
ORANGE = "ff7a3c"
# The colour of every power, as in scripts/powers.gd, a little deeper so the disc reads.
COLORS = {
    "blast": "ff9a4d", "rapid": "ffcf3d", "air": "4fc8f0", "ghost": "a57cff", "laser": "ff4f6a",
    "rebuild": "6fd35a", "mirror": "3fd0e8", "walls": "c9b94a", "stun": "5fb8ff", "weld": "3fcf8e",
    "thorns": "d77cff", "freeze": "6fc0ff", "magnet": "ffb82e", "pierce": "ff7a52",
    "sun_ray": "ffc82e", "meteors": "9f7cff", "thunder": "3fc8f0", "singularity": "ff3f5a",
    "sentries": "ff8a3d", "bloom": "6fd35a", "plunder": "ffb52e", "surge": "ff4fb8",
    "volley": "ff7a3c", "plating": "ffb81a",
}
ICONS = {}


def icon(name):
    def register(fn):
        ICONS[name] = fn
        return fn
    return register


# --- the objects ------------------------------------------------------------------------
# Roles: "shell" cream, "team" the power's colour, "trim" orange, "dark", "metal", "glow"
# (lit from inside), "label" a deeper shade of the power's colour.

@icon("blast")
def _(p):
    p.ball("dark", (0.05, -0.1, -0.3), (0.95, 0.95, 0.95), detail=32)
    p.ball("shell", (-0.18, 0.1, -0.72), (0.26, 0.2, 0.1), detail=16)
    p.tube("metal", (0.2, 0.4, -0.3), 0.14, 0.2, rot=(0, 0, -30), bevel=0.03)
    p.path("shell", [(0.25, 0.48, -0.3), (0.38, 0.62, -0.3), (0.52, 0.6, -0.35)], [0.035, 0.035, 0.035])
    p.ball("glow", (0.55, 0.62, -0.38), (0.2, 0.2, 0.2))
    for a in range(5):
        ang = math.radians(20 + a * 22)
        at = (0.55 + 0.2 * math.cos(ang), 0.62 + 0.2 * math.sin(ang), -0.4)
        p.ball("trim", at, (0.07, 0.07, 0.07), detail=8)


@icon("rapid")
def _(p):
    for i, x in enumerate((-0.42, 0.0, 0.42)):
        y = -0.05 + (0.08 if i == 1 else 0.0)
        p.tube("trim", (x, y - 0.25, -0.35), 0.16, 0.34, bevel=0.03)
        p.tube("dark", (x, y - 0.06, -0.35), 0.165, 0.05)
        p.tube("shell", (x, y + 0.14, -0.35), 0.16, 0.34)
        p.ball("shell", (x, y + 0.31, -0.35), (0.32, 0.4, 0.32))


@icon("air")
def _(p):
    for i in range(5):
        ang = math.radians(50 + i * 20)
        tip = Vector((math.cos(ang) * 0.62, math.sin(ang) * 0.62 - 0.35, -0.35))
        base = Vector((0, -0.45, -0.35))
        p.strut("label", base + (tip - base) * 0.25, tip - (tip - base) * 0.12, 0.04, radius2=0.075)
        p.ball("shell", tuple(tip), (0.24, 0.24, 0.24))
    p.ball("team", (0, -0.5, -0.35), (0.34, 0.26, 0.26))


@icon("ghost")
def _(p):
    p.ball("shell", (0, 0.2, -0.35), (0.92, 0.92, 0.7), detail=32)
    p.tube("shell", (0, -0.12, -0.35), 0.46, 0.62, detail=32)
    for x in (-0.3, 0.0, 0.3):
        p.ball("shell", (x, -0.44, -0.35), (0.32, 0.32, 0.34))
    for x in (-0.17, 0.17):
        p.ball("dark", (x, 0.18, -0.64), (0.17, 0.24, 0.1))
    p.ball("label", (0, -0.03, -0.66), (0.14, 0.1, 0.06))


@icon("laser")
def _(p):
    # The emitter low on the left, the beam up to a wall and bouncing off it.
    p.tube("shell", (-0.5, -0.5, -0.35), 0.22, 0.42, rot=(0, 0, 40), bevel=0.08)
    p.tube("dark", (-0.36, -0.34, -0.35), 0.15, 0.12, rot=(0, 0, 40))
    p.strut("beam", (-0.3, -0.28, -0.35), (0.12, 0.44, -0.35), 0.075)
    p.strut("beam", (0.12, 0.44, -0.35), (0.6, -0.1, -0.35), 0.075)
    p.ball("beam", (0.12, 0.44, -0.35), (0.24, 0.24, 0.24))
    p.box("shell", (0.12, 0.62, -0.3), (0.72, 0.14, 0.3), radius=0.06)


def brick(p, at, scale=1.0, team="team"):
    x, y, z = at
    p.box(team, (x, y, z), (0.46 * scale, 0.26 * scale, 0.32 * scale), radius=0.07 * scale)
    p.box("shell", (x, y + 0.17 * scale, z), (0.4 * scale, 0.08 * scale, 0.27 * scale), radius=0.04 * scale)


@icon("rebuild")
def _(p):
    brick(p, (-0.26, -0.42, -0.3))
    brick(p, (0.26, -0.42, -0.3))
    brick(p, (0.0, -0.05, -0.3))
    p.path("trim", [(-0.55, 0.05, -0.55), (-0.5, 0.42, -0.55), (-0.2, 0.6, -0.55), (0.2, 0.58, -0.55), (0.45, 0.42, -0.55)],
           [0.06, 0.06, 0.06, 0.06, 0.06])
    p.wedge("trim", (0.5, 0.35, -0.55), (0.28, 0.26, 0.12), rot=(0, 0, -135), taper=0.0, radius=0.02)


@icon("mirror")
def _(p):
    p.ball("shell", (0, 0.08, -0.3), (1.08, 1.2, 0.36), detail=32)
    p.wedge("shell", (0, -0.4, -0.3), (0.76, 0.5, 0.36), rot=(0, 0, 180), taper=0.1, radius=0.08)
    p.ball("glow", (0, 0.02, -0.46), (0.62, 0.72, 0.1), detail=32)
    p.ball("shell", (-0.12, 0.2, -0.53), (0.14, 0.2, 0.04))


@icon("walls")
def _(p):
    for row, y in enumerate((-0.42, -0.1)):
        for i in range(3 if row == 0 else 2):
            x = (i - (1 if row == 0 else 0.5)) * 0.48
            p.box("shell", (x, y, -0.3), (0.44, 0.28, 0.4), radius=0.07)
    for x in (-0.42, 0.0, 0.42):
        p.box("team", (x, 0.2, -0.3), (0.24, 0.26, 0.4), radius=0.06)


def prism(p, role, points, depth, z=-0.35, bevel=0.04):
    """A flat shape (points in the XY plane, anticlockwise) pushed out `depth` towards the
    camera, its edges rounded: bolts, arrowheads."""
    bm = rk.bmesh.new()
    back = [bm.verts.new((x, y, depth / 2)) for x, y in points]
    front = [bm.verts.new((x, y, -depth / 2)) for x, y in points]
    bm.faces.new(back)
    bm.faces.new(list(reversed(front)))
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[j], back[i], front[i], front[j]))
    rk.bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        rk.bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=3, profile=0.5, affect="EDGES", clamp_overlap=True)
    p.add(role, bm, rk.xform((0, 0, z)))


def bolt(p, role, scale=1.0, at=(0, 0, -0.35)):
    x, y, _z = at
    shape = [(0.12, 0.62), (-0.34, -0.04), (-0.04, -0.04), (-0.16, -0.62), (0.34, 0.06), (0.04, 0.06)]
    prism(p, role, [(x + a * scale, y + b * scale) for a, b in shape], 0.24 * scale, at[2], 0.035 * scale)


def arrow_head(p, role, tip, direction, size=0.3, z=-0.35):
    d = Vector((direction[0], direction[1])).normalized()
    n = Vector((-d.y, d.x))
    t = Vector(tip)
    base = t - d * size
    prism(p, role, [tuple(t), tuple(base + n * size * 0.62), tuple(base - n * size * 0.62)], 0.18, z, 0.03)


@icon("stun")
def _(p):
    p.ring("label", (0, 0, -0.3), 0.66, 0.05, rot=(90, 0, 0), detail=40)
    bolt(p, "shell", 1.0, (0, 0, -0.42))


@icon("weld")
def _(p):
    p.strut("shell", (-0.5, -0.5, -0.35), (0.22, 0.22, -0.35), 0.13)
    p.ball("shell", (-0.5, -0.5, -0.35), (0.28, 0.28, 0.28))
    p.ring("shell", (0.34, 0.34, -0.35), 0.24, 0.1, rot=(90, 0, 0), detail=24, sides=10)
    p.box("team", (0.48, 0.48, -0.35), (0.22, 0.3, 0.3), radius=0.04, rot=(0, 0, -45))
    for a in range(4):
        ang = math.radians(200 + a * 30)
        p.ball("glow", (-0.1 + 0.3 * math.cos(ang), 0.3 + 0.3 * math.sin(ang) * 0.5 + 0.25, -0.5), (0.09, 0.09, 0.09), detail=8)


@icon("thorns")
def _(p):
    p.box("shell", (0, -0.42, -0.3), (1.3, 0.3, 0.46), radius=0.1)
    for x, h in ((-0.46, 0.5), (-0.16, 0.66), (0.16, 0.66), (0.46, 0.5)):
        p.tube("team", (x, -0.27 + h / 2, -0.3), 0.15, h, radius2=0.0, detail=16)
    p.ball("label", (0, -0.42, -0.54), (0.9, 0.08, 0.04))


@icon("freeze")
def _(p):
    for k in range(3):
        a = k * 60
        p.box("shell", (0, 0, -0.35), (1.3, 0.14, 0.18), radius=0.06, rot=(0, 0, a))
        for side in (-1, 1):
            ang = math.radians(a) + (0 if side > 0 else math.pi)
            tip = (math.cos(ang) * 0.62, math.sin(ang) * 0.62, -0.35)
            p.ball("team", tip, (0.2, 0.2, 0.2))
            for turn in (-40, 40):
                mid = (math.cos(ang) * 0.38, math.sin(ang) * 0.38, -0.35)
                end = (mid[0] + math.cos(ang + math.radians(turn)) * 0.18, mid[1] + math.sin(ang + math.radians(turn)) * 0.18, -0.35)
                p.strut("shell", mid, end, 0.05)
    p.ball("team", (0, 0, -0.45), (0.3, 0.3, 0.2))


@icon("magnet")
def _(p):
    pts, radii = [], []
    for i in range(13):
        a = math.pi * i / 12
        pts.append((math.cos(a) * 0.4, 0.05 + math.sin(a) * 0.4, -0.35))
        radii.append(0.16)
    p.path("team", pts, radii, detail=16)
    for x in (-0.4, 0.4):
        p.tube("team", (x, -0.14, -0.35), 0.16, 0.38)
        p.tube("shell", (x, -0.43, -0.35), 0.165, 0.22, bevel=0.03)
    for x in (-0.66, 0.66):
        p.path("glow", [(x, -0.2, -0.35), (x * 1.18, -0.02, -0.35)], [0.03, 0.03])


@icon("pierce")
def _(p):
    p.tube("shell", (0, 0.1, -0.35), 0.3, 0.82, radius2=0.02, detail=24)
    for i in range(4):
        p.ring("label", (0, -0.12 + i * 0.16, -0.35), 0.26 - i * 0.055, 0.035, rot=(0, i * 20, 8))
    p.tube("dark", (0, -0.38, -0.35), 0.24, 0.16, bevel=0.03)
    p.tube("team", (0, -0.55, -0.35), 0.3, 0.2, bevel=0.05)
    brick(p, (-0.56, 0.3, -0.25), 0.7, "label")
    brick(p, (0.56, 0.3, -0.25), 0.7, "label")


@icon("sun_ray")
def _(p):
    for k in range(10):
        ang = math.radians(k * 36 + 18)
        p.wedge("team" if k % 2 else "shell", (math.cos(ang) * 0.6, math.sin(ang) * 0.6, -0.3), (0.2, 0.3, 0.16),
                rot=(0, 0, math.degrees(ang) - 90), taper=0.0, radius=0.02)
    p.ball("shell", (0, 0, -0.35), (0.84, 0.84, 0.6), detail=32)
    for x in (-0.14, 0.14):
        p.ball("dark", (x, 0.06, -0.62), (0.1, 0.14, 0.06))
    p.ring("dark", (0, -0.09, -0.62), 0.13, 0.025, rot=(90, 0, 0), detail=16)


@icon("meteors")
def _(p):
    for at, s in (((0.28, 0.22, -0.4), 0.55), ((-0.38, -0.34, -0.35), 0.3), ((-0.32, 0.44, -0.35), 0.24)):
        x, y, z = at
        p.strut("glow", (x + 0.5 * s, y + 0.6 * s, z + 0.05), (x, y, z + 0.05), 0.02, radius2=0.2 * s)
        p.ball("shell", at, (s, s * 0.92, s), detail=10)
        p.ball("label", (x + 0.08 * s, y - 0.1 * s, z - 0.3 * s), (0.25 * s, 0.25 * s, 0.1 * s), detail=8)


@icon("thunder")
def _(p):
    for at, s in (((-0.3, 0.35, -0.3), 0.55), ((0.1, 0.45, -0.3), 0.65), ((0.42, 0.3, -0.3), 0.5), ((0.05, 0.22, -0.35), 0.6)):
        p.ball("shell", at, (s, s * 0.8, s * 0.8))
    bolt(p, "glow", 0.7, (0.02, -0.3, -0.5))


@icon("singularity")
def _(p):
    for i, (major, tilt) in enumerate(((0.7, 70), (0.52, 60), (0.36, 50))):
        p.ring("team" if i % 2 == 0 else "shell", (0, 0, -0.3), major, 0.06, rot=(tilt, 0, 15 + i * 25), detail=40, sides=8)
    p.ball("dark", (0, 0, -0.3), (0.42, 0.42, 0.42), detail=24)
    p.ball("glow", (0.08, 0.08, -0.5), (0.1, 0.1, 0.06))


@icon("sentries")
def _(p):
    p.tube("dark", (0, -0.52, -0.3), 0.42, 0.14, bevel=0.04)
    p.tube("shell", (0, -0.36, -0.3), 0.18, 0.3)
    p.ball("shell", (0, 0.02, -0.3), (0.72, 0.62, 0.62), detail=24)
    p.box("team", (0, 0.02, -0.64), (0.4, 0.18, 0.08), radius=0.04)
    for x in (-0.12, 0.12):
        p.tube("metal", (x + 0.36, 0.1, -0.3), 0.07, 0.62, rot=(0, 0, -90))
        p.ball("glow", (x + 0.68, 0.1, -0.3), (0.12, 0.12, 0.12))


@icon("bloom")
def _(p):
    p.strut("label", (0, -0.7, -0.3), (0, -0.1, -0.3), 0.06)
    p.ball("label", (-0.2, -0.45, -0.3), (0.3, 0.12, 0.16))
    for k in range(6):
        ang = math.radians(k * 60 + 90)
        p.ball("shell", (math.cos(ang) * 0.32, 0.15 + math.sin(ang) * 0.32, -0.32), (0.36, 0.36, 0.22))
    p.ball("trim", (0, 0.15, -0.42), (0.34, 0.34, 0.22))


@icon("plunder")
def _(p):
    # Two walls trading places: a cream arrow over the top, a coloured one under the bottom.
    for side, role in ((1, "shell"), (-1, "trim")):
        pts = []
        for i in range(9):
            a = math.radians(160 - i * 17.5) if side > 0 else math.radians(-20 - i * 17.5)
            pts.append((math.cos(a) * 0.56, math.sin(a) * 0.5, -0.35))
        p.path(role, pts[:-1], [0.08] * 8)
        last, before = pts[-1], pts[-3]
        arrow_head(p, role, (last[0], last[1]), (last[0] - before[0], last[1] - before[1]), 0.3)
    brick(p, (0, -0.05, -0.3), 0.9, "label")


@icon("surge")
def _(p):
    p.box("shell", (0, -0.08, -0.3), (0.72, 1.0, 0.44), radius=0.16)
    p.box("dark", (0, 0.48, -0.3), (0.3, 0.14, 0.26), radius=0.05)
    p.box("team", (0, -0.28, -0.3), (0.62, 0.5, 0.46), radius=0.12)
    bolt(p, "dark", 0.42, (0, 0.02, -0.56))


@icon("volley")
def _(p):
    p.tube("shell", (0, -0.2, -0.3), 0.3, 0.8, radius2=0.2, detail=24)
    for y in (-0.42, -0.1):
        p.tube("team", (0, y, -0.3), 0.29 - (y + 0.42) * 0.12, 0.12, detail=24)
    p.tube("dark", (0, 0.22, -0.3), 0.26, 0.06)
    p.ball("glow", (0, 0.36, -0.3), (0.34, 0.3, 0.34))
    p.ball("team", (0, 0.56, -0.3), (0.38, 0.2, 0.38))
    for side in (-1, 1):
        p.strut("glow", (side * 0.2, 0.36, -0.3), (side * 0.7, 0.5, -0.3), 0.03, radius2=0.1)
    p.tube("dark", (0, -0.64, -0.3), 0.4, 0.1)


@icon("plating")
def _(p):
    p.ball("shell", (0, 0.04, -0.35), (0.9, 1.2, 0.6), detail=6)
    p.ball("team", (0, 0.04, -0.4), (0.62, 0.84, 0.5), detail=6)
    p.ball("glow", (-0.1, 0.2, -0.62), (0.1, 0.16, 0.05))


# --- scene ------------------------------------------------------------------------------
def disc(p):
    """The fat rubber coin every icon stands on, facing the camera."""
    p.tube("disc", (0, 0, 0.05), 0.92, 0.3, rot=(90, 0, 0), detail=48, bevel=0.1)
    p.ring("rim", (0, 0, -0.1), 0.9, 0.07, rot=(90, 0, 0), detail=48, sides=10)


def shade(hex_value, k):
    c = rk.hex_rgb(hex_value)
    return tuple(max(0.0, min(1.0, v * k)) for v in c)


def materials(color):
    base = rk.hex_rgb(color)
    table = {
        "shell": (rk.hex_rgb(CREAM), 0.42, 0.0, 0.0),
        "team": (base, 0.4, 0.0, 0.0),
        "label": (shade(color, 0.62), 0.45, 0.0, 0.0),
        "disc": (base, 0.5, 0.0, 0.0),
        "rim": (shade(color, 0.55), 0.45, 0.0, 0.0),
        "trim": (rk.hex_rgb(ORANGE), 0.42, 0.0, 0.0),
        "dark": (rk.hex_rgb(DARK), 0.4, 0.1, 0.0),
        "metal": ((0.62, 0.66, 0.72), 0.3, 0.8, 0.0),
        "glow": (tuple(min(1.0, v * 0.6 + 0.4) for v in base), 0.3, 0.0, 3.0),
        "beam": (base, 0.3, 0.0, 1.6),
    }
    mats = {}
    for role, (col, rough, metal, glow) in table.items():
        mat = bpy.data.materials.new(role)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*col, 1)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if glow > 0:
            bsdf.inputs["Emission Color"].default_value = (*col, 1)
            bsdf.inputs["Emission Strength"].default_value = glow
        mats[role] = mat
    return mats


def stage():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.78, 0.84, 0.9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.75
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 2.6
    sun.data.angle = math.radians(14)
    # Blender space: the front of the icon is +Y. Light from the upper left, in front.
    sun.rotation_euler = Vector((0, 0, -1)).rotation_difference(Vector((0.55, -1.0, -1.0)).normalized()).to_euler()
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.16
    cam.location = (0, 8, 0.9)
    # Looking along -Y with +Z up, a touch from above.
    cam.rotation_euler = (math.radians(90) - math.atan2(0.9, 8), 0, math.radians(180))
    scene.collection.objects.link(cam)
    scene.camera = cam


def render(name, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rk.reset()
    stage()
    bpy.context.scene.cycles.samples = samples
    mats = materials(COLORS[name])
    p = rk.Part("icon_" + name)
    disc(p)
    ICONS[name](p)
    for role, me in p.meshes.items():
        me.materials.append(mats.get(role) or mats["shell"])
        obj = bpy.data.objects.new(me.name, me)
        # Seen from the front, Godot's +X falls on the camera's left: mirror it back.
        obj.scale.x = -1
        bpy.context.scene.collection.objects.link(obj)
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(OUT / (name + ".png"))
    bpy.ops.render.render(write_still=True)
    print("ICON", name)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    samples = int(args[0]) if args else 64
    for name in (args[1:] or list(ICONS)):
        render(name, samples)
