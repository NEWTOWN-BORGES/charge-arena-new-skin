"""BATIDA: the original B11 radio DJ, with restrained material and guard refinements.

The barrel radio, headphone speakers, chest subwoofer, rear turntable and megaphone
are the original authored shapes. This module registers meshes only.
"""
import mech_kit as mk
import mech_cast as mc
from mech_parts import T

DESIGN = {
    "hip": [0.20, .70, 0.0], "muzzle": [.44, .86, -1.0],
    "scale": [.95, .95, .95], "eye_style": "equalizer", "mouth": False, "wear": .22,
    "parts": {"head": "batida12_head", "torso": "batida12_torso",
              "shoulders": "batida12_shoulders", "arm": "batida12_arm",
              "gun": "batida12_gun", "legs": "batida12_leg",
              "top": "", "back": "", "spin": ""},
    "palette": {"shell": "be377b", "trim": "d4cad9", "dark": "20192c",
                "metal": "919bb0", "glow": "ff4fb8", "team": "",
                "eyes": "ff8ad6", "rubber": "17121e"},
    "design_note": "DJ original do circuito: cabeça de rádio em tambor com colunas "
                   "nas pontas, pega e antena; tronco em pipo com subwoofer e gira-discos "
                   "às costas, ombreiras-coluna e megafone. Mesma silhueta com magenta "
                   "mais encorpado, metal definido, grelha protetora e bacia fechada.",
}


def batida12_head(p):
    mc.batida11_head(p)
    mk.HEADS["batida12_head"] = dict(mk.HEADS["batida11_head"])


def batida12_torso(p):
    mc.batida11_torso(p)
    # Two thin protective rods sit in the original speaker rim, without a new chest.
    for offset in (-.044, .044):
        mk.rod(p, "metal", (-.086, 1.245+offset, -.217),
               (.086, 1.245+offset, -.217), .0038, 6)
    mk.mbox(p, "shell", mk.sub(T(0, .670, -.173), rot=(8, 0, 180)),
            (.21, .148, .039), .014, 1, taper=(.57, .91))


def batida12_shoulders(p):
    mc.batida11_shoulders(p)


def batida12_arm(p):
    mc.batida11_arm(p)


def batida12_gun(p):
    mc.batida11_gun(p)


def batida12_leg(p, out):
    mc.batida11_leg(p, out)


def define(part):
    for suffix in ("head", "torso", "shoulders", "arm", "gun"):
        part("batida12_"+suffix)(globals()["batida12_"+suffix])
    part("batida12_leg")(lambda p: batida12_leg(p, 1))
    part("batida12_leg_l")(lambda p: batida12_leg(p, -1))
    part("batida12_leg_r")(lambda p: batida12_leg(p, 1))
