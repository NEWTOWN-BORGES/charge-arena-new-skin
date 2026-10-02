extends SceneTree
## Actual imported Blender geometry, assembled with the game's robot shaders.
const View = preload("res://scripts/presentation/arena_view.gd")
const Robots = preload("res://scripts/presentation/robots.gd")
const SKINS = [5, 6, 8]
const NAMES = ["ECLIPSE", "ROSCA", "BATIDA"]
const THEMES = ["VILÃO · NÚCLEO GRAVITACIONAL · BLINDAGEM ORBITAL", "MARINHEIRO · HÉLICE · GUINCHO · LANÇA-ARPÃO", "SUBWOOFER · RESSONÂNCIA · AMORTECEDORES"]
var view
var camera: Camera3D
var units: Array = []
var overlay: Control
var prefix: String

func _initialize() -> void: call_deferred("run")

func label_at(text: String, at: Vector2, width: float, size: int, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, 44)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://art/fonts/Rubik-Variable.ttf"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	overlay.add_child(label)

func captions(title: String) -> void:
	for child in overlay.get_children(): child.queue_free()
	label_at(title, Vector2(40, 28), 1360, 31, Color("edf4fa"))
	label_at("MODELOS 3D NO GODOT · GEOMETRIA CRIADA NO BLENDER", Vector2(40, 76), 1360, 15, Color("8da4bb"))

func stage() -> void:
	view = View.new()
	view.quality_level = 2
	root.add_child(view)
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c1424")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9c3ec")
	env.ambient_light_energy = 0.50
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	view.add_child(world)
	var key = DirectionalLight3D.new()
	key.position = Vector3(-3, 6, -5)
	key.light_color = Color("fff0d9")
	key.light_energy = 1.75
	key.shadow_enabled = true
	view.add_child(key)
	key.look_at(Vector3(0, 1, 0))
	for spec in [[Vector3(-5, 3, -2), Color("74bbff"), 2.2], [Vector3(2, 3, 3), Color("bf9bff"), 3.1]]:
		var light = OmniLight3D.new()
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.omni_range = 12
		view.add_child(light)
	var floor = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(200, 200)
	floor.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("111b2c")
	mat.roughness = 0.78
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor.material_override = mat
	floor.position.y = -0.025
	view.add_child(floor)
	for index in range(3):
		var unit = view.build_player(Color("00caff"), 0, SKINS[index], view)
		unit.position = Vector3((1 - index) * 2.7, 0, 0)
		units.append(unit)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.85
	camera.position = Vector3(0, 3.1, -7)
	view.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.current = true
	var canvas = CanvasLayer.new()
	root.add_child(canvas)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	root.msaa_3d = Viewport.MSAA_4X

func grab(name: String) -> void:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(prefix + name + ".png") == OK)
	print("ROBOT_REDESIGN_CAPTURE ", prefix + name + ".png")

func run() -> void:
	prefix = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	stage()
	captions("ECLIPSE / ROSCA / BATIDA")
	for i in range(3):
		label_at(NAMES[i], Vector2(36 + i * 468, 762), 432, 28, Color("edf4fa"))
		label_at(["GRAVIDADE", "MARINHEIRO", "SOM"][i], Vector2(36 + i * 468, 808), 432, 17, Color("75caff"))
	await grab("-elenco")
	# Each character has three real viewing angles, at the same size and lighting.
	for i in range(3):
		for unit in units: unit.hide()
		var copies: Array = []
		for angle in range(3):
			var robot = view.build_player(Color("00caff"), 0, SKINS[i], view)
			robot.position = Vector3((1 - angle) * 2.65, 0, 0)
			robot.rotation.y = deg_to_rad([0, -40, 170][angle])
			copies.append(robot)
		captions(NAMES[i] + " · " + THEMES[i])
		for angle in range(3): label_at(["FRENTE", "TRÊS QUARTOS", "COSTAS"][angle], Vector2(36 + angle * 468, 786), 432, 19, Color("a9bfd3"))
		await grab("-" + NAMES[i].to_lower())
		for robot in copies: robot.queue_free()
	# Keep geometry budget and attachment evidence with the pictures.
	for i in range(3):
		var unit: Node3D = units[i]
		var triangles = 0
		for node in unit.find_children("Robot_*", "MeshInstance3D", true, false):
			if node.name == "Robot_outline": continue
			for surface in range(node.mesh.get_surface_count()):
				var indices = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
				triangles += indices.size() / 3 if indices != null else node.mesh.surface_get_array_len(surface) / 3
		print("ROBOT_REDESIGN_MODEL ", NAMES[i], " triangles=", triangles, " hip=", Robots.recipe(SKINS[i]).hip, " muzzle=", Robots.recipe(SKINS[i]).muzzle)
	print("ROBOT_REDESIGN_RESULT actual_game_models=true characters=3")
	quit(0)
