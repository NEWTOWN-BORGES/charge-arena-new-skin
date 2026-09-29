extends Node3D
## Stylized floating stadium. Beveled reusable meshes, soft decals and bounded VFX.
const CYAN = Color("72ddc6")
const CORAL = Color("ef947e")
const LIME = Color("dbdf9a")
const CREAM = Color("dedbca")
const DARK = Color("223c46")
const GOLD = Color("d2ad73")
# Accents of the boss skins (their main colours live in Skins.CATALOG).
const COPPER = Color("c07a45")
const WOOD = Color("6e4a2e")
const STORM_YELLOW = Color("e0b84a")
const Rules = preload("res://scripts/arena_rules.gd")
const Skins = preload("res://scripts/skins.gd")
const Powers = preload("res://scripts/powers.gd")
const SOFT_DISC = preload("res://shaders/soft_disc.gdshader")
const GameFeel = preload("res://scripts/game_feel.gd")
const Robots = preload("res://scripts/robots.gd")
const ArenaTheme = preload("res://scripts/arena_theme.gd")
const ArenaDressing = preload("res://scripts/arena_dressing.gd")
const ArenaSky = preload("res://scripts/arena_sky.gd")
const ArenaGround = preload("res://scripts/arena_ground.gd")
const ArenaSea = preload("res://scripts/arena_sea.gd")
const ArenaSpace = preload("res://scripts/arena_space.gd")
const ArenaCity = preload("res://scripts/arena_city.gd")
const ArenaDiorama = preload("res://scripts/arena_diorama.gd")
const ArenaLife = preload("res://scripts/arena_life.gd")
const Fx = preload("res://scripts/fx.gd")
const ORB = preload("res://shaders/fx_orb.gdshader")
const CombatFinish = preload("res://scripts/combat_finish.gd")
const ArenaFinish = preload("res://scripts/arena_finish.gd")
const ArtStyle = preload("res://scripts/art_style.gd")
const GRASS = preload("res://shaders/grass_painted.gdshader")
const GLASS = preload("res://shaders/glass.gdshader")
const GUIDE_DOTS = 30
# Projectile size per power: normal, explosive, machine-gun round, air pellet.
# Plain, blast, machine gun, fan, marksman, cluster shell, ricochet, shard.
const POWER_BALL_SCALE = [1.0, 1.4, 0.95, 0.7, 0.85, 1.6, 1.0, 0.7]
# A closer gameplay framing makes the bevels, pilots and particles easier to
# read while the enlarged walls still remain fully visible.
const LANDSCAPE_SIZE = 17.0 * Rules.MAP_SCALE
var units: Array = []
var crafting_pilot = false
var brick_nodes: Array = []
var goals: Array = []
var projectiles: Dictionary = {}
var sentries: Dictionary = {}
var effects: Array = []
var presentation_environment: Environment
# The scenery the dressing built (exported to be baked), and whether this build is for that.
var world_nodes: Array = []
# Pivots of the moving scenery (clouds, fish schools, asteroids) and their turn per second.
var drifters: Array = []
var bake_export = false
var court_material: ShaderMaterial
# The arena environment (colours of floor, sky, blocks and stadium); see arena_theme.gd.
var theme: Dictionary = {}
# GPU particle batches (sparks, glows, smoke, rings, debris); see fx.gd.
var fx: Node3D
# Projectile nodes waiting to be reused.
var orb_pool: Array[Node3D] = []
var camera: Camera3D
var aim_line: Node3D
var materials: Dictionary = {}
var shapes: Dictionary = {}
var phase_before = ""
var stuns_before: Array = [0.0, 0.0]
# The run along the rail: a step cycle per pilot, how fast it is going (smoothed) and to
# which side of its own body it is heading.
var gait_phase: Array = [0.0, 0.0]
var gait_speed: Array = [0.0, 0.0]
var gait_side: Array = [0.0, 0.0]
var clock = 0.0
var ball_previous: Dictionary = {}
var trail_timer = 0.0
var booster_nodes: Array = []
var obstacle_nodes: Array = []
# True while the two walls are crossing over, so they are put back down exactly once.
var carrying = false
# Whether each side's wall is currently showing its crystal plating.
var plated: Array = [false, false]
# The running total of damage each side is taking from the power landing right now. One
# number that climbs answers the only question worth asking - how much did that take off
# in all - where forty little ones only buried the field in digits.
var tally: Array = [{}, {}]
const TALLY_HOLD = 1.0
const TALLY_FADE = 0.35
var effect_limit = 112
# Floating numbers draw on top of that budget instead of competing with it. They are text,
# they cost almost nothing, and they were the first thing dropped in a crowded frame -
# which is the frame where the player most needs to know what just happened.
const NUMBER_ALLOWANCE = 30
# How high above the floor the storm and the meteors come from.
const SKY_TOP = 8.4
# And how tall the bolt itself is drawn.
const BOLT_TOP = 5.4
var trail_interval = 0.035
var brick_instances: Array = []
var brick_batches: Array = []
var static_batch_count = 0
var previous_motion: Dictionary = {}
var view_bounds = Rect2()
# The layout this stadium was built for (see Rules.default_map).
var map: Dictionary = {}
var walls: Array = []
var unit_skins: Array = [0, 0]
# Which pilots glare: season two's corrupted friends (the story sets it).
var angry: Array = [false, false]
# Cape, goal curtain and repulsor rings, one set per team.
var power_nodes: Array = []
# Campaign bosses wear their team's red until beaten (see Skins.colors).
var unit_tints: Array = [false, false]
# A colour that replaces the team's on the pilot itself, for opponents with no palette.
var unit_hues: Array = ["", ""]
var shot_colors: Array = [CYAN, CORAL]
var aim_guide: Node3D
var guide_dots: MultiMeshInstance3D
# How many guide dots the current prediction shows.
var guide_shown = 0
var guide_marker: MeshInstance3D
var guide_enabled = true
var guide_timer = 0.0
var guide_angle = INF
var soft_disc_nodes: Array = []
var secondary_light: DirectionalLight3D
var quality_level = 0
# Camera shake: a strength that decays, added to the camera's resting place.
var camera_home = Vector3(0, 21.8, 18.3)
# Shared tuning for everything the player feels; main.gd hands in the same object.
var feel = GameFeel.new()
# Layered, directional camera shakes: {strength, age, life, hz, dir, seed}.
var shakes: Array = []
# Visual hit-stop and time dilation: the effects' own clock, which can hold still or slow
# down for a beat while the match itself runs on untouched.
var fx_clock = 0.0
# Shader warm-up: invisible samples of every kind of effect material, drawn for a few frames
# while nothing is happening yet, so no effect compiles its shader in the middle of a match.
var warm_root: Node3D
var warm_frames = 0
var hitstop_left = 0.0
var dilation_left = 0.0
var dilation_rate = 1.0
var shake_scale = 0.55
var shot_age = [1.0, 1.0]
var feedback_pool: Array[Node3D] = []
var feedback_allocated = 0
const FEEDBACK_POOL_LIMIT = 80
var brick_reactions: Dictionary = {}
# Effects waiting for their moment: {"time": seconds, "call": Callable}.
var pending: Array = []
# Reuse lamps instead of creating/destroying them during ultimates; particles live in the
# fixed GPU batches of fx.gd.
const LIGHT_POOL_LIMIT = 8
var light_pool: Array[OmniLight3D] = []
var active_lights = 0
# Ultimate mood: from the first spark of a windup to the last blow of the ultimate, the sky
# and the room dim a little, so what the ultimate throws out is the brightest thing in the
# arena. Big blasts light the whole field for a moment through the key light itself (free on
# a phone, unlike a lamp), and the sun ray keeps it lit warm for as long as it burns.
const MOOD_DARK = 0.34
const MOOD_SKY_DARK = 0.42
var key_light: DirectionalLight3D
var backdrop_mat: ShaderMaterial
var mood_base: Dictionary = {}
var mood = 0.0
var mood_hold = 0.0
var sun_glow = 0.0
var laser_glow = 0.0
var field_light = 0.0
var field_decay = 1.0
var field_tint = Color.WHITE
# Two lamps per side that follow the laser and the sun ray: one halfway down the beam,
# one where it lands. Always part of the scene (warmed with the shaders), dark when idle.
var beam_lamps: Array = []

func prepare_fx_pool() -> void:
	for i in range(LIGHT_POOL_LIMIT):
		var lamp = OmniLight3D.new()
		lamp.shadow_enabled = false
		lamp.hide()
		add_child(lamp)
		light_pool.append(lamp)
	beam_lamps.clear()
	for team in range(2):
		var pair: Array = []
		for i in range(2):
			var lamp = OmniLight3D.new()
			lamp.shadow_enabled = false
			lamp.light_energy = 0.0
			lamp.omni_range = 0.1
			lamp.position = Vector3(0, -50, 0)
			add_child(lamp)
			pair.append(lamp)
		beam_lamps.append(pair)

func material(color: Color, luminous: bool = false) -> Material:
	var key = str(color) + str(luminous)
	if materials.has(key):
		return materials[key]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.52
	mat.metallic = 0.12
	if color == CREAM:
		mat.roughness = 0.48
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.22
		mat.clearcoat_roughness = 0.42
	elif color == GOLD:
		mat.metallic = 0.72
		mat.roughness = 0.32
	elif color == DARK:
		mat.roughness = 0.76
	if luminous:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.set_meta("always_unshaded", luminous)
	if color.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ArenaFinish.surface(mat, quality_level)
	if ArtStyle.painted_nature() and not luminous and String(mat.get_meta("surface_finish", "")) == "grass":
		# The meadow, painted and combed by the wind.
		var meadow = ShaderMaterial.new()
		meadow.shader = GRASS
		meadow.set_shader_parameter("grass", color)
		materials[key] = meadow
		return meadow
	materials[key] = mat
	return mat

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color, luminous: bool = false) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color, luminous)
	node.position = pos
	# Soft contact decals avoid expensive shadow maps and shadow acne on phones.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal((c - a).cross(b - a).normalized())
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func beveled_shape(dim: Vector3, bevel: float) -> ArrayMesh:
	var key = str(dim) + str(bevel)
	if shapes.has(key):
		return shapes[key]
	var half = dim * 0.5
	var b = minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.8)
	var rings: Array = []
	for layer in range(4):
		var inset = b if layer == 0 or layer == 3 else 0.0
		var x = half.x - inset
		var z = half.z - inset
		var y = [-half.y, -half.y + b, half.y - b, half.y][layer]
		var cut = minf(b, minf(x, z) * 0.5)
		rings.append([Vector3(-x + cut, y, -z), Vector3(x - cut, y, -z), Vector3(x, y, -z + cut), Vector3(x, y, z - cut), Vector3(x - cut, y, z), Vector3(-x + cut, y, z), Vector3(-x, y, z - cut), Vector3(-x, y, -z + cut)])
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var j = (i + 1) % 8
		triangle(st, Vector3(0, half.y, 0), rings[3][i], rings[3][j])
		triangle(st, Vector3(0, -half.y, 0), rings[0][j], rings[0][i])
		for layer in range(3):
			triangle(st, rings[layer][i], rings[layer][j], rings[layer + 1][j])
			triangle(st, rings[layer][i], rings[layer + 1][j], rings[layer + 1][i])
	var shape = st.commit()
	shapes[key] = shape
	return shape

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color, luminous: bool = false, bevel: float = 0.06) -> MeshInstance3D:
	if crafting_pilot and not luminous and dimensions.x * dimensions.y * dimensions.z > 0.004 and minf(dimensions.x, minf(dimensions.y, dimensions.z)) > 0.07:
		return mesh(parent, rounded_pilot_shape(dimensions, maxf(bevel, 0.07)), pos, color, luminous)
	return mesh(parent, beveled_shape(dimensions, bevel), pos, color, luminous)

func rounded_pilot_shape(dim: Vector3, radius: float) -> ArrayMesh:
	var r = minf(radius, minf(dim.x, minf(dim.y, dim.z)) * 0.45)
	var key = "pilot_round" + str(dim) + str(r)
	if shapes.has(key): return shapes[key]
	var half = dim * 0.5
	var inner = half - Vector3.ONE * r
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six rounded patches with analytic normals: smooth enamel, flat central panels.
	for axis in range(3):
		var u = (axis + 1) % 3
		var v = (axis + 2) % 3
		var us = [-half[u], -half[u] + r * 0.3, -inner[u], inner[u], half[u] - r * 0.3, half[u]]
		var vs = [-half[v], -half[v] + r * 0.3, -inner[v], inner[v], half[v] - r * 0.3, half[v]]
		for sign_value in [-1.0, 1.0]:
			for x in range(5):
				for y in range(5):
					var order = [Vector2i(x,y), Vector2i(x,y+1), Vector2i(x+1,y+1), Vector2i(x,y), Vector2i(x+1,y+1), Vector2i(x+1,y)]
					if sign_value < 0: order.reverse()
					for at in order:
						var point = Vector3.ZERO
						point[axis] = half[axis] * sign_value
						point[u] = us[at.x]
						point[v] = vs[at.y]
						var core = point.clamp(-inner, inner)
						var normal = (point - core).normalized()
						st.set_normal(normal)
						st.add_vertex(core + normal * r)
	var shape = st.commit()
	shapes[key] = shape
	return shape

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, luminous: bool = false, segments: int = 48) -> MeshInstance3D:
	var key = "c" + str(radius) + str(height) + str(segments)
	if not shapes.has(key):
		var shape = CylinderMesh.new()
		shape.top_radius = radius
		shape.bottom_radius = radius
		shape.height = height
		shape.radial_segments = segments
		shapes[key] = shape
	return mesh(parent, shapes[key], pos, color, luminous)

func cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, luminous: bool = false, segments: int = 24) -> MeshInstance3D:
	var key = "cone" + str(radius) + str(height) + str(segments)
	if not shapes.has(key):
		var shape = CylinderMesh.new()
		shape.top_radius = 0.0
		shape.bottom_radius = radius
		shape.height = height
		shape.radial_segments = segments
		shapes[key] = shape
	return mesh(parent, shapes[key], pos, color, luminous)

func sphere(parent: Node3D, pos: Vector3, scale_value: Vector3, color: Color, luminous: bool = false) -> MeshInstance3D:
	# Spend geometry on helmet silhouettes, not on sparks only a few pixels wide.
	var diameter = maxf(scale_value.x, maxf(scale_value.y, scale_value.z))
	var detail = 40 if diameter >= 0.65 else (24 if diameter >= 0.3 else 12)
	var key = "sphere" + str(detail)
	if not shapes.has(key):
		var shape = SphereMesh.new()
		shape.radius = 0.5
		shape.height = 1.0
		shape.radial_segments = detail
		shape.rings = detail / 2
		shapes[key] = shape
	var node = mesh(parent, shapes[key], pos, color, luminous)
	node.scale = scale_value
	return node

func torus(parent: Node3D, pos: Vector3, radius: float, thickness: float, color: Color, luminous: bool = true) -> MeshInstance3D:
	var key = "r" + str(radius) + str(thickness)
	if not shapes.has(key):
		var shape = TorusMesh.new()
		shape.inner_radius = radius - thickness
		shape.outer_radius = radius + thickness
		shape.rings = 64
		shape.ring_segments = 8
		shapes[key] = shape
	return mesh(parent, shapes[key], pos, color, luminous)

func segment(parent: Node3D, a: Vector3, b: Vector3, width: float, height: float, color: Color, luminous: bool = false) -> MeshInstance3D:
	var node = box(parent, (a + b) * 0.5, Vector3(a.distance_to(b), height, width), color, luminous)
	node.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	return node

func soft_disc(parent: Node3D, pos: Vector3, size_value: Vector2, color: Color) -> MeshInstance3D:
	var shape_key = "plane" + str(size_value)
	if not shapes.has(shape_key):
		var shape = PlaneMesh.new()
		shape.size = size_value
		shapes[shape_key] = shape
	var node = mesh(parent, shapes[shape_key], pos, color, true)
	node.material_override = soft_disc_material(color)
	soft_disc_nodes.append(node)
	node.visible = quality_level > 0
	return node

func light_pool_material(color: Color) -> ShaderMaterial:
	# The pool of light a lit round throws on the court: the soft disc, added to the floor
	# instead of laid over it, so it brightens even the dark stone.
	var key = "pool" + str(color)
	if not materials.has(key):
		if not materials.has("pool:shader"):
			var shader = Shader.new()
			shader.code = SOFT_DISC.code.replace("render_mode unshaded,", "render_mode blend_add, unshaded,")
			materials["pool:shader"] = shader
		var mat = ShaderMaterial.new()
		mat.shader = materials["pool:shader"]
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("falloff", 2.4)
		materials[key] = mat
	return materials[key]

func soft_disc_material(color: Color) -> ShaderMaterial:
	var key = "disc" + str(color)
	if not materials.has(key):
		var mat = ShaderMaterial.new()
		mat.shader = SOFT_DISC
		mat.set_shader_parameter("tint", color)
		materials[key] = mat
	return materials[key]

func set_shadows(on: bool) -> void:
	# Options switched real shadows on or off: the sun is set up again from the world's light.
	if ArtStyle.real_shadows == on:
		return
	ArtStyle.real_shadows = on
	if not is_instance_valid(key_light):
		return
	key_light.light_color = theme.get("key", theme.get("sun", Color("fff3e6")))
	key_light.light_energy = float(theme.get("key_energy", 1.1))
	key_light.rotation_degrees = Vector3(-52, -35, 0)
	ArtStyle.key_light(key_light, quality_level)
	capture_mood_base()

func set_quality(level: int) -> void:
	quality_level = clampi(level, 0, 2)
	if presentation_environment != null: ArenaFinish.environment(presentation_environment, quality_level)
	capture_mood_base()
	if court_material != null: court_material.set_shader_parameter("finish_quality", float(quality_level))
	Robots.set_quality(self, quality_level)
	if fx != null: fx.quality = quality_level
	# Transparent contact decals are the largest group of separate draw calls.
	# Keep them in the two prettier profiles and remove them entirely on Leve.
	for node in soft_disc_nodes:
		if is_instance_valid(node):
			node.visible = quality_level > 0
	if is_instance_valid(secondary_light):
		secondary_light.visible = quality_level > 0
	for mat in materials.values():
		if mat is StandardMaterial3D:
			# Leve lights per vertex: the studio's soft volume without per-pixel light.
			ArenaFinish.surface(mat, quality_level)

func world_label(text: String, pos: Vector3, color: Color, font_size: int = 48, horizontal: bool = true) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.position = pos
	if horizontal:
		label.rotation_degrees.x = -90
	add_child(label)
	return label

func platform(outline: Array, height: float, depth: float, color: Color) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The cap fans from the outline's own middle: a pad off to the side fanned from the world
	# origin ran its triangles under the field (seen through the glass floor in space).
	var middle := Vector2.ZERO
	for p in outline:
		middle += p
	middle /= maxf(outline.size(), 1)
	for i in range(outline.size()):
		var a = Vector3(outline[i].x, height, outline[i].y)
		var b = Vector3(outline[(i + 1) % outline.size()].x, height, outline[(i + 1) % outline.size()].y)
		triangle(st, Vector3(middle.x, height, middle.y), a, b)
		triangle(st, a, a - Vector3.UP * depth, b - Vector3.UP * depth)
		triangle(st, a, b - Vector3.UP * depth, b)
	return mesh(self, st.commit(), Vector3.ZERO, color)

func build(new_map: Dictionary = {}) -> void:
	prepare_fx_pool()
	map = new_map if not new_map.is_empty() else Rules.default_map()
	Rules.apply_stretch(map)
	walls = Rules.map_outline(map)
	theme = ArenaTheme.for_map(map)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CANVAS
	environment.environment.background_canvas_max_layer = -1
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b0c6c5")
	presentation_environment = environment.environment
	ArenaFinish.environment(presentation_environment, quality_level)
	ArenaFinish.fog(presentation_environment, theme.get("fog", {}))
	# The season-two worlds bring their own night light (dawn, dusk or midnight).
	if theme.has("ambient"):
		presentation_environment.ambient_light_color = theme.ambient
		presentation_environment.ambient_light_energy *= float(theme.get("ambient_energy", 1.0))
		# No bright studio dome in the reflections: the night stays dark.
		presentation_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	add_child(environment)
	var background_layer = CanvasLayer.new()
	background_layer.layer = -1
	add_child(background_layer)
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_mat = ShaderMaterial.new()
	bg_mat.shader = preload("res://shaders/backdrop.gdshader")
	for key in ["sky_top", "sky_mid", "sky_low"]:
		bg_mat.set_shader_parameter(key, theme[key])
	bg_mat.set_shader_parameter("stars", theme.get("stars", 0.0))
	# A day sky gets its sun and high clouds; night, space and the sea keep their own.
	bg_mat.set_shader_parameter("daylight", 1.0 if ArtStyle.day_sky(theme) else 0.0)
	background.material = bg_mat
	backdrop_mat = bg_mat
	background_layer.add_child(background)
	# Studio light: a large warm key from the upper left and a cool, gentle fill from behind
	# on the right. The grey dome of the environment does the rest.
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -35, 0)
	light.light_color = theme.get("key", theme.get("sun", Color("fff3e6")))
	light.light_energy = float(theme.get("key_energy", 1.1))
	light.shadow_enabled = false
	ArtStyle.key_light(light, quality_level)
	add_child(light)
	key_light = light
	secondary_light = DirectionalLight3D.new()
	secondary_light.rotation_degrees = Vector3(-30, 145, 0)
	secondary_light.light_color = theme.get("fill", Color("e4ecf6"))
	secondary_light.light_energy = float(theme.get("fill_energy", 0.35))
	add_child(secondary_light)
	ArtStyle.floodlights(self)
	capture_mood_base()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = LANDSCAPE_SIZE
	camera.position = Vector3(0, 21.8, 18.3)
	add_child(camera)
	camera.look_at(Vector3(0, -0.15, 0))
	camera.current = true
	if theme.has("neon"):
		build_neon_rim()
	# Each world builds its own ground around the field (arena_theme.gd names it); a theme
	# without one falls back to the studio plinth and stands.
	# A bare map (the test arena) is just the floor: no plinth, no world around it.
	var dressing = "bare" if map.get("bare", false) else String(theme.get("dressing", ""))
	var outer: Array = []
	for p in walls:
		outer.append(p * Vector2(1.16, 1.07))
	# The plinth the arena floats on: a mid grey of the theme's frame, so the platform reads as
	# a soft studio object and not a dark hole around the field.
	if dressing == "":
		platform(outer, -0.28, 0.75, theme.frame.lerp(theme.stand, 0.55))
		var under: Array = []
		for p in outer:
			under.append(p * 0.97)
		platform(under, -0.98, 0.22, theme.frame.lerp(theme.stand, 0.3))
	# Floating plinth silhouette and a painted hexagon floor without coplanar seams.
	var court = platform(walls, 0.0, 0.28, Color.WHITE)
	var court_mat = ShaderMaterial.new()
	court_mat.shader = preload("res://shaders/court.gdshader")
	if theme.get("glass_floor", false):
		# Space: plates of glass, seams and paint solid, the stars showing through.
		var glass = Shader.new()
		# Only the faces towards the camera: seen through the top, the slab's own underside
		# and inner sides made a pale band across the field.
		glass.code = court_mat.shader.code.replace("	SPECULAR = 0.45;", "	SPECULAR = 0.45;\n	ALPHA = mix(0.82, 1.0, max(seam, paint));").replace("cull_disabled", "cull_back")
		court_mat.shader = glass
		# Glass is drawn with the other see-through things, sorted by distance: a shot, a beam
		# or an ultimate over the field could fall behind it and vanish under the floor. The
		# floor is always the first of them, so everything on it draws on top.
		court_mat.render_priority = Material.RENDER_PRIORITY_MIN
	court_mat.set_shader_parameter("surface_grain", ArenaFinish.SURFACES.ceramic[0])
	court_material = court_mat
	court_mat.set_shader_parameter("floor_color", theme.floor)
	court_mat.set_shader_parameter("floor_alt", theme.floor_alt)
	court_mat.set_shader_parameter("seam_color", theme.seam)
	court_mat.set_shader_parameter("line_color", theme.line)
	court_mat.set_shader_parameter("team_near", CYAN)
	court_mat.set_shader_parameter("team_far", CORAL)
	ArtStyle.court(court_mat)
	court.material_override = court_mat
	# A world whose light was baked in Blender for this map (tools/export_world.gd, then
	# tools/blender/bake_scene.py) replaces the lit dressing; the pieces the dressing adds are
	# kept in `world_nodes` so they can be exported to be baked.
	var first_world_node = get_child_count()
	var baked_world = ArenaDiorama.baked_path(String(map.get("id", "")))
	if dressing != "" and dressing != "diorama" and dressing != "bare" and not bake_export and ResourceLoader.exists(baked_world):
		dressing = "baked"
	match dressing:
		"bare":
			build_wall_segments()
		"baked":
			ArenaDiorama.build(self, theme, baked_world)
		"sky":
			# The floating sky arena: deck, hull, armoured walls and deck furniture from the kit.
			ArenaSky.build(self, theme)
		"ground":
			ArenaGround.build(self, theme)
		"sea":
			ArenaSea.build(self, theme)
		"space":
			ArenaSpace.build(self, theme)
		"city":
			ArenaCity.build(self, theme)
		"diorama":
			# The baked island brings its own teal tiled floor; the neutral court is laid a hair
			# above it, so shots and powers read on grey here too.
			court.position.y = 0.014
			ArenaDiorama.build(self, theme)
		_:
			soft_disc(self, Vector3(0, -1.32, 0.3), Vector2(19, 23), Color(0.005, 0.015, 0.025, 0.7))
			ArenaDressing.perimeter(self, theme)
			ArenaDressing.stadium(self, theme, quality_level)
	# Life on top of the world: trees, flowers, mountains on the horizon, drifting clouds.
	if not bake_export:
		ArenaLife.build(self, theme, String(theme.get("dressing", "")))
	world_nodes = get_children().slice(first_world_node)
	world_label("C H A R G E", Vector3(0, 0.024, 1.34), theme.line, 30)
	for team in range(2):
		build_goal(team)
		units.append(build_player(CYAN if team == 0 else CORAL, team))
	build_bricks()
	build_boosters()
	build_obstacles()
	build_barriers()
	build_power_effects()
	# The short aim line and the dotted shot guide are one MultiMesh each: a draw apiece
	# instead of one per dot.
	aim_line = Node3D.new()
	add_child(aim_line)
	var line_dots = dot_batch(aim_line, 8, 0.031)
	for i in range(8):
		var width = 1.0 if i < 5 else 0.022 / 0.031
		line_dots.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(width, 1, width)), Vector3(0, 0, -0.9 - i * 0.24)))
		line_dots.multimesh.set_instance_color(i, Color(CREAM, 0.55 - i * 0.045))
	aim_guide = Node3D.new()
	add_child(aim_guide)
	guide_dots = dot_batch(aim_guide, GUIDE_DOTS, 0.045)
	guide_dots.multimesh.visible_instance_count = 0
	guide_marker = torus(aim_guide, Vector3.ZERO, 0.42, 0.024, LIME)
	aim_guide.hide()
	fx = Fx.new()
	fx.name = "Fx"
	fx.quality = quality_level
	add_child(fx)
	CombatFinish.prepare(self)
	batch_bricks()
	batch_static_geometry()
	# A rebuilt arena brings its floor words back facing the first player.
	orient_labels()

# How far from the centre things cast real shadows (the court, its walls and the robots).
const SHADOW_REACH = 18.0

func batch_static_geometry() -> void:
	# Merge opaque architecture by material, leaving animated models independent.
	var groups: Dictionary = {}
	collect_static(self, groups)
	for group in groups.values():
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in group:
			st.append_from(part.mesh, 0, global_transform.affine_inverse() * part.global_transform)
			part.hide()
		var merged = MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = group[0].material_override
		var near = Vector2(group[0].global_position.x, group[0].global_position.z).length() < SHADOW_REACH
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ArtStyle.shadows() and near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(merged)
		static_batch_count += 1

func collect_static(parent: Node, groups: Dictionary) -> void:
	for child in parent.get_children():
		if child in units or child in brick_nodes or child in obstacle_nodes or child in wall_segments or child in power_nodes or child == aim_line or child == aim_guide:
			continue
		var opaque = child is MeshInstance3D and child.material_override is StandardMaterial3D and child.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		# Robot-painted props (goal posts) merge too; their ink outlines stay separate so the
		# Leve profile can still hide them.
		var painted = child is MeshInstance3D and child.material_override is ShaderMaterial and child.material_override.get_meta("robot_paint", false)
		if opaque or painted:
			# Separate attribute layouts so SurfaceTool never mixes UV and non-UV formats.
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var has_uv = arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size() > 0
			# Only what stands by the court casts a shadow: the scenery round it would draw the
			# whole world a second time into the shadow map.
			var near = Vector2(child.global_position.x, child.global_position.z).length() < SHADOW_REACH
			var key = str(child.material_override.get_instance_id()) + str(has_uv) + ("near" if near else "")
			if not groups.has(key):
				groups[key] = []
			groups[key].append(child)
		collect_static(child, groups)

