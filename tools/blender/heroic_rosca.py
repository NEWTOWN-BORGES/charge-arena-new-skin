"""ROSCA 12: a naval workshop sailor, a distant sibling of Gancho.

A continuous barrel and integrated dome replace the rejected boxy engineer.
Navy enamel, off-white curved armour and brass fittings repeat across every
limb. Geometry uses Godot coordinates: Y up, front -Z; legs are hip-local.
The module registers pieces only and never exports or edits the roster.
"""
import math
import bmesh
from mathutils import Matrix, Vector
import mech_kit as mk
import mech_parts as mp
from mech_kit import (at, axis_frame, bearing, bolts, cable, capsule, cyl_panel,
                      dome, frame, lathe, mbox, mring, mtube, piston, rod,
                      sphere_panel, sub)
from mech_parts import T
from mech_cast import screen_well

DESIGN = {
    "hip": [0.22, 0.60, 0.0], "muzzle": [0.47, 0.81, -1.01],
    "scale": [1.0, 1.0, 1.0], "eye_style": "visor", "mouth": False,
    "palette": {"shell": "24556b", "trim": "d8ded9", "dark": "12232d",
                "metal": "ba9c60", "glow": "ffd26a", "screen": "07141c",
                "team": "", "rubber": "101922", "eyes": "ffd375"},
    "parts": {"head": "rosca12_head", "torso": "rosca12_torso",
              "shoulders": "rosca12_shoulders", "arm": "rosca12_arm",
              "gun": "rosca12_gun", "legs": "rosca12_leg",
              "legs_l": "rosca12_leg_l", "legs_r": "rosca12_leg_r",
              "back": "", "top": "", "spin": ""},
    "design_note": "Marinheiro robótico, irmão afastado do Gancho: pipa naval azul-petróleo e cúpula integrada off-white, vigia âmbar, gola de marinheiro, hélice peitoral, pinça articulada, guincho de corda e lança-arpão de proa. Anca compacta sólida, membros curvos uniformes.",
}
CHEST = Vector((0.0, 1.07, 0.02))
DOME_BASE = Vector((0.0, 1.305, 0.01))
HEAD = Vector((0.0, 1.42, -0.025))
ELBOW_L = Vector((-0.52, 0.97, 0.025))
ELBOW_R = Vector((0.52, 0.97, -0.025))
WRIST_L = Vector((-0.54, 0.715, -0.105))
MUZZLE = Vector(DESIGN["muzzle"])


def sphere(p, role, center, radius, detail=20):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=detail, v_segments=detail // 2, radius=radius)
    p.add(role, bm, T(*center))


def propeller(p, m, radius=.082):
    """Three curved radial screw blades inside the chest's brass inspection port."""
    for blade in range(3):
        bm = bmesh.new()
        a = blade * math.tau / 3
        outline = [(radius * .24, -.007), (radius * .57, -.028),
                   (radius * .98, -.030), (radius * .99, -.003),
                   (radius * .58, .033), (radius * .27, .023)]
        rows = []
        for depth in (-.004, .004):
            row = []
            for radial, tangent in outline:
                x = radial * math.cos(a) - tangent * math.sin(a)
                z = radial * math.sin(a) + tangent * math.cos(a)
                row.append(bm.verts.new((x, depth + radial * .09, z)))
            rows.append(row)
        bm.faces.new(tuple(reversed(rows[0])))
        bm.faces.new(rows[1])
        for i in range(len(outline)):
            j = (i + 1) % len(outline)
            bm.faces.new((rows[0][i], rows[0][j], rows[1][j], rows[1][i]))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=.0015, segments=2,
                        profile=.5, affect="EDGES", clamp_overlap=True)
        p.add("metal", bm, m)
    mtube(p, "metal", sub(m, 0, .006, 0), radius * .22, .024, 12)
    mtube(p, "dark", sub(m, 0, .023, 0), radius * .075, .005, 6)


