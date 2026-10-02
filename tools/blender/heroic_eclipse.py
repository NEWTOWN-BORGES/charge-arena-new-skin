"""ECLIPSE 12: slender orbital sentinel made from real Blender geometry.

A circular cyclopean sensor, tapered chest shield, asymmetric shoulder equipment and
long articulated legs distinguish this silhouette from the engineer and sound brawler.
Coordinates: Godot Y-up, front -Z. Legs are local to the hip pivots in DESIGN.
"""
import math

import bmesh
from mathutils import Matrix, Vector

import mech_kit as mk
import mech_parts as mp


DESIGN = {
    "parts": {"head": "eclipse12_head", "torso": "eclipse12_torso",
              "shoulders": "eclipse12_shoulders", "arm": "eclipse12_arm",
              "gun": "eclipse12_gun", "legs": "eclipse12_leg",
              "top": "", "back": "", "spin": ""},
    "hip": [0.195, 0.96, 0.0],
    "muzzle": [0.40, 1.23, -1.13],
    "scale": [1.0, 1.0, 1.0],
    "eye_style": "visor", "mouth": False,
    "palette": {"shell": "2c2c43", "trim": "695280", "dark": "101621",
                "metal": "9da9bd", "glow": "ad46ee", "team": "",
                "screen": "070b14", "rubber": "090e15", "hazard": "deac53",
                "label": "bfc7db", "eyes": "ff3164"},
    "design_note": "Vilão orbital alto e esguio: sensor circular negro com olhar rubro "
                   "estreito, pala angular, núcleo abissal violeta, escudo peitoral em ponta, "
                   "ombros assimétricos e pernas longas articuladas.",
}
HEAD = Vector((0, 2.105, -.022))
ELBOW_L = Vector((-.425, 1.485, .02))
ELBOW_R = Vector((.425, 1.485, -.01))
WRIST_L = Vector((-.466, 1.13, -.10))
MUZZLE = Vector(DESIGN["muzzle"])
HIP = Vector(DESIGN["hip"])


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
    mk.HEADS["eclipse12_head"] = {"top": 2.278, "center": 2.105, "aspect": 4.889}
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


def eclipse12_torso(p):
    panel(p, "dark", (0, 1.685, .034), (.336, .405, .266), radius=.022,
          taper=(1.20, 1.0))
    # A single tall tapered shield replaces the shared rectangular chest recipe.
    outline = [(-.242, 1.887), (.242, 1.887), (.211, 1.631), (.069, 1.430),
               (-.069, 1.430), (-.211, 1.631)]
    shield(p, "shell", outline, -.136, .056)
    shield(p, "trim", [(-.227, 1.889), (.227, 1.889), (.19, 1.846),
                        (-.19, 1.846)], -.176, .014)
    core = mk.axis_frame((0, 1.707, -.185), "-z")
    mk.mtube(p, "dark", core, .121, .049, 24)
    mk.mring(p, "metal", mk.sub(core, 0, .028, 0), .119, .011, 24, 4)
    mk.mring(p, "glow", mk.sub(core, 0, .036, 0), .10, .008, 32, 5)
    mk.mtube(p, "dark", mk.sub(core, 0, .045, 0), .079, .019, 24)
    for degree in (0, 120, 240):
        a = math.radians(degree)
        x, y = math.cos(a)*.124, math.sin(a)*.124
        mk.mbox(p, "trim", mk.sub(core, x, .032, y, rot=(0, -degree, 0)),
                (.037, .017, .026), .004, 1)
    mp.neck(p, 1.888, 1.944, radius=.052, z=.015, plate=(.157, .144))
    # Fine yaw spindle with a V of oblique plates; no generic accordion waist.
    mk.mtube(p, "dark", T(0, 1.245, .018), .048, .338, 12)
    mk.mring(p, "metal", T(0, 1.40, .018), .072, .009, 16, 4)
    for out in (-1, 1):
        mk.piston(p, (out*.084, 1.049, .068), (out*.111, 1.408, .07), .014)
        panel(p, "trim", (out*.071, 1.252, -.056), (.036, .242, .042),
              angle=(0, 0, -out*16), radius=.007)
    panel(p, "shell", (0, 1.404, -.087), (.141, .039, .061), radius=.008)
    # Closed compact hip shield; broad top and pointed bottom, no U or cyan crossbar.
    panel(p, "dark", (0, .982, .005), (.263, .14, .214), radius=.016)
    shield(p, "shell", [(-.137, 1.051), (.137, 1.051), (.113, .957),
                        (.052, .862), (-.052, .862), (-.113, .957)], -.13, .039)
    shield(p, "trim", [(-.103, 1.051), (.103, 1.051), (.083, 1.017),
                       (-.083, 1.017)], -.154, .012)
    for out in (-1, 1):
        mk.mtube(p, "metal", mk.axis_frame((out*.158, HIP.y, 0), "x"), .039, .109, 12)
    # Dorsal orbital hardware is restrained and mounted to a real back frame.
    for out in (-1, 1):
        mk.rod(p, "dark", (out*.088, 1.564, .177), (out*.135, 1.823, .255), .019, 10)
    orbit = mk.axis_frame((0, 1.787, .261), "z")
    mk.mring(p, "trim", orbit, .194, .018, 24, 5)
    mk.mring(p, "glow", mk.sub(orbit, 0, .009, 0), .194, .005, 32, 4)
    panel(p, "dark", (0, 1.724, .199), (.087, .269, .046), radius=.01)
    finish(p)