func batch_bricks() -> void:
	var groups: Dictionary = {}
	for brick in brick_nodes:
		var bindings: Array = []
		for part in brick.get_children():
			if not part is MeshInstance3D:
				continue
			var key = str(part.mesh.get_instance_id()) + ":" + str(part.material_override.get_instance_id())
			if not groups.has(key):
				groups[key] = []
			var binding = {"part": part, "slot": groups[key].size()}
			groups[key].append(binding)
			bindings.append(binding)
			part.layers = 0
		brick_instances.append(bindings)
	for group in groups.values():
		var batch = MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = group[0].part.mesh
		batch.multimesh.instance_count = group.size()
		batch.material_override = group[0].part.material_override
		# The walls keep their soft contact shade: hundreds of bricks in the shadow map cost
		# more than their shadows show.
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		brick_batches.append(batch)
		for binding in group:
			binding["batch"] = batch.multimesh
	for i in range(brick_nodes.size()):
		update_brick_batch(i)

func update_brick_batch(index: int) -> void:
	for binding in brick_instances[index]:
		var pose: Transform3D = global_transform.affine_inverse() * binding.part.global_transform
		if not binding.part.is_visible_in_tree():
			# Collapsed where it stands, not parked a hundred units under the floor: the
			# batch's bounding box is what the menu camera frames the stadium by, and a
			# single hidden piece down there shrank the whole preview to a stamp.
			pose = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.000001), pose.origin)
		binding.batch.set_instance_transform(binding.slot, pose)

func capture_motion(rules) -> void:
	previous_motion = {"phase": rules.phase, "players": rules.players.duplicate(true), "obstacles": rules.obstacles.duplicate(true), "balls": {}}
	for ball in rules.balls:
		previous_motion.balls[ball.id] = {"p": ball.p, "bounces": ball.bounces}

func arc_points(center: Vector2, radius: float, limit: float, team: int, height: float, samples: int = 64) -> Array:
	var result: Array = []
	for i in range(samples + 1):
		# The rail follows the same ellipse the rules walk the pilot along.
		var angle = lerpf(-limit, limit, float(i) / samples)
		var p = center + Vector2(sin(angle) * Rules.TRACK_WIDTH, -cos(angle) * radius * (1 if team == 0 else -1))
		result.append(Vector3(p.x, height, p.y))
	return result

func arc_ribbon(parent: Node3D, points: Array, width: float, height: float, color: Color, luminous: bool = true) -> void:
	# A continuous strip avoids the scalloped joins of dozens of small boxes.
	var sides: Array = []
	for i in range(points.size()):
		var tangent: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		sides.append(Vector3(-tangent.z, 0, tangent.x) * width * 0.5)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i] + Vector3.UP * height * 0.5
		var b: Vector3 = points[i + 1] + Vector3.UP * height * 0.5
		var al: Vector3 = a + sides[i]
		var ar: Vector3 = a - sides[i]
		var bl: Vector3 = b + sides[i + 1]
		var br: Vector3 = b - sides[i + 1]
		triangle(st, al, br, bl)
		triangle(st, al, ar, br)
		var down = Vector3.DOWN * height
		triangle(st, al, bl, bl + down)
		triangle(st, al, bl + down, al + down)
		triangle(st, ar, br + down, br)
		triangle(st, ar, ar + down, br + down)
	mesh(parent, st.commit(), Vector3.ZERO, color, luminous)

func build_goal(team: int) -> void:
	var color = CYAN if team == 0 else CORAL
	var center = Rules.goal_center(team)
	var points = arc_points(center, Rules.GOAL_RADIUS, PI / 3, team, 0.04)
	var floor_st = SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		if team == 0:
			triangle(floor_st, Vector3(center.x, 0.04, center.y), b, a)
		else:
			triangle(floor_st, Vector3(center.x, 0.04, center.y), a, b)
	arc_ribbon(self, points, 0.09, 0.06, color)
	mesh(self, floor_st.commit(), Vector3.ZERO, color.darkened(0.6), true)
	var shield = SurfaceTool.new()
	shield.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var verts = [a, b, b + Vector3.UP * 0.75, a, b + Vector3.UP * 0.75, a + Vector3.UP * 0.75]
		var divisions = float(points.size() - 1)
		var uv = [Vector2(i / divisions, 0), Vector2((i + 1) / divisions, 0), Vector2((i + 1) / divisions, 1), Vector2(i / divisions, 0), Vector2((i + 1) / divisions, 1), Vector2(i / divisions, 1)]
		for n in range(6):
			shield.set_uv(uv[n])
			shield.set_normal(Vector3.UP)
			shield.add_vertex(verts[n])
	var gate = mesh(self, shield.commit(), Vector3.ZERO, color, true)
	var shader = ShaderMaterial.new()
	shader.shader = preload("res://shaders/energy_gate.gdshader")
	shader.set_shader_parameter("tint", color)
	gate.material_override = shader
	goals.append(gate)
	for endpoint in [points.front(), points.back()]:
		var post = Node3D.new()
		add_child(post)
		post.position = endpoint
		Robots.prop(self, post, "goal_post", ["goal_post"], {"shell": theme.block_alt, "trim": theme.block, "dark": theme.frame, "metal": Color("9aa7b5"), "glow": color, "team": color})
	# (The arch over each goal is gone: seen from behind the pilot it filled the view.)
	world_label("01" if team == 0 else "02", Vector3(0, 0.05, center.y * 0.89), color, 49)
	var track = arc_points(center, Rules.TRACK_RADIUS, Rules.track_limit_for(map), team, 0.023)
	arc_ribbon(self, track, 0.045, 0.015, color.darkened(0.2))
	for p in [track.front(), track.back()]:
		cylinder(self, p, 0.1, 0.018, color, true, 16)

func build_bricks() -> void:
	for data in Rules.map_bricks(map):
		brick_nodes.append(make_brick(self, data, 0))

func make_brick(parent: Node3D, data: Dictionary, skin: int, tint: bool = false) -> Node3D:
	# Every theme keeps the same footprint, the soft shadow and three team-coloured life lights.
	var team_color = CYAN if data.team == 0 else CORAL
	var brick = Node3D.new()
	parent.add_child(brick)
	brick.position = Vector3(data.p.x, 0, data.p.y)
	brick.rotation.y = -data.rotation
	# A tall map pulls its sides in and the bricks come in with it, exactly as the collision
	# box does. Left at full width a bank would read as one solid bar.
	brick.scale = Vector3(Rules.narrow_of(map), 1.0, 1.0)
	# A shell around the whole brick rather than a lid on top of it: at this camera angle a
	# flat plate all but disappears, and the brick has to look encased.
	# BIGORNA's plating: a hexagonal shell of yard steel with a hazard band round its top.
	var plate = cylinder(brick, Vector3(0, 0.3, 0), 0.42, 0.7, Color(Rules.power_color("plating"), 0.3), true, 6)
	plate.scale = Vector3(1.0, 1.0, 0.62)
	plate.name = "Plate"
	var band = torus(plate, Vector3(0, 0.33, 0), 0.4, 0.014, Color("2b2f36", 0.45), true)
	band.scale = Vector3(1.05, 1.0, 1.05)
	plate.hide()
	brick.set_meta("hp", int(map.get("lives", Rules.BRICK_LIVES)))
	brick.set_meta("skin", skin)
	soft_disc(brick, Vector3(0.035, 0.018, 0.06), Vector2(0.92, 0.58), Color(0.006, 0.015, 0.022, 0.70))
	if Robots.brick(self, brick, skin, team_color, tint):
		# A themed brick is tall and busy on top: its three life lights sit on the plinth,
		# front and back, where they are always in sight.
		for i in range(3):
			for face in [-1, 1]:
				var pip = box(brick, Vector3((i - 1) * 0.1, 0.05, face * 0.151), Vector3(0.07, 0.035, 0.008), team_color.lightened(0.2), true, 0.004)
				pip.name = "HP" + str(i) + ("b" if face > 0 else "")
	else:
		for i in range(3):
			var pip = box(brick, Vector3((i - 1) * 0.13, 0.426, 0), Vector3(0.078, 0.012, 0.095), team_color.darkened(0.45), true, 0.006)
			pip.name = "HP" + str(i)
	return brick

func set_brick_theme(team: int, skin: int, tint: bool = false) -> void:
	# Rebuild that team's bricks, then regroup every brick part into shared draws.
	var layout = Rules.map_bricks(map)
	for i in range(layout.size()):
		if layout[i].team == team:
			brick_nodes[i].queue_free()
			brick_nodes[i] = make_brick(self, layout[i], skin, tint)
	for batch in brick_batches:
		batch.queue_free()
	brick_batches.clear()
	brick_instances.clear()
	batch_bricks()

func build_boosters() -> void:
	for center in Rules.booster_centers(map):
		var root = Node3D.new()
		add_child(root)
		# Each accelerator stands at its own depth along the wall. The pieces below are laid
		# out around depth 0, so the root carries the depth: without it every accelerator of
		# the rail was drawn on top of the middle one, and the ones the rules had at the other
		# depths were there to hit but never seen.
		root.position.z = center.y
		var sign_x = 1 if center.x > 0 else -1
		var side = absf(center.x) - 0.75
		var limit = acos((absf(center.x) - side) / Rules.BOOST_RADIUS)
		var curve: Array = []
		var upper: Array = []
		var lower: Array = []
		for i in range(49):
			var angle = lerpf(-limit, limit, float(i) / 48)
			var p = Vector3(center.x - sign_x * cos(angle) * Rules.BOOST_RADIUS, 0.30, sin(angle) * Rules.BOOST_RADIUS)
			curve.append(p)
			upper.append(p + Vector3.UP * 0.32)
			lower.append(p - Vector3.UP * 0.21)
		arc_ribbon(root, curve, 0.15, 0.6, theme.frame, false)
		arc_ribbon(root, upper, 0.075, 0.055, theme.accent)
		arc_ribbon(root, lower, 0.09, 0.07, theme.line)
		soft_disc(root, Vector3(sign_x * (side - 0.25), 0.012, 0), Vector2(1.8, 2.8), Color(theme.accent, 0.32))
		var label = world_label("BOOST", Vector3(sign_x * (side + 0.42), 0.5, 0), theme.accent, 29)
		label.rotation.y = -sign_x * PI * 0.5
		booster_nodes.append(root)

func build_neon_rim() -> void:
	# Season two: a neon tube round the court, on the floor at the foot of the walls, and a
	# second, in the other neon, a little outside it.
	for ring in [[1.0, theme.neon, 0.035], [1.06, theme.get("neon_alt", theme.neon), 0.025]]:
		var points: Array = walls
		for i in range(points.size()):
			var a: Vector2 = points[i] * float(ring[0])
			var b: Vector2 = points[(i + 1) % points.size()] * float(ring[0])
			var mid = (a + b) * 0.5
			var tube = box(self, Vector3(mid.x, 0.04, mid.y), Vector3(a.distance_to(b) + 0.05, 0.05, float(ring[2]) * 2.0), ring[1], true, 0.0)
			tube.rotation.y = -atan2(b.y - a.y, b.x - a.x)

# The walls of a bare map, one block per edge of the outline; on a map with serpent walls
# they follow the ripple every frame (Rules.snake_walls).
var wall_segments: Array = []

func build_wall_segments() -> void:
	for i in range(walls.size()):
		var segment = box(self, Vector3.ZERO, Vector3(1.0, 0.6, 0.3), theme.frame.lerp(Color.WHITE, 0.3), false, 0.03)
		box(segment, Vector3(0, 0.32, 0), Vector3(1.0, 0.06, 0.34), GOLD, true, 0.01)
		wall_segments.append(segment)
	place_wall_segments(walls)

func place_wall_segments(points: Array) -> void:
	for i in range(mini(points.size(), wall_segments.size())):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var mid = (a + b) * 0.5
		var segment: MeshInstance3D = wall_segments[i]
		segment.position = Vector3(mid.x, 0.3, mid.y)
		segment.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		segment.scale.x = a.distance_to(b) + 0.14

func build_obstacles() -> void:
	# Painted guides are opaque, pre-blended with the floor, so they merge with the static
	# geometry instead of costing a transparent draw each.
	var color = theme.line
	# The same specs the rules use: narrowed on a tall map, so the painted guides and the base
	# of a fixed pillar sit where the pillar really is.
	for spec in Rules.map_obstacles(map):
		var kind: String = spec.get("kind", "fixed")
		var radius: float = spec.get("radius", Rules.OBSTACLE_RADIUS)
		var center: Vector2 = spec.get("center", Vector2.ZERO)
		var travel: float = spec.get("travel", 0.0)
		# Painted guides show where a bumper will go; they have no collision.
		if kind == "slide":
			var axis: Vector2 = spec.get("axis", Vector2.RIGHT)
			for n in range(-10, 11):
				var at = center + axis * travel * n / 10.0
				var tick = box(self, Vector3(at.x, 0.017, at.y), Vector3(0.10, 0.012, 0.025), color.lerp(theme.floor, 0.7), true)
				tick.rotation.y = -axis.angle()
			for end in [-1, 1]:
				var cap = center + axis * travel * end
				cylinder(self, Vector3(cap.x, 0.021, cap.y), 0.085, 0.015, color.lerp(theme.floor, 0.5), true, 12)
		elif kind == "orbit":
			var dots = maxi(24, int(TAU * travel / 0.32))
			for n in range(dots):
				var angle = TAU * n / dots
				var at = center + Vector2(cos(angle), sin(angle)) * travel
				var tick = box(self, Vector3(at.x, 0.017, at.y), Vector3(0.10, 0.012, 0.025), color.lerp(theme.floor, 0.72), true)
				tick.rotation.y = -(angle + PI * 0.5)
		else:
			cylinder(self, Vector3(center.x, 0.02, center.y), radius + 0.14, 0.03, DARK, false, 32)
		var pos = Rules.spec_position(spec, 0)
		var node = Node3D.new()
		add_child(node)
		node.position = Vector3(pos.x, 0, pos.y)
		var size = radius / Rules.OBSTACLE_RADIUS
		soft_disc(node, Vector3(0.06, 0.025, 0.09), Vector2(1.9, 1.6) * size, Color(0.005, 0.018, 0.024, 0.8))
		# An industrial hex pylon from the kit; fixed pillars wear the accent colour, moving
		# bumpers the theme's block colour. Its three-armed cap (Core) turns while it runs.
		var paint = {"shell": theme.block_alt, "trim": theme.accent if kind == "fixed" else theme.block, "dark": theme.frame, "metal": Color("9aa7b5"), "glow": theme.line, "team": theme.line}
		if spec.get("boost", false):
			# A boost bumper: gold and lit, with bright rings on the floor, so it reads as the
			# thing to aim at, not one more thing in the way.
			paint = {"shell": GOLD, "trim": Color("fff1a8"), "dark": theme.frame, "metal": Color("ffd23f"), "glow": Color("fff4c2"), "team": GOLD}
			torus(self, Vector3(center.x, 0.03, center.y), radius + 0.22, 0.035, Color("ffd23f"), true)
			torus(self, Vector3(center.x, 0.03, center.y), radius + 0.38, 0.02, Color("ffe98a"), true)
		var shell = Node3D.new()
		node.add_child(shell)
		shell.scale = Vector3(radius / 0.44, 1.0, radius / 0.44)
		Robots.prop(self, shell, "bumper_body", ["bumper_body"], paint)
		var core = Node3D.new()
		core.name = "Core"
		core.scale = shell.scale
		node.add_child(core)
		Robots.prop(self, core, "bumper_core", ["bumper_core"], paint.duplicate())
		# Stars for the shock pulse, hidden until the bumper seizes up.
		var dazed = Node3D.new()
		dazed.name = "Stun"
		node.add_child(dazed)
		torus(dazed, Vector3(0, 0.95, 0), radius * 0.72, 0.022, GOLD)
		for i in range(3):
			var angle = i * TAU / 3
			var star = box(dazed, Vector3(cos(angle) * radius * 0.7, 0.98, sin(angle) * radius * 0.7), Vector3(0.11, 0.11, 0.11), LIME, true)
			star.rotation_degrees.z = 45
		dazed.hide()
		obstacle_nodes.append(node)

func build_barriers() -> void:
	# Low ceramic walls with a gold rail; their rounded ends match the collision capsule.
	var thickness = Rules.BARRIER_RADIUS * 2
	for barrier in map.get("barriers", []):
		var a = Vector3(barrier.a.x, 0.0, barrier.a.y)
		var b = Vector3(barrier.b.x, 0.0, barrier.b.y)
		segment(self, a + Vector3.UP * 0.2, b + Vector3.UP * 0.2, thickness, 0.4, theme.block)
		segment(self, a + Vector3.UP * 0.42, b + Vector3.UP * 0.42, thickness * 0.6, 0.05, theme.frame)
		segment(self, a + Vector3.UP * 0.46, b + Vector3.UP * 0.46, 0.05, 0.02, theme.line, true)
		for end in [a, b]:
			cylinder(self, end + Vector3.UP * 0.2, Rules.BARRIER_RADIUS, 0.4, theme.block_alt, false, 16)
			cylinder(self, end + Vector3.UP * 0.43, Rules.BARRIER_RADIUS * 0.7, 0.06, theme.accent, false, 12)

func build_player(color: Color, team: int, skin: int = 0, parent: Node3D = null, tint: bool = false) -> Node3D:
	# `parent` lets the skins viewer build the same model inside its own 3D world.
	var root = Node3D.new()
	(parent if parent != null else self).add_child(root)
	root.position.z = Rules.track_position(team, 0).y
	# Soft contact shadow under the pilot, a little towards the back right, away from the key.
	soft_disc(root, Vector3(0.12, 0.024, 0.14), Vector2(1.8, 1.45), Color(0.07, 0.08, 0.1, 0.55))
	torus(root, Vector3(0, 0.043, 0), 0.53, 0.018, Color(color, 0.72))
	var body = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	# Robots come from the Blender kit; each provides LegL, LegR, Gun and Gun/Flash for
	# the shared animation code.
	Robots.build(self, body, skin, color, tint)
	# Frost: a block of ice around the pilot with crystals standing off it, and a ring of
	# spikes grown out of the floor. It is the heaviest of the worn effects on purpose -
	# being frozen is the worst thing that happens to you in a match.
	var frost = Node3D.new()
	frost.name = "Frost"
	root.add_child(frost)
	var ice = Rules.power_color("freeze")
	box(frost, Vector3(0, 0.62, 0), Vector3(1.08, 1.44, 0.98), Color(ice, 0.5), true, 0.16)
	box(frost, Vector3(0, 0.62, 0), Vector3(0.92, 1.58, 0.84), Color("dff4ff", 0.34), true, 0.22)
	# A bright edge around the middle of the block, so it reads as ice and not as haze.
	for band in [0.26, 0.62, 0.98]:
		torus(frost, Vector3(0, band, 0), 0.6, 0.038, Color("f2fdff", 0.95))
	for i in range(7):
		var shard_angle = i * TAU / 7.0
		var shard = cone(frost, Vector3(cos(shard_angle) * 0.6, 0.3 + (i % 3) * 0.26, sin(shard_angle) * 0.6), 0.14, 0.62 + (i % 3) * 0.2, Color("f2fdff", 0.95), true, 6)
		shard.rotation_degrees = Vector3(cos(shard_angle) * 32, 0, -sin(shard_angle) * 32)
	for i in range(9):
		var spike_angle = i * TAU / 9.0 + 0.3
		cone(frost, Vector3(cos(spike_angle) * 0.96, 0.12, sin(spike_angle) * 0.96), 0.1, 0.46, Color("dff4ff", 0.95), true, 6)
	torus(frost, Vector3(0, 0.03, 0), 1.02, 0.05, Color("f2fdff", 0.95))
	frost.hide()
	# The magnet: a field ring turning on its side around the pilot, with two poles.
	var pull = Node3D.new()
	pull.name = "Magnet"
	root.add_child(pull)
	var lode = Rules.power_color("magnet")
	for lift in [0.35, 0.75, 1.15]:
		torus(pull, Vector3(0, lift, 0), 0.82 - absf(lift - 0.75) * 0.5, 0.028, Color(lode, 0.8))
	for side in [-1, 1]:
		box(pull, Vector3(side * 0.82, 0.75, 0), Vector3(0.16, 0.3, 0.16), Color(lode, 0.95), true, 0.03)
	pull.hide()
	# Armour piercing: a drill bit of light riding over the gun.
	var drill = Node3D.new()
	drill.name = "Pierce"
	root.add_child(drill)
	var bite = Rules.power_color("pierce")
	cone(drill, Vector3(0, 0.95, -0.95), 0.13, 0.46, Color(bite, 0.9), true, 8).rotation_degrees.x = -90
	for i in range(3):
		torus(drill, Vector3(0, 0.95, -0.6 + i * 0.22), 0.16, 0.022, Color(bite, 0.75))
	drill.hide()
	var surge = Node3D.new()
	surge.name = "Surge"
	root.add_child(surge)
	torus(surge, Vector3(0, 0.06, 0), 0.72, 0.03, Color(GOLD, 0.9))
	torus(surge, Vector3(0, 0.5, 0), 0.46, 0.022, Color(GOLD, 0.6))
	for i in range(6):
		var spark_angle = i * TAU / 6.0
		sphere(surge, Vector3(cos(spark_angle) * 0.66, 0.2 + 0.08 * (i % 3), sin(spark_angle) * 0.66), Vector3.ONE * (0.1 + 0.04 * (i % 2)), GOLD, true)
	surge.hide()
	var stun = Node3D.new()
	stun.name = "Stun"
	root.add_child(stun)
	torus(stun, Vector3(0, 1.95, 0), 0.54, 0.025, GOLD)
	for i in range(3):
		var angle = i * TAU / 3
		var star = box(stun, Vector3(cos(angle) * 0.53, 1.98, sin(angle) * 0.53), Vector3(0.13, 0.13, 0.13), LIME, true)
		star.rotation_degrees.z = 45
	stun.hide()
	root.set_meta("last_cooldown", 0.0)
	return root

func refresh_ultimate_colors() -> void:
	# The ultimates of the skins in the match take their skin's ultimate colour, if it has one.
	Rules.color_overrides.clear()
	for team in range(unit_skins.size()):
		var skin = int(unit_skins[team])
		var paint = Skins.ultimate_color(skin)
		if paint != "" and not bool(unit_tints[team]):
			Rules.color_overrides[String(Skins.CATALOG[skin].ultimate)] = Color(paint)

func set_skin(team: int, skin: int, tint: bool = false, hue: String = "") -> void:
	# `tint`: dress the skin in a single colour instead of its own palette. `hue`: which
	# colour, when it is not the team's - that is how the station pilots each get a look of
	# their own out of hulls that already exist.
	if unit_skins[team] == skin and unit_tints[team] == tint and unit_hues[team] == hue:
		return
	var old: Node3D = units[team]
	var team_color: Color = Color(hue) if hue != "" else (CYAN if team == 0 else CORAL)
	unit_hues[team] = hue
	var fresh = build_player(team_color, team, skin, null, tint)
	fresh.transform = old.transform
	fresh.set_meta("last_cooldown", old.get_meta("last_cooldown"))
	units[team] = fresh
	unit_skins[team] = skin
	unit_tints[team] = tint
	shot_colors[team] = Skins.colors(skin, team_color, tint).shot
	# The wall keeps the team colour whatever the pilot is wearing: whose bricks are whose
	# has to stay unmistakable, and make_brick works that out for itself.
	set_brick_theme(team, skin, tint)
	old.queue_free()
	refresh_ultimate_colors()

# Station pilots are addressed from here up, well clear of the eleven skins in the shop.
const STATION_SKIN = 100


func spin_parts(body: Node3D, time: float) -> void:
	# Crests on the robots (a crown, a halo, an orbit) turn slowly.
	var spin: Node3D = body.get_node_or_null("Head/CrestMount/Spin")
	if spin == null:
		spin = body.get_node_or_null("Head/CrestMount/KeyMount/Spin")
	if spin != null:
		spin.rotation.y = time * 1.6

func glass_material() -> ShaderMaterial:
	if not materials.has("glass"):
		var glass = ShaderMaterial.new()
		glass.shader = GLASS
		materials["glass"] = glass
	return materials["glass"]

func stadium_marks(wall: float = -1.0) -> Array:
	# Everything the camera has to keep on screen: the boundary, the rails the pilots walk
	# — which reach outside the wall line at the goal ends on some outlines — and the top of
	# the walls, each with a hair of margin around it.
	var spots: Array = Rules.map_outline(map).duplicate()
	var limit: float = Rules.track_limit_for(map)
	for team in range(2):
		for step in range(9):
			spots.append(Rules.track_position(team, lerpf(-limit, limit, step / 8.0)))
	# The leaning view needs less room around the boundary: the rails are already among the
	# marks, and out there a wide margin is a lot of screen.
	var margin: float = wall if wall >= 0.0 else (0.3 if leaning() else 0.72)
	var marks: Array = []
	for spot in spots:
		for corner in [Vector2(-margin, -margin), Vector2(margin, -margin), Vector2(-margin, margin), Vector2(margin, margin)]:
			for height in [0.0, 1.35]:
				marks.append(Vector3(spot.x + corner.x, height, spot.y + corner.y))
	return marks

func projected_bounds(screen: Vector2) -> Rect2:
	# Where the stadium lands on screen, in HUD units, with the lean's perspective taken
	# into account: the far end really is smaller, so a flat projection would lie about it.
	var basis = camera.global_transform.basis
	var half: float = screen.y * 0.5
	var tan_half: float = tan(deg_to_rad(camera.fov) * 0.5)
	var bounds = Rect2()
	var first = true
	for mark in stadium_marks():
		var offset: Vector3 = mark - camera.global_position
		var depth: float = maxf(-offset.dot(basis.z), 0.05)
		var point = Vector2(offset.dot(basis.x), -offset.dot(basis.y)) * half / (depth * tan_half) + screen * 0.5
		bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
		first = false
	return bounds

func measure_view_bounds() -> Rect2:
	# What the camera has to show, on the camera plane, for the orthographic seats.
	var basis = camera.global_transform.basis
	var bounds = Rect2()
	var first = true
	# The menu seat measures the field and its wall with a wider margin, never the stands and
	# towers around it: measuring every mesh let the floodlights and skyline decide the zoom
	# and shrank the previewed level to a stamp.
	for mark in stadium_marks(1.1 if camera_home == LANDSCAPE_EYE else -1.0):
		var offset: Vector3 = mark - camera.global_position
		var point = Vector2(offset.dot(basis.x), offset.dot(basis.y))
		bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
		first = false
	return bounds
	# Menu seat: the field and its wall, not the stands and towers around it. Measuring every
	# mesh let the floodlights and skyline decide the zoom and shrank the level to a stamp.
	for mark in stadium_marks(1.1):
		var offset: Vector3 = mark - camera.global_position
		var point = Vector2(offset.dot(basis.x), offset.dot(basis.y))
		bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
		first = false
	return bounds

func view_aspect() -> float:
	if view_bounds.size == Vector2.ZERO:
		view_bounds = measure_view_bounds()
	return view_bounds.size.x / view_bounds.size.y

# 50 degrees down: low enough that the walls, the robots and the deck around the field show
# their volume, high enough that the far end of the field still reads clearly.
const LANDSCAPE_EYE = Vector3(0, 21.8, 18.3)

# Whose side of the arena the camera sits on. Each player sees their own goal at the bottom:
# in PvP the second pilot's camera is turned half round, and their stick with it.
var view_team = 0

func turned(point: Vector3) -> Vector3:
	return Basis(Vector3.UP, PI) * point if view_team == 1 else point

func set_view_team(team: int) -> void:
	if view_team == team:
		return
	view_team = team
	# Force every framing to take its seat again from the new side.
	camera_home = Vector3.ZERO
	view_bounds = Rect2()
	orient_labels()

func orient_labels() -> void:
	# The words painted on the floor turn to face whoever is looking.
	for label in find_children("*", "Label3D", true, false):
		var facing = PI if view_team == 1 else 0.0
		if not label.has_meta("base_yaw"):
			label.set_meta("base_yaw", label.rotation.y)
		label.rotation.y = float(label.get_meta("base_yaw")) + facing

# The camera stick (like a MOBA camera): the player turns the match camera up to 61 degrees
# either way round the arena - enough to look along either side, never enough to sit on the
# rival's end - and pulls it in or out. Closing in slides the view towards their own pilot.
const VIEW_YAW_MAX = 1.065
const VIEW_ZOOM_MIN = 0.8
const VIEW_ZOOM_MAX = 2.4
const VIEW_PIVOT = Vector3(0, -0.15, 0)
var view_yaw = 0.0
var view_zoom = 1.0
# Set while a match is framed; the menu, lobby and tour place the camera themselves.
var match_seat = false
# The framed seat, before the player's turn and zoom.
var seat_size = 0.0
var seat_offset = Vector2.ZERO

func remember_seat() -> void:
	seat_size = camera.size
	seat_offset = Vector2(camera.h_offset, camera.v_offset)

