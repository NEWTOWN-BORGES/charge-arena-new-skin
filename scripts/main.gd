extends Node3D
const StoryScript = preload("res://scripts/story_script.gd")
const ArenaTheme = preload("res://scripts/arena_theme.gd")
const Rules = preload("res://scripts/arena_rules.gd")
const ArenaView = preload("res://scripts/indie_arena_view.gd")
const HUD = preload("res://scripts/game_hud.gd")
const VideoSettings = preload("res://scripts/video_settings.gd")
const Music = preload("res://scripts/music_player.gd")
const Skins = preload("res://scripts/skins.gd")
const PowerShop = preload("res://scripts/powers.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Cup = preload("res://scripts/cup.gd")
const Press = preload("res://scripts/story_press.gd")
const CupScreen = preload("res://scripts/story_hub.gd")
const GameFeel = preload("res://scripts/game_feel.gd")
var cup = Cup.new()
var cup_screen
var cup_active = false
var cup_resolved = false
var skin_music_return = ""
const PORT = 27940
var rules = Rules.new()
var arena
var hud
var mode = "menu"
var local_team = 0
var connected = false
var remote_id = 0
var remote_command = {"move": Vector2.ZERO, "fire": false}
# Powers arrive on their own reliable channel, so a tap is never lost in the input stream.
var remote_power = -1
# One shot per tap. Taps made while the gun reloads wait their turn and leave at the gun's
# own cadence, so ten quick taps are ten shots; holding the finger down does not keep
# firing. Per team: the host keeps the guest's taps the same way it keeps its own.
const FIRE_BUFFER_MS = 900
const MAX_QUEUED_SHOTS = 24
var queued_shots: Array = [0, 0]
var queued_until: Array = [0, 0]
var pending_clicks = 0
var pending_events: Array = []
var remote_power_until = 0
var remote_age = 0.0
var network_tick = 0.0
var connection_timer = 0.0
var network_status = ""
var pause_ai = false
var tones: Dictionary = {}
var audio: AudioStreamPlayer
var audio_voices: Array = []
var audio_cursor = 0
var sound_times: Dictionary = {}
var shot_variants = [0, 1]
var impact_variant = 0
var haptic_next_ms = 0
var haptic_strength = 0.0
var sustained_haptic = false
var sustained_next_ms = 0
var haptic_pulse_until = 0
var arena_duck_db = 0.0
# How the game feels: shared with the arena and edited by the LAB tuning panel.
var feel = GameFeel.new()
var release_focus = 0.0
var break_times = [-10.0, -10.0]
var last_phase = ""
var last_stuns: Array = [0.0, 0.0]
var packets_received = 0
var mouse_firing = false
var video = VideoSettings.new()
var music
var visual_packet_age = 0.0
var hud_timer = 0.0
var fps_timer = 0.0
var pve_paused = false
var skins = Skins.new()
var power_shop = PowerShop.new()
# Bricks already paid into the shop wallet this match.
var credited_bricks = 0
# The angle the pilot is walking to, chosen by tapping the stadium or stepping with the
# arrows. INF means "stay where you are".
const MAGNET_ANGLE = 0.05
# The stick: anything under the dead zone is a resting thumb, and anything over it moves
# the pilot at once, never below STICK_FLOOR of its speed.
const POWER_HOLD_MS = 500
var held_power = -1
var held_power_until = 0
const STICK_DEADZONE = 0.08
const STICK_FLOOR = 0.34
var game_settings = GameSettings.new()
var campaign = Campaign.new()
# Campaign level being played, or -1 for quick play, PvP and the menu.
var level_index = -1
# Level shown in the menu carousel, and the delay before its arena is rebuilt.
var menu_level = 0
var menu_preview_timer = -1.0
var client_boosted_ids: Dictionary = {}
# Last seen position of each explosive round, to replay the blast the host resolved.
var client_blast_spots: Dictionary = {}

func configure_test_access(enabled: bool) -> void:
	# Access flags, not fake victories. Enabled only by the isolated LAB export.
	if not enabled:
		return
	skins.unlock_all = true
	skins.selected = 5
	power_shop.unlock_all = true
	power_shop.owned = PowerShop.all_ids()
	power_shop.bricks = PowerShop.TEST_WALLET
	campaign.unlock_all = true

func _ready() -> void:
	arena = ArenaView.new()
	feel.load_values()
	arena.feel = feel
	add_child(arena)
	arena.build()
	var layer = CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	layer.add_child(hud)
	hud.arena_aspect = arena.view_aspect()
	hud.layout_changed.connect(frame_arena)
	hud.showroom_spun.connect(func(amount): arena.turn_showroom(amount))
	get_window().size_changed.connect(fit_content_scale)
	fit_content_scale()
	hud.play_requested.connect(start_pve)
	hud.map_previewed.connect(preview_world)
	hud.map_chosen.connect(func(world): start_pve(Rules.quick_map(world)))
	hud.map_picker_closed.connect(func():
		# The picker toured other worlds in a rebuilt stadium: back in the lobby, put its
		# stage back (the level's map, your pilot and the boss), or the lobby stood empty.
		if mode == "menu":
			show_menu_preview()
		frame_arena())
	hud.map_orbited.connect(func(dx, dy): arena.orbit_tour(dx, dy))
	hud.map_zoomed.connect(func(factor): arena.zoom_tour(factor))
	hud.host_requested.connect(host_game)
	hud.join_requested.connect(join_game)
	hud.pvp_ai_requested.connect(start_pvp_ai)
	hud.squad_requested.connect(start_squad)
	hud.test_arena_requested.connect(func(): start_pve(Rules.test_map()))
	hud.menu_requested.connect(request_menu)
	hud.resume_requested.connect(resume_pve)
	hud.quit_requested.connect(return_to_menu)
	hud.replay_requested.connect(replay)
	hud.video_changed.connect(change_video)
	hud.video_opened.connect(func(): mouse_firing = false)
	hud.audio_changed.connect(change_audio)
	video.load_preferences()
	video.apply(get_viewport(), arena)
	hud.smooth = video.smooth_hud
	hud.queue_redraw()
	hud.sync_video(video)
	music = Music.new()
	add_child(music)
	music.load_preferences()
	hud.sync_audio(music)
	music.play("menu")
	configure_test_access(OS.has_feature("open_test"))
	skins.load_preferences()
	power_shop.load_preferences()
	hud.sync_powers(power_shop)
	hud.power_bought.connect(buy_power)
	hud.power_equipped.connect(equip_power)
	hud.team_skins = arena.unit_skins
	hud.team_tints = arena.unit_tints
	hud.arena_view = arena
	hud.skin_selected.connect(select_skin)
	hud.skin_previewed.connect(preview_skin_music)
	hud.skin_preview_closed.connect(restore_skin_music)
	hud.cup_requested.connect(open_cup)
	hud.sync_skins(skins)
	dress_pilots(0)
	game_settings.load_preferences()
	rules.ai_level = game_settings.difficulty
	arena.guide_enabled = game_settings.aim_guide
	arena.shake_scale = [0.0, 0.45, 1.0][game_settings.camera_feedback]
	feel.intensity = 1.0 if game_settings.effects_full else 0.6
	rules.assist_team = local_team if game_settings.aim_assist else -1
	hud.sync_game(game_settings)
	hud.difficulty_changed.connect(change_difficulty)
	hud.guide_changed.connect(change_guide)
	hud.sensitivity_changed.connect(change_sensitivity)
	hud.feedback_changed.connect(change_feedback)
	hud.effects_changed.connect(change_effects)
	hud.feel_tuning_requested.connect(open_feel_tuning)
	hud.story_play_requested.connect(func():
		open_cup()
		cup_screen.open_versus())
	hud.fire_layout_changed.connect(change_fire_layout)
	hud.bosses_requested.connect(open_bosses)
	hud.tutorial_finished.connect(tutorial_done)
	hud.powers_opened.connect(maybe_shop_tutorial)
	hud.tutorials_reset.connect(func():
		game_settings.tutorial_lobby = false
		game_settings.tutorial_match = false
		game_settings.tutorial_shop = false
		save_game_settings()
		if mode == "menu":
			maybe_lobby_tutorial())
	hud.notice_shown.connect(func(_kind): play_tone("notify", 2.0))
	hud.story_boss_chosen.connect(start_story)
	hud.story_recap_requested.connect(func(hard): hud.play_story_talk(story_recap(hard)))
	hud.story_voice_db = linear_to_db(maxf(game_settings.sfx_volume, 0.0001))
	campaign.load_preferences()
	sync_boss_skins()
	hud.sync_campaign(campaign)
	hud.level_selected.connect(start_level)
	hud.next_level_requested.connect(func():
		if not story_run.is_empty():
			start_story(int(story_run.step) + 1, bool(story_run.hard))
		else:
			start_level(Campaign.menu_level(level_index + 1)))
	hud.levels_requested.connect(func():
		if not story_run.is_empty():
			hud.open_powers()
		else:
			show_levels())
	hud.menu_level_changed.connect(step_menu_level)
	menu_level = Campaign.menu_level(campaign.suggested_level())
	hud.sync_menu_level(menu_level)
	show_menu_preview()
	# First visit: a written tour of the lobby (not in automated runs without a screen).
	get_tree().create_timer(1.2).timeout.connect(maybe_lobby_tutorial)
	hud.show_menu()
	get_window().focus_exited.connect(func(): hud.reset_touch(); mouse_firing = false)
	get_window().focus_exited.connect(pause_pve)
	get_window().focus_exited.connect(stop_haptics)
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(joined_server)
	multiplayer.connection_failed.connect(func(): return_to_menu.call_deferred("Não foi possível ligar. Confirma o IP e a rede."))
	multiplayer.server_disconnected.connect(func(): return_to_menu.call_deferred("O anfitrião saiu da partida."))
	build_audio()
	cup.restore()
	# Reconcile earned rewards when upgrading an older tournament save.
	for reward in cup.defeated_bosses():
		skins.defeat(reward)
	if cup.wins == Cup.FULL_MATCHES:
		skins.defeat(11)
	save_skins()
	sync_story()
	cup_screen = CupScreen.new()
	cup_screen.cup = cup
	cup_screen.player_skin_provider = func(): return skins.selected
	hud.add_child(cup_screen)
	hud.move_child(cup_screen, hud.menu.get_index() + 1)
	cup_screen.action.connect(cup_action)
	cup_screen.refresh()
	cup_screen.hide()
	var scroll_gestures = preload("res://scripts/ui_scroll.gd").new()
	scroll_gestures.name = "ScrollGestures"
	scroll_gestures.surface = func():
		# Topmost first: the shop can open over the story, both over the lobby. The story
		# screen and the quick-play map strip were missing, so their lists would not drag.
		for overlay in [hud.powers_overlay, hud.pause_overlay, hud.video_overlay, hud.bosses_overlay, hud.skins_overlay, hud.levels_overlay, hud.pvp_overlay, hud.map_overlay]:
			if is_instance_valid(overlay) and overlay.visible: return overlay
		return cup_screen if cup_screen.visible else hud.menu
	hud.add_child(scroll_gestures)
	arena.show()
	for arg in OS.get_cmdline_user_args():
		if arg == "--pve":
			start_pve()
		if arg == "--pvp-ai" or arg == "--colosseum":
			start_pvp_ai()
		if arg.begins_with("--capture="):
			capture_preview(arg.trim_prefix("--capture="))

func use_loadouts(boss_kit: Array, boss_skin: int = 0, rival_ultimate: String = "") -> void:
	# Two bought powers plus the ultimate that comes with each pilot's skin. The local
	# pilot is not always team 0 — in PvP the guest plays team 1 — so the kits are placed
	# by side. Built the other way round, the guest walked in with the host's ultimate in
	# its keys and none of its own.
	var mine: Array = power_shop.loadout(String(Skins.CATALOG[worn_skin()].ultimate))
	# A station pilot has no skin to bring one, so its level names the ultimate instead.
	var theirs: Array = boss_kit + [rival_ultimate if rival_ultimate != "" else String(Skins.CATALOG[boss_skin].ultimate)]
	rules.loadouts = [mine, theirs] if local_team == 0 else [theirs, mine]
	credited_bricks = 0
	if PowerShop.START_WITH_ULTIMATE_FOR_TESTS:
		# Testing build: both sides walk in with the ultimate ready.
		charge_ultimates.call_deferred()

func charge_ultimates() -> void:
	for team in range(rules.powers.size()):
		var cost = rules.power_charge_cost(team, 2)
		if cost > 0:
			rules.powers[team].charge[2] = cost

func start_pve(layout: Dictionary = {}) -> void:
	close_cup_screen()
	# Quick play opens on the tall arena, which fills a phone held upright instead of
	# sitting in a band across the middle of it. Campaign levels bring their own.
	if layout.is_empty():
		layout = Rules.tower_map()
	pve_paused = false
	close_network()
	mode = "pve"
	local_team = 0
	arena.set_view_team(local_team)
	network_status = ""
	leave_campaign(layout)
	use_loadouts(["blast", "rapid"])
	rules.reset_match()
	dress_pilots(local_team)
	# Compile what the match can draw during the countdown, not at its first shot.
	arena.warm_shaders.call_deferred()
	hud.show_game(mode, local_team)
	# The 3 v 3 arena is watched: all six robots are the AI's (see _physics_process).
	hud.spectating = rules.squad
	if rules.squad:
		arena.guide_enabled = false
	sync_assist()
	music.play_skin(skins.selected)
	# The first quick match on this device walks through the game, the match on hold.
	if not rules.squad and not game_settings.tutorial_match and level_index < 0 and tutorials_allowed():
		pve_paused = true
		hud.start_tutorial.call_deferred("match")

func start_pvp_ai() -> void:
	start_pve(Rules.pvp_map())

func start_squad() -> void:
	# 3 contra 3: the squad arena, six robots playing each other while the player watches.
	start_pve(Rules.squad_map())

func start_level(index: int) -> void:
	story_run = {}
	arena.angry = [false, false]
	close_cup_screen()
	if not campaign.is_unlocked(index):
		return
	var level: Dictionary = Campaign.LEVELS[index]
	pve_paused = false
	close_network()
	mode = "pve"
	local_team = 0
	arena.set_view_team(local_team)
	network_status = ""
	level_index = index
	menu_level = Campaign.menu_level(index)
	hud.sync_menu_level(index)
	use_map(level.map)
	rules.ai_profile = Campaign.ai_profile(index, game_settings.difficulty)
	use_loadouts(Campaign.boss_kit(index), level.boss, Campaign.level_ultimate(index))
	rules.reset_match()
	dress_pilots(local_team)
	# The boss wears its own skin and its own bricks, in the colours they were drawn in. A
	# station pilot has none: it flies the standard hull in the rival's colour, which is how
	# you know at a glance that there is no skin to win here.
	arena.set_skin(1, level.boss, Campaign.is_minor(index), Campaign.level_hue(index))
	hud.team_hues = arena.unit_hues
	var rival_name: String = String(level.name).to_upper() if Campaign.is_minor(index) else String(Skins.CATALOG[level.boss].name)
	hud.level_info = {"number": Campaign.menu_levels().find(Campaign.menu_level(index)) + 1, "name": level.name, "challenge": level.challenge, "boss_name": rival_name, "has_next": index + 1 < Campaign.LEVELS.size()}
	hud.level_result = ""
	hud.level_skin = ""
	# Compile what the match can draw during the countdown, not at its first shot.
	arena.warm_shaders.call_deferred()
	hud.show_game(mode, local_team)
	sync_assist()
	# The theme follows whoever is on the other side, station pilot or boss, so ten matches
	# in a row do not share one tune. A station hull is numbered past the catalogue, so the
	# level names its theme instead - left to the hull number they all fell through to the
	# last track in the list, which is the final boss's.
	if Campaign.is_minor(index):
		music.play_bot(Campaign.level_music(index))
	else:
		music.play_skin(Campaign.level_music(index))

func leave_campaign(layout: Dictionary = {}) -> void:
	story_run = {}
	arena.angry = [false, false]
	level_index = -1
	rules.ai_profile = {}
	hud.level_info = {}
	hud.level_result = ""
	hud.level_skin = ""
	use_map(layout if not layout.is_empty() else Rules.default_map())

func step_menu_level(step: int) -> void:
	var visible = Campaign.menu_levels()
	var chosen: int = visible[clampi(visible.find(menu_level) + step, 0, visible.size() - 1)]
	if chosen == menu_level:
		return
	menu_level = chosen
	hud.sync_menu_level(menu_level)
	# The name updates at once; the arena follows once the thumb settles.
	menu_preview_timer = 0.18

func show_menu_preview() -> void:
	var level: Dictionary = Campaign.LEVELS[menu_level]
	use_map(level.map)
	dress_pilots(0)
	show_menu_boss()
	refresh_showroom()

func refresh_showroom() -> void:
	# The lobby's stage: your pilot on the pedestal, the chosen level's boss behind, in its
	# team colour alone until it has been beaten.
	var level: Dictionary = Campaign.LEVELS[menu_level]
	var boss: int = int(level.boss)
	var beaten: bool = boss < Skins.CATALOG.size() and skins.is_unlocked(boss)
	arena.show_showroom(skins.selected, boss, not beaten)

func show_menu_boss() -> void:
	# The previewed rival is shown in its own colours, like it fights: a boss in its skin's
	# palette, a station pilot in the colour its level gives it.
	var boss: int = Campaign.LEVELS[menu_level].boss
	arena.set_skin(1, boss, Campaign.is_minor(menu_level), Campaign.level_hue(menu_level))
	hud.team_hues = arena.unit_hues

func sync_boss_skins() -> void:
	# Levels won before boss skins existed still award their skins.
	var changed = false
	for index in campaign.completed:
		# A station pilot has no skin to award: its hull is numbered past the catalogue.
		if Campaign.is_minor(index):
			continue
		changed = skins.defeat(Campaign.LEVELS[index].boss) or changed
	if changed:
		save_skins()
		hud.sync_skins(skins)

func use_map(layout: Dictionary) -> void:
	# Swap the rules layout and rebuild the stadium only when the map really changes.
	if rules.map.get("id", "") != layout.get("id", ""):
		rules.set_map(layout)
	if arena.map.get("id", "") == layout.get("id", ""):
		return
	var old = arena
	remove_child(old)
	old.queue_free()
	arena = ArenaView.new()
	add_child(arena)
	# The world is dressed for the chosen profile (richer on the nicer ones).
	arena.quality_level = video.quality
	arena.build(layout)
	# A new stadium starts on team 0's side. The PvP guest joins on the PvP map, which
	# rebuilds the stadium after its seat was turned round: without this the guest saw its
	# own pilot at the top of the screen.
	arena.set_view_team(local_team if mode == "client" else 0)
	video.apply(get_viewport(), arena)
	hud.smooth = video.smooth_hud
	hud.queue_redraw()
	arena.guide_enabled = game_settings.aim_guide
	arena.shake_scale = [0.0, 0.45, 1.0][game_settings.camera_feedback]
	hud.arena_view = arena
	hud.team_skins = arena.unit_skins
	hud.team_tints = arena.unit_tints
	hud.arena_aspect = arena.view_aspect()
	hud.layout()

# --------------------------------------------------------------------------------------
# Modo história: a história do BIT (StoryScript). Onze adversários por ordem, com conversas antes
# e depois de cada partida. Em NORMAL jogas com o BIT (e com o BIT DE ELITE na final) e vencer um
# chefe dá a sua skin; o HÉLIO ensina-te o RAIO DE ELITE ganhes ou percas. O DIFÍCIL abre depois
# do NORMAL: os chefes vestem as skins difíceis, e é essa que ganhas.
var story_run: Dictionary = {}

func story_bosses(hard: bool = false) -> Array:
	# NORMAL is the first Taça; DIFÍCIL is the second season, in its own order.
	return (StoryScript.ORDER_HARD if hard else StoryScript.ORDER).duplicate()

func campaign_level_of(boss: int) -> int:
	for i in range(Campaign.LEVELS.size()):
		if not Campaign.is_minor(i) and int(Campaign.LEVELS[i].boss) == boss:
			return i
	return Campaign.LEVELS.size() - 1

func story_level_of(boss: int, hard: bool = false) -> int:
	# Season two opens with MAGNUS loose in the city: the city arena.
	if hard and boss == StoryScript.MAGNUS:
		return campaign_level_of(StoryScript.ROSCA)
	# The arena: each boss plays at home. MAGNUS, ECLIPSE's henchman, guards the last Eclipse
	# outpost; his kit is still the champion's (see story_kit_level).
	if boss == StoryScript.MAGNUS:
		for i in range(Campaign.LEVELS.size()):
			if String(Campaign.LEVELS[i].name) == "Posto Eclipse V":
				return i
	return campaign_level_of(boss)

func story_map(boss: int, hard: bool) -> Dictionary:
	# Season two plays the same courts in the corrupted worlds, dark and lit by neon.
	var layout: Dictionary = Campaign.LEVELS[story_level_of(boss, hard)].map.duplicate(true)
	if hard:
		layout.id = String(StoryScript.S2_WORLD.get(boss, "cidade_negra"))
	return layout

func story_place(boss: int, hard: bool) -> String:
	if hard:
		return String(ArenaTheme.theme(String(StoryScript.S2_WORLD.get(boss, "cidade_negra"))).name)
	return story_arena_name(boss)

func story_kit_level(boss: int) -> int:
	return Campaign.LEVELS.size() - 1 if boss == StoryScript.MAGNUS else campaign_level_of(boss)

func story_ai_level(step: int) -> int:
	# The rivals grow stronger step by step: the pace of the campaign level of the same tier.
	for i in range(Campaign.LEVELS.size()):
		if not Campaign.is_minor(i) and int(Campaign.LEVELS[i].tier) == step:
			return i
	return Campaign.LEVELS.size() - 1

func story_pilot(boss: int, hard: bool) -> int:
	# The story is BIT's: he plays as BIT until HÉLIO teaches him the RAIO DE ELITE, and faces
	# ECLIPSE as BIT DE ELITE; in DIFÍCIL he is BIT DE ELITE throughout. The other skins are
	# for the other modes.
	return StoryScript.BIT_ELITE if hard or boss == StoryScript.FINAL else StoryScript.BIT

func worn_skin() -> int:
	return story_pilot(int(story_run.boss), bool(story_run.hard)) if not story_run.is_empty() else skins.selected

func story_prize(boss: int, hard: bool) -> int:
	return Skins.hard_of_boss(boss) if hard else boss

func story_rival(boss: int, hard: bool) -> int:
	# The skin the rival fights in: its prize, except season two's MAGNUS, who wrecks the city
	# in his usual skin; MAGNUS IMPERADOR, his true form, is the twist once BIT frees him.
	if hard and boss == StoryScript.MAGNUS:
		return boss
	return story_prize(boss, hard)

func story_key(boss: int, hard: bool) -> String:
	return ("h%d" if hard else "n%d") % boss

func story_beaten(boss: int, hard: bool) -> bool:
	return skins.story_won.has(story_key(boss, hard)) or skins.defeated.has(story_prize(boss, hard))

func story_passed(boss: int, hard: bool) -> bool:
	# HÉLIO's match moves the story on even when he wins it.
	return story_beaten(boss, hard) or (not hard and boss == StoryScript.TEACHER and skins.story_won.has("p%d" % boss))

func story_hard_open() -> bool:
	# DIFÍCIL only opens once the whole NORMAL story is done (the LAB build opens it to test).
	return skins.unlock_all or story_bosses().all(func(boss): return story_passed(boss, false))

func story_entries(hard: bool) -> Array:
	var order = story_bosses(hard)
	var list: Array = []
	var reachable = not hard or story_hard_open()
	for step in range(order.size()):
		var boss: int = order[step]
		var wear = story_prize(boss, hard) if story_beaten(boss, hard) else story_rival(boss, hard)
		list.append({"name": String(Skins.CATALOG[wear].name), "skin": wear, "beaten": story_beaten(boss, hard),
			"passed": story_passed(boss, hard),
			# The LAB build opens every fight, so any of them can be jumped to for testing.
			"open": reachable and (skins.unlock_all or step == 0 or story_passed(order[step - 1], hard) or story_passed(boss, hard))})
	return list

func story_arena_name(boss: int) -> String:
	return String(Campaign.LEVELS[story_level_of(boss)].name)

func story_trained() -> bool:
	return skins.story_won.has("treino") or story_beaten(StoryScript.ORDER[0], false)

func story_recap(hard: bool = false) -> Array:
	# Every conversation of the story in order, without the matches: up to where the player
	# has got (the whole story in the LAB build, or once it is finished). DIFÍCIL tells
	# season two.
	if hard:
		return story_recap_hard()
	var lines: Array = StoryScript.INTRO.duplicate()
	if not (skins.unlock_all or story_trained()):
		lines.append([StoryScript.NARRADOR, "Continua no Modo história: o treino com a BATIDA é já a seguir."])
		return lines
	lines += StoryScript.TRAINING_LOST + StoryScript.TRAINING_AFTER + StoryScript.OPENING
	var order = story_bosses()
	for step in range(order.size()):
		var boss: int = order[step]
		var reached = skins.unlock_all or step == 0 or story_passed(order[step - 1], false)
		if not reached:
			break
		if step > 0:
			lines.append(StoryScript.round_card(step, boss, story_arena_name(boss)))
		lines += StoryScript.lines(boss, "before")
		if boss == StoryScript.TEACHER and (skins.unlock_all or story_passed(boss, false)):
			lines += StoryScript.lines(boss, "won" if story_beaten(boss, false) else "lost")
			lines += StoryScript.lines(boss, "teach")
		elif skins.unlock_all or story_beaten(boss, false):
			lines += StoryScript.lines(boss, "won")
		else:
			lines.append([StoryScript.NARRADOR, "Continua no Modo história: vence o %s para veres o resto." % StoryScript.speaker_name(boss)])
			break
	return lines

func story_recap_hard() -> Array:
	# Season two, as it is told in DIFÍCIL: the city, then each corrupted friend in turn.
	if not story_hard_open():
		return [[StoryScript.NARRADOR, "A segunda temporada abre no DIFÍCIL depois de acabares a história no NORMAL."]]
	var lines: Array = []
	var order = story_bosses(true)
	for step in range(order.size()):
		var boss: int = order[step]
		var reached = skins.unlock_all or step == 0 or story_passed(order[step - 1], true)
		if not reached:
			break
		if step == 0:
			lines += StoryScript.S2_INTRO
		else:
			lines.append(StoryScript.round_card(step, boss, story_place(boss, true), "arena_s2_%d" % boss))
		lines += StoryScript.hard_lines(boss, "before")
		if skins.unlock_all or story_beaten(boss, true):
			lines += StoryScript.S2_AFTER_MAGNUS if boss == StoryScript.MAGNUS else StoryScript.hard_lines(boss, "won")
		else:
			lines.append([StoryScript.NARRADOR, "Continua no Modo história DIFÍCIL: vence o %s para veres o resto." % StoryScript.speaker_name(boss)])
			break
	return lines

func open_bosses() -> void:
	hud.open_bosses({"normal": story_entries(false), "hard": story_entries(true), "hard_open": story_hard_open()})

func start_story(step: int, hard: bool, talk: bool = true) -> void:
	var order = story_bosses(hard)
	if step < 0 or step >= order.size():
		return_to_menu()
		return
	if hard and not story_hard_open():
		return
	var boss: int = order[step]
	if not hard and step == 0 and not story_trained():
		# A new story: chapters 1 to 3 (the fine, the call, the way to training), then the
		# training match with BATIDA, which is the game's tutorial.
		hud.play_story_talk(StoryScript.INTRO + [StoryScript.versus(StoryScript.BIT, StoryScript.BATIDA, -1, 0, "Circuito Aurora")], begin_training)
		return
	if talk and not hard:
		# The story is told in NORMAL: each round opens on its card and the rival's lines; the
		# first also on the opening ceremony. The match begins when the talk ends (or is skipped).
		var lines: Array = []
		if step == 0 and not story_beaten(boss, false):
			lines += StoryScript.OPENING
		else:
			lines.append(StoryScript.round_card(step, boss, story_arena_name(boss)))
		lines += StoryScript.lines(boss, "before")
		lines.append(StoryScript.versus(story_pilot(boss, false), boss, step, order.size(), story_arena_name(boss)))
		hud.play_story_talk(lines, func(): begin_story(step, hard))
		return
	if talk and hard:
		# Season two: the city under attack before MAGNUS, then a round card and the words of
		# each corrupted friend; the fight card closes every talk.
		var lines: Array = []
		var wear = story_rival(boss, true)
		var place = story_place(boss, true)
		if step == 0 and not story_beaten(boss, true):
			lines += StoryScript.S2_INTRO
		else:
			lines.append(StoryScript.round_card(step, boss, place, "arena_s2_%d" % boss))
		lines += StoryScript.hard_lines(boss, "before")
		lines.append(StoryScript.versus(story_pilot(boss, true), wear, step, order.size(), place, true))
		hud.play_story_talk(lines, func(): begin_story(step, hard))
		return
	begin_story(step, hard)

func begin_training() -> void:
	# Chapter 3: a friendly match with BATIDA at the training arena, the written tutorial
	# walking through it. She keeps her ultimate to herself and goes easy.
	var index = 0
	close_cup_screen()
	pve_paused = false
	close_network()
	mode = "pve"
	local_team = 0
	arena.set_view_team(local_team)
	network_status = ""
	level_index = index
	use_map(Campaign.LEVELS[index].map)
	story_run = {"step": -1, "hard": false, "boss": StoryScript.BATIDA, "training": true}
	arena.angry = [false, false]
	rules.ai_profile = Campaign.ai_profile(0, 0)
	use_loadouts(Campaign.boss_kit(index), StoryScript.BATIDA)
	rules.loadouts[1 - local_team][2] = ""
	rules.reset_match()
	dress_pilots(local_team)
	arena.set_skin(1, StoryScript.BATIDA, false)
	hud.team_hues = arena.unit_hues
	hud.level_info = {"number": 0, "name": "TREINO · " + String(Campaign.LEVELS[index].name),
		"challenge": "Treino com a BATIDA: aprende a jogar.", "boss_name": "BATIDA", "has_next": true, "story": true}
	hud.level_result = ""
	hud.level_skin = ""
	arena.warm_shaders.call_deferred()
	hud.show_game(mode, local_team)
	sync_assist()
	music.play_skin(StoryScript.BATIDA)
	# The written tutorial of a first match, over the paused court.
	pve_paused = true
	hud.start_tutorial.call_deferred("match")

func finish_training() -> void:
	var won = rules.winner == local_team
	if not skins.story_won.has("treino"):
		skins.story_won.append("treino")
		save_skins()
	hud.level_skin = ""
	hud.level_result = "won" if won else "lost"
	hud.level_opened = false
	hud.level_info["has_next"] = true
	var lines: Array = (StoryScript.TRAINING_WON if won else StoryScript.TRAINING_LOST) + StoryScript.TRAINING_AFTER + StoryScript.OPENING + StoryScript.lines(StoryScript.ORDER[0], "before") + [StoryScript.versus(StoryScript.BIT, StoryScript.ORDER[0], 0, StoryScript.ORDER.size(), story_arena_name(StoryScript.ORDER[0]))]
	get_tree().create_timer(1.6).timeout.connect(func():
		if mode == "pve" and bool(story_run.get("training", false)):
			hud.play_story_talk(lines, func(): begin_story(0, false)))

func begin_story(step: int, hard: bool) -> void:
	var order = story_bosses(hard)
	var boss: int = order[step]
	var index = story_level_of(boss, hard)
	close_cup_screen()
	pve_paused = false
	close_network()
	mode = "pve"
	local_team = 0
	arena.set_view_team(local_team)
	network_status = ""
	level_index = index
	use_map(story_map(boss, hard))
	story_run = {"step": step, "hard": hard, "boss": boss}
	# Season two's rivals are corrupted: they glare.
	arena.angry = [false, hard]
	rules.ai_profile = Campaign.ai_profile(story_ai_level(step), 2 if hard else 1)
	var wear = story_rival(boss, hard)
	# You bring the ultimate of the skin you wear (BIT has none; BIT DE ELITE brings the RAIO
	# DE ELITE); the boss brings the ultimate of the skin it wears.
	use_loadouts(Campaign.boss_kit(story_kit_level(boss)), wear)
	rules.reset_match()
	var teacher = boss == StoryScript.TEACHER and not hard
	if teacher:
		# The champion walks in with the sun already charged: this is the match he wins easily.
		charge_rival_ultimate.call_deferred()
	dress_pilots(local_team)
	# Season two: the corrupted friend fights in its hard skin, as it already is in the game.
	arena.set_skin(1, wear, false)
	hud.team_hues = arena.unit_hues
	hud.level_info = {"number": step + 1, "name": ("TEMPORADA 2 · " if hard else "") + String(Campaign.LEVELS[index].name),
		"challenge": "O campeão chega com a COROA SOLAR carregada. Aguenta o sol!" if teacher else "Trava o MAGNUS antes que destrua a cidade!" if wear != story_prize(boss, hard) else "Vence para ganhar a skin %s." % String(Skins.CATALOG[wear].name),
		"boss_name": String(Skins.CATALOG[wear].name), "has_next": step + 1 < order.size(), "story": true}
	hud.level_result = ""
	hud.level_skin = ""
	arena.warm_shaders.call_deferred()
	hud.show_game(mode, local_team)
	sync_assist()
	music.play_skin(boss)

func charge_rival_ultimate() -> void:
	var team = 1 - local_team
	var cost = rules.power_charge_cost(team, 2)
	if cost > 0:
		rules.powers[team].charge[2] = cost

func finish_story() -> void:
	if bool(story_run.get("training", false)):
		finish_training()
		return
	var won = rules.winner == local_team
	var boss: int = int(story_run.boss)
	var hard: bool = bool(story_run.hard)
	var prize = story_prize(boss, hard)
	var teacher = boss == StoryScript.TEACHER and not hard
	var unlocked: Array = []
	hud.level_skin = ""
	if won:
		if not skins.story_won.has(story_key(boss, hard)):
			skins.story_won.append(story_key(boss, hard))
			save_skins()
		if skins.defeat(prize):
			unlocked.append(Skins.CATALOG[prize].name)
	if teacher:
		# Win or lose, HÉLIO teaches BIT the RAIO DE ELITE: BIT DE ELITE is his from now on.
		if not skins.story_won.has("p%d" % boss):
			skins.story_won.append("p%d" % boss)
		if skins.defeat(StoryScript.BIT_ELITE):
			unlocked.append(Skins.CATALOG[StoryScript.BIT_ELITE].name)
		save_skins()
	if not unlocked.is_empty():
		save_skins()
		hud.sync_skins(skins)
		hud.level_skin = unlocked[0]
		hud.announce_unlock(unlocked)
	hud.level_result = "won" if won else "lost"
	hud.level_opened = false
	# The next boss only opens once this one has fallen (HÉLIO: once his match is over).
	hud.level_info["has_next"] = (won or teacher) and int(story_run.step) + 1 < story_bosses(hard).size()
	if hard:
		var place = story_place(boss, true)
		var s2: Array = [StoryScript.round_card(int(story_run.step), boss, place, "arena_s2_%d" % boss)]
		s2[0][2]["quiet"] = true
		if won and boss == StoryScript.MAGNUS:
			s2 += StoryScript.S2_AFTER_MAGNUS
		else:
			s2 += StoryScript.hard_lines(boss, "won" if won else "lost")
		get_tree().create_timer(1.6).timeout.connect(func():
			if s2.size() > 1 and mode == "pve" and not story_run.is_empty():
				hud.play_story_talk(s2))
	if not hard:
		var lines: Array = [StoryScript.round_card(int(story_run.step), boss, story_arena_name(boss))]
		lines[0][2]["quiet"] = true
		lines += StoryScript.lines(boss, "won" if won else "lost")
		if teacher:
			lines += StoryScript.lines(boss, "teach")
		# Let the last goal land before the conversation opens.
		get_tree().create_timer(1.6).timeout.connect(func():
			if not lines.is_empty() and mode == "pve" and not story_run.is_empty():
				hud.play_story_talk(lines))

func finish_level() -> void:
	if not story_run.is_empty():
		finish_story()
		return
	var won = rules.winner == local_team
	var opened = false
	var boss: int = Campaign.LEVELS[level_index].boss
	hud.level_skin = ""
	if won:
		opened = campaign.complete(level_index)
		if campaign.save_preferences() != OK:
			push_warning("Could not save campaign progress to " + campaign.config_path)
		# Nothing to win from a station pilot but the way through.
		if not Campaign.is_minor(level_index) and skins.defeat(boss):
			save_skins()
			hud.sync_skins(skins)
			hud.level_skin = Skins.CATALOG[boss].name
			hud.announce_unlock([hud.level_skin])
		if not Campaign.is_minor(level_index):
			arena.set_skin(1, boss, false)
	hud.level_result = "won" if won else "lost"
	hud.level_opened = opened
	hud.sync_campaign(campaign)

func show_levels() -> void:
	return_to_menu()
	hud.open_levels()

func close_network() -> void:
	clear_shots()
	mouse_firing = false
	connected = false
	remote_id = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	remote_command = {"move": Vector2.ZERO, "fire": false}
	remote_power = -1
	remote_age = 0
	packets_received = 0
	client_boosted_ids.clear()
	client_blast_spots.clear()

func return_to_menu(message: String = "") -> void:
	if hud.skins_overlay.visible:
		hud.close_skins()
	cup_active = false
	pve_paused = false
	close_network()
	chase_push = 1.0
	arena.set_chase(false)
	story_run = {}
	arena.angry = [false, false]
	mode = "menu"
	network_status = ""
	menu_preview_timer = -1.0
	leave_campaign(Campaign.LEVELS[menu_level].map)
	rules.reset_match()
	save_skins()
	save_powers()
	dress_pilots(0)
	show_menu_boss()
	refresh_showroom()
	hud.sync_skins(skins)
	hud.show_menu(message)
	# Back in the lobby: the story card says where the run stands and whether there is news.
	sync_story()
	music.play("menu")
	if is_instance_valid(cup_screen):
		cup_screen.hide()
		arena.show()

func request_menu() -> void:
	if mode == "pve":
		pause_pve()
	else:
		return_to_menu()

func pause_pve() -> void:
	stop_haptics()
	if mode != "pve" or not is_instance_valid(hud):
		return
	pve_paused = true
	mouse_firing = false
	clear_shots()
	hud.show_pause(true)

func resume_pve() -> void:
	if mode != "pve":
		return
	hud.show_pause(false)
	mouse_firing = false
	clear_shots()
	pve_paused = false
	arena.capture_motion(rules)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		go_background(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		go_background(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_skins()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Back during a tutorial skips it, like its own SALTAR.
		if hud.tutorial_running():
			hud.tutorial.close(true)
			return
		# Back during a story conversation skips it too.
		if hud.story_talk_running():
			hud.story_talk.close(true)
			return
		request_menu()

func host_game() -> void:
	close_cup_screen()
	close_network()
	mode = "host"
	local_team = 0
	arena.set_view_team(local_team)
	leave_campaign(Rules.pvp_map())
	use_loadouts(PowerShop.STARTER_KIT.duplicate())
	rules.reset_match()
	dress_pilots(local_team)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 1)
	if error != OK:
		hud.show_menu("Não foi possível criar a sala. A porta pode estar ocupada.")
		return
	multiplayer.multiplayer_peer = peer
	network_status = "À espera do rival…"
	hud.show_game(mode, local_team)
	music.play_skin(skins.selected)
	var addresses: PackedStringArray = []
	for address in IP.get_local_addresses():
		if ":" not in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	hud.menu_status.text = "IP desta sala: " + ", ".join(addresses)
	# Host address stays visible while waiting, in the status panel.
	if addresses.size() > 0:
		network_status = "IP: " + addresses[0]
	print("HOST_READY port=", PORT)

func join_game(address: String) -> void:
	close_cup_screen()
	if address.is_empty():
		hud.show_menu("Escreve o IP do telemóvel ou PC que criou a partida.")
		return
	close_network()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		hud.show_menu("Não foi possível iniciar a ligação a esse IP.")
		return
	multiplayer.multiplayer_peer = peer
	mode = "client"
	local_team = 1
	arena.set_view_team(local_team)
	connection_timer = 10.0
	network_status = "A ligar ao rival…"
	leave_campaign(Rules.pvp_map())
	use_loadouts(PowerShop.STARTER_KIT.duplicate())
	rules.reset_match()
	dress_pilots(local_team)
	hud.show_game(mode, local_team)
	music.play_skin(skins.selected)

func peer_connected(id: int) -> void:
	if mode == "host":
		remote_id = id
		connected = true
		network_status = ""
		rules.reset_match()
		if PowerShop.START_WITH_ULTIMATE_FOR_TESTS:
			# The match restarts when the guest arrives, and that wipes the charge the
			# testing build hands out: without this, PvP begins with dead ultimate keys.
			charge_ultimates()
		share_skin.rpc_id(id, skins.selected)
		share_kit.rpc_id(id, String(power_shop.kit[0]), String(power_shop.kit[1]))
		print("HOST_PEER_CONNECTED ", id)

func joined_server() -> void:
	if mode == "client":
		connected = true
		network_status = ""
		share_skin.rpc_id(1, skins.selected)
		share_kit.rpc_id(1, String(power_shop.kit[0]), String(power_shop.kit[1]))
		print("CLIENT_CONNECTED")

func peer_disconnected(_id: int) -> void:
	if mode == "host" or mode == "client":
		return_to_menu.call_deferred("O outro jogador desligou-se. Podes criar uma nova partida.")

func replay() -> void:
	if cup_active:
		start_cup()
		return
	if mode == "pve" and bool(story_run.get("training", false)):
		begin_training()
		return
	if mode == "pve" and not story_run.is_empty():
		# A rematch goes straight back in; the lines were said the first time.
		start_story(int(story_run.step), bool(story_run.hard), false)
		return
	if mode == "pve" and level_index >= 0:
		start_level(level_index)
		return
	if mode == "pve" or mode == "host":
		rules.reset_match()
		hud.reset_touch()
		mouse_firing = false

func _input(event: InputEvent) -> void:
	last_input_ms = Time.get_ticks_msec()
	# Release even if the pointer ends over a UI button.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		mouse_firing = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Touch is emulated into mouse clicks so the menu buttons work on a phone.
		# The HUD already reads the real touches, so ignore the emulated copies.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		mouse_firing = event.pressed and mode != "menu"
		if mouse_firing:
			pending_clicks += 1

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey and mode == "menu" and not hud.menu_overlay_open():
		if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
			step_menu_level(-1 if event.keycode == KEY_LEFT else 1)
			return
	if event.is_pressed() and not event.is_echo() and event is InputEventKey and mode != "menu":
		if event.keycode == KEY_SPACE:
			pending_clicks += 1
			return
		# On a PC the three powers are on the number keys; phones use the HUD buttons.
		var slot = [KEY_1, KEY_2, KEY_3].find(event.keycode)
		if slot < 0:
			slot = [KEY_KP_1, KEY_KP_2, KEY_KP_3].find(event.keycode)
		if slot >= 0:
			hud.request_power(slot)
			return
	if event.is_pressed() and event is InputEventKey and event.keycode == KEY_ESCAPE:
		if hud.video_overlay.visible:
			hud.close_video()
		elif hud.skins_overlay.visible:
			hud.close_skins()
		elif hud.levels_overlay.visible:
			hud.close_levels()
		elif hud.powers_overlay.visible:
			hud.close_powers()
		elif hud.pvp_overlay.visible:
			hud.close_pvp()
		elif pve_paused:
			resume_pve()
		else:
			request_menu()

func dress_pilots(team: int) -> void:
	# The local pilot wears the chosen skin; the rival stays default until PvP shares theirs.
	arena.set_skin(team, worn_skin())
	arena.set_skin(1 - team, 0)

func select_skin(index: int) -> void:
	if not skins.select(index):
		return
	save_skins()
	hud.sync_skins(skins)
	if mode == "menu":
		arena.set_skin(0, index)
		refresh_showroom()

func bank_bricks() -> void:
	# Bricks destroyed in any mode are the shop currency; they are banked as they fall.
	var earned: int = int(rules.powers[local_team].destroyed) - credited_bricks
	if earned <= 0:
		return
	credited_bricks += earned
	var could: Array = power_shop.affordable().map(func(e): return String(e.id))
	power_shop.add_bricks(earned)
	hud.sync_powers(power_shop)
	# A power the wallet has just reached gets a notice, once, pointing at the shop.
	for entry in power_shop.affordable():
		if not could.has(String(entry.id)):
			hud.announce_affordable(String(entry.id), String(entry.name), int(entry.price))

func save_powers() -> void:
	if power_shop.save_preferences() != OK:
		push_warning("Could not save power progress to " + power_shop.config_path)

func buy_power(id: String) -> void:
	if not power_shop.buy(id):
		return
	hud.announce_power(id, PowerShop.CATALOG[PowerShop.index_of(id)].name)
	save_powers()
	hud.sync_powers(power_shop)

func equip_power(slot: int, id: String) -> void:
	if not power_shop.equip(slot, id):
		return
	save_powers()
	hud.sync_powers(power_shop)

func save_skins() -> void:
	if skins.save_preferences() != OK:
		push_warning("Could not save skin progress to " + skins.config_path)

@rpc("any_peer", "call_remote", "reliable")
func share_skin(skin: int) -> void:
	if mode != "host" and mode != "client":
		return
	if mode == "host" and multiplayer.get_remote_sender_id() != remote_id:
		return
	if skin < 0 or skin >= Skins.CATALOG.size():
		return
	arena.set_skin(1 - local_team, skin)
	# The rival's third key is the ultimate of the skin it just showed.
	var kit: Array = rules.loadouts[1 - local_team]
	rules.loadouts[1 - local_team] = [kit[0], kit[1], String(Skins.CATALOG[skin].ultimate)]

@rpc("any_peer", "call_remote", "reliable")
func share_kit(first: String, second: String) -> void:
	# The two bought powers the rival brought; the ultimate rides with the skin.
	if mode != "host" and mode != "client":
		return
	if mode == "host" and multiplayer.get_remote_sender_id() != remote_id:
		return
	var kit: Array = [first, second]
	for id in kit:
		if PowerShop.index_of(id) < 0:
			return
	rules.loadouts[1 - local_team] = kit + [rules.power_id(1 - local_team, 2)]

func fit_content_scale() -> void:
	# Keep 720 HUD units on the short side, whichever way the screen is held.
	var window = get_window()
	window.content_scale_size = Vector2i(720, 1280) if window.size.y > window.size.x else Vector2i(1280, 720)

func preview_world(world: String) -> void:
	# The map picker shows the world it would play in, the camera touring it.
	use_map(Rules.quick_map(world))
	arena.start_tour()

func frame_arena() -> void:
	arena.unsteer()
	if hud.mode == "menu" and hud.map_overlay.visible:
		arena.start_tour()
	elif hud.mode == "menu":
		arena.frame_lobby(hud.lobby_stage(), hud.size)
	elif hud.vertical:
		arena.frame_rect(hud.arena_rect, hud.size, hud.mode == "menu")
	else:
		arena.frame_landscape(-4.5 if hud.mode == "menu" else 0.0)
	arena.match_seat = hud.mode != "menu"
	arena.remember_seat()
	arena.steer_view(game_settings.view_yaw, game_settings.view_zoom)
	if game_settings.view_chase and arena.match_seat and not arena.chase:
		arena.set_chase(true)

# How far the player keeps pulling in past the closest zoom before the camera drops behind
# the pilot (third person), and how far it has to be pushed back out to leave it.
const CHASE_PAST = 1.35
const CHASE_LEAVE = 0.72
var chase_push = 1.0

func steer_camera(dt: float) -> void:
	# Steered on the map itself: a finger dragged sideways turns round the arena, up pulls
	# in, down pulls back; two fingers pinch. Pulling in past the closest zoom puts the
	# camera behind the pilot, following it and looking where it aims; pulling back out
	# leaves. The turn and zoom are kept for the next match; a double tap puts them back.
	if mode == "menu":
		return
	if hud.camera_reset:
		hud.camera_reset = false
		game_settings.view_yaw = 0.0
		game_settings.view_zoom = 1.0
		game_settings.view_chase = false
		leave_chase()
		arena.steer_view(0.0, 1.0)
		save_game_settings()
		return
	var drag: Vector2 = hud.camera_drag
	var pinch: float = hud.camera_zoom
	hud.camera_drag = Vector2.ZERO
	hud.camera_zoom = 1.0
	arena.chase_held = not hud.camera_touches.is_empty()
	# The turn is a look, not a setting: let go and the view swings back to its seat
	# (the zoom stays where it was left).
	if not arena.chase and hud.camera_touches.is_empty() and game_settings.view_yaw != 0.0:
		game_settings.view_yaw = lerpf(game_settings.view_yaw, 0.0, 1.0 - exp(-dt * 5.0))
		if absf(game_settings.view_yaw) < 0.002:
			game_settings.view_yaw = 0.0
		arena.steer_view(game_settings.view_yaw, game_settings.view_zoom)
	if drag == Vector2.ZERO and is_equal_approx(pinch, 1.0):
		# Saved once the finger lifts: saving syncs the HUD, which drops every touch, and a
		# held look (or stick) would snap back as if let go.
		if hud.camera_moved and hud.camera_touches.is_empty():
			hud.camera_moved = false
			save_game_settings()
		return
	hud.camera_moved = true
	var step: float = exp(-drag.y * 0.006) * pinch
	if arena.chase:
		# Sideways looks round the pilot (it swings back when the finger lifts); only a
		# mostly vertical pull back, or a pinch, leaves third person.
		arena.chase_look = clampf(arena.chase_look - drag.x * 0.006, -arena.CHASE_LOOK_MAX, arena.CHASE_LOOK_MAX)
		if is_zero_approx(drag.y) and is_equal_approx(pinch, 1.0):
			return
		chase_push = chase_push * step if step < 1.0 else 1.0
		if chase_push < CHASE_LEAVE:
			game_settings.view_zoom = arena.VIEW_ZOOM_MAX * 0.9
			leave_chase()
		return
	game_settings.view_yaw = clampf(game_settings.view_yaw - drag.x * 0.005, -arena.VIEW_YAW_MAX, arena.VIEW_YAW_MAX)
	var wanted: float = game_settings.view_zoom * step
	if wanted > arena.VIEW_ZOOM_MAX and game_settings.view_zoom >= arena.VIEW_ZOOM_MAX - 0.001:
		chase_push *= step
		if chase_push > CHASE_PAST:
			chase_push = 1.0
			game_settings.view_chase = true
			arena.set_chase(true)
	else:
		chase_push = 1.0
	game_settings.view_zoom = clampf(wanted, arena.VIEW_ZOOM_MIN, arena.VIEW_ZOOM_MAX)
	arena.steer_view(game_settings.view_yaw, game_settings.view_zoom)

func leave_chase() -> void:
	chase_push = 1.0
	game_settings.view_chase = false
	if arena.chase:
		arena.set_chase(false)
		frame_arena()

func change_difficulty(level: int) -> void:
	game_settings.configure(level, game_settings.aim_guide)
	rules.ai_level = game_settings.difficulty
	if level_index >= 0 and story_run.is_empty():
		rules.ai_profile = Campaign.ai_profile(level_index, game_settings.difficulty)
	if cup_active:
		rules.ai_profile = cup.profile(game_settings.difficulty)
	save_game_settings()

func sync_assist() -> void:
	# PvE and PvP alike: only the pilot on this device gets the magnetism.
	rules.assist_team = local_team if (game_settings.aim_assist and mode != "menu") else -1

func change_guide(on: bool) -> void:
	game_settings.configure(game_settings.difficulty, on)
	arena.guide_enabled = on
	save_game_settings()

func change_fire_layout(control: int, radius_scale: float, x: float, y: float) -> void:
	game_settings.fire_control = clampi(control, 0, 1)
	game_settings.fire_size = clampf(radius_scale, 0.7, 1.5)
	game_settings.fire_x = clampf(x, 0.0, 1.0)
	game_settings.fire_y = clampf(y, 0.0, 1.0)
	save_game_settings()

func change_feedback(camera: int, haptics: bool, automatic: bool, volume: float) -> void:
	game_settings.camera_feedback = camera
	game_settings.haptics = haptics
	if not haptics: stop_haptics()
	game_settings.auto_fire = automatic
	game_settings.sfx_volume = volume
	hud.story_voice_db = linear_to_db(maxf(volume, 0.0001))
	arena.shake_scale = [0.0, 0.45, 1.0][camera]
	if camera == 0: arena.shakes.clear()
	mouse_firing = false
	clear_shots()
	save_game_settings()

func change_effects(full: bool) -> void:
	game_settings.effects_full = full
	feel.intensity = 1.0 if full else 0.6
	save_game_settings()

var feel_panel

func open_feel_tuning() -> void:
	if not is_instance_valid(feel_panel):
		feel_panel = preload("res://scripts/feel_panel.gd").new()
		hud.add_child(feel_panel)
	feel_panel.open(feel)

func haptic(milliseconds: int, strength: float) -> void:
	if not game_settings.haptics or mode == "menu" or not OS.has_feature("android"):
		return
	var now = Time.get_ticks_msec()
	if now < haptic_next_ms and strength <= haptic_strength: return
	haptic_next_ms = now + maxi(110, milliseconds + 55)
	haptic_strength = strength
	haptic_pulse_until = now + milliseconds
	sustained_next_ms = haptic_pulse_until + 15
	Input.vibrate_handheld(milliseconds, strength)

func stop_haptics() -> void:
	if OS.has_feature("android"): Input.vibrate_handheld(0)
	sustained_haptic = false
	sustained_next_ms = 0
	haptic_pulse_until = 0
	haptic_next_ms = 0

static func sustained_haptic_profile(state: Dictionary) -> Vector3:
	# x = pulse duration, y = refresh interval in ms, z = amplitude.
	# Beam pulses overlap for a continuous feel; other powers keep a distinct rhythm.
	if state.laser_time > 0.0: return Vector3(130, 95, 0.20)
	if state.ultimate_time > 0.0:
		match String(state.ultimate_id):
			"sun_ray": return Vector3(150, 105, 0.32)
			"sun_beam": return Vector3(120, 105, 0.24)
			"singularity": return Vector3(65, 170, 0.25)
	if state.rapid_time > 0.0: return Vector3(12, 115, 0.17)
	if state.surge_time > 0.0: return Vector3(20, 190, 0.20)
	return Vector3.ZERO

func update_sustained_haptics() -> void:
	if not OS.has_feature("android"): return
	if not game_settings.haptics or mode == "menu" or pve_paused or hud.video_overlay.visible or not get_window().has_focus():
		if sustained_haptic or haptic_pulse_until > 0: stop_haptics()
		return
	var now = Time.get_ticks_msec()
	var profile = sustained_haptic_profile(rules.powers[local_team]) if rules.phase == "play" else Vector3.ZERO
	if profile == Vector3.ZERO:
		if sustained_haptic:
			# Do not cancel a stronger goal/impact pulse that replaced the beam.
			if now >= haptic_pulse_until: Input.vibrate_handheld(0)
			sustained_haptic = false
		return
	if now < sustained_next_ms or now < haptic_pulse_until: return
	Input.vibrate_handheld(int(profile.x), profile.z)
	sustained_haptic = true
	sustained_next_ms = now + int(profile.y)

func update_feedback_mix(dt: float) -> void:
	release_focus = maxf(0.0, release_focus - dt)
	var focus = release_focus > 0.0
	for state in rules.powers:
		if state.ultimate_windup > 0.0 and state.ultimate_windup < 0.18: focus = true
	arena_duck_db = move_toward(arena_duck_db, feel.get_value("ultimate_duck_db") if focus else 0.0, dt * (70.0 if focus else 24.0))
	var volume = linear_to_db(maxf(game_settings.sfx_volume, 0.0001))
	for voice in audio_voices:
		if voice.playing:
			voice.volume_db = float(voice.get_meta("mix_gain", -18.0)) + volume + (arena_duck_db if voice.get_meta("secondary", false) else 0.0)

func change_sensitivity(level: int) -> void:
	game_settings.configure(game_settings.difficulty, game_settings.aim_guide, level)
	save_game_settings()

func save_game_settings() -> void:
	if game_settings.save_preferences() != OK:
		hud.video_note.text = "Aplicado nesta sessão. Não foi possível guardar as opções."
	hud.sync_game(game_settings)

func change_audio(on: bool, volume: float) -> void:
	music.configure(on, volume)
	var error = music.save_preferences()
	hud.sync_audio(music)
	if error != OK:
		hud.video_note.text = "Aplicado nesta sessão. Não foi possível guardar as opções."

func change_video(fps: int, quality: int, sync: bool, counter: bool, shadows: bool = false) -> void:
	video.configure(fps, quality, sync, counter, 1 if shadows else 0)
	video.apply(get_viewport(), arena)
	hud.smooth = video.smooth_hud
	hud.queue_redraw()
	var error = video.save_preferences()
	hud.sync_video(video)
	if error != OK:
		hud.video_note.text = "Aplicado nesta sessão. Não foi possível guardar as opções."

func play_events() -> void:
	# Sound and spectacle for whatever just happened. The host runs this off its own
	# simulation; the client runs it off the events the host ships with each snapshot,
	# which is the only way it sees a power go off at all.
	for event in rules.events:
		ArenaView.CombatFinish.event(arena, event, rules)
		if event.kind == "shot":
			# weapon_fired: the one moment every layer answers at once — sound, recoil,
			# muzzle, camera, button and (when the player pulls the trigger themselves) a
			# micro pulse under the thumb. Auto-fire gets no buzz: it would never stop.
			var team = int(event.team)
			# Which robot fired: a leader (its team) or, on the 3 v 3 arena, a wingman. There
			# the player only watches, so no shot is theirs.
			var pilot = int(event.get("pilot", team))
			var mine = team == local_team and pilot == local_team and not rules.squad
			arena.shot_feedback(team, mine, pilot)
			if int(event.get("power", 0)) == 4:
				arena.sniper_fire(team)
			if mine:
				hud.fire_age = 0.0
				if not game_settings.auto_fire:
					haptic(int(feel.get_value("haptic_fire_ms")), feel.get_value("haptic_fire_strength"))
			var skin = int(arena.unit_skins[team])
			# Intermediate opponents share the Aurora base, never a missing sample.
			if skin >= Skins.CATALOG.size(): skin = 0
			skin = Skins.base_of(skin)
			var variant = int(shot_variants[team]) % 3
			shot_variants[team] += 1
			play_tone("shot_%d_%d" % [skin, variant], (-9.0 if rules.squad else (0.0 if team == local_team else -5.0)), true)
		elif event.kind == "boost":
			play_tone("boost")
		elif event.kind in ["bounce", "spent"]:
			# A ricochet tells the trajectory; it never competes with a break.
			arena.impact_feedback(event)
			play_tone("metal" if event.get("surface", "") == "obstacle" else "ricochet", -1.5, true)
			if int(event.get("power", 0)) == 6:
				arena.ricochet_spark(event.p, event.get("heading", Vector2.UP))
		elif event.kind == "player_hit":
			arena.impact_feedback(event)
			play_tone("shield")
		elif event.kind == "power":
			# Both sides are announced: a power launched at you should never be silent.
			arena.power_flash(event.p, String(event.get("id", "")))
			var ability_cue = "ability_" + String(event.get("id", ""))
			play_tone(ability_cue if tones.has(ability_cue) else "power")
			arena.shake_level(GameFeel.Level.POWER)
			if int(event.team) == local_team: haptic(int(feel.get_value("haptic_power_ms")), feel.get_value("haptic_power_strength"))
		elif event.kind == "laser":
			arena.laser_beam(event.p, event.heading, event.team)
			play_tone("laser_tick", -2.0)
		elif event.kind == "rebuild":
			var back: Array = event.bricks.map(func(i): return rules.bricks[i].p)
			arena.rebuild_flash(back)
			for spot in back:
				arena.gain_mark(spot, int(event.get("gain", 0)), Rules.power_color("rebuild"))
		elif event.kind == "mirror":
			arena.impact_feedback(event)
			play_tone("shield")
		elif event.kind == "shock":
			arena.shock_pulse(event.p)
		elif event.kind == "ultimate_charge":
			# Two seconds of rising charge, heard by both sides.
			play_tone("charging")
		elif event.kind == "ultimate":
			# The arena steps back for a beat so the ultimate's own sound comes through.
			release_focus = feel.get_value("ultimate_duck_seconds")
			arena.shake_level(GameFeel.Level.ULTIMATE)
			arena.ultimate_accent(event.p, String(event.get("id", "")))
			if int(event.team) == local_team:
				haptic(48 if String(event.get("id", "")) in ["meteors", "sun_ray", "sun_beam", "singularity"] else 30, 0.55)
			# A hard-mode skin's ultimate sounds deeper and heavier than its boss's.
			var hard_skin = Skins.CATALOG[clampi(int(arena.unit_skins[int(event.team)]), 0, Skins.CATALOG.size() - 1)].has("hard_of") if int(arena.unit_skins[int(event.team)]) < Skins.CATALOG.size() else false
			var pitch = 0.8 if hard_skin else 1.0
			play_tone("unleash", 0.0, false, pitch)
			if tones.has(String(event.get("id", ""))):
				play_tone(String(event.id), 1.5 if hard_skin else 0.0, false, pitch)
		elif event.kind == "sun_ray":
			# The beam is drawn from the gun; this is the discharge around it.
			arena.sun_ray(event.p, event.heading, event.width)
			play_tone("sun_ray")
		elif event.kind == "meteor":
			arena.meteor_fall(event.p, event.radius, randf() < 0.5)
			if int(event.team) == local_team: haptic(28, 0.38)
			# Fourteen rocks in a second would be a wall of noise: every other one sounds.
			if randf() < 0.5:
				play_tone("meteor")
		elif event.kind == "thunder":
			arena.thunder_bolt(event.p, event.radius)
			if int(event.team) == local_team: haptic(35, 0.55)
			play_tone("thunder")
		elif event.kind == "singularity":
			arena.singularity_open(event.p)
		elif event.kind == "singularity_wave":
			arena.singularity_wave(event.p, int(event.index), float(event.seconds))
			if int(event.team) == local_team: haptic(45, 0.50)
			play_tone("void_wave")
		elif event.kind == "swallow":
			arena.singularity_swallow(event.p)
		elif event.kind == "turret_shot":
			# Lighter than the pilot's gun, so a wall of sentry fire stays readable.
			play_tone("sentry")
		elif event.kind == "turret_hit":
			play_tone("power")
		elif event.kind == "turret_down":
			arena.sentry_down(event.p, int(event.team))
			play_tone("blast")
		elif event.kind == "bloom":
			arena.bloom_flash(event.bricks.map(func(i): return rules.bricks[i].p), event.heal)
		elif event.kind == "plunder":
			arena.plunder_flash(event.team)
		elif event.kind == "surge":
			arena.surge_flash(event.p)
			arena.gain_mark(event.p, int(event.get("gain", 0)), Rules.power_color("surge"))
			play_tone("boost")
		elif event.kind == "missile_launch":
			arena.missile_launch(int(event.team), event.at, float(event.seconds))
			if int(event.team) == local_team: haptic(18, 0.3)
			play_tone("volley")
		elif event.kind == "missile":
			arena.rocket_impact(event.p, float(event.radius), false)
			play_tone("blast")
		elif event.kind == "bazooka_fire":
			arena.bazooka_fire(int(event.team), event.at, float(event.seconds), float(event.windup))
			if int(event.team) == local_team: haptic(40, 0.6)
		elif event.kind == "bazooka":
			arena.rocket_impact(event.p, float(event.radius), true)
			if int(event.team) == local_team: haptic(45, 0.6)
			play_tone("void_burst")
		elif event.kind == "volley":
			arena.volley_flash(event.p, event.heading)
			if int(event.team) == local_team: haptic(18, 0.30)
			play_tone("power")
		elif event.kind == "weld":
			var mended: Array = event.bricks.map(func(i): return rules.bricks[i].p)
			arena.weld_flash(mended)
			for spot in mended:
				arena.gain_mark(spot, int(event.get("heal", 0)), Rules.power_color("weld"))
			play_tone("ability_weld")
		elif event.kind == "freeze":
			arena.frost_flash(event.p)
			play_tone("ability_freeze")
		elif event.kind == "magnet":
			arena.magnet_flash(event.p)
			play_tone("ability_magnet")
		elif event.kind == "thorns":
			arena.thorns_flash(int(event.team))
			play_tone("ability_thorns")
		elif event.kind == "thorns_bite":
			arena.burst(event.p, Rules.power_color("thorns"), false)
		elif event.kind == "plating":
			arena.plating_flash(event.team)
			arena.gain_mark(event.p, int(event.get("gain", 0)), Rules.power_color("plating"))
			play_tone("power")
		elif event.kind == "shock_wave":
			arena.shock_wave(event.p, event.get("marks", []), 1 - int(event.team))
			play_tone("void_burst")
		elif event.kind == "plunder_land":
			arena.plunder_land(event.team)
			play_tone("power")
		elif event.kind == "drain":
			arena.drain_beam(event.get("from", event.p), event.p, bool(event.get("interrupted", false)))
			if event.get("interrupted", false):
				play_tone("void_burst")
		elif event.kind == "emp":
			arena.emp_flash(event.get("target", event.p))
		elif event.kind == "mortar_launch":
			arena.mortar_shell(event.p, event.target, float(event.get("flight", 0.9)))
		elif event.kind == "mortar":
			arena.mortar_impact(event.p, float(event.get("radius", 1.0)))
			arena.shake_level(GameFeel.Level.POWER)
			play_tone("blast")
		elif event.kind == "cluster":
			arena.cluster_flash(event.p)
			play_tone("blast", -4.0)
		elif event.kind == "absorb":
			arena.absorb_flash(event.p, int(event.team))
			play_tone("shield", -3.0, true)
		elif event.kind == "immune":
			arena.immune_flash(event.p, true)
		elif event.kind == "immune_block":
			arena.immune_block(int(event.team), event.p)
			play_tone("shield")
		elif event.kind == "sniper_hit":
			arena.sniper_hit(event.p, event.get("heading", Vector2.UP))
		elif event.kind == "power_ready" and event.team == local_team:
			play_tone("ready")
		elif event.kind in ["brick", "brick_hit"]:
			if event.get("soaked", false) and rules.powers[int(event.team)].dome_time > 0:
				arena.dome_ripple(int(event.team), event.p)
			arena.impact_feedback(event)
			impact_variant = (impact_variant + 1) % 3
			if event.get("soaked", false):
				play_tone("shield", 0.0, true)
			else:
				# THOCK on every hit; when the brick gives, the CRACK lands a beat after it.
				play_tone("hit_" + str(impact_variant), 0.0, true)
				if event.kind == "brick":
					var crack = "break_" + str(impact_variant)
					arena.schedule(0.028, func(): play_tone(crack, 0.0, true))
			if event.kind == "brick":
				var team = int(event.team)
				break_times[team] = rules.elapsed
				# The player feels the bricks they break, not their own wall crumbling.
				if team != local_team: haptic(int(feel.get_value("haptic_destroy_ms")), feel.get_value("haptic_destroy_strength"))
			if event.get("defense_open", false):
				arena.schedule(feel.get_value("hitstop_last_brick"), func(): play_tone("defense"))
				haptic(int(feel.get_value("haptic_destroy_ms")) + 14, minf(1.0, feel.get_value("haptic_destroy_strength") + 0.15))
				hud.defense_notice = "DEFESA ABERTA — ATACA A BALIZA!" if int(event.team) != local_team else "A TUA BALIZA ESTÁ DESPROTEGIDA!"
				hud.defense_notice_time = 1.25
			if int(event.get("bite", 0)) > 0:
				arena.damage_mark(int(event.team), event.p, int(event.bite))
		elif event.kind == "explosion":
			arena.explosion(event.p, event.radius)
			play_tone("blast")

func local_command() -> Dictionary:
	if hud.video_overlay.visible or pve_paused:
		# Drop anything tapped while the match was on hold.
		hud.take_power()
		hud.fire_tap = false
		hud.fire_id = -1
		return {"move": Vector2.ZERO, "fire": false, "power": -1}
	# Past a small dead zone the pilot leaves at once: the first sliver of the push is
	# already worth a third of the speed, so nudging the stick never feels like nothing
	# happened. From there it climbs almost straight to a full run.
	var stick: float = hud.move_vector.x
	var response = 0.0
	if absf(stick) > STICK_DEADZONE:
		var push = (absf(stick) - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
		response = signf(stick) * lerpf(STICK_FLOOR, 1.0, pow(push, 1.2)) * game_settings.sensitivity_scale()
	else:
		# Thumb still: let the magnetism settle the pilot on the target it is beside.
		response = magnet_pull()
	# The second PvP pilot looks at the arena from the other end, so right on their screen
	# is left in the world. The magnet already speaks world directions and is left alone.
	var screen_side = -1.0 if arena.view_team == 1 else 1.0
	if absf(stick) > STICK_DEADZONE:
		response *= screen_side
	var move = Vector2(response, 0)
	if DisplayServer.get_name() != "headless":
		var keys = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		move += keys * screen_side
	# Manual fire: every tap is one shot, from the button, the joystick, the mouse or the
	# space bar.
	pending_clicks += hud.fire_taps
	hud.fire_taps = 0
	var clicks: int = 0 if game_settings.auto_fire else mini(pending_clicks, MAX_QUEUED_SHOTS)
	pending_clicks = 0
	var fire: bool = game_settings.auto_fire
	if mode != "client":
		for click in range(clicks):
			queue_shot(local_team)
		fire = fire or take_queued_shot(local_team)
	return {"move": Vector2(clampf(move.x, -1, 1), 0), "fire": fire, "tap": clicks > 0, "clicks": clicks, "manual": not game_settings.auto_fire, "power": read_power()}

func queue_shot(team: int) -> void:
	queued_shots[team] = mini(int(queued_shots[team]) + 1, MAX_QUEUED_SHOTS)
	queued_until[team] = Time.get_ticks_msec() + FIRE_BUFFER_MS

func take_queued_shot(team: int) -> bool:
	if int(queued_shots[team]) <= 0:
		return false
	if Time.get_ticks_msec() > int(queued_until[team]):
		# Taps from long ago are not fired late: that would feel like the gun going off by itself.
		queued_shots[team] = 0
		return false
	if not rules.can_fire(team, 1.0 / Engine.physics_ticks_per_second):
		return false
	queued_shots[team] = int(queued_shots[team]) - 1
	# The next tap in the queue gets its own window from here.
	queued_until[team] = Time.get_ticks_msec() + FIRE_BUFFER_MS
	return true

func clear_shots() -> void:
	queued_shots = [0, 0]
	queued_until = [0, 0]
	pending_clicks = 0

func read_power() -> int:
	# A key pressed a moment too early — during the countdown, or while another power is
	# still running — used to be swallowed without a word. It is now held for half a
	# second and tried again, which is the difference between a power that feels broken
	# and one that simply waited its turn.
	var asked: int = hud.take_power()
	if asked >= 0:
		held_power = asked
		held_power_until = Time.get_ticks_msec() + POWER_HOLD_MS
	if held_power < 0:
		return -1
	if Time.get_ticks_msec() > held_power_until:
		held_power = -1
		return -1
	if not rules.can_activate_power(local_team, held_power):
		return -1
	var ready = held_power
	held_power = -1
	return ready

func magnet_pull() -> float:
	# With the thumb nearly still, the pilot eases onto the nearest firing angle instead
	# of hovering a hair beside it. It never fights a real push of the stick.
	if not game_settings.aim_assist or rules.players.size() <= local_team:
		return 0.0
	var player: Dictionary = rules.players[local_team]
	var best = INF
	var best_gap = MAGNET_ANGLE
	for option in rules.firing_angles(local_team):
		var gap: float = absf(option.angle - player.angle)
		if gap < best_gap:
			best_gap = gap
			best = option.angle
	if best == INF:
		return 0.0
	return clampf((best - player.angle) * 5.0, -0.35, 0.35)

func _physics_process(dt: float) -> void:
	if mode == "menu":
		return
	if mode == "pve" and (hud.video_overlay.visible or pve_paused):
		return
	if mode == "client" and not connected:
		connection_timer -= dt
		if connection_timer <= 0:
			return_to_menu("A ligação demorou demasiado. Confirma o IP e a rede Wi-Fi.")
		return
	if mode == "host" and not connected:
		return
	var command = local_command()
	if mode == "client":
		for click in range(int(command.get("clicks", 0))):
			submit_fire_tap.rpc_id(1)
		if command.power >= 0:
			submit_power.rpc_id(1, command.power)
		network_tick += dt
		if network_tick >= 1.0 / 30:
			network_tick = 0
			submit_input.rpc_id(1, command.move, command.fire)
		return
	if mode == "pve" and rules.squad:
		# 3 contra 3: every pilot is the AI's, the player's seat included - they watch.
		var squad_commands: Array = []
		for index in range(rules.players.size()):
			squad_commands.append(rules.squad_command(index) if not pause_ai else {"move": Vector2.ZERO, "fire": false})
		arena.capture_motion(rules)
		rules.step(dt, squad_commands)
		play_events()
		return
	var other: Dictionary
	if mode == "pve":
		other = rules.ai_command() if not pause_ai else {"move": Vector2.ZERO, "fire": false}
	else:
		remote_age += dt
		var stale = remote_age >= 0.35
		# The rival's key gets the same half second of patience the local one does: pressed
		# during the countdown, or while another power is running, it used to vanish on the
		# host without the guest ever knowing why.
		var remote_slot = -1
		if remote_power >= 0:
			if Time.get_ticks_msec() > remote_power_until:
				remote_power = -1
			elif rules.can_activate_power(1 - local_team, remote_power):
				remote_slot = remote_power
				remote_power = -1
		# The guest's taps are manual shots like the host's own: without the flag the host fired
		# them at the slower automatic cadence, so only the host had the quick tap fire.
		var remote_tap = false if (not stale and remote_command.fire) else take_queued_shot(1 - local_team)
		other = {"move": Vector2.ZERO if stale else remote_command.move, "fire": (false if stale else remote_command.fire) or remote_tap, "manual": remote_tap, "power": remote_slot}
	arena.capture_motion(rules)
	rules.step(dt, [command, other])
	bank_bricks()
	play_events()
	if mode == "host":
		# Events happen every tick but packets leave at 20 Hz, so they are kept until the
		# next one goes out. Capped, because a meteor shower must not inflate a packet.
		if pending_events.size() < 80:
			pending_events.append_array(rules.events)
		network_tick += dt
		if network_tick >= 1.0 / 20:
			network_tick = 0
			# Already-packed numeric arrays avoid a synchronous DEFLATE spike every 50 ms.
			var packet: Dictionary = rules.network_snapshot()
			packet["e"] = pending_events
			pending_events = []
			receive_state.rpc_id(remote_id, packet)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(move: Vector2, firing: bool) -> void:
	if mode != "host" or multiplayer.get_remote_sender_id() != remote_id:
		return
	if not move.is_finite():
		return
	remote_command = {"move": Vector2(clampf(move.x, -1, 1), 0), "fire": firing}
	remote_age = 0
	packets_received += 1

@rpc("any_peer", "call_remote", "reliable")
func submit_fire_tap() -> void:
	if mode == "host" and multiplayer.get_remote_sender_id() == remote_id:
		queue_shot(1 - local_team)

@rpc("any_peer", "call_remote", "reliable")
func submit_power(power: int) -> void:
	# Reliable and separate: a dropped movement packet must not swallow a power.
	if mode != "host" or multiplayer.get_remote_sender_id() != remote_id:
		return
	if power < 0 or power >= Rules.POWER_SLOTS:
		return
	remote_power = power
	remote_power_until = Time.get_ticks_msec() + POWER_HOLD_MS

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_state(data: Dictionary) -> void:
	if mode != "client":
		return
	arena.capture_motion(rules)
	if not rules.apply_network_snapshot(data):
		return
	# The client does not simulate, so without these it never sees a shot, a power or an
	# ultimate happen: no flash, no sound, nothing.
	var carried = data.get("e", [])
	# Left in place until the next packet overwrites them: they are what the arena and the
	# HUD read to know what just happened.
	rules.events = carried if typeof(carried) == TYPE_ARRAY else []
	play_events()
	visual_packet_age = 0.0
	packets_received += 1

const IDLE_FPS = 30
# Nobody has touched the screen for this long on a resting screen: paint it at a crawl.
const DOZE_SECONDS = 25.0
const DOZE_FPS = 10
# In the background: one frame a second, just enough to hear the system bring it back.
const BACKGROUND_FPS = 1
var last_input_ms = 0
var backgrounded = false
var screen_kept_on = true

func idle_frame_rate() -> void:
	# Outside a live match — menu, shop, skins, pause, a finished round — the screen is
	# nearly still, and there is no reason to paint it 120 times a second. Left alone it
	# dozes at 10, and it lets the phone switch the screen off like any other app; only a
	# live match keeps the screen awake.
	if backgrounded:
		if Engine.max_fps != BACKGROUND_FPS:
			Engine.max_fps = BACKGROUND_FPS
		return
	var resting: bool = mode == "menu" or pve_paused or hud.video_overlay.visible or network_status != "" \
		or (rules != null and rules.phase == "finished")
	var dozing: bool = resting and Time.get_ticks_msec() - last_input_ms > DOZE_SECONDS * 1000.0
	var wanted: int = (DOZE_FPS if dozing else IDLE_FPS) if resting else video.runtime_fps
	if Engine.max_fps != wanted:
		Engine.max_fps = wanted
	if screen_kept_on == resting:
		screen_kept_on = not resting
		DisplayServer.screen_set_keep_on(screen_kept_on)
	# The lobby's robots are the showcase: at the resting rate they can afford smooth
	# edges on every profile. A match keeps the antialiasing the chosen profile pays for.
	var wanted_aa = Viewport.MSAA_4X if mode == "menu" else video.AA_LEVELS[video.quality]
	if get_viewport().msaa_3d != wanted_aa:
		get_viewport().msaa_3d = wanted_aa

# Automated runs without a screen (the tests) never see a tutorial; a test can force it.
var force_tutorials = false

func tutorials_allowed() -> bool:
	return force_tutorials or DisplayServer.get_name() != "headless"

func maybe_lobby_tutorial() -> void:
	# The lobby tour, once per device, when the lobby is really on screen.
	if game_settings.tutorial_lobby or mode != "menu" or hud.tutorial_running() or not tutorials_allowed():
		return
	hud.start_tutorial("lobby")

func maybe_shop_tutorial() -> void:
	# The shop tour, once per device, the first time the PODERES shop opens (after it is laid out).
	if game_settings.tutorial_shop or hud.tutorial_running() or not tutorials_allowed():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if hud.powers_overlay.visible and not hud.tutorial_running():
		hud.start_tutorial("shop")

func tutorial_done(kind: String, _skipped: bool) -> void:
	if kind == "lobby":
		game_settings.tutorial_lobby = true
	elif kind == "shop":
		game_settings.tutorial_shop = true
	else:
		game_settings.tutorial_match = true
		if mode == "pve":
			# Also clears a pause menu raised while the tutorial was up (the app went to the
			# background and came back).
			resume_pve()
	save_game_settings()

func go_background(away: bool) -> void:
	# Like any other app: out of sight, the game stops - the match paused, every sound
	# silenced, the frame rate at one - and it comes back where it was.
	backgrounded = away
	AudioServer.set_bus_mute(0, away)
	if away:
		pause_pve()
		save_skins()
		DisplayServer.screen_set_keep_on(false)
		screen_kept_on = false
		Engine.max_fps = BACKGROUND_FPS
	else:
		last_input_ms = Time.get_ticks_msec()

func _process(dt: float) -> void:
	update_sustained_haptics()
	update_feedback_mix(dt)
	idle_frame_rate()
	hud.fps_label.visible = video.show_fps and mode != "menu"
	if mode == "menu" and is_instance_valid(cup_screen) and cup_screen.visible:
		return
	if mode == "menu" and menu_preview_timer >= 0:
		menu_preview_timer -= dt
		if menu_preview_timer < 0:
			show_menu_preview()
	# Two pilots, or six on the 3 v 3 arena; none before the first match is set up.
	if not is_instance_valid(arena) or rules.players.size() < 2:
		return
	if mode == "pve" and (pve_paused or hud.video_overlay.visible):
		return
	visual_packet_age += dt
	var alpha = clampf(visual_packet_age * 20.0, 0, 1) if mode == "client" else Engine.get_physics_interpolation_fraction()
	if mode == "menu" or (mode == "pve" and hud.video_overlay.visible):
		alpha = 1.0
	steer_camera(dt)
	arena.update_state(rules, local_team, dt, alpha)
	music.follow_phase("" if mode == "menu" or network_status != "" else rules.phase)
	hud_timer += dt
	if hud_timer >= 1.0 / 30.0:
		hud_timer = 0
		hud.update_match(rules, network_status)
	fps_timer += dt
	if fps_timer >= 0.5:
		fps_timer = 0
		var measured = Engine.get_frames_per_second()
		if mode != "menu" and video.adapt(get_viewport(), measured):
			hud.video_note.text = "Ajuste automático ativo: limite %d FPS." % video.runtime_fps
		hud.fps_label.text = "%d FPS  /  alvo %d" % [measured, video.runtime_fps]
	if rules.phase == "finished" and cup_active and not cup_resolved:
		cup_resolved = true
		finish_cup.call_deferred()
	if rules.phase != last_phase:
		if rules.phase == "finished" and mode == "pve" and level_index >= 0:
			finish_level()
		if rules.phase == "goal" or rules.phase == "finished":
			# The goal: a hit of the blast under the chime, and the strongest pulse of the match.
			play_tone("blast", -3.0)
			play_tone("goal")
			haptic(int(feel.get_value("haptic_goal_ms")), feel.get_value("haptic_goal_strength"))
			save_skins()
		last_phase = rules.phase
	for i in range(2):
		if rules.players[i].stun > 0 and last_stuns[i] <= 0:
			play_tone("stun")
		last_stuns[i] = rules.players[i].stun
	if mode == "client":
		var present: Dictionary = {}
		for ball in rules.balls:
			present[ball.id] = true
			if ball.get("boosted", false) and not client_boosted_ids.has(ball.id):
				play_tone("boost")
				client_boosted_ids[ball.id] = true
			if int(ball.get("power", 0)) == 1:
				client_blast_spots[ball.id] = ball.p
		for id in client_boosted_ids.keys():
			if not present.has(id):
				client_boosted_ids.erase(id)
		for id in client_blast_spots.keys():
			if present.has(id):
				continue
			# The host already resolved this blast; replay it where the round was last seen.
			if rules.phase == "play":
				arena.explosion(client_blast_spots[id], Rules.EXPLOSION_RADIUS)
				play_tone("blast")
			client_blast_spots.erase(id)

func build_audio() -> void:
	# A pool lets weapon tails, ricochets and impacts overlap instead of every
	# new effect cutting the sound already playing.
	var combat_bus = preload("res://scripts/combat_audio.gd").prepare_bus()
	for i in range(28):
		var voice = AudioStreamPlayer.new()
		voice.bus = combat_bus
		voice.set_meta("weapon_voice", i < 12)
		voice.volume_db = -16
		add_child(voice)
		audio_voices.append(voice)
	audio = audio_voices[0]
	tones = preload("res://scripts/combat_audio.gd").TRACKS.duplicate()
	tones["notify"] = notify_wave()
	for skin in range(Skins.CATALOG.size()):
		if tones.has("shot_%d_0" % skin):
			tones["shot_%d" % skin] = tones["shot_%d_0" % skin]

func notify_wave() -> AudioStreamWAV:
	# The notification: two bright, soft bell notes rising a fourth, like a phone's.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * 0.62)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t = float(i) / 22050.0
		var sample = 0.0
		for note in [[0.0, 1318.5], [0.14, 1760.0]]:
			var local = t - note[0]
			if local < 0.0:
				continue
			var envelope = minf(local / 0.006, 1.0) * exp(-local * 7.5)
			sample += (sin(TAU * note[1] * local) + 0.3 * sin(TAU * note[1] * 2.0 * local)) * envelope * 0.32
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32000.0))
	wave.data = bytes
	return wave

func roar_wave(seconds: float, base_hz: float, grit: float) -> AudioStreamWAV:
	# A held, throaty beam: two detuned saws under a slow tremolo.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * seconds)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var noise = RandomNumberGenerator.new()
	noise.seed = int(base_hz)
	for i in range(count):
		var t = float(i) / 22050.0
		var progress = float(i) / count
		var saw = fmod(t * base_hz, 1.0) * 2.0 - 1.0 + fmod(t * base_hz * 1.004, 1.0) * 2.0 - 1.0
		var tremolo = 0.75 + 0.25 * sin(t * TAU * 21.0)
		var envelope = minf(t * 24.0, 1.0) * minf((1.0 - progress) * 4.0, 1.0)
		var value = saw * 0.4 + grit * noise.randf_range(-1.0, 1.0) * 0.5
		bytes.encode_s16(i * 2, int(clampf(value * tremolo * envelope * 0.8, -1.0, 1.0) * 19000))
	wave.data = bytes
	return wave

func crack_wave(seconds: float) -> AudioStreamWAV:
	# Lightning: a white crack that collapses into a rolling tail.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * seconds)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var noise = RandomNumberGenerator.new()
	noise.seed = 4711
	var rumble = 0.0
	for i in range(count):
		var t = float(i) / 22050.0
		var progress = float(i) / count
		var snap = noise.randf_range(-1.0, 1.0) * pow(1.0 - progress, 5.0)
		rumble = lerpf(rumble, noise.randf_range(-1.0, 1.0), 0.06)
		var body = rumble * pow(1.0 - progress, 1.6) * 0.9 + sin(t * TAU * lerpf(90.0, 40.0, progress)) * 0.3 * pow(1.0 - progress, 2.0)
		bytes.encode_s16(i * 2, int(clampf(snap + body, -1.0, 1.0) * 19000))
	wave.data = bytes
	return wave

func chime_wave(seconds: float, base_hz: float) -> AudioStreamWAV:
	# Bloom: a soft major chord that opens upwards, like the wall breathing again.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * seconds)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t = float(i) / 22050.0
		var progress = float(i) / count
		var value = 0.0
		for step in range(3):
			var partial = base_hz * [1.0, 1.26, 1.5][step]
			var start = step * 0.08
			if t < start:
				continue
			value += sin((t - start) * TAU * partial) * pow(1.0 - progress, 1.8) * [0.5, 0.36, 0.3][step]
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 19000))
	wave.data = bytes
	return wave

