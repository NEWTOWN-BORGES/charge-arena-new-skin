extends SceneTree
## GPU evidence from actual casts and their gameplay events, at both quality profiles.
## godot --path . -s tests/capture_abilities_heroic.gd -- <absolute output prefix>
const Rules = preload("res://scripts/arena_rules.gd")
const Powers = preload("res://scripts/powers.gd")
const Skins = preload("res://scripts/skins.gd")
const SIZE = Vector2i(960, 720)
const DT = 1.0 / 60.0
const MOMENTS = [
	["sun_ray", "COROA SOLAR", 8, "beam"],
	["singularity", "SINGULARIDADE", 24, "caster"],
	["volley", "MISSEIS", 27, "rocket"],
	["dome", "CUPULA", 21, "wall"],
	["freeze", "GELO", 9, "target"],
	["bloom", "FLORESCER", 13, "wall"],
	["shock_wave", "ONDA DE CHOQUE", 101, "field"],
	["b_salvo", "SALVA", 7, "beam"],
	["plating", "COURACA DE CRISTAL", 20, "wall"],
	["sentries", "SENTINELAS", 20, "center"],
	["drain", "DRENO", 8, "field"],
	["emp", "PULSO EMP", 11, "target"]
]

var game
var prefix: String
var seen: Dictionary = {}
var label: Label

func _initialize() -> void:
	call_deferred("run")

func tick() -> void:
	game.rules.step(DT, [{"move": Vector2.ZERO, "fire": false}, {"move": Vector2.ZERO, "fire": false}])
	for event in game.rules.events:
		seen[String(event.kind)] = true
	game.play_events()
	game.arena.update_state(game.rules, 0, DT)
	game.rules.phase = "play"

func advance(ticks: int) -> void:
	for frame in range(ticks): tick()

func wall_center() -> Vector2:
	var sum = Vector2.ZERO
	var count = 0
	for brick in game.rules.bricks:
		if brick.team == 0:
			sum += Vector2(brick.p)
			count += 1
	return sum / float(maxi(count, 1))

func reset_cast(id: String, release: bool = true) -> void:
	game.rules.reset_match()
	game.rules.phase = "play"
	# Let the preceding cast return its transient nodes, particles and lamps.
	for frame in range(260): game.arena.update_state(game.rules, 0, DT)
	game.arena.shakes.clear()
	game.rules.power_rng.seed = 3440
	seed(3440)
	var skin = 1 if id == "b_salvo" else 0
	for index in range(Skins.CATALOG.size()):
		if String(Skins.CATALOG[index].ultimate) == id:
			skin = index
			break
	game.arena.set_skin(0, skin)
	game.arena.set_skin(1, 7)
	game.rules.players[0].angle = -0.34
	game.rules.players[0].p = Rules.track_position(0, -0.34)
	game.rules.players[1].angle = 0.2
	game.rules.players[1].p = Rules.track_position(1, 0.2)
	game.arena.update_state(game.rules, 0, DT)
	seen.clear()
	var ultimate = Powers.is_ultimate(id)
	game.rules.loadouts[0] = ["blast", "air", id] if ultimate else [id, "air", "sun_ray"]
	game.rules.loadouts[1] = ["mirror", "thorns", "thunder"]
	game.rules.powers[0].charge = [99, 99, 99]
	game.rules.powers[1].charge = [99, 99, 99]
	if id in ["bloom", "weld"]:
		for brick in game.rules.bricks:
			if brick.team == 0: brick.hp = maxi(1, brick.hp - 1)
	if id == "drain":
		assert(game.rules.activate_power(1, 2), "Rival ultimate must charge before drain")
		game.play_events()
		advance(30)
	if id == "emp":
		assert(game.rules.activate_power(1, 0), "EMP needs an actual active rival shield")
		game.play_events()
		advance(12)
	game.rules.events.clear()
	assert(game.rules.activate_power(0, 2 if ultimate else 0), "Cast rejected: " + id)
	for event in game.rules.events:
		seen[String(event.kind)] = true
	game.play_events()
	if ultimate and release:
		for frame in range(140):
			tick()
			if seen.has("ultimate"): break
		assert(seen.has("ultimate"), "Ultimate did not release: " + id)

func close_camera(center: Vector2, wide: bool) -> void:
	var cam: Camera3D = game.arena.camera
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 48.0
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	var target = Vector3(center.x, 0.35, center.y)
	cam.global_position = target + (Vector3(0.0, 14.0, 15.0) if wide else Vector3(0.0, 6.2, 7.4))
	cam.look_at(target)

func capture(name: String, title: String, focus: String) -> Image:
	var caster: Vector2 = game.rules.players[0].p
	var target = Vector2.ZERO
	match focus:
		"caster": target = caster
		"companion": target = game.rules.players[2].p
		"target": target = game.rules.players[1].p
		"wall": target = wall_center()
		"beam": target = caster + Rules.forward_direction(0, game.rules.players[0].angle) * 2.2
		"rocket":
			if not game.arena.flights.is_empty():
				var airborne: Vector3 = game.arena.flights[0].node.global_position
				target = Vector2(airborne.x, airborne.z)
	close_camera(target, focus == "field")
	label.text = title
	for frame in range(4):
		await process_frame
		close_camera(target, focus == "field")
		game.arena.update_state(game.rules, 0, 0.0)
		close_camera(target, focus == "field")
	await RenderingServer.frame_post_draw
	var shot = root.get_texture().get_image()
	assert(shot.get_size() == SIZE, "Capture viewport changed size")
	var path = prefix + "-" + name + ".png"
	assert(shot.save_png(path) == OK, "Could not save " + path)
	print("ABILITY_CAPTURE ", name, " events=", seen.keys(), " quality=", game.arena.quality_level,
		" fronts=", game.arena.CombatFinish.active_count(game.arena), " effects=", game.arena.effects.size())
	return shot