def rosca12_head(p):
    mk.HEADS["rosca12_head"] = {"top": 1.61, "center": 1.42, "aspect": 3.8}
    r = .267
    base = T(*DOME_BASE)
    sphere(p, "dark", DOME_BASE, r-.024)
    # Gancho family shape: continuous rounded dome, no separate neck or square face.
    for lo in ((-53, 34), (38, 121), (125, 208), (212, 233)):
        sphere_panel(p, "trim", base, r, (3, 86), lo, .025, (9, 7), gap=.006)
    sphere_panel(p, "trim", base, r, (47, 86), (-127, -53), .025, (7, 4), gap=.005)
    sphere_panel(p, "shell", base, r+.001, (3, 9), (-127, -53), .012, (8, 2), gap=.003)
    mring(p, "shell", sub(base, 0, .016, 0), .265, .012, 32, 5)
    # A narrow amber visor in a round naval porthole, rather than a pirate eye patch.
    port = axis_frame((0, HEAD.y, -.252), "-z")
    mtube(p, "dark", port, .104, .040, 28)
    mring(p, "metal", sub(port, 0, .026, 0), .101, .010, 28, 6)
    bolts(p, sub(port, 0, .030, 0), .099, 6, size=.0055, phase=.16)
    screen_well(p, (0, HEAD.y, -.277), (.171, .045), depth=.024, recess=.003, ring=False)
    # Low sailor-cap crown and a neat navy ribbon use the same curved language.
    crown = T(0, 1.558, .025)
    mtube(p, "shell", crown, .139, .029, 26, bevel=.005)
    lathe(p, "trim", crown, [(.155, .009), (.155, .025), (.145, .038),
                              (.105, .045), (0, .047)], 28, cap_bottom=True)
    for side in (-1, 1):
        hub = axis_frame((side * .267, 1.36, .01), "x" if side > 0 else "-x")
        mtube(p, "metal", hub, .035, .018, 14)
        mtube(p, "dark", sub(hub, 0, .013, 0), .018, .006, 8)


def rosca12_torso(p):
    c = CHEST
    ex, ey, ez = .325, .31, .285
    flat = T(*c) @ Matrix.Diagonal((1, 1, ez/ex, 1))
    ell = T(*c) @ Matrix.Diagonal((ex, ey, ez, 1))
    profile = [(0, -.218)]
    for angle in range(-44, 45, 11):
        a = math.radians(angle)
        profile.append(((ex-.025) * math.cos(a), ey * math.sin(a)))
    lathe(p, "dark", flat, profile+[(0, .218)], 28)
    # Rounded barrel staves directly reference Gancho's established construction.
    staves = ((-66, -12), (-8, 45), (49, 89), (93, 138),
              (142, 187), (191, 244))
    for lo in staves:
        sphere_panel(p, "shell", ell, 1, (-43, 43), lo, .085, (8, 8), gap=0)
    for y, rad in ((-.213, .235), (.211, .239)):
        mring(p, "trim", sub(flat, 0, y, 0), rad, .020, 32, 6)
        mring(p, "metal", sub(flat, 0, y-.022, 0), rad-.001, .006, 32, 4)
    # Front inspection hatch frames the screw-propeller, ROSCA's naval identity.
    port = axis_frame((0, 1.074, -.272), "-z")
    mtube(p, "dark", port, .125, .05, 28)
    mring(p, "metal", sub(port, 0, .024, 0), .119, .012, 32, 6)
    bolts(p, sub(port, 0, .037, 0), .119, 8, size=.006, phase=.18)
    propeller(p, sub(port, 0, .027, 0), radius=.091)
    # Sailor collar is a short curved lip at the integrated dome, not a cape.
    cyl_panel(p, "trim", T(0, 1.285, .014), .259, .063, (-145, -35),
              .018, (16, 2), gap=.003, radius_top=.274)
    for side in (-1, 1):
        cable(p, [(side*.275, 1.237, .101), (side*.343, 1.232, .135),
                  (side*.404, 1.116, .079)], .012)
    # Compact solid gearbox pelvis and a short central yaw bearing; no U outline.
    mtube(p, "dark", T(0, .813, .018), .146, .12, 22)
    mring(p, "metal", T(0, .852, .018), .155, .012, 26, 5)
    mring(p, "rubber", T(0, .791, .018), .146, .013, 24, 5)
    mbox(p, "dark", T(0, .684, .0), (.374, .172, .28), .048, 3)
    mbox(p, "trim", T(0, .679, -.145), (.326, .138, .068), .029, 3)
    # Discrete brass front fasteners match the porthole rings.
    for side in (-1, 1):
        mtube(p, "metal", axis_frame((side*.125, .704, -.181), "-z"), .010, .008, 8)
        mtube(p, "dark", axis_frame((side*.211, .60, 0), "x"), .072, .066, 16)