def eclipse12_shoulders(p):
    for out, elbow in ((-1, ELBOW_L), (1, ELBOW_R)):
        start = Vector((out*.319, 1.795, .015))
        bearing(p, start, out, radius=.067, width=.097)
        mk.rod(p, "dark", start, elbow, .039, 10)
        arm = mk.frame(start.lerp(elbow, .50), elbow-start)
        mk.mbox(p, "trim", arm, (.10, .168, .123), .014, 1)
        mk.piston(p, start+Vector((out*.048, -.013, .073)),
                  elbow+Vector((out*.031, .019, .055)), .015)
        bearing(p, elbow, out, radius=.053, width=.141)
    # Tall left sensor shield versus a round, exposed magnetic unit on the right.
    shield(p, "shell", [(-.461, 2.063), (-.317, 1.932), (-.327, 1.697),
                        (-.475, 1.646), (-.493, 1.847)], -.10, .052)
    panel(p, "glow", (-.411, 1.833, -.13), (.011, .18, .007), angle=(0, 0, -5), radius=.002)
    right = mk.axis_frame((.351, 1.816, -.024), "-z")
    mk.mring(p, "trim", right, .105, .020, 20, 5)
    mk.mring(p, "glow", mk.sub(right, 0, .021, 0), .103, .0055, 24, 4)
    panel(p, "metal", (.35, 1.816, .047), (.157, .031, .051), radius=.007)
    finish(p)


def eclipse12_arm(p):
    a, b = ELBOW_L, WRIST_L
    m = mk.frame(a.lerp(b, .5), b-a)
    mk.mbox(p, "dark", m, (.095, (b-a).length, .10), .012, 1)
    mk.mbox(p, "shell", mk.sub(m, 0, -.014, 0), (.144, .23, .141), .015, 1,
            taper=(.86, .88))
    mk.mbox(p, "trim", mk.sub(m, 0, .094, 0), (.151, .021, .146), .005, 1)
    mk.piston(p, a+Vector((-.055, -.025, .042)), b+Vector((-.037, .035, .042)), .013)
    mk.mtube(p, "metal", mk.axis_frame(b, b-a), .033, .059, 12)
    mk.hand(p, T(-.47, 1.077, -.128), fingers=3, scale=1.06, curl=.66, armor="trim")
    m = mk.frame(ELBOW_R, MUZZLE-ELBOW_R, front=(0, 1, 0))
    mk.mtube(p, "dark", mk.sub(m, 0, .163, 0), .049, .278, 12)
    mk.mbox(p, "shell", mk.sub(m, 0, .153, 0), (.164, .238, .157), .016, 1)
    mk.mbox(p, "trim", mk.sub(m, 0, .27, 0), (.171, .024, .164), .005, 1)
    finish(p)


