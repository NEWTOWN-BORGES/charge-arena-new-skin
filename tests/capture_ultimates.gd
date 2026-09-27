extends SceneTree
# Every skin ultimate fired in a real match, a frame taken as it lands (needs a GPU; omit
# --headless).  Usage: godot -s tests/capture_ultimates.gd -- <output prefix> [ids...]
const Powers = preload("res://scripts/powers.gd")
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-ult"
	var ids: Array = args.slice(1) if args.size() > 1 else Powers.ULTIMATES.map(func(e): return String(e.id))
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.5).timeout
	# The match is stepped by hand, one tick a frame: with the engine stepping it too, a slow
	# software renderer ran whole ultimates between two frames.
	game.set_physics_process(false)
	for id in ids:
		game.start_level(0)
		await create_timer(0.8).timeout
		game.rules.phase = "play"
		game.rules.loadouts[0] = [game.rules.loadouts[0][0], game.rules.loadouts[0][1], id]
		game.rules.powers[0].charge[2] = 99
		game.rules.activate_power(0, 2)
		# Wind-up, then frames as the ultimate lands and plays out.
		var shots = {int(60 * 2.1): "a", int(60 * 2.5): "b", int(60 * 3.1): "c"}
		game.hud.visible = false
		for f in range(int(60 * 3.2)):
			game._physics_process(1.0 / 60.0)
			await process_frame
			if shots.has(f):
				await RenderingServer.frame_post_draw
				var path = "%s-%s-%s.png" % [prefix, id, shots[f]]
				print("ULT ", path, " ", root.get_texture().get_image().save_png(path))
		game.hud.visible = true
	quit()
