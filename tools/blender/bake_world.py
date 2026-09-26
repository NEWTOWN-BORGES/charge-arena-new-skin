"""Mundo com a luz do Cycles cozida: o diorama de relva (tools/blender/arena_kit.py) montado à
volta do campo "torre" do jogo, com a iluminação do render (sol suave, céu, oclusão nos cantos,
luz rebatida) calculada uma vez e guardada nas cores dos vértices.

    python3 tools/blender/bake_world.py [amostras]     # escreve art/worlds/jardim.glb

No jogo o mundo é desenhado sem luz (a luz já vem nas cores), por isso fica igual ao render
e custa menos do que os mapas iluminados. Tudo estático: nada se mexe depois de cozido.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

import robot_kit as rk  # noqa: E402
import arena_kit as ak  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "art" / "worlds" / "jardim.glb"
# O contorno do mapa "torre" (Rules.map_outline(Rules.tower_map())), em unidades do Godot.
BROAD = ("grass", "grass_dark", "cliff", "cliff_dark", "track", "track_edge", "check1", "check2", "dark")
# Triangles the world may keep once the light is in the colours (the simplification keeps the
# colours, so the look survives).
BUDGET = 170000
# The brightest baked light kept (see encode()); must match shaders/baked_world.gdshader.
BAKE_RANGE = 2.0
TOWER = [(-3.4, -8.5932), (3.4, -8.5932), (5.3, -6.3932), (5.3, 6.3932), (3.4, 8.5932), (-3.4, 8.5932), (-5.3, 6.3932), (-5.3, -6.3932)]


def densify(me, max_len):
    """Parte os triângulos compridos até nenhuma aresta passar de `max_len`: a luz fica
    guardada nos vértices, e uma laje de relva com quatro vértices não guardava sombra."""
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    for _ in range(9):
        long = [e for e in bm.edges if e.calc_length() > max_len]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=False)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(me)
    bm.free()


def build():
    ak.OUTLINE = TOWER
    ak.HALF_W = 5.3
    ak.HALF_L = 8.5932
    rk.reset()
    parts = []
    # O chão em xadrez, os muros de borracha e a ilha com a relva, as falésias, a pista, as
    # árvores, arbustos, rochas, cristais e nuvens. As balizas e os tijolos são do jogo.
    for name, fn in (("floor", ak.build_vivid_floor), ("walls", ak.build_vivid_walls), ("vivid", ak.build_vivid)):
        prt = rk.Part("jardim_" + name)
        fn(prt)
        parts.append(prt)
    mats = {}
    for role, value in {**ak.THEME, **ak.VIVID}.items():
        mat = bpy.data.materials.new(role)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        col = rk.hex_rgb(value)
        bsdf.inputs["Base Color"].default_value = (*col, 1)
        bsdf.inputs["Roughness"].default_value = {"metal": 0.3, "rubber": 0.85, "dark": 0.5, "paint": 0.5}.get(role, 0.45)
        bsdf.inputs["Metallic"].default_value = {"metal": 0.85, "dark": 0.3}.get(role, 0.0)
        if role in ("glow", "crystal", "crystal2"):
            bsdf.inputs["Emission Color"].default_value = (*col, 1)
            bsdf.inputs["Emission Strength"].default_value = 3.0 if role == "glow" else 0.8
        mats[role] = mat
    objects = []
    for prt in parts:
        for role, me in prt.meshes.items():
            # Only the big flat surfaces need extra vertices to hold the shade; the round
            # trees, bushes and rocks already have plenty.
            if role in BROAD:
                densify(me, 0.5)
            for poly in me.polygons:
                poly.use_smooth = True
            me.set_sharp_from_angle(angle=math.radians(40))
            me.materials.append(mats.get(role) or mats["shell"])
            me.color_attributes.new("bake", "FLOAT_COLOR", "CORNER")
            me.color_attributes.active_color_name = "bake"
            me.color_attributes.render_color_index = me.color_attributes.active_color_index
            obj = bpy.data.objects.new(me.name, me)
            bpy.context.collection.objects.link(obj)
            objects.append(obj)
    return objects


def light():
    """A mesma luz do render do diorama: céu em gradiente e um sol largo e suave."""
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    world.node_tree.links.new(coord.outputs["Generated"], sep.inputs[0])
    world.node_tree.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].color = (*rk.hex_rgb("d6eef6"), 1)
    ramp.color_ramp.elements[1].color = (*rk.hex_rgb("3f97c2"), 1)
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


def bake(objects, samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.device = "CPU"
    scene.render.bake.target = "VERTEX_COLORS"
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.bake(type="COMBINED", target="VERTEX_COLORS")


def light_seams(objects):
    """The orange track runs under the floor tiles and shows in the gaps between them, lit.
    Baked into vertices, its points under the tiles came out in shadow and the gaps went dark:
    inside the field it takes the track's own lit colour instead."""
    for obj in objects:
        if "track" not in obj.name:
            continue
        me = obj.data
        attr = me.color_attributes["bake"]
        values = [0.0] * (len(attr.data) * 4)
        attr.data.foreach_get("color", values)
        inside, outside = [], []
        for loop in me.loops:
            co = me.vertices[loop.vertex_index].co
            # Blender (x, y) is Godot (x, -z).
            (inside if ak.inside((co.x, -co.y), TOWER, 0.0) else outside).append(loop.index)
        if not outside:
            continue
        lit = [sum(values[i * 4 + c] for i in outside) / len(outside) for c in range(3)]
        for i in inside:
            values[i * 4:i * 4 + 3] = lit
        attr.data.foreach_set("color", values)