def eclipse12_gun(p):
    m = mk.frame(ELBOW_R, MUZZLE-ELBOW_R, front=(0, 1, 0))
    length = (MUZZLE-ELBOW_R).length
    mk.mtube(p, "dark", mk.sub(m, 0, (.29+length)/2, 0), .037, length-.29, 16)
    mk.mbox(p, "shell", mk.sub(m, 0, .40, 0), (.119, .18, .115), .014, 1)
    for pos, radius in ((.58, .09), (.80, .117)):
        mk.mring(p, "trim", mk.sub(m, 0, pos, 0), radius, .017, 20, 5)
        mk.mring(p, "glow", mk.sub(m, 0, pos+.011, 0), radius, .005, 24, 4)
    for x, z in ((1,0),(-1,0),(0,1),(0,-1)):
        mk.rod(p, "metal", mk.at(m, x*.088, .57, z*.088),
               mk.at(m, x*.111, .81, z*.111), .010, 8)
    mk.mtube(p, "dark", mk.sub(m, 0, length-.025, 0), .061, .043, 20)
    mk.mring(p, "glow", mk.sub(m, 0, length-.005, 0), .051, .0055, 24, 4)
    finish(p)


def eclipse12_leg(p, out):
    mp.LAST_KNEE = -.425
    knee = Vector((0, -.425, -.019))
    ankle = Vector((0, -HIP.y+.152, .023))
    bearing(p, (0, 0, 0), out, radius=.061, width=.102)
    panel(p, "dark", (0, -.21, .012), (.072, .32, .089), radius=.009)
    shield(p, "shell", [(-.089, -.065), (.081, -.085), (.065, -.339),
                        (-.056, -.361), (-.079, -.238)], -.071, .042)
    mk.piston(p, (0, -.032, .069), (0, -.389, .063), .017)
    bearing(p, knee, out, radius=.05, width=.12)
    panel(p, "trim", (0, -.432, -.093), (.125, .076, .034),
          angle=(12, 0, 0), radius=.01)
    panel(p, "dark", (0, -.635, .021), (.077, .335, .081), radius=.009)
    shield(p, "shell", [(-.069, -.495), (.07, -.483), (.073, -.663),
                        (.049, -.785), (-.044, -.788), (-.073, -.653)], -.072, .046)
    panel(p, "glow", (0, -.624, -.101), (.010, .116, .007), radius=.002)
    mk.piston(p, (out*.065, -.468, .048), (out*.046, ankle.y+.026, .04), .012)
    panel(p, "trim", (0, -.654, .079), (.082, .151, .024), radius=.008)
    bearing(p, ankle, out, radius=.03, width=.093)
    panel(p, "dark", (0, ankle.y-.04, .021), (.063, .049, .086), radius=.006)
    mk.foot(p, T(0, -HIP.y, .018), length=.32, width=.20, out=out,
            toes=2, armor="shell", heel="trim")
    finish(p)


def define(part):
    for suffix in ("head", "torso", "shoulders", "arm", "gun"):
        part("eclipse12_"+suffix)(globals()["eclipse12_"+suffix])
    part("eclipse12_leg")(lambda p: eclipse12_leg(p, 1))
    part("eclipse12_leg_l")(lambda p: eclipse12_leg(p, -1))
    part("eclipse12_leg_r")(lambda p: eclipse12_leg(p, 1))