func unsteer() -> void:
	# Back on the framed seat before the framing measures the arena through the camera.
	if match_seat and camera_home != Vector3.ZERO:
		camera.position = camera_home
		camera.look_at(VIEW_PIVOT)

# Third person: the camera behind the player's own pilot, following it and looking the way
# it aims. Entered by pulling the zoom in past its closest; the framed seat returns on exit.
var chase = false
# Looking round in third person: the same drag that turns the map turns the view about the
# pilot; let go and it swings back to where the pilot aims.
var chase_look = 0.0
var chase_held = false
const CHASE_LOOK_MAX = 1.9

func set_chase(on: bool) -> void:
	chase = on
	if not on:
		camera_home = Vector3.ZERO
		view_bounds = Rect2()

func place_chase_camera(rules, team: int, dt: float) -> void:
	if team >= units.size() or not is_instance_valid(units[team]):
		return
	var aim: Vector2 = rules.players[team].aim
	var forward = Vector3(aim.x, 0.0, aim.y)
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	if not chase_held:
		chase_look = lerpf(chase_look, 0.0, 1.0 - exp(-dt * 5.0))
	forward = forward.rotated(Vector3.UP, chase_look)
	var pilot: Vector3 = units[team].global_position
	var eye = pilot - forward * 4.4 + Vector3.UP * 3.2
	var look = pilot + forward * 6.0 + Vector3.UP * 0.5
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 62.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	var target = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
	camera.global_transform = camera.global_transform.interpolate_with(target, 1.0 - exp(-dt * 8.0))

func steer_view(yaw: float, zoom: float) -> void:
	view_yaw = clampf(yaw, -VIEW_YAW_MAX, VIEW_YAW_MAX)
	view_zoom = clampf(zoom, VIEW_ZOOM_MIN, VIEW_ZOOM_MAX)

func place_match_seat(shake: Vector3) -> void:
	var rel: Vector3 = Basis(Vector3.UP, view_yaw) * (camera_home - VIEW_PIVOT)
	var focus = Vector3.ZERO
	var closer = clampf((view_zoom - 1.0) / (VIEW_ZOOM_MAX - 1.0), 0.0, 1.0)
	if closer > 0.0 and is_instance_valid(units[view_team]):
		var pilot: Vector3 = units[view_team].position
		focus = Vector3(pilot.x, 0.0, pilot.z) * closer * 0.7
	# Turned, the long field lies across a tall screen: the camera eases back as it turns so
	# both ends stay in the picture.
	var reach = view_zoom / (1.0 + 0.55 * absf(sin(view_yaw)))
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		rel /= reach
	else:
		camera.size = seat_size / reach
		camera.h_offset = seat_offset.x / reach
		camera.v_offset = seat_offset.y / reach
	camera.global_transform = Transform3D(Basis.looking_at(-rel, Vector3.UP), VIEW_PIVOT + focus + rel + shake)

func frame_landscape(h_offset: float) -> void:
	lobby_view = false
	tour_view = false
	# Wide screens keep the original lean, which reads more like a stadium seen from a seat.
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_home = Vector3.ZERO
		view_bounds = Rect2()
	if camera_home != turned(LANDSCAPE_EYE):
		camera_home = turned(LANDSCAPE_EYE)
		camera.position = camera_home
		camera.look_at(Vector3(0, -0.15, 0))
		view_bounds = Rect2()
	camera.size = LANDSCAPE_SIZE
	camera.h_offset = h_offset
	# Keep the enlarged upper wall clear of the scoreboard.
	camera.v_offset = 0.52

# A hair more lean than the landscape seat, no more: at 72 degrees the arena flattened
# into something that read as 2D, and the depth is what gives this game its look.
const PORTRAIT_EYE = Vector3(0, 22.2, 18.6)
# A map that asks to lean is shown through a real perspective instead: the board tips
# towards the player, the near goal comes at you and the far one falls away. The arena has
# to be narrow for this, which is why only the tall one asks for it.
const LEAN_DIR = Vector3(0, 0.64, 0.77)
const LEAN_FOV = 40.0
const LEAN_MARGIN = 1.05

func leaning() -> bool:
	return map.get("lean", false)

func frame_leaning(rect: Rect2, screen: Vector2) -> void:
	# There is no closed form for fitting a perspective view to a rectangle — how big the
	# stadium comes out depends on how far each corner is — so the seat is found by
	# repeatedly projecting it, pulling back to fit and sliding sideways to centre.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = LEAN_FOV
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	var direction: Vector3 = turned(LEAN_DIR).normalized()
	var pivot := Vector3(0, 0.3, 0)
	var distance := 34.0
	for step in range(6):
		camera.position = pivot + direction * distance
		camera.look_at(pivot)
		var shot: Rect2 = projected_bounds(screen)
		distance *= maxf(shot.size.x / rect.size.x, shot.size.y / rect.size.y) * LEAN_MARGIN
		camera.position = pivot + direction * distance
		camera.look_at(pivot)
		shot = projected_bounds(screen)
		var delta: Vector2 = rect.get_center() - shot.get_center()
		var basis = camera.global_transform.basis
		var per_unit: float = 2.0 * distance * tan(deg_to_rad(LEAN_FOV) * 0.5) / screen.y
		pivot += (basis.y * delta.y - basis.x * delta.x) * per_unit
	camera.position = pivot + direction * distance
	camera.look_at(pivot)
	camera_home = camera.position

# The lobby: your pilot alone on a pedestal, far below the arena under the same sky, turning
# slowly while the camera sways; the boss of the chosen level waits on a smaller plinth
# behind, in its fighting colours until it has been beaten.
const LOBBY_FOV = 30.0
const LOBBY_PILOT_HEIGHT = 2.6
const SHOWROOM = Vector3(0, -400, 0)
const PEDESTAL_TOP = 0.42
const BOSS_SPOT = Vector3(1.55, 0, -5.2)
var lobby_view = false
var lobby_rect = Rect2()
var lobby_screen = Vector2.ZERO
var showroom: Node3D
var showroom_pilot: Node3D
var showroom_boss: Node3D
var showroom_skins = [-1, -1, false]
var showroom_turn = 0.0
# Dragging on the stage turns the pilot; it eases back to turning on its own.
var showroom_drag = 0.0
var showroom_idle = 9.0

func build_showroom() -> void:
	showroom = Node3D.new()
	showroom.name = "Showroom"
	showroom.position = SHOWROOM
	add_child(showroom)
	var floor_node = MeshInstance3D.new()
	var disc = PlaneMesh.new()
	disc.size = Vector2(20, 20)
	floor_node.mesh = disc
	var floor_mat = ShaderMaterial.new()
	floor_mat.shader = preload("res://shaders/showroom_floor.gdshader")
	floor_node.material_override = floor_mat
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	showroom.add_child(floor_node)
	# A toy showroom: a mint step under a white pedestal with a thin painted lip in the team
	# colour, on a pale floor that melts into the backdrop.
	cylinder(showroom, Vector3(0, 0.1, 0), 1.75, 0.2, Color("6fd4bd"))
	torus(showroom, Vector3(0, 0.2, 0), 1.75, 0.018, Color(CYAN, 0.9))
	cylinder(showroom, Vector3(0, 0.31, 0), 1.35, 0.22, Color("fbfaf6"))
	torus(showroom, Vector3(0, PEDESTAL_TOP, 0), 1.35, 0.02, Color("f2cb6e"))
	# The boss's plinth, lower and a shade darker.
	cylinder(showroom, BOSS_SPOT + Vector3(0, 0.12, 0), 1.1, 0.24, Color("f59a82"))
	torus(showroom, BOSS_SPOT + Vector3(0, 0.24, 0), 1.1, 0.02, Color(CORAL, 0.9))
	var key = OmniLight3D.new()
	key.position = Vector3(1.6, 3.6, 3.2)
	key.light_color = Color("fff4e8")
	key.light_energy = 0.55
	key.omni_range = 9.0
	showroom.add_child(key)
	var rim = OmniLight3D.new()
	rim.position = Vector3(-2.2, 2.6, -2.4)
	rim.light_color = Color("e6eef8")
	rim.light_energy = 0.5
	rim.omni_range = 7.0
	showroom.add_child(rim)

func show_showroom(skin: int, boss: int, boss_dark: bool) -> void:
	# Rebuilt only when the pilot or the boss changes.
	if not is_instance_valid(showroom):
		build_showroom()
		showroom_skins = [-1, -1, false]
	if showroom_skins[0] != skin:
		if is_instance_valid(showroom_pilot):
			showroom_pilot.queue_free()
		showroom_pilot = build_player(CYAN, 0, skin, showroom)
		showroom_pilot.position = Vector3(0, PEDESTAL_TOP, 0)
	if showroom_skins[1] != boss or showroom_skins[2] != boss_dark:
		if is_instance_valid(showroom_boss):
			showroom_boss.queue_free()
		Robots.shadow_build = boss_dark
		showroom_boss = build_player(CORAL, 1, boss, showroom, false)
		Robots.shadow_build = false
		showroom_boss.position = BOSS_SPOT + Vector3(0, 0.24, 0)
		showroom_boss.scale = Vector3.ONE * 0.9
		showroom_boss.rotation.y = PI - 0.45
	showroom_skins = [skin, boss, boss_dark]

func animate_showroom(dt: float) -> void:
	if not is_instance_valid(showroom_pilot):
		return
	showroom_drag = move_toward(showroom_drag, 0.0, dt * 1.5)
	showroom_idle += dt
	# A pilot faces down -z: turned round to face the camera. A finger turns it all the way
	# round; left alone it stays where it was put (its routine does the moving).
	showroom_pilot.rotation.y = PI + showroom_turn
	for pilot in [showroom_pilot, showroom_boss]:
		if not is_instance_valid(pilot):
			continue
		live_on_pedestal(pilot, 0.0 if pilot == showroom_pilot else 4.3)

# The two robots in the lobby idle quietly: they breathe, look about slowly, shift their
# weight a little and now and then raise the gun to check their aim. Nothing takes the feet
# off the pedestal or pushes them into it - the body only ever rises a hair above where it
# stands. The rival runs the same idle out of step.
const LOBBY_ROUTINE = 12.0

func live_on_pedestal(pilot: Node3D, offset: float) -> void:
	var body: Node3D = pilot.get_node("Body")
	var legs = [body.get_node("LegL"), body.get_node("LegR")]
	var gun: Node3D = body.get_node("Gun")
	var t = fmod(clock + offset, LOBBY_ROUTINE)
	# Aim check: a slow bell between 7 and 9.5 seconds of the loop.
	var aim = smoothstep(7.0, 7.8, t) * (1.0 - smoothstep(8.8, 9.6, t))
	var look = (sin(clock * 0.35 + offset) * 0.3 + sin(clock * 0.9 + offset * 2.0) * 0.08) * (1.0 - aim)
	var breath = 0.5 + 0.5 * sin(clock * 1.6 + offset)
	body.rotation.y = lerp_angle(body.rotation.y, look * 0.35, 0.08)
	body.rotation.x = lerpf(body.rotation.x, 0.0, 0.1)
	body.rotation.z = sin(clock * 0.5 + offset) * 0.018
	body.position.x = lerpf(body.position.x, 0.0, 0.1)
	body.position.z = lerpf(body.position.z, 0.0, 0.1)
	body.position.y = breath * 0.012
	for i in range(2):
		legs[i].rotation.x = lerpf(legs[i].rotation.x, 0.0, 0.1)
		legs[i].rotation.z = lerpf(legs[i].rotation.z, 0.0, 0.1)
	var head: Node3D = body.get_node_or_null("Head")
	if head != null:
		head.rotation.y = lerpf(head.rotation.y, look, 0.08)
		head.rotation.x = lerpf(head.rotation.x, -aim * 0.05 + breath * 0.02, 0.1)
	var arm: Node3D = body.get_node_or_null("Arm")
	if arm != null:
		arm.rotation.x = lerpf(arm.rotation.x, sin(clock * 1.6 + offset) * 0.04 - aim * 0.45, 0.1)
		arm.rotation.z = lerpf(arm.rotation.z, 0.0, 0.1)
	gun.rotation.x = lerpf(gun.rotation.x, -aim * 0.1, 0.1)
	gun.position.z = lerpf(gun.position.z, 0.0, 0.2)
	gun.get_node("Flash").scale = Vector3.ONE * 0.001
	spin_parts(body, clock)

func turn_showroom(amount: float) -> void:
	showroom_turn += amount
	showroom_drag = 0.0
	showroom_idle = 0.0

# The map picker: behind it the camera orbits the chosen world, always looking at its middle.
# A finger turns and tilts it and two fingers zoom, like the hangar; left alone it goes on
# turning slowly.
var tour_view = false
var tour_yaw = 0.5
var tour_pitch = 0.62
var tour_distance = 24.0
var tour_idle = 9.0

func start_tour() -> void:
	lobby_view = false
	tour_view = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 44.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	place_tour_camera()

func orbit_tour(dx: float, dy: float) -> void:
	tour_yaw -= dx * 0.01
	tour_pitch = clampf(tour_pitch + dy * 0.006, 0.18, 1.45)
	tour_idle = 0.0
	place_tour_camera()

func zoom_tour(factor: float) -> void:
	tour_distance = clampf(tour_distance * factor, 9.0, 45.0)
	tour_idle = 0.0
	place_tour_camera()

func advance_tour(dt: float) -> void:
	tour_idle += dt
	if tour_idle > 2.5:
		tour_yaw += dt * 0.12
	place_tour_camera()

func place_tour_camera() -> void:
	var toward = Vector3(sin(tour_yaw) * cos(tour_pitch), sin(tour_pitch), cos(tour_yaw) * cos(tour_pitch))
	camera.position = toward * tour_distance
	camera.look_at(Vector3(0, 0.3, 0))
	# The seat the shake settles back to each frame: without it the camera snapped back to the
	# lobby's and the picker showed nothing but sky.
	camera_home = camera.position

func frame_lobby(rect: Rect2, screen: Vector2) -> void:
	lobby_view = true
	tour_view = false
	lobby_rect = rect
	lobby_screen = screen
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = LOBBY_FOV
	view_bounds = Rect2()
	place_lobby_camera()

func place_lobby_camera() -> void:
	var focus = SHOWROOM + Vector3(0, PEDESTAL_TOP + 0.95, 0)
	var tan_half = tan(deg_to_rad(LOBBY_FOV) * 0.5)
	# The pilot fills most of its band: it is what the lobby is for.
	var distance = LOBBY_PILOT_HEIGHT / 0.8 / (2.0 * tan_half) * (lobby_screen.y / maxf(lobby_rect.size.y, 1.0))
	var yaw = sin(clock * 0.2) * 0.12 - 0.12
	camera.position = focus + Vector3(sin(yaw), 0.34, cos(yaw)).normalized() * distance
	camera.look_at(focus)
	camera_home = camera.position
	# Slide the picture so the pilot stands in the middle of its band.
	var per_pixel = 2.0 * distance * tan_half / lobby_screen.y
	camera.h_offset = -(lobby_rect.get_center().x - lobby_screen.x * 0.5) * per_pixel
	camera.v_offset = (lobby_rect.get_center().y + lobby_rect.size.y * 0.04 - lobby_screen.y * 0.5) * per_pixel

func frame_rect(rect: Rect2, screen: Vector2, is_menu: bool = false) -> void:
	lobby_view = false
	tour_view = false
	# Fit the stadium inside the viewport band between top cards and bottom controls.
	# In menu mode, restore the original camera seat so demo maps look as they did before.
	# In match portrait mode, frame the arena closely without cutting off the sides.
	if leaning() and not is_menu:
		frame_leaning(rect, screen)
		return
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		# Coming back from a leaning arena: the flat seat has to be taken again from scratch.
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_home = Vector3.ZERO
		view_bounds = Rect2()
	var target_eye = LANDSCAPE_EYE if is_menu else turned(PORTRAIT_EYE)
	if camera_home != target_eye:
		camera_home = target_eye
		camera.position = camera_home
		camera.look_at(Vector3(0, -0.15, 0))
		view_bounds = Rect2()
	view_aspect()
	var zoom_factor = 1.015 if is_menu else 1.05
	var units_per_pixel = maxf(view_bounds.size.x / rect.size.x, view_bounds.size.y / rect.size.y) * zoom_factor
	var center = view_bounds.get_center()
	camera.size = units_per_pixel * screen.y
	camera.h_offset = center.x - (rect.get_center().x - screen.x * 0.5) * units_per_pixel
	camera.v_offset = center.y + (rect.get_center().y - screen.y * 0.5) * units_per_pixel

