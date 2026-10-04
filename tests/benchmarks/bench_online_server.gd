extends SceneTree
# How much server time one online match costs: a match played by two firing, moving
# pilots, stepped at 60 Hz with a snapshot every third tick, as the server does.
const Rules = preload("res://scripts/gameplay/arena_rules.gd")

func _initialize() -> void:
	var rules = Rules.new()
	rules.set_map(Rules.pvp_map())
	rules.loadouts = [["blast", "air", "meteors"], ["rapid", "laser", "thunder"]]
	rules.reset_match()
	var ticks = 60 * 120
	var started = Time.get_ticks_usec()
	for i in range(ticks):
		var sway = Vector2(1 if (i / 90) % 2 == 0 else -1, 0)
		var commands = [{"move": sway, "fire": true, "manual": false, "power": (i / 600) % 3 if i % 600 == 0 else -1},
			{"move": -sway, "fire": true, "manual": false, "power": (i / 700) % 3 if i % 700 == 0 else -1}]
		rules.step(1.0 / 60.0, commands)
		if rules.phase == "finished":
			rules.reset_match()
		if i % 3 == 0:
			var packet = rules.network_snapshot()
			var bytes = var_to_bytes(packet)
			if i == 300:
				print("SNAPSHOT_BYTES ", bytes.size())
	var elapsed = (Time.get_ticks_usec() - started) / 1000000.0
	print("MATCH_SECONDS_SIMULATED ", ticks / 60.0, " CPU_SECONDS ", elapsed, " CPU_SHARE_PER_MATCH ", elapsed / (ticks / 60.0))
	quit()