def rosca12_shoulders(p):
    for side in (-1, 1):
        at_shoulder = Vector((side*.405, 1.215, .015))
        bearing(p, axis_frame(at_shoulder, "x" if side > 0 else "-x"), .085, .045, 4)
        cap = T(side*.43, 1.232, .014)
        # Matching curved shoulders, with broad enamel and off-white lower collars.
        dome(p, "shell", cap, .146, .118, 24, 7)
        mring(p, "trim", sub(cap, 0, .011, 0), .145, .021, 26, 6)
        mring(p, "metal", sub(cap, 0, -.010, 0), .135, .007, 24, 5)
        elbow = ELBOW_L if side < 0 else ELBOW_R
        start = Vector((side*.461, 1.13, .02))
        direction = elbow-start
        m = frame((start+elbow)/2, direction)
        mtube(p, "dark", m, .046, direction.length, 14)
        capsule(p, "shell", sub(m, 0, -.005, .027), .073, direction.length*.80, 18)
        piston(p, start+Vector((0, 0, .055)), elbow+Vector((0, -.03, .062)), .018)
        bearing(p, axis_frame(elbow, "x"), .045, .12, 4)


def rosca12_arm(p):
    # Same naval barrel/manguito profile on both forearms; only their tools differ.
    for side, elbow, wrist in ((-1, ELBOW_L, WRIST_L), (1, ELBOW_R, MUZZLE)):
        m = frame(elbow, wrist-elbow, front=(0, 0, -1) if side < 0 else (0, 1, 0))
        length = (wrist-elbow).length if side < 0 else .425
        lathe(p, "shell", m, [(0, .04), (.06, .04), (.095, .075),
                              (.108, length*.52), (.094, length-.03),
                              (.078, length), (0, length)], 24)
        for y, radius in ((length*.30, .102), (length*.76, .102)):
            mring(p, "metal", sub(m, 0, y, 0), radius, .008, 24, 5)
        lathe(p, "trim", m, [(.084, length-.056), (.116, length-.056),
                             (.122, length-.012), (.108, length+.018),
                             (.065, length+.018), (.065, length-.055)], 24)
        if side < 0:
            # Jointed two-jaw naval clamp, rounded finger links and rubber grip pads.
            palm = sub(m, 0, length+.054, 0)
            mtube(p, "dark", palm, .064, .065, 14)
            mtube(p, "metal", sub(palm, rot=(0, 0, 90)), .020, .173, 10)
            for s in (-1, 1):
                jaw = sub(palm, s*.068, .026, 0, rot=(0, 0, s*-10))
                capsule(p, "metal", sub(jaw, 0, .046, 0), .022, .118, 12)
                mbox(p, "metal", sub(jaw, -s*.018, .094, 0), (.075, .044, .048), .013, 2)
                mbox(p, "rubber", sub(jaw, -s*.047, .095, -.001), (.014, .032, .035), .004, 1)
            piston(p, at(palm, -.072, -.014, .058), at(palm, .067, .023, .058), .013)
        else:
            # Compact naval rope winch, replacing the rejected rectangular tool box.
            spool = frame(at(m, .142, .24, 0), at(m, 1, 0, 0)-at(m))
            mtube(p, "dark", spool, .038, .06, 16)
            for y in (-.030, .030):
                mtube(p, "metal", sub(spool, 0, y, 0), .057, .012, 20, bevel=.003)
            for y in (-.018, -.005, .008, .021):
                mring(p, "rubber", sub(spool, 0, y, 0), .042, .006, 18, 5)
            cable(p, [at(m, .142, .262, .036), at(m, .102, .35, .077),
                      at(m, .065, .444, .047)], .008)