func update_state(rules, local_team: int, dt: float, motion_alpha: float = 1.0) -> void:
	clock += dt
	for drift in drifters:
		drift[0].rotation.y += dt * float(drift[1])
	advance_fx_clock(dt)
	if fx != null: fx.tick(fx_clock)
	if lobby_view:
		place_lobby_camera()
		animate_showroom(dt)
	elif tour_view:
		advance_tour(dt)
	# A delayed frame must not launch every queued cosmetic burst at once.
	for job in pending:
		job.time -= dt
	var ready: Array = []
	var job_index = 0
	while job_index < pending.size() and ready.size() < 4:
		if pending[job_index].time <= 0:
			ready.append(pending[job_index].call)
			pending.remove_at(job_index)
		else:
			job_index += 1
	for callback in ready:
		callback.call()
	step_flights(dt)
	if warm_frames > 0:
		warm_frames -= 1
		if warm_frames == 0 and is_instance_valid(warm_root):
			warm_root.queue_free()
			warm_root = null
		if warm_frames == 0:
			for pair in beam_lamps:
				for lamp in pair:
					lamp.light_energy = 0.0
					lamp.omni_range = 0.1
					lamp.position = Vector3(0, -50, 0)
	if not lobby_view and not tour_view and rules != null and rules.get("powers") != null:
		apply_mood(rules, dt)
	# Camera shake: a quick decaying wobble, never enough to lose the ball.
	var offset = shake_offset(dt)
	if chase and match_seat and not lobby_view and not tour_view:
		place_chase_camera(rules, local_team, dt)
		# The same shakes as the view from above, halved: this camera is four times closer.
		camera.global_position += offset * 0.5
	elif match_seat and not lobby_view and not tour_view and seat_size > 0.0:
		place_match_seat(offset)
	elif offset != Vector3.ZERO:
		camera.position = camera_home + offset
	elif camera.position != camera_home:
		camera.position = camera_home
	for id in brick_reactions.keys():
		brick_reactions[id] -= dt
		if id < brick_nodes.size():
			var brick: Node3D = brick_nodes[id]
			# A brick near the end jumps harder: its lives are read from how it takes a hit.
			var worn = clampf(3.0 - float(brick.get_meta("hp", 3)), 0.0, 2.0)
			brick.position.y = sin(maxf(0.0, brick_reactions[id]) / 0.14 * PI) * 0.065 * (1.0 + worn * 0.45)
			update_brick_batch(id)
		if brick_reactions[id] <= 0.0:
			brick_reactions.erase(id)
	step_tallies(dt)
	trail_timer += dt
	var interpolate = not previous_motion.is_empty() and previous_motion.phase == rules.phase
	if map.has("snake") and not wall_segments.is_empty():
		place_wall_segments(Rules.snake_walls(map, rules.obstacle_time))
	for i in range(rules.obstacles.size()):
		var p: Vector2 = rules.obstacles[i].p
		if interpolate:
			p = previous_motion.obstacles[i].p.lerp(p, motion_alpha)
		obstacle_nodes[i].position = Vector3(p.x, 0, p.y)
		var frozen: float = rules.obstacle_stun if rules.get("obstacle_stun") != null else 0.0
		obstacle_nodes[i].get_node("Core").rotation.y = clock * (0.7 if i == 0 else -0.7) * (0.0 if frozen > 0 else 1.0)
		var dazed: Node3D = obstacle_nodes[i].get_node("Stun")
		dazed.visible = frozen > 0
		if dazed.visible:
			dazed.rotation.y = clock * 2.7
	# The plunder flight: the wall is crossing over in the simulation, so the models follow
	# it rather than the other way round — where a brick is drawn is where a shot finds it.
	# Each one lifts as it goes and comes back down on the far side.
	# Crystal plating goes on every brick of the side that called it and comes off the
	# moment it runs out. Only the change is drawn: the rest of the time it costs nothing.
	for team in range(2):
		var lit: bool = rules.powers[team].plating_time > 0
		if plated[team] == lit:
			continue
		plated[team] = lit
		var half: int = brick_nodes.size() / 2
		for i in range(brick_nodes.size()):
			if (i < half) != (team == 0):
				continue
			var plate: Node3D = brick_nodes[i].get_node_or_null("Plate")
			if plate != null:
				plate.visible = lit
				update_brick_batch(i)
	var crossing: float = rules.plunder_progress()
	if crossing > 0 or carrying:
		carrying = crossing > 0
		for i in range(rules.bricks.size()):
			var data: Dictionary = rules.bricks[i]
			var node: Node3D = brick_nodes[i]
			# An arc, not a slide: sin gives it the whole hop in the length of the flight.
			var hop: float = sin(pow(clampf(crossing, 0.0, 1.0), 0.62 + Rules.float_scatter(i, 12.9898) * 0.95) * PI)
			node.position = Vector3(data.p.x, hop * (0.5 + Rules.float_scatter(i, 45.164) * 1.1), data.p.y)
			node.rotation.y = -data.rotation + hop * (Rules.float_scatter(i, 91.7) - 0.5) * 3.4
			update_brick_batch(i)
	for team in range(2):
		var data: Dictionary = rules.players[team]
		var node: Node3D = units[team]
		var desired = Vector3(data.p.x, 0, data.p.y)
		var facing: Vector2 = data.aim
		if interpolate:
			var angle = lerpf(previous_motion.players[team].angle, data.angle, motion_alpha)
			var position_on_arc = Rules.track_position(team, angle)
			desired = Vector3(position_on_arc.x, 0, position_on_arc.y)
			facing = Rules.forward_direction(team, angle)
		var step_vector: Vector3 = desired - node.position
		var speed = minf(step_vector.length() / maxf(dt, 0.001), 5.0)
		node.position = desired
		var body: Node3D = node.get_node("Body")
		body.rotation.y = atan2(-facing.x, -facing.y)
		spin_parts(body, clock)
		# The pilots run sideways along their rail, facing the field: a side-step gait. Which
		# side of its own body it is heading to, and how hard, both eased so a tap on the stick
		# does not flick the whole robot.
		var right_of_body = Vector3(cos(body.rotation.y), 0, -sin(body.rotation.y))
		var heading: float = signf(step_vector.dot(right_of_body)) if speed > 0.3 else 0.0
		gait_side[team] = lerpf(gait_side[team], heading, minf(dt * 8.0, 1.0))
		gait_speed[team] = lerpf(gait_speed[team], clampf(speed / 3.2, 0.0, 1.0), minf(dt * 9.0, 1.0))
		var run: float = gait_speed[team]
		var side: float = gait_side[team]
		var still: float = 1.0 - run
		# Steps come quicker the faster it goes; standing, the cycle slows to a sway of weight.
		gait_phase[team] += dt * lerpf(1.6, 12.5, run)
		var phase: float = gait_phase[team]
		# The body: sinks into a runner's crouch, bounces once per step, leans into the run,
		# rocks side to side over the planted foot and twists its hips with the stride.
		var bounce = absf(cos(phase))
		body.position.y = bounce * 0.05 * run - 0.035 * run + (0.5 + 0.5 * sin(clock * 1.8 + team * 1.3)) * 0.01 * still
		var lean = -side * 0.12 * run + sin(phase) * 0.045 * run + sin(phase) * 0.02 * still
		body.rotation.z = lerpf(body.rotation.z, sin(clock * 16) * 0.09 if data.stun > 0 else lean, minf(dt * 10, 1))
		body.rotation.x = -0.06 * run
		body.rotation.y += sin(phase) * 0.09 * run
		# The legs, joint by joint: the lifting leg's hip swings out towards the run and forward,
		# its knee folds to carry the foot up and under; the planted leg pushes off with a softly
		# bent knee. Standing, the weight rolls from one foot to the other.
		var legs = [body.get_node("LegL"), body.get_node("LegR")]
		for i in range(2):
			var leg: Node3D = legs[i]
			if not leg.has_meta("rest"):
				leg.set_meta("rest", leg.position)
			var rest: Vector3 = leg.get_meta("rest")
			var own = phase + (PI if i == 1 else 0.0)
			var lift = maxf(0.0, sin(own))
			var plant = maxf(0.0, -sin(own))
			var out = -1.0 if i == 0 else 1.0
			leg.position = rest + Vector3(0, lift * 0.035 * run, 0)
			leg.rotation.z = (side * 0.16 + cos(own) * side * 0.2 + out * 0.05) * run + out * 0.03 * still
			leg.rotation.x = (lift * 0.55 - plant * 0.12 + 0.1) * run + plant * 0.05 * still
			leg.rotation.y = -body.rotation.y * 0.0 + sin(own) * 0.12 * run
			var knee: Node3D = leg.get_node_or_null("Knee")
			if knee != null:
				knee.rotation.x = -(lift * 1.05 + 0.18 + plant * 0.1) * run - (0.12 * plant) * still
		# The head keeps its eyes on the field (against the twist), looks the way it runs and
		# wobbles when stunned.
		var head: Node3D = body.get_node_or_null("Head")
		if head != null:
			head.rotation.y = sin(clock * 0.9 + team * 2.0) * 0.14 * still + side * 0.28 * run - sin(phase) * 0.07 * run + (sin(clock * 14.0) * 0.2 if data.stun > 0 else 0.0)
			head.rotation.x = sin(clock * 2.2 + team) * 0.03 + bounce * 0.05 * run
			head.rotation.z = -lean * 0.6
		# The free arm swings against the legs, pumping harder the faster it runs.
		var arm: Node3D = body.get_node_or_null("Arm")
		if arm != null:
			arm.rotation.x = -sin(phase) * 0.6 * run - 0.15 * run + sin(clock * 2.2) * 0.04 * still
			arm.rotation.z = side * 0.2 * run + 0.05 * run
		var overload: Node3D = node.get_node_or_null("Surge")
		if overload != null:
			overload.visible = rules.powers[team].surge_time > 0
			if overload.visible:
				overload.rotation.y = -clock * 3.4
		# Worn for as long as their clocks run, and turning at their own pace so that even
		# standing still the pilot is visibly under something.
		var chilled: Node3D = node.get_node_or_null("Frost")
		if chilled != null:
			chilled.visible = rules.powers[team].freeze_time > 0
			if chilled.visible:
				chilled.rotation.y = clock * 0.5
				chilled.scale = Vector3.ONE * (1.0 + sin(clock * 3.0) * 0.03)
		var lode: Node3D = node.get_node_or_null("Magnet")
		if lode != null:
			lode.visible = rules.powers[team].magnet_time > 0
			if lode.visible:
				lode.rotation.y = clock * 2.6
				lode.rotation.x = sin(clock * 1.4) * 0.22
		var drill: Node3D = node.get_node_or_null("Pierce")
		if drill != null:
			drill.visible = rules.powers[team].pierce_time > 0
			if drill.visible:
				drill.get_child(0).rotation_degrees.y = clock * 420.0
		var halo: Node3D = node.get_node("Stun")
		halo.visible = data.stun > 0
		halo.rotation.y = clock * 2.7
		Robots.set_mood(body, 2 if data.stun > 0 else (3 if angry[team] else 0))
		if data.stun > stuns_before[team] + 0.2:
			burst(data.p, GOLD, false)
		stuns_before[team] = data.stun
		var gun: Node3D = body.get_node("Gun")
		shot_age[team] += dt
		var age: float = shot_age[team]
		# Visual recoil only, the simulation never moves: the gun snaps back in a frame,
		# holds a hair, returns with a small overshoot; the body takes a little of the kick.
		var recoil = recoil_curve(age)
		gun.position.z = recoil * feel.get_value("fire_recoil_strength")
		# Aim, fire, recover, aim: the gun arm comes up level while it keeps firing, kicks up
		# with each shot and settles back on the line; a second after the last shot it lowers
		# to a ready carry.
		var ready_pose = smoothstep(0.9, 1.6, age)
		gun.rotation.x = recoil * 0.22 - ready_pose * 0.32 + sin(phase) * 0.05 * run * ready_pose
		gun.rotation.z = -side * 0.06 * run * ready_pose
		var kick = recoil * feel.get_value("fire_body_kick")
		# The rules fire every round down the pilot's centre line; the robot stands a little to
		# the side of it so its muzzle is on that line and the round flies straight out of the
		# barrel instead of curving in to it.
		var flash_local: Vector3 = gun.get_meta("rest", gun.position) + gun.get_node("Flash").position
		var muzzle_shift = -right_of_body * flash_local.x
		body.position.x = body.basis.z.x * kick + muzzle_shift.x
		body.position.z = body.basis.z.z * kick + muzzle_shift.z
		body.rotation.x += -recoil * 0.05
		gun.get_node("Flash").scale = Vector3.ONE * maxf(0.001, 0.42 * (1.0 - age / feel.get_value("muzzle_flash_duration")))
		goals[team].material_override.set_shader_parameter("unlocked", 1.0 if rules.brick_count(team) == 0 else 0.0)
	for i in range(rules.bricks.size()):
		var data: Dictionary = rules.bricks[i]
		var brick: Node3D = brick_nodes[i]
		if int(brick.get_meta("hp")) == data.hp:
			continue
		brick.set_meta("hp", data.hp)
		brick.visible = data.alive
		# Narrowed along the arena's own axis on a tall map, so the bank reads as separate
		# bricks instead of one bar.
		brick.scale = Vector3(Rules.narrow_of(map), 1.0, 1.0) * maxf(0.001, Rules.brick_scale(data.hp))
		for n in range(3):
			brick.get_node("HP" + str(n)).visible = n < data.hp
			var back = brick.get_node_or_null("HP" + str(n) + "b")
			if back != null:
				back.visible = n < data.hp
		update_brick_batch(i)
	var active: Array = []
	for ball in rules.balls:
		active.append(ball.id)
		# Aura and trail take the shooter's skin colour; the floor glow keeps the team colour.
		var kind: int = int(ball.get("power", 0))
		var color = Color("fff0b0") if ball.get("amplified", false) else (GOLD if ball.get("boosted", false) else shot_colors[ball.owner])
		# Power rounds keep their own colour, boosted or not, so each is read at a glance.
		if kind == 1:
			color = Rules.power_color("blast")
		elif kind == 3:
			color = Rules.power_color("air")
		elif kind == 4:
			color = deep(Rules.power_color("sniper"))
		elif kind == 5 or kind == 7:
			color = deep(Rules.power_color("cluster"))
		elif kind == 6:
			color = deep(Rules.power_color("ricochet"))
		if ball.get("ghost", false):
			color = Rules.power_color("ghost")
		if not projectiles.has(ball.id):
			projectiles[ball.id] = take_orb(ball.owner)
			# A fresh round leaves from the muzzle of the gun that fired it and drops to the
			# height of the bricks as it flies, so it meets even a worn, shrunken brick.
			var launch = Vector3.ZERO
			var owner_unit = units[ball.owner] if ball.owner < units.size() else null
			if int(ball.get("bounces", 0)) == 0 and is_instance_valid(owner_unit):
				var flash: Node3D = owner_unit.get_node_or_null("Body/Gun/Flash")
				if flash != null and flash.is_inside_tree():
					launch = flash.global_position - Vector3(ball.p.x, SHOT_HEIGHT, ball.p.y)
			projectile_launch[ball.id] = [launch, 0.0]
		var node: Node3D = projectiles[ball.id]
		node.position = Vector3(ball.p.x, SHOT_HEIGHT, ball.p.y)
		if interpolate and previous_motion.balls.has(ball.id):
			var old: Dictionary = previous_motion.balls[ball.id]
			# Do not cut through walls when interpolating across a ricochet.
			if old.bounces == ball.bounces:
				var pos: Vector2 = old.p.lerp(ball.p, motion_alpha)
				node.position = Vector3(pos.x, SHOT_HEIGHT, pos.y)
		if projectile_launch.has(ball.id):
			var launch_state: Array = projectile_launch[ball.id]
			launch_state[1] += dt
			node.position += launch_state[0] * (1.0 - smoothstep(0.0, LAUNCH_BLEND, launch_state[1]))
		# A heavy explosive round, a lean burst round: size alone says which is which.
		var swell: float = POWER_BALL_SCALE[clampi(kind, 0, POWER_BALL_SCALE.size() - 1)]
		var charged = ball.get("boosted", false) or ball.get("amplified", false)
		var orb: MeshInstance3D = node.get_node("Orb")
		# Lit energy orbs, as in the first versions: the halo needs a little more card.
		orb.scale = Vector3.ONE * (0.95 if charged else 0.78) * swell
		orb.material_override.set_shader_parameter("tint", color)
		var lamp: OmniLight3D = node.get_node_or_null("Lamp")
		if ArtStyle.lit_shots():
			var pool: MeshInstance3D = node.get_node("FloorGlow")
			# The pool on the floor keeps the team's colour: it says whose round it is.
			pool.material_override = light_pool_material(Color(CYAN if int(ball.owner) == 0 else CORAL, 0.6))
			pool.scale = Vector3.ONE * (2.4 if charged else 2.0) * swell
		if lamp != null:
			# At most six lit rounds at once: every lamp is paid again on every mesh it touches.
			lamp.visible = projectiles.keys().find(ball.id) < 6
			lamp.light_color = color
			lamp.light_energy = (7.0 if charged else 5.0) * swell
			lamp.omni_range = 4.2 * swell
		orb.material_override.set_shader_parameter("charged", 1.0 if charged else 0.0)
		# The comet tail: short-lived glows left behind every frame by the GPU batch.
		if fx != null:
			# Two glows per frame, one halfway back along this frame's travel, so the tail
			# reads as one continuous streak rather than a string of beads.
			var back = Vector3(-ball.v.x, 0, -ball.v.y).normalized()
			var stride = Vector3(ball.v.x, 0, ball.v.y) * dt
			# Two glows a frame only on Refinado: every glow is transparent overdraw, and a
			# phone on the lighter profiles reads the comet just as well from one.
			for k in range(2 if quality_level > 1 else 1):
				# trail_length stretches the tail by how long each glow lives: short and legible,
				# never a line across the arena that hides the bricks behind it.
				fx.emit("glow", node.position - stride * (0.5 * k) + back * 0.1, back * 0.8, Color(color, 0.55), 0.42 * swell, 0.08, (0.24 if quality_level > 0 else 0.14) * feel.get_value("trail_length"))
			match kind:
				4:
					# The marksman's tracer: a long bright streak behind a fast round.
					fx.emit("spark", node.position, back * 2.0, Color("fffbe0"), 0.7, 0.14, 0.25, 0.0, 1.0, 0.6)
					fx.emit("glow", node.position, back * 0.5, Color(color, 0.9), 0.75, 0.12, 0.4)
				5:
					# The cluster shell smokes and throws embers as it goes.
					# A burning fuse: a fire tail, dark smoke rolling off it and embers.
					if Engine.get_process_frames() % 2 == 0:
						fx.smoke(node.position, Color("4d433c"), 1, 0.4, 1.1, 0.05, 0.5)
					fx.emit("glow", node.position, back * 1.2 + Vector3(0, 0.4, 0), Color(color, 0.95), 0.7, 0.15, 0.35)
					fx.emit("glow", node.position, back * 0.6, Color("fff0c0", 0.95), 0.35, 0.05, 0.15)
					for n in range(2):
						fx.emit("spark", node.position, back * 2.5 + Vector3(randf_range(-1.5, 1.5), randf_range(0, 1.5), randf_range(-1.5, 1.5)), color.lightened(0.2), 0.16, 0.02, 0.45, -3.0, 1.0, 0.08)
				6:
					# The ricochet round leaves teal after-images, brighter once it has bounced.
					fx.emit("glow", node.position, Vector3.ZERO, Color(color, 0.8 if ball.bounces < 1 else 0.95), 0.6 if ball.bounces < 1 else 0.8, 0.08, 0.35)
					fx.emit("spark", node.position, Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * 2.0, Color("e8fff8"), 0.12, 0.02, 0.3, 0.0, 1.0, 0.05)
				7:
					fx.emit("spark", node.position, back * 1.5, color.lightened(0.3), 0.22, 0.04, 0.25, 0.0, 1.0, 0.2)
					fx.emit("glow", node.position, back * 0.4, Color(color, 0.9), 0.45, 0.06, 0.22)
			var defender_state: Dictionary = rules.powers[1 - int(ball.owner)]
			if defender_state.slow_time > 0 and signf(ball.p.y) == signf(rules.players[1 - int(ball.owner)].p.y):
				# Caught in the slow field: a green halo drags behind it.
				fx.emit("glow", node.position, back * 0.3, Color(Rules.power_color("slow"), 0.8), 0.55, 0.3, 0.35)
			if charged and quality_level > 0:
				fx.emit("spark", node.position, back * 3.0 + Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)), color.lightened(0.3), 0.12, 0.02, 0.22, -4.0, 2.0, 0.06)
	if trail_timer > trail_interval:
		trail_timer = 0
	for id in projectiles.keys():
		if not active.has(id):
			# Projectiles go back to a pool instead of being freed: no churn per shot.
			projectiles[id].hide()
			orb_pool.append(projectiles[id])
			projectiles.erase(id)
			projectile_launch.erase(id)
			ball_previous.erase(id)
	update_sentries(rules, dt)
	var player: Dictionary = rules.players[local_team]
	aim_line.visible = rules.phase == "play" and player.stun <= 0 and not guide_enabled
	update_aim_guide(rules, local_team, dt)
	aim_line.position = units[local_team].position + Vector3.UP * 0.032
	aim_line.rotation.y = units[local_team].get_node("Body").rotation.y
	if rules.phase != phase_before and (rules.phase == "goal" or rules.phase == "finished"):
		var end_z = -(Rules.HALF_LENGTH - 1.03) if rules.winner == 0 else Rules.HALF_LENGTH - 1.03
		goal_scored(rules.winner, Vector3(0, 0.1, end_z))
		for i in range(5):
			burst(Vector2((i - 2) * 0.45, -(Rules.HALF_LENGTH - 1.03) if rules.winner == 0 else Rules.HALF_LENGTH - 1.03), CYAN if rules.winner == 0 else CORAL, true)
	phase_before = rules.phase
	update_power_effects(rules, dt)
	for effect_index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[effect_index]
		effect.ttl -= dt
		if effect.gravity:
			effect.v.y -= dt * 6
		effect.node.position += effect.v * dt
		var remaining = clampf(effect.ttl / effect.life, 0.001, 1)
		if not effect.has("energy") and not effect.get("combat_finish", false) and not effect.get("pooled", false) and effect.get("lamp", 0.0) <= 0.0:
			effect.energy = energize(effect.node)
		for glow_material in effect.get("energy", []):
			glow_material.set_shader_parameter("fade", remaining if effect.get("grow", false) or effect.get("keep", false) else 1.0)
		if effect.get("combat_finish", false):
			CombatFinish.animate(effect, remaining)
		if effect.get("lamp", 0.0) > 0.0:
			# A lamp dies down instead of shrinking.
			effect.node.light_energy = effect.lamp * remaining * remaining
		elif effect.has("expand"):
			# A solid shape that opens out at a steady speed and sinks away at the end.
			var opened = 1.0 - remaining
			var radius = lerpf(0.6, effect.expand, opened)
			var tall = effect.height * clampf(remaining * 1.8, 0.0, 1.0) * (0.5 + 0.5 * minf(opened * 6.0, 1.0))
			effect.node.scale = Vector3(radius, maxf(tall, 0.01), radius)
		elif effect.get("keep", false):
			pass
		elif effect.get("grow", false):
			# Blast ring: opens outwards and fades instead of shrinking away.
			effect.node.scale = effect.base * lerpf(0.25, 1.0, 1.0 - remaining)
			if effect.has("shield"):
				effect.node.material_override.set_shader_parameter("strength", effect.shield * remaining)
			elif effect.energy.is_empty():
				effect.node.material_override = material(Color(effect.tint, snappedf(remaining, 0.1) * 0.9), true)
		else:
			effect.node.scale = effect.base * remaining
		if effect.gravity:
			effect.node.rotate_x(dt * 4)
			effect.node.rotate_z(dt * 2)
		if effect.get("spin", false):
			effect.node.rotate_x(dt * 7.5)
			effect.node.rotate_z(dt * 5.5)
		if effect.get("spin_y", false):
			effect.node.rotate_y(dt * 3.0)
		if effect.has("trail") and fx != null:
			# A shell in flight: smoke and embers left in the air behind it.
			if Engine.get_process_frames() % 2 == 0:
				fx.smoke(effect.node.position, Color("4a433e"), 1, 0.5, 1.4, 0.05, 0.6)
			fx.emit("glow", effect.node.position, -effect.v.normalized() * 1.0, Color(effect.trail, 0.95), 0.8, 0.15, 0.3)
			fx.emit("spark", effect.node.position, -effect.v.normalized() * 2.0, Color(effect.trail).lightened(0.2), 0.2, 0.03, 0.45, -2.0, 1.0, 0.12)
		if effect.get("blink", false):
			# Lightning does not fade: it stutters and is gone.
			effect.node.visible = fmod(effect.ttl, 0.07) > 0.025
		if effect.ttl <= 0:
			if effect.get("combat_finish", false):
				CombatFinish.recycle(self, effect.node)
			elif effect.get("light_pool", false):
				effect.node.hide()
				light_pool.append(effect.node)
				active_lights -= 1
			elif effect.get("pooled", false):
				effect.node.hide()
				feedback_pool.append(effect.node)
			else:
				effect.node.queue_free()
			effects.remove_at(effect_index)


const ENERGY = preload("res://shaders/fx_energy.gdshader")

func energize(node: Node) -> Array:
	# Turn the flat lit pieces of an effect (rings, beams, shells, bolts) into energy: see
	# shaders/fx_energy.gdshader. Returns the materials, so the effect can fade them out.
	var made: Array = []
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for piece in meshes:
		var flat = piece.material_override
		if not (flat is StandardMaterial3D) or not bool(flat.get_meta("always_unshaded", false)):
			continue
		var glow = ShaderMaterial.new()
		glow.shader = ENERGY
		var color: Color = flat.albedo_color
		glow.set_shader_parameter("tint", Color(color.r, color.g, color.b, 1.0))
		glow.set_shader_parameter("strength", color.a)
		piece.material_override = glow
		made.append(glow)
	return made

func warm_shaders() -> void:
	if not is_instance_valid(camera):
		return
	if is_instance_valid(warm_root):
		warm_root.queue_free()
	warm_root = Node3D.new()
	warm_root.name = "ShaderWarmup"
	add_child(warm_root)
	# Just in front of the camera and far too small to cover a pixel, but inside the view,
	# so every sample is really drawn.
	warm_root.global_position = camera.global_position - camera.global_basis.z * 4.0
	var tiny = Vector3.ONE * 0.004
	for sample in [[Color(1, 1, 1, 1), true], [Color(1, 1, 1, 0.5), true], [Color(0.5, 0.5, 0.5, 1), false], [Color(0.05, 0.05, 0.08, 0.45), false]]:
		sphere(warm_root, Vector3.ZERO, tiny, sample[0], sample[1])
		torus(warm_root, Vector3.ZERO, 0.002, 0.001, sample[0], sample[1])
	box(warm_root, Vector3.ZERO, tiny, Color(0.9, 0.9, 0.9), false, 0.001)
	soft_disc(warm_root, Vector3.ZERO, Vector2(0.004, 0.004), Color(0, 0, 0, 0.5)).visible = true
	# A projectile, the one effect every match draws within its first second.
	var orb = take_orb(0)
	orb.reparent(warm_root, false)
	orb.position = Vector3.ZERO
	orb.scale = Vector3.ONE * 0.004
	orb.show()
	warm_frames = 4
	# The beam lamps touch the whole arena once now, so every material has its lit variant
	# ready before the first laser - not compiled in the middle of it.
	for pair in beam_lamps:
		for lamp in pair:
			lamp.position = Vector3(0, 2.0, 0)
			lamp.omni_range = Rules.HALF_LENGTH * 2.2
			lamp.light_energy = 0.001

# Rounds fly at brick height; a new one starts at its gun's muzzle and blends down onto its
# path over LAUNCH_BLEND seconds. projectile_launch: id -> [muzzle offset, age].
const SHOT_HEIGHT = 0.3
const LAUNCH_BLEND = 0.22
var projectile_launch: Dictionary = {}

func take_orb(owner: int) -> Node3D:
	# One camera-facing card with the orb shader and a team-coloured glow on the floor.
	var root: Node3D
	if not orb_pool.is_empty():
		root = orb_pool.pop_back()
	else:
		root = Node3D.new()
		add_child(root)
		var orb = MeshInstance3D.new()
		orb.name = "Orb"
		var card = QuadMesh.new()
		card.size = Vector2.ONE
		orb.mesh = card
		var mat = ShaderMaterial.new()
		mat.shader = ORB
		orb.material_override = mat
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(orb)
		var glow = soft_disc(root, Vector3(0, -0.53, 0), Vector2(1.55, 1.55), Color(CYAN, 0.42))
		glow.name = "FloorGlow"
		if ArtStyle.lit_shots() and (quality_level > 0 or not OS.has_feature("mobile")):
			# A real light in every round: it washes the court, the bricks and the robots
			# it flies past.
			var lamp = OmniLight3D.new()
			lamp.name = "Lamp"
			lamp.shadow_enabled = false
			lamp.omni_range = 3.2
			lamp.omni_attenuation = 1.4
			lamp.light_energy = 1.6
			root.add_child(lamp)
	# The light the orb throws on the floor under it.
	root.get_node("FloorGlow").material_override = soft_disc_material(Color(CYAN if owner == 0 else CORAL, 0.6))
	root.show()
	return root

func dot_batch(parent: Node3D, count: int, radius: float) -> MultiMeshInstance3D:
	var disc = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.012
	disc.radial_segments = 10
	disc.rings = 1
	var batch = MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = disc
	batch.multimesh.instance_count = count
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	batch.material_override = mat
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)
	return batch

func update_aim_guide(rules, local_team: int, dt: float) -> void:
	# Dotted path of the shot the local pilot would fire now, ricochets included, and a ring
	# on whatever it would hit. It uses the rules' own collision prediction.
	var player: Dictionary = rules.players[local_team]
	aim_guide.visible = guide_enabled and rules.phase == "play" and player.stun <= 0
	if not aim_guide.visible:
		guide_angle = INF
		return
	guide_marker.scale = Vector3.ONE * (1.0 + 0.08 * sin(clock * 8.0))
	guide_timer -= dt
	if guide_timer > 0.0:
		return
	# Refresh quickly while aiming, slowly while still (obstacles keep moving). Predicting
	# a whole path costs over a millisecond, so a phone refreshes it less often.
	var moving: bool = absf(player.angle - guide_angle) > 0.0005
	guide_timer = ([0.14, 0.09, 0.05][quality_level] if moving else [0.4, 0.25, 0.15][quality_level])
	guide_angle = player.angle
	var path: Dictionary = rules.predict_path(local_team, player.angle)
	var points: PackedVector2Array = path.points
	var total = 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	var travelled = 0.0
	var next_dot = 0.35
	var shown = 0
	for i in range(1, points.size()):
		var length = points[i].distance_to(points[i - 1])
		while next_dot <= travelled + length and shown < GUIDE_DOTS:
			var at = points[i - 1].lerp(points[i], (next_dot - travelled) / maxf(length, 0.0001))
			guide_dots.multimesh.set_instance_transform(shown, Transform3D(Basis.IDENTITY, Vector3(at.x, 0.035, at.y)))
			guide_dots.multimesh.set_instance_color(shown, Color(CREAM, lerpf(0.85, 0.25, next_dot / maxf(total, 0.001))))
			shown += 1
			next_dot += 0.34
		travelled += length
	guide_dots.multimesh.visible_instance_count = shown
	guide_shown = shown
	var outcome: Dictionary = path.outcome
	guide_marker.show()
	match outcome.get("kind", ""):
		"brick":
			var brick: Dictionary = rules.bricks[outcome.target]
			guide_marker.position = Vector3(brick.p.x, 0.05, brick.p.y)
			guide_marker.material_override = material(LIME, true)
		"goal":
			var end: Vector2 = points[points.size() - 1]
			guide_marker.position = Vector3(end.x, 0.05, end.y)
			guide_marker.material_override = material(GOLD, true)
		"player":
			var target: Dictionary = rules.players[outcome.target]
			guide_marker.position = Vector3(target.p.x, 0.05, target.p.y)
			guide_marker.material_override = material(CORAL.lightened(0.2), true)
		_:
			guide_marker.hide()

func emitter(at: Vector3, color: Color, amount: int, life: float, speed: float, spread: float, size: float, gravity: float = -7.0, direction: Vector3 = Vector3.UP) -> CPUParticles3D:
	# A one-shot spray of embers and sparks from the GPU batches: no node, no per-frame cost.
	if fx == null:
		return null
	var cone = clampf(spread, 5.0, 180.0)
	fx.embers(at, color, amount, speed, size * 1.4, life, direction, cone, gravity * 0.5)
	fx.sparks(at, color.lightened(0.3), maxi(2, amount / 2), speed * 1.4, size * 1.1, life * 0.7, direction, cone, gravity)
	return null

func dust(at: Vector3, color: Color, amount: int, life: float, speed: float, size: float) -> void:
	# Heavy, slow and unlit: the smoke that hangs after an impact, not a spark.
	if fx != null:
		fx.smoke(at, color, amount, size, life * 1.3, size, 0.3 + speed * 0.1)

# -1 follows the quality profile; tests set it to compare.
var light_override = -1

func light_cap() -> int:
	# Every lamp is paid again on every lit pixel of every mesh it touches. On a phone one
	# lamp at a time is enough for the arena to answer a big hit; the particles' glow does
	# the rest.
	if light_override >= 0:
		return light_override
	# Reduced effects: no light flashes at all.
	if feel.intensity < 1.0:
		return 0
	# On a phone: none. The first lamp to touch a material makes the GL renderer compile its
	# lit variant on the spot - the stall of the first blast - and the particles' own glow
	# carries the impact anyway.
	if ArtStyle.lit_shots():
		# The lit look: blasts and powers light the stadium on phones too, from Médio up.
		return ([0, 2, 3] if OS.has_feature("mobile") else [2, 4, 6])[quality_level]
	return 0 if OS.has_feature("mobile") else [2, 4, 6][quality_level]

func flash(at: Vector3, color: Color, energy: float, life: float, reach: float = 7.0) -> void:
	# A short-lived lamp: what sells an impact is the light it throws on the ceramic.
	# Even the performance profile gets one, just dimmer and shorter.
	if effects.size() >= effect_limit:
		return
	if quality_level == 0:
		energy *= 0.6
		life *= 0.7
	if fx != null:
		fx.glow(at, color, clampf(reach * 0.14, 0.4, 1.6), life * 0.8)
	# A big blast lights the whole field for a moment, on every device.
	if reach >= 9.0:
		light_field(color, clampf(energy / 8.0, 0.25, 1.1) * clampf(reach / 14.0, 0.7, 1.3), life)
	if light_pool.is_empty() or active_lights >= light_cap(): return
	var lamp = light_pool.pop_back()
	active_lights += 1
	lamp.show()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	effects.append({"node": lamp, "light_pool": true, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "keep": true, "lamp": energy})

func dim_beam_lamps(team: int) -> void:
	if team >= beam_lamps.size():
		return
	for lamp in beam_lamps[team]:
		if lamp.light_energy > 0.0:
			lamp.light_energy = 0.0
			lamp.omni_range = 0.1
			lamp.position = Vector3(0, -50, 0)

func place_beam_lamp(team: int, index: int, at: Vector3, color: Color, energy: float, reach: float) -> void:
	if team >= beam_lamps.size() or not beam_lamps_on():
		return
	var lamp: OmniLight3D = beam_lamps[team][index]
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 0.8

func light_field(color: Color, strength: float, life: float) -> void:
	# The key light itself takes the colour of the blast and swells, then dies back.
	strength *= feel.intensity if feel != null else 1.0
	if strength < field_light * 0.6:
		return
	field_tint = color if field_light <= 0.05 else field_tint.lerp(color, 0.6)
	field_light = maxf(field_light, strength)
	field_decay = field_light / maxf(life * 1.5, 0.2)

func hold_mood(seconds: float) -> void:
	# Ultimates that land in one blow still keep the room dim for a beat after.
	mood_hold = maxf(mood_hold, seconds)

func capture_mood_base() -> void:
	if presentation_environment == null or not is_instance_valid(key_light):
		return
	mood_base = {
		"ambient": presentation_environment.ambient_light_energy,
		"key": key_light.light_energy,
		"key_color": key_light.light_color,
		"fill": secondary_light.light_energy if is_instance_valid(secondary_light) else 0.0,
		"sky": [theme.get("sky_top", Color.BLACK), theme.get("sky_mid", Color.BLACK), theme.get("sky_low", Color.BLACK)],
	}
	mood = 0.0

func beam_lamps_on() -> bool:
	# One laser's worth of lamps is affordable on a phone from Médio up; Leve keeps only the
	# field light.
	return quality_level >= 1 and light_override != 0 and (feel == null or feel.intensity >= 1.0)

func apply_mood(rules, dt: float) -> void:
	if mood_base.is_empty():
		return
	var target = 0.0
	var sun = 0.0
	var laser = 0.0
	for team in range(mini(2, rules.powers.size())):
		var state: Dictionary = rules.powers[team]
		if float(state.get("ultimate_windup", 0.0)) > 0.0 or float(state.get("ultimate_time", 0.0)) > 0.0:
			target = 1.0
		if float(state.get("ultimate_time", 0.0)) > 0.0 and String(state.get("ultimate_id", "")) in ["sun_ray", "sun_beam"]:
			sun = 1.0
		if float(state.get("laser_time", 0.0)) > 0.0:
			laser = 1.0
	mood_hold = maxf(mood_hold - dt, 0.0)
	if mood_hold > 0.0:
		target = 1.0
	mood = move_toward(mood, target, dt * (3.2 if target > mood else 1.1))
	sun_glow = move_toward(sun_glow, sun, dt * 5.0)
	laser_glow = move_toward(laser_glow, laser, dt * 8.0)
	field_light = maxf(field_light - dt * field_decay, 0.0)
	var dark = 1.0 - MOOD_DARK * mood
	var sun_color = Color("ffb467")
	var tint_mix = clampf(field_light * 0.55, 0.0, 0.7)
	var key_color: Color = mood_base.key_color.lerp(field_tint, tint_mix)
	key_color = key_color.lerp(sun_color, sun_glow * 0.65)
	key_color = key_color.lerp(Rules.power_color("laser"), laser_glow * 0.3)
	key_light.light_color = key_color
	key_light.light_energy = mood_base.key * dark + 1.25 * field_light + 1.1 * sun_glow + 0.15 * laser_glow
	presentation_environment.ambient_light_energy = mood_base.ambient * (1.0 - 0.3 * mood) + 0.3 * field_light + 0.35 * sun_glow
	if is_instance_valid(secondary_light):
		secondary_light.light_energy = mood_base.fill * (1.0 - 0.45 * mood)
	if backdrop_mat != null:
		var names = ["sky_top", "sky_mid", "sky_low"]
		var sky_dark = 1.0 - MOOD_SKY_DARK * mood
		for i in range(3):
			var base = mood_base.sky[i]
			if not (base is Color):
				continue
			var shade: Color = base.darkened(1.0 - sky_dark).lerp(Color("ffb467"), sun_glow * 0.12 * (1.0 if i > 0 else 0.4)).lerp(field_tint, tint_mix * 0.12)
			backdrop_mat.set_shader_parameter(names[i], shade)

func schedule(seconds: float, call: Callable) -> void:
	pending.append({"time": seconds, "call": call})

func shake(power: float) -> void:
	# The older call: a plain shake without a direction, at a mid frequency.
	shake_event(power, 0.22, 22.0)

func shake_event(strength: float, life: float, hz: float, direction: Vector3 = Vector3.ZERO) -> void:
	# Each shake has its own strength, length, frequency and falloff, and, when the event
	# has one, a direction: the first swing goes the way the blow went.
	strength *= shake_scale
	if strength <= 0.0005:
		return
	if shakes.size() >= 6:
		shakes.remove_at(0)
	shakes.append({"strength": strength, "age": 0.0, "life": life, "hz": hz, "dir": direction.normalized() if direction != Vector3.ZERO else Vector3.ZERO, "seed": randf() * 10.0})

func shake_level(level: int, direction: Vector3 = Vector3.ZERO, scale: float = 1.0) -> void:
	var spec: Dictionary = GameFeel.LEVELS.get(level, {})
	if spec.is_empty():
		return
	shake_event(feel.get_value(spec.camera) * scale, spec.shake_time, spec.shake_hz, direction)

func shake_offset(dt: float) -> Vector3:
	var total = Vector3.ZERO
	for index in range(shakes.size() - 1, -1, -1):
		var item: Dictionary = shakes[index]
		item.age += dt
		var k: float = item.age / item.life
		if k >= 1.0:
			shakes.remove_at(index)
			continue
		var falloff = (1.0 - k) * (1.0 - k)
		var wave = cos(TAU * item.hz * item.age)
		var push: Vector3 = item.dir * wave * item.strength * falloff
		# Around the main swing, a smaller wobble on the other axes so it never reads as a
		# mechanical back-and-forth.
		var wobble = Vector3(sin(TAU * item.hz * 1.37 * item.age + item.seed), cos(TAU * item.hz * 0.83 * item.age + item.seed * 1.7) * 0.6, sin(TAU * item.hz * 1.11 * item.age + item.seed * 0.6) * 0.5)
		total += push + wobble * item.strength * falloff * (0.35 if item.dir != Vector3.ZERO else 0.8)
	return total

