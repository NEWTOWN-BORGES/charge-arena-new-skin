"""Bakes the Cycles light into a world exported by the game (tools/export_world.gd).

    python3 tools/blender/bake_scene.py torre_terra [amostras]   # art/worlds/src/<id>.glb -> art/worlds/<id>.glb

The exported mesh carries each material's colour in its vertex colours (sRGB) and its finish
in the alpha (1 a light, 0.75 metal, 0.5 dark, 0.45 rubber, else paint). Here that becomes a
real material, the render's sun and sky light it, and the light is stored back in the vertex
colours the way bake_world.py stores the island's, for shaders/baked_world.gdshader.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402

import bake_world as bw  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BUDGET = 170000
# The sky over each world, from the top down (the light that fills the shade).
SKIES = {
    "torre": ("2f7fd0", "d6eef6"),
    "torre_terra": ("3f95e0", "dff2f7"),
    "torre_oceano": ("0f5f8c", "5cc9d6"),
    "torre_orbita": ("171a4a", "a35bbd"),
    "torre_cidade": ("5e4fc0", "f2c9e0"),
}


def material():
    """Base colour from the vertex colour (sRGB, so decoded), and the finish from its alpha:
    lights glow, metal shines, the rest is the robots' semi-matte paint."""
    mat = bpy.data.materials.new("world")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Color"
    gamma = nt.nodes.new("ShaderNodeGamma")
    gamma.inputs["Gamma"].default_value = 2.2
    nt.links.new(col.outputs["Color"], gamma.inputs["Color"])
    nt.links.new(gamma.outputs["Color"], bsdf.inputs["Base Color"])
    glow = nt.nodes.new("ShaderNodeMath")
    glow.operation = "GREATER_THAN"
    glow.inputs[1].default_value = 0.9
    nt.links.new(col.outputs["Alpha"], glow.inputs[0])
    strength = nt.nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY"
    strength.inputs[1].default_value = 3.0
    nt.links.new(glow.outputs[0], strength.inputs[0])
    nt.links.new(gamma.outputs["Color"], bsdf.inputs["Emission Color"])
    nt.links.new(strength.outputs[0], bsdf.inputs["Emission Strength"])
    lo = nt.nodes.new("ShaderNodeMath")
    lo.operation = "GREATER_THAN"
    lo.inputs[1].default_value = 0.7
    hi = nt.nodes.new("ShaderNodeMath")
    hi.operation = "LESS_THAN"
    hi.inputs[1].default_value = 0.8
    nt.links.new(col.outputs["Alpha"], lo.inputs[0])
    nt.links.new(col.outputs["Alpha"], hi.inputs[0])
    metal = nt.nodes.new("ShaderNodeMath")
    metal.operation = "MULTIPLY"
    nt.links.new(lo.outputs[0], metal.inputs[0])
    nt.links.new(hi.outputs[0], metal.inputs[1])
    nt.links.new(metal.outputs[0], bsdf.inputs["Metallic"])
    bsdf.inputs["Roughness"].default_value = 0.45
    return mat


def sky(top, low):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    world.node_tree.links.new(coord.outputs["Generated"], sep.inputs[0])
    world.node_tree.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].color = (*bw.rk.hex_rgb(low), 1)
    ramp.color_ramp.elements[1].color = (*bw.rk.hex_rgb(top), 1)
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[1].position = 0.75
    world.node_tree.links.new(ramp.outputs["Color"], nodes["Background"].inputs[0])
    nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(12)
    sun.rotation_euler = (math.radians(48), math.radians(-18), math.radians(-35))
    bpy.context.collection.objects.link(sun)


def main(world_id, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "art" / "worlds" / "src" / (world_id + ".glb")))
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    mat = material()
    for obj in objects:
        me = obj.data
        bw.densify(me, 0.6)
        for poly in me.polygons:
            poly.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(40))
        me.materials.clear()
        me.materials.append(mat)
        me.color_attributes.new("bake", "FLOAT_COLOR", "CORNER")
        me.color_attributes.active_color_name = "bake"
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    sky(*SKIES.get(world_id, ("3f95e0", "dff2f7")))
    bw.bake(objects, samples)
    bw.encode(objects)
    # Keep only the baked light for export, then simplify to the budget.
    for obj in objects:
        me = obj.data
        for name in [a.name for a in me.color_attributes if a.name != "bake"]:
            me.color_attributes.remove(me.color_attributes[name])
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.data.calc_loop_triangles()
    total = len(joined.data.loop_triangles)
    if total > BUDGET:
        decimate = joined.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = BUDGET / total
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    out = ROOT / "art" / "worlds" / (world_id + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(out), export_yup=True, export_materials="NONE", export_apply=True,
                              export_vertex_color="ACTIVE", export_texcoords=False, use_selection=True)
    joined.data.calc_loop_triangles()
    print("BAKED", out.relative_to(ROOT), len(joined.data.loop_triangles), "triângulos", out.stat().st_size, "bytes")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(args[0], int(args[1]) if len(args) > 1 else 32)
