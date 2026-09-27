extends SceneTree
# The second shelf in a real match, each power fired and caught at three moments, with what
# it answers staged against it (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_abilities.gd -- <output prefix> [ids...]
const IDS = ["sniper", "cluster", "drain", "ricochet", "emp", "mortar", "dome", "slow", "sponge", "immune"]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-ability"
	var ids: Array = args.slice(1) if args.size() > 1 else IDS
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.5).timeout
	# Slow software frames would run the effects' clocks ahead: both loops go by hand.
	game.set_physics_process(false)
	game.set_process(false)
	game.hud.visible = false
	for id in ids:
		game.start_level(0)
		for f in range(12):
			game._process(1.0 / 60.0)
			await process_frame
		game.hud.visible = false
		var r = game.rules
		r.phase = "play"
		r.loadouts[0] = [id, r.loadouts[0][1], "sun_ray"]
		r.loadouts[1] = ["freeze", "stun", "meteors"]
		for team in range(2):
			for slot in range(3):
				r.powers[team].charge[slot] = 99
		if id == "drain":
			r.activate_power(1, 2)
			for f in range(20):
				game._physics_process(1.0 / 60.0)
				game._process(1.0 / 60.0)
				await process_frame
		if id == "emp":
			r.powers[1].mirror_time = 4.0
		# Fired as the player fires it: through the button, so the match plays its events.
		game.hud.request_power(0)
		# The mortar is caught landing, after its flight.
		var shots = {6: "a", 30: "b", 60: "c"} if id == "mortar" else {6: "a", 22: "b", 50: "c"}
		for f in range(64 if id == "mortar" else 56):
			if id == "sponge" and f % 6 == 0:
				r.spawn_ball(1, Vector2(randf_range(-0.3, 0.3), 1.0 if r.players[0].p.y > 0 else -1.0).normalized(), 0)
			if id == "dome" and f == 14:
				r.events.clear()
				for k in range(4):
					r.sky_strike(1, "meteor", 1, 0.4)
				game.play_events()
			if id == "immune" and f == 16:
				r.events.clear()
				r.activate_power(1, 0)
				r.activate_power(1, 1)
				game.play_events()
			game._physics_process(1.0 / 60.0)
			game._process(1.0 / 60.0)
			await process_frame
			if shots.has(f):
				await RenderingServer.frame_post_draw
				var path = "%s-%s-%s.png" % [prefix, id, shots[f]]
				print("ABILITY ", path, " ", root.get_texture().get_image().save_png(path))
	quit()