func sweep_wave(seconds: float, from_hz: float, to_hz: float, grit: float) -> AudioStreamWAV:
	# Continuous phase keeps the sweep free of clicks; the noise share gives each cue its body.
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count = int(22050 * seconds)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var noise = RandomNumberGenerator.new()
	noise.seed = int(from_hz + to_hz)
	var phase = 0.0
	for i in range(count):
		var progress = float(i) / count
		phase += TAU * lerpf(from_hz, to_hz, progress * progress) / 22050.0
		var envelope = minf(float(i) / 140.0, 1.0) * pow(1.0 - progress, 1.55)
		var value = sin(phase) + grit * noise.randf_range(-1.0, 1.0) * (1.0 - progress)
		bytes.encode_s16(i * 2, int(clampf(value * envelope * 0.62, -1.0, 1.0) * 19000))
	wave.data = bytes
	return wave

func play_tone(sound: String, gain_db: float = 0.0, vary: bool = false, pitch: float = 1.0) -> void:
	# `vary`: a touch of pitch and level variation, so the same shot heard a thousand times
	# stays the same weapon without sounding pasted.
	if audio_voices.is_empty() or not tones.has(sound):
		return
	var now = Time.get_ticks_msec()
	var weapon = sound.begins_with("shot_")
	var priority = 0 if weapon or sound in ["bounce", "ricochet", "metal"] else (3 if sound in ["charging", "unleash", "goal"] else 2)
	# Dense combat should not turn one event into a stack of identical loud transients.
	if not weapon and priority < 3 and now - int(sound_times.get(sound, -1000)) < 28 and audio_voices.any(func(v): return v.playing and v.stream == tones[sound]):
		return
	sound_times[sound] = now
	var voice: AudioStreamPlayer = null
	for candidate in audio_voices:
		if bool(candidate.get_meta("weapon_voice", false)) == weapon and not candidate.playing:
			voice = candidate
			break
	if voice == null and not weapon:
		for candidate in audio_voices:
			if not candidate.get_meta("weapon_voice", false) and int(candidate.get_meta("priority", 0)) < priority and (voice == null or int(candidate.get_meta("started", 0)) < int(voice.get_meta("started", 0))):
				voice = candidate
	if voice == null:
		return
	voice.set_meta("priority", priority)
	voice.set_meta("started", now)
	voice.volume_db = (-17.5 if weapon else (-14.0 if priority == 3 else (-23.0 if priority == 0 else -18.0))) + gain_db
	voice.set_meta("mix_gain", voice.volume_db)
	voice.set_meta("secondary", weapon or sound in ["bounce", "metal", "ricochet", "sentry", "hit_0", "hit_1", "hit_2", "break_0", "break_1", "break_2"])
	voice.volume_db += linear_to_db(maxf(game_settings.sfx_volume, 0.0001)) + (arena_duck_db if voice.get_meta("secondary") else 0.0)
	voice.pitch_scale = 1.0
	if vary:
		var spread = feel.get_value("audio_pitch_variation")
		voice.pitch_scale = 1.0 + randf_range(-spread, spread)
		voice.volume_db += randf_range(-1.0, 1.0) * feel.get_value("audio_volume_variation")
	voice.pitch_scale *= pitch
	voice.stream = tones[sound]
	voice.play()

