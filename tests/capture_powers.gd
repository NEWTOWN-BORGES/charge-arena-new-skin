extends SceneTree
# The solid pieces of the powers in a match: the walls up, a sentry and a falling meteor
# (needs a GPU; omit --headless).  Usage: godot -s tests/capture_powers.gd -- <output.png>
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "res://preview-powers.png"
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.5).timeout
	game.start_level(0)
	await create_timer(1.0).timeout
	game.rules.phase = "play"
	var Rules = load("res://scripts/arena_rules.gd")
	game.rules.powers[0].walls_time = Rules.WALLS_SECONDS * 0.5
	var sentry = game.arena.build_sentry(0)
	sentry.position = Vector3(-1.6, 0, 1.2)
	var other = game.arena.build_sentry(1)
	other.position = Vector3(1.6, 0, -1.2)
	game.arena.meteor_fall(Vector2(1.0, -4.0), 0.45, true)
	for f in range(12):
		game._physics_process(1.0 / 60.0)
		await process_frame
	game.hud.visible = false
	await RenderingServer.frame_post_draw
	print("POWERS ", path, " ", root.get_texture().get_image().save_png(path))
	quit()