func recoil_curve(age: float) -> float:
	var peak = feel.get_value("fire_recoil_peak")
	var back = feel.get_value("fire_return_duration")
	if age < 0.016:
		return age / 0.016
	if age < peak:
		return 1.0
	var x = (age - peak) / back
	if x >= 1.4:
		return 0.0
	if x >= 1.0:
		# Settle: the overshoot eases back to rest.
		return -0.08 * (1.0 - (x - 1.0) / 0.4)
	return pow(1.0 - x, 3.0) - 0.08 * smoothstep(0.55, 1.0, x)

func advance_fx_clock(dt: float) -> void:
	if hitstop_left > 0.0:
		hitstop_left -= dt
		return
	var rate = 1.0
	if dilation_left > 0.0:
		dilation_left -= dt
		rate = dilation_rate
	fx_clock += dt * rate

func hitstop(seconds: float) -> void:
	# Effects hold still for a beat; projectiles, pilots and the rules never do.
	hitstop_left = maxf(hitstop_left, seconds)

func dilate(rate: float, seconds: float) -> void:
	dilation_rate = rate
	dilation_left = maxf(dilation_left, seconds)

func scorch(at: Vector2, size: float, color: Color, life: float) -> void:
	# A soft mark left on the floor, using the same decal shader as the shadows.
	if effects.size() >= effect_limit:
		return
	var mark = soft_disc(self, Vector3(at.x, 0.016, at.y), Vector2(size, size), Color(color, 0.5))
	mark.visible = true
	effects.append({"node": mark, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "keep": true})

func burst(pos: Vector2, color: Color, debris: bool = true) -> void:
	# A hit: a hot star and a spray of sparks; when something breaks, chunks of it tumble
	# out in the arena's block colours and the colour that was struck.
	if fx == null:
		return
	var at = Vector3(pos.x, 0.45, pos.y)
	if debris:
		fx.debris(at, [theme.get("block_alt", CREAM), color, color.darkened(0.35)], 6, 3.4, 0.12, 0.95)
		fx.smoke(Vector3(pos.x, 0.25, pos.y), theme.get("frame", DARK).lerp(color, 0.25), 2, 0.35, 0.7, 0.2)
	fx.hit(at, color, 1.0 if debris else 0.8)

func explosion(pos: Vector2, radius: float) -> void:
	# The blast radius has to be readable at a glance: a floor ring that opens to its real
	# size under a fireball, sparks, embers, tumbling chunks and a hanging cloud.
	var tint: Color = Rules.power_color("blast")
	if fx != null:
		fx.blast(Vector3(pos.x, 0.4, pos.y), tint, radius)
		fx.debris(Vector3(pos.x, 0.4, pos.y), [theme.get("block_alt", CREAM), tint, DARK], 8, 5.0, 0.13, 1.1)
	flash(Vector3(pos.x, 0.9, pos.y), tint, 4.0, 0.25, 6.0)
	scorch(pos, radius * 1.4, tint, 0.65)
	shake(0.12)

# --- the second shelf's effects --------------------------------------------------------------
const SHIELD = preload("res://shaders/fx_shield.gdshader")

# Immunity's shop colour is near white, which vanishes over a bright floor: its light in the
# arena is a holy white-gold instead.
const IMMUNE_GLOW = Color("ffc93c")

func deep(color: Color) -> Color:
	# The body colour of an effect: the shop's pale tints pushed to full saturation and a
	# touch darker, so rings and beams read over the bright floors instead of washing out.
	return Color.from_hsv(color.h, maxf(color.s, 0.82), minf(color.v, 0.92), color.a)

func shader_time() -> float:
	# The clock the shaders read as TIME (it rolls over every hour).
	return fmod(Time.get_ticks_msec() / 1000.0, 3600.0)

func shield_material(color: Color, cells: float, strength: float = 1.0) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = SHIELD
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("cells", cells)
	mat.set_shader_parameter("strength", strength)
	return mat

func link(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	# A lit rod from one point to another in any direction (segment() only turns about Y).
	# One shared unit rod, stretched: bolts of every length share a single mesh.
	var length = maxf(a.distance_to(b), 0.001)
	var rod = cylinder(parent, (a + b) * 0.5, radius, 1.0, color, true, 8)
	var along = (b - a) / length
	var side = along.cross(Vector3.FORWARD if absf(along.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	rod.basis = Basis(side, along * length, side.cross(along))
	return rod

func lightning(a: Vector3, b: Vector3, color: Color, life: float, jag: float = 0.35, width: float = 0.06) -> void:
	# A jagged arc of electricity between two points: a hot core over a wide glow, strobing.
	if effects.size() + 2 >= effect_limit:
		return
	var bolt = Node3D.new()
	add_child(bolt)
	var steps = 7
	var side = (b - a).cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var last = a
	for k in range(1, steps + 1):
		var t = k / float(steps)
		var point = a.lerp(b, t)
		if k < steps:
			point += side * randf_range(-jag, jag) + Vector3(0, randf_range(-jag, jag) * 0.6, 0)
		link(bolt, last, point, width * 1.6, Color(color, 0.45))
		link(bolt, last, point, width * 0.5, Color("f4fbff", 1.0))
		last = point
	effects.append({"node": bolt, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "keep": true, "blink": true})

func sniper_fire(team: int) -> void:
	# The marksman's shot: a star flare off the muzzle, a sonic ring punched in the air and a
	# kick of smoke; the round itself leaves a long tracer (see the ball trails).
	if not is_instance_valid(units[team]):
		return
	var color = deep(Rules.power_color("sniper"))
	var body: Node3D = units[team].get_node("Body")
	var muzzle: Vector3 = body.get_node("Gun/Flash").global_position
	var ahead: Vector3 = -body.global_basis.z
	if fx != null:
		fx.star(muzzle, Color("fffbe0"), 1.6, 0.18)
		fx.glow(muzzle, color, 1.2, 0.2, 2.2)
		fx.sparks(muzzle, color.lightened(0.3), 14, 9.0, 0.12, 0.25, ahead, 18.0, 0.0)
		fx.smoke(muzzle + ahead * 0.3, Color("d8d4c8"), 4, 0.35, 0.8, 0.12, 0.35)
	if effects.size() < effect_limit:
		var boom = torus(self, muzzle + ahead * 0.5, 0.3, 0.08, Color(color, 0.95), true)
		boom.look_at_from_position(muzzle + ahead * 0.5, muzzle + ahead * 2.0 + Vector3(0.001, 0, 0), Vector3.UP)
		boom.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		effects.append({"node": boom, "v": ahead * 3.0, "ttl": 0.3, "life": 0.3, "gravity": false, "base": Vector3.ONE * 3.2, "grow": true, "tint": color})
	if effects.size() + 1 < effect_limit:
		# The line of the shot burnt into the air the whole way across the court: a wide
		# golden glow over a white-hot core, thinning as it fades.
		var reach = muzzle + Vector3(ahead.x, 0, ahead.z).normalized() * 16.0
		var tracer = Node3D.new()
		add_child(tracer)
		link(tracer, muzzle, reach, 0.22, Color(color, 0.55))
		link(tracer, muzzle, reach, 0.07, Color("fffdf0", 1.0))
		effects.append({"node": tracer, "v": Vector3.ZERO, "ttl": 0.4, "life": 0.4, "gravity": false, "base": Vector3.ONE, "keep": true})
		if fx != null:
			for k in range(10):
				fx.emit("spark", muzzle.lerp(reach, k / 10.0), Vector3(randf_range(-1, 1), randf_range(0.5, 2), randf_range(-1, 1)), color.lightened(0.3), 0.16, 0.03, 0.4, 3.0, 1.0, 0.1)
	flash(muzzle, color, 3.5, 0.15, 6.0)
	shake(0.18)

func sniper_hit(at: Vector2, heading: Vector2) -> void:
	# Where the marksman's round lands: a piercing white star, sparks thrown on through and a
	# ring punched in the air.
	var color = deep(Rules.power_color("sniper"))
	var p = Vector3(at.x, 0.55, at.y)
	var through = Vector3(heading.x, 0.15, heading.y).normalized()
	if fx != null:
		fx.star(p, Color("ffffff"), 1.3, 0.2)
		fx.sparks(p, color.lightened(0.2), 18, 8.0, 0.12, 0.3, through, 35.0)
		fx.ring(Vector3(at.x, 0.06, at.y), color, 0.9, 0.35)
	flash(p, color, 3.0, 0.15, 5.0)

func cluster_flash(at: Vector2) -> void:
	# The shell bursts: a fireball with a white heart, a ring opening on the floor, chunks,
	# smoke and a scorch; the shards fly out on their own trails.
	var color = deep(Rules.power_color("cluster"))
	var p = Vector3(at.x, 0.5, at.y)
	if fx != null:
		fx.blast(p, color, 1.1)
		fx.star(p, Color("fff4d6"), 1.4, 0.16)
		fx.debris(p, [DARK, color, color.darkened(0.3)], 10, 5.5, 0.1, 1.0)
		fx.smoke(p, Color("5d544c"), 6, 0.5, 1.3, 0.35, 0.6)
	flash(p, color, 4.5, 0.25, 7.0)
	scorch(at, 1.6, color, 0.9)
	shake(0.2)

func drain_beam(from: Vector2, to: Vector2, interrupted: bool) -> void:
	# Violet power ripped out of the rival along a sagging arc of light and poured into the
	# thief: a vortex closing on the rival, a flare opening on you, motes running the arc.
	var color = deep(Rules.power_color("drain"))
	var a = Vector3(from.x, 1.0, from.y)
	var b = Vector3(to.x, 1.0, to.y)
	var lift = Vector3(0, 2.6, 0)
	var arc: Array = []
	for k in range(13):
		var t = k / 12.0
		arc.append(a.lerp(b, t) + lift * 4.0 * t * (1.0 - t))
	if effects.size() + 3 < effect_limit:
		var tether = Node3D.new()
		add_child(tether)
		for k in range(12):
			link(tether, arc[k], arc[k + 1], 0.3, Color(color, 0.5))
			link(tether, arc[k], arc[k + 1], 0.09, Color("f3e6ff", 1.0))
		# A second strand winding round the arc, so it reads as power being wrung out.
		var last: Vector3 = arc[0]
		for k in range(1, 37):
			var t = k / 36.0
			var centre: Vector3 = a.lerp(b, t) + lift * 4.0 * t * (1.0 - t)
			var twist = t * TAU * 4.0
			var point = centre + Vector3(cos(twist), sin(twist), 0) * 0.35 * sin(t * PI)
			link(tether, last, point, 0.06, Color(color.lightened(0.35), 0.95))
			last = point
		effects.append({"node": tether, "v": Vector3.ZERO, "ttl": 0.8, "life": 0.8, "gravity": false, "base": Vector3.ONE, "keep": true})
		var suck = torus(self, a + Vector3(0, -0.5, 0), 1.3, 0.12, Color(color, 0.95), true)
		effects.append({"node": suck, "v": Vector3.ZERO, "ttl": 0.6, "life": 0.6, "gravity": false, "base": Vector3.ONE * 1.3})
		var gain = torus(self, b + Vector3(0, -0.5, 0), 0.4, 0.08, Color(color, 0.95), true)
		effects.append({"node": gain, "v": Vector3.ZERO, "ttl": 0.6, "life": 0.6, "gravity": false, "base": Vector3.ONE * 3.2, "grow": true, "tint": color})
	if fx != null:
		for k in range(12):
			var along = (arc[k + 1] - arc[k]) * 10.0
			fx.emit("glow", arc[k], along, Color(color.lightened(0.2), 0.95), 0.35, 0.05, 0.5)
			fx.emit("spark", arc[k], along * 0.8 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)), Color("f3e6ff"), 0.14, 0.03, 0.4, 0.0, 1.5, 0.1)
		fx.embers(a, color, 16, 2.5, 0.16, 0.7, Vector3.UP, 120.0, 1.0)
		fx.star(b, Color("f3e6ff"), 1.2, 0.3)
	flash(b, color, 4.0, 0.4, 8.0)
	if interrupted:
		# The rival's ultimate breaks in its hands: a white shatter, shards of its own light
		# and a heavier shake - the moment to be proud of.
		if fx != null:
			fx.star(a, Color("ffffff"), 2.4, 0.3)
			fx.sparks(a, Color("ffffff"), 30, 9.0, 0.14, 0.5, Vector3.UP, 180.0)
			fx.debris(a, [color, Color("f3e6ff"), Color("ffffff")], 14, 6.0, 0.08, 0.9)
			fx.pulse(Vector3(from.x, 0.08, from.y), color, 3.5, 0.6)
		flash(a, Color("ffffff"), 8.0, 0.35, 10.0)
		shake(0.45)

func emp_flash(at: Vector2) -> void:
	# An electromagnetic storm over the rival: three shock shells opening one after the
	# other, arcs of lightning jumping between the rival and its wall, every shield fizzling.
	var color = deep(Rules.power_color("emp"))
	var centre = Vector3(at.x, 0.6, at.y)
	for k in range(3):
		schedule(k * 0.1, func():
			if effects.size() < effect_limit:
				var shell = sphere(self, centre, Vector3.ONE * 1.0, Color(color, 0.8), true)
				effects.append({"node": shell, "v": Vector3.ZERO, "ttl": 0.55, "life": 0.55, "gravity": false, "base": Vector3(9.0, 3.0, 9.0), "grow": true, "tint": color})
				var ring = torus(self, Vector3(at.x, 0.1, at.y), 1.0, 0.07, Color(color, 0.95), true)
				effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3.ONE * 5.5, "grow": true, "tint": color}))
	# Arcs from the rival to the bricks behind it, and between the bricks.
	var targets: Array = []
	for i in range(brick_nodes.size()):
		var node: Node3D = brick_nodes[i]
		if node.visible and signf(node.position.z) == signf(at.y) and i % 5 == 0:
			targets.append(node.position + Vector3(0, 0.4, 0))
	for k in range(mini(targets.size(), 7)):
		var to: Vector3 = targets[k]
		schedule(randf_range(0.0, 0.35), func(): lightning(centre, to, color, 0.32, 0.45, 0.11))
		if fx != null:
			fx.sparks(to, color.lightened(0.3), 6, 4.0, 0.1, 0.35, Vector3.UP, 120.0)
			fx.smoke(to, Color("8a93a8"), 2, 0.25, 0.8, 0.1, 0.4)
	# A cage of electric lattice clamps down over the rival for a moment.
	if effects.size() < effect_limit:
		var cage = MeshInstance3D.new()
		var ball = SphereMesh.new()
		ball.radial_segments = 32
		ball.rings = 16
		cage.mesh = ball
		cage.material_override = shield_material(color, 7.0, 1.3)
		cage.position = Vector3(at.x, 0.2, at.y)
		cage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cage)
		effects.append({"node": cage, "v": Vector3.ZERO, "ttl": 0.7, "life": 0.7, "gravity": false, "base": Vector3(3.6, 2.6, 3.6), "grow": true, "tint": color, "shield": 1.3})
	# Forks of lightning crawling out across the floor in every direction from the rival.
	for k in range(8):
		var angle = k * TAU / 8.0 + randf_range(-0.2, 0.2)
		var tip = Vector3(at.x, 0.12, at.y) + Vector3(cos(angle), 0, sin(angle)) * randf_range(2.2, 3.4)
		schedule(k * 0.03, func(): lightning(Vector3(at.x, 0.3, at.y), tip, color, 0.3, 0.3, 0.09))
	if fx != null:
		fx.sparks(centre, Color("e6f0ff"), 40, 9.0, 0.16, 0.5, Vector3.UP, 180.0)
		fx.sparks(centre, color, 30, 6.0, 0.14, 0.6, Vector3.UP, 180.0)
		fx.star(centre, Color("ffffff"), 2.6, 0.25)
		fx.pulse(Vector3(at.x, 0.08, at.y), color, 4.5, 0.5)
	flash(centre, color, 7.0, 0.45, 12.0)
	shake(0.4)

func mortar_shell(from: Vector2, target: Vector2, flight: float) -> void:
	# The launch: a blast of smoke and flame straight up; the shell climbs trailing smoke and
	# embers and comes down on a target reticle that tightens as it falls.
	var color = deep(Rules.power_color("mortar"))
	var start = Vector3(from.x, 1.0, from.y)
	var end = Vector3(target.x, 0.3, target.y)
	if fx != null:
		fx.muzzle(start, Vector3.UP, color, 0.2, 12, 1.0)
		fx.smoke(start, Color("cfc8bb"), 6, 0.45, 1.2, 0.2, 0.9)
	flash(start, color, 3.0, 0.2, 6.0)
	shake(0.15)
	if effects.size() + 3 >= effect_limit:
		return
	# The effects pull down at 6 units/s^2 when they have gravity: pick the launch to land.
	var velocity = (end - start) / flight
	velocity.y += 0.5 * 6.0 * flight
	var shell = Node3D.new()
	add_child(shell)
	shell.position = start
	sphere(shell, Vector3.ZERO, Vector3(0.46, 0.46, 0.62), Color("2d2a2e"))
	sphere(shell, Vector3.ZERO, Vector3.ONE * 1.0, Color(color, 0.7), true)
	sphere(shell, Vector3.ZERO, Vector3.ONE * 0.5, Color("fff0d0", 0.9), true)
	effects.append({"node": shell, "v": velocity, "ttl": flight, "life": flight, "gravity": true, "base": Vector3.ONE, "keep": true, "trail": color})
	# The reticle: an outer ring turning, an inner one closing in, four ticks.
	var reticle = Node3D.new()
	add_child(reticle)
	reticle.position = Vector3(target.x, 0.07, target.y)
	torus(reticle, Vector3.ZERO, Rules.MORTAR_RADIUS, 0.09, Color(color, 0.95), true)
	for k in range(4):
		var d = Vector3(cos(k * PI * 0.5), 0, sin(k * PI * 0.5))
		segment(reticle, d * Rules.MORTAR_RADIUS * 0.7, d * Rules.MORTAR_RADIUS * 1.25, 0.06, 0.03, Color(color, 0.95), true)
	effects.append({"node": reticle, "v": Vector3.ZERO, "ttl": flight, "life": flight, "gravity": false, "base": Vector3.ONE, "keep": true, "spin_y": true})
	var closing = torus(self, Vector3(target.x, 0.08, target.y), Rules.MORTAR_RADIUS * 2.0, 0.09, Color(color.lightened(0.25), 0.9), true)
	effects.append({"node": closing, "v": Vector3.ZERO, "ttl": flight, "life": flight, "gravity": false, "base": Vector3.ONE})

