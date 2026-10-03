"""ECLIPSE: the original E8 executor body, improved with the new orbital villain head.

Original chest, shoulders, claw and greaves are authored in mech_cast. The new optical
head is adjusted to the original collar; a closed hip shield removes the rejected U.
Godot coordinates: Y up, front -Z. This module registers geometry only.
"""
import math
import bmesh
from mathutils import Matrix, Vector
import mech_kit as mk
import mech_parts as mp
import mech_cast as mc

DESIGN = {
    "parts": {"head": "eclipse12_head", "torso": "eclipse12_torso",
              "shoulders": "eclipse12_shoulders", "arm": "eclipse12_arm",
              "gun": "eclipse12_gun", "legs": "eclipse12_leg",
              "top": "", "back": "", "spin": ""},
    "hip": [0.20, 0.88, 0.0], "muzzle": [0.52, 1.0, -1.12],
    "scale": [1.0, 1.0, 1.0], "eye_style": "visor", "mouth": False,
    "wear": .25,
    "palette": {"shell": "3c3b51", "trim": "aea1be", "dark": "14151c",
                "metal": "7e8096", "glow": "b95cff", "team": "",
                "screen": "070b14", "rubber": "101014", "hazard": "c78c57",
                "label": "c8c0d6", "eyes": "ff315d"},
    "design_note": "Vilão executor no desenho original: peito em cunha e núcleo eclipse "
                   "violeta, gola alta, ombreiras maciças, garra e grevas angulosas. "
                   "Cabeça orbital nova ajustada à gola, com pala e visor rubro estreito; "
                   "bacia sólida compacta e acabamento metálico mais definido.",
}
# The orbital head is built in its authored frame and lowered .265 m after construction.
HEAD = Vector((0, 2.105, -.022))


def T(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


def panel(p, role, location, size, angle=(0, 0, 0), radius=.012, taper=None):
    mk.mbox(p, role, mk.sub(T(*location), rot=angle), size, radius, 1, taper=taper)


def shield(p, role, points, z, depth):
    """Solid extruded armour with a designed outline, never a U-shaped cut-out."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y, z-depth/2)) for x, y in points]
    back = [bm.verts.new((x, y, z+depth/2)) for x, y in points]
    bm.faces.new(tuple(reversed(front)))
    bm.faces.new(back)
    for i in range(len(points)):
        j = (i+1) % len(points)
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=.004, segments=1,
                    profile=.5, affect="EDGES", clamp_overlap=True)
    p.add(role, bm, Matrix.Identity(4))


def bearing(p, at, out, radius=.052, width=.14):
    m = mk.axis_frame(at, "x" if out > 0 else "-x")
    mk.mtube(p, "dark", m, radius, width, 12)
    cap = mk.sub(m, 0, width*.5+.005, 0)
    mk.mtube(p, "metal", cap, radius*.76, .012, 12)
    mk.mtube(p, "dark", mk.sub(cap, 0, .009, 0), radius*.32, .012, 8)
    mk.bolts(p, mk.sub(cap, 0, .009, 0), radius*.84, 4, size=.007)


def finish(p):
    for role in ("shell", "trim", "dark", "rubber", "team"):
        if role in p.meshes:
            for polygon in p.meshes[role].polygons:
                polygon.use_smooth = False


def eclipse12_head(p):
    mk.HEADS["eclipse12_head"] = {"top": 2.013, "center": 1.84, "aspect": 4.889}
    # A compact circular optical sensor replaces the square helmet and jaw.
    face = mk.axis_frame(HEAD, "-z")
    mk.mtube(p, "dark", face, .149, .151, 24)
    mk.mring(p, "trim", mk.sub(face, 0, .070, 0), .148, .023, 24, 5)
    mk.mring(p, "glow", mk.sub(face, 0, .091, 0), .142, .007, 32, 5)
    mk.mtube(p, "dark", mk.sub(face, 0, .075, 0), .127, .038, 24)
    # A narrow rubro-magenta slit and an angular hood keep this a villain, not a cute eye.
    p.screen((0, HEAD.y, HEAD.z-.116), (.176, .036), bulge=.002)
    shield(p, "shell", [(-.129, 2.162), (-.011, 2.133), (-.011, 2.121),
                        (-.123, 2.140)], HEAD.z-.139, .015)
    shield(p, "shell", [(.129, 2.162), (.011, 2.133), (.011, 2.121),
                        (.123, 2.140)], HEAD.z-.139, .015)
    # Four retaining clamps attach the optical casing to the support bearing.
    for degree in (45, 135, 225, 315):
        a = math.radians(degree)
        x, y = math.cos(a)*.154, math.sin(a)*.154
        mk.mbox(p, "metal", mk.sub(face, x, .082, y, rot=(0, -degree, 0)),
                (.037, .024, .027), .004, 1)
    bearing(p, (0, 1.948, .012), 1, radius=.052, width=.146)
    for out in (-1, 1):
        mk.rod(p, "dark", (out*.058, 1.95, .020), (out*.087, 2.047, .025), .025, 10)
        panel(p, "trim", (out*.092, 2.032, .062), (.018, .096, .065), radius=.006)
    panel(p, "team", (0, 2.267, -.014), (.011, .01, .072), radius=.002)
    finish(p)
    # Match the original executor collar: Godot Y is Blender Z.
    for mesh in p.meshes.values():
        for vertex in mesh.vertices:
            vertex.co.z -= .265


def eclipse12_torso(p):
    mc.eclipse8_torso(p)
    mc.eclipse8_torso_detail(p)
    # Restrained reactor retention ring and a solid compact central hip shield.
    mk.mring(p, "metal", mk.axis_frame((0, 1.37, -.251), "-z"), .121, .006, 24, 4)
    shield(p, "shell", [(-.156, .973), (.156, .973), (.132, .881),
                        (.055, .788), (-.055, .788), (-.132, .881)], -.160, .042)
    shield(p, "trim", [(-.107, .97), (.107, .97), (.093, .941),
                       (-.093, .941)], -.186, .009)


def eclipse12_shoulders(p):
    mc.eclipse8_shoulders(p)
    mc.eclipse8_shoulders_detail(p)


def eclipse12_arm(p):
    mc.eclipse8_arm(p)
    mc.eclipse8_arm_detail(p)


def eclipse12_gun(p):
    mc.eclipse8_gun(p)
    m = mk.frame(mc.E8["elbow_r"], mc.E8["muzzle"]-mc.E8["elbow_r"], front=(0, 1, 0))
    length = (mc.E8["muzzle"]-mc.E8["elbow_r"]).length
    mk.mring(p, "metal", mk.sub(m, 0, length-.049, 0), .104, .006, 20, 4)


def eclipse12_leg(p, out):
    mc.eclipse8_leg(p, out)
    mc.eclipse8_leg_detail(p, out)
    # The original knee axle lies here; preserve it in the animation split metadata.
    mp.LAST_KNEE = -.4


def define(part):
    for suffix in ("head", "torso", "shoulders", "arm", "gun"):
        part("eclipse12_"+suffix)(globals()["eclipse12_"+suffix])
    part("eclipse12_leg")(lambda p: eclipse12_leg(p, 1))
    part("eclipse12_leg_l")(lambda p: eclipse12_leg(p, -1))
    part("eclipse12_leg_r")(lambda p: eclipse12_leg(p, 1))
