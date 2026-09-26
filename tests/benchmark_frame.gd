extends SceneTree
# Frame cost of a real match: draw calls, primitives and CPU time per frame, per quality profile
# (needs a GPU for the render counters; omit --headless).
# Usage: godot -s tests/benchmark_frame.gd -- [level index] [nohud] [lights=N]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var level = int(args[0]) if args.size() > 0 else -1
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.3).timeout
	var t0 = Time.get_ticks_usec()
	if level >= 0:
		game.start_level(level)
	else:
		game.start_pve()
	# Without the HUD, to see what the interface alone costs.
	if args.has("nohud"):
		game.hud.visible = false
	# lights=N caps the impact lamps, to see what they cost.
	for arg in args:
		if arg.begins_with("lights="):
			game.arena.light_override = int(arg.substr(7))
	print("BENCH build_ms=", (Time.get_ticks_usec() - t0) / 1000.0)
	for quality in [2, 1, 0]:
		game.video.configure(60, quality, false, false)
		game.video.apply(root, game.arena)
		game.rules.phase = "play"
		for i in range(20):
			await process_frame
		var draws = 0.0
		var prims = 0.0
		var objects = 0.0
		var cpu = 0.0
		var worst = 0.0
		var frames = 90
		for i in range(frames):
			var start = Time.get_ticks_usec()
			game._physics_process(1.0 / 60.0)
			await process_frame
			var spent = (Time.get_ticks_usec() - start) / 1000.0
			cpu += spent
			worst = maxf(worst, spent)
			draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		print("BENCH quality=%d draws=%d primitives=%d objects=%d frame_ms=%.1f worst_ms=%.1f" % [quality, draws / frames, prims / frames, objects / frames, cpu / frames, worst])
	quit()
