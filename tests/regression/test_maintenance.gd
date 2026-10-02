extends SceneTree
const Video = preload("res://scripts/settings/video_settings.gd")
const Rules = preload("res://scripts/gameplay/arena_rules.gd")
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check("ChargeArenaQA" in OS.get_user_data_dir(), "Regression saves are isolated")
	for quality in range(3):
		check(Video.antialiasing(quality, true) <= Viewport.MSAA_2X, "Mobile AA stays within its budget: %d" % quality)
		check(Video.antialiasing(quality, false) == Video.AA_LEVELS[quality], "Desktop profile remains explicit: %d" % quality)
	var settings = Video.new()
	settings.configure(60, 2, true, false, 1)
	settings.save_preferences("user://video-test.cfg")
	var restored = Video.new()
	restored.load_preferences("user://video-test.cfg")
	check(restored.shadows, "The saved shadow preference survives a reload")
	# Every new projectile must travel across the same wire format as the original shots.
	var host = Rules.new()
	var client = Rules.new()
	for kind in range(Rules.PROJECTILE_KINDS):
		host.balls.clear()
		host.spawn_ball(0, Vector2.UP, kind, 1)
		check(client.apply_network_snapshot(host.network_snapshot()) and client.balls[0].power == kind, "Projectile kind %d survives network serialization" % kind)
	var before = client.snapshot().duplicate(true)
	for kind in [-1.0, 1.5, 8.0]:
		var bad = host.network_snapshot()
		bad.b[10] = kind
		check(not client.apply_network_snapshot(bad) and client.snapshot() == before, "Invalid kind %s leaves match untouched" % kind)
	for field in ["p", "h", "b", "m", "w", "t"]:
		var bad = host.network_snapshot()
		bad[field] = "invalid"
		check(not client.apply_network_snapshot(bad) and client.snapshot() == before, "Invalid packet field %s is rejected without a partial update" % field)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_pve()
	game.rules.phase = "play"
	root.msaa_3d = Viewport.MSAA_2X
	game.idle_frame_rate()
	check(root.msaa_3d == Viewport.MSAA_2X, "The frame limiter does not overwrite antialiasing")
	game.hud.open_skins()
	check(game.hud.viewer_viewport.msaa_3d <= Viewport.MSAA_4X, "The gallery no longer forces 8x")
	game.hud.close_skins()
	# Excess events and stale commands cannot cross a session boundary.
	var events: Array = []
	for i in range(180): events.append({"kind": "bounce", "p": Vector2.ZERO, "team": 0})
	game.queue_network_events(events)
	check(game.pending_events.size() == game.MAX_PENDING_EVENTS, "A single burst respects the event packet budget")
	game.network_tick = 0.04
	game.close_network()
	check(game.pending_events.is_empty() and game.network_tick == 0.0, "Disconnect clears unsent effects and packet timer")
	for mode in ["pve", "host", "client"]:
		game.mode = mode
		game.connected = mode != "pve"
		game.pve_paused = false
		game.held_power = 0
		game.queue_shot(0)
		game.hud.move_vector = Vector2.RIGHT
		var elapsed: float = game.rules.elapsed
		game.go_background(true)
		game.go_background(true)
		for i in range(60): game._physics_process(1.0 / 60.0)
		game._process(0.5)
		check(game.rules.elapsed == elapsed and game.process_mode == Node.PROCESS_MODE_DISABLED, "%s stops simulation and descendants in background" % mode)
		check(game.hud.move_vector == Vector2.ZERO and game.held_power == -1 and game.queued_shots == [0, 0], "%s clears held controls" % mode)
		game.go_background(false)
		check(not AudioServer.is_bus_mute(0), "%s restores audio after duplicate pause notifications" % mode)
	AudioServer.set_bus_mute(0, true)
	game.go_background(true)
	game.go_background(false)
	check(AudioServer.is_bus_mute(0), "Returning does not unmute a previously muted master bus")
	AudioServer.set_bus_mute(0, false)
	# Deferred calls on an old arena used to access a camera outside the tree.
	var detached = game.ArenaView.new()
	detached.camera = Camera3D.new()
	detached.add_child(detached.camera)
	detached.warm_shaders()
	check(not is_instance_valid(detached.warm_root), "Detached arena warmup safely does nothing")
	detached.free()
	game.close_network()
	game.queue_free()
	await process_frame
	await process_frame
	print("MAINTENANCE_RESULT failures=", failures)
	quit(failures)
