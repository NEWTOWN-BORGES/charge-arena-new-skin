"""Build Eclipse, Rosca and Batida's revised mechanical cast with Blender.

blender --background --python tools/blender/heroic_cast.py
The original kit remains available; this exports the three revised machines.
"""
import json
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import robot_kit as kit
import heroic_eclipse
import heroic_rosca
import heroic_batida

DETAIL = 0.75
MODULES = [(5, heroic_eclipse), (6, heroic_rosca), (8, heroic_batida)]
OUTPUT = kit.ROOT / "art" / "robots" / "heroic_cast.glb"


def replace_entry(text, name, updates):
    start = re.search(r'\{\s*"name"\s*:\s*"' + re.escape(name) + '"', text).start()
    entry, length = json.JSONDecoder().raw_decode(text[start:])
    entry.update(updates)
    replacement = json.dumps(entry, ensure_ascii=False, indent="\t")
    replacement = replacement.replace("\n", "\n\t\t")
    return text[:start] + replacement + text[start + length:]


def studio_source(objects):
    for root in objects.values():
        root.hide_viewport = True
        root.hide_render = True
        for child in root.children:
            child.hide_viewport = True
            child.hide_render = True
    for col, (_, module) in enumerate(MODULES):
        design = module.DESIGN
        parent = bpy.data.objects.new(["ECLIPSE", "ROSCA", "BATIDA"][col], None)
        bpy.context.collection.objects.link(parent)
        offset = kit.CONVERT.to_3x3() @ Vector(((col - 1) * 3.1, 0, 0))
        size = design.get("scale", [1, 1, 1])
        parent.matrix_world = Matrix.Translation(offset) @ Matrix.Diagonal((size[0], size[2], size[1], 1))
        materials = {}
        for role in kit.ROLES:
            material = bpy.data.materials[role].copy()
            material.name = parent.name + "_" + role
            shade = material.node_tree.nodes["Principled BSDF"]
            value = design["palette"].get(role) or "00caff"
            color = kit.hex_rgb(value)
            shade.inputs["Base Color"].default_value = (*color, 1)
            if role == "glow":
                shade.inputs["Emission Color"].default_value = (*color, 1)
            materials[role] = material
        placed = [(name, Matrix.Identity(4)) for slot, name in design["parts"].items()
                  if name and slot not in ["legs", "legs_l", "legs_r"]]
        for side, suffix in [(-1, "_l"), (1, "_r")]:
            hip = design["hip"]
            placed.append((design["parts"]["legs"] + suffix,
                           Matrix.Translation(kit.CONVERT.to_3x3() @ Vector((side * hip[0], hip[1], hip[2])))))
        for name, transform in placed:
            for child in objects[name].children:
                copy = child.copy()
                copy.data = child.data.copy()
                copy.parent = parent
                copy.hide_viewport = False
                copy.hide_render = False
                copy.matrix_parent_inverse = Matrix.Identity(4)
                copy.matrix_basis = transform
                copy.data.materials[0] = materials[child.data.materials[0].name]
                bpy.context.collection.objects.link(copy)


def build():
    text = kit.ROSTER.read_text(encoding="utf-8")
    old = json.loads(text)
    for index, module in MODULES:
        module.define(kit.part)
        text = replace_entry(text, old["cast"][index]["name"], module.DESIGN)
    kit.ROSTER.write_text(text, encoding="utf-8", newline="\n")
    kit.PARTS = {name: fn for name, fn in kit.PARTS.items()
                 if name.startswith(("eclipse12_", "rosca12_", "batida12_"))}
    objects = kit.build_kit()
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_yup=True,
                              export_texcoords=True, export_materials="EXPORT",
                              export_extras=False, export_apply=True,
                              export_vertex_color="NONE")
    # Preserve all previous head and knee measurements; add only this cast.
    text = kit.ROSTER.read_text(encoding="utf-8")
    for name, values in kit.HEADS.items():
        if not name.startswith(("eclipse12_", "rosca12_", "batida12_")): continue
        pattern = r'"' + re.escape(name) + r'"\s*:\s*\{[^}]+\}'
        entry = '"' + name + '": ' + json.dumps(values)
        if re.search(pattern, text):
            text = re.sub(pattern, entry, text, count=1)
        else:
            start = text.index('"heads": {') + len('"heads": {')
            text = text[:start] + '\n\t\t' + entry + ',' + text[start:]
    kit.ROSTER.write_text(text, encoding="utf-8", newline="\n")
    knees_path = OUTPUT.parent / "knees.json"
    knees = json.loads(knees_path.read_text(encoding="utf-8"))
    knees.update(kit.KNEES)
    knees_path.write_text(json.dumps(knees, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    metrics = {}
    for index, module in MODULES:
        tris = 0
        names = set(module.DESIGN["parts"].values()) - {""}
        names.discard(module.DESIGN["parts"]["legs"])
        leg_name = module.DESIGN["parts"]["legs"]
        names.update([leg_name + "_l", leg_name + "_r"])
        for name in names:
            for child in objects[name].children:
                child.data.calc_loop_triangles()
                tris += len(child.data.loop_triangles)
        metrics[old["cast"][index]["name"]] = tris
    print("HEROIC_CAST", json.dumps(metrics), "bytes", OUTPUT.stat().st_size)
    # Keep a native Blender source containing the actual exported geometry.
    studio_source(objects)
    blend_path = kit.ROOT.parent.parent / "outputs" / "robos-redesenhados.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print("BLENDER_SOURCE", blend_path)


if __name__ == "__main__":
    build()
