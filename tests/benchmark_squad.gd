extends SceneTree
# What the 3 v 3 arena costs a tick: six robots planning and the shots in the air (headless).
# Usage: godot --headless -s tests/benchmark_squad.gd
const Rules = preload("res://scripts/arena_rules.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rules = Rules.new()
	rules.set_map(Rules.squad_map())
	var dt = 1.0 / 60.0
	var ai_us = 0
	var step_us = 0
	var forecasts = 0
	for tick in range(3600):
		var t0 = Time.get_ticks_usec()
		var commands: Array = []
		for index in range(6):
			commands.append(rules.squad_command(index))
		var t1 = Time.get_ticks_usec()
		rules.step(dt, commands)
		var t2 = Time.get_ticks_usec()
		ai_us += t1 - t0
		step_us += t2 - t1
	print("AI %.2f ms/tick, step %.2f ms/tick" % [ai_us / 3600000.0, step_us / 3600000.0])
	# One forecast alone.
	var t = Time.get_ticks_usec()
	for i in range(200):
		rules.squad_forecast(2, randf_range(-1, 1), 0.0)
	print("forecast %.3f ms" % ((Time.get_ticks_usec() - t) / 200000.0))
	quit(0)
