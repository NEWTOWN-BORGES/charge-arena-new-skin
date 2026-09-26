extends SceneTree
# Frame cost while a power is running: both pilots fire the machine gun (METRALHADORA) back to
# back, the heaviest moment reported on phones. Prints per-profile averages and the worst frame
# (needs a GPU for the render counters; omit --headless).
# Usage: godot -s tests/benchmark_powers.gd -- [power id, default rapid]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var power = args[0] if args.size() > 0 else "rapid"
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.3).timeout
	game.start_pve()
	for quality in [2, 1, 0]:
		game.video.configure(60, quality, false, false)
		game.video.apply(root, game.arena)
		game.rules.phase = "play"
		for i in range(20):
			await process_frame
		var draws = 0.0
		var objects = 0.0
		var cpu = 0.0
		var worst = 0.0
		var frames = 180
		for i in range(frames):
			if i % 60 == 0:
				for team in range(2):
					if power == "rapid":
						game.rules.powers[team].rapid_time = game.rules.RAPID_SECONDS
			var start = Time.get_ticks_usec()
			game._physics_process(1.0 / 60.0)
			await process_frame
			var spent = (Time.get_ticks_usec() - start) / 1000.0
			cpu += spent
			worst = maxf(worst, spent)
			draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		print("POWERS power=%s quality=%d draws=%d objects=%d frame_ms=%.1f worst_ms=%.1f nodes=%d effects=%d" % [power, quality, draws / frames, objects / frames, cpu / frames, worst, game.arena.get_child_count(), game.arena.effects.size()])
	quit()
