extends SceneTree
## Run in an isolated QA mirror, with a graphical renderer and an output directory.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(3440)
	var output: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1000, 760)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await process_frame
	game.game_settings.tutorial_match = true
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	var worlds: Array = ["aurora", "terra", "oceano", "orbita", "cidade"]
	if OS.get_cmdline_user_args().size() > 1:
		if OS.get_cmdline_user_args()[1] == "neon":
			worlds = ["aurora_sombria", "vale_corrompido", "abismo_neon", "eclipse_orbital", "cidade_negra"]
		else:
			worlds = [OS.get_cmdline_user_args()[1]]
	for world in worlds:
		game.start_pve(game.Rules.quick_map(world))
		game.set_physics_process(false)
		game.rules.phase = "play"
		game.arena.update_state(game.rules, 0, 0.016)
		game.hud.hide()
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var result = root.get_texture().get_image().save_png(output.path_join(world + ".png"))
		assert(result == OK)
		print("MAP_CAPTURE ", world, " static_batches=", game.arena.static_batch_count,
			" draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" primitives=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	game.video.configure(60, 0, false, false)
	game.video.apply(root, game.arena)
	# Detail density is chosen during construction, so rebuild at the new quality.
	# Quick play reuses an arena with the same id; invalidate that cache in this capture.
	game.arena.map = {}
	game.start_pve(game.Rules.quick_map(worlds.back()))
	game.set_physics_process(false)
	game.rules.phase = "play"
	game.arena.update_state(game.rules, 0, 0.016)
	game.hud.hide()
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(String(worlds.back()) + "-leve.png")) == OK)
	print("MAP_LEVE draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	game.queue_free()
	await process_frame
	quit()
