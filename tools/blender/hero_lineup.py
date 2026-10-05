"""O elenco do Charge Arena lado a lado, de corpo inteiro, para o site e a imagem de destaque da loja.

    python3 tools/blender/hero_lineup.py [saida.png] [--quick]

Usa as mesmas receitas, materiais e luz de estúdio dos retratos da história
(tools/blender/story_portraits.py) e renderiza com fundo transparente, em 3840x1600.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402,F401
from mathutils import Matrix, Vector  # noqa: E402

import story_portraits as sp  # noqa: E402

W, H = 3840, 1600
# (skin, x, z, rotação em graus): o BIT ao centro, à frente; os maiores atrás.
CAST = [
    (0, 0.0, -0.7, 0),      # BIT
    (10, -1.15, 0.8, 8),    # HÉLIO
    (11, 1.25, 0.85, -8),   # MAGNUS
    (8, -2.3, 0.1, 14),     # BATIDA
    (6, 2.35, 0.15, -14),   # ROSCA
    (5, -3.45, 0.7, 18),    # ECLIPSE
    (7, 3.5, 0.6, -18),     # FAÍSCA
    (9, -4.6, 0.0, 24),     # GANCHO
    (2, 4.6, 0.05, -24),    # ÓRBITA
    (3, -5.6, -0.45, 28),   # BROTO
    (4, 5.65, -0.4, -28),   # BIGORNA
]


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    quick = "--quick" in args
    out = next((a for a in args if not a.startswith("--")), str(sp.ROOT / "store" / "hero_lineup.png"))
    objects = sp.rk.build_kit()
    objects.update(sp.import_redesigns())
    for obj in objects.values():
        obj.hide_render = True
        for child in obj.children:
            child.hide_render = True
    cam = sp.studio(16 if quick else 40)
    scene = bpy.context.scene
    scene.render.resolution_x = W // 4 if quick else W
    scene.render.resolution_y = H // 4 if quick else H
    origin = sp.godot((0, 0, 0))
    for skin, x, z, turn in CAST:
        entry = sp.recipe(skin, sp.TEAM)
        mats = sp.materials(entry["palette"], "happy", False)
        created, _shape = sp.assemble(objects, entry, mats)
        move = Matrix.Translation(sp.godot((x, 0, z)) - origin) @ Matrix.Rotation(math.radians(turn), 4, "Z")
        for obj in created:
            obj.matrix_world = move @ obj.matrix_world
    # Uma luz de frente larga para o grupo inteiro, além das três do estúdio.
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy = 2600
    fill.data.size = 9.0
    fill.location = sp.godot((0, 3.0, -7.0))
    fill.rotation_euler = (sp.godot((0, 1.2, 0)) - fill.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(fill)
    rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "AREA"))
    rim.data.energy = 3000
    rim.data.size = 10.0
    rim.data.color = sp.rk.hex_rgb("9ec8ff")
    rim.location = sp.godot((0, 4.0, 5.0))
    rim.rotation_euler = (sp.godot((0, 1.2, 0)) - rim.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(rim)
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.angle = math.radians(38)
    focus = Vector((0, 1.25, 0.4))
    eye = focus + Vector((0, 0.08, -1.0)).normalized() * 19.0
    cam.location = sp.godot(eye)
    cam.rotation_euler = (sp.godot(focus) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sp.render(out)


if __name__ == "__main__":
    main()
