extends SceneTree
# The lobby robots through their routine: one frame per phase (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_lobby_motion.gd -- <output prefix>
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-lobby-motion"
	root.size = Vector2i(720, 1560)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	for moment in [1.0, 3.0, 5.2, 7.4]:
		# Jump the lobby clock to a moment of the routine.
		game.arena.clock = moment
		for i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var path = "%s-%s.png" % [prefix, str(moment)]
		print("MOTION ", path, " ", root.get_texture().get_image().save_png(path))
	quit()
