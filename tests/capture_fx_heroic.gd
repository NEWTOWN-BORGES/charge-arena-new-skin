extends SceneTree
## Real GPU captures of the shared combat callbacks, at high and light quality.
## Usage: godot --path . -s tests/capture_fx_heroic.gd -- <absolute output prefix>
## The simulation and particle clock advance by fixed ticks, independent of capture time.
const Rules = preload("res://scripts/gameplay/arena_rules.gd")
const Front = preload("res://scripts/presentation/combat_finish.gd")
const SIZE = Vector2i(960, 720)
const DT = 1.0 / 60.0

var game
var prefix: String

func _initialize() -> void:
	call_deferred("run")

func advance(ticks: int, move_rounds: bool = false) -> void:
	for tick in range(ticks):
		if move_rounds:
			for ball in game.rules.balls:
				ball.p += ball.v * DT
		game.arena.update_state(game.rules, 0, DT)

func clear_moment() -> void:
	game.rules.balls.clear()
	advance(150)
	game.arena.shakes.clear()

func close_camera(center: Vector2 = Vector2.ZERO, wide: bool = false) -> void:
	var cam: Camera3D = game.arena.camera
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 48.0
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	var target = Vector3(center.x, 0.2, center.y)
	cam.global_position = target + (Vector3(0.0, 10.0, 11.0) if wide else Vector3(0.0, 6.2, 7.4))
	cam.look_at(target)

func capture(name: String, center: Vector2 = Vector2.ZERO, wide: bool = false) -> Image:
	close_camera(center, wide)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var shot = root.get_texture().get_image()
	assert(shot.get_size() == SIZE, "Capture viewport changed size")
	var path = prefix + "-" + name + ".png"
	assert(shot.save_png(path) == OK, "Could not save " + path)
	print("FX_CAPTURE ", path, " profile=", game.arena.quality_level,
		" batches=", game.arena.fx.batches.size(), " effects=", game.arena.effects.size())
	return shot

func setup(quality: int) -> void:
	seed(3440)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if root.focus_exited.is_connected(game.pause_pve):
		root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "user://heroic-fx-preview.cfg"
	game.game_settings.tutorial_match = true
	game.set_process(false)
	game.set_physics_process(false)
	game.start_pve(Rules.quick_map("aurora"))
	game.rules.phase = "play"
	game.hud.hide()
	game.hud.set_process(false)
	game.arena.guide_enabled = false
	game.video.configure(60, quality, false, false)
	game.video.apply(root, game.arena)
	game.arena.set_skin(0, 7)
	game.arena.set_skin(1, 10)
	game.rules.players[0].p = Vector2(-1.6, 3.2)
	game.rules.players[1].p = Vector2(1.6, -3.2)
	advance(150)
	await process_frame

func profile(quality: int, label: String) -> void:
	await setup(quality)
	var shots: Array[Image] = []
	game.rules.balls.append({"id": 9700, "owner": 0, "p": Vector2(-1.1, 1.6),
		"v": Vector2(2.0, -11.0), "bounces": 1, "ttl": 4.0, "damage": 1, "boosted": false})
	game.rules.balls.append({"id": 9701, "owner": 1, "p": Vector2(1.3, -1.6),
		"v": Vector2(-2.0, 11.0), "bounces": 1, "ttl": 4.0, "damage": 2, "boosted": true, "power": 1})
	advance(7, true)
	game.arena.shot_feedback(0, true)
	game.arena.shot_feedback(1, false)
	advance(2, true)
	shots.append(await capture(label + "-tiros"))
	clear_moment()

	game.arena.impact_feedback({"kind": "brick", "p": Vector2(-1.5, 0.2),
		"team": 0, "heading": Vector2.UP})
	game.arena.impact_feedback({"kind": "bounce", "surface": "obstacle", "p": Vector2(1.5, -0.2),
		"team": 1, "heading": Vector2(0.7, 0.7)})
	advance(4)
	shots.append(await capture(label + "-impacto"))
	clear_moment()

	game.arena.explosion(Vector2.ZERO, 1.65)
	Front.event(game.arena, {"kind": "explosion", "p": Vector2.ZERO, "radius": 1.65, "team": 0}, game.rules)
	advance(10)
	shots.append(await capture(label + "-explosao"))
	clear_moment()

	var indexes: Array = []
	var positions: Array = []
	for index in range(game.rules.bricks.size()):
		if game.rules.bricks[index].team == 0:
			indexes.append(index)
			positions.append(game.rules.bricks[index].p)
			if positions.size() == 5:
				break
	var heal_center = Vector2.ZERO
	for pos in positions:
		heal_center += pos
	heal_center /= float(positions.size())
	game.arena.bloom_flash(positions, 2)
	Front.event(game.arena, {"kind": "bloom", "p": heal_center, "team": 0, "bricks": indexes}, game.rules)
	advance(13)
	shots.append(await capture(label + "-cura", heal_center))
	clear_moment()

	game.arena.thunder_bolt(Vector2.ZERO, 1.0)
	Front.event(game.arena, {"kind": "thunder", "p": Vector2.ZERO, "radius": 1.0, "team": 1}, game.rules)
	advance(11)
	shots.append(await capture(label + "-eletrico"))
	clear_moment()
	game.arena.explosion(Vector2(-1.7, -0.6), 1.4)
	Front.event(game.arena, {"kind": "explosion", "p": Vector2(-1.7, -0.6), "radius": 1.4, "team": 0}, game.rules)
	game.arena.thunder_bolt(Vector2(1.7, -0.6), 1.0)
	Front.event(game.arena, {"kind": "thunder", "p": Vector2(1.7, -0.6), "radius": 1.0, "team": 1}, game.rules)
	advance(10)
	game.arena.shot_feedback(0, true)
	game.arena.shot_feedback(1, false)
	advance(1)
	shots.append(await capture(label + "-combate", Vector2.ZERO, true))
	var sheet = Image.create(SIZE.x * 3, SIZE.y * 2, false, shots[0].get_format())
	sheet.fill(Color("101e30"))
	for index in range(shots.size()):
		sheet.blit_rect(shots[index], Rect2i(Vector2i.ZERO, SIZE),
			Vector2i((index % 3) * SIZE.x, (index / 3) * SIZE.y))
	assert(sheet.save_png(prefix + "-" + label + "-contacto.png") == OK)
	game.queue_free()
	await process_frame

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Provide an absolute output prefix after --")
		quit(1)
		return
	prefix = args[0]
	root.size = SIZE
	await profile(2, "alto")
	await profile(0, "leve")
	print("FX_HEROIC_CAPTURE_RESULT profiles=2 moments=6 actual_game_callbacks=true")
	quit(0)