def encode(objects):
    """Godot keeps vertex colours in 8 bits, which in linear light loses the shade and clips
    the sunlit tops above 1: store the light halved and sRGB-encoded, and the world's shader
    (shaders/baked_world.gdshader) undoes it."""
    for obj in objects:
        attr = obj.data.color_attributes["bake"]
        values = [0.0] * (len(attr.data) * 4)
        attr.data.foreach_get("color", values)
        for i in range(0, len(values), 4):
            for c in range(3):
                x = min(max(values[i + c] / BAKE_RANGE, 0.0), 1.0)
                values[i + c] = 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
        attr.data.foreach_set("color", values)


def export(objects):
    # Um só objeto, sem materiais: no jogo é uma malha com a luz nas cores.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    # Simplify the scenery, never the floor: collapsing across the gaps between tiles pulled
    # the dark slab's shade up onto them in smudges.
    counts = {}
    for obj in objects:
        obj.data.calc_loop_triangles()
        counts[obj.name] = len(obj.data.loop_triangles)
    keep = [o for o in objects if o.name.startswith("jardim_floor") or "track" in o.name]
    fixed = sum(counts[o.name] for o in keep)
    rest = sum(counts.values()) - fixed
    if fixed + rest > BUDGET and rest > 0:
        ratio = max(0.1, (BUDGET - fixed) / rest)
        for obj in objects:
            if obj in keep:
                continue
            decimate = obj.modifiers.new("Decimate", "DECIMATE")
            decimate.ratio = ratio
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=decimate.name)
    print("FLOOR", fixed, "SCENERY", rest)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_yup=True, export_materials="NONE", export_apply=True,
                              export_vertex_color="ACTIVE", export_texcoords=False, use_selection=True)
    me = bpy.context.view_layer.objects.active.data
    me.calc_loop_triangles()
    print("BAKED", OUTPUT.relative_to(ROOT), len(me.loop_triangles), "triângulos", OUTPUT.stat().st_size, "bytes")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    objs = build()
    light()
    bake(objs, int(args[0]) if args else 48)
    light_seams(objs)
    encode(objs)
    export(objs)
