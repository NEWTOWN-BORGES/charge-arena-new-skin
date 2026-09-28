extends SceneTree
# Looking at the maps of the quick match and coming back leaves the lobby's pilots standing.
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
	await create_timer(0.5).timeout
	var lobby_map = String(game.arena.map.get("id", ""))
	game.hud.map_previewed.emit("abismo_neon")
	await process_frame
	check(String(game.arena.map.get("id", "")) != lobby_map, "The picker tours another world")
	game.hud.map_picker_closed.emit()
	await process_frame
	check(String(game.arena.map.get("id", "")) == lobby_map, "Back in the lobby, its own map is back")
	check(game.arena.units.all(func(u): return is_instance_valid(u) and u.visible), "and its pilots stand on it")
	print("MAP_PICKER_LOBBY_RESULT failures=%d" % failures)
	quit(failures)
