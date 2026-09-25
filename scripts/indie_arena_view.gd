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
const Robots = preload("res://scripts/robots.gd")
const ArenaTheme = preload("res://scripts/arena_theme.gd")
const ArenaDressing = preload("res://scripts/arena_dressing.gd")
const Fx = preload("res://scripts/fx.gd")
const ORB = preload("res://shaders/fx_orb.gdshader")
const CombatFinish = preload("res://scripts/combat_finish.gd")
const ArenaFinish = preload("res://scripts/arena_finish.gd")
const GLASS = preload("res://shaders/glass.gdshader")
const GUIDE_DOTS = 30
# Projectile size per power: normal, explosive, machine-gun round, air pellet.
const POWER_BALL_SCALE = [1.0, 1.4, 0.95, 0.7]
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
var camera_home = Vector3(0, 26, 15)
var shake_power = 0.0
var shake_scale = 0.55
var shot_age = [1.0, 1.0]
var feedback_pool: Array[Node3D] = []
var feedback_allocated = 0
const FEEDBACK_POOL_LIMIT = 80
var brick_reactions: Dictionary = {}
var shake_seed = 0.0
# Effects waiting for their moment: {"time": seconds, "call": Callable}.
var pending: Array = []
# Reuse lamps instead of creating/destroying them during ultimates; particles live in the
# fixed GPU batches of fx.gd.
const LIGHT_POOL_LIMIT = 8
var light_pool: Array[OmniLight3D] = []
var active_lights = 0

func prepare_fx_pool() -> void:
	for i in range(LIGHT_POOL_LIMIT):
		var lamp = OmniLight3D.new()
		lamp.shadow_enabled = false
		lamp.hide()
		add_child(lamp)
		light_pool.append(lamp)

func material(color: Color, luminous: bool = false) -> StandardMaterial3D:
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

func soft_disc_material(color: Color) -> ShaderMaterial:
	var key = "disc" + str(color)
	if not materials.has(key):
		var mat = ShaderMaterial.new()
		mat.shader = SOFT_DISC
		mat.set_shader_parameter("tint", color)
		materials[key] = mat
	return materials[key]

func set_quality(level: int) -> void:
	quality_level = clampi(level, 0, 2)
	if presentation_environment != null: ArenaFinish.environment(presentation_environment, quality_level)
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
			ArenaFinish.surface(mat, quality_level)
			# Flat lighting on Leve removes per-light passes and is also a clean
			# indie look. Higher profiles restore the modeled ceramic shading.
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if quality_level == 0 or mat.get_meta("always_unshaded", false) else BaseMaterial3D.SHADING_MODE_PER_PIXEL
			if mat.albedo_color == CREAM:
				mat.clearcoat_enabled = quality_level >= 2

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
	for i in range(outline.size()):
		var a = Vector3(outline[i].x, height, outline[i].y)
		var b = Vector3(outline[(i + 1) % outline.size()].x, height, outline[(i + 1) % outline.size()].y)
		triangle(st, Vector3(0, height, 0), a, b)
		triangle(st, a, a - Vector3.UP * depth, b - Vector3.UP * depth)
		triangle(st, a, b - Vector3.UP * depth, b)
	return mesh(self, st.commit(), Vector3.ZERO, color)