func capture_preview(path: String) -> void:
	await get_tree().create_timer(4.2).timeout
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var error = img.save_png(path)
	print("CAPTURE_RESULT ", error, " ", path)
	get_tree().quit(error)

func close_cup_screen() -> void:
	if hud.skins_overlay.visible:
		hud.close_skins()
	cup_active = false
	arena.show()
	if is_instance_valid(cup_screen):
		cup_screen.hide()

func cup_action(id: String) -> void:
	match id:
		"play": start_cup()
		"menu": return_to_menu()
		"practice": start_pve()
		"arenas": hud.open_levels()
		"settings_open": hud.open_video()
		"skins": hud.open_skins()
		"powers": hud.open_powers()
		"settings": hud.open_video()
		"pvp": hud.open_pvp()

func start_cup() -> void:
	# A Taça match is the campaign level for that round, played exactly as the campaign
	# plays it: its arena, its boss in its own colours, its kit, its pace and its theme.
	if cup.confirmed_match().is_empty():
		return
	var index: int = cup.level_index()
	var level: Dictionary = cup.level()
	arena.show()
	close_network()
	pve_paused = false
	mode = "pve"
	local_team = 0
	network_status = ""
	level_index = -1
	menu_level = index
	use_map(level.map)
	rules.ai_profile = cup.profile(game_settings.difficulty)
	use_loadouts(cup.kit(), int(level.boss), Campaign.level_ultimate(index))
	rules.reset_match()
	dress_pilots(0)
	arena.set_skin(1, int(level.boss), Campaign.is_minor(index), Campaign.level_hue(index))
	hud.team_hues = arena.unit_hues
	hud.level_info = {"number": cup.step(), "cup": true, "round": cup.round_name().to_upper(), "name": level.name, "challenge": level.get("challenge", ""), "boss_name": cup.opponent().to_upper(), "has_next": false}
	hud.level_result = ""
	hud.level_skin = ""
	# Compile what the match can draw during the countdown, not at its first shot.
	arena.warm_shaders.call_deferred()
	hud.show_game(mode, 0)
	sync_assist()
	cup_screen.hide()
	cup_active = true
	cup_resolved = false
	last_phase = ""
	music.play_skin(Campaign.level_music(index))