func profile(quality: int, title: String) -> void:
	game.video.configure(60, quality, false, false)
	game.video.apply(root, game.arena)
	var shots: Array[Image] = []
	for moment in MOMENTS:
		var id: String = moment[0]
		reset_cast("singularity" if id == "shock_wave" else id)
		advance(int(moment[2]))
		assert(seen.has("shock_wave") if id == "shock_wave" else seen.has("power"), "Missing gameplay event: " + id)
		shots.append(await capture(title + "-" + id, moment[1] + "  /  " + title.to_upper(), moment[3]))
	var sheet = Image.create(SIZE.x * 4, SIZE.y * 3, false, shots[0].get_format())
	sheet.fill(Color("101e30"))
	for index in range(shots.size()):
		sheet.blit_rect(shots[index], Rect2i(Vector2i.ZERO, SIZE), Vector2i((index % 4) * SIZE.x, (index / 4) * SIZE.y))
	assert(sheet.save_png(prefix + "-" + title + "-contacto.png") == OK)
	reset_cast("singularity", false)
	advance(62)
	await capture(title + "-preparacao", "PREPARACAO DA ULTIMATE  /  " + title.to_upper(), "caster")

func capture_hud() -> void:
	root.size = Vector2i(720, 1280)
	label.hide()
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.rules.reset_match()
	game.rules.phase = "play"
	game.rules.loadouts[0] = ["freeze", "blast", "sun_ray"]
	game.rules.powers[0].charge = [99, 99, 99]
	game.arena.set_skin(0, 10)
	game.hud.show()
	game.hud.show_game("pve", 0)
	game.power_shop.tutorial_done = true
	for moment in ["pronto", "preparacao"]:
		if moment == "preparacao":
			assert(game.rules.activate_power(0, 1))
			game.play_events()
			game.rules.events.clear()
			assert(game.rules.activate_power(0, 2))
			game.play_events()
			advance(52)
		game.hud.update_match(game.rules, "")
		game.hud.queue_redraw()
		for frame in range(5):
			await process_frame
			game.steer_camera(DT)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(prefix + "-hud-" + moment + ".png") == OK)
		print("ABILITY_HUD_CAPTURE ", moment)

func capture_squad() -> void:
	game.start_squad(false)
	game.hud.hide()
	game.arena.guide_enabled = false
	game.arena.set_pilot_skin(2, 5)
	for quality in [2, 0]:
		var title = "alto" if quality == 2 else "leve"
		game.video.configure(60, quality, false, false)
		game.video.apply(root, game.arena)
		game.rules.reset_match()
		game.rules.phase = "play"
		game.rules.players[2].kit = ["magnet", "air", "singularity"]
		game.rules.players[2].charge = [99, 99, 99]
		for frame in range(260): game.arena.update_state(game.rules, 0, DT)
		seen.clear()
		game.rules.events.clear()
		assert(game.rules.with_pilot(2, func(): return game.rules.activate_power(0, 0)))
		game.play_events()
		advance(8)
		await capture(title + "-3v3-habilidade", "HABILIDADE NO CORPO DO COMPANHEIRO  /  " + title.to_upper(), "companion")
		game.rules.events.clear()
		assert(game.rules.with_pilot(2, func(): return game.rules.activate_power(0, 2)))
		game.play_events()
		advance(50)
		await capture(title + "-3v3-preparacao", "PREPARACAO NO CORPO DO COMPANHEIRO  /  " + title.to_upper(), "companion")
		advance(73)
		await capture(title + "-3v3-ultimate", "ULTIMATE NO CORPO DO COMPANHEIRO  /  " + title.to_upper(), "companion")
	game.start_pve(Rules.quick_map("aurora"))
	game.hud.hide()
	game.arena.guide_enabled = false

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Provide an absolute output prefix after --")
		quit(1)
		return
	prefix = args[0]
	root.size = SIZE
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if root.focus_exited.is_connected(game.pause_pve): root.focus_exited.disconnect(game.pause_pve)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.set_process(false)
	game.game_settings.config_path = "user://heroic-abilities-preview.cfg"
	game.game_settings.tutorial_match = true
	game.start_pve(Rules.quick_map("aurora"))
	game.hud.hide()
	game.arena.guide_enabled = false
	var overlay = CanvasLayer.new()
	root.add_child(overlay)
	label = Label.new()
	label.position = Vector2(18, 14)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("f4f9ff"))
	label.add_theme_color_override("font_outline_color", Color("061428"))
	label.add_theme_constant_override("outline_size", 7)
	overlay.add_child(label)
	if not args.has("--hud-only"):
		if not args.has("--squad-only"):
			await profile(2, "alto")
			await profile(0, "leve")
		await capture_squad()
	await capture_hud()
	print("ABILITIES_HEROIC_CAPTURE_RESULT profiles=2 moments=12 actual_gameplay_casts=true")
	quit(0)
