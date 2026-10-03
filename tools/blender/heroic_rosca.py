"""ROSCA: original workshop mechanic, refined without changing its silhouette.

The fused drum, welding goggles, articulated loupe, claw, riveter and round walking
legs come from the original R2/R3 construction. Geometry only; no exports or roster edits.
"""
from mathutils import Vector
import mech_kit as mk
import mech_cast as mc
from mech_parts import T

DESIGN = {
    "hip": [0.21, 0.66, 0.0], "muzzle": [0.45, 0.78, -0.93],
    "scale": [.97, .97, .97], "eye_style": "monocle", "mouth": False, "wear": .38,
    "palette": {"shell": "c35e2e", "trim": "dfd5bd", "dark": "30272b",
                "metal": "b99a68", "glow": "ffc15a", "screen": "100d12",
                "team": "", "rubber": "171419", "eyes": "ffd27a"},
    "parts": {"head": "", "torso": "rosca12_hull", "shoulders": "rosca12_shoulders",
              "arm": "rosca12_arm", "gun": "rosca12_gun", "legs": "rosca12_leg",
              "back": "", "top": "", "spin": ""},
    "design_note": "Mecânica original de bancada: casco e tronco em tambor fundido sem "
                   "pescoço, óculos de soldador e lupa articulada, garra esquerda, rebitadora "
                   "e caixa de ferramentas. Silhueta recuperada com fixações legíveis, "
                   "acabamento cobre/latão e bacia central compacta fechada.",
}


def rosca12_hull(p):
    mc.rosca_hull(p)
    mk.HEADS["rosca12_hull"] = dict(mk.HEADS["rosca3_hull"])
    # A closed lower cover joins the existing hip front instead of making a U apron.
    mk.mbox(p, "shell", mk.sub(T(0, .624, -.195), rot=(8, 0, 180)),
            (.22, .144, .038), .014, 1, taper=(.56, .92))
    for out in (-1, 1):
        mk.screw(p, mk.axis_frame((out*.057, .677, -.218), "-z"), 0, 0, .008)


def rosca12_shoulders(p):
    mc.rosca_shoulders(p)


def rosca12_arm(p):
    mc.rosca_forearm_left(p)
    mc.rosca_forearm_right(p)


def rosca12_gun(p):
    mc.rosca_gun(p)
    e, muzzle = mc.ROSCA["elbow_r"], mc.ROSCA["muzzle"]
    m = mk.frame(e, muzzle-e, front=(0, 1, 0))
    mk.mring(p, "metal", mk.sub(m, 0, .552, 0), .061, .005, 20, 4)


def rosca12_leg(p, out):
    mc.rosca_leg(p, out)


def define(part):
    part("rosca12_hull")(rosca12_hull)
    for suffix in ("shoulders", "arm", "gun"):
        part("rosca12_"+suffix)(globals()["rosca12_"+suffix])
    part("rosca12_leg")(lambda p: rosca12_leg(p, 1))
    part("rosca12_leg_l")(lambda p: rosca12_leg(p, -1))
    part("rosca12_leg_r")(lambda p: rosca12_leg(p, 1))
