extends SceneTree
# Every menu of the game, phone portrait and landscape, to check them by eye (needs a GPU;
# omit --headless).  Usage: godot -s tests/capture_menus.gd -- <output prefix>
func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	print("MENU ", path, " ", root.get_texture().get_image().save_png(path))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-menu"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var hud = game.hud
	for size in [Vector2i(720, 1560), Vector2i(1560, 720)]:
		root.size = size
		await create_timer(0.8).timeout
		var tag = "p" if size.x < size.y else "l"
		await shot("%s-%s-lobby.png" % [prefix, tag])
		for name in ["video", "skins", "powers", "pvp", "levels", "map_picker"]:
			hud.call("open_" + name)
			await create_timer(0.4).timeout
			await shot("%s-%s-%s.png" % [prefix, tag, name])
			for overlay in ["video_overlay", "skins_overlay", "powers_overlay", "pvp_overlay", "levels_overlay", "map_overlay"]:
				var node = hud.get(overlay)
				if node != null:
					node.hide()
		game.start_level(0)
		await create_timer(1.0).timeout
		game.rules.phase = "play"
		await shot("%s-%s-match.png" % [prefix, tag])
		hud.show_pause(true)
		await shot("%s-%s-pause.png" % [prefix, tag])
		hud.show_pause(false)
		game.return_to_menu()
		await create_timer(0.6).timeout
	quit()
