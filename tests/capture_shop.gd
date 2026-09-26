extends SceneTree
# The power shop at each step of its lesson, and a match key with the tutorial bubble (needs a
# GPU; omit --headless).  Usage: godot -s tests/capture_shop.gd -- <output prefix>
func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	print("SHOP ", path, " ", root.get_texture().get_image().save_png(path))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-shop"
	root.size = Vector2i(720, 1560)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	var hud = game.hud
	hud.open_powers()
	hud.preview_power(4)
	for step in range(3):
		hud.tutorial_step = step
		hud.step_clock = hud.STEP_TIME[step] * 0.55
		hud.demo_clock = 1.6
		await create_timer(0.05).timeout
		await shot("%s-step%d.png" % [prefix, step])
	hud.close_powers()
	game.power_shop.tutorial_done = false
	game.start_level(0)
	await create_timer(1.0).timeout
	game.rules.phase = "play"
	game.rules.powers[0].charge[0] = 20
	for i in range(20):
		game._physics_process(1.0 / 60.0)
		await process_frame
	await shot("%s-match.png" % prefix)
	quit()
