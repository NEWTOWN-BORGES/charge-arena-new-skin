extends SceneTree
# The second shelf of the shop: six attacks and four defences, each an answer to something.
# Headless, on the rules alone: what each one does, what it counters, and that the network
# snapshot carries its state.
const Rules = preload("res://scripts/arena_rules.gd")
const Powers = preload("res://scripts/powers.gd")
var failures = 0
var idle = {"move": Vector2.ZERO, "fire": false}

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func playing(kit: Array, rival: Array = ["blast", "air", "sun_ray"]):
	var r = Rules.new()
	r.phase = "play"
	r.loadouts = [kit.duplicate(), rival.duplicate()]
	for team in range(2):
		for slot in range(3):
			r.powers[team].charge[slot] = 99
	return r

func first_brick(r, team: int) -> int:
	for i in range(r.bricks.size()):
		if r.bricks[i].team == team and r.bricks[i].alive:
			return i
	return -1

func wall_health(r, team: int) -> int:
	var total = 0
	for brick in r.bricks:
		if brick.team == team:
			total += brick.hp
	return total

func run() -> void:
	var attacks = Powers.CATALOG.filter(func(e): return e.id in ["sniper", "cluster", "drain", "ricochet", "emp", "mortar"])
	var defences = Powers.CATALOG.filter(func(e): return e.id in ["dome", "slow", "sponge", "immune"])
	check(attacks.size() == 6 and attacks.all(func(e): return e.kind == "ataque"), "Six new attacks in the shop")
	check(defences.size() == 4 and defences.all(func(e): return e.kind == "defesa"), "Four new defences in the shop")

	# TIRO CERTEIRO: fast, three lives, no ricochet.
	var r = playing(["sniper", "cluster", "b_charge"])
	check(r.activate_power(0, 0), "The marksman's shot fires")
	var round = r.balls.back()
	check(round.power == 4 and round.damage == Rules.SNIPER_DAMAGE and round.v.length() > Rules.BALL_SPEED * 2.0 and round.bounces == Rules.MAX_BOUNCES, "It flies twice as fast, takes three lives and never ricochets")

	# FRAGMENTAÇÃO: bursts into shards on the first thing it touches.
	r = playing(["cluster", "sniper", "b_charge"])
	r.activate_power(0, 0)
	var shell = r.balls.back()
	check(shell.power == 5 and shell.v.length() < Rules.BALL_SPEED, "The cluster shell is a slow round")
	r.cluster_burst(shell)
	check(r.balls.filter(func(b): return b.power == 7).size() == Rules.CLUSTER_SHARDS, "It breaks into six shards")

	# DRENO: steals ultimate charge and breaks a wind-up.
	r = playing(["drain", "sniper", "b_charge"])
	r.activate_power(1, 2)
	check(r.powers[1].ultimate_windup > 0, "The rival starts winding up its ultimate")
	r.powers[1].charge[2] = 6
	r.powers[0].charge[2] = 0
	r.activate_power(0, 0)
	check(r.powers[1].ultimate_windup == 0 and r.powers[1].charge[2] == 6 - Rules.DRAIN_STEAL and r.powers[0].charge[2] == Rules.DRAIN_STEAL, "The drain breaks the wind-up and moves four charge across")

	# RICOCHETE: four extra ricochets, then two lives a hit.
	r = playing(["ricochet", "sniper", "b_charge"])
	r.activate_power(0, 0)
	check(r.balls.back().power == 6 and r.balls.back().bounces == -Rules.RICOCHET_EXTRA, "The ricochet round has four bounces to spare")

	# PULSO EMP: switches off the rival's buffs and sets its kit back.
	r = playing(["emp", "sniper", "b_charge"], ["mirror", "walls", "sun_ray"])
	r.powers[1].mirror_time = 3.0
	r.powers[1].dome_time = 3.0
	r.powers[1].cool[0] = 0.0
	r.activate_power(0, 0)
	check(r.powers[1].mirror_time == 0 and r.powers[1].dome_time == 0 and r.powers[1].cool[0] >= Rules.EMP_DELAY, "The EMP turns off the mirror and the dome and sets the rival's kit back")

	# MORTEIRO: over the mirror, onto the wall.
	r = playing(["mortar", "sniper", "b_charge"])
	r.powers[1].mirror_time = 5.0
	var before = wall_health(r, 1)
	r.activate_power(0, 0)
	for f in range(70):
		r.step(1.0 / 60.0, [idle, idle])
	var after = wall_health(r, 1)
	check(after < before, "The mortar lands behind a raised mirror and takes lives (%d -> %d)" % [before, after])

	# CÚPULA: like every shield, it takes 45% of what an ultimate throws at the wall.
	r = playing(["dome", "sniper", "b_charge"])
	r.activate_power(0, 0)
	var target = first_brick(r, 0)
	var hp = r.bricks[target].hp
	r.sky_hit(1, "meteor", 2, 0.6, r.bricks[target].p)
	check(hp - r.bricks[target].hp == 1, "A meteor on a domed wall takes 1 of its 2 (%d)" % (hp - r.bricks[target].hp))
	r.powers[0].dome_time = 0.0
	r.sky_hit(1, "meteor", 2, 0.6, r.bricks[target].p)
	check(r.bricks[target].hp < hp, "Without the dome the same meteor bites")

	# CAMPO LENTO: rounds crawl through the defended half.
	r = playing(["slow", "sniper", "b_charge"])
	r.activate_power(0, 0)
	r.balls.clear()
	r.spawn_ball(1, Vector2(1, 0), 0)
	var shot = r.balls.back()
	shot.p = Vector2(0, 1.0 * signf(r.players[0].p.y))
	var from = shot.p
	r.step(1.0 / 60.0, [idle, idle])
	var slow_travel = shot.p.distance_to(from)
	check(slow_travel < Rules.BALL_SPEED / 60.0 * 0.6, "A rival round in the slowed half moves at half speed (%.3f)" % slow_travel)

	# ESPONJA: rounds are swallowed and turned into charge.
	r = playing(["sponge", "sniper", "b_charge"])
	r.activate_power(0, 0)
	r.powers[0].charge = [0, 0, 0]
	var sponge_brick = first_brick(r, 0)
	var sponge_hp = r.bricks[sponge_brick].hp
	r.balls.clear()
	r.spawn_ball(1, Vector2(1, 0), 0)
	var soaked = r.balls.back()
	var brick_p: Vector2 = r.bricks[sponge_brick].p
	soaked.p = brick_p + Vector2(0, -0.9 * signf(brick_p.y))
	soaked.v = (brick_p - soaked.p).normalized() * Rules.BALL_SPEED
	for f in range(10):
		r.step(1.0 / 60.0, [idle, idle])
	check(r.bricks[sponge_brick].hp == sponge_hp and r.powers[0].charge[0] >= 1, "The sponge swallows the round and charges the kit")

	# IMUNIDADE: shakes off frost and daze, and nothing puts it down again.
	r = playing(["immune", "sniper", "b_charge"], ["freeze", "stun", "sun_ray"])
	r.powers[0].freeze_time = 3.0
	r.activate_power(0, 0)
	check(r.powers[0].freeze_time == 0 and r.powers[0].immune_time > 0, "Immunity clears the frost")
	r.activate_power(1, 0)
	r.activate_power(1, 1)
	check(r.powers[0].freeze_time == 0 and r.players[0].stun == 0, "Frost and the shock pulse do nothing to an immune pilot")

	# The network carries the new state.
	r = playing(["dome", "slow", "b_charge"])
	r.activate_power(0, 0)
	r.activate_power(0, 1)
	var copy = playing(["dome", "slow", "b_charge"])
	check(copy.apply_network_snapshot(r.network_snapshot()) and copy.powers[0].dome_time > 0 and copy.powers[0].slow_time > 0, "The online snapshot carries dome and slow field")
	print("SECOND_SHELF_RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
