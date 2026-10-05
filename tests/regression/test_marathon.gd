extends SceneTree
# MARATONA: rival after rival, each in its own arena and a little sharper, until the first
# defeat; the best run is kept as the record and shown on the lobby card.
const Marathon = preload("res://scripts/progression/marathon.gd")

func _initialize() -> void:
	call_deferred("run")

func finish(game, won: bool) -> void:
	game.rules.scores = [2, 0] if won else [0, 2]
	game.rules.winner = 0 if won else 1
	game.rules.phase = "finished"

func run() -> void:
	# The run itself: every robot once before any repeats, a new order after eleven.
	var unit = Marathon.new()
	unit.path = "user://marathon-unit.cfg"
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	unit.start(rng)
	var seen: Dictionary = {}
	for i in range(11):
		seen[unit.rival()] = true
		unit.advance(rng)
	assert(seen.size() == 11 and not seen.has(0), "eleven different rivals, never BIT")
	var first_of_cycle = unit.rival()
	assert(first_of_cycle >= 1 and first_of_cycle <= 11)
	# The AI tightens past the eleventh round, never below the floor.
	unit.round_number = 11
	var at_eleven: float = unit.ai_profile(1).fire_gap
	unit.round_number = 40
	assert(unit.ai_profile(1).fire_gap < at_eleven and unit.ai_profile(1).fire_gap >= at_eleven * Marathon.LATE_FLOOR - 0.0001)
	unit.round_number = 1
	assert(unit.ai_profile(1).fire_gap > at_eleven, "the first round is the gentlest")
	assert(unit.kit(rng).size() == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(unit.path))

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.marathon.path = "user://marathon-test.cfg"
	game.marathon.record = 0
	assert(game.hud.lobby.MODES.any(func(m): return m.id == "marathon"), "the lobby offers MARATONA")
	game.hud.lobby.mode_id = "marathon"
	game.hud.play_chosen_mode()
	await process_frame
	assert(game.mode == "pve" and game.marathon_live() and game.hud.level_info.number == 1)
	var first_rival: int = game.marathon.rival()
	assert(game.arena.unit_skins[1] == first_rival and game.level_index == -1)
	finish(game, true)
	await create_timer(0.2).timeout
	assert(game.hud.level_result == "won" and game.marathon.wins == 1 and game.marathon.record == 1)
	game.hud.update_match(game.rules, "")
	assert(game.hud.next_button.visible and not game.hud.replay.visible and not game.hud.levels_button.visible)
	game.hud.next_level_requested.emit()
	await process_frame
	assert(game.hud.level_info.number == 2 and game.marathon.rival() != first_rival and game.rules.phase == "countdown")
	finish(game, false)
	await create_timer(0.2).timeout
	assert(game.hud.level_result == "lost" and not game.marathon.active and game.marathon.record == 1)
	game.hud.update_match(game.rules, "")
	assert(game.hud.replay.visible and game.hud.replay.text == "NOVA MARATONA" and not game.hud.next_button.visible)
	var saved = ConfigFile.new()
	assert(saved.load(game.marathon.path) == OK and int(saved.get_value("marathon", "record", 0)) == 1, "the record is saved")
	assert(game.hud.marathon_record == 1)
	game.replay()
	await process_frame
	assert(game.marathon.active and game.hud.level_info.number == 1 and game.marathon.wins == 0, "a new run starts at round one")
	# Another mode takes the screen: the run is no longer live.
	game.start_pve()
	assert(not game.marathon_live())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.marathon.path))
	game.queue_free()
	await process_frame
	await process_frame
	print("PASS MARATHON: rounds, rivals, rising AI, record, buttons")
	quit()
