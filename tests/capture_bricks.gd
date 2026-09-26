extends SceneTree
# The themed wall of every robot, seen close from the stands: each skin in turn defends the
# far goal, one picture per skin on a 4 x 3 sheet (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_bricks.gd -- <output.png>
const CELL = 400

func _initialize() -> void:
	call_deferred("run")

func frame() -> Image:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "res://preview-bricks.png"
	root.size = Vector2i(CELL, CELL)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.3).timeout
	game.start_pve()
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.visible = false
	var arena = game.arena
	var cam: Camera3D = arena.camera
	var sheet: Image
	for skin in range(12):
		arena.set_skin(1, skin)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 38
		cam.h_offset = 0
		cam.v_offset = 0
		cam.global_position = Vector3(0.0, 3.2, -1.2)
		cam.look_at(Vector3(0.0, 0.2, -4.6))
		arena.camera_home = cam.position
		var shot = await frame()
		if sheet == null:
			sheet = Image.create(CELL * 4, CELL * 3, false, shot.get_format())
		sheet.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i(skin % 4 * CELL, skin / 4 * CELL))
	print("BRICK_SHEET ", sheet.save_png(path))
	quit()
