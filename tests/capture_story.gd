extends SceneTree
# The story mode's screens on one sheet: the Taça hub, Rosa's kiosk, today's paper, the
# versus card, the result after a win, the route and the tree, a few rounds into a run
# (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_story.gd -- <output.png> [folder for each screen]
var shots: Array = []

func _initialize() -> void:
	call_deferred("run")

func grab() -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	shots.append(root.get_texture().get_image())

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "res://preview-story.png"
	root.size = Vector2i(540, 1080)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for key in ["campaign", "skins", "power_shop"]:
		game.get(key).config_path = "res://tests/story-capture-%s.tmp" % key
	game.cup.path = "res://tests/story-capture-cup.tmp"
	game.cup.seed_value = 4242
	game.cup.reset()
	# Three rounds into the run: the paper has noticed the rookie.
	game.cup.complete([2, 1])
	for i in range(3):
		game.cup.complete([2, i % 2])
	game.sync_story()
	await create_timer(0.5).timeout
	await grab()
	game.open_cup()
	var hub = game.cup_screen
	await create_timer(0.4).timeout
	await grab()
	hub.open_kiosk()
	await create_timer(0.6).timeout
	await grab()
	hub.open_paper(game.cup.wins)
	await create_timer(1.2).timeout
	await grab()
	hub.close_page()
	hub.open_versus()
	await create_timer(0.8).timeout
	await grab()
	hub.show_after({"won": true, "score": [2, 1], "rival": game.cup.opponent(), "step": game.cup.step(), "reward": ""})
	await create_timer(0.8).timeout
	await grab()
	hub.close_overlay()
	hub.open_route()
	await create_timer(0.4).timeout
	await grab()
	hub.open_bracket()
	await create_timer(0.4).timeout
	await grab()
	if args.size() > 1:
		for i in range(shots.size()):
			shots[i].save_png(args[1].path_join("story-%02d.png" % i))
	var cell: Vector2i = shots[0].get_size()
	var sheet = Image.create(cell.x * 4, cell.y * 2, false, shots[0].get_format())
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, cell), Vector2i(i % 4 * cell.x, i / 4 * cell.y))
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	print("STORY_SHEET ", shots.size(), " ", sheet.save_png(path))
	for key in ["campaign", "skins", "power_shop", "cup"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/story-capture-%s.tmp" % key))
	quit()
