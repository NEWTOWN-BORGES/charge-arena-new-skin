extends SceneTree
# Every world from the default top camera, as a phone sees it: a quality profile and the
# phone's half-detail scenery (needs a GPU). One sheet of the six worlds.
# Usage: godot -s tests/captures/capture_top.gd -- <output.png> <quality 0-2> [light parts: 1/0] [camera turn]
const Rules = preload("res://scripts/gameplay/arena_rules.gd")
const Robots = preload("res://scripts/presentation/robots.gd")
const WORLDS = ["aurora", "terra", "oceano", "orbita", "cidade", "cidade_negra"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var quality = int(args[1])
	Robots.light_parts = args.size() > 2 and args[2] == "1"
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/style-preview.tmp"
	game.game_settings.tutorial_match = true
	await create_timer(0.3).timeout
	game.video.configure(30, quality, false, false)
	game.video.apply(root, game.arena)
	var sheet = Image.create(360 * 6, 640, false, Image.FORMAT_RGBA8)
	for i in range(WORLDS.size()):
		game.start_pve(Rules.quick_map(WORLDS[i]))
		game.pve_paused = false
		await create_timer(0.8).timeout
		game.rules.phase = "play"
		for f in range(20):
			game._physics_process(1.0 / 60.0)
			await process_frame
		if args.size() > 3:
			# A pulled-back, turned camera, like a phone after dragging the view round.
			var cam = Camera3D.new()
			game.arena.add_child(cam)
			cam.fov = 60
			var turn = float(args[3])
			cam.position = Vector3(sin(turn) * 26.0, 34.0, cos(turn) * 26.0)
			cam.look_at(Vector3(0, 0, 0))
			cam.current = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot: Image = root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(360, 640)
		sheet.blit_rect(shot, Rect2i(0, 0, 360, 640), Vector2i(i * 360, 0))
	print("TOP ", sheet.save_png(args[0]))
	quit()
