extends RefCounted
# MARATONA: one rival after another until the first defeat. Each round brings a robot
# from the cast (all eleven before any repeats), in its own arena, a little sharper than
# the last; the best run is kept as the record.

const Campaign = preload("res://scripts/progression/campaign.gd")
const CAST = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
# Two abilities drawn at random for each rival, from the same pool as the 3 v 3 arena.
const ABILITIES = ["blast", "rapid", "air", "laser", "pierce", "sniper", "cluster", "ricochet", "mortar", "drain", "emp", "walls", "mirror", "weld", "freeze", "stun", "thorns", "dome", "slow", "immune", "magnet", "rebuild", "sponge", "ghost"]
# Past the eleventh round the AI keeps tightening, down to this share of its gaps.
const LATE_FLOOR = 0.6
const LATE_STEP = 0.94

var path = "user://marathon.cfg"
var record = 0
var runs = 0
var round_number = 0
var wins = 0
var cast: Array = []
var active = false

func load_record() -> void:
	var config = ConfigFile.new()
	if config.load(path) == OK:
		record = int(config.get_value("marathon", "record", 0))
		runs = int(config.get_value("marathon", "runs", 0))

func save_record() -> int:
	var config = ConfigFile.new()
	config.set_value("marathon", "record", record)
	config.set_value("marathon", "runs", runs)
	return config.save(path)

func start(rng: RandomNumberGenerator = null) -> void:
	active = true
	round_number = 1
	wins = 0
	cast = shuffled(CAST, rng)
	runs += 1

func shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var out = items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j = rng.randi_range(0, i) if rng != null else randi_range(0, i)
		var swap = out[i]
		out[i] = out[j]
		out[j] = swap
	return out

# The robot of the current round.
func rival() -> int:
	return int(cast[(round_number - 1) % CAST.size()])

# The arena the rival plays at home in.
static func level_of(boss: int) -> int:
	for i in range(Campaign.LEVELS.size()):
		if not Campaign.is_minor(i) and int(Campaign.LEVELS[i].boss) == boss:
			return i
	return Campaign.LEVELS.size() - 1

# The AI climbs the campaign's curve one step per round, then keeps tightening.
func ai_profile(difficulty: int) -> Dictionary:
	# The eleven headline levels (stations left out) are the eleven steps.
	var steps: Array = Campaign.menu_levels()
	var profile: Dictionary = Campaign.ai_profile(steps[mini(round_number - 1, steps.size() - 1)], difficulty)
	var late = round_number - steps.size()
	if late > 0:
		var scale = maxf(LATE_FLOOR, pow(LATE_STEP, late))
		for key in ["fire_gap", "power_gap", "ultimate_wait", "charge_tick", "ultimate_gap"]:
			profile[key] = float(profile[key]) * scale
	return profile

func kit(rng: RandomNumberGenerator = null) -> Array:
	var pool = shuffled(ABILITIES, rng)
	return [pool[0], pool[1]]

# The match is over: a win moves to the next round, a defeat ends the run. Returns
# true when the record was beaten.
func finish(won: bool) -> bool:
	if won:
		wins += 1
	var beaten = wins > record
	if beaten:
		record = wins
	if not won:
		active = false
	save_record()
	return beaten

func advance(rng: RandomNumberGenerator = null) -> void:
	round_number += 1
	if (round_number - 1) % CAST.size() == 0:
		# Every eleven rounds a new order, never the same robot twice in a row.
		var last = cast[-1]
		cast = shuffled(CAST, rng)
		if cast[0] == last:
			cast.reverse()