func finish_cup() -> void:
	# The result becomes part of the story: a win moves the draw on and prints the next
	# edition; a defeat is remembered by the kiosk and nothing else. Either way the run
	# comes back to the hub, never to a generic menu.
	var won = rules.winner == 0
	var step: int = cup.step()
	var rival: String = cup.opponent()
	var boss: int = cup.boss_id()
	var index: int = cup.level_index()
	var score = Array(rules.scores).duplicate()
	bank_bricks()
	var rewards: Array = []
	if won:
		cup.complete(score)
		open_arena(index)
		if step > 0 and boss > 0 and skins.defeat(boss):
			rewards.append(Skins.CATALOG[boss].name)
		if cup.champion() and skins.defeat(11):
			rewards.append(Skins.CATALOG[11].name)
		save_skins()
	else:
		cup.lose(score)
	if cup.save() != OK:
		push_warning("Não foi possível guardar a Taça.")
	sync_story()
	return_to_menu()
	open_cup()
	cup_screen.show_after({"won": won, "score": score, "rival": rival, "step": step, "reward": " · ".join(rewards)})

func open_arena(index: int) -> void:
	# A round won opens its arena for free play in ARENAS, whatever the build.
	if not campaign.completed.has(index):
		campaign.completed.append(index)
	campaign.unlocked = clampi(maxi(campaign.unlocked, index + 2), 1, Campaign.LEVELS.size())
	campaign.save_preferences()
	hud.sync_campaign(campaign)

func sync_story() -> void:
	# What the lobby says about the story: the round to play and who waits in it.
	if cup.champion():
		hud.lobby.story_line = "Campeão da Taça Aurora"
		hud.lobby.story_boss = -1
	else:
		var m: Dictionary = cup.confirmed_match()
		hud.lobby.story_round = String(m.round_name).to_upper()
		hud.lobby.story_line = "vs " + String(m.name).to_upper()
		hud.lobby.story_boss = int(m.boss)
	hud.lobby.story_news = Press.has_new_edition(cup)
	hud.lobby.refresh()

func open_cup() -> void:
	# The hub takes the whole screen: the lobby's own top bar and rail step aside.
	hud.lobby.hide()
	hud.lobby.close_sheet()
	cup_screen.show()
	cup_screen.refresh()
	arena.hide()

func preview_skin_music(index: int) -> void:
	if skin_music_return.is_empty():
		skin_music_return = music.track
	music.play_skin(index)
	if not music.enabled:
		hud.skin_music_note.text = "MÚSICA DESLIGADA · ativa-a nas Opções"

func restore_skin_music() -> void:
	if not skin_music_return.is_empty():
		music.play(skin_music_return)
		skin_music_return = ""
