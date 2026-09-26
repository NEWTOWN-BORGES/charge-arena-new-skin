extends SceneTree
# Renders the HUD portraits from the real robot models (needs a GPU; omit --headless):
#   godot -s tools/render_portraits.gd
# Writes art/robots/portraits/cast_<skin>.png and road_<kind>.png, each with a _dizzy twin.
const View = preload("res://scripts/indie_arena_view.gd")
const Robots = preload("res://scripts/robots.gd")
const SIZE = 256
const OUT = "res://art/robots/portraits/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(SIZE, SIZE)
	root.transparent_bg = true
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# The studio light of the game: neutral fill, AgX like the Blender renders.
	world.environment.ambient_light_color = Color("c3c9cf")
	world.environment.ambient_light_energy = 0.9
	world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root.add_child(world)
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_color = Color("fff3e6")
	key.light_energy = 1.15
	root.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color("e4ecf6")
	root.add_child(fill)
	var camera = Camera3D.new()
	camera.fov = 26
	root.add_child(camera)
	camera.position = Vector3(-0.95, 1.68, -3.75)
	camera.look_at(Vector3(0, 1.28, 0))
	var view = View.new()
	view.quality_level = 2
	root.add_child(view)
	var stage = Node3D.new()
	root.add_child(stage)
	var jobs: Array = []
	for skin in range(Robots.cast().size()):
		jobs.append([skin, "cast_%d" % skin])
	for kind in range(10):
		jobs.append([Robots.STATION_SKIN + kind, "road_%d" % kind])
	for job in jobs:
		var pilot: Node3D = view.build_player(Color("72ddc6"), 0, job[0], stage)
		pilot.position = Vector3.ZERO
		for node in pilot.get_children():
			if node.name != "Body":
				node.hide()
		var body: Node3D = pilot.get_node("Body")
		for mood in [0, 2]:
			Robots.set_mood(body, mood)
			# Keep the capture away from a blink.
			var face: ShaderMaterial = body.get_node("Robot_screen").material_override
			face.set_shader_parameter("seed", 1.5 - Time.get_ticks_msec() / 1000.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var image = root.get_texture().get_image()
			var file = OUT + job[1] + ("_dizzy" if mood == 2 else "") + ".png"
			print("PORTRAIT ", file, " ", image.save_png(file))
		pilot.free()
	quit()