func mortar_impact(at: Vector2, radius: float) -> void:
	# A heavy landing: fireball, a column of smoke, a shockwave across the floor, flying
	# chunks of wall and a scorch that stays.
	var color = deep(Rules.power_color("mortar"))
	var p = Vector3(at.x, 0.4, at.y)
	explosion(at, radius)
	if fx != null:
		fx.blast(p + Vector3(0, 0.3, 0), color, radius * 1.3)
		fx.star(p, Color("fff4d6"), 2.2, 0.2)
		fx.smoke(p, Color("4a4440"), 10, 0.7, 1.8, 0.4, 1.2)
		fx.debris(p, [theme.get("block_alt", CREAM), DARK, color], 14, 7.0, 0.13, 1.3)
		fx.embers(p, color, 18, 4.0, 0.15, 1.0, Vector3.UP, 70.0, -4.0)
	if effects.size() < effect_limit:
		var wave = torus(self, Vector3(at.x, 0.1, at.y), 1.0, 0.1, Color(color, 0.95), true)
		effects.append({"node": wave, "v": Vector3.ZERO, "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3.ONE * radius * 3.2, "grow": true, "tint": color})
	flash(p + Vector3(0, 0.5, 0), color, 8.0, 0.35, 10.0)
	scorch(at, radius * 2.2, Color("2b2320"), 2.5)
	shake(0.4)

func absorb_flash(at: Vector2, team: int) -> void:
	# The sponge swallows a round: an implosion where it struck, golden motes flying to its
	# pilot, a +1 floating up.
	var color = deep(Rules.power_color("sponge"))
	var p = Vector3(at.x, 0.45, at.y)
	if effects.size() < effect_limit:
		var gulp = torus(self, p, 0.55, 0.11, Color(color, 0.95), true)
		effects.append({"node": gulp, "v": Vector3.ZERO, "ttl": 0.3, "life": 0.3, "gravity": false, "base": Vector3.ONE * 1.4})
	if fx != null:
		var home = units[team].position + Vector3(0, 1.0, 0) if is_instance_valid(units[team]) else p
		for k in range(6):
			var jitter = Vector3(randf_range(-0.3, 0.3), randf_range(0, 0.4), randf_range(-0.3, 0.3))
			fx.emit("glow", p + jitter, (home - p) * randf_range(1.2, 1.7), Color(color, 0.95), 0.26, 0.06, 0.6, 0.0, 0.5)
		fx.star(p, Color("fff6d0"), 0.8, 0.15)
	gain_mark(at, 1, color)

func immune_flash(at: Vector2, cleansed: bool) -> void:
	# A column of white-gold light over the pilot; if frost was on it, the ice shatters off.
	var color = IMMUNE_GLOW
	var p = Vector3(at.x, 0.9, at.y)
	if effects.size() < effect_limit:
		var column = cylinder(self, Vector3(at.x, 2.0, at.y), 0.6, 4.0, Color(color, 0.8), true, 20)
		effects.append({"node": column, "v": Vector3.ZERO, "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3.ONE, "keep": true})
	if fx != null:
		fx.star(p, Color("ffffff"), 2.0, 0.3)
		fx.embers(Vector3(at.x, 0.1, at.y), Color("fff6d8"), 20, 3.0, 0.14, 0.9, Vector3.UP, 30.0, 1.0)
		fx.ring(Vector3(at.x, 0.06, at.y), color, 1.6, 0.5)
		if cleansed:
			fx.debris(p, [deep(Rules.power_color("freeze")), Color("f2fdff"), Color("dff4ff")], 16, 5.0, 0.1, 1.0)
	flash(p, color, 5.0, 0.4, 8.0)

func immune_block(team: int, at: Vector2) -> void:
	# Something tried to put an immune pilot down: the bubble flares where it was struck.
	var color = IMMUNE_GLOW
	var bubble: MeshInstance3D = power_nodes[team].get_node("Immune/Bubble")
	bubble.material_override.set_shader_parameter("ripple_at", Vector3(at.x, 1.0, at.y))
	bubble.material_override.set_shader_parameter("ripple_time", shader_time())
	if fx != null:
		fx.star(Vector3(at.x, 1.0, at.y), Color("ffffff"), 1.4, 0.2)
		fx.sparks(Vector3(at.x, 1.0, at.y), color, 16, 5.0, 0.12, 0.35, Vector3.UP, 180.0)

func dome_ripple(team: int, at: Vector2) -> void:
	# An ultimate strikes the dome and the lattice ripples out from the blow.
	var shell: MeshInstance3D = power_nodes[team].get_node("Dome/Shell")
	shell.material_override.set_shader_parameter("ripple_at", Vector3(at.x, 1.2, at.y))
	shell.material_override.set_shader_parameter("ripple_time", shader_time())
	if fx != null:
		fx.star(Vector3(at.x, 1.6, at.y), Color("ffffff"), 1.2, 0.2)
		fx.sparks(Vector3(at.x, 1.6, at.y), deep(Rules.power_color("dome")), 10, 4.0, 0.1, 0.35, Vector3.UP, 160.0)

func ricochet_spark(at: Vector2, heading: Vector2) -> void:
	# The ricochet round kisses a surface: a teal star, a ring and a spray thrown off it.
	var color = deep(Rules.power_color("ricochet"))
	var p = Vector3(at.x, 0.55, at.y)
	if fx != null:
		fx.star(p, Color("e8fff8"), 0.9, 0.14)
		fx.sparks(p, color, 10, 6.0, 0.1, 0.25, Vector3(heading.x, 0.2, heading.y), 60.0)
		fx.ring(Vector3(at.x, 0.06, at.y), color, 0.55, 0.25)

func power_flash(pos: Vector2, id: String) -> void:
	# A power going off: a floor ring in its colour; defensive powers lift a column of
	# embers, attacks throw sparks outwards.
	var color = Rules.power_color(id)
	if fx != null:
		var defense = id in ["weld", "rebuild", "mirror", "walls", "bloom", "plating", "dome", "slow", "sponge", "immune"]
		fx.ring(Vector3(pos.x, 0.06, pos.y), color, 0.8, 0.45)
		fx.glow(Vector3(pos.x, 0.5, pos.y), color, 0.9, 0.3)
		if defense:
			fx.embers(Vector3(pos.x, 0.2, pos.y), color, 10, 1.2, 0.18, 0.7, Vector3.UP, 25.0, 1.5)
		else:
			fx.sparks(Vector3(pos.x, 0.45, pos.y), color, 10, 6.0, 0.14, 0.35, Vector3.UP, 100.0)
	burst(pos, color, false)

func laser_beam(from: Vector2, heading: Vector2, team: int) -> void:
	# Each bite sparks at the muzzle; the beam itself is drawn every frame below.
	var muzzle: Vector3 = muzzle_of(team)
	burst(Vector2(muzzle.x, muzzle.z) + heading * 0.2, Rules.power_color("laser"), false)

func muzzle_of(team: int) -> Vector3:
	# Where the pilot's weapon actually points from, so a beam leaves the barrel.
	var unit: Node3D = units[team]
	var flash_node: Node3D = unit.get_node_or_null("Body/Gun/Flash")
	if flash_node == null:
		return unit.position + Vector3(0, 0.7, 0)
	return to_local(flash_node.global_position)

func sun_ray(from: Vector2, heading: Vector2, half_width: float) -> void:
	# The beam itself is a standing node (see update_power_effects); this is the discharge:
	# a shock ring at the muzzle, embers thrown down the barrel and a scorched floor.
	var color = Rules.power_color("sun_ray")
	var hot = Color("fff4d2")
	var origin = Vector3(from.x, 0.62, from.y)
	var direction = Vector3(heading.x, 0, heading.y)
	if effects.size() + 3 < effect_limit:
		var ring = torus(self, origin + direction * 0.8, half_width * 1.1, 0.08, Color(hot, 0.95), true)
		ring.rotation.y = -heading.angle()
		ring.rotation.z = PI * 0.5
		effects.append({"node": ring, "v": direction * 9.0, "ttl": 0.45, "life": 0.45, "gravity": false, "base": Vector3.ONE * 1.4, "grow": true, "tint": color})
	emitter(origin + direction * 1.2, hot, 26, 0.5, 9.0, 26.0, 0.26, -2.0, direction)
	emitter(origin + direction * 0.4, color, 18, 0.7, 3.4, 70.0, 0.36, -1.0, Vector3.UP)
	dust(origin + direction * 2.0, Color("e2c49a"), 9, 1.2, 1.6, 0.8)
	flash(origin + direction * 1.5, color, 7.0, 0.35, 11.0)
	shake(0.55)
	# Embers and scorch marks the length of the band, so the floor remembers it.
	for step in range(6):
		var along = from + heading * (2.4 + step * 2.4)
		if not Rules.point_inside(walls, along):
			break
		scorch(along, half_width * 2.6, color, 0.9)
		if step % 2 == 0:
			emitter(Vector3(along.x, 0.3, along.y), color, 10, 0.55, 4.5, 60.0, 0.3, -6.0, Vector3.UP)

func meteor_fall(at: Vector2, radius: float, warm: bool) -> void:
	# A rock with a burning tail comes down at an angle, cracks the floor and throws dust.
	var color = Color("ffc861") if warm else Rules.power_color("meteors")
	var hot = Color("fff0cf") if warm else Color("e8d9ff")
	if effects.size() + 5 >= effect_limit:
		return
	var lean = Vector3(-1.6, 0, -1.1) * (1.0 if warm else -1.0)
	var start = Vector3(at.x, 0.2, at.y) - lean * 4.2 + Vector3(0, 9.4, 0)
	var fall = 0.34
	# The rock: a stone core in a shell of fire, tumbling as it comes.
	var rock = Node3D.new()
	add_child(rock)
	rock.position = start
	# The rock is the Blender kit's (fx_meteor): dark stone with glowing veins.
	var stone = Node3D.new()
	rock.add_child(stone)
	stone.scale = Vector3.ONE * radius * 1.6
	Robots.prop(self, stone, "fx_meteor:" + str(warm), ["fx_meteor"], {"shell": Color("3b3438") if warm else Color("342f45"), "glow": color, "dark": Color("1e1a22"), "wear": 0.6})
	sphere(rock, Vector3.ZERO, Vector3.ONE * radius * 2.1, Color(color, 0.35), true)
	# The target lights up on the floor while the rock is on its way: you see where it lands.
	var target = torus(self, Vector3(at.x, 0.08, at.y), radius * 1.6, 0.05, Color(color, 0.9), true)
	effects.append({"node": target, "v": Vector3.ZERO, "ttl": fall, "life": fall, "gravity": false, "base": Vector3.ONE, "keep": true})
	var velocity = (Vector3(at.x, 0.2, at.y) - start) / fall
	effects.append({"node": rock, "v": velocity, "ttl": fall, "life": fall, "gravity": false, "base": Vector3.ONE, "keep": true, "spin": true})
	# The tail: embers left behind along the way down.
	var tail = emitter(start, color, 20, fall + 0.2, 1.8, 18.0, radius * 0.75, -1.2, -velocity.normalized())
	if tail != null:
		tail.emitting = false
		tail.emitting = true
	# Landing: crater ring, dust, a flash and a mark that stays a moment.
	# The dust, the light and the crater belong to the landing, not to the launch.
	schedule(fall, func(): meteor_impact(at, radius, color, hot))

func meteor_impact(at: Vector2, radius: float, color: Color, hot: Color) -> void:
	scorch(at, radius * 4.2, color, 1.4)
	emitter(Vector3(at.x, 0.2, at.y), hot, 22, 0.5, 6.5, 74.0, 0.26, -9.0, Vector3.UP)
	emitter(Vector3(at.x, 0.1, at.y), color, 14, 0.75, 3.2, 88.0, 0.32, -2.0, Vector3.UP)
	dust(Vector3(at.x, 0.15, at.y), Color("cbbfae"), 10, 1.1, 1.4, 0.75)
	flash(Vector3(at.x, 0.9, at.y), color, 6.0, 0.3, 8.0)
	shake(0.32)
	var crater = torus(self, Vector3(at.x, 0.12, at.y), radius * 0.9, 0.07, Color(hot, 0.95), true)
	crater.scale = Vector3.ONE * 0.25
	effects.append({"node": crater, "v": Vector3.ZERO, "ttl": 0.45, "life": 0.45, "gravity": false, "base": Vector3.ONE * 2.1, "grow": true, "tint": color})

# Rockets in flight (Salvo's missiles, Magnus's bazooka round): a kit model flown along a
# curve, trailing fire and smoke. {node, from, apex, to, t, life, fire, big}
var flights: Array = []

func fly(node: Node3D, from: Vector3, apex: Vector3, to: Vector3, life: float, fire: Color, big: bool) -> void:
	node.position = from
	flights.append({"node": node, "from": from, "apex": apex, "to": to, "t": 0.0, "life": maxf(life, 0.05), "fire": fire, "big": big})

func flight_point(f: Dictionary, k: float) -> Vector3:
	var a: Vector3 = f.from.lerp(f.apex, k)
	var b: Vector3 = f.apex.lerp(f.to, k)
	return a.lerp(b, k)

func step_flights(dt: float) -> void:
	for i in range(flights.size() - 1, -1, -1):
		var f: Dictionary = flights[i]
		f.t += dt
		var k = clampf(f.t / f.life, 0.0, 1.0)
		var node: Node3D = f.node
		if not is_instance_valid(node):
			flights.remove_at(i)
			continue
		var here = flight_point(f, k)
		var ahead = flight_point(f, minf(k + 0.04, 1.0))
		node.position = here
		if ahead.distance_to(here) > 0.001:
			node.look_at(ahead, Vector3.UP if absf((ahead - here).normalized().y) < 0.98 else Vector3.RIGHT)
		if fx != null:
			# Fire out of the nozzle and a trail of smoke that hangs behind.
			var back = -(ahead - here).normalized()
			var nozzle = here + back * (0.62 if f.big else 0.42)
			fx.emit("glow", nozzle, back * 2.5, Color(f.fire, 0.95), 0.55 if f.big else 0.38, 0.1, 0.18)
			fx.emit("glow", nozzle, back * 1.2, Color("fff1c8", 0.9), 0.28 if f.big else 0.2, 0.05, 0.1)
			if Engine.get_process_frames() % 2 == 0:
				fx.smoke(nozzle, Color("5d5752"), 1, 0.55 if f.big else 0.4, 1.3, 0.05, 0.5)
		if k >= 1.0:
			node.queue_free()
			flights.remove_at(i)

func rocket_paint(team: int) -> Dictionary:
	var paint = Robots.colors(int(unit_skins[team]), CYAN if team == 0 else CORAL)
	paint["wear"] = 0.3
	return paint

func missile_launch(team: int, at: Vector2, seconds: float) -> void:
	# Out of Salvo's shoulder pod, up in an arc and down on the wall.
	var body: Node3D = units[team].get_node("Body")
	var from: Vector3 = body.global_transform * Vector3(0.5, 1.55, -0.3)
	var to = Vector3(at.x, 0.3, at.y)
	var apex = from.lerp(to, 0.45) + Vector3.UP * 4.5
	var missile = Node3D.new()
	add_child(missile)
	Robots.prop(self, missile, "fx_missile", ["fx_missile"], rocket_paint(team))
	missile.scale = Vector3.ONE * 1.3
	fly(missile, from, apex, to, seconds, Color("ff8a2a"), false)
	emitter(from, Color("ffcf7a"), 10, 0.3, 4.0, 40.0, 0.2, -2.0, Vector3.UP)
	dust(from, Color("8a8580"), 4, 0.9, 1.0, 0.5)
	# Where it will land glows on the floor while it is on its way.
	var target = torus(self, Vector3(at.x, 0.08, at.y), 0.9, 0.05, Color("ff8a2a", 0.9), true)
	effects.append({"node": target, "v": Vector3.ZERO, "ttl": seconds, "life": seconds, "gravity": false, "base": Vector3.ONE, "keep": true})

func bazooka_fire(team: int, at: Vector2, seconds: float, windup: float) -> void:
	# The arm becomes a rocket tube, kicks back as it fires, then folds away.
	var gun: Node3D = units[team].get_node_or_null("Body/Gun")
	if gun == null:
		return
	var flash_node: Node3D = gun.get_node_or_null("Flash")
	var muzzle: Vector3 = flash_node.position if flash_node != null else Vector3(0.44, 0.9, -1.1)
	var tube = Node3D.new()
	tube.name = "Bazooka"
	gun.add_child(tube)
	tube.position = muzzle + Vector3(0, 0.02, 0.62)
	Robots.prop(self, tube, "fx_bazooka", ["fx_bazooka"], rocket_paint(team))
	tube.scale = Vector3.ONE * 0.05
	var grow = create_tween()
	grow.tween_property(tube, "scale", Vector3.ONE * 1.05, windup * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var color = Rules.power_color("b_forge")
	emitter(gun.global_transform * muzzle, color, 14, 0.35, 2.5, 90.0, 0.16, -1.0, Vector3.UP)
	schedule(windup, func():
		if not is_instance_valid(tube):
			return
		var mouth: Vector3 = tube.global_transform * Vector3(0, 0, -0.72)
		var to = Vector3(at.x, 0.4, at.y)
		var rocket = Node3D.new()
		add_child(rocket)
		Robots.prop(self, rocket, "fx_rocket", ["fx_rocket"], rocket_paint(team))
		rocket.scale = Vector3.ONE * 1.2
		fly(rocket, mouth, mouth.lerp(to, 0.5) + Vector3.UP * 0.5, to, maxf(seconds - windup, 0.08), Color("ffb347"), true)
		flash(mouth, Color("ffcf7a"), 6.0, 0.25, 8.0)
		emitter(mouth, Color("fff0c8"), 18, 0.3, 6.0, 30.0, 0.24, -1.0, (to - mouth).normalized())
		dust(mouth, Color("8a8580"), 6, 1.0, 1.6, 0.7)
		shake_event(0.55, 0.3, 18.0, (to - mouth).normalized())
		# Recoil: the tube kicks back along the arm.
		var kick = create_tween()
		kick.tween_property(tube, "position:z", tube.position.z + 0.25, 0.06)
		kick.tween_property(tube, "position:z", tube.position.z, 0.2))
	schedule(seconds + 0.45, func():
		if is_instance_valid(tube):
			var fold = create_tween()
			fold.tween_property(tube, "scale", Vector3.ONE * 0.02, 0.2)
			fold.tween_callback(tube.queue_free))

func rocket_impact(at: Vector2, radius: float, big: bool) -> void:
	# Salvo's missile: a tight fireball. Magnus's rocket: a wide blast with a shock ring.
	var fire = Color("ff8a2a") if not big else Color("ffb347")
	var hot = Color("fff0cf")
	scorch(at, radius * 3.2, Color("2a1e18"), 1.8)
	emitter(Vector3(at.x, 0.3, at.y), hot, 26 if big else 16, 0.45, 7.5 if big else 5.5, 80.0, 0.3, -8.0, Vector3.UP)
	emitter(Vector3(at.x, 0.2, at.y), fire, 30 if big else 16, 0.7, 4.5 if big else 3.0, 90.0, 0.36, -2.0, Vector3.UP)
	dust(Vector3(at.x, 0.2, at.y), Color("6a625c"), 14 if big else 7, 1.4, 1.6, 0.9 if big else 0.6)
	flash(Vector3(at.x, 1.0, at.y), fire, 9.0 if big else 6.0, 0.4, 16.0 if big else 9.0)
	if effects.size() + 3 < effect_limit:
		var ball = sphere(self, Vector3(at.x, 0.3, at.y), Vector3.ONE * 0.3, fire, true)
		effects.append({"node": ball, "v": Vector3.ZERO, "ttl": 0.35, "life": 0.35, "gravity": false, "base": Vector3.ONE, "expand": radius * 1.1, "height": radius * 0.9, "energy": []})
		var ring = torus(self, Vector3(at.x, 0.15, at.y), 1.0, 0.08, Color(hot, 0.95), true)
		ring.scale = Vector3.ONE * 0.2
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.45, "life": 0.45, "gravity": false, "base": Vector3.ONE * radius * 1.2, "grow": true, "tint": fire})
	shake(0.85 if big else 0.35)
	if big:
		light_field(fire, 0.9, 0.5)

func thunder_bolt(at: Vector2, radius: float) -> void:
	# A straight column of light dropped on the spot, not a drawn zigzag. It is built from
	# a stack of segments of different thicknesses, so the line has a shape of its own
	# without ever leaving the vertical, and it strobes: on, off, on, gone. A bolt that
	# hangs around reads as scenery; one that is over before you can follow it reads as
	# lightning.
	var color = Rules.power_color("thunder")
	var hot = Color("f2fbff")
	if effects.size() + 8 >= effect_limit + NUMBER_ALLOWANCE:
		return
	var mark = torus(self, Vector3(at.x, 0.06, at.y), radius * 1.5, 0.05, Color(hot, 0.85), true)
	mark.scale = Vector3.ONE * 1.6
	effects.append({"node": mark, "v": Vector3.ZERO, "ttl": 0.26, "life": 0.26, "gravity": false, "base": Vector3.ONE * 0.9, "grow": false, "tint": color})
	# Three flashes, each thinner and shorter than the one before it.
	# Long enough to be seen at sixty frames a second, short enough that it is gone before
	# the eye settles on it. Below a tenth of a second a phone dropping frames never draws
	# it at all.
	pending.append({"time": 0.14, "call": func(): thunder_stroke(at, color, hot, 1.0, 0.11)})
	pending.append({"time": 0.27, "call": func(): thunder_stroke(at, color, hot, 0.62, 0.08)})
	pending.append({"time": 0.37, "call": func(): thunder_stroke(at, color, hot, 0.34, 0.06)})
	pending.append({"time": 0.16, "call": func(): thunder_land(at, radius, color, hot)})
	# A column of charged air stays over the spot a moment after the strokes, so the strike
	# is read even by an eye that blinked through the flashes.
	var column = cylinder(self, Vector3(at.x, BOLT_TOP * 0.5, at.y), radius * 0.45, BOLT_TOP, Color(color, 0.45), true, 16)
	effects.append({"node": column, "v": Vector3.ZERO, "ttl": 0.6, "life": 0.6, "gravity": false, "base": Vector3.ONE, "keep": true})

func thunder_stroke(at: Vector2, color: Color, hot: Color, weight: float, life: float) -> void:
	# One flash of the column. The thicknesses run heavy at the top and fine at the ground,
	# with a couple of swellings on the way down, and a hard white core the whole length.
	# It draws on the same reserve as the numbers: the bolt is the ultimate, and it was
	# being dropped in exactly the frames where the storm had filled the pool.
	if effects.size() >= effect_limit + NUMBER_ALLOWANCE:
		return
	var bolt = Node3D.new()
	add_child(bolt)
	var widths: Array = [0.62, 0.3, 0.5, 0.2, 0.4, 0.16, 0.3, 0.12]
	var floor_y := 0.12
	# Three and a half units, not the whole eight: seen from this camera a column as tall
	# as the sky projects clean out of the top of the arena and reads as something floating
	# in the dark rather than as a bolt landing on that spot.
	var span: float = (BOLT_TOP - floor_y) / float(widths.size())
	# Boxes standing on end, not segments: `segment` lays its length along X and only turns
	# about Y, so a vertical one comes out lying flat on the floor.
	for step in range(widths.size()):
		var low := floor_y + step * span
		var wide: float = float(widths[widths.size() - 1 - step]) * weight
		var kink = Vector2(0.09 if step % 2 == 0 else -0.09, 0.06 if step % 3 == 0 else -0.04) * weight
		cylinder(bolt, Vector3(at.x + kink.x, low + span * 0.5, at.y + kink.y), wide * 0.5, span, Color(color, 0.32), true, 10)
	var core: float = 0.15 * weight
	cylinder(bolt, Vector3(at.x, (floor_y + BOLT_TOP) * 0.5, at.y), core * 0.5, BOLT_TOP - floor_y, Color(hot, 1.0), true, 8)
	effects.append({"node": bolt, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "keep": true})

func thunder_land(at: Vector2, radius: float, color: Color, hot: Color) -> void:
	# What the ground does about it.
	if effects.size() + 2 < effect_limit:
		var ring = torus(self, Vector3(at.x, 0.12, at.y), radius * 0.8, 0.08, Color(hot, 0.95), true)
		ring.scale = Vector3.ONE * 0.25
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3.ONE * 2.6, "grow": true, "tint": color})
	emitter(Vector3(at.x, 0.2, at.y), hot, 30, 0.45, 8.5, 78.0, 0.24, -12.0, Vector3.UP)
	emitter(Vector3(at.x, 0.1, at.y), color, 16, 0.7, 5.0, 90.0, 0.22, -3.0, Vector3.UP)
	dust(Vector3(at.x, 0.12, at.y), Color("b9cdd4"), 8, 0.9, 1.2, 0.6)
	flash(Vector3(at.x, 1.4, at.y), color, 9.0, 0.3, 9.0)
	scorch(at, radius * 4.0, color, 1.2)
	shake(0.5)

func bloom_flash(positions: Array, heal: int) -> void:
	# A wave of green light crosses the wall, petals lift off each brick and a +2 floats up.
	var color = Rules.power_color("bloom")
	var pale = Color("e6ffd0")
	if positions.is_empty():
		return
	var middle = Vector2.ZERO
	for at in positions:
		middle += at
	middle /= positions.size()
	var wave = torus(self, Vector3(middle.x, 0.45, middle.y), 1.0, 0.09, Color(pale, 0.9), true)
	effects.append({"node": wave, "v": Vector3.ZERO, "ttl": 0.7, "life": 0.7, "gravity": false, "base": Vector3.ONE * 7.5, "grow": true, "tint": color})
	flash(Vector3(middle.x, 1.2, middle.y), color, 4.5, 0.55, 12.0)
	for index in range(positions.size()):
		var at: Vector2 = positions[index]
		if effects.size() + 3 >= effect_limit:
			return
		# Every third brick gets the full treatment; the rest keep it cheap.
		if index % 3 == 0:
			emitter(Vector3(at.x, 0.45, at.y), color, 12, 0.8, 2.4, 42.0, 0.26, -1.4, Vector3.UP)
		var halo = torus(self, Vector3(at.x, 0.42, at.y), 0.38, 0.045, Color(color, 0.85), true)
		effects.append({"node": halo, "v": Vector3(0, 1.3, 0), "ttl": 0.55, "life": 0.55, "gravity": false, "base": Vector3.ONE * 1.5, "grow": true, "tint": color})
		if index % 2 == 1 and effects.size() < effect_limit:
			# A shaft of green light stands up out of the brick as it heals.
			var shaft = cylinder(self, Vector3(at.x, 1.0, at.y), 0.2, 2.0, Color(color, 0.55), true, 14)
			effects.append({"node": shaft, "v": Vector3(0, 0.6, 0), "ttl": 0.75, "life": 0.75, "gravity": false, "base": Vector3.ONE, "keep": true})
			if fx != null:
				for k in range(3):
					fx.emit("glow", Vector3(at.x + randf_range(-0.2, 0.2), 0.5, at.y + randf_range(-0.2, 0.2)), Vector3(0, randf_range(1.6, 2.6), 0), Color(pale, 0.9), 0.18, 0.02, 0.8)
		if index % 2 == 0:
			gain_mark(at, heal, color)

func surge_flash(at: Vector2) -> void:
	# The gauntlet overloads: rings open off the pilot and sparks come with them. The rest
	# of the reading is the rounds themselves, which come out gold like a boosted shot.
	var color = Rules.power_color("surge")
	for step in range(3):
		if effects.size() >= effect_limit:
			break
		var life = 0.5 + step * 0.12
		var ring = torus(self, Vector3(at.x, 0.36 + step * 0.2, at.y), 0.5, 0.07, Color(color, 0.9), true)
		ring.scale = Vector3.ONE * 0.25
		effects.append({"node": ring, "v": Vector3(0, 0.7, 0), "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE * 3.2, "grow": true, "tint": color})
	if effects.size() < effect_limit:
		# A column of overload round the pilot, thinning out as it fades.
		var aura = cylinder(self, Vector3(at.x, 1.1, at.y), 0.8, 2.4, Color(color, 0.7), true, 24)
		effects.append({"node": aura, "v": Vector3(0, 0.4, 0), "ttl": 1.1, "life": 1.1, "gravity": false, "base": Vector3.ONE, "keep": true})
	emitter(Vector3(at.x, 0.7, at.y), GOLD, 26, 0.9, 3.4, 70.0, 0.3, -1.6, Vector3.UP)
	flash(Vector3(at.x, 1.3, at.y), color, 5.0, 0.6, 12.0)
	shake(0.35)

func volley_flash(at: Vector2, heading: Vector2) -> void:
	# One wave of the fan: a wide arc of light off the lantern, five times over.
	var color = Rules.power_color("volley")
	burst(at + heading * 0.7, color, false)
	if effects.size() < effect_limit:
		var arc = torus(self, Vector3(at.x, 0.45, at.y), 0.7, 0.05, Color(color, 0.85), true)
		effects.append({"node": arc, "v": Vector3.ZERO, "ttl": 0.32, "life": 0.32, "gravity": false, "base": Vector3.ONE * 2.6, "grow": true, "tint": color})
	# Five lances of light down the fan, gone as fast as they came.
	for k in range(5):
		if effects.size() >= effect_limit:
			break
		var dir = heading.rotated(lerpf(-0.42, 0.42, k / 4.0))
		var lance = segment(self, Vector3(at.x, 0.55, at.y) + Vector3(dir.x, 0, dir.y) * 0.8, Vector3(at.x, 0.55, at.y) + Vector3(dir.x, 0, dir.y) * 4.6, 0.16, 0.16, Color(color, 0.9), true)
		effects.append({"node": lance, "v": Vector3(dir.x, 0, dir.y) * 3.0, "ttl": 0.32, "life": 0.32, "gravity": false, "base": Vector3.ONE, "keep": true})
	flash(Vector3(at.x, 0.9, at.y), color, 3.2, 0.3, 8.0)
	for lane in [-0.45, 0.0, 0.45]:
		if effects.size() >= effect_limit:
			break
		var way = heading.rotated(lane)
		var missile = Node3D.new()
		add_child(missile)
		missile.position = Vector3(at.x, 1.3, at.y)
		missile.rotation.y = -Vector2(way.x, way.y).angle() - PI * 0.5
		var body = cylinder(missile, Vector3.ZERO, 0.07, 0.36, Color("4f6db3"), false, 10)
		body.rotation.x = PI * 0.5
		var nose = cone(missile, Vector3(0, 0, -0.24), 0.07, 0.14, color, true, 10)
		nose.rotation.x = -PI * 0.5
		sphere(missile, Vector3(0, 0, 0.2), Vector3.ONE * 0.14, Color(color, 0.8), true)
		effects.append({"node": missile, "v": Vector3(way.x, 0.25, way.y) * 11.0, "ttl": 0.4, "life": 0.4, "gravity": false, "base": Vector3.ONE, "keep": true})

# How fast the front of the wave crosses the floor, so each brick lights up as it
# arrives instead of the whole wall flashing at once.
const SHOCK_SPEED = 24.0

func tally_mark(team: int, at: Vector2, amount: int, color: Color) -> void:
	# Starts at the first bite and climbs with every one after it, then lingers a moment
	# past the last so the final figure can be read.
	if amount <= 0 or team < 0 or team > 1:
		return
	var box: Dictionary = tally[team]
	if not box.is_empty() and is_instance_valid(box.node):
		box.total = int(box.total) + amount
		box.left = TALLY_HOLD
		box.pop = 1.0
		box.node.text = "-%d" % int(box.total)
		return
	# Centred over the half it is hitting, not over the first brick: a blow that starts at
	# the edge of the wall would otherwise put the figure half off the screen.
	var label = world_label("-%d" % amount, Vector3(0.0, 2.5, at.y), color.lightened(0.4), 128)
	label.outline_size = 36
	label.outline_modulate = Color(0.01, 0.04, 0.05, 0.96)
	label.no_depth_test = true
	label.render_priority = 6
	label.outline_render_priority = 5
	if chase:
		# Seen from behind the pilot the figure stands over the bricks it is about.
		label.position.x = at.x
	stand_for_camera(label)
	tally[team] = {"node": label, "total": amount, "left": TALLY_HOLD, "pop": 1.0}

func step_tallies(dt: float) -> void:
	for team in range(2):
		var box: Dictionary = tally[team]
		if box.is_empty():
			continue
		if not is_instance_valid(box.node):
			tally[team] = {}
			continue
		box.left = float(box.left) - dt
		if box.left <= 0:
			box.node.queue_free()
			tally[team] = {}
			continue
		# A kick each time it climbs, then it settles and drifts up as it fades out.
		box.pop = maxf(0.0, float(box.pop) - dt * 4.0)
		box.node.scale = Vector3.ONE * (1.0 + float(box.pop) * 0.3)
		box.node.position.y += dt * 0.4
		box.node.modulate.a = clampf(float(box.left) / TALLY_FADE, 0.0, 1.0)

func float_number(text: String, at: Vector3, color: Color, size: int, life: float) -> void:
	# Every number that floats off the field goes through here, because the field is the
	# hardest place in the game to read text on: a teal floor, cream walls and whatever the
	# effect itself is throwing off. So each one is drawn over everything else, in a strong
	# colour, inside a thick dark outline. Without the outline the greens and the ambers
	# both disappeared into the floor.
	if effects.size() >= effect_limit + NUMBER_ALLOWANCE:
		return
	var label = world_label(text, at, color, size)
	label.outline_size = maxi(18, size / 4)
	label.outline_modulate = Color(0.01, 0.04, 0.05, 0.96)
	label.no_depth_test = true
	label.render_priority = 5
	label.outline_render_priority = 4
	stand_for_camera(label)
	effects.append({"node": label, "v": Vector3(0, 0.8, 0), "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "keep": true})

func stand_for_camera(label: Label3D) -> void:
	# From above, the numbers lie on the field like paint. In third person they stand up and
	# turn to the camera like a third-person game's, at a size read from close by.
	if not chase:
		return
	label.rotation = Vector3.ZERO
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0042

func damage_mark(team: int, at: Vector2, bite: int) -> void:
	# What a single brick took, floating off it. A power hits a whole wall at once and the
	# counter on the card only moves by the total; this is where that total comes from.
	if bite <= 0:
		return
	# Pale for a scratch, amber for two, red for three: the colour says it before the digit.
	var color: Color = [Color("fff6e0"), Color("fff0c4"), Color("ffb13c"), Color("ff6134")][clampi(bite, 0, 3)]
	# A ring says which brick and how hard; the total over the wall says how much the whole
	# attack has taken off so far.
	if effects.size() + 1 < effect_limit:
		var ring = torus(self, Vector3(at.x, 0.42, at.y), 0.3, 0.045, Color(color, 0.9), true)
		effects.append({"node": ring, "v": Vector3(0, 0.8, 0), "ttl": 0.4, "life": 0.4, "gravity": false, "base": Vector3.ONE * 1.7, "grow": true, "tint": color})
	tally_mark(team, at, bite, color)

func gain_mark(at: Vector2, gain: int, tint: Color) -> void:
	# A buff keeps its number on the thing it helps, one by one: it lands on a handful of
	# bricks at most, and seeing which ones is the point. Only damage, which can touch a
	# whole wall at once, is gathered into a single total.
	if gain <= 0:
		return
	float_number("+%d" % gain, Vector3(at.x, 1.6, at.y), tint.lightened(0.45), 84, 1.7)

func shock_mark(team: int, at: Vector2, bite: int, source: Vector2 = Vector2.ZERO) -> void:
	# One brick, caught by the wave: a halo in the colour of the blow and the lives it took
	# floating off it. Without this the ultimate is all sky and you cannot read what it did.
	if effects.size() + 2 >= effect_limit:
		return
	var color: Color = [Color("ffe9c0"), Color("ffd27a"), Color("ff9f5c"), Color("ff6a5c")][clampi(bite, 0, 3)]
	var halo = torus(self, Vector3(at.x, 0.42, at.y), 0.32, 0.05, Color(color, 0.95), true)
	effects.append({"node": halo, "v": Vector3(0, 1.0, 0), "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3.ONE * 2.0, "grow": true, "tint": color})
	# Chips torn off the brick and thrown the way the wave is going.
	var away = (at - source).normalized() if at.distance_to(source) > 0.01 else Vector2.UP
	for i in range(2 + mini(bite, 3)):
		var kick = Vector3(away.x, 0, away.y) * randf_range(2.5, 5.0) + Vector3(randf_range(-1, 1), randf_range(2.5, 4.5), randf_range(-1, 1))
		feedback_chip(Vector3(at.x, 0.4, at.y), kick, Color("2a1d38").lerp(color, 0.35), 0.55, Vector3.ONE * randf_range(0.07, 0.12), true)
	tally_mark(team, at, bite, color)

func shock_wall_shape() -> ArrayMesh:
	# An open band one unit wide and one unit tall, with a rounded lip: scaled out it is the
	# wall of force of the singularity's release.
	if shapes.has("shock_wall"):
		return shapes["shock_wall"]
	var profile = [Vector2(1.0, 0.0), Vector2(1.0, 0.72), Vector2(0.992, 0.9), Vector2(0.975, 1.0), Vector2(0.958, 0.9), Vector2(0.95, 0.72), Vector2(0.95, 0.0)]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides = 64
	for i in range(sides):
		var a0 = float(i) / sides * TAU
		var a1 = float(i + 1) / sides * TAU
		for k in range(profile.size() - 1):
			var p0: Vector2 = profile[k]
			var p1: Vector2 = profile[k + 1]
			var v00 = Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 = Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 = Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 = Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			triangle(st, v00, v10, v11)
			triangle(st, v00, v11, v01)
			triangle(st, v00, v11, v10)
			triangle(st, v00, v01, v11)
	var shape = st.commit()
	shapes["shock_wall"] = shape
	return shape

func shock_wave(at: Vector2, marks: Array = [], hurt: int = 1) -> void:
	# The core lets go: a solid wall of dark force, lit white on the inside, that leaves the
	# pilot at the speed the bricks are struck and runs out past the walls. The ground is
	# scorched under the core, dust rises where the front passes, the whole arena flashes
	# violet and the camera takes the blow.
	var color = Rules.power_color("singularity")
	var deep = color.darkened(0.55)
	var pale = Color("f1e2ff")
	var reach = Rules.HALF_LENGTH * 2.0 + 4.0
	var life = reach / SHOCK_SPEED
	var centre = Vector3(at.x, 0.0, at.y)
	if effects.size() + 10 < effect_limit:
		# A wall of force taller than a pilot, so it towers over the camera in third person:
		# the dark front, a bright inner face, a glowing crest riding its top and a second,
		# lower wave a beat behind.
		var front = mesh(self, shock_wall_shape(), centre, deep, true)
		effects.append({"node": front, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "expand": reach * 1.03, "height": 3.4, "energy": []})
		var inner = mesh(self, shock_wall_shape(), centre, pale, true)
		effects.append({"node": inner, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "expand": reach, "height": 2.3, "energy": []})
		var crest = mesh(self, shock_wall_shape(), centre + Vector3.UP * 0.0, color.lightened(0.35), true)
		effects.append({"node": crest, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "expand": reach * 1.045, "height": 3.8, "energy": []})
		var floor_ring = mesh(self, shock_wall_shape(), centre, color.lightened(0.15), true)
		effects.append({"node": floor_ring, "v": Vector3.ZERO, "ttl": life * 1.1, "life": life * 1.1, "gravity": false, "base": Vector3.ONE, "expand": reach * 0.96, "height": 0.35, "energy": []})
		schedule(0.22, func():
			if effects.size() + 2 < effect_limit:
				var echo = mesh(self, shock_wall_shape(), centre, deep.lerp(color, 0.5), true)
				effects.append({"node": echo, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "expand": reach * 0.9, "height": 1.7, "energy": []})
				var echo_face = mesh(self, shock_wall_shape(), centre, pale, true)
				effects.append({"node": echo_face, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "expand": reach * 0.88, "height": 1.1, "energy": []}))
		# The core bursts: a dome that swells and flattens, and a pillar thrown straight up.
		var dome = sphere(self, centre, Vector3.ONE * 0.8, deep.lerp(color, 0.4), true)
		effects.append({"node": dome, "v": Vector3.ZERO, "ttl": 0.6, "life": 0.6, "gravity": false, "base": Vector3.ONE, "expand": 4.2, "height": 2.6, "energy": []})
		var pillar = cylinder(self, centre + Vector3.UP * 4.0, 0.6, 8.0, pale, true, 24)
		effects.append({"node": pillar, "v": Vector3(0, 7.0, 0), "ttl": 0.45, "life": 0.45, "gravity": false, "base": Vector3(1.6, 1.0, 1.6), "energy": []})
	# Sparks thrown up off the crest as it runs, all the way round.
	if fx != null:
		for step in range(1, 8):
			var radius_s = SHOCK_SPEED * step * 0.1
			schedule(step * 0.1, func():
				for k in range(12):
					var around = k * TAU / 12.0 + step * 0.3
					var spot = at + Vector2(cos(around), sin(around)) * radius_s
					if absf(spot.x) < Rules.HALF_WIDTH + 2.0 and absf(spot.y) < Rules.HALF_LENGTH + 2.0:
						fx.emit("glow", Vector3(spot.x, 3.0, spot.y), Vector3(cos(around) * 2.0, 3.5, sin(around) * 2.0), Color(color.lightened(0.4), 0.95), 0.35, 0.08, 0.45))
	scorch(at, 7.5, Color("1a0d26"), 2.6)
	emitter(Vector3(at.x, 0.6, at.y), pale, 44, 0.9, 14.0, 90.0, 0.34, -4.0, Vector3.UP)
	emitter(Vector3(at.x, 0.3, at.y), color, 30, 0.7, 11.0, 180.0, 0.3, -2.0, Vector3.UP)
	# Dust kicked up by the front as it runs across the floor.
	if fx != null:
		for step in range(1, 7):
			var radius = SHOCK_SPEED * step * 0.12
			schedule(step * 0.12, func():
				for k in range(16):
					var around = k * TAU / 16.0 + step * 0.4
					var spot = at + Vector2(cos(around), sin(around)) * radius
					if absf(spot.x) < Rules.HALF_WIDTH + 1.0 and absf(spot.y) < Rules.HALF_LENGTH + 1.0:
						fx.smoke(Vector3(spot.x, 0.25, spot.y), Color("3b2a4d"), 1, 0.9, 0.9, 0.3, 0.9))
	flash(Vector3(at.x, 1.4, at.y), color.lightened(0.25), 9.0, 0.8, 24.0)
	light_field(color.lightened(0.35), 1.35, 1.0)
	hold_mood(1.6)
	hitstop(0.07)
	dilate(0.55, 0.32)
	shake_event(1.25, 0.55, 15.0)
	schedule(0.3, func(): shake_event(0.5, 0.6, 9.0))
	# Every brick the wave catches lights up as the front reaches it, and says what it took.
	for mark in marks:
		var spot: Vector2 = mark.p
		var bite: int = int(mark.bite)
		pending.append({"time": clampf(at.distance_to(spot) / SHOCK_SPEED, 0.0, 0.8), "call": func(): shock_mark(hurt, spot, bite, at)})

func frost_flash(at: Vector2) -> void:
	# The frost taking hold: three rings racing out across the floor, a burst of crystal
	# shards thrown off the pilot, and the whole thing lit cold. The ice the pilot then
	# wears is built into the model and shown for as long as the clock runs.
	var color = Rules.power_color("freeze")
	var pale = Color("eafaff")
	for wave in range(3):
		if effects.size() >= effect_limit:
			break
		var life = 0.55 + wave * 0.16
		var ring = torus(self, Vector3(at.x, 0.1 + wave * 0.28, at.y), 1.0, 0.075 - wave * 0.015, Color(pale if wave == 0 else color, 0.95), true)
		ring.scale = Vector3.ONE * 0.2
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE * (3.4 + wave * 1.4), "grow": true, "tint": color})
	# Shards thrown outwards and falling: the crack of something freezing solid.
	for i in range(10):
		if effects.size() >= effect_limit:
			break
		var throw = i * 2.399
		var shard = cone(self, Vector3(at.x, 0.7, at.y), 0.09, 0.34, Color(pale, 0.9), true, 6)
		shard.rotation_degrees = Vector3(randf_range(-60, 60), randf_range(0, 360), randf_range(-60, 60))
		effects.append({"node": shard, "v": Vector3(cos(throw) * 3.4, 2.2, sin(throw) * 3.4), "ttl": 0.7, "life": 0.7, "gravity": true, "base": Vector3.ONE, "spin": true})
	var burst_ball = sphere(self, Vector3(at.x, 0.7, at.y), Vector3.ONE * 0.9, Color(pale, 0.55), true)
	effects.append({"node": burst_ball, "v": Vector3.ZERO, "ttl": 0.4, "life": 0.4, "gravity": false, "base": Vector3.ONE * 2.8, "grow": true, "tint": color})
	emitter(Vector3(at.x, 0.8, at.y), pale, 34, 1.3, 3.2, 75.0, 0.28, -2.2, Vector3.UP)
	flash(Vector3(at.x, 1.2, at.y), color, 6.5, 0.7, 15.0)
	shake(0.55)

func magnet_flash(at: Vector2) -> void:
	# The field snapping on: rings collapsing inwards onto the pilot, drawn in from wide,
	# and filings pulled off the floor with them.
	var color = Rules.power_color("magnet")
	for step in range(3):
		if effects.size() >= effect_limit:
			break
		var life = 0.5 + step * 0.14
		var ring = torus(self, Vector3(at.x, 0.25 + step * 0.35, at.y), 3.0, 0.055, Color(color, 0.9), true)
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE * 0.12, "grow": false, "tint": color})
	for i in range(8):
		if effects.size() >= effect_limit:
			break
		var lane = i * TAU / 8.0
		var filing = box(self, Vector3(at.x + cos(lane) * 2.6, 0.25, at.y + sin(lane) * 2.6), Vector3(0.14, 0.07, 0.07), Color(color, 0.95), true, 0.02)
		effects.append({"node": filing, "v": Vector3(-cos(lane) * 4.4, 1.1, -sin(lane) * 4.4), "ttl": 0.55, "life": 0.55, "gravity": false, "base": Vector3.ONE, "spin": true})
	emitter(Vector3(at.x, 0.7, at.y), Color("fff0c0"), 24, 0.8, 2.4, 70.0, 0.24, -1.6, Vector3.UP)
	flash(Vector3(at.x, 1.1, at.y), color, 5.0, 0.55, 11.0)
	shake(0.3)

func weld_flash(positions: Array) -> void:
	# A welding torch on each brick: a white bead of light and a spray of sparks off it.
	var color = Rules.power_color("weld")
	var white = Color("f2fff4")
	for index in range(positions.size()):
		if effects.size() + 2 >= effect_limit:
			return
		var at: Vector2 = positions[index]
		var bead = sphere(self, Vector3(at.x, 0.5, at.y), Vector3.ONE * 0.26, Color(white, 0.95), true)
		effects.append({"node": bead, "v": Vector3(0, 0.6, 0), "ttl": 0.45, "life": 0.45, "gravity": false, "base": Vector3.ONE, "spin": false})
		var halo = torus(self, Vector3(at.x, 0.42, at.y), 0.3, 0.04, Color(color, 0.9), true)
		effects.append({"node": halo, "v": Vector3.ZERO, "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3.ONE * 1.6, "grow": true, "tint": color})
		if index % 2 == 0:
			emitter(Vector3(at.x, 0.55, at.y), Color("ffe9a8"), 10, 0.55, 3.4, 80.0, 0.16, -8.0, Vector3.UP)
	if not positions.is_empty():
		var middle = Vector2.ZERO
		for at in positions:
			middle += at
		middle /= positions.size()
		flash(Vector3(middle.x, 1.0, middle.y), color, 4.5, 0.5, 12.0)

func thorns_flash(team: int) -> void:
	# Spikes standing up off every brick of that wall, for as long as they are out.
	var color = Rules.power_color("thorns")
	var half: int = brick_nodes.size() / 2
	for i in range(brick_nodes.size()):
		if (i < half) != (team == 0) or not brick_nodes[i].visible:
			continue
		if i % 2 != 0 or effects.size() + 1 >= effect_limit:
			continue
		var spike = cone(self, brick_nodes[i].position + Vector3(0, 0.5, 0), 0.12, 0.34, Color(color, 0.8), true, 8)
		effects.append({"node": spike, "v": Vector3.ZERO, "ttl": Rules.THORNS_SECONDS, "life": Rules.THORNS_SECONDS, "gravity": false, "base": Vector3.ONE, "keep": true})
	# A wave of violet light down the wall as the spikes come up, so it is not just a
	# quiet change of scenery.
	var line: float = Rules.goal_center(team).y * 0.55
	var wave = torus(self, Vector3(0, 0.4, line), 1.0, 0.08, Color(color, 0.9), true)
	effects.append({"node": wave, "v": Vector3.ZERO, "ttl": 0.65, "life": 0.65, "gravity": false, "base": Vector3.ONE * 7.5, "grow": true, "tint": color})
	emitter(Vector3(0, 0.6, line), color, 26, 0.9, 3.0, 110.0, 0.22, -2.0, Vector3.UP)
	flash(Vector3(0, 1.0, line), color, 5.0, 0.55, 14.0)
	shake(0.3)

func plating_flash(team: int) -> void:
	# Crystal closes over the wall: a plate lights up on each brick and stays lit while the
	# plating holds, so both sides can see why the rounds are bouncing.
	var color = Rules.power_color("plating")
	var pale = Color("e8fbff")
	var middle = Vector2.ZERO
	var count = 0
	for i in range(brick_nodes.size()):
		var node: Node3D = brick_nodes[i]
		if not node.visible or (i < brick_nodes.size() / 2) != (team == 0):
			continue
		middle += Vector2(node.position.x, node.position.z)
		count += 1
	if count == 0:
		return
	middle /= count
	# A faceted crystal of light rises over every other brick of the wall.
	for i in range(brick_nodes.size()):
		var node: Node3D = brick_nodes[i]
		if not node.visible or (i < brick_nodes.size() / 2) != (team == 0) or i % 2 != 0 or effects.size() >= effect_limit:
			continue
		var crystal = Node3D.new()
		add_child(crystal)
		crystal.position = node.position + Vector3(0, 0.75, 0)
		cone(crystal, Vector3(0, 0.14, 0), 0.14, 0.28, Color(color, 0.85), true, 6)
		var under = cone(crystal, Vector3(0, -0.1, 0), 0.14, 0.2, Color(pale, 0.85), true, 6)
		under.rotation.x = PI
		effects.append({"node": crystal, "v": Vector3(0, 0.25, 0), "ttl": 0.9, "life": 0.9, "gravity": false, "base": Vector3.ONE, "keep": true, "spin_y": true})
	var sheet = torus(self, Vector3(middle.x, 0.45, middle.y), 1.0, 0.08, Color(pale, 0.9), true)
	effects.append({"node": sheet, "v": Vector3.ZERO, "ttl": 0.7, "life": 0.7, "gravity": false, "base": Vector3.ONE * 7.0, "grow": true, "tint": color})
	flash(Vector3(middle.x, 1.2, middle.y), color, 5.0, 0.6, 13.0)

func plunder_land(team: int) -> void:
	# The two walls touch down on the far side: one thump per brick, and a flash across the
	# pair of them so the trade is read as one thing and not as eighty little ones.
	var color = Rules.power_color("plunder")
	for i in range(brick_nodes.size()):
		if effects.size() >= effect_limit:
			break
		if i % 3 != 0 or not brick_nodes[i].visible:
			continue
		var node: Node3D = brick_nodes[i]
		var ring = torus(self, node.position + Vector3(0, 0.1, 0), 0.3, 0.035, Color(color, 0.8), true)
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.4, "life": 0.4, "gravity": false, "base": Vector3.ONE * 1.6, "grow": true, "tint": color})
	flash(Vector3(0, 1.2, 0), color, 6.0, 0.55, 18.0)
	shake(0.5)

func plunder_flash(team: int) -> void:
	# Two curtains of light cross the arena in opposite directions, dragging embers with
	# them, and every brick flashes as it changes hands.
	var color = Rules.power_color("plunder")
	var pale = Color("fff0c8")
	for side in [-1.0, 1.0]:
		if effects.size() + 2 >= effect_limit:
			break
		var curtain = Node3D.new()
		add_child(curtain)
		curtain.position = Vector3(0, 0, side * Rules.HALF_LENGTH * 0.7)
		var span: float = Rules.side_x(map.get("outline", "hex"), Rules.narrow_of(map)) * 2.0
		# A wall of light sweeping across the arena: a bright leading edge on top, a veil
		# under it and a glow where it touches the floor.
		box(curtain, Vector3(0, 0.85, 0), Vector3(span, 1.7, 0.1), Color(color, 0.45), true, 0.02)
		box(curtain, Vector3(0, 0.85, 0), Vector3(span, 1.9, 0.35), Color(color, 0.18), true, 0.02)
		segment(curtain, Vector3(-span * 0.5, 1.72, 0), Vector3(span * 0.5, 1.72, 0), 0.08, 0.08, Color(pale, 0.95), true)
		box(curtain, Vector3(0, 0.05, 0), Vector3(span, 0.04, 1.6), Color(pale, 0.5), true, 0.02)
		effects.append({"node": curtain, "v": Vector3(0, 0, -side * 9.0), "ttl": 0.62, "life": 0.62, "gravity": false, "base": Vector3.ONE, "keep": true})
		emitter(Vector3(0, 0.6, side * Rules.HALF_LENGTH * 0.7), pale, 22, 0.7, 3.0, 85.0, 0.34, -1.2, Vector3.UP)
	flash(Vector3(0, 1.6, 0), color, 6.0, 0.5, 16.0)
	shake(0.4)
	for index in range(brick_nodes.size()):
		if index % 4 != 0 or effects.size() >= effect_limit:
			continue
		var brick: Node3D = brick_nodes[index]
		var mark = torus(self, Vector3(brick.position.x, 0.4, brick.position.z), 0.34, 0.04, Color(pale, 0.8), true)
		effects.append({"node": mark, "v": Vector3(0, 0.6, 0), "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3.ONE * 1.3, "grow": true, "tint": color})

func singularity_open(at: Vector2) -> void:
	# The moment the hole opens: the floor is scorched under it and the arena dust lifts.
	var color = Rules.power_color("singularity")
	scorch(at, 5.0, Color("0b0d14"), Rules.SINGULARITY_PULL + 0.6)
	scorch(at, 3.0, color, Rules.SINGULARITY_PULL + 0.2)
	for step in range(3):
		if effects.size() >= effect_limit:
			break
		# Three rings caught on the way in, staggered so the collapse reads at once.
		var width = 5.4 - step * 1.2
		var ring = torus(self, Vector3(at.x, 0.4 + step * 0.22, at.y), 1.0, 0.07 - step * 0.012, Color("ffe6b8" if step == 0 else color, 0.7), true)
		ring.scale = Vector3(width, 0.3, width)
		effects.append({"node": ring, "v": Vector3(0, 0.35, 0), "ttl": 0.5 + step * 0.16, "life": 0.5 + step * 0.16, "gravity": false, "base": Vector3(width, 0.3, width)})
	dust(Vector3(at.x, 0.2, at.y), Color("c8b79a"), 14, 1.1, 2.2, 0.9)
	flash(Vector3(at.x, 0.9, at.y), color, 6.0, 0.45, 12.0)
	shake(0.4)

func singularity_wave(at: Vector2, index: int, seconds: float) -> void:
	# A shock front out of the sky. It comes down past the rim of the arena and closes on
	# the pilot, a bright band with a curtain of light hanging off it, sweeping everything
	# it passes over towards the core.
	var color = Rules.power_color("singularity")
	var pale = Color("ffeccb")
	if effects.size() + 3 >= effect_limit:
		return
	var front = Node3D.new()
	add_child(front)
	# The front starts just outside the rim, so it sweeps the arena and not the screen. It
	# is modelled at radius 1 and scaled flat: only the ground plane grows, never the
	# height, or the band would come out as thick as a wall.
	var reach = Rules.HALF_LENGTH * 1.5
	var band = torus(front, Vector3.ZERO, 1.0, 0.011, Color(pale, 0.95), true)
	var halo = torus(front, Vector3.ZERO, 1.0, 0.03, Color(color, 0.28), true)
	halo.scale = Vector3(1, 1.8, 1)
	# A fainter band chasing the first one: two edges read as a wave, one reads as a hoop.
	var trail = torus(front, Vector3(0, 0.3, 0), 0.93, 0.02, Color(color, 0.2), true)
	trail.scale = Vector3(1, 1.2, 1)
	# A low skirt under the band rather than hanging spokes: a slab sheared by the flat
	# scale reads as a stray bar, a second ring does not.
	var skirt = torus(front, Vector3(0, -0.22, 0), 1.0, 0.026, Color(color, 0.5), true)
	skirt.scale = Vector3(1, 2.4, 1)
	var sky = 4.6 - index * 1.1
	front.position = Vector3(at.x, sky, at.y)
	front.scale = Vector3(reach, 1.0, reach)
	# The default fade shrinks it to nothing: that is the sweep closing on the pilot.
	effects.append({"node": front, "v": Vector3(0, -(sky - 0.45) / seconds, 0), "ttl": seconds, "life": seconds, "gravity": false, "base": Vector3(reach, 1.0, reach)})
	# Dust lifted off the floor all around the rim as the wave breaks over it.
	for i in range(6):
		if effects.size() >= effect_limit:
			break
		var angle = i * TAU / 6.0 + index * 0.4
		var edge = at + Vector2(cos(angle), sin(angle)) * (Rules.HALF_WIDTH * 0.85)
		var inward = (at - edge).normalized()
		emitter(Vector3(edge.x, 0.3, edge.y), color, 10, 0.75, 6.0, 22.0, 0.3, -1.0, Vector3(inward.x, 0.25, inward.y))
	flash(Vector3(at.x, 2.4, at.y), color, 5.0 + index * 1.5, 0.3, 14.0)
	shake(0.3 + index * 0.12)

func singularity_swallow(at: Vector2) -> void:
	# One round going down the throat: a short bright lick around the core.
	if effects.size() >= effect_limit:
		return
	var ring = torus(self, Vector3(at.x, 0.62, at.y), 0.42, 0.04, Color("fff0cf", 0.95), true)
	ring.rotation.z = PI * 0.5
	ring.scale = Vector3.ONE * 2.1
	effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.22, "life": 0.22, "gravity": false, "base": Vector3.ONE * 2.1})
	emitter(Vector3(at.x, 0.62, at.y), Color("ffd79a"), 6, 0.25, 2.4, 120.0, 0.18, 0.0, Vector3.UP)

func shock_pulse(at: Vector2) -> void:
	# Two rings racing outwards, a dome of light over the pilot and a spray of sparks.
	var color = Rules.power_color("stun")
	var pale = Color("eafaff")
	for wave in range(2):
		if effects.size() >= effect_limit:
			break
		var ring = torus(self, Vector3(at.x, 0.35 + wave * 0.15, at.y), 1.0, 0.09 - wave * 0.03, Color(pale if wave == 0 else color, 0.95), true)
		ring.scale = Vector3.ONE * 0.2
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.7 + wave * 0.15, "life": 0.7 + wave * 0.15, "gravity": false, "base": Vector3.ONE * (9.0 + wave * 3.0), "grow": true, "tint": color})
	var dome = sphere(self, Vector3(at.x, 0.5, at.y), Vector3.ONE * 1.2, Color(color, 0.45), true)
	effects.append({"node": dome, "v": Vector3.ZERO, "ttl": 0.45, "life": 0.45, "gravity": false, "base": Vector3.ONE * 3.4, "grow": true, "tint": color})
	emitter(Vector3(at.x, 0.5, at.y), pale, 26, 0.6, 7.0, 85.0, 0.3, -5.0, Vector3.UP)
	flash(Vector3(at.x, 1.2, at.y), color, 6.5, 0.4, 13.0)
	shake(0.45)

func rebuild_flash(positions: Array) -> void:
	# Each brick comes back inside a ring of light, so the wall visibly grows again.
	for at in positions:
		if effects.size() >= effect_limit:
			return
		burst(at, Rules.power_color("rebuild"), false)
		var ring = torus(self, Vector3(at.x, 0.42, at.y), 0.62, 0.07, Color(Rules.power_color("rebuild"), 0.95), true)
		ring.scale = Vector3(2.0, 1.0, 2.0)
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.55, "life": 0.55, "gravity": false, "base": Vector3(2.0, 1.0, 2.0), "tint": Rules.power_color("rebuild")})

