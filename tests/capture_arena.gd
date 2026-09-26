extends SceneTree
# A real match frame, HUD included, in portrait and landscape (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_arena.gd -- <output prefix> [level index]
func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	print("ARENA ", path, " ", root.get_texture().get_image().save_png(path))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-arena"
	var level = int(args[1]) if args.size() > 1 else -1
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	if level >= 0:
		game.skins.unlock_all = true
		game.start_level(level)
	else:
		game.start_pve()
	await create_timer(1.2).timeout
	game.rules.phase = "play"
	for i in range(90):
		game._physics_process(1.0 / 60.0)
		await process_frame
	await shot(prefix + "-portrait.png")
	root.size = Vector2i(1280, 720)
	await create_timer(0.3).timeout
	await shot(prefix + "-landscape.png")
	quit()
