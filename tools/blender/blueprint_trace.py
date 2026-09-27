"""Decalque de uma planta no Blender: monta um robô a partir das peças do kit e renderiza as
quatro vistas ortográficas (frente, lado direito, costas, lado esquerdo) com fundo transparente,
a 250 px por metro, para pôr por cima das vistas da planta e acertar peça a peça.

    python3 tools/blender/blueprint_trace.py -- <saída prefixo> <receita.json>

A receita: {"parts": {"head": ..., "torso": ..., "shoulders": ..., "arm": ..., "gun": ...,
"legs": ...}, "hip": [x, y, z], "palette": {"trim": "f8f6f0", ...}}. Escreve
<prefixo>-0.png ... <prefixo>-3.png (Cycles, luz de estúdio, cores sem tone mapping).
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import robot_kit as rk  # noqa: E402

TILE = (480, 560)
SPAN = 2.24          # metros na vertical: 250 px por metro
MIDDLE = 1.02        # altura do centro da imagem


def material(role, hexcolor):
    mat = bpy.data.materials.new(f"bp_{role}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgb = rk.hex_rgb(hexcolor)
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = {"metal": 0.35, "screen": 0.15}.get(role, 0.55)
    bsdf.inputs["Metallic"].default_value = 0.6 if role == "metal" else 0.0
    if role == "glow":
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = 1.5
    return mat


def build(name, mats, offset=Vector((0, 0, 0))):
    p = rk.Part(name)
    rk.PARTS[name](p)
    for role, me in p.meshes.items():
        for poly in me.polygons:
            poly.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(40))
        me.materials.append(mats.get(role) or mats["trim"])
        obj = bpy.data.objects.new(f"{name}__{role}", me)
        obj.location = offset
        bpy.context.collection.objects.link(obj)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    prefix, recipe_path = args[0], args[1]
    recipe = json.loads(Path(recipe_path).read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = {"shell": "f4a261", "trim": "f8f6f0", "dark": "3a3f46", "metal": "8e9399", "glow": "ef476f",
               "team": "4fd6c4", "screen": "0a0d12", "rubber": "1e1e1e", "hazard": "ffc837", "label": "f4f1e8"}
    palette.update(recipe.get("palette", {}))
    mats = {role: material(role, hexcolor) for role, hexcolor in palette.items()}
    parts = recipe["parts"]
    for slot in ("head", "torso", "shoulders", "back", "spin", "arm", "gun"):
        if parts.get(slot):
            build(parts[slot], mats)
    hx, hy, hz = recipe["hip"]
    for side, suffix in ((-1, "_l"), (1, "_r")):
        # Godot (x, y, z) -> Blender (x, -z, y).
        build(parts["legs"] + suffix, mats, Vector((side * hx, -hz, hy)))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.device = "CPU"
    scene.render.resolution_x, scene.render.resolution_y = TILE
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.6, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    for loc, power in (((-3, 5, 6), 900), ((4, 3, 3), 350), ((0, -5, 4), 300)):
        light = bpy.data.objects.new("Light", bpy.data.lights.new("Light", "AREA"))
        light.data.energy = power
        light.data.size = 5
        light.location = loc
        light.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        bpy.context.collection.objects.link(light)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = SPAN
    scene.camera = cam
    # O robô olha para +Y no Blender: frente, o seu lado direito (+X), costas, lado esquerdo.
    views = [((0, 8, MIDDLE), (90, 0, 180)), ((8, 0, MIDDLE), (90, 0, 90)), ((0, -8, MIDDLE), (90, 0, 0)), ((-8, 0, MIDDLE), (90, 0, -90))]
    for i, (loc, rot) in enumerate(views):
        cam.location = loc
        cam.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.render.filepath = f"{prefix}-{i}.png"
        bpy.ops.render.render(write_still=True)
        print("VIEW", scene.render.filepath)
    # E um retrato a 3/4 em perspetiva, para ver o robô como objeto e não só como silhueta.
    cam.data.type = "PERSP"
    cam.data.lens = 60
    cam.location = (-2.3, 3.9, 1.2)
    cam.rotation_euler = (Vector((0, 0, 0.92)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = 720, 900
    scene.cycles.samples = 128
    scene.render.filepath = f"{prefix}-beauty.png"
    bpy.ops.render.render(write_still=True)
    print("VIEW", scene.render.filepath)


main()
