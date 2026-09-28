extends SceneTree
# Renders the talking portraits of the Modo história (needs a GPU; omit --headless):
#   godot -s tools/render_story_faces.gd
#   python3 tools/ink_story_faces.py
# The real robot models in flat toon light (two or three hard bands, no gloss), framed from
# the waist up; ink_story_faces.py then draws the anime ink lines. Writes
# art/story/faces/<speaker>.png (and <speaker>_hit.png, dazed): a skin index, or "agente"
# for the traffic officer.
const View = preload("res://scripts/indie_arena_view.gd")
const Robots = preload("res://scripts/robots.gd")
const Story = preload("res://scripts/story_script.gd")
const W = 1024
const H = 1280
const OUT = "res://art/story/faces/"

func _initialize() -> void:
	call_deferred("run")

func toon() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.55
	mat.metallic_specular = 0.25
	return mat

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(W, H)
	root.transparent_bg = true
	root.use_hdr_2d = false
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d9dde6")
	world.environment.ambient_light_energy = 0.95
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(world)
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -40, 0)
	key.light_energy = 1.05
	root.add_child(key)
	# A cool rim from behind, so dark robots (ECLIPSE, MAGNUS) keep their shape.
	var rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_color = Color("b9d4ff")
	rim.light_energy = 0.7
	root.add_child(rim)
	var camera = Camera3D.new()
	camera.fov = 30
	root.add_child(camera)
	var view = View.new()
	view.quality_level = 2
	root.add_child(view)
	var stage = Node3D.new()
	root.add_child(stage)
	var material = toon()
	var jobs: Array = []
	for who in [Story.BIT, Story.BIT_ELITE] + Story.ORDER:
		jobs.append([who, str(who), Color("72ddc6")])
	# The traffic officer: the station robot with the siren on its head, in police blue.
	jobs.append([Robots.STATION_SKIN + 9, "agente", Color("3b6fe0")])
	# VOLTZ, the tournament's announcer: the round-eyed station robot in stage purple.
	jobs.append([Robots.STATION_SKIN + 6, "locutor", Color("a45cff")])
	for job in jobs:
		var pilot: Node3D = view.build_player(job[2], 0, job[0], stage)
		pilot.position = Vector3.ZERO
		for node in pilot.get_children():
			if node.name != "Body":
				node.hide()
		var body: Node3D = pilot.get_node("Body")
		for node in body.find_children("Robot_*", "MeshInstance3D", true, false):
			if node.name != "Robot_screen" and node.name != "Robot_outline":
				node.material_override = material
		# Waist up, framed on the face: the head's own top (plus room for crowns, antennas and
		# leaves) down to about the belt, a little from the side.
		var parts: Dictionary = Robots.recipe(job[0]).parts
		var shape = Robots.head(String(parts.head) if String(parts.head) != "" else String(parts.torso))
		var k = body.scale.y
		var top = (float(shape.top) + 0.42) * k
		var bottom = (float(shape.center) - 1.05) * k
		var focus = Vector3(0, (top + bottom) * 0.5, 0)
		var span = (top - bottom) * 1.05
		var distance = span * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
		camera.position = focus + Vector3(-0.42, 0.1, -1.0).normalized() * distance
		camera.look_at(focus)
		var screen: MeshInstance3D = body.get_node_or_null("Head/Robot_screen")
		if screen == null:
			screen = body.get_node_or_null("Robot_screen")
		# Two faces each: happy, and dazed ("_hit") for the line after a defeat.
		for mood in [1, 2]:
			if screen != null and screen.material_override is ShaderMaterial:
				Robots.set_mood(body, mood)
				screen.material_override.set_shader_parameter("seed", 1.5 - Time.get_ticks_msec() / 1000.0)
			for i in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var image = root.get_texture().get_image()
			var file = OUT + String(job[1]) + ("_hit" if mood == 2 else "") + ".png"
			print("FACE ", file, " ", image.save_png(file))
		pilot.free()
	quit()
