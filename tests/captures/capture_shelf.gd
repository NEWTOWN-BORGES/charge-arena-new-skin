extends SceneTree
# The shop with the second shelf, and a match with the new shields up (needs a GPU; omit
# --headless).  Usage: godot -s tests/captures/capture_shelf.gd -- <output prefix>
func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	print("SHELF ", path, " ", root.get_texture().get_image().save_png(path))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "user://preview-shelf"
	root.size = Vector2i(720, 1560)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	var hud = game.hud
	hud.open_powers()
	var index = hud.shop_entries().map(func(e): return e.id).find("dome")
	hud.preview_power(index)
	hud.tutorial_step = 2
	hud.step_clock = 1.5
	hud.demo_clock = 1.6
	hud.shop_scroll.scroll_vertical = 10000
	await create_timer(0.1).timeout
	await shot("%s-shop.png" % prefix)
	hud.close_powers()
	game.start_level(0)
	await create_timer(1.0).timeout
	game.set_physics_process(false)
	game.rules.phase = "play"
	game.rules.powers[0].dome_time = 5.0
	game.rules.powers[0].immune_time = 5.0
	game.rules.powers[1].slow_time = 5.0
	for f in range(12):
		game._physics_process(1.0 / 60.0)
		await process_frame
	await shot("%s-match.png" % prefix)
	quit()
