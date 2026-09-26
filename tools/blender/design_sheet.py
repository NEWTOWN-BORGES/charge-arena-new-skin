"""Folha de design de um robô, renderizada do próprio modelo do jogo (Cycles).

    python3 tools/blender/design_sheet.py BIT saida.png            # folha completa
    python3 tools/blender/design_sheet.py BIT saida.png --quick    # só a vista 3/4, para rever

Monta o robô a partir de art/robots/roster.json e do kit (robot_kit.py), e renderiza: 3/4 de
frente, frente, costas, os dois lados, 3/4 de trás, pormenores das articulações e uma vista
explodida com os painéis de blindagem afastados do chassis. A composição (títulos e legendas)
é feita com o Pillow.
"""
import json
import math
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import robot_kit as rk  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TEAM = "4fd6c4"
BG = (0.62, 0.67, 0.72)


def godot(v):
    """Ponto em coordenadas do Godot para o Blender."""
    return (rk.CONVERT @ Vector((*v, 1))).to_3d()


def recipe_of(name):
    roster = json.loads((ROOT / "art" / "robots" / "roster.json").read_text())
    for entry in roster["cast"]:
        if entry["name"] == name:
            return entry
    raise SystemExit(f"robô {name} não está no roster")


def materials(palette):
    mats = {}
    for role in rk.ROLES:
        mat = bpy.data.materials[role].copy()
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        value = palette.get(role) or ""
        if role == "rubber" and not value:
            value = "15161a"
        if role == "hazard" and not value:
            value = "f2c230"
        if role == "label" and not value:
            value = "f4f1e8"
        color = rk.hex_rgb(value or TEAM) if role != "screen" else (0.015, 0.02, 0.035)
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Roughness"].default_value = {"metal": 0.32, "rubber": 0.85, "dark": 0.55, "screen": 0.15}.get(role, 0.42)
        bsdf.inputs["Metallic"].default_value = {"metal": 0.85, "dark": 0.35}.get(role, 0.0)
        if role in rk.EMISSIVE:
            bsdf.inputs["Emission Color"].default_value = (*color, 1)
            bsdf.inputs["Emission Strength"].default_value = 4.0
        mats[role] = mat
    return mats


def face_texture(mat, eye_color):
    """Olhos em cápsula no ecrã, como o shader do jogo desenha no estado calmo."""
    img = bpy.data.images.new("face", 256, 128)
    px = [0.0] * (256 * 128 * 4)
    ec = rk.hex_rgb(eye_color)
    for y in range(128):
        for x in range(256):
            i = (y * 256 + x) * 4
            c = (0.01, 0.015, 0.03)
            for cx in (96, 160):
                dx, dy = (x - cx) / 13.0, (y - 70) / 30.0
                if dx * dx + dy * dy < 1.0:
                    c = ec
            if 40 < y < 48 and abs(x - 128) < 12 and abs(y - 44 + ((x - 128) / 12.0) ** 2 * 5) < 3:
                c = ec
            px[i:i + 4] = (*c, 1.0)
    img.pixels = px
    nodes = mat.node_tree.nodes
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = nodes["Principled BSDF"]
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Emission Strength"].default_value = 2.5


def assemble(objects, entry, offset=Vector((0, 0, 0)), explode=0.0):
    """Coloca o robô na cena. Devolve os objetos criados."""
    parts = entry["parts"]
    mats = materials(entry["palette"])
    face_texture(mats["screen"], entry["palette"].get("eyes") or TEAM)
    hip = Vector(entry.get("hip", list(rk.LEG_PIVOT)))
    created = []
    body = Matrix.Translation(godot(offset))

    def place(name, extra):
        for child in objects[name].children:
            copy = child.copy()
            copy.parent = None
            copy.data = child.data.copy()
            copy.data.materials[0] = mats[child.data.materials[0].name]
            copy.matrix_world = body @ extra
            bpy.context.collection.objects.link(copy)
            copy.hide_render = False
            created.append(copy)

    for slot in ("head", "torso", "shoulders", "back", "arm", "gun", "top"):
        if parts.get(slot):
            place(parts[slot], Matrix.Identity(4))
    for side in (-1, 1):
        name = parts["legs"] + ("_l" if side < 0 else "_r")
        if name not in objects:
            name = parts["legs"]
        place(name, Matrix.Translation(godot((side * hip.x, hip.y, hip.z))))
    if explode > 0:
        explode_armor(created, explode)
    return created


