extends SceneTree
# Renders the story backdrops that are real arenas of the game (needs a GPU; omit --headless):
#   godot -s tools/render_story_arenas.gd
# Writes art/story/scenes/treino.png (the training arena) and arena_<boss>.png, the arena
# where each story rival plays: the empty court from a low, wide angle behind BIT's wall,
# portrait 1080x1920, no pilots and no HUD.
const Story = preload("res://scripts/story_script.gd")
const OUT = "res://art/story/scenes/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1080, 1920)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	if game.hud.tutorial_running():
		game.hud.tutorial.close(true)
	game.video.configure(60, 2, false, false)
	var jobs: Array = [["treino", 0]]
	for boss in Story.ORDER:
		jobs.append(["arena_%d" % boss, game.story_level_of(boss)])
	for job in jobs:
		game.start_level(int(job[1]))
		await create_timer(0.8).timeout
		if game.hud.tutorial_running():
			game.hud.tutorial.close(true)
		game.video.apply(root, game.arena)
		game.set_process(false)
		game.set_physics_process(false)
		game.hud.visible = false
		var arena = game.arena
		for unit in arena.units:
			unit.visible = false
		var cam: Camera3D = arena.camera
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 58
		cam.h_offset = 0
		cam.v_offset = 0
		cam.global_position = Vector3(3.2, 3.6, 12.5)
		cam.look_at(Vector3(-0.4, 1.4, -6.0))
		for i in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		var file = OUT + String(job[0]) + ".png"
		print("ARENA ", file, " ", root.get_texture().get_image().save_png(file))
		game.set_process(true)
		game.set_physics_process(true)
		game.hud.visible = true
	quit()
