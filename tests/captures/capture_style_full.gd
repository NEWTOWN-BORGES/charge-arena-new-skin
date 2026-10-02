extends SceneTree
# A whole art direction on trial (scripts/presentation/art_style.gd): every world from above and over the
# shoulder, a fight with explosions, and the whole cast up close (needs a GPU).
# Usage: godot -s tests/captures/capture_style_full.gd -- <output prefix> <style or "atual">
const Rules = preload("res://scripts/gameplay/arena_rules.gd")
const ArtStyle = preload("res://scripts/presentation/art_style.gd")
const WORLDS = ["aurora", "terra", "oceano", "orbita", "cidade", "cidade_negra"]

func _initialize() -> void:
	call_deferred("run")

func grab() -> Image:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0]
	ArtStyle.current = "" if args[1] == "atual" else args[1]
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/style-preview.tmp"
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	var tops: Array = []
	var views: Array = []
	var cam: Camera3D
	for world in WORLDS:
		game.set_physics_process(true)
		game.start_pve(Rules.quick_map(world))
		game.arena.set_skin(0, 0)
		game.arena.set_skin(1, 11)
		await create_timer(0.8).timeout
		game.rules.phase = "play"
		for f in range(30):
			game._physics_process(1.0 / 60.0)
			await process_frame
		game.set_physics_process(false)
		game.hud.visible = false
		root.size = Vector2i(720, 1280)
		game.arena.camera.current = true
		tops.append(await grab())
		# The arena is rebuilt for every world, and its children with it: a fresh camera each time.
		cam = Camera3D.new()
		game.arena.add_child(cam)
		cam.current = true
		cam.fov = 50
		root.size = Vector2i(1280, 720)
		var me: Node3D = game.arena.units[0]
		var rival: Node3D = game.arena.units[1]
		cam.global_position = me.global_position + Vector3(1.6, 2.6, 4.2)
		cam.look_at(rival.global_position.lerp(me.global_position, 0.35) + Vector3.UP * 0.6)
		views.append(await grab())
		cam.current = false
		game.hud.visible = true
	# A fight: explosions and thunder on the last world, HUD on.
	game.start_pve(Rules.quick_map("aurora"))
	game.arena.set_skin(0, 5)
	game.arena.set_skin(1, 10)
	await create_timer(0.8).timeout
	game.rules.phase = "play"
	for f in range(30):
		game._physics_process(1.0 / 60.0)
		await process_frame
	root.size = Vector2i(720, 1280)
	game.arena.camera.current = true
	game.arena.explosion(Vector2(1.2, -3.5), 1.65)
	game.arena.CombatFinish.event(game.arena, {"kind": "explosion", "p": Vector2(1.2, -3.5), "radius": 1.65, "team": 0}, game.rules)
	game.arena.thunder_bolt(Vector2(-1.5, 2.5), 1.0)
	game.arena.CombatFinish.event(game.arena, {"kind": "thunder", "p": Vector2(-1.5, 2.5), "radius": 1.0, "team": 1}, game.rules)
	for f in range(8):
		game._physics_process(1.0 / 60.0)
		await process_frame
	(await grab()).save_png(prefix + "-combate.png")
	# The cast.
	game.set_physics_process(false)
	game.hud.visible = false
	root.size = Vector2i(512, 640)
	game.arena.units[1].hide()
	cam = Camera3D.new()
	game.arena.add_child(cam)
	cam.current = true
	cam.fov = 26
	var catalog = Image.create(2048, 1920, false, Image.FORMAT_RGBA8)
	for skin in range(12):
		game.arena.set_skin(0, skin)
		var unit = game.arena.units[0]
		unit.get_node("Body").rotation.y = 0.35
		cam.global_position = unit.global_position + Vector3(0, 1.75, 6.8)
		cam.look_at(unit.global_position + Vector3.UP * 1.1)
		var shot: Image = await grab()
		shot.convert(Image.FORMAT_RGBA8)
		catalog.blit_rect(shot, Rect2i(0, 0, 512, 640), Vector2i((skin % 4) * 512, (skin / 4) * 640))
	catalog.save_png(prefix + "-elenco.png")
	var sheet = Image.create(360 * 6, 640, false, Image.FORMAT_RGBA8)
	for i in range(tops.size()):
		var t: Image = tops[i]
		t.convert(Image.FORMAT_RGBA8)
		t.resize(360, 640)
		sheet.blit_rect(t, Rect2i(0, 0, 360, 640), Vector2i(i * 360, 0))
	sheet.save_png(prefix + "-mundos-cima.png")
	var wide = Image.create(640 * 3, 360 * 2, false, Image.FORMAT_RGBA8)
	for i in range(views.size()):
		var v: Image = views[i]
		v.convert(Image.FORMAT_RGBA8)
		v.resize(640, 360)
		wide.blit_rect(v, Rect2i(0, 0, 640, 360), Vector2i((i % 3) * 640, (i / 3) * 360))
	wide.save_png(prefix + "-mundos-3pessoa.png")
	print("STYLE_FULL done")
	quit()