def explode_armor(created, distance):
    """Separa cada painel de blindagem (ilha de malha pintada) e afasta-o do eixo do corpo."""
    for obj in list(created):
        role = obj.data.materials[0].name.split(".")[0]
        if role not in ("shell", "trim", "team"):
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.transform(obj.matrix_world)
        islands = []
        seen = set()
        for f in bm.faces:
            if f.index in seen:
                continue
            stack, island = [f], []
            seen.add(f.index)
            while stack:
                cur = stack.pop()
                island.append(cur)
                for e in cur.edges:
                    for g in e.link_faces:
                        if g.index not in seen:
                            seen.add(g.index)
                            stack.append(g)
            islands.append(island)
        for island in islands:
            verts = {v for f in island for v in f.verts}
            centre = sum((v.co for v in verts), Vector()) / len(verts)
            out = Vector((centre.x, centre.y, 0))
            if out.length < 0.05:
                out = Vector((0, 1 if centre.y > 0 else -1, 0))
            # A cabeça sobe um pouco mais, para se ver o pescoço por baixo.
            lift = 0.5 if centre.z > 1.5 else 0.0
            move = out.normalized() * distance + Vector((0, 0, lift * distance))
            for v in verts:
                v.co += move
        bm.transform(obj.matrix_world.inverted())
        bm.to_mesh(obj.data)
        bm.free()


