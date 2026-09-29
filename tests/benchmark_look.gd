extends SceneTree
# Wall-clock frame time of a live match in one look, with parts of it switched off: on a
# software renderer the time follows the pixel work, so it ranks what the look costs.
# Usage: godot -s tests/benchmark_look.gd -- <style or "atual"> <world> <quality> [off,...]
const Rules = preload("res://scripts/arena_rules.gd")
const ArtStyle = preload("res://scripts/art_style.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	ArtStyle.current = "" if args[0] == "atual" else args[0]
	if args.size() > 3:
		ArtStyle.off = Array(args[3].split(","))
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/style-preview.tmp"
	game.game_settings.tutorial_match = true
	await create_timer(0.3).timeout
	game.video.configure(90, int(args[2]), false, false)
	game.video.apply(root, game.arena)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.start_pve(Rules.quick_map(args[1]))
	game.pve_paused = false
	await create_timer(0.8).timeout
	game.rules.phase = "play"
	for i in range(30):
		await process_frame
	var t0 = Time.get_ticks_usec()
	var frames = 60
	for i in range(frames):
		await process_frame
	var ms = (Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("LOOK %s %s q%s off=%s ms=%.2f prims=%d draws=%d" % [args[0], args[1], args[2], ",".join(ArtStyle.off), ms, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