func build_sentry(team: int) -> Node3D:
	# A squat little gun platform: ceramic drum on a brass ring, a barrel that recoils, and
	# five pips of health around the collar so the rival can see how close it is to falling.
	var color = CYAN if team == 0 else CORAL
	var root = Node3D.new()
	add_child(root)
	# A glow on the floor marks it as yours from across the arena, the way a shot does.
	soft_disc(root, Vector3(0, 0.02, 0), Vector2(2.2, 2.2), Color(color, 0.4))
	var drum = Node3D.new()
	drum.name = "Drum"
	root.add_child(drum)
	# ROSCA's workshop build: a round copper drum with a toothed gear collar, a domed head
	# with a lit lens, and a riveter barrel with a coil spring out front. Tall enough not to
	# be taken for a bumper.
	# The Blender kit's sentry (fx_sentry_body / fx_sentry_gun): armoured gunmetal, a band of
	# the team's energy, a lit lens, a twin barrel that recoils.
	var paint = {"shell": Color("4f5866"), "glow": color, "dark": Color("22262f"), "metal": Color("a3aebb"), "wear": 0.55}
	Robots.prop(self, drum, "fx_sentry_body", ["fx_sentry_body"], paint.duplicate())
	var gun = Node3D.new()
	gun.name = "Gun"
	drum.add_child(gun)
	Robots.prop(self, gun, "fx_sentry_gun", ["fx_sentry_gun"], paint.duplicate())
	var flash = sphere(gun, Vector3(0, 0.6, 0.78), Vector3.ONE * 0.2, Color("fff2cf"), true)
	flash.name = "Flash"
	flash.scale = Vector3.ONE * 0.001
	for pip in range(Rules.TURRET_LIVES):
		var angle = -PI * 0.5 + (pip - (Rules.TURRET_LIVES - 1) * 0.5) * 0.36
		var light = sphere(root, Vector3(cos(angle) * 0.5, 0.34, sin(angle) * 0.5), Vector3.ONE * 0.075, Color(color, 0.95), true)
		light.name = "Pip%d" % pip
	return root

func update_sentries(rules, dt: float) -> void:
	# Built when the ultimate puts them down, lit by their own health, and freed the moment
	# the rival shoots one apart.
	var alive: Array = []
	for data in rules.turrets:
		if not data.alive:
			continue
		alive.append(data.id)
		if not sentries.has(data.id):
			sentries[data.id] = build_sentry(int(data.team))
			sentries[data.id].set_meta("reload", float(data.cooldown))
			spawn_flash(data.p, CYAN if data.team == 0 else CORAL)
		var node: Node3D = sentries[data.id]
		node.position = Vector3(data.p.x, 0.0, data.p.y)
		var drum: Node3D = node.get_node("Drum")
		drum.rotation.y = atan2(data.aim.x, data.aim.y)
		var gun: Node3D = drum.get_node("Gun")
		# A round just left: kick the barrel back and light the muzzle.
		if float(data.cooldown) > float(node.get_meta("reload")) + 0.05:
			gun.position.z = -0.16
			gun.get_node("Flash").scale = Vector3.ONE * 1.0
			emitter(node.position + Vector3(data.aim.x, 0.0, data.aim.y) * 0.8 + Vector3(0, 0.6, 0), Color("fff2cf"), 8, 0.28, 6.0, 20.0, 0.2, -1.0, Vector3(data.aim.x, 0.1, data.aim.y))
		node.set_meta("reload", float(data.cooldown))
		gun.position.z = lerpf(gun.position.z, 0.0, minf(dt * 16, 1))
		gun.get_node("Flash").scale = gun.get_node("Flash").scale.lerp(Vector3.ONE * 0.001, minf(dt * 20, 1))
		for pip in range(Rules.TURRET_LIVES):
			node.get_node("Pip%d" % pip).visible = pip < int(data.hp)
	for id in sentries.keys():
		if not alive.has(id):
			sentries[id].queue_free()
			sentries.erase(id)

func spawn_flash(at: Vector2, color: Color) -> void:
	# A sentry arriving: it unfolds out of a ring of light.
	if effects.size() + 2 >= effect_limit:
		return
	var ring = torus(self, Vector3(at.x, 0.12, at.y), 0.7, 0.06, Color(color, 0.9), true)
	ring.scale = Vector3(0.3, 1, 0.3)
	effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3(2.4, 1, 2.4), "grow": true, "tint": color})
	emitter(Vector3(at.x, 0.3, at.y), color, 18, 0.6, 4.0, 60.0, 0.24, -3.0, Vector3.UP)
	flash(Vector3(at.x, 0.8, at.y), color, 4.0, 0.35, 8.0)

func sentry_down(at: Vector2, team: int) -> void:
	# And leaving: the drum blows apart, the ring collapses, the floor is scorched.
	var color = CYAN if team == 0 else CORAL
	burst(at, color, true)
	emitter(Vector3(at.x, 0.4, at.y), Color("ffd7a1"), 26, 0.7, 7.0, 95.0, 0.3, -6.0, Vector3.UP)
	dust(Vector3(at.x, 0.15, at.y), Color("c9b79a"), 10, 0.9, 2.0, 0.8)
	flash(Vector3(at.x, 0.7, at.y), color, 6.0, 0.4, 9.0)
	scorch(at, 2.2, color, 1.0)
	shake(0.45)

