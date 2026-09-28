extends SceneTree
# Modo história: dez chefes sem ultimate; NORMAL dá a skin do chefe, DIFÍCIL a skin difícil.
var failures = 0

func check(ok: bool, text: String) -> void:
	if ok:
		print("PASS: ", text)
	else:
		failures += 1
		push_error("FAIL: " + text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.skins.config_path = "user://story-test-skins.cfg"
	root.add_child(game)
	await create_timer(0.5).timeout
	game.skins.defeated.clear()
	game.skins.story_won.clear()
	var Skins = game.Skins
	var order: Array = game.story_bosses()
	check(order.size() == 12, "Twelve bosses in the story (%d)" % order.size())
	for boss in order:
		var hard = Skins.hard_of_boss(boss)
		check(hard > 11 and int(Skins.CATALOG[hard].hard_of) == boss, "%s has a hard skin" % Skins.CATALOG[boss].name)
	var normal: Array = game.story_entries(false)
	check(normal[0].open and not normal[1].open, "Only the first boss is open at the start")
	game.start_story(0, false)
	await create_timer(0.2).timeout
	check(String(game.rules.loadouts[0][2]) == String(Skins.CATALOG[game.skins.selected].ultimate), "You bring the ultimate of the skin you wear")
	check(String(game.rules.loadouts[1][2]) == String(Skins.CATALOG[order[0]].ultimate), "The boss brings the ultimate of its skin")
	check(int(game.arena.unit_skins[1]) == order[0], "The boss wears its own skin in NORMAL")
	game.rules.winner = 0
	game.finish_level()
	check(game.skins.is_unlocked(order[0]), "Beating the boss in NORMAL unlocks its skin")
	check(game.story_entries(false)[1].open, "The next boss opens")
	check(not game.skins.is_unlocked(Skins.hard_of_boss(order[0])), "The hard skin is not won in NORMAL")
	game.skins.selected = 5
	game.start_story(0, true)
	await create_timer(0.2).timeout
	check(String(game.rules.loadouts[0][2]) == "singularity", "Wearing ECLIPSE you have its ultimate in the story")
	check(int(game.arena.unit_skins[1]) == Skins.hard_of_boss(order[0]), "In DIFÍCIL the boss wears its hard skin")
	game.rules.winner = 0
	game.finish_level()
	check(game.skins.is_unlocked(Skins.hard_of_boss(order[0])), "Beating it in DIFÍCIL unlocks the hard skin")
	# The hard skins build and carry their added pieces.
	var body = Node3D.new()
	game.arena.add_child(body)
	preload("res://scripts/robots.gd").build(game.arena, body, Skins.hard_of_boss(order[0]), Color.RED)
	check(body.get_child_count() > 3, "A hard skin builds")
	# Shields take 45% of an ultimate's blow.
	var rules = game.rules
	rules.reset_match()
	rules.powers[1].walls_time = 5.0
	var taken = 0
	for i in range(20):
		taken += rules.absorb(1, 10)
	check(taken == 110, "A shield lets 55%% of an ultimate through (%d of 200)" % taken)
	check(rules.shielded(1) and not rules.shielded(0), "Only the shielded side is shielded")
	game.return_to_menu()
	check(game.story_run.is_empty(), "Leaving the match leaves the story")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://story-test-skins.cfg"))
	print("STORY_BOSSES_RESULT failures=%d" % failures)
	quit(1 if failures else 0)
