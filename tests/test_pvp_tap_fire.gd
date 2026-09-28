extends SceneTree
# PvP: the guest's taps fire at the same quick manual cadence as the host's own.
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else: print("PASS: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.mode = "host"
	game.connected = true
	game.local_team = 0
	game.remote_age = 0.0
	game.rules.phase = "play"
	var guest = 1
	game.rules.players[guest].cooldown = 0.0
	game.rules.players[guest].stun = 0.0
	game.queue_shot(guest)
	game._physics_process(1.0 / 60.0)
	var Rules = load("res://scripts/arena_rules.gd")
	check(game.rules.players[guest].cooldown <= Rules.TAP_INTERVAL + 0.001, "A guest's tap reloads as quickly as a host's tap (%.2f s)" % game.rules.players[guest].cooldown)
	print("PVP_TAP_RESULT failures=%d" % failures)
	quit(failures)
