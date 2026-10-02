extends SceneTree
# Pictures of the season-two worlds (needs a GPU; omit --headless):
#   godot -s tools/render_dark_worlds.gd
# Writes art/ui/maps/<world>.png (the map picker thumbnail, a 256 px match view) for the five
# corrupted worlds, and art/story/scenes/arena_s2_<boss>.png: the empty court where each
# season-two rival fights, portrait 1080x1920, for the story's round cards.
const Story = preload("res://scripts/story/story_script.gd")
const ArenaTheme = preload("res://scripts/presentation/arena_theme.gd")
const Rules = preload("res://scripts/gameplay/arena_rules.gd")

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int = 20) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	if game.hud.tutorial_running():
		game.hud.tutorial.close(true)
	game.video.configure(60, 2, false, false)
	# Thumbnails: a quick match in each world, seen from the match camera, cropped square.
	root.size = Vector2i(720, 1280)
	for world in ArenaTheme.DARK_THEMES:
		game.start_pve(Rules.quick_map(world))
		await create_timer(0.8).timeout
		if game.hud.tutorial_running():
			game.hud.tutorial.close(true)
		game.pve_paused = true
		game.video.apply(root, game.arena)
		game.hud.visible = false
		await settle()
		var image: Image = root.get_texture().get_image()
		var side = image.get_width()
		var square = image.get_region(Rect2i(0, int(image.get_height() * 0.5 - side * 0.5), side, side))
		square.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		print("THUMB ", world, " ", square.save_png("res://art/ui/maps/%s.png" % world))
		game.hud.visible = true
		game.pve_paused = false
	# Story backdrops: each season-two rival's court, empty, from low behind BIT's wall.
	root.size = Vector2i(1080, 1920)
	for boss in Story.ORDER_HARD:
		game.begin_story(Story.ORDER_HARD.find(boss), true)
		await create_timer(0.8).timeout
		if game.hud.tutorial_running():
			game.hud.tutorial.close(true)
		game.video.apply(root, game.arena)
		game.set_process(false)
		game.set_physics_process(false)
		game.hud.visible = false
		for unit in game.arena.units:
			unit.visible = false
		var cam: Camera3D = game.arena.camera
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 58
		cam.h_offset = 0
		cam.v_offset = 0
		cam.global_position = Vector3(3.2, 3.6, 12.5)
		cam.look_at(Vector3(-0.4, 1.4, -6.0))
		await settle()
		print("S2 ", boss, " ", root.get_texture().get_image().save_png("res://art/story/scenes/arena_s2_%d.png" % boss))
		game.set_process(true)
		game.set_physics_process(true)
		game.hud.visible = true
	quit()
