extends SceneTree
# Firing on the joystick is the default, old saves move to it once, and the match tutorial
# teaches it and where to change it.
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var Settings = load("res://scripts/game_settings.gd")
	var fresh = Settings.new()
	check(fresh.fire_control == 1 and not fresh.auto_fire, "A new player fires on the joystick")
	var path = "user://fire-default-test.cfg"
	var old = ConfigFile.new()
	old.set_value("game", "fire_default", 2)
	old.set_value("game", "fire_control", 0)
	old.save(path)
	var moved = Settings.new()
	moved.config_path = path
	moved.load_preferences()
	check(moved.fire_control == 1 and not moved.auto_fire, "An old save moves to joystick fire once")
	moved.fire_control = 0
	moved.save_preferences()
	var kept = Settings.new()
	kept.config_path = path
	kept.load_preferences()
	check(kept.fire_control == 0, "A choice made after that is kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.hud.fire_control = 1
	game.hud.auto_fire = false
	var titles = game.hud.match_steps().map(func(s): return String(s.title))
	check(titles.has("Disparar no joystick") and titles.has("Mudar o disparo"), "The match tutorial teaches joystick fire and where to change it")
	print("FIRE_DEFAULT_RESULT failures=%d" % failures)
	quit(failures)
