"""O mundo cozido (art/worlds/jardim.glb) visto no Blender com a câmara de comparação, para pôr
ao lado da mesma vista no jogo (tests/capture_world_view.gd).

    python3 tools/color/blender_world_view.py saida.png
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
EYE, TARGET, FOV = (9.5, 13.5, 17.0), (0.0, 0.8, 0.0), 40.0


def godot(v):
    return Vector((v[0], -v[2], v[1]))


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "art" / "worlds" / "jardim.glb"))
mat = bpy.data.materials.new("baked")
mat.use_nodes = True
nt = mat.node_tree
nt.nodes.clear()
col = nt.nodes.new("ShaderNodeVertexColor")
gamma = nt.nodes.new("ShaderNodeGamma")  # the stored colour is sRGB-encoded: undo it
gamma.inputs["Gamma"].default_value = 2.2
scale = nt.nodes.new("ShaderNodeMixRGB")
scale.blend_type = "MULTIPLY"
scale.inputs["Fac"].default_value = 1.0
scale.inputs["Color2"].default_value = (2.0, 2.0, 2.0, 1.0)
emit = nt.nodes.new("ShaderNodeEmission")
out = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(col.outputs["Color"], gamma.inputs["Color"])
nt.links.new(gamma.outputs["Color"], scale.inputs["Color1"])
nt.links.new(scale.outputs["Color"], emit.inputs["Color"])
nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        obj.data.materials.clear()
        obj.data.materials.append(mat)
scene = bpy.context.scene
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.sensor_fit = "VERTICAL"
cam.data.angle = math.radians(FOV)
cam.location = godot(EYE)
cam.rotation_euler = (godot(TARGET) - godot(EYE)).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam
world = bpy.data.worlds.new("w")
world.color = (0.2, 0.3, 0.4)
scene.world = world
scene.render.engine = "CYCLES"
scene.cycles.samples = 8
scene.render.resolution_x, scene.render.resolution_y = 900, 700
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.render.filepath = sys.argv[-1]
bpy.ops.render.render(write_still=True)
