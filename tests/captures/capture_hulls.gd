extends SceneTree
# The robots with a fused hull (trunk and head one piece, no neck) close up: front
# three-quarter, straight front and back three-quarter (needs a GPU; omit --headless).
# Usage: godot -s tests/captures/capture_hulls.gd -- <output.png> [skins...]
const TILE = 480
# The last view is a close-up of the face.
const TURNS = [PI * 0.82, PI, PI * 0.25, PI * 0.9]

func _initialize() -> void:
	call_deferred("run")

func shot() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "user://preview-hulls.png"
	var skins: Array = []
	for value in args.slice(1):
		skins.append(int(value))
	if skins.is_empty():
		skins = [4, 1, 9, 8, 6, 3]
	root.size = Vector2i(TILE, TILE)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve()
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.visible = false
	var arena = game.arena
	var cam: Camera3D = arena.camera
	var sheet: Image = null
	for row in range(skins.size()):
		arena.set_skin(0, skins[row])
		await process_frame
		var unit: Node3D = arena.units[0]
		for column in range(TURNS.size()):
			unit.get_node("Body").rotation.y = TURNS[column]
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			var close = column == TURNS.size() - 1
			cam.fov = 26
			cam.h_offset = 0
			cam.v_offset = 0
			cam.global_position = unit.global_position + (Vector3(0, 1.75, 1.7) if close else Vector3(0, 2.0, 4.4))
			cam.look_at(unit.global_position + Vector3.UP * (1.4 if close else 1.05))
			var image = await shot()
			if sheet == null:
				sheet = Image.create(TILE * TURNS.size(), TILE * skins.size(), false, image.get_format())
			sheet.blit_rect(image, Rect2i(0, 0, TILE, TILE), Vector2i(column * TILE, row * TILE))
	var error = sheet.save_png(path)
	print("HULLS result=", error)
	quit(error)
