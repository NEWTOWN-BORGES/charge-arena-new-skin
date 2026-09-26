extends SceneTree
# The app icon: BIT's face, front on, rendered from the real model (needs a GPU; omit --headless).
#   godot -s tools/render_icon.gd      # writes art/icon/bit_face.png (512 x 512, transparent)
const View = preload("res://scripts/indie_arena_view.gd")
const Robots = preload("res://scripts/robots.gd")
const OUT = "res://art/icon/bit_face.png"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(512, 512)
	root.transparent_bg = true
	root.use_hdr_2d = false
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c3c9cf")
	world.environment.ambient_light_energy = 0.9
	world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root.add_child(world)
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 200, 0)
	key.light_energy = 1.2
	root.add_child(key)
	var view = View.new()
	view.quality_level = 2
	root.add_child(view)
	var stage = Node3D.new()
	root.add_child(stage)
	var pilot: Node3D = view.build_player(Color("72ddc6"), 0, 0, stage)
	for node in pilot.get_children():
		if node.name != "Body":
			node.hide()
	var body: Node3D = pilot.get_node("Body")
	Robots.set_mood(body, 1)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	# Robots face -Z: the camera stands in front, a touch above, and frames the head.
	# Framed from the real top of the head (the pilots are small in game units).
	var top = 0.0
	for node in body.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (node.global_transform * node.get_aabb()).end.y)
	# The screen of the head sits about a sixth of the way down from the antenna tip.
	var focus = Vector3(0, top * 0.8, 0)
	camera.size = top * 0.5
	camera.position = focus + Vector3(0.0, top * 0.05, -4.0)
	camera.look_at(focus)
	camera.current = true
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	print("ICON ", root.get_texture().get_image().save_png(OUT))
	quit()
