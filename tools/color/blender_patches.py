"""O quadro de cores de teste no Blender, com a gestão de cor dos renders (AgX, Medium High
Contrast): cada quadrado emite exatamente a luz linear do tools/color/patches.json.

    python3 tools/color/blender_patches.py saida.png
"""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh

data = json.loads(Path(__file__).with_name("patches.json").read_text())
cols, cell, patches = data["columns"], data["cell"], data["patches"]
rows = math.ceil(len(patches) / cols)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
me = bpy.data.meshes.new("patches")
bm = bmesh.new()
for i in range(len(patches)):
    x, y = i % cols, i // cols
    v = [bm.verts.new((x, -y, 0)), bm.verts.new((x + 1, -y, 0)), bm.verts.new((x + 1, -y - 1, 0)), bm.verts.new((x, -y - 1, 0))]
    bm.faces.new(v)
bm.to_mesh(me)
attr = me.color_attributes.new("c", "FLOAT_COLOR", "CORNER")
for poly in me.polygons:
    r, g, b = patches[poly.index]
    for li in poly.loop_indices:
        attr.data[li].color = (r, g, b, 1.0)
mat = bpy.data.materials.new("emit")
mat.use_nodes = True
nt = mat.node_tree
nt.nodes.clear()
col = nt.nodes.new("ShaderNodeVertexColor")
col.layer_name = "c"
emit = nt.nodes.new("ShaderNodeEmission")
out = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(col.outputs["Color"], emit.inputs["Color"])
nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
me.materials.append(mat)
obj = bpy.data.objects.new("patches", me)
scene.collection.objects.link(obj)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(cols, rows)
cam.location = (cols / 2, -rows / 2, 10)
scene.collection.objects.link(cam)
scene.camera = cam
world = bpy.data.worlds.new("w")
world.color = (0, 0, 0)
scene.world = world
scene.render.engine = "CYCLES"
scene.cycles.samples = 1
scene.cycles.use_denoising = False
scene.cycles.filter_width = 0.01
scene.render.resolution_x = cols * cell
scene.render.resolution_y = rows * cell
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = sys.argv[-1]
bpy.ops.render.render(write_still=True)