def studio(width, height, samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*BG, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    scene.world = world
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    for loc, power, size in (((-3.5, 5.5, -4.5), 900, 3.5), ((4.5, 3.0, -2.0), 420, 3.0), ((0.5, 3.5, 5.0), 700, 3.0)):
        light = bpy.data.objects.new("Light", bpy.data.lights.new("Light", "AREA"))
        light.data.energy = power
        light.data.size = size
        light.location = godot(loc)
        light.rotation_euler = (godot((0, 1.0, 0)) - light.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.collection.objects.link(light)
    # Chão de estúdio que só recebe a sombra de contacto.
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    floor = bpy.context.active_object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*BG, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    floor.data.materials.append(fm)
    floor.is_shadow_catcher = True
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    scene.camera = cam
    return cam


def shoot(cam, direction, target, scale, path, width=None, height=None):
    """Câmara ortográfica a olhar para `target` vinda de `direction` (Godot)."""
    scene = bpy.context.scene
    if width:
        scene.render.resolution_x = width
        scene.render.resolution_y = height
    cam.data.ortho_scale = scale
    cam.location = godot(Vector(target) + Vector(direction).normalized() * 8.0)
    cam.rotation_euler = (godot(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


VIEWS = [
    ("3/4 FRENTE", (0.55, 0.32, -0.8)),
    ("FRENTE", (0.0, 0.0, -1.0)),
    ("COSTAS", (0.0, 0.0, 1.0)),
    ("LADO ESQUERDO", (-1.0, 0.0, 0.0)),
    ("LADO DIREITO", (1.0, 0.0, 0.0)),
    ("3/4 COSTAS", (-0.6, 0.3, 0.8)),
]


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    name, out = args[0], Path(args[1])
    quick = "--quick" in args
    entry = recipe_of(name)
    objects = rk.build_kit()
    for obj in objects.values():
        for child in obj.children:
            child.hide_render = True
    work = Path(tempfile.mkdtemp(prefix="sheet_"))
    cam = studio(900, 1100, 24 if quick else 40)
    robot = assemble(objects, entry)
    centre = (0, 1.0, 0)
    if quick:
        for i, (label, direction) in enumerate(VIEWS[:5] if "--all" in args else VIEWS[:1]):
            shoot(cam, direction, centre, 2.55, out.with_name(f"{out.stem}_{i}{out.suffix}") if i else out)
        return
    shots = []
    for i, (label, eye) in enumerate(VIEWS):
        path = work / f"view_{i}.png"
        size = (1000, 1250) if i == 0 else (560, 700)
        shoot(cam, eye, centre, 2.55, path, *size)
        shots.append((label, path))
    callouts = []
    for call in entry.get("callouts", []):
        label, point, scale = call[0], call[1], call[2]
        p = Vector(point)
        side = 1 if p.x >= 0 else -1
        direction = call[3] if len(call) > 3 else (side * 0.8, 0.35, -0.7)
        path = work / f"call_{len(callouts)}.png"
        shoot(cam, direction, tuple(p), scale, path, 380, 380)
        callouts.append((label, path))
    # The silhouette: the same 3/4 view in solid black, to check it reads with no detail.
    black = bpy.data.materials.new("silhouette")
    black.use_nodes = True
    black.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
    black.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    black.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.0
    for obj in robot:
        obj.data.materials[0] = black
    silhouette = work / "silhouette.png"
    shoot(cam, VIEWS[0][1], centre, 2.55, silhouette, 560, 700)
    shots.append(("SILHUETA", silhouette))
    for obj in robot:
        bpy.data.objects.remove(obj)
    assemble(objects, entry, explode=0.16)
    exploded = work / "exploded.png"
    shoot(cam, VIEWS[0][1], centre, 3.0, exploded, 900, 1000)
    compose(entry, shots, callouts, exploded, out)


def compose(entry, shots, callouts, exploded, out):
    from PIL import Image, ImageDraw, ImageFont
    fonts = ROOT / "art" / "fonts"
    title = ImageFont.truetype(str(fonts / "LilitaOne-Regular.ttf"), 64)
    label = ImageFont.truetype(str(fonts / "LilitaOne-Regular.ttf"), 24)
    small = ImageFont.truetype(str(fonts / "Rubik-Variable.ttf"), 22)
    W, H = 3100, 2690
    sheet = Image.new("RGB", (W, H), (226, 230, 234))
    draw = ImageDraw.Draw(sheet)
    draw.text((60, 40), f"CHARGE ARENA · {entry['name']}", font=title, fill=(24, 28, 44))
    draw.text((64, 118), entry.get("design_note", ""), font=small, fill=(70, 76, 92))

    def paste(path, x, y, caption):
        img = Image.open(path).convert("RGB")
        sheet.paste(img, (x, y))
        draw.rectangle((x, y, x + img.width - 1, y + img.height - 1), outline=(150, 156, 166), width=2)
        box = draw.textbbox((x + 14, y + 10), caption, font=label)
        draw.rounded_rectangle((box[0] - 8, box[1] - 5, box[2] + 8, box[3] + 5), radius=8, fill=(244, 246, 248))
        draw.text((x + 14, y + 10), caption, font=label, fill=(24, 28, 44))
        return img

    top = 170
    main_img = paste(shots[0][1], 60, top, shots[0][0])
    grid_x = 60 + main_img.width + 30
    for i, (caption, path) in enumerate(shots[1:7]):
        col, row = i % 3, i // 3
        paste(path, grid_x + col * 580, top + row * 720, caption)
    second = top + max(main_img.height, 2 * 720) + 30
    ex = paste(exploded, 60, second, "VISTA EXPLODIDA · BLINDAGEM SOBRE O CHASSIS")
    cx = 60 + ex.width + 30
    for i, (caption, path) in enumerate(callouts):
        col, row = i % 5, i // 5
        paste(path, cx + col * 400, second + row * 400, caption)
    bottom = max(second + ex.height, second + ((len(callouts) + 4) // 5) * 400) + 40
    sheet = sheet.crop((0, 0, W, min(H, bottom)))
    sheet.save(out)
    print("SHEET", out, sheet.size)


if __name__ == "__main__":
    main()
