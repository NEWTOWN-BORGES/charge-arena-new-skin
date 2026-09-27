extends SceneTree
# A robot in orthographic front, right, back and left views on a plain dark studio, to lay
# over a blueprint (needs a GPU; omit --headless). The roster is only changed in memory.
# Usage: godot -s tests/capture_ortho.gd -- <output.png> <skin> [part=value,...]
#   keys as in capture_proposals.gd: torso, head, legs, arm, ..., eyes, pal_<role>, hip_y
const View = preload("res://scripts/indie_arena_view.gd")
const Robots = preload("res://scripts/robots.gd")
const TILE = Vector2i(480, 560)
# Vertical span shown, in metres: the robot's 1.8 m and a margin.
const SPAN = 2.24

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0]
	var skin = int(args[1])
	var entry: Dictionary = Robots.cast()[skin]
	if args.size() > 2:
		entry.parts["head"] = ""
		entry.parts["top"] = ""
		entry.parts["spin"] = ""
		for pair in String(args[2]).split(","):
			var kv = pair.split("=")
			if kv[0] == "eyes":
				entry.eye_style = kv[1]
			elif kv[0].begins_with("pal_"):
				entry.palette[kv[0].substr(4)] = kv[1]
			elif kv[0] == "hip_y":
				entry.hip = [entry.hip[0], float(kv[1]), entry.hip[2]]
			else:
				entry.parts[kv[0]] = kv[1]
	root.size = TILE
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("2a2e35")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c3c9cf")
	world.environment.ambient_light_energy = 0.95
	world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root.add_child(world)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_energy = 1.1
	root.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 150, 0)
	fill.light_energy = 0.45
	root.add_child(fill)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = SPAN
	root.add_child(camera)
	var view = View.new()
	view.quality_level = 2
	root.add_child(view)
	var stage = Node3D.new()
	root.add_child(stage)
	var pilot: Node3D = view.build_player(Color("72ddc6"), 0, skin, stage)
	pilot.position = Vector3.ZERO
	for node in pilot.get_children():
		if node.name != "Body":
			node.hide()
	var body: Node3D = pilot.get_node("Body")
	body.rotation = Vector3.ZERO
	var middle = Vector3(0, SPAN * 0.5 - 0.1, 0)
	var sheet: Image = null
	# The robot faces -Z: front, its right (+X), back, its left.
	var eyes = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	for i in range(eyes.size()):
		camera.position = middle + eyes[i] * 8.0
		camera.look_at(middle)
		for f in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var image = root.get_texture().get_image()
		if sheet == null:
			sheet = Image.create(TILE.x * eyes.size(), TILE.y, false, image.get_format())
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, TILE), Vector2i(i * TILE.x, 0))
	print("ORTHO ", path, " ", sheet.save_png(path))
	quit()
