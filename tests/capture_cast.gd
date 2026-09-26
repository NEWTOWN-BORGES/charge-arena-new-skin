extends SceneTree
# The whole shop cast in one sheet (needs a GPU; omit --headless).
# Top row: three-quarter studio view. Bottom row: the real gameplay camera, zoomed.
# Usage: godot -s tests/capture_cast.gd -- [output.png]
const TILE = 320

func _initialize() -> void:
	call_deferred("run")

func shot() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "res://preview-cast.png"
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
	var count: int = game.Skins.CATALOG.size()
	var tiles: Array = []
	for skin in range(count):
		arena.set_skin(0, skin)
		await process_frame
		var unit: Node3D = arena.units[0]
		unit.get_node("Body").rotation.y = PI * 0.82
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 28
		cam.h_offset = 0
		cam.v_offset = 0
		cam.global_position = unit.global_position + Vector3(0, 1.5, 4.4)
		cam.look_at(unit.global_position + Vector3.UP * 1.0)
		var studio = await shot()
		unit.get_node("Body").rotation.y = 0
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.global_position = Vector3(0, 26, 15)
		cam.look_at(Vector3(0, -0.15, 0))
		cam.size = 3.2
		var offset = unit.global_position + Vector3.UP * 0.9 - cam.global_position
		cam.h_offset = offset.dot(cam.global_transform.basis.x)
		cam.v_offset = offset.dot(cam.global_transform.basis.y)
		tiles.append([studio, await shot()])
	var sheet = Image.create(TILE * 6, TILE * 4, false, tiles[0][0].get_format())
	for skin in range(count):
		var column = skin % 6
		var band = skin / 6 * 2
		sheet.blit_rect(tiles[skin][0], Rect2i(0, 0, TILE, TILE), Vector2i(column * TILE, band * TILE))
		sheet.blit_rect(tiles[skin][1], Rect2i(0, 0, TILE, TILE), Vector2i(column * TILE, (band + 1) * TILE))
	var error = sheet.save_png(path)
	print("CAST_SHEET result=", error)
	quit(error)
