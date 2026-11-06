extends SceneTree
# Test that Marathon Mode properly randomizes both the opponent (and their powers)
# and the player's character (selected from unlocked skins including neon skins) and their powers.

const Skins = preload("res://scripts/progression/skins.gd")
const Marathon = preload("res://scripts/progression/marathon.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Simulate player having unlocked some skins, including a neon skin (19: BATIDA NEON) and a boss (1: SALVO)
	game.skins.defeated = [1, 19] # Unlocks SALVO and BATIDA NEON, in addition to BIT (0)
	assert(game.skins.is_unlocked(0), "BIT is unlocked")
	assert(game.skins.is_unlocked(1), "SALVO is unlocked")
	assert(game.skins.is_unlocked(19), "BATIDA NEON is unlocked")
	assert(not game.skins.is_unlocked(5), "ECLIPSE is locked")

	# Test player skin picker: must only pick from [0, 1, 19]
	var picked_skins: Dictionary = {}
	for i in range(50):
		var s = game.marathon_pick_player_skin()
		assert(s in [0, 1, 19], "Picked skin must be an unlocked skin")
		picked_skins[s] = true
	assert(picked_skins.size() >= 2, "Random selection covers multiple unlocked skins")

	# Start marathon and check round setup
	game.start_marathon()
	await process_frame

	assert(game.marathon_live(), "Marathon is live")
	var p_skin = game.marathon_current_player_skin
	assert(p_skin in [0, 1, 19], "Current player skin is one of unlocked")
	assert(game.arena.unit_skins[0] == p_skin, "Arena player model matches randomized skin")

	var p_loadout = game.rules.loadouts[0]
	var r_loadout = game.rules.loadouts[1]
	assert(p_loadout.size() == 3, "Player has 3 powers")
	assert(r_loadout.size() == 3, "Rival has 3 powers")
	assert(p_loadout[0] in Marathon.ABILITIES, "Player power 0 is from ABILITIES pool")
	assert(p_loadout[1] in Marathon.ABILITIES, "Player power 1 is from ABILITIES pool")
	assert(r_loadout[0] in Marathon.ABILITIES, "Rival power 0 is from ABILITIES pool")
	assert(r_loadout[1] in Marathon.ABILITIES, "Rival power 1 is from ABILITIES pool")

	# Cleanup
	game.leave_campaign()
	assert(game.marathon_current_player_skin == -1, "Player skin reset after leaving marathon")
	game.queue_free()
	await process_frame

	print("PASS MARATHON RANDOMNESS: player unlocked skins + neon skins + random kits")
	quit(0)