func update_power_effects(rules, dt: float) -> void:
	# Capes over the bricks and a curtain in front of a shielded goal.
	for team in range(2):
		var state: Dictionary = rules.powers[team]
		var dome_node: Node3D = power_nodes[team].get_node("Dome")
		dome_node.visible = state.dome_time > 0
		if dome_node.visible:
			var shell_mat: ShaderMaterial = dome_node.get_node("Shell").material_override
			shell_mat.set_shader_parameter("rise", clampf((Rules.DOME_SECONDS - state.dome_time) / 0.7, 0.0, 1.0))
			shell_mat.set_shader_parameter("strength", clampf(state.dome_time / 0.6, 0.0, 1.0))
		var field_node: Node3D = power_nodes[team].get_node("SlowField")
		field_node.visible = state.slow_time > 0
		if field_node.visible:
			for k in range(3):
				var roll = fmod(clock * 0.35 + k / 3.0, 1.0)
				var wave: Node3D = field_node.get_node("Wave%d" % k)
				wave.scale = Vector3.ONE * (0.5 + roll * Rules.HALF_WIDTH * 1.2)
				wave.visible = roll < 0.9
			if fx != null and fmod(clock, 0.06) < dt:
				# Motes hanging in the thickened air, drifting up slowly.
				var side_z = signf(rules.players[team].p.y)
				fx.emit("glow", Vector3(randf_range(-Rules.HALF_WIDTH, Rules.HALF_WIDTH), randf_range(0.1, 0.8), side_z * randf_range(0.5, Rules.HALF_LENGTH - 0.5)), Vector3(0, 0.25, 0), Color(Rules.power_color("slow"), 0.8), 0.16, 0.05, 1.6)
		var sponge_node: Node3D = power_nodes[team].get_node("Sponge")
		sponge_node.visible = state.sponge_time > 0
		if sponge_node.visible:
			sponge_node.scale = Vector3.ONE * (1.0 + sin(clock * 7.0) * 0.03)
		var immune_node: Node3D = power_nodes[team].get_node("Immune")
		immune_node.visible = state.immune_time > 0
		if immune_node.visible:
			immune_node.position = Vector3(rules.players[team].p.x, 0, rules.players[team].p.y)
			immune_node.rotation.y = clock * 2.2
			immune_node.get_node("Orbit").rotation.z = clock * 3.0
			immune_node.get_node("Bubble").material_override.set_shader_parameter("rise", clampf((Rules.IMMUNE_SECONDS - state.immune_time) / 0.35, 0.0, 1.0))
			immune_node.get_node("Bubble").material_override.set_shader_parameter("strength", 0.85 * clampf(state.immune_time / 0.5, 0.0, 1.0))
			if fx != null and fmod(clock, 0.09) < dt:
				var around = randf() * TAU
				fx.emit("glow", immune_node.position + Vector3(cos(around) * 0.9, 0.1, sin(around) * 0.9), Vector3(0, 1.6, 0), Color("fff3c8", 0.9), 0.14, 0.03, 0.8)
		var cape: Node3D = power_nodes[team].get_node("Cape")
		cape.visible = state.mirror_time > 0
		if cape.visible:
			cape.scale = Vector3.ONE * (1.0 + sin(clock * 9.0) * 0.04)
		var walls: Node3D = power_nodes[team].get_node("Walls")
		walls.visible = state.walls_time > 0
		if walls.visible:
			# Rise out of the floor in the first third of a second, sink back at the end.
			var elapsed: float = Rules.WALLS_SECONDS - state.walls_time
			var height = clampf(minf(elapsed / 0.3, state.walls_time / 0.45), 0.04, 1.0)
			walls.scale = Vector3(1, height, 1)
			walls.position.y = (height - 1.0) * 0.55
		var charging: Node3D = power_nodes[team].get_node("Windup")
		charging.visible = state.ultimate_windup > 0
		if charging.visible:
			# Winding up: a ring of light closes on the pilot and sparks rise out of it.
			var pilot: Vector2 = rules.players[team].p
			charging.position = Vector3(pilot.x, 0, pilot.y)
			var wind = 1.0 - state.ultimate_windup / Rules.ULTIMATE_WINDUP
			charging.scale = Vector3.ONE * lerpf(2.6, 0.9, wind)
			charging.rotation.y = clock * 3.4
			var glow: Color = Rules.power_color(String(state.ultimate_id))
			if String(state.ultimate_id).begins_with("b_"):
				glow = glow.lerp(Color("fff4d8"), 0.35)
				charging.rotation.y = -clock * 5.5
				charging.scale.y = 1.25 + 0.15 * sin(clock * 18)
			for part in charging.get_children():
				if part is MeshInstance3D:
					var energy = part.material_override
					if not (energy is ShaderMaterial and energy.shader == ENERGY):
						energy = ShaderMaterial.new()
						energy.shader = ENERGY
						part.material_override = energy
					energy.set_shader_parameter("tint", glow)
					energy.set_shader_parameter("strength", 0.45 + 0.55 * wind)
			if fmod(clock, 0.14) < dt:
				# Embers pulled up into the pilot, faster as the moment approaches.
				var ring_at = pilot + Vector2(cos(clock * 5.0), sin(clock * 5.0)) * lerpf(2.4, 0.8, wind)
				emitter(Vector3(ring_at.x, 0.15, ring_at.y), glow, 8, 0.45, 1.6 + wind * 2.4, 16.0, 0.26, -2.5, Vector3.UP)
				flash(Vector3(pilot.x, 0.9, pilot.y), glow, 1.2 + wind * 3.5, 0.2, 6.0)
		if warm_frames <= 0:
			dim_beam_lamps(team)
		var ray: Node3D = power_nodes[team].get_node("SunRay")
		var firing_sun: bool = state.ultimate_time > 0 and String(state.ultimate_id) in ["sun_ray", "sun_beam"]
		ray.visible = firing_sun
		if firing_sun:
			# Out of the barrel, past the wall, and thick enough to swallow four bricks.
			var muzzle: Vector3 = muzzle_of(team)
			var aim: Vector2 = Rules.forward_direction(team, rules.players[team].angle)
			var reach = 3.0 * (Rules.HALF_LENGTH + Rules.HALF_WIDTH)
			ray.position = muzzle
			ray.rotation.y = -aim.angle()
			var beat = 1.0 + sin(clock * 26.0) * 0.06
			var fade = clampf(state.ultimate_time / 0.25, 0.35, 1.0)
			# BIT DE ELITE's beam is the same sun drawn thin: about one brick across.
			var girth = beat * fade * (Rules.SUN_BEAM_HALF_WIDTH / Rules.SUN_RAY_HALF_WIDTH if String(state.ultimate_id) == "sun_beam" else 1.0)
			ray.scale = Vector3(reach, girth, girth)
			ray.get_node("Spiral").rotation.x = clock * 6.0
			for i in range(4):
				var halo: Node3D = ray.get_node("Ring%d" % i)
				# The rings travel away from the gun, over and over.
				halo.position.x = fmod(0.1 + i * 0.25 + clock * 0.55, 1.0)
				halo.scale = Vector3.ONE * (1.0 + sin(clock * 9.0 + i) * 0.12)
			if fmod(clock, 0.1) < dt:
				emitter(muzzle, Color("fff4d2"), 10, 0.4, 7.0, 24.0, 0.3, -1.5, Vector3(aim.x, 0, aim.y))
				shake(0.28)
			# The ray lights the arena it crosses: a wide warm lamp down its length and a
			# white-hot one at the barrel.
			var down = Vector3(aim.x, 0, aim.y)
			place_beam_lamp(team, 0, muzzle + down * Rules.HALF_LENGTH * 0.9 + Vector3.UP * 1.6, Color("ffa04a"), 4.8 * fade, Rules.HALF_LENGTH * 2.1)
			place_beam_lamp(team, 1, muzzle + Vector3.UP * 0.6, Color("fff1d6"), 3.6 * fade, 6.5)
		var vortex: Node3D = power_nodes[team].get_node("Vortex")
		var collapsing: bool = state.ultimate_time > 0 and String(state.ultimate_id) == "singularity"
		vortex.visible = collapsing
		if collapsing:
			# The core swells and the disc spins faster as the collapse tightens; rings of
			# shock keep falling inwards, and the light bends the same way.
			var pilot: Vector2 = rules.players[team].p
			var draw_in = clampf(1.0 - state.ultimate_time / Rules.SINGULARITY_PULL, 0.0, 1.0)
			var glow: Color = Rules.power_color("singularity")
			vortex.position = Vector3(pilot.x, 1.05, pilot.y)
			vortex.scale = Vector3.ONE * lerpf(0.6, 1.35, draw_in) * (1.0 + sin(clock * 24.0) * 0.03)
			vortex.get_node("Disc").rotation.y = clock * lerpf(2.6, 9.5, draw_in)
			vortex.get_node("Rim").scale = Vector3.ONE * (1.0 + sin(clock * 17.0) * 0.07)
			vortex.get_node("Halo").scale = Vector3.ONE * (1.0 + sin(clock * 11.0) * 0.12)
			vortex.get_node("Core").scale = Vector3.ONE * lerpf(0.8, 1.15, draw_in)
			for i in range(4):
				var lance: Node3D = vortex.get_node("Lance%d" % i)
				lance.rotation.y = -(i * TAU / 4.0 + clock * lerpf(1.4, 5.0, draw_in))
				lance.position = Vector3(cos(-lance.rotation.y) * 1.05, 0, sin(-lance.rotation.y) * 1.05)
			if fmod(clock, 0.09) < dt and effects.size() + 3 < effect_limit:
				# Embers torn off the floor right where the wave is passing, all pulled in.
				var span = clampf(rules.singularity_front(team), 1.2, Rules.HALF_LENGTH)
				for spoke in range(2):
					var around = clock * 2.6 + spoke * PI
					var edge = pilot + Vector2(cos(around), sin(around)) * span
					var inward = (pilot - edge).normalized()
					emitter(Vector3(edge.x, 0.18, edge.y), Color("ffd79a"), 10, 0.55, 6.0 + draw_in * 6.0, 16.0, 0.26, 0.0, Vector3(inward.x, 0.14, inward.y))
				# And a ring around the core itself, drawn down to nothing.
				var wave = torus(self, Vector3(pilot.x, 0.75, pilot.y), 1.0, 0.07, Color(glow, 0.55), true)
				var width = lerpf(3.4, 1.6, draw_in)
				wave.scale = Vector3(width, 0.3, width)
				effects.append({"node": wave, "v": Vector3.ZERO, "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3(width, 0.3, width)})
				flash(Vector3(pilot.x, 0.7, pilot.y), glow, 1.6 + draw_in * 3.0, 0.22, 7.5)
				shake(0.1 + draw_in * 0.22)
		var beam: Node3D = power_nodes[team].get_node("Beam")
		beam.visible = state.laser_time > 0
		if beam.visible:
			var origin: Vector2 = rules.players[team].p
			var heading: Vector2 = Rules.forward_direction(team, rules.players[team].angle)
			var path: Array = rules.laser_path(origin, heading)
			var flicker = 1.0 + sin(clock * 30.0) * 0.14
			beam.position = Vector3.ZERO
			beam.rotation.y = 0.0
			beam.scale = Vector3.ONE
			for leg in range(Rules.LASER_BOUNCES + 1):
				var limb: Node3D = beam.get_node("Leg%d" % leg)
				limb.visible = leg < path.size() - 1
				if not limb.visible:
					continue
				var from: Vector2 = path[leg]
				# The first leg leaves the barrel and dips to the bricks' height; every leg
				# after it runs at that height, so the beam meets small bricks too.
				var start_y: float = SHOT_HEIGHT
				if leg == 0:
					var muzzle: Vector3 = muzzle_of(team)
					from = Vector2(muzzle.x, muzzle.z)
					start_y = muzzle.y
				var travel: Vector2 = path[leg + 1] - from
				var drop: float = SHOT_HEIGHT - start_y
				# Each leg is modelled from 0 to 1 along +X, so it grows out of its corner.
				limb.position = Vector3(from.x, start_y, from.y)
				limb.rotation = Vector3(0.0, -travel.angle(), atan2(drop, travel.length()))
				limb.scale = Vector3(sqrt(travel.length_squared() + drop * drop), flicker, flicker)
				if leg == 0:
					# The laser lights the floor along its path and burns bright where it lands.
					var length = travel.length()
					var mid = Vector3(from.x, 0.7, from.y) + Vector3(travel.x, 0, travel.y) * 0.5
					place_beam_lamp(team, 0, mid, Rules.power_color("laser").lightened(0.2), 4.6 * flicker, length * 0.6 + 2.6)
				if leg == path.size() - 2:
					var landing: Vector2 = path[leg + 1]
					place_beam_lamp(team, 1, Vector3(landing.x, 0.55, landing.y), Color("ffc14a"), 5.0 * flicker, 4.2)
				if leg == path.size() - 2 and fx != null and fmod(clock, 0.05) < dt:
					# Where it lands: small yellow and orange sparks, thrown back off the hit.
					var hit: Vector2 = path[leg + 1]
					var back = Vector3(-travel.x, 0.6, -travel.y).normalized()
					fx.sparks(Vector3(hit.x, SHOT_HEIGHT, hit.y), Color("ffd23f"), 3, 4.5, 0.06, 0.22, back, 70.0, -5.0)
					fx.sparks(Vector3(hit.x, SHOT_HEIGHT, hit.y), Color("ff8a3c"), 2, 3.5, 0.05, 0.2, back, 80.0, -5.0)


func build_power_effects() -> void:
	# Built once, hidden until a power turns them on.
	power_nodes.clear()
	for team in range(2):
		var root = Node3D.new()
		add_child(root)
		power_nodes.append(root)
		var cape = Node3D.new()
		cape.name = "Cape"
		root.add_child(cape)
		for data in Rules.map_bricks(map):
			if data.team != team:
				continue
			var dome = box(cape, Vector3(data.p.x, 0.36, data.p.y), Vector3(0.66, 0.78, 0.4), Color(Rules.power_color("mirror"), 0.34), true, 0.1)
			dome.rotation.y = -data.rotation
			# A bright lid makes the cape read from across the arena, not just up close.
			var lid = box(cape, Vector3(data.p.x, 0.75, data.p.y), Vector3(0.6, 0.035, 0.34), Color(Rules.power_color("mirror"), 0.85), true, 0.01)
			lid.rotation.y = -data.rotation
		cape.hide()
		var walls = Node3D.new()
		walls.name = "Walls"
		root.add_child(walls)
		# Steel blocks from the Blender kit (fx_wall_block), laid end to end along each slab,
		# with the team's energy running along them.
		var wall_paint = {"shell": Color("5b6573"), "metal": Color("9aa7b5"), "glow": CYAN if team == 0 else CORAL,
			"dark": Color("262b36"), "wear": 0.55}
		for slab in Rules.team_walls(team, map):
			var a = Vector3(slab.a.x, 0.0, slab.a.y)
			var b = Vector3(slab.b.x, 0.0, slab.b.y)
			var span = a.distance_to(b)
			if span < 0.01:
				continue
			var along = (b - a) / span
			var count = maxi(1, int(round(span / 0.5)))
			for k in range(count):
				var block = Node3D.new()
				walls.add_child(block)
				block.transform = Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)).scaled(Vector3(span / count / 0.5, 1.0, Rules.BARRIER_RADIUS * 2.0 / 0.34)), a.lerp(b, (k + 0.5) / count))
				Robots.prop(self, block, "fx_wall_block", ["fx_wall_block"], wall_paint.duplicate())
		walls.hide()
		var ray = Node3D.new()
		ray.name = "SunRay"
		root.add_child(ray)
		# Modelled from 0 to 1 along +X: an opaque white core, a solid sun-coloured body
		# and a soft corona around them, plus rings that ride down the beam.
		# Solid now: a white core, an opaque sun body, an opaque orange sheath and only the
		# outermost corona see-through; a spiral of flame bands turns round it.
		for layer in [[0.22, Color("fff8e8")], [0.42, Rules.power_color("sun_ray")], [0.56, Color("ff7a1a")], [0.66, Color(Color("ff9a3c"), 0.2)]]:
			var tube = cylinder(ray, Vector3(0.5, 0, 0), float(layer[0]), 1.0, layer[1], true, 20)
			tube.rotation.z = PI * 0.5
		var spiral = Node3D.new()
		spiral.name = "Spiral"
		ray.add_child(spiral)
		for k in range(36):
			var along = (k + 0.5) / 36.0
			var turn = k * 0.9
			var band = box(spiral, Vector3(along, cos(turn) * 0.6, sin(turn) * 0.6), Vector3(0.022, 0.1, 0.1), Color("fff1c2"), true, 0.01)
			band.rotation.x = turn
		for i in range(4):
			var halo = torus(ray, Vector3(0.1 + i * 0.25, 0, 0), 0.62, 0.06, Color("ff9a3c"))
			halo.name = "Ring%d" % i
			halo.rotation.z = PI * 0.5
		ray.hide()
		var vortex = Node3D.new()
		vortex.name = "Vortex"
		root.add_child(vortex)
		# A hole, not a light: an opaque black core, a searing rim around it, three discs of
		# debris lying flat, and four lances of light bent around the edge.
		var core = sphere(vortex, Vector3.ZERO, Vector3.ONE * 0.74, Color("04050a"), false)
		core.name = "Core"
		# A wider, softer shadow around it: the light nearby is bent, not lit.
		sphere(vortex, Vector3.ZERO, Vector3.ONE * 1.12, Color("05070d", 0.45), false)
		var rim = torus(vortex, Vector3.ZERO, 0.52, 0.09, Color("fff3d8"), true)
		rim.name = "Rim"
		rim.rotation.x = 0.16
		var rim_glow = torus(vortex, Vector3.ZERO, 0.6, 0.2, Color("ffc46a", 0.45), true)
		rim_glow.name = "Halo"
		rim_glow.rotation.x = 0.16
		var disc = Node3D.new()
		disc.name = "Disc"
		vortex.add_child(disc)
		for i in range(3):
			var ring = torus(disc, Vector3(0, -0.04 * i, 0), 0.88 + i * 0.36, 0.075 - i * 0.014, Color(Rules.power_color("singularity"), 0.95 - i * 0.2), true)
			ring.name = "Ring%d" % i
			ring.scale = Vector3(1, 0.18, 1)
			ring.rotation.x = 0.13 + i * 0.05
		for i in range(4):
			var angle = i * TAU / 4.0
			var lance = box(vortex, Vector3(cos(angle) * 1.05, 0, sin(angle) * 1.05), Vector3(0.9, 0.035, 0.035), Color("ffd79a"), true, 0.01)
			lance.name = "Lance%d" % i
			lance.rotation.y = -angle
		vortex.hide()
		var windup = Node3D.new()
		windup.name = "Windup"
		root.add_child(windup)
		torus(windup, Vector3(0, 0.5, 0), 0.9, 0.05, Color(GOLD, 0.7), true)
		for i in range(4):
			var angle = i * TAU / 4
			cylinder(windup, Vector3(cos(angle) * 0.9, 0.5, sin(angle) * 0.9), 0.07, 0.5, Color(GOLD, 0.6), true, 10)
		# Ground seal makes the cast readable before the bright discharge, even from above.
		torus(windup, Vector3(0, 0.055, 0), 1.04, 0.022, Color(GOLD, 0.7), true)
		for spoke in range(8):
			var bearing = spoke * TAU / 8.0
			var mark = box(windup, Vector3(cos(bearing)*1.04, 0.06, sin(bearing)*1.04), Vector3(0.20, 0.025, 0.035), Color(GOLD, 0.7), true, 0.006)
			mark.rotation.y = -bearing
		windup.hide()
		var beam = Node3D.new()
		beam.name = "Beam"
		root.add_child(beam)
		# One unit-long lance per leg of the folded beam, each placed every frame.
		for leg in range(Rules.LASER_BOUNCES + 1):
			var limb = Node3D.new()
			limb.name = "Leg%d" % leg
			beam.add_child(limb)
			# A solid beam: a white-hot core inside an opaque body of the laser's colour,
			# and only a thin glow round it.
			var core_tube = cylinder(limb, Vector3(0.5, 0, 0), 0.06, 1.0, Color("fff6ea"), true, 12)
			core_tube.rotation.z = PI * 0.5
			var body_tube = cylinder(limb, Vector3(0.5, 0, 0), 0.12, 1.0, Rules.power_color("laser"), true, 14)
			body_tube.rotation.z = PI * 0.5
			var glow_tube = cylinder(limb, Vector3(0.5, 0, 0), 0.19, 1.0, Color(Rules.power_color("laser").lightened(0.2), 0.3), true, 14)
			glow_tube.rotation.z = PI * 0.5
		beam.hide()
		# The new shields. Dome: a shell of light over the wall. Slow field: a veil over the
		# defended half. Sponge: a golden skin over the bricks. Immunity: a halo on the pilot.
		var bank = Vector2.ZERO
		var banked = 0
		for data in Rules.map_bricks(map):
			if data.team == team:
				bank += data.p
				banked += 1
		bank /= maxf(banked, 1)
		var side_sign = signf(bank.y) if bank.y != 0.0 else (1.0 if team == 0 else -1.0)
		var dome = Node3D.new()
		dome.name = "Dome"
		root.add_child(dome)
		# The dome: a hexagon lattice of light rising over the wall (shaders/fx_shield).
		var shell = MeshInstance3D.new()
		shell.name = "Shell"
		var half_sphere = SphereMesh.new()
		half_sphere.radius = 0.5
		half_sphere.height = 1.0
		half_sphere.is_hemisphere = true
		half_sphere.radial_segments = 48
		half_sphere.rings = 16
		shell.mesh = half_sphere
		shell.position = Vector3(bank.x, 0.0, bank.y)
		shell.scale = Vector3(Rules.HALF_WIDTH * 2.2, 5.2, 4.6)
		shell.material_override = shield_material(deep(Rules.power_color("dome")), 11.0)
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dome.add_child(shell)
		torus(dome, Vector3(bank.x, 0.05, bank.y), 1.0, 0.06, Color(deep(Rules.power_color("dome")), 0.95), true).scale = Vector3(Rules.HALF_WIDTH * 1.1, 1.0, 2.3)
		dome.hide()
		var field = Node3D.new()
		field.name = "SlowField"
		root.add_child(field)
		# The slow field: a low veil over the defended half, a bright border on the half-way line
		# and rings of slowed time rolling out across the floor.
		box(field, Vector3(0, 0.35, side_sign * Rules.HALF_LENGTH * 0.5), Vector3(Rules.HALF_WIDTH * 2.0, 0.7, Rules.HALF_LENGTH), Color(Rules.power_color("slow"), 0.4), true, 0.02)
		segment(field, Vector3(-Rules.HALF_WIDTH, 0.08, 0.15 * side_sign), Vector3(Rules.HALF_WIDTH, 0.08, 0.15 * side_sign), 0.14, 0.06, Color("eaffea", 0.95), true)
		segment(field, Vector3(-Rules.HALF_WIDTH, 0.72, 0.15 * side_sign), Vector3(Rules.HALF_WIDTH, 0.72, 0.15 * side_sign), 0.08, 0.04, Color(Rules.power_color("slow"), 0.9), true)
		for k in range(3):
			var wave = torus(field, Vector3(0, 0.05, side_sign * Rules.HALF_LENGTH * 0.5), 1.0, 0.03, Color(Rules.power_color("slow"), 0.8), true)
			wave.name = "Wave%d" % k
		field.hide()
		var sponge = Node3D.new()
		sponge.name = "Sponge"
		root.add_child(sponge)
		for data in Rules.map_bricks(map):
			if data.team != team:
				continue
			var skin = box(sponge, Vector3(data.p.x, 0.4, data.p.y), Vector3(0.62, 0.7, 0.36), Color(Rules.power_color("sponge"), 0.7), true, 0.1)
			skin.rotation.y = -data.rotation
		sponge.hide()
		var halo_node = Node3D.new()
		halo_node.name = "Immune"
		root.add_child(halo_node)
		torus(halo_node, Vector3(0, 0.08, 0), 0.9, 0.07, Color(IMMUNE_GLOW, 0.95), true)
		var spin_ring = torus(halo_node, Vector3(0, 1.0, 0), 1.0, 0.025, Color("fff3c8", 0.95), true)
		spin_ring.name = "Orbit"
		spin_ring.rotation.x = 1.1
		# The bubble: a lattice of white light around the pilot.
		var bubble = MeshInstance3D.new()
		bubble.name = "Bubble"
		var ball_mesh = SphereMesh.new()
		ball_mesh.radius = 0.5
		ball_mesh.height = 1.0
		ball_mesh.radial_segments = 32
		ball_mesh.rings = 16
		bubble.mesh = ball_mesh
		bubble.position = Vector3(0, 1.0, 0)
		bubble.scale = Vector3(1.9, 2.3, 1.9)
		bubble.material_override = shield_material(IMMUNE_GLOW, 6.0, 0.95)
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo_node.add_child(bubble)
		halo_node.hide()
		# Everything these standing effects are built from is energy, not flat colour (the
		# steel walls excepted).
		for piece in root.get_children():
			if piece.name != "Walls":
				energize(piece)


func world_at(screen: Vector2) -> Vector2:
	var point = Plane(Vector3.UP, 0.58).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	return Vector2(point.x, point.z) if point != null else Vector2.ZERO

# Basic feedback uses a bounded reusable pool, separate from the elaborate ultimate VFX.
func feedback_chip(at: Vector3, velocity: Vector3, tint: Color, life: float, size: Vector3, debris: bool = false) -> void:
	# Muzzle sparks and impact chips come from the GPU batches: a chip is written once and
	# animated by its shader, so a volley costs no nodes and no per-frame work.
	if fx == null:
		return
	if debris:
		fx.emit("debris", at, velocity, tint.darkened(0.15), size.x, 0.0, life * 2.2, -9.0, 0.0, 0.0, 0.0, 10.0)
	else:
		fx.emit("spark", at, velocity, tint, size.x * 1.8, size.x * 0.3, life * 1.8, -2.0, 2.0, 0.08)

func shot_feedback(team: int, local: bool = false) -> void:
	# FIRE: the gun snaps back, the barrel flashes with a shape and a direction, and the
	# arena answers for a moment. Everything starts on the frame the shot is made.
	shot_age[team] = 0.0
	var gun: Node3D = units[team].get_node("Body/Gun")
	gun.get_node("Flash").scale = Vector3.ONE * 0.42
	var origin = muzzle_of(team)
	var direction = -units[team].get_node("Body").global_basis.z
	if fx != null:
		var spark_count = int(feel.get_value("muzzle_spark_amount") * (1.0 if local else 0.6))
		fx.muzzle(origin, direction, shot_colors[team], feel.get_value("muzzle_flash_duration"), spark_count, feel.get_value("muzzle_flash_size") * (1.0 if local else 0.8))
	# A lamp for a few frames, where the budget allows (never on a phone's lighter profiles).
	if local and light_cap() >= 2:
		flash(origin, shot_colors[team], 1.1, 0.05, 3.0)
	if local:
		shake_level(GameFeel.Level.SHOT, -direction)

func impact_feedback(event: Dictionary) -> void:
	# IMPACT: exactly where the shot met something, in that thing's own language.
	var kind = String(event.kind)
	var broken = kind == "brick"
	var shield = kind in ["mirror", "player_hit"] or event.get("soaked", false)
	var tint: Color = shot_colors[int(event.get("team", 0))] if shield or kind.begins_with("brick") else GOLD
	var at: Vector2 = event.p
	var heading2: Vector2 = event.get("heading", Vector2.ZERO)
	var heading = Vector3(heading2.x, 0, heading2.y)
	var origin = Vector3(at.x, 0.5, at.y)
	var material = "shield" if shield else ("brick" if kind.begins_with("brick") else ("metal" if event.get("surface", "") == "obstacle" else "wall"))
	if fx != null:
		fx.impact(origin, heading, tint, material, feel.count("impact_particle_amount", quality_level), feel.get_value("impact_flash_size"))
		if broken:
			var brick_color: Color = tint
			fx.break_apart(origin, heading, [theme.get("block_alt", CREAM), brick_color, brick_color.darkened(0.35)], feel.count("destruction_particle_amount", quality_level))
	if kind == "brick_hit" and event.has("brick_id"):
		# The hit is confirmed on the brick itself: it jumps, and a little harder the closer
		# it is to falling.
		brick_reactions[int(event.brick_id)] = 0.14
	if broken:
		hitstop(feel.get_value("hitstop_destroy"))
		shake_level(GameFeel.Level.DESTROY, heading)
	elif material != "wall":
		shake_level(GameFeel.Level.IMPACT, heading, 0.6)
	if event.get("defense_open", false):
		defense_falls(int(event.team), tint)

func defense_falls(team: int, tint: Color) -> void:
	# The last brick: CRACK, a beat of stillness, then the goal's shield gives way in a
	# pulse and the goal itself lights up. The match should feel different from here on.
	hitstop(feel.get_value("hitstop_last_brick"))
	shake_level(GameFeel.Level.DESTROY, Vector3.ZERO, feel.get_value("camera_last_brick_strength") / maxf(feel.get_value("camera_destroy_strength"), 0.001))
	var centre: Vector2 = Rules.goal_center(team)
	var spot = Vector3(centre.x, 0.1, centre.y)
	schedule(feel.get_value("hitstop_last_brick"), func():
		if fx != null:
			fx.pulse(spot, tint.lightened(0.2), 1.6, 0.5)
			fx.sparks(spot + Vector3(0, 0.4, 0), tint.lightened(0.3), 14, 6.0, 0.12, 0.4, Vector3.UP, 70.0)
		if effects.size() < effect_limit:
			var ring = torus(self, spot, 1.1, 0.045, tint, true)
			effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.45, "life": 0.45, "gravity": false, "base": Vector3.ONE * 2.2, "grow": true, "tint": tint}))

func goal_scored(team_scoring: int, spot: Vector3) -> void:
	# The biggest normal payoff of a match: a longer hold, the effects slowed for a beat,
	# the strongest shake, and the goal erupting.
	hitstop(feel.get_value("hitstop_goal"))
	dilate(0.45, 0.55)
	shake_level(GameFeel.Level.DECISIVE, Vector3(0, 0, -1 if team_scoring == 0 else 1))
	var color = CYAN if team_scoring == 0 else CORAL
	if fx != null:
		fx.pulse(spot, color, 2.6, 0.7)
		fx.star(spot + Vector3(0, 0.6, 0), Color(1, 0.97, 0.9), 1.6, 0.25)
		fx.sparks(spot + Vector3(0, 0.4, 0), color.lightened(0.3), 26, 9.0, 0.16, 0.6, Vector3.UP, 80.0)
		fx.embers(spot, color, 16, 3.0, 0.2, 0.9, Vector3.UP, 60.0, -1.5)
	flash(spot + Vector3(0, 1.0, 0), color, 3.0, 0.3, 7.0)

func ultimate_accent(at: Vector2, id: String) -> void:
	# Small silhouette accents augment, rather than replace, each themed main effect.
	var tint = Rules.power_color(id)
	# The release itself lights the field and keeps the room dim for a beat.
	hold_mood(1.4)
	light_field(tint.lightened(0.2), 0.8, 0.5)
	var origin = Vector3(at.x, 0.7, at.y)
	var count = 5 if quality_level == 0 else 9
	var rising = id in ["bloom", "meteors", "sun_ray", "sun_beam"]
	var inward = id in ["singularity", "plunder"]
	for i in range(count):
		var a = float(i) / count * TAU
		var radial = Vector3(cos(a), 0, sin(a))
		feedback_chip(origin + radial * (0.95 if inward else 0.22), radial * (-2.0 if inward else 2.4) + Vector3.UP * (2.3 if rising else 0.55), tint, 0.24, Vector3(0.055, 0.22 if rising else 0.055, 0.12))
	shake(0.30)
