"""Cenários do Modo história, renderizados em Cycles (retrato, 1080x1920).

    python3 tools/blender/story_scenes.py            # todos
    python3 tools/blender/story_scenes.py rua quarto  # só alguns
    python3 tools/blender/story_scenes.py --quick     # poucas amostras, para rever

Escreve art/story/scenes/<nome>.png:
  rua     - uma rua de Voltara ao anoitecer, com o carro da polícia e as luzes a piscar
  quarto  - o quarto do BIT à noite: secretária, monitor aceso, janela para a cidade
  estadio - o estádio da TAÇA CHARGE ARENA cheio, com o ecrã gigante e os holofotes
São fundos sem personagens: os retratos dos cartões vão por cima.
"""
import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "story" / "scenes"
W, H = 1080, 1920
_mats = {}


def hex_rgb(value):
    value = value.lstrip("#")
    srgb = [int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def mat(name, color, rough=0.55, metal=0.0, emit=None, strength=0.0, alpha=1.0):
    key = (name, color, rough, metal, emit, strength, alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*hex_rgb(color), 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*hex_rgb(emit), 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    _mats[key] = m
    return m


def box(loc, size, material, bevel=0.0, rot=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(0, 0, rot))
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    obj.data.materials.append(material)
    return obj


def cylinder(loc, radius, depth, material, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return obj


def sphere(loc, radius, material):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=24, ring_count=12)
    obj = bpy.context.active_object
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return obj


def text(body, loc, size, material, rot=(math.pi / 2, 0, 0), extrude=0.02, align="CENTER"):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.data.body = body
    obj.data.size = size
    obj.data.extrude = extrude
    obj.data.align_x = align
    obj.data.align_y = "CENTER"
    obj.data.materials.append(material)
    return obj


def light(kind, loc, energy, color="ffffff", size=1.0, target=None, spot=None):
    data = bpy.data.lights.new(kind, kind)
    data.energy = energy
    data.color = hex_rgb(color)
    if kind == "AREA":
        data.size = size
    elif kind in ("POINT", "SPOT"):
        data.shadow_soft_size = size
    if kind == "SPOT" and spot:
        data.spot_size = spot
        data.spot_blend = 0.4
    obj = bpy.data.objects.new(kind, data)
    obj.location = loc
    if target is not None:
        obj.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(obj)
    return obj


def camera(loc, target, lens=26):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def world_sky(elevation, strength=1.0, tint=None):
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    nodes = world.node_tree.nodes
    sky = nodes.new("ShaderNodeTexSky")
    for kind in ("NISHITA", "SINGLE_SCATTERING", "PREETHAM"):
        try:
            sky.sky_type = kind
            break
        except TypeError:
            continue
    if hasattr(sky, "sun_elevation"):
        sky.sun_elevation = math.radians(elevation)
        sky.sun_rotation = math.radians(200)
    background = nodes["Background"]
    background.inputs[1].default_value = strength
    if tint:
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[7].default_value = (*hex_rgb(tint), 1)
        world.node_tree.links.new(sky.outputs[0], mix.inputs[6])
        world.node_tree.links.new(mix.outputs[2], background.inputs[0])
    else:
        world.node_tree.links.new(sky.outputs[0], background.inputs[0])
    bpy.context.scene.world = world


def world_color(color, strength):
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*hex_rgb(color), 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = strength
    bpy.context.scene.world = world


def render(name, samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = W
    scene.render.resolution_y = H
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    OUT.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(OUT / f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("SCENE", scene.render.filepath)


def facade_windows(x, y0, y1, height, facing, rng, lit_share=0.55):
    """Janelas numa fachada virada para a rua (facing = +1 / -1 no eixo X)."""
    warm = mat("win_warm", "2a2014", emit="ffcf8a", strength=3.5)
    cool = mat("win_cool", "1a2230", emit="9ed2ff", strength=3.5)
    off = mat("win_off", "1b2230", rough=0.2, metal=0.3)
    floor = 2.2
    rows = int((height - 3.0) / floor)
    cols = max(1, int((y1 - y0 - 1.0) / 1.8))
    for r in range(rows):
        for c in range(cols):
            z = 3.0 + r * floor + 0.9
            y = y0 + 1.0 + c * ((y1 - y0 - 2.0) / max(1, cols - 1) if cols > 1 else 0)
            roll = rng.random()
            m = warm if roll < lit_share * 0.8 else (cool if roll < lit_share else off)
            box((x + facing * 0.06, y, z), (0.05, 1.1, 1.3), m)


def scene_rua(samples):
    reset()
    rng = random.Random(7)
    world_sky(0.4, 0.35)
    asphalt = mat("asphalt", "2b2d33", rough=0.35)
    side = mat("sidewalk", "8b8f96", rough=0.8)
    stripe = mat("stripe", "f2efe6", rough=0.6, emit="f2efe6", strength=0.3)
    box((0, 40, -0.05), (8, 120, 0.1), asphalt)
    for sx in (-1, 1):
        box((sx * 5.5, 40, 0.07), (3, 120, 0.3), side)
    for i in range(30):
        box((0, 2 + i * 4, 0.005), (0.18, 2.0, 0.02), stripe)
    palettes = ["b5533c", "3f7f7a", "d9c7a4", "5a6475", "8a5a7a", "c98b4a", "4c5f8a", "a8a39a"]
    for sx in (-1, 1):
        y = -2.0
        while y < 90:
            width = rng.uniform(6, 11)
            height = rng.uniform(12, 34) if y > 6 else rng.uniform(9, 14)
            depth = 10
            x = sx * (7.0 + depth / 2)
            color = rng.choice(palettes)
            box((x, y + width / 2, height / 2), (depth, width - 0.3, height), mat("wall" + color, color, rough=0.75), bevel=0.05)
            box((x, y + width / 2, height + 0.25), (depth + 0.4, width, 0.5), mat("cornice", "3a3d44", rough=0.6))
            facade_windows(x - sx * depth / 2, y, y + width, height, -sx, rng)
            # Montras acesas no rés-do-chão e alguns letreiros de néon.
            box((x - sx * (depth / 2 + 0.05), y + width / 2, 1.3), (0.05, width * 0.7, 2.0), mat("shop", "1b1a1a", emit="ffe0b0", strength=2.5))
            if rng.random() < 0.6:
                neon = rng.choice(["ff4fb8", "4ff0ff", "ffd23f", "7cff6b"])
                word = rng.choice(["CAFÉ", "BAR", "HOTEL", "24H", "ARENA", "ROBÔS"])
                t = text(word, (x - sx * (depth / 2 + 0.25), y + width / 2, 3.4), 1.1, mat("neon" + neon, "111111", emit=neon, strength=18.0),
                         rot=(math.pi / 2, 0, -sx * math.pi / 2))
                light("POINT", (x - sx * (depth / 2 + 1.2), y + width / 2, 3.4), 120, neon, size=0.5)
            y += width
    # Candeeiros de rua.
    pole = mat("pole", "2c3036", rough=0.4, metal=0.6)
    bulb = mat("bulb", "ffffff", emit="ffd9a0", strength=40.0)
    for sx in (-1, 1):
        for i in range(8):
            y = 6 + i * 11
            cylinder((sx * 4.3, y, 3.0), 0.09, 6.0, pole)
            box((sx * 3.6, y, 6.0), (1.5, 0.18, 0.12), pole)
            box((sx * 3.0, y, 5.9), (0.5, 0.3, 0.1), bulb)
            light("POINT", (sx * 3.0, y, 5.6), 450, "ffcf8a", size=0.3)
    # O carro da polícia, parado à direita, com a barra de luzes acesa.
    car_white = mat("car_white", "eef1f5", rough=0.25, metal=0.2)
    car_blue = mat("car_blue", "1f3fa8", rough=0.25, metal=0.3)
    glass = mat("car_glass", "0d1420", rough=0.05, metal=0.5)
    tyre = mat("tyre", "111214", rough=0.8)
    cx, cy = 2.6, 7.5
    box((cx, cy, 0.75), (2.0, 4.6, 0.8), car_blue, bevel=0.25)
    box((cx, cy - 0.2, 1.35), (1.8, 2.6, 0.7), car_white, bevel=0.25)
    box((cx, cy + 0.35, 1.4), (1.85, 0.9, 0.5), glass, bevel=0.1)
    box((cx, cy - 1.15, 1.4), (1.85, 0.6, 0.45), glass, bevel=0.1)
    for dy in (-1.5, 1.5):
        for dx in (-1.0, 1.0):
            cylinder((cx + dx, cy + dy, 0.38), 0.38, 0.3, tyre, rot=(0, math.pi / 2, 0))
    box((cx - 0.4, cy - 0.2, 1.78), (0.7, 0.35, 0.16), mat("siren_red", "ff2030", emit="ff2030", strength=60.0))
    box((cx + 0.4, cy - 0.2, 1.78), (0.7, 0.35, 0.16), mat("siren_blue", "2050ff", emit="2a5cff", strength=60.0))
    text("POLÍCIA", (cx - 1.03, cy, 0.8), 0.42, mat("police_txt", "ffffff", emit="ffffff", strength=1.0), rot=(math.pi / 2, 0, -math.pi / 2))
    light("POINT", (cx - 0.5, cy - 0.2, 2.3), 9000, "ff2a3c", size=0.4)
    light("POINT", (cx + 0.5, cy - 0.2, 2.3), 9000, "2f5dff", size=0.4)
    # O reflexo das luzes nas fachadas: a rua inteira pisca a vermelho e azul.
    light("AREA", (cx - 3.0, cy + 4, 3.0), 900, "ff2a3c", size=4, target=(-7, cy + 8, 4))
    light("AREA", (cx + 1.5, cy + 4, 3.0), 900, "2f5dff", size=4, target=(7, cy + 8, 4))
    # Luz do fim de tarde a rasar a rua, e um céu quente ao fundo.
    light("SUN", (0, 0, 20), 0.35, "ff9a50").rotation_euler = (math.radians(86), 0, math.radians(180))
    camera((-1.2, -6.0, 1.7), (0.8, 30, 4.5), lens=24)
    render("rua", samples)


def scene_quarto(samples):
    reset()
    rng = random.Random(3)
    world_color("0b1024", 0.3)
    floor = mat("wood", "7a5234", rough=0.5)
    wall = mat("wall", "3a4a6a", rough=0.85)
    wall2 = mat("wall2", "33425f", rough=0.85)
    box((0, 0, -0.05), (8, 8, 0.1), floor)
    for i in range(12):
        box((-4 + i * 0.66 + 0.33, 0, 0.001), (0.02, 8, 0.004), mat("seam", "5d3d26", rough=0.6))
    # The back wall, cut round the window (x -1.0..1.6, z 1.0..2.8) so the city shows through.
    box((-2.5, 4.0, 1.6), (3.0, 0.2, 3.4), wall)
    box((2.8, 4.0, 1.6), (2.4, 0.2, 3.4), wall)
    box((0.3, 4.0, 0.45), (2.6, 0.2, 1.1), wall)
    box((0.3, 4.0, 3.05), (2.6, 0.2, 0.5), wall)
    box((-4.0, 0, 1.6), (0.2, 8, 3.4), wall2)
    box((4.0, 0, 1.6), (0.2, 8, 3.4), wall2)
    box((0, 0, 3.35), (8, 8, 0.1), mat("ceiling", "2a3450", rough=0.9))
    # Janela para a cidade à noite, com a lua.
    frame = mat("frame", "e9e4d8", rough=0.4)
    box((0.3, 3.92, 1.9), (2.6, 0.02, 1.8), mat("glass_night", "6f8fd0", rough=0.05, alpha=0.12))
    for dx in (-1.3, 0.0, 1.3):
        box((0.3 + dx, 3.86, 1.9), (0.08, 0.1, 1.9), frame)
    for dz in (-0.9, 0.9):
        box((0.3, 3.86, 1.9 + dz), (2.7, 0.1, 0.08), frame)
    box((0.3, 3.8, 0.98), (2.9, 0.3, 0.08), frame)
    city = mat("city_win", "0a0f1e", emit="ffd08a", strength=5.0)
    skyline = mat("skyline", "0d1328", rough=0.9)
    for i in range(18):
        x = -3.5 + i * 0.45 + rng.uniform(-0.1, 0.1)
        h = rng.uniform(0.6, 2.2)
        box((x, 9.0, 0.9 + h / 2), (0.4, 0.3, h), skyline)
        for k in range(int(h / 0.25)):
            if rng.random() < 0.45:
                box((x + rng.uniform(-0.12, 0.12), 8.84, 1.0 + k * 0.25), (0.05, 0.02, 0.07), city)
    sphere((1.2, 12, 3.2), 0.35, mat("moon", "ffffff", emit="f4f1e0", strength=6.0))
    light("AREA", (0.3, 3.4, 2.0), 120, "8fb4ff", size=2.4, target=(0.3, 0, 0.5))
    # A secretária, o monitor aceso com o cartaz da Taça e o candeeiro.
    desk = mat("desk", "c9a27a", rough=0.45)
    box((0.3, 3.35, 0.78), (2.6, 0.9, 0.08), desk, bevel=0.02)
    for dx in (-1.2, 1.2):
        box((0.3 + dx, 3.35, 0.38), (0.08, 0.8, 0.76), desk)
    box((0.1, 3.5, 1.3), (1.1, 0.06, 0.66), mat("monitor", "15171c", rough=0.3), bevel=0.02)
    box((0.1, 3.46, 1.3), (1.0, 0.02, 0.56), mat("screen", "0b1a2a", emit="2fd8ff", strength=3.0))
    text("TAÇA CHARGE ARENA", (0.1, 3.44, 1.36), 0.07, mat("screen_txt", "ffffff", emit="ffe45c", strength=8.0), rot=(math.pi / 2, 0, 0))
    text("INSCRIÇÕES ABERTAS", (0.1, 3.44, 1.22), 0.05, mat("screen_txt2", "ffffff", emit="ffffff", strength=5.0), rot=(math.pi / 2, 0, 0))
    box((0.1, 3.55, 0.92), (0.1, 0.1, 0.25), mat("stand", "15171c", rough=0.3))
    box((0.1, 3.05, 0.83), (0.7, 0.22, 0.03), mat("keys", "2a2e36", rough=0.4))
    cylinder((-0.95, 3.3, 0.9), 0.06, 0.2, mat("mug", "ec8a72", rough=0.3))
    lamp_m = mat("lamp", "ffd23f", rough=0.35, metal=0.2)
    cylinder((1.2, 3.45, 0.84), 0.12, 0.04, lamp_m)
    cylinder((1.2, 3.45, 1.1), 0.02, 0.5, lamp_m)
    cylinder((1.1, 3.35, 1.35), 0.14, 0.18, lamp_m, rot=(math.radians(35), 0, math.radians(20)))
    light("POINT", (1.05, 3.25, 1.25), 160, "ffc27a", size=0.1)
    light("AREA", (0.1, 3.2, 1.3), 25, "4fd8ff", size=1.0, target=(0.1, 0, 1.2))
    for k in range(4):
        box((-1.45 + k * 0.09, 3.45, 0.93), (0.07, 0.3, 0.22 + rng.uniform(0, 0.1)), mat("book%d" % k, rng.choice(["b5533c", "3f7f7a", "ffd23f", "4c5f8a"]), rough=0.6))
    # A cama à direita, um cartaz na parede e uma estante com robôs de brincar.
    box((2.8, 1.4, 0.3), (1.8, 3.2, 0.5), mat("bedframe", "5a3a28", rough=0.6), bevel=0.03)
    box((2.8, 1.4, 0.62), (1.7, 3.1, 0.18), mat("blanket", "4fd3b9", rough=0.9), bevel=0.06)
    box((2.8, 2.7, 0.78), (1.3, 0.45, 0.16), mat("pillow", "f4f1e8", rough=0.9), bevel=0.07)
    box((-3.88, 1.2, 1.9), (0.02, 1.2, 1.6), mat("poster", "1b2a55", rough=0.7))
    text("CHARGE", (-3.86, 1.2, 2.25), 0.26, mat("poster_t", "ffffff", emit="ffd23f", strength=1.5), rot=(math.pi / 2, 0, -math.pi / 2))
    text("ARENA", (-3.86, 1.2, 1.95), 0.26, mat("poster_t2", "ffffff", emit="4ff0ff", strength=1.5), rot=(math.pi / 2, 0, -math.pi / 2))
    shelf = mat("shelf", "c9a27a", rough=0.45)
    box((-3.8, -0.8, 1.6), (0.3, 1.4, 0.05), shelf)
    for k in range(4):
        color = ["4fd3b9", "ec8a72", "ffd23f", "8a84a8"][k]
        box((-3.75, -1.3 + k * 0.33, 1.72), (0.14, 0.14, 0.18), mat("toy%d" % k, color, rough=0.4), bevel=0.02)
    # Um fio de luzes quentes ao longo da parede, por cima da janela.
    bulb = mat("fairy", "ffffff", emit="ffcf7a", strength=25.0)
    for k in range(26):
        t = k / 25
        x = -3.6 + 7.2 * t
        z = 3.05 - 0.25 * math.sin(t * math.pi * 3) ** 2
        sphere((x, 3.85, z), 0.035, bulb)
    light("AREA", (0, 3.6, 3.0), 60, "ffcf7a", size=6.0, target=(0, 0, 1.0))
    # Um tapete e a luz fria da noite a entrar.
    box((0.5, 0.8, 0.005), (2.4, 1.6, 0.01), mat("rug", "8a5a7a", rough=1.0))
    # Luz de teto suave e quente, para o quarto se ler.
    light("AREA", (0, 1.0, 3.2), 180, "ffd6a8", size=3.0, target=(0, 1.0, 0))
    camera((-0.9, -0.9, 1.35), (0.25, 3.6, 1.55), lens=18)
    render("quarto", samples)


def crowd_mesh(name, radius_x, radius_y, rows, rng):
    """Bancadas em anel com público: degraus e milhares de cabeças coloridas num só objeto."""
    step = mat("stand", "2a2f3c", rough=0.8)
    people = [mat("fan%d" % i, c, rough=0.6) for i, c in enumerate(["ec8a72", "4fd3b9", "ffd23f", "f4f1e8", "5fcfb7", "ff4fb8", "7a8cff", "e8a92e"])]
    for r in range(rows):
        rx = radius_x + r * 1.1
        ry = radius_y + r * 1.1
        z = 0.6 + r * 0.8
        segments = int(2 * math.pi * rx / 1.2)
        for s in range(segments):
            a = 2 * math.pi * s / segments
            if math.sin(a) < -0.55:
                continue  # O lado da câmara fica aberto.
            x, y = math.cos(a) * rx, math.sin(a) * ry
            box((x, y, z - 0.3), (1.2, 1.1, 0.6), step, rot=a)
            for k in range(2):
                off = (k - 0.5) * 0.5
                px = x - math.sin(a) * off
                py = y + math.cos(a) * off
                body = rng.choice(people)
                box((px, py, z + 0.25), (0.34, 0.3, 0.5), body, rot=a)
                sphere((px, py, z + 0.62), 0.14, rng.choice(people))


def beam(loc, target, color, length=40, radius=2.2):
    """Feixe de holofote falso: um cone emissivo e translúcido."""
    direction = (Vector(target) - Vector(loc)).normalized()
    m = bpy.data.materials.new("beam" + color)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    out = nodes["Material Output"]
    nodes.remove(nodes["Principled BSDF"])
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs[0].default_value = (*hex_rgb(color), 1)
    emit.inputs[1].default_value = 1.6
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.12
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emit.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs[0])
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.2, radius2=radius, depth=length,
                                    location=Vector(loc) + direction * length / 2)
    cone = bpy.context.active_object
    cone.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    cone.data.materials.append(m)
    cone.visible_shadow = False
    return cone


def scene_estadio(samples):
    reset()
    rng = random.Random(11)
    world_color("0c1433", 1.0)
    # A arena flutuante do jogo ao centro: plataforma, bordo aceso, muralhas das duas equipas.
    box((0, 0, -0.4), (60, 60, 0.2), mat("pit", "1a2240", rough=0.25, metal=0.3))
    box((0, 0, 0.2), (9, 16, 0.6), mat("platform", "d9dee3", rough=0.5), bevel=0.3)
    box((0, 0, 0.52), (8.2, 15.2, 0.05), mat("court", "cfe7f2", rough=0.35, emit="9fd8ff", strength=0.2))
    for sx in (-1, 1):
        box((sx * 4.55, 0, 0.55), (0.1, 16, 0.1), mat("edge", "4ff0ff", emit="4ff0ff", strength=12.0))
    for sy, color in ((-1, "4fd3b9"), (1, "ec8a72")):
        for i in range(8):
            box((-3.2 + i * 0.9, sy * 6.2, 0.85), (0.8, 0.5, 0.5), mat("brick" + color, color, rough=0.5), bevel=0.08)
            box((-3.2 + i * 0.9, sy * 6.2, 1.13), (0.8, 0.5, 0.08), mat("cushion", "f4f1e8", rough=0.7), bevel=0.03)
    crowd_mesh("crowd", 13, 17, 9, rng)
    # O ecrã gigante do outro lado, com o nome da Taça.
    box((0, 30, 12), (22, 1.0, 9), mat("screen_frame", "15171c", rough=0.3), bevel=0.2)
    box((0, 29.45, 12), (20.5, 0.1, 7.8), mat("screen_bg", "0b1430", emit="1b3a8a", strength=2.5))
    text("TAÇA", (0, 29.3, 13.8), 3.0, mat("cup_t", "ffffff", emit="ffd23f", strength=12.0), rot=(math.pi / 2, 0, 0))
    text("CHARGE ARENA", (0, 29.3, 10.6), 2.3, mat("cup_t2", "ffffff", emit="ffffff", strength=9.0), rot=(math.pi / 2, 0, 0))
    light("AREA", (0, 27, 12), 3000, "5f8cff", size=18, target=(0, 0, 0))
    # Mastros com holofotes e os seus feixes.
    pole = mat("mast", "2c3036", rough=0.4, metal=0.6)
    lamp = mat("lampface", "ffffff", emit="ffffff", strength=50.0)
    for x, y, color in ((-18, 20, "ffe7b0"), (18, 20, "ffe7b0"), (-20, -6, "9fd8ff"), (20, -6, "ff9fd0")):
        cylinder((x, y, 12), 0.35, 24, pole)
        box((x, y, 24.3), (3.0, 0.6, 1.4), lamp)
        light("SPOT", (x, y, 24), 60000, color, size=1.0, target=(0, 0, 0), spot=math.radians(28))
        beam((x, y, 24), (x * 0.1, y * 0.1, 0), color)
    # A cobertura do estádio: um anel de treliça com uma fiada de luzes, e o céu estrelado.
    roof = mat("roof", "3a4152", rough=0.5, metal=0.5)
    roof_light = mat("roof_light", "ffffff", emit="fff1d0", strength=30.0)
    for k in range(64):
        a = 2 * math.pi * k / 64
        if math.sin(a) < -0.7:
            continue
        x, y = math.cos(a) * 30, math.sin(a) * 34
        box((x, y, 30), (3.2, 0.5, 0.6), roof, rot=a + math.pi / 2)
        box((x * 0.94, y * 0.94, 29.4), (0.6, 0.6, 0.25), roof_light)
        cylinder((x, y, 22), 0.25, 16, roof)
    star = mat("star", "ffffff", emit="ffffff", strength=8.0)
    for k in range(220):
        a = rng.uniform(0, 2 * math.pi)
        box((rng.uniform(-80, 80), rng.uniform(60, 90), rng.uniform(25, 90)), (0.12, 0.12, 0.12), star)
    light("AREA", (0, 10, 40), 4000, "6f7fff", size=40, target=(0, 10, 0))
    # Luz de palco sobre a arena e confetis no ar.
    light("AREA", (0, -4, 18), 5000, "ffffff", size=10, target=(0, 0, 0))
    for k in range(260):
        c = rng.choice(["ffd23f", "4ff0ff", "ff4fb8", "ffffff", "7cff6b"])
        box((rng.uniform(-14, 14), rng.uniform(-6, 26), rng.uniform(3, 18)), (0.18, 0.02, 0.12),
            mat("conf" + c, c, emit=c, strength=2.0), rot=rng.uniform(0, 6.28))
    camera((0, -24, 7.5), (0, 8, 7.0), lens=22)
    render("estadio", samples)


SCENES = {"rua": scene_rua, "quarto": scene_quarto, "estadio": scene_estadio}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    quick = "--quick" in args
    names = [a for a in args if a in SCENES] or list(SCENES)
    for name in names:
        SCENES[name](16 if quick else (64 if name == "estadio" else 96))


if __name__ == "__main__":
    main()
