extends SceneTree
# The effects at work: projectiles with their comet tails, a hit, a brick breaking, a blast
# and a defensive power, caught mid-flight (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_fx.gd -- <output.png>
const Rules = preload("res://scripts/arena_rules.gd")

func _initialize() -> void:
	call_deferred("run")

func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "res://preview-fx.png"
	root.size = Vector2i(720, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve()
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.visible = false
	var arena = game.arena
	game.rules.phase = "play"
	game.rules.balls.append({"id": 700, "owner": 0, "p": Vector2(-1.2, 1.5), "v": Vector2(1.5, -12.0), "bounces": 0, "ttl": 4.0, "damage": 1, "boosted": false})
	game.rules.balls.append({"id": 701, "owner": 1, "p": Vector2(1.4, -1.0), "v": Vector2(-2.0, 12.0), "bounces": 0, "ttl": 4.0, "damage": 2, "boosted": true})
	var dt = 1.0 / 60.0
	for i in range(8):
		for ball in game.rules.balls:
			ball.p += ball.v * dt
		arena.update_state(game.rules, 0, dt)
		await process_frame
	arena.explosion(Vector2(1.6, -3.2), Rules.EXPLOSION_RADIUS)
	arena.burst(Vector2(-1.8, 3.4), Color("72ddc6"), true)
	arena.power_flash(Vector2(0.0, 4.4), "bloom")
	arena.burst(Vector2(-0.6, -2.0), Color("ef947e"), false)
	for i in range(7):
		for ball in game.rules.balls:
			ball.p += ball.v * dt
		arena.update_state(game.rules, 0, dt)
		await process_frame
	var cam: Camera3D = arena.camera
	var play = await frame()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 40
	cam.h_offset = 0
	cam.v_offset = 0
	cam.global_position = Vector3(0.5, 5.5, 6.5)
	cam.look_at(Vector3(0.2, 0.3, 0.0))
	var close = await frame()
	var sheet = Image.create(1440, 720, false, play.get_format())
	sheet.blit_rect(play, Rect2i(0, 0, 720, 720), Vector2i.ZERO)
	sheet.blit_rect(close, Rect2i(0, 0, 720, 720), Vector2i(720, 0))
	print("FX_SHEET ", sheet.save_png(path))
	quit()
