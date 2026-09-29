extends SceneTree
# 3 contra 3: six robots play each other on the squad map, headless. Checks the arena is laid
# out right (300 bricks a side, three rails a base clear of the walls and the bricks), that the
# pilots break bricks with ricochets and score, and what a tick costs.
# Usage: godot --headless -s tests/test_squad.gd [-- <seconds of play>]
const Rules = preload("res://scripts/arena_rules.gd")
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var seconds: float = float(args[0]) if args.size() > 0 else 240.0
	var rules = Rules.new()
	rules.set_map(Rules.squad_map())
	check(rules.players.size() == 6, "Six pilots on the squad map")
	check(rules.brick_count(0) == 300 and rules.brick_count(1) == 300, "300 bricks a side (%d, %d)" % [rules.brick_count(0), rules.brick_count(1)])
	check(is_equal_approx(Rules.HALF_LENGTH, Rules.BASE_HALF_LENGTH * 2.7), "Twice the PvP arena's length")
	var outline: Array = rules.walls
	# Every rail clear of the walls and of its own bricks, end to end.
	var clear = true
	for index in range(6):
		var limit: float = rules.pilot_limit(index)
		for step in range(21):
			var at: Vector2 = rules.pilot_position(index, lerpf(-limit, limit, step / 20.0))
			if not Rules.point_inside(outline, at):
				clear = false
			for i in range(outline.size()):
				var closest = Geometry2D.get_closest_point_to_segment(at, outline[i], outline[(i + 1) % outline.size()])
				if at.distance_to(closest) < 0.6:
					clear = false
			for brick in rules.bricks:
				if brick.p.distance_to(at) < 0.9:
					clear = false
	check(clear, "The three rails of each base clear the walls and the bricks")
	# Six robots, one tick at a time.
	var dt = 1.0 / 60.0
	var ticks = int(seconds / dt)
	var bounces = 0
	var boosts = 0
	var broken = [0, 0]
	var goals = 0
	var shots = [0, 0, 0, 0, 0, 0]
	var busiest = 0
	var worst = 0
	var total_usec = 0
	var first_goal = -1.0
	for tick in range(ticks):
		var begin = Time.get_ticks_usec()
		var commands: Array = []
		for index in range(6):
			commands.append(rules.squad_command(index))
		rules.step(dt, commands)
		var spent = Time.get_ticks_usec() - begin
		total_usec += spent
		worst = maxi(worst, spent)
		busiest = maxi(busiest, rules.balls.size())
		for event in rules.events:
			match event.kind:
				"bounce":
					bounces += 1
				"boost":
					boosts += 1
				"brick":
					broken[event.team] += 1
				"shot":
					shots[int(event.get("pilot", event.team))] += 1
				"goal":
					goals += 1
					if first_goal < 0:
						first_goal = tick * dt
					print("GOAL team %d at %.1fs (score %s)" % [event.team, tick * dt, str(rules.scores)])
		if rules.phase == "finished":
			print("Match over at %.1fs, winner %d" % [tick * dt, rules.winner])
			break
		if tick % 1800 == 0:
			print("t=%.0fs bricks %d / %d, balls %d" % [tick * dt, rules.brick_count(0), rules.brick_count(1), rules.balls.size()])
	print("Shots per pilot: %s" % str(shots))
	print("Bricks broken: %s, ricochets %d, boosts %d, most shots in the air %d" % [str(broken), bounces, boosts, busiest])
	print("Tick: %.2f ms average, %.2f ms worst" % [total_usec / 1000.0 / maxi(ticks, 1), worst / 1000.0])
	for index in range(6):
		check(shots[index] > 0, "Pilot %d fires" % index)
	check(broken[0] + broken[1] > 60, "The robots break bricks")
	check(bounces > 100, "Shots ricochet round the arena")
	check(goals > 0 or seconds < 200, "Someone scores (first at %.1fs)" % first_goal)
	print("SQUAD_RESULT failures=%d" % failures)
	quit(failures)
