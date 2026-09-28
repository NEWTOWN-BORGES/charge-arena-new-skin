"""Pré-visualização de um tijolo temático, renderizada em 3D (Cycles) a partir do kit do jogo.

    python3 tools/blender/brick_preview.py brick_broto 3 saida.png

Monta uma fila de tijolos encaixados (azuis e vermelhos, as duas equipas) na paleta do robô
que defende a muralha (índice do elenco), e um tijolo em grande plano ao lado.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import robot_kit as rk  # noqa: E402
import story_portraits as sp  # noqa: E402

TEAMS = ("3a8dff", "ff4d5e")


def place(objects, name, mats, where, turn=0.0, scale=1.0):
    matrix = Matrix.Translation(sp.godot(where)) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Scale(scale, 4)
    for child in objects[name].children:
        copy = child.copy()
        copy.parent = None
        copy.data = child.data.copy()
        role = child.data.materials[0].name.split(".")[0]
        copy.data.materials[0] = mats.get(role, child.data.materials[0])
        copy.matrix_world = matrix @ child.matrix_world
        bpy.context.collection.objects.link(copy)
        copy.hide_render = False


def sheet(objects, jobs, out):
    """Todos os tijolos numa folha: uma grelha, cada um na paleta do seu robô, as equipas
    alternadas."""
    scene = bpy.context.scene
    cam = sp.studio(48)
    scene.render.resolution_x, scene.render.resolution_y = 1800, 1400
    scene.render.film_transparent = False
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.09, 0.1, 0.12, 1)
    cols = 4
    for i, (name, skin) in enumerate(jobs):
        palette = dict(sp.ROSTER["cast"][skin]["palette"], team=TEAMS[i % 2])
        x = (i % cols - (cols - 1) / 2) * 0.95
        z = (i // cols - 1) * 0.95
        place(objects, name, sp.materials(palette, "happy", False), (x, 0.0, z), turn=-18)
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
    mat = bpy.data.materials.new("floor")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.055, 0.065, 1)
    bpy.context.active_object.data.materials.append(mat)
    cam.data.angle = math.radians(40)
    cam.location = sp.godot((0.0, 2.9, 3.4))
    cam.rotation_euler = (sp.godot((0.0, 0.2, -0.05)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("BRICK", out)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args[0] == "--sheet":
        objects = rk.build_kit()
        for obj in objects.values():
            obj.hide_render = True
            for child in obj.children:
                child.hide_render = True
        names = ["bit", "salvo", "orbita", "broto", "bigorna", "eclipse", "rosca", "faisca", "batida", "gancho", "helio", "magnus"]
        jobs = [("brick_broto" if n == "broto" else "brick_%s_mech" % n, i) for i, n in enumerate(names)]
        sheet(objects, jobs, args[1])
        return
    name, skin, out = args[0], int(args[1]), args[2]
    objects = rk.build_kit()
    for obj in objects.values():
        obj.hide_render = True
        for child in obj.children:
            child.hide_render = True
    scene = bpy.context.scene
    cam = sp.studio(64)
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    scene.render.film_transparent = False
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.09, 0.1, 0.12, 1)
    palette = dict(sp.ROSTER["cast"][skin]["palette"])
    # A fila: quatro tijolos encaixados, as duas cores de equipa, e um em grande à frente.
    for i, x in enumerate((-0.84, -0.28, 0.28, 0.84)):
        team = dict(palette, team=TEAMS[i // 2])
        place(objects, name, sp.materials(team, "happy", False), (x, 0.0, -0.9))
    place(objects, name, sp.materials(dict(palette, team=TEAMS[0]), "happy", False), (0.0, 0.0, 0.25), turn=-28, scale=1.9)
    # Chão escuro para as sombras.
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0))
    floor = bpy.context.active_object
    mat = bpy.data.materials.new("floor")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.055, 0.065, 1)
    floor.data.materials.append(mat)
    cam.data.angle = math.radians(34)
    cam.location = sp.godot((0.0, 1.7, 2.9))
    cam.rotation_euler = (sp.godot((0.0, 0.42, -0.35)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("BRICK", out)


if __name__ == "__main__":
    main()
