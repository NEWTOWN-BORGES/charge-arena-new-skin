extends SceneTree
## Reproducible GPU previews: lobby, match, 3v3, low profile and the original robot cast.
## godot --path . -s tests/capture_heroic.gd -- <absolute output prefix>
const Rules = preload("res://scripts/gameplay/arena_rules.gd")

func _initialize() -> void:
	call_deferred("run")

func grab(path: String) -> void:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(path)
	assert(error == OK, "Could not save " + path)
	print("CAPTURE ", path)

func run() -> void:
	seed(3440)
	var prefix = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "user://heroic-preview.cfg"
	game.game_settings.tutorial_match = true
	await create_timer(0.6).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	await grab(prefix + "-lobby.png")
	game.start_pve(Rules.quick_map("aurora"))
	await create_timer(0.3).timeout
	game.set_physics_process(false)
	game.rules.phase = "play"
	game.arena.set_skin(0, 7)
	game.arena.set_skin(1, 10)
	game.arena.update_state(game.rules, 0, 0.016)
	await grab(prefix + "-arena.png")
	game.video.configure(60, 0, false, false)
	game.video.apply(root, game.arena)
	await grab(prefix + "-leve.png")
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	root.size = Vector2i(1280, 720)
	game.hud.visible = false
	var cam = Camera3D.new()
	game.arena.add_child(cam)
	cam.current = true
	cam.fov = 44
	var unit = game.arena.units[0]
	cam.global_position = unit.global_position + Vector3(1.7, 1.9, 4.2)
	cam.look_at(unit.global_position + Vector3.UP * 0.9)
	await grab(prefix + "-robo.png")
	game.start_squad(true)
	await create_timer(0.3).timeout
	game.set_physics_process(false)
	game.rules.phase = "play"
	for tick in range(180):
		var commands: Array = []
		for index in range(game.rules.players.size()):
			commands.append(game.rules.squad_command(index))
		game.rules.step(1.0 / 60.0, commands)
		game.arena.update_state(game.rules, 0, 1.0 / 60.0)
	game.hud.visible = true
	root.size = Vector2i(720, 1280)
	await grab(prefix + "-3v3.png")
	print("HEROIC_CAPTURE_RESULT players=", game.rules.players.size())
	quit(0)
