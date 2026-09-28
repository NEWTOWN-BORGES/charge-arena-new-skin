"""Retratos dos cartões do Modo história, renderizados em 3D (Cycles) a partir do kit do jogo.

    python3 tools/blender/story_portraits.py            # todos
    python3 tools/blender/story_portraits.py 0 22 agente
    python3 tools/blender/story_portraits.py --quick     # poucas amostras, para rever

Monta cada robô com a sua receita (roster.json, como Robots.recipe no jogo: as skins difíceis
juntam as peças "parts_add" ao seu chefe; os pilotos de estrada ganham a sua cabeça e topo) e
renderiza-o da cintura para cima, com fundo transparente, em luz de estúdio com contraluz.
Escreve art/story/faces/<quem>.png (olhos felizes) e <quem>_hit.png (atordoado, olhos em X);
os corrompidos da temporada 2 também <quem>_angry.png (cara de poucos amigos);
para as skins difíceis também <quem>_dark.png: o corpo negro e só o néon aceso, a forma
corrompida da segunda temporada.
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import robot_kit as rk  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "story" / "faces"
ROSTER = json.loads((ROOT / "art" / "robots" / "roster.json").read_text())
W, H = 1024, 1280
STATION = 100
TEAM = "72ddc6"
# Who speaks in the story: skin indices, and the two station robots with a role.
JOBS = [(str(i), i, TEAM) for i in range(24)] + [("agente", STATION + 9, "3b6fe0"), ("locutor", STATION + 6, "a45cff")]
CENTRED_SPINS = ("spin_rays", "spin_halo", "spin_orbit")
# Quem fala corrompido na temporada 2: o MAGNUS (na skin normal) e as skins difíceis, menos o
# BIT DE ELITE (22) e o MAGNUS IMPERADOR (23), que nunca estão corrompidos.
ANGRY = {"11"} | {str(i) for i in range(12, 22)}


def godot(v):
    return (rk.CONVERT @ Vector((*v, 1))).to_3d()


def recipe(skin, team):
    """O mesmo que Robots.recipe no jogo, com a cor de equipa já resolvida na paleta."""
    if skin >= STATION:
        variant = skin - STATION
        kind = variant % 10
        family = min(max(variant // 10, 0), 4)
        station = ROSTER["station"]
        parts = dict(station["families"][family])
        parts["head"] = station["heads"][kind % 5]
        parts["top"] = station["tops"][kind]
        parts["spin"] = ""
        entry = {"parts": parts, "palette": dict(station["palette"]), "scale": [1, 1, 1], "hip": list(rk.LEG_PIVOT)}
    else:
        entry = dict(ROSTER["cast"][skin])
        if "base" in entry:
            base = dict(ROSTER["cast"][entry["base"]])
            parts = dict(base["parts"])
            parts.update(entry.get("parts_add", {}))
            base["parts"] = parts
            base["palette"] = entry["palette"]
            entry = base
        entry = {"parts": entry["parts"], "palette": dict(entry["palette"]), "scale": entry.get("scale", [1, 1, 1]),
                 "hip": entry.get("hip") or list(rk.LEG_PIVOT)}
    palette = entry["palette"]
    for role in ("shell", "trim", "dark", "metal", "glow", "eyes", "team"):
        if not palette.get(role):
            palette[role] = team
    if not palette.get("rubber"):
        palette["rubber"] = "15161a"
    return entry


def head_shape(parts):
    name = parts.get("head") or parts.get("torso")
    return ROSTER["heads"].get(name, {"top": rk.HEAD_TOP, "center": rk.HEAD_CENTER})


def face_texture(eye_hex, mood, dark_screen=(0.01, 0.015, 0.03)):
    """O ecrã da cara: olhos felizes em arco, ou atordoados em X, como o shader do jogo."""
    w, h = 256, 128
    img = bpy.data.images.new("face_%s_%s" % (eye_hex, mood), w, h)
    ec = rk.hex_rgb(eye_hex)
    px = [0.0] * (w * h * 4)
    for y in range(h):
        for x in range(w):
            c = dark_screen
            for cx in (92, 164):
                # Blender images run bottom-up: flip so the arcs point up (^ ^).
                dx, dy = x - cx, (h - 1 - y) - 66
                if mood == "angry":
                    # Cara de poucos amigos: sobrancelha a descer para o meio, olho meio fechado.
                    inner = 1 if cx < 128 else -1
                    up = -dy
                    brow = 14 - 0.5 * inner * dx
                    if abs(dx) < 22 and abs(up - brow) < 4:
                        c = ec
                    elif math.hypot(dx, up + 2) < 15 and up < brow - 7:
                        c = ec
                elif mood == "hit":
                    # Um X de traço grosso.
                    if abs(dx) < 20 and abs(dy) < 20 and (abs(dx - dy) < 5 or abs(dx + dy) < 5):
                        c = ec
                else:
                    # Um arco virado para cima (^): feliz.
                    r = math.hypot(dx, (dy + 8) * 1.1)
                    if 13 < r < 21 and dy + 8 < 2:
                        c = ec
            i = (y * w + x) * 4
            px[i:i + 4] = (*c, 1.0)
    img.pixels = px
    return img


def materials(palette, mood, dark):
    mats = {}
    for role in rk.ROLES:
        mat = bpy.data.materials[role].copy()
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        value = palette.get(role) or ("f2c230" if role == "hazard" else "f4f1e8" if role == "label" else TEAM)
        color = rk.hex_rgb(value)
        if dark and role != "glow":
            color = (0.004, 0.004, 0.006)
        if role == "screen":
            color = (0.015, 0.02, 0.035)
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Roughness"].default_value = {"metal": 0.3, "rubber": 0.85, "dark": 0.5, "screen": 0.12}.get(role, 0.38)
        bsdf.inputs["Metallic"].default_value = {"metal": 0.85, "dark": 0.3}.get(role, 0.0)
        if dark:
            bsdf.inputs["Metallic"].default_value = 0.0
            bsdf.inputs["Roughness"].default_value = 0.6
        if role in rk.EMISSIVE:
            bsdf.inputs["Emission Color"].default_value = (*color, 1)
            bsdf.inputs["Emission Strength"].default_value = 9.0 if dark else 4.0
        if role == "screen":
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = face_texture(palette.get("glow" if dark else "eyes") or TEAM, mood)
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Emission Strength"].default_value = 3.0
        mats[role] = mat
    return mats


def assemble(objects, entry, mats):
    parts = entry["parts"]
    shape = head_shape(parts)
    sx, sy, sz = entry["scale"]
    body = Matrix.Diagonal((sx, sz, sy, 1.0))
    lift = Matrix.Translation(godot((0, float(shape["top"]) - rk.HEAD_TOP, 0)))
    centre = Matrix.Translation(godot((0, float(shape["center"]) - rk.HEAD_CENTER, 0)))
    hip = Vector(entry["hip"])
    created = []

    def place(name, extra):
        if not name or name not in objects:
            return
        for child in objects[name].children:
            copy = child.copy()
            copy.parent = None
            copy.data = child.data.copy()
            role = child.data.materials[0].name.split(".")[0]
            copy.data.materials[0] = mats.get(role, child.data.materials[0])
            copy.matrix_world = body @ extra
            bpy.context.collection.objects.link(copy)
            copy.hide_render = False
            created.append(copy)

    for slot in ("head", "torso", "shoulders", "back", "extra", "hat", "arm", "gun"):
        place(parts.get(slot), Matrix.Identity(4))
    place(parts.get("top"), lift)
    crest = parts.get("spin") or ""
    if crest:
        in_place = crest.endswith("2_spin") or crest.endswith("3_spin")
        place(crest, Matrix.Identity(4) if in_place else (centre if crest in CENTRED_SPINS else lift))
    for side in (-1, 1):
        name = parts["legs"] + ("_l" if side < 0 else "_r")
        if name not in objects:
            name = parts["legs"]
        place(name, Matrix.Translation(godot((side * hip.x, hip.y, hip.z))))
    return created, shape


def studio(samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = W
    scene.render.resolution_y = H
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.55, 0.65, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    scene.world = world

    def area(loc, power, color, size, target=(0, 1.4, 0)):
        light = bpy.data.objects.new("Light", bpy.data.lights.new("Light", "AREA"))
        light.data.energy = power
        light.data.size = size
        light.data.color = rk.hex_rgb(color)
        light.location = godot(loc)
        light.rotation_euler = (godot(target) - light.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.collection.objects.link(light)
        return light

    # Luz principal quente à esquerda, contraluz fria forte atrás à direita, enchimento suave.
    area((-2.5, 3.2, -3.5), 700, "fff1e0", 2.5)
    area((2.8, 2.6, 2.4), 900, "9ec8ff", 2.0)
    area((2.5, 1.2, -3.0), 180, "ffe0f0", 3.0)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(30)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    return cam


def frame(cam, shape, scale_y):
    top = (float(shape["top"]) + 0.42) * scale_y
    bottom = (float(shape["center"]) - 1.05) * scale_y
    focus = Vector((0, (top + bottom) * 0.5, 0))
    span = (top - bottom) * 1.05
    distance = span * 0.5 / math.tan(math.radians(15))
    eye = focus + Vector((-0.42, 0.1, -1.0)).normalized() * distance
    cam.location = godot(eye)
    cam.rotation_euler = (godot(focus) - cam.location).to_track_quat("-Z", "Y").to_euler()


def render(path):
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("PORTRAIT", path)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    quick = "--quick" in args
    wanted = [a for a in args if not a.startswith("--")]
    objects = rk.build_kit()
    for obj in objects.values():
        obj.hide_render = True
        for child in obj.children:
            child.hide_render = True
    cam = studio(12 if quick else 28)
    OUT.mkdir(parents=True, exist_ok=True)
    for key, skin, team in JOBS:
        if wanted and key not in wanted:
            continue
        entry = recipe(skin, team)
        hard = skin < STATION and "base" in ROSTER["cast"][skin]
        variants = [("", "happy", False), ("_hit", "hit", False)] + ([("_dark", "happy", True)] if hard else [])
        # Os amigos corrompidos da temporada 2 (as skins difíceis e o MAGNUS antes da reviravolta).
        if key in ANGRY:
            variants.append(("_angry", "angry", False))
        if "--angry" in args:
            variants = [v for v in variants if v[0] == "_angry"]
        for suffix, mood, dark in variants:
            mats = materials(entry["palette"], mood, dark)
            created, shape = assemble(objects, entry, mats)
            frame(cam, shape, entry["scale"][1])
            render(OUT / f"{key}{suffix}.png")
            for obj in created:
                bpy.data.objects.remove(obj, do_unlink=True)


if __name__ == "__main__":
    main()