func build(new_map: Dictionary = {}) -> void:
	prepare_fx_pool()
	map = new_map if not new_map.is_empty() else Rules.default_map()
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
	background.material = bg_mat
	background_layer.add_child(background)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -35, 0)
	light.light_color = Color("ffe9cc")
	light.light_energy = 1.35
	light.shadow_enabled = false
	add_child(light)
	secondary_light = DirectionalLight3D.new()
	secondary_light.rotation_degrees = Vector3(-35, 145, 0)
	secondary_light.light_color = Color("8fc8ff")
	secondary_light.light_energy = 0.72
	add_child(secondary_light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = LANDSCAPE_SIZE
	camera.position = Vector3(0, 26, 15)
	add_child(camera)
	camera.look_at(Vector3(0, -0.15, 0))
	camera.current = true
	var outer: Array = []
	for p in walls:
		outer.append(p * Vector2(1.16, 1.07))
	platform(outer, -0.28, 0.75, theme.frame)
	var under: Array = []
	for p in outer:
		under.append(p * 0.97)
	platform(under, -0.98, 0.22, theme.frame.darkened(0.35))
	# Floating plinth silhouette and a painted hexagon floor without coplanar seams.
	var court = platform(walls, 0.0, 0.28, Color.WHITE)
	var court_mat = ShaderMaterial.new()
	court_mat.shader = preload("res://shaders/court.gdshader")
	court_mat.set_shader_parameter("surface_grain", ArenaFinish.SURFACES.ceramic[0])
	court_material = court_mat
	court_mat.set_shader_parameter("floor_color", theme.floor)
	court_mat.set_shader_parameter("floor_alt", theme.floor_alt)
	court_mat.set_shader_parameter("seam_color", theme.seam)
	court_mat.set_shader_parameter("line_color", theme.line)
	court_mat.set_shader_parameter("team_near", CYAN)
	court_mat.set_shader_parameter("team_far", CORAL)
	court.material_override = court_mat
	soft_disc(self, Vector3(0, -1.32, 0.3), Vector2(19, 23), Color(0.005, 0.015, 0.025, 0.7))
	ArenaDressing.perimeter(self, theme)
	ArenaDressing.stadium(self, theme, quality_level)
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
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(merged)
		static_batch_count += 1

func collect_static(parent: Node, groups: Dictionary) -> void:
	for child in parent.get_children():
		if child in units or child in brick_nodes or child in obstacle_nodes or child in power_nodes or child == aim_line or child == aim_guide:
			continue
		var opaque = child is MeshInstance3D and child.material_override is StandardMaterial3D and child.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		# Robot-painted props (goal posts) merge too; their ink outlines stay separate so the
		# Leve profile can still hide them.
		var painted = child is MeshInstance3D and child.material_override is ShaderMaterial and child.material_override.get_meta("robot_paint", false)
		if opaque or painted:
			# Separate attribute layouts so SurfaceTool never mixes UV and non-UV formats.
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var has_uv = arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size() > 0
			var key = str(child.material_override.get_instance_id()) + str(has_uv)
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
	var plate = box(brick, Vector3(0, 0.3, 0), Vector3(0.7, 0.68, 0.44), Color(Rules.power_color("plating"), 0.3), true, 0.07)
	plate.name = "Plate"
	plate.hide()
	brick.set_meta("hp", int(map.get("lives", Rules.BRICK_LIVES)))
	brick.set_meta("skin", skin)
	soft_disc(brick, Vector3(0.035, 0.018, 0.06), Vector2(0.92, 0.58), Color(0.006, 0.015, 0.022, 0.70))
	Robots.brick(self, brick, skin, team_color, tint)
	for i in range(3):
		var pip = box(brick, Vector3((i - 1) * 0.13, 0.614, 0), Vector3(0.078, 0.012, 0.095), team_color.darkened(0.45), true, 0.006)
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

func build_obstacles() -> void:
	# Painted guides are opaque, pre-blended with the floor, so they merge with the static
	# geometry instead of costing a transparent draw each.
	var color = theme.line
	for spec in map.get("obstacles", []):
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
	soft_disc(root, Vector3(0.12, 0.024, 0.14), Vector2(1.7, 1.35), Color(0.006, 0.02, 0.025, 0.8))
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
		box(surge, Vector3(cos(spark_angle) * 0.66, 0.26, sin(spark_angle) * 0.66), Vector3(0.07, 0.2, 0.07), GOLD, true, 0.02)
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

# Station pilots are addressed from here up, well clear of the eleven skins in the shop.
const STATION_SKIN = 100

func spin_parts(body: Node3D, time: float) -> void:
	# Crests on the robots (a crown, a halo, an orbit) turn slowly.
	var spin: Node3D = body.get_node_or_null("Spin")
	if spin == null:
		spin = body.get_node_or_null("KeyMount/Spin")
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

const LANDSCAPE_EYE = Vector3(0, 26, 15)

func frame_landscape(h_offset: float) -> void:
	lobby_view = false
	# Wide screens keep the original lean, which reads more like a stadium seen from a seat.
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_home = Vector3.ZERO
		view_bounds = Rect2()
	if camera_home != LANDSCAPE_EYE:
		camera_home = LANDSCAPE_EYE
		camera.position = camera_home
		camera.look_at(Vector3(0, -0.15, 0))
		view_bounds = Rect2()
	camera.size = LANDSCAPE_SIZE
	camera.h_offset = h_offset
	# Keep the enlarged upper wall clear of the scoreboard.
	camera.v_offset = 0.52

# A hair more lean than the landscape seat, no more: at 72 degrees the arena flattened
# into something that read as 2D, and the depth is what gives this game its look.
const PORTRAIT_EYE = Vector3(0, 26.6, 14.2)
# A map that asks to lean is shown through a real perspective instead: the board tips
# towards the player, the near goal comes at you and the far one falls away. The arena has
# to be narrow for this, which is why only the tall one asks for it.
const LEAN_DIR = Vector3(0, 0.80, 0.62)
const LEAN_FOV = 40.0
const LEAN_MARGIN = 1.0

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
	var direction: Vector3 = LEAN_DIR.normalized()
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

# The lobby: your pilot up close in the middle of the previewed arena, the camera swaying
# slowly round it, the boss waiting at the far end behind.
const LOBBY_FOV = 34.0
const LOBBY_PILOT_HEIGHT = 2.5
var lobby_view = false
var lobby_rect = Rect2()
var lobby_screen = Vector2.ZERO

func frame_lobby(rect: Rect2, screen: Vector2) -> void:
	lobby_view = true
	lobby_rect = rect
	lobby_screen = screen
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = LOBBY_FOV
	view_bounds = Rect2()
	place_lobby_camera()

func lobby_yaw() -> float:
	return sin(clock * 0.22) * 0.55

func place_lobby_camera() -> void:
	var pilot: Node3D = units[0]
	var focus = pilot.position + Vector3(0, 1.05, 0)
	var tan_half = tan(deg_to_rad(LOBBY_FOV) * 0.5)
	# Far enough that the pilot fills about two thirds of the band it is shown in.
	var distance = LOBBY_PILOT_HEIGHT / 0.64 / (2.0 * tan_half) * (lobby_screen.y / maxf(lobby_rect.size.y, 1.0))
	var yaw = lobby_yaw()
	camera.position = focus + Vector3(sin(yaw), 0.36, cos(yaw)).normalized() * distance
	camera.look_at(focus)
	camera_home = camera.position
	# Slide the picture so the pilot stands in the middle of its band, a little low, with
	# the arena and the boss rising behind its head.
	var per_pixel = 2.0 * distance * tan_half / lobby_screen.y
	camera.h_offset = -(lobby_rect.get_center().x - lobby_screen.x * 0.5) * per_pixel
	camera.v_offset = (lobby_rect.get_center().y + lobby_rect.size.y * 0.1 - lobby_screen.y * 0.5) * per_pixel

func frame_rect(rect: Rect2, screen: Vector2, is_menu: bool = false) -> void:
	lobby_view = false
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
	var target_eye = LANDSCAPE_EYE if is_menu else PORTRAIT_EYE
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
	if fx != null: fx.tick(clock)
	if lobby_view:
		place_lobby_camera()
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
	# Camera shake: a quick decaying wobble, never enough to lose the ball.
	if shake_power > 0.0:
		shake_power *= exp(-dt * 17.0)
		if shake_power < 0.0005: shake_power = 0.0
		shake_seed += dt * 46.0
		camera.position = camera_home + Vector3(sin(shake_seed) * 0.6, cos(shake_seed * 1.37) * 0.35, sin(shake_seed * 0.8) * 0.3) * shake_power
	elif camera.position != camera_home:
		camera.position = camera_home
	for id in brick_reactions.keys():
		brick_reactions[id] -= dt
		if id < brick_nodes.size():
			var brick: Node3D = brick_nodes[id]
			brick.position.y = sin(maxf(0.0, brick_reactions[id]) / 0.14 * PI) * 0.065
			update_brick_batch(id)
		if brick_reactions[id] <= 0.0:
			brick_reactions.erase(id)
	step_tallies(dt)
	trail_timer += dt
	var interpolate = not previous_motion.is_empty() and previous_motion.phase == rules.phase
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
		var speed = minf(node.position.distance_to(desired) / maxf(dt, 0.001), 5.0)
		node.position = desired
		var body: Node3D = node.get_node("Body")
		body.rotation.y = atan2(-facing.x, -facing.y)
		if lobby_view and team == 0:
			# In the lobby your pilot turns to face the camera.
			body.rotation.y = atan2(-sin(lobby_yaw()), -cos(lobby_yaw()))
		body.position.y = sin(clock * (12.0 if speed > 0.5 else 2.2)) * (0.035 if speed > 0.5 else 0.016)
		body.rotation.z = lerpf(body.rotation.z, sin(clock * 16) * 0.09 if data.stun > 0 else -data.aim.x * speed * 0.018, minf(dt * 10, 1))
		spin_parts(body, clock)
		body.get_node("LegL").rotation.x = sin(clock * 13) * minf(speed / 5.0, 1) * 0.48
		body.get_node("LegR").rotation.x = -sin(clock * 13) * minf(speed / 5.0, 1) * 0.48
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
		Robots.set_mood(body, 2 if data.stun > 0 else 0)
		if data.stun > stuns_before[team] + 0.2:
			burst(data.p, GOLD, false)
		stuns_before[team] = data.stun
		var gun: Node3D = body.get_node("Gun")
		shot_age[team] += dt
		var age: float = shot_age[team]
		# Only the weapon moves: 60 ms impulse, 150 ms recovery. Simulation is untouched.
		var recoil = sin(clampf(age / 0.06, 0.0, 1.0) * PI * 0.5) if age < 0.06 else pow(maxf(0.0, 1.0 - (age - 0.06) / 0.15), 2.0)
		gun.position.z = recoil * 0.17
		gun.rotation.x = recoil * 0.045
		gun.get_node("Flash").scale = Vector3.ONE * maxf(0.001, 0.42 * (1.0 - age / 0.055))
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
		if ball.get("ghost", false):
			color = Rules.power_color("ghost")
		if not projectiles.has(ball.id):
			projectiles[ball.id] = take_orb(ball.owner)
		var node: Node3D = projectiles[ball.id]
		node.position = Vector3(ball.p.x, 0.58, ball.p.y)
		if interpolate and previous_motion.balls.has(ball.id):
			var old: Dictionary = previous_motion.balls[ball.id]
			# Do not cut through walls when interpolating across a ricochet.
			if old.bounces == ball.bounces:
				var pos: Vector2 = old.p.lerp(ball.p, motion_alpha)
				node.position = Vector3(pos.x, 0.58, pos.y)
		# A heavy explosive round, a lean burst round: size alone says which is which.
		var swell: float = POWER_BALL_SCALE[clampi(kind, 0, POWER_BALL_SCALE.size() - 1)]
		var charged = ball.get("boosted", false) or ball.get("amplified", false)
		var orb: MeshInstance3D = node.get_node("Orb")
		orb.scale = Vector3.ONE * (1.04 if charged else 0.78) * swell
		orb.material_override.set_shader_parameter("tint", color)
		orb.material_override.set_shader_parameter("charged", 1.0 if charged else 0.0)
		# The comet tail: short-lived glows left behind every frame by the GPU batch.
		if fx != null:
			# Two glows per frame, one halfway back along this frame's travel, so the tail
			# reads as one continuous streak rather than a string of beads.
			var back = Vector3(-ball.v.x, 0, -ball.v.y).normalized()
			var stride = Vector3(ball.v.x, 0, ball.v.y) * dt
			for k in range(2 if quality_level > 0 else 1):
				fx.emit("glow", node.position - stride * (0.5 * k) + back * 0.1, back * 0.8, Color(color, 0.55), 0.42 * swell, 0.08, 0.24 if quality_level > 0 else 0.14)
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
			ball_previous.erase(id)
	update_sentries(rules, dt)
	var player: Dictionary = rules.players[local_team]
	aim_line.visible = rules.phase == "play" and player.stun <= 0 and not guide_enabled
	update_aim_guide(rules, local_team, dt)
	aim_line.position = units[local_team].position + Vector3.UP * 0.032
	aim_line.rotation.y = units[local_team].get_node("Body").rotation.y
	if rules.phase != phase_before and (rules.phase == "goal" or rules.phase == "finished"):
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
		if effect.get("combat_finish", false):
			CombatFinish.animate(effect, remaining)
		if effect.get("lamp", 0.0) > 0.0:
			# A lamp dies down instead of shrinking.
			effect.node.light_energy = effect.lamp * remaining * remaining
		elif effect.get("keep", false):
			pass
		elif effect.get("grow", false):
			# Blast ring: opens outwards and fades instead of shrinking away.
			effect.node.scale = effect.base * lerpf(0.25, 1.0, 1.0 - remaining)
			effect.node.material_override = material(Color(effect.tint, snappedf(remaining, 0.1) * 0.9), true)
		else:
			effect.node.scale = effect.base * remaining
		if effect.gravity:
			effect.node.rotate_x(dt * 4)
			effect.node.rotate_z(dt * 2)
		if effect.get("spin", false):
			effect.node.rotate_x(dt * 7.5)
			effect.node.rotate_z(dt * 5.5)
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
	root.get_node("FloorGlow").material_override = soft_disc_material(Color(CYAN if owner == 0 else CORAL, 0.42))
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
	if light_pool.is_empty() or active_lights >= [2, 4, 8][quality_level]: return
	var lamp = light_pool.pop_back()
	active_lights += 1
	lamp.show()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	effects.append({"node": lamp, "light_pool": true, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "keep": true, "lamp": energy})

func schedule(seconds: float, call: Callable) -> void:
	pending.append({"time": seconds, "call": call})

func shake(power: float) -> void:
	shake_power = maxf(shake_power, power * shake_scale)

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

func power_flash(pos: Vector2, id: String) -> void:
	# A power going off: a floor ring in its colour; defensive powers lift a column of
	# embers, attacks throw sparks outwards.
	var color = Rules.power_color(id)
	if fx != null:
		var defense = id in ["weld", "rebuild", "mirror", "walls", "bloom", "plating"]
		fx.ring(Vector3(pos.x, 0.06, pos.y), color, 0.8, 0.45)
		fx.glow(Vector3(pos.x, 0.5, pos.y), color, 0.9, 0.3)
		if defense:
			fx.embers(Vector3(pos.x, 0.2, pos.y), color, 10, 1.2, 0.18, 0.7, Vector3.UP, 25.0, 1.5)
		else:
			fx.sparks(Vector3(pos.x, 0.45, pos.y), color, 10, 6.0, 0.14, 0.35, Vector3.UP, 100.0)
	burst(pos, color, false)

func laser_beam(from: Vector2, heading: Vector2, team: int) -> void:
	# Each bite sparks at the muzzle; the beam itself is drawn every frame below.
	burst(from + heading * 0.6, Rules.power_color("laser"), false)

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
	sphere(rock, Vector3.ZERO, Vector3.ONE * radius * 1.1, Color("1b2b33"))
	sphere(rock, Vector3.ZERO, Vector3.ONE * radius * 0.7, Color(hot, 0.9), true)
	sphere(rock, Vector3.ZERO, Vector3.ONE * radius * 1.45, Color(color, 0.3), true)
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
		box(bolt, Vector3(at.x, low + span * 0.5, at.y), Vector3(wide, span, wide), Color(color, 0.32), true, 0.02)
	var core: float = 0.15 * weight
	box(bolt, Vector3(at.x, (floor_y + BOLT_TOP) * 0.5, at.y), Vector3(core, BOLT_TOP - floor_y, core), Color(hot, 1.0), true, 0.01)
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
	flash(Vector3(at.x, 0.9, at.y), color, 3.2, 0.3, 8.0)

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
	effects.append({"node": label, "v": Vector3(0, 0.8, 0), "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE, "keep": true})

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

func shock_mark(team: int, at: Vector2, bite: int) -> void:
	# One brick, caught by the wave: a halo in the colour of the blow and the lives it took
	# floating off it. Without this the ultimate is all sky and you cannot read what it did.
	if effects.size() + 2 >= effect_limit:
		return
	var color: Color = [Color("ffe9c0"), Color("ffd27a"), Color("ff9f5c"), Color("ff6a5c")][clampi(bite, 0, 3)]
	var halo = torus(self, Vector3(at.x, 0.42, at.y), 0.32, 0.05, Color(color, 0.95), true)
	effects.append({"node": halo, "v": Vector3(0, 1.0, 0), "ttl": 0.5, "life": 0.5, "gravity": false, "base": Vector3.ONE * 2.0, "grow": true, "tint": color})
	tally_mark(team, at, bite, color)

func shock_wave(at: Vector2, marks: Array = [], hurt: int = 1) -> void:
	# The same blow as the stun pulse, on the scale of the whole stadium: rings that leave
	# the core and keep going out past the walls, with the ground lit under them.
	var color = Rules.power_color("singularity")
	var pale = Color("fff0d2")
	for wave in range(3):
		if effects.size() >= effect_limit:
			break
		var life = 0.85 + wave * 0.18
		var ring = torus(self, Vector3(at.x, 0.3 + wave * 0.22, at.y), 1.0, 0.13 - wave * 0.03, Color(pale if wave == 0 else color, 0.95), true)
		ring.scale = Vector3.ONE * 0.16
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": Vector3.ONE * (22.0 + wave * 6.0), "grow": true, "tint": color})
	var dome = sphere(self, Vector3(at.x, 0.6, at.y), Vector3.ONE * 1.4, Color(color, 0.5), true)
	effects.append({"node": dome, "v": Vector3.ZERO, "ttl": 0.55, "life": 0.55, "gravity": false, "base": Vector3.ONE * 6.5, "grow": true, "tint": color})
	emitter(Vector3(at.x, 0.6, at.y), pale, 40, 0.9, 13.0, 90.0, 0.34, -4.0, Vector3.UP)
	flash(Vector3(at.x, 1.4, at.y), color, 8.0, 0.7, 22.0)
	shake(0.85)
	# Every brick the wave catches lights up as the front reaches it, and says what it took.
	for mark in marks:
		var spot: Vector2 = mark.p
		var bite: int = int(mark.bite)
		pending.append({"time": clampf(at.distance_to(spot) / SHOCK_SPEED, 0.0, 0.8), "call": func(): shock_mark(hurt, spot, bite)})

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
	var pale = Color("ffd7e6")
	for side in [-1.0, 1.0]:
		if effects.size() + 2 >= effect_limit:
			break
		var curtain = Node3D.new()
		add_child(curtain)
		curtain.position = Vector3(0, 0, side * Rules.HALF_LENGTH * 0.7)
		var span: float = Rules.side_x(map.get("outline", "hex"), Rules.narrow_of(map)) * 2.0
		box(curtain, Vector3(0, 0.75, 0), Vector3(span, 1.5, 0.1), Color(color, 0.8), true, 0.04)
		box(curtain, Vector3(0, 0.75, 0), Vector3(span, 1.9, 0.5), Color(color, 0.22), true, 0.04)
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
	cylinder(root, Vector3(0, 0.1, 0), 0.5, 0.2, DARK, false, 18)
	cylinder(root, Vector3(0, 0.26, 0), 0.44, 0.12, Color(GOLD, 0.95), false, 18)
	var drum = Node3D.new()
	drum.name = "Drum"
	root.add_child(drum)
	# Tall enough not to be taken for a bumper, with a lit head and a barrel out front.
	box(drum, Vector3(0, 0.62, 0), Vector3(0.54, 0.62, 0.54), CREAM, false, 0.09)
	box(drum, Vector3(0, 0.98, 0), Vector3(0.34, 0.16, 0.34), Color(color, 0.95), true, 0.04)
	cylinder(drum, Vector3(0, 1.1, 0), 0.06, 0.22, Color(GOLD, 0.9), true, 10)
	var gun = Node3D.new()
	gun.name = "Gun"
	drum.add_child(gun)
	box(gun, Vector3(0, 0.6, 0.42), Vector3(0.2, 0.2, 0.62), DARK, false, 0.03)
	box(gun, Vector3(0, 0.6, 0.3), Vector3(0.3, 0.3, 0.18), Color(GOLD, 0.85), false, 0.04)
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
					part.material_override = material(Color(glow, snappedf(0.35 + 0.45 * wind, 0.05)), true)
			if fmod(clock, 0.14) < dt:
				# Embers pulled up into the pilot, faster as the moment approaches.
				var ring_at = pilot + Vector2(cos(clock * 5.0), sin(clock * 5.0)) * lerpf(2.4, 0.8, wind)
				emitter(Vector3(ring_at.x, 0.15, ring_at.y), glow, 8, 0.45, 1.6 + wind * 2.4, 16.0, 0.26, -2.5, Vector3.UP)
				flash(Vector3(pilot.x, 0.9, pilot.y), glow, 1.2 + wind * 3.5, 0.2, 6.0)
		var ray: Node3D = power_nodes[team].get_node("SunRay")
		var firing_sun: bool = state.ultimate_time > 0 and String(state.ultimate_id) == "sun_ray"
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
			ray.scale = Vector3(reach, beat * fade, beat * fade)
			for i in range(4):
				var halo: Node3D = ray.get_node("Ring%d" % i)
				# The rings travel away from the gun, over and over.
				halo.position.x = fmod(0.1 + i * 0.25 + clock * 0.55, 1.0)
				halo.scale = Vector3.ONE * (1.0 + sin(clock * 9.0 + i) * 0.12)
			if fmod(clock, 0.1) < dt:
				emitter(muzzle, Color("fff4d2"), 10, 0.4, 7.0, 24.0, 0.3, -1.5, Vector3(aim.x, 0, aim.y))
				shake(0.28)
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
				var travel: Vector2 = path[leg + 1] - from
				# Each leg is modelled from 0 to 1 along +X, so it grows out of its corner.
				limb.position = Vector3(from.x, 0.58, from.y)
				limb.rotation.y = -travel.angle()
				limb.scale = Vector3(travel.length(), flicker, flicker)


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
		# Ceramic slabs with a brass rail, the same build as the fixed barriers.
		for slab in Rules.team_walls(team, map):
			var a = Vector3(slab.a.x, 0.0, slab.a.y)
			var b = Vector3(slab.b.x, 0.0, slab.b.y)
			segment(walls, a + Vector3.UP * 0.55, b + Vector3.UP * 0.55, Rules.BARRIER_RADIUS * 2, 1.1, CREAM)
			segment(walls, a + Vector3.UP * 1.12, b + Vector3.UP * 1.12, Rules.BARRIER_RADIUS * 1.2, 0.06, DARK)
			segment(walls, a + Vector3.UP * 1.17, b + Vector3.UP * 1.17, 0.06, 0.03, Color(Rules.power_color("walls"), 0.95), true)
			for end in [a, b]:
				cylinder(walls, end + Vector3.UP * 0.55, Rules.BARRIER_RADIUS, 1.1, CREAM, false, 14)
		walls.hide()
		var ray = Node3D.new()
		ray.name = "SunRay"
		root.add_child(ray)
		# Modelled from 0 to 1 along +X: an opaque white core, a solid sun-coloured body
		# and a soft corona around them, plus rings that ride down the beam.
		box(ray, Vector3(0.5, 0, 0), Vector3(1.0, 0.34, 0.34), Color("fff6e0"), true, 0.02)
		box(ray, Vector3(0.5, 0, 0), Vector3(1.0, 0.72, 0.72), Rules.power_color("sun_ray"), true, 0.03)
		box(ray, Vector3(0.5, 0, 0), Vector3(1.0, 1.25, 1.25), Color(Rules.power_color("sun_ray"), 0.35), true, 0.04)
		box(ray, Vector3(0.5, 0, 0), Vector3(1.0, 1.9, 1.9), Color(Color("ff9a3c"), 0.16), true, 0.05)
		for i in range(4):
			var halo = torus(ray, Vector3(0.1 + i * 0.25, 0, 0), 0.85, 0.07, Color("ffe9a8"))
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
			box(windup, Vector3(cos(angle) * 0.9, 0.5, sin(angle) * 0.9), Vector3(0.14, 0.5, 0.14), Color(GOLD, 0.6), true, 0.02)
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
			box(limb, Vector3(0.5, 0, 0), Vector3(1.0, 0.16, 0.16), Color(Rules.power_color("laser"), 0.85), true, 0.02)
			box(limb, Vector3(0.5, 0, 0), Vector3(1.0, 0.34, 0.34), Color(Rules.power_color("laser"), 0.22), true, 0.02)
		beam.hide()


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

func shot_feedback(team: int) -> void:
	shot_age[team] = 0.0
	var gun: Node3D = units[team].get_node("Body/Gun")
	gun.position.z = 0.055
	gun.get_node("Flash").scale = Vector3.ONE * 0.42
	var origin = muzzle_of(team)
	var direction = -units[team].get_node("Body").global_basis.z
	for i in range(2 if quality_level == 0 else 4):
		feedback_chip(origin, direction * (2.5 + i) + Vector3((i % 2 - 0.5) * 1.1, 0.3, 0), shot_colors[team], 0.09, Vector3.ONE * 0.06)

func impact_feedback(event: Dictionary) -> void:
	var kind = String(event.kind)
	var broken = kind == "brick"
	var shield = kind in ["mirror", "player_hit"] or event.get("soaked", false)
	var tint: Color = shot_colors[int(event.get("team", 0))] if shield or kind.begins_with("brick") else GOLD
	var at: Vector2 = event.p
	var heading: Vector2 = event.get("heading", Vector2.ZERO)
	var direction = Vector3(heading.x, 0, heading.y)
	var origin = Vector3(at.x, 0.55, at.y)
	feedback_chip(origin, Vector3.ZERO, Color("fff3d5"), 0.055, Vector3.ONE * (0.28 if broken else 0.16))
	var count = (5 if quality_level == 0 else 8) if broken else (2 if quality_level == 0 else 4)
	for i in range(count):
		var angle = i * 2.399
		var velocity = direction * (1.5 if broken else -0.65) + Vector3(cos(angle), 0.8 + (i % 3) * 0.35, sin(angle)) * (1.7 if broken else 0.7)
		feedback_chip(origin, velocity, CREAM if broken and i % 2 == 0 else tint, 0.38 if broken else 0.13, Vector3(0.13, 0.08, 0.16) if broken else Vector3.ONE * 0.055, broken)
	if shield and effects.size() < effect_limit:
		var ring = torus(self, origin, 0.32, 0.025, tint, true)
		effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.18, "life": 0.18, "gravity": false, "base": Vector3.ONE * 1.7, "grow": true, "tint": tint})
	if kind == "brick_hit" and event.has("brick_id"):
		brick_reactions[int(event.brick_id)] = 0.14
	if event.get("defense_open", false):
		var team = int(event.team)
		var spot = Vector3(goals[team].global_position.x, 0.1, goals[team].global_position.z)
		if effects.size() < effect_limit:
			var ring = torus(self, spot, 1.1, 0.045, tint, true)
			effects.append({"node": ring, "v": Vector3.ZERO, "ttl": 0.35, "life": 0.35, "gravity": false, "base": Vector3.ONE * 2.0, "grow": true, "tint": tint})

func ultimate_accent(at: Vector2, id: String) -> void:
	# Small silhouette accents augment, rather than replace, each themed main effect.
	var tint = Rules.power_color(id)
	var origin = Vector3(at.x, 0.7, at.y)
	var count = 5 if quality_level == 0 else 9
	var rising = id in ["bloom", "meteors", "sun_ray"]
	var inward = id in ["singularity", "plunder"]
	for i in range(count):
		var a = float(i) / count * TAU
		var radial = Vector3(cos(a), 0, sin(a))
		feedback_chip(origin + radial * (0.95 if inward else 0.22), radial * (-2.0 if inward else 2.4) + Vector3.UP * (2.3 if rising else 0.55), tint, 0.24, Vector3(0.055, 0.22 if rising else 0.055, 0.12))
	shake(0.30)