def rosca12_gun(p):
    m = frame(ELBOW_R, MUZZLE-ELBOW_R, front=(0, 1, 0))
    length = (MUZZLE-ELBOW_R).length
    # Naval torpedo/harpoon launcher: a coherent turned barrel and two anchor flukes.
    lathe(p, "metal", m, [(.073, .434), (.073, .48), (.060, .51),
                          (.054, length-.17), (.068, length-.13),
                          (.076, length-.07), (.065, length), (.049, length),
                          (.047, length-.09), (.03, length-.16)], 24)
    for y in (.515, length-.15):
        mring(p, "dark", sub(m, 0, y, 0), .056, .006, 24, 4)
    mring(p, "trim", sub(m, 0, length-.063, 0), .076, .009, 26, 5)
    rod(p, "metal", at(m, 0, length-.16, 0), at(m, 0, length+.044, 0), .016, 12)
    lathe(p, "metal", sub(m, 0, length+.044, 0), [(.022, -.009), (.018, .004), (0, .050)], 16)
    for side in (-1, 1):
        # Curved arrow-shaped flukes fit inside the bow launcher silhouette.
        a = at(m, side*.008, length+.022, 0)
        b = at(m, side*.050, length+.005, 0)
        c = at(m, side*.041, length-.018, 0)
        rod(p, "metal", a, b, .011, 10)
        rod(p, "metal", b, c, .009, 10)


def rosca12_leg(p, out):
    mp.LAST_KNEE = -.235
    ground = -DESIGN["hip"][1]
    knee = Vector((0, mp.LAST_KNEE, -.009))
    ankle = Vector((0, ground+.157, 0))
    bearing(p, axis_frame((out*.032, 0, 0), "x" if out > 0 else "-x"), .067, .066, 4)
    rod(p, "dark", (0, -.045, 0), knee, .038, 12)
    mtube(p, "shell", T(0, -.13, .004), .104, .145, 20, radius2=.090, bevel=.008)
    mring(p, "metal", T(0, -.070, .004), .101, .007, 22, 5)
    bearing(p, axis_frame(knee, "x"), .052, .17, 4)
    rod(p, "dark", knee, ankle, .038, 12)
    # Naval boot cuffs and curved shin echo the forearm manguitos exactly.
    center_y = (knee.y+ankle.y)/2
    mtube(p, "shell", T(0, center_y, 0), .093, .138, 20, radius2=.105, bevel=.008)
    lathe(p, "trim", T(0, knee.y-.028, 0), [(.088, -.043), (.105, -.043),
                                        (.124, -.001), (.123, .027),
                                        (.098, .027), (.088, -.043)], 24)
    piston(p, (out*.046, knee.y+.031, .075), (out*.046, ankle.y-.015, .075), .017)
    mtube(p, "metal", axis_frame(ankle, "x"), .018, .142, 10)
    # Broad low rounded deck boots: no wheeled bogies or square crates.
    boot = sub(T(0, ground+.071, -.066), rot=(90, 0, 0)) @ Matrix.Diagonal((1.05, 1, .5, 1))
    capsule(p, "rubber", sub(boot, 0, 0, .050), .095, .352, 20)
    capsule(p, "trim", boot, .091, .319, 20)
    capsule(p, "shell", sub(boot, 0, -.018, -.029), .066, .24, 18)
    mbox(p, "dark", T(0, ground+.151, .013), (.082, .035, .109), .012, 2)
    for side in (-1, 1):
        mtube(p, "metal", axis_frame((side*.069, ground+.116, .014), "x"), .007, .008, 6)


def define(part):
    for slot in ("head", "torso", "shoulders", "arm", "gun"):
        part("rosca12_"+slot)(globals()["rosca12_"+slot])
    part("rosca12_leg")(lambda p: rosca12_leg(p, 1))
    part("rosca12_leg_l")(lambda p: rosca12_leg(p, -1))
    part("rosca12_leg_r")(lambda p: rosca12_leg(p, 1))
