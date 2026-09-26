extends SceneTree
# One match frame per world, portrait and landscape, HUD hidden (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_worlds.gd -- <output prefix> [level index ...]
func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	print("WORLD ", path, " ", root.get_texture().get_image().save_png(path))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-world"
	var levels: Array = []
	for i in range(1, args.size()):
		levels.append(int(args[i]))
	if levels.is_empty():
		levels = [0]
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.skins.unlock_all = true
	for level in levels:
		root.size = Vector2i(720, 1280)
		game.start_level(level)
		await create_timer(1.0).timeout
		game.rules.phase = "play"
		for i in range(30):
			game._physics_process(1.0 / 60.0)
			await process_frame
		game.hud.visible = false
		await shot("%s-%d-portrait.png" % [prefix, level])
		root.size = Vector2i(1280, 720)
		await create_timer(0.3).timeout
		await shot("%s-%d-landscape.png" % [prefix, level])
		game.hud.visible = true
	quit()
