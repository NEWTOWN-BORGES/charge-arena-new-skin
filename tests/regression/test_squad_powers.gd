extends SceneTree
# 3 contra 3 with powers: all six robots fire their abilities and ultimates on the squad
# arena, headless, through every ultimate in the game, without an error.
# Usage: godot --headless -s tests/regression/test_squad_powers.gd
const Rules = preload("res://scripts/gameplay/arena_rules.gd")
const ULTIMATES = [["thunder", "sun_ray"], ["volley", "meteors"], ["bloom", "plating"], ["singularity", "sentries"], ["surge", "plunder"], ["b_forge", "sun_beam"]]
var failures = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for pair in ULTIMATES:
		var rules = Rules.new()
		rules.set_map(Rules.squad_map())
		rules.loadouts = [["rapid", "walls", pair[0]], ["blast", "mirror", pair[1]]]
		var used = {}
		var dt = 1.0 / 60.0
		for tick in range(int(30.0 / dt)):
			if tick % 600 == 0:
				for team in range(2):
					for slot in range(3):
						rules.powers[team].charge[slot] = maxi(rules.power_charge_cost(team, slot), 0)
				for index in range(2, 6):
					rules.players[index].charge = [99, 99, 99]
			var commands: Array = []
			for index in range(6):
				commands.append(rules.squad_command(index))
			rules.step(dt, commands)
			for event in rules.events:
				if event.kind == "power":
					used[String(event.get("id", "?"))] = true
			if rules.phase != "play":
				rules.phase = "play"
		print("%s: used %s, bricks %d / %d" % [str(pair), str(used.keys()), rules.brick_count(0), rules.brick_count(1)])
		if used.size() < 4:
			failures += 1
			push_error("Too few powers used with %s" % str(pair))
	# Random kits, as the menu deals them: every ability in the game gets its turn.
	var abilities = ["blast", "rapid", "air", "laser", "pierce", "sniper", "cluster", "ricochet", "mortar", "drain", "emp", "walls", "mirror", "weld", "freeze", "stun", "thorns", "dome", "slow", "immune", "magnet", "rebuild", "sponge", "ghost"]
	for round_index in range(4):
		var rules = Rules.new()
		rules.set_map(Rules.squad_map())
		var kits: Array = []
		for k in range(6):
			kits.append([abilities[(round_index * 12 + k * 2) % abilities.size()], abilities[(round_index * 12 + k * 2 + 1) % abilities.size()], ULTIMATES[k % 6][round_index % 2]])
		rules.loadouts = [kits[0], kits[1]]
		rules.squad_kits = kits.slice(2)
		rules.reset_match()
		var used = {}
		for tick in range(int(25.0 * 60)):
			if tick % 600 == 0:
				for team in range(2):
					rules.powers[team].charge = [99, 99, 99]
				for index in range(2, 6):
					rules.players[index].charge = [99, 99, 99]
			var commands: Array = []
			for index in range(6):
				commands.append(rules.squad_command(index))
			rules.step(1.0 / 60.0, commands)
			for event in rules.events:
				if event.kind == "power":
					used[String(event.get("id", "?"))] = true
			if rules.phase != "play":
				rules.phase = "play"
		print("random kits %d: used %s" % [round_index, str(used.keys())])
	print("SQUAD_POWERS_RESULT failures=%d" % failures)
	quit(failures)
