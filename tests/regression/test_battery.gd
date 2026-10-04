extends SceneTree
# Battery: out of sight the game stops; a still menu dozes; only a live match keeps the
# screen awake.
var failures = 0

func check(ok: bool, text: String) -> void:
	if ok:
		print("PASS: ", text)
	else:
		failures += 1
		push_error("FAIL: " + text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	check(Engine.max_fps == game.IDLE_FPS, "The menu paints at %d FPS (%d)" % [game.IDLE_FPS, Engine.max_fps])
	check(not game.screen_kept_on, "The menu lets the phone switch the screen off")
	game.last_input_ms = Time.get_ticks_msec() - int(game.DOZE_SECONDS * 1000.0) - 100
	await process_frame
	await process_frame
	check(Engine.max_fps == game.DOZE_FPS, "Left alone, the menu dozes at %d FPS (%d)" % [game.DOZE_FPS, Engine.max_fps])
	game.start_pve()
	game.last_input_ms = Time.get_ticks_msec()
	await create_timer(0.3).timeout
	check(Engine.max_fps == game.video.runtime_fps, "A live match runs at the chosen rate (%d)" % Engine.max_fps)
	check(game.screen_kept_on, "A live match keeps the screen awake")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await process_frame
	check(game.pve_paused, "Going to the background pauses the match")
	check(AudioServer.is_bus_mute(0), "Going to the background silences everything")
	check(Engine.max_fps == game.BACKGROUND_FPS, "In the background it runs at one frame a second")
	check(not game.screen_kept_on, "In the background it does not keep the screen on")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await process_frame
	await process_frame
	check(not AudioServer.is_bus_mute(0), "Coming back, the sound returns")
	check(Engine.max_fps == game.IDLE_FPS, "Coming back to a paused match it paints at the resting rate (%d)" % Engine.max_fps)
	# Battery saver: 30 FPS and the light picture in a match, remembered, and the earlier
	# choices come back when it is switched off.
	var chosen_fps: int = game.video.fps
	var chosen_quality: int = game.video.quality
	game.hud.battery_choice.button_pressed = true
	game.start_pve()
	game.last_input_ms = Time.get_ticks_msec()
	await create_timer(0.3).timeout
	check(Engine.max_fps == 30, "Battery saver: a match runs at 30 FPS (%d)" % Engine.max_fps)
	check(game.arena.quality_level == 0 and game.video.effective_quality() == 0, "Battery saver: the light picture")
	check(game.video.fps == chosen_fps and game.video.quality == chosen_quality, "Battery saver keeps the player's own choices")
	var saved = ConfigFile.new()
	saved.load(game.video.CONFIG_PATH)
	check(bool(saved.get_value("video", "battery_saver", false)), "Battery saver is remembered")
	game.hud.battery_choice.button_pressed = false
	await create_timer(0.3).timeout
	check(Engine.max_fps == game.video.fps, "Switched off, the chosen rate returns (%d)" % Engine.max_fps)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.video.CONFIG_PATH))
	print("BATTERY_RESULT failures=%d" % failures)
	quit(1 if failures else 0)
