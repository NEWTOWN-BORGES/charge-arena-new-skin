extends SceneTree
## Repeatable comparison of the shipped lobby, battlefield and a close-up of the same robot.
func _initialize() -> void:
	call_deferred("run")

func capture(prefix: String, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path = prefix + "-" + name + ".png"
	var error = root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " error=", error)
	assert(error == OK)

func run() -> void:
	assert("ChargeArenaQA" in OS.get_user_data_dir())
	var prefix = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(720, 1280) if OS.get_cmdline_user_args().has("--portrait") else Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.game_settings.tutorial_lobby = true
	game.game_settings.tutorial_match = true
	game.game_settings.tutorial_shop = true
	game.skins.unlock_all = true
	game.hud.sync_skins(game.skins)
	root.focus_exited.disconnect(game.pause_pve)
	game.set_physics_process(false)
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	await create_timer(1.5).timeout
	await capture(prefix, "menu")
	game.start_pve(game.Rules.quick_map("aurora"))
	game.rules.phase = "play"
	await create_timer(0.8).timeout
	await capture(prefix, "arena")
	game.return_to_menu()
	game.hud.open_skins()
	game.hud.preview_skin(5)
	game.hud.viewer_yaw = PI + 0.35
	await create_timer(0.8).timeout
	await capture(prefix, "skin")
	game.queue_free()
	await process_frame
	await process_frame
	quit()
