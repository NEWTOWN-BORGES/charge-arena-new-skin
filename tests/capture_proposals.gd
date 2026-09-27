extends SceneTree
# Design proposals for robots without a neck, shown before they enter the game: for each
# robot, today's look and the proposal from four sides and a close-up of the face (needs a
# GPU; omit --headless). The roster is only changed in memory.
# Usage: godot -s tests/capture_proposals.gd -- <output prefix> [skin:hull[:eyes] ...]
const TILE = 480
const PROPOSALS = {0: "bit3_hull", 2: "orbita3_hull", 5: "eclipse3_hull", 7: "faisca3_hull", 10: "helio3_hull", 11: "magnus3_hull"}
const Robots = preload("res://scripts/robots.gd")

func _initialize() -> void:
	call_deferred("run")

func shot() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func pose(arena, cam: Camera3D, turn: float, close: bool) -> void:
	var unit: Node3D = arena.units[0]
	unit.get_node("Body").rotation.y = turn
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 26
	cam.h_offset = 0
	cam.v_offset = 0
	cam.global_position = unit.global_position + (Vector3(0, 1.8, 1.9) if close else Vector3(0, 2.0, 4.6))
	cam.look_at(unit.global_position + Vector3.UP * (1.45 if close else 1.1))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-proposal"
	var jobs: Dictionary = {}
	for value in args.slice(1):
		var bits = String(value).split(":")
		jobs[int(bits[0])] = bits[1] + (":" + bits[2] if bits.size() > 2 else "")
	if jobs.is_empty():
		jobs = PROPOSALS
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
	for skin in jobs:
		var tiles: Array = []
		arena.set_skin(0, 1 if skin != 1 else 3)
		arena.set_skin(0, skin)
		await process_frame
		pose(arena, cam, PI * 0.82, false)
		tiles.append(await shot())
		var entry: Dictionary = Robots.cast()[skin]
		var saved: Dictionary = entry.parts.duplicate()
		entry.parts["head"] = ""
		entry.parts["top"] = ""
		var job: PackedStringArray = String(jobs[skin]).split(":")
		entry.parts["torso"] = job[0]
		var eyes: String = entry.eye_style
		if job.size() > 1:
			entry.eye_style = job[1]
		# Crests modelled around the old head are left out of the proposal; the hull carries its own.
		if skin != 2:
			entry.parts["spin"] = ""
		Robots._merged.clear()
		arena.set_skin(0, 1 if skin != 1 else 3)
		arena.set_skin(0, skin)
		await process_frame
		for view in [[PI * 0.82, false], [PI, false], [PI * 0.2, false], [PI * 0.9, true]]:
			pose(arena, cam, view[0], view[1])
			tiles.append(await shot())
		entry.parts = saved
		entry.eye_style = eyes
		Robots._merged.clear()
		var sheet = Image.create(TILE * tiles.size(), TILE, false, tiles[0].get_format())
		for i in range(tiles.size()):
			sheet.blit_rect(tiles[i], Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
		var path = "%s-%d.png" % [prefix, skin]
		print("PROPOSAL ", path, " ", sheet.save_png(path))
	quit()
