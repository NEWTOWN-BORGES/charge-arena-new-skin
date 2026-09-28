extends SceneTree
# Modo história: a aventura do BIT, com conversas; NORMAL dá a skin do chefe, DIFÍCIL a skin difícil.
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
	var Story = game.StoryScript
	check(order == [6, 1, 4, 8, 3, 9, 2, 7, 11, 10, 5], "The tournament order: ROSCA, SALVO, BIGORNA, BATIDA, BROTO, GANCHO, ÓRBITA, FAÍSCA, MAGNUS, HÉLIO, ECLIPSE")
	for boss in order:
		var hard = Skins.hard_of_boss(boss)
		check(hard > 11 and int(Skins.CATALOG[hard].hard_of) == boss, "%s has a hard skin" % Skins.CATALOG[boss].name)
		check(not Story.lines(boss, "before").is_empty() and not Story.lines(boss, "won").is_empty() and not Story.lines(boss, "lost").is_empty(), "%s talks before and after its match" % Skins.CATALOG[boss].name)
	for who in [Story.BIT, Story.BIT_ELITE, Story.AGENTE, Story.LOCUTOR] + order:
		var key = Story.face_key(who)
		check(ResourceLoader.exists("res://art/story/faces/%s.png" % key) and ResourceLoader.exists("res://art/story/faces/%s_hit.png" % key), "%s has a talking portrait and a dazed one" % Story.speaker_name(who))
		check(ResourceLoader.exists("res://audio/voices/%s_0.wav" % key), "%s has a voice" % Story.speaker_name(who))
	for hard_skin in range(12, 24):
		check(ResourceLoader.exists("res://art/story/faces/%d.png" % hard_skin) and ResourceLoader.exists("res://art/story/faces/%d_dark.png" % hard_skin), "%s has a portrait and a corrupted one" % Skins.CATALOG[hard_skin].name)
	# Every scene card points at a backdrop that exists.
	var cards: Array = []
	for entry in Story.INTRO + Story.OPENING:
		if int(entry[0]) == Story.SCENE:
			cards.append(entry)
	for step in range(order.size()):
		cards.append(Story.round_card(step, order[step], "x"))
	for entry in Story.S2_INTRO + Story.S2_AFTER_MAGNUS + Story.hard_lines(Story.HELIO, "before") + Story.hard_lines(Story.HELIO, "won"):
		if int(entry[0]) == Story.SCENE:
			cards.append(entry)
	check(cards.all(func(c): return ResourceLoader.exists("res://art/story/scenes/%s.png" % String(c[2].bg))), "Every scene has its backdrop (%d)" % cards.size())
	# VER HISTÓRIA: the conversations only, as far as the player has got.
	var recap: Array = game.story_recap()
	check(recap.size() == Story.INTRO.size() + 1, "A new player's recap stops before the training (%d lines)" % recap.size())
	game.skins.unlock_all = true
	var whole: Array = game.story_recap()
	game.skins.unlock_all = false
	check(String(whole[-1][1]) == String(Story.lines(Story.FINAL, "won")[-1][1]) and whole.any(func(l): return String(l[1]) == String(Story.lines(Story.TEACHER, "teach")[1][1])), "With everything open the recap runs to the end, HÉLIO's lesson included (%d lines)" % whole.size())
	var normal: Array = game.story_entries(false)
	check(normal[0].open and not normal[1].open, "Only the first rival is open at the start")
	# A new story: chapters 1 to 3, then the training match with BATIDA and the tutorial.
	game.start_story(0, false)
	await create_timer(0.2).timeout
	check(game.hud.story_talk_running() and game.hud.story_talk.lines.size() == Story.INTRO.size() + 1 and int(game.hud.story_talk.lines[-1][0]) == Story.VERSUS, "The story opens on the fine, the call and the way to training, and the BIT vs BATIDA card")
	check(game.story_run.is_empty(), "The match waits for the conversation")
	game.hud.story_talk.close(true)
	await create_timer(0.3).timeout
	check(bool(game.story_run.get("training", false)) and int(game.arena.unit_skins[1]) == Story.BATIDA, "Then BIT trains with BATIDA")
	check(String(game.rules.loadouts[1][2]) == "", "BATIDA keeps her ultimate to herself in training")
	check(game.hud.tutorial_running(), "The training match walks through the game")
	game.hud.tutorial.close(true)
	game.rules.winner = 1
	game.finish_level()
	await create_timer(1.8).timeout
	var after: Array = game.hud.story_talk.lines
	check(game.hud.story_talk_running() and String(after[0][1]) == String(Story.TRAINING_LOST[0][1]) and after.any(func(l): return int(l[0]) == Story.LOCUTOR), "Win or lose, BATIDA signs him up and VOLTZ opens the Taça")
	check(game.skins.story_won.has("treino"), "The training is remembered")
	game.hud.story_talk.close(true)
	await create_timer(0.3).timeout
	check(not game.story_run.is_empty() and int(game.story_run.boss) == order[0] and not bool(game.story_run.get("training", false)), "Then comes the first round, against ROSCA")
	check(int(game.arena.unit_skins[0]) == 0 and String(game.rules.loadouts[0][2]) == String(Skins.CATALOG[0].ultimate), "In the story NORMAL you play as BIT, whatever skin is chosen")
	check(String(game.rules.loadouts[1][2]) == String(Skins.CATALOG[order[0]].ultimate), "The boss brings the ultimate of its skin")
	check(int(game.arena.unit_skins[1]) == order[0], "The boss wears its own skin in NORMAL")
	game.rules.winner = 0
	game.finish_level()
	await create_timer(1.8).timeout
	var talk_after: Array = game.hud.story_talk.lines
	check(game.hud.story_talk_running() and int(talk_after[0][0]) == Story.SCENE and String(talk_after[0][2].bg) == "arena_%d" % order[0] and String(talk_after[1][1]) == String(Story.lines(order[0], "won")[0][1]), "After the match the rival has its word, in its own arena")
	game.hud.story_talk.close(true)
	check(game.skins.is_unlocked(order[0]), "Beating the boss in NORMAL unlocks its skin")
	check(game.story_entries(false)[1].open, "The next boss opens")
	check(not game.skins.is_unlocked(Skins.hard_of_boss(order[0])), "The hard skin is not won in NORMAL")
	# HÉLIO: he wins with his ultimate charged, then teaches BIT the RAIO DE ELITE anyway.
	var helio = order.find(Story.TEACHER)
	game.start_story(helio, false, false)
	await create_timer(0.3).timeout
	check(game.rules.powers[1].charge[2] >= game.rules.power_charge_cost(1, 2), "HÉLIO walks in with his ultimate charged")
	game.rules.winner = 1
	game.finish_level()
	check(game.skins.is_unlocked(Story.BIT_ELITE), "Losing to HÉLIO still earns BIT DE ELITE")
	check(String(Skins.CATALOG[Story.BIT_ELITE].ultimate) == "sun_beam", "BIT DE ELITE brings the RAIO DE ELITE")
	check(not game.skins.is_unlocked(Story.TEACHER), "HÉLIO's own skin still has to be won")
	check(game.story_entries(false)[helio + 1].open and game.hud.level_info.has_next, "After HÉLIO the final opens")
	await create_timer(1.8).timeout
	if game.hud.story_talk_running():
		game.hud.story_talk.close(true)
	game.start_story(order.size() - 1, false, false)
	await create_timer(0.2).timeout
	check(int(game.arena.unit_skins[0]) == Story.BIT_ELITE and String(game.rules.loadouts[0][2]) == "sun_beam", "BIT faces ECLIPSE as BIT DE ELITE, with the RAIO DE ELITE")
	check(not game.story_entries(true)[0].open, "DIFÍCIL stays shut until NORMAL is finished")
	game.start_story(0, true)
	await create_timer(0.2).timeout
	check(not bool(game.story_run.get("hard", false)), "A hard boss cannot be started before NORMAL is finished")
	for boss in order:
		if not game.skins.story_won.has(game.story_key(boss, false)):
			game.skins.story_won.append(game.story_key(boss, false))
	check(game.story_entries(true)[0].open, "Finishing NORMAL opens DIFÍCIL")
	# Season two: MAGNUS loose in the city, the corrupted friends, HÉLIO in the final.
	var hard_order: Array = game.story_bosses(true)
	check(hard_order[0] == Story.MAGNUS and hard_order[-1] == Story.HELIO and hard_order[-2] == Story.ECLIPSE and hard_order[-3] == Story.BATIDA and hard_order.size() == 11, "Season two: MAGNUS first, BATIDA just before ECLIPSE, HÉLIO in the final")
	for boss in hard_order:
		check(not Story.hard_lines(boss, "lost").is_empty() and (boss == Story.MAGNUS or not Story.hard_lines(boss, "before").is_empty()), "%s has season-two lines" % Story.speaker_name(boss))
	check(Story.hard_lines(Story.HELIO, "won").any(func(l): return int(l[0]) == Story.BATIDA_NEON), "Beating HÉLIO brings everyone back, BATIDA first")
	game.skins.selected = 5
	game.start_story(0, true)
	await create_timer(0.2).timeout
	var s2: Array = game.hud.story_talk.lines
	check(game.hud.story_talk_running() and String(s2[0][2].bg) == "cidade" and int(s2[-1][0]) == Story.VERSUS and bool(s2[-1][2].dark), "Season two opens on the city in chaos and a BIT vs corrupted MAGNUS card")
	game.hud.story_talk.close(true)
	await create_timer(0.3).timeout
	check(bool(game.story_run.get("hard", false)) and int(game.story_run.boss) == Story.MAGNUS, "Then BIT takes MAGNUS on")
	check(int(game.arena.unit_skins[0]) == Story.BIT_ELITE, "In the story DIFÍCIL you play as BIT DE ELITE, whatever skin is chosen")
	check(int(game.arena.unit_skins[1]) == Story.MAGNUS, "MAGNUS fights corrupted in his usual skin (IMPERADOR is the twist)")
	var talk = game.hud.story_talk
	check(talk.corrupted(Story.ROSCA) == Skins.hard_of_boss(Story.ROSCA) and talk.corrupted(Story.MAGNUS_IMP) == Story.MAGNUS_IMP and talk.corrupted(Story.MAGNUS) == Story.MAGNUS, "A corrupted friend speaks as its hard skin")
	check(game.arena.angry == [false, true], "The corrupted rival glares in the match")
	var glares = [Story.MAGNUS]
	for boss in Story.ORDER_HARD:
		if boss != Story.MAGNUS:
			glares.append(Skins.hard_of_boss(boss))
	check(glares.all(func(k): return ResourceLoader.exists("res://art/story/faces/%d_angry.png" % k)), "Every corrupted friend has an angry portrait")
	game.rules.winner = 0
	game.finish_level()
	check(game.skins.is_unlocked(Story.MAGNUS_IMP), "Freeing MAGNUS unlocks MAGNUS IMPERADOR")
	await create_timer(1.8).timeout
	var after_magnus: Array = game.hud.story_talk.lines
	check(game.hud.story_talk_running() and after_magnus.any(func(l): return l.size() > 2 and l[2] is Dictionary and String(l[2].get("fx", "")) == "lineup"), "Freed, MAGNUS tells his story and the dark entrants walk into the second Taça")
	game.hud.story_talk.close(true)
	check(game.story_entries(true)[1].open, "The next corrupted friend opens")
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
