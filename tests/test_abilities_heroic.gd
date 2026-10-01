extends SceneTree
## Cast every catalogue power through the real presentation pipeline. A graphics
## profile may change detail, but it must never change a match or leak effect cards.
const Rules = preload("res://scripts/arena_rules.gd")
const Powers = preload("res://scripts/powers.gd")
const Front = preload("res://scripts/combat_finish.gd")
var failures = 0
var casts = 0
var origin_cases = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else: print("PASS: ", message)

func chassis_center(arena, pilot: int) -> Vector3:
	# Measure the rendered armour itself, independently of the cast-origin API.
	var hull: MeshInstance3D = arena.units[pilot].get_node("Body/Robot_paint")
	return hull.to_global(hull.mesh.get_aabb().get_center())

func cast_effects(arena) -> Array:
	return arena.effects.filter(func(effect): return effect.has("cast_pilot") and effect.node.visible)

func body_origins(game, quality: int) -> void:
	game.start_squad(false)
	game.hud.hide()
	game.arena.guide_enabled = false
	game.video.configure(60, quality, false, false)
	game.video.apply(root, game.arena)
	game.rules.loadouts = [["blast", "air", "sun_ray"], ["blast", "air", "sun_ray"]]
	game.rules.squad_kits = [["blast", "air", "sun_ray"], ["blast", "air", "sun_ray"], ["blast", "air", "sun_ray"], ["blast", "air", "sun_ray"]]
	var positions_ok = true
	var selected_ok = true
	var followed_ok = true
	var windup_ok = true
	for pilot in range(6):
		var team = pilot % 2
		game.rules.reset_match()
		game.rules.phase = "play"
		for frame in range(260): game.arena.update_state(game.rules, 0, 1.0 / 60.0)
		game.rules.powers[team].charge = [99, 99, 99]
		if pilot >= 2: game.rules.players[pilot].charge = [99, 99, 99]
		game.rules.events.clear()
		check(game.rules.with_pilot(pilot, func(): return game.rules.activate_power(team, 0)), "Real ability activates for squad pilot %d at quality %d" % [pilot, quality])
		game.play_events()
		var marks = cast_effects(game.arena)
		selected_ok = selected_ok and marks.size() == 1 and int(marks[0].cast_pilot) == pilot
		if not marks.is_empty():
			positions_ok = positions_ok and marks[0].node.global_position.distance_to(chassis_center(game.arena, pilot)) < 0.001
		# A running cast follows the actual armour transform, including mesh offsets,
		# rotation/scale and the body's recoil, rather than the ground or the gun.
		var hull: MeshInstance3D = game.arena.units[pilot].get_node("Body/Robot_paint")
		var rest = hull.transform
		hull.position += Vector3(0.13, 0.16, -0.11)
		hull.scale *= Vector3(1.08, 0.94, 1.04)
		game.arena.update_state(game.rules, 0, 1.0 / 60.0)
		if not marks.is_empty():
			followed_ok = followed_ok and marks[0].node.global_position.distance_to(chassis_center(game.arena, pilot)) < 0.001
		hull.transform = rest
		# The same pilot charges and releases its own ultimate. The view can still
		# hold the previous frame's caster when the rules dispatch the release.
		game.rules.events.clear()
		check(game.rules.with_pilot(pilot, func(): return game.rules.activate_power(team, 2)), "Real ultimate activates for squad pilot %d at quality %d" % [pilot, quality])
		game.play_events()
		game.arena.update_state(game.rules, 0, 1.0 / 60.0)
		var seal: MeshInstance3D = game.arena.power_nodes[team].get_node("Windup/Seal")
		windup_ok = windup_ok and seal.is_visible_in_tree() and seal.global_position.distance_to(chassis_center(game.arena, pilot)) < 0.001
		game.arena.casters[team] = team
		game.rules.events.clear()
		game.rules.as_caster(team, func(): game.rules.step_ultimate(team, Rules.ULTIMATE_WINDUP + 0.01))
		# Another teammate can cast during this simulation step. The release event
		# must retain its actual pilot even when the team's running caster changes.
		game.rules.caster[team] = (pilot + 2) % 6
		game.play_events()
		marks = cast_effects(game.arena)
		var release = marks.back() if not marks.is_empty() else null
		selected_ok = selected_ok and release != null and int(release.cast_pilot) == pilot
		if release != null:
			positions_ok = positions_ok and release.node.global_position.distance_to(chassis_center(game.arena, pilot)) < 0.001
		origin_cases += 2
		await process_frame
	check(selected_ok, "Both leaders and all four companions retain their own cast and ultimate origin at quality %d" % quality)
	check(positions_ok, "Ability and ultimate activation are centred on the rendered body at quality %d" % quality)
	check(followed_ok, "Cast badges follow the animated body, including armour transforms, at quality %d" % quality)
	check(windup_ok, "Ultimate preparation stays centred on the casting companion's body at quality %d" % quality)
	game.start_pve(Rules.quick_map("aurora"))
	game.hud.hide()
	game.arena.guide_enabled = false

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.set_process(false)
	game.start_pve(Rules.quick_map("aurora"))
	game.game_settings.config_path = "user://heroic-abilities-test.cfg"
	game.hud.hide()
	game.arena.guide_enabled = false
	var entries: Array = Powers.CATALOG + Powers.ULTIMATES + Powers.BASIC_ULTIMATES
	for quality in [2, 0]:
		await body_origins(game, quality)
		game.video.configure(60, quality, false, false)
		game.video.apply(root, game.arena)
		var max_cards = 0
		var unchanged = true
		var emitted = true
		for entry in entries:
			var id = String(entry.id)
			game.rules.reset_match()
			game.rules.phase = "play"
			game.rules.loadouts = [[id, "air", "sun_ray"], ["mirror", "thorns", "thunder"]]
			game.rules.powers[0].charge = [99, 99, 99]
			for brick in game.rules.bricks:
				if brick.team == 0:
					brick.hp = 1
					if id == "rebuild" and int(brick.id) % 3 == 0:
						brick.alive = false
			game.rules.events.clear()
			var launched: bool = game.rules.activate_power(0, 0)
			emitted = emitted and launched and game.rules.events.any(func(event): return event.kind == "power" and event.id == id)
			game.play_events()
			if Powers.is_ultimate(id):
				game.rules.events.clear()
				game.rules.step_ultimate(0, Rules.ULTIMATE_WINDUP + 0.01)
				emitted = emitted and game.rules.events.any(func(event): return event.kind == "ultimate" and event.id == id)
				game.play_events()
			var before: Dictionary = game.rules.network_snapshot()
			# Several updates also exercise deferred impacts and the persistent statuses.
			for tick in range(8): game.arena.update_state(game.rules, 0, 1.0 / 60.0)
			unchanged = unchanged and before == game.rules.network_snapshot()
			max_cards = maxi(max_cards, Front.active_count(game.arena))
			casts += 1
			await process_frame
		check(emitted, "Every ability and ultimate retains its real gameplay identity at quality %d" % quality)
		check(unchanged, "All effect callbacks leave the authoritative match unchanged at quality %d" % quality)
		check(max_cards <= (8 if quality == 0 else Front.POOL_SIZE), "Combined real casts stay inside the effect-card budget at quality %d (peak %d)" % [quality, max_cards])
		game.rules.reset_match()
		game.rules.phase = "play"
		for tick in range(480): game.arena.update_state(game.rules, 0, 1.0 / 60.0)
		await process_frame
		var pool: Array = game.arena.get_meta(Front.META)
		var unique: Dictionary = {}
		for card in pool: unique[card.get_instance_id()] = true
		check(Front.active_count(game.arena) == 0 and pool.size() == Front.POOL_SIZE and unique.size() == Front.POOL_SIZE,
			"All effect cards return exactly once after their animations finish at quality %d" % quality)
		check(game.arena.pending.is_empty(), "Deferred ability work finishes at quality %d" % quality)
	game.queue_free()
	await process_frame
	print("ABILITIES_HEROIC_RESULT casts=", casts, " origin_cases=", origin_cases, " failures=", failures)
	quit(failures)
