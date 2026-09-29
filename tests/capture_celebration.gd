extends SceneTree
# The goal light show and the robots' reactions (needs a GPU): a wall knocked down (the gate
# opening), a goal (scorer and scored-on), the end of the match.
# Usage: godot -s tests/capture_celebration.gd -- <output prefix> [world]
const Rules = preload("res://scripts/arena_rules.gd")

func _initialize() -> void:
	call_deferred("run")

func step(game, frames: int) -> void:
	for i in range(frames):
		if OS.has_environment("TRACE"):
			print("frame ", i)
		game.arena.update_state(game.rules, 0, 1.0 / 60.0)
		await process_frame

func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("CELEBRATION ", path, " ", root.get_texture().get_image().save_png(path))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0]
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/style-preview.tmp"
	game.game_settings.tutorial_match = true
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve(Rules.quick_map(args[1] if args.size() > 1 else "aurora"))
	game.pve_paused = false
	game.set_physics_process(false)
	game.set_process(false)
	await create_timer(0.8).timeout
	game.hud.visible = false
	var rules = game.rules
	rules.phase = "play"
	await step(game, 10)
	# The far wall falls: its gate opens.
	for brick in rules.bricks:
		if int(brick.team) == 1:
			brick.alive = false
			brick.hp = 0
	var cam = Camera3D.new()
	game.arena.add_child(cam)
	cam.current = true
	cam.fov = 60
	var far_goal = Rules.goal_center(1)
	cam.position = Vector3(0, 3.0, far_goal.y + 9.0)
	cam.look_at(Vector3(0, 2.5, far_goal.y))
	await step(game, 12)
	await shot(prefix + "-1-baliza-abre.png")
	await step(game, 40)
	await shot(prefix + "-2-baliza-aberta.png")
	# A goal by the near robot, into the far goal.
	rules.scores[0] += 1
	rules.winner = 0
	rules.phase = "goal"
	game.arena.goal_scored(0, Vector3(0, 0.1, far_goal.y))
	await step(game, 30)
	await shot(prefix + "-3-golo.png")
	var me: Node3D = game.arena.units[0]
	cam.position = me.position + Vector3(0.3, 1.7, -4.2)
	cam.look_at(me.position + Vector3.UP * 1.0)
	await step(game, 8)
	await shot(prefix + "-4-festejo.png")
	var rival: Node3D = game.arena.units[1]
	cam.position = rival.position + Vector3(-0.3, 1.7, 4.2)
	cam.look_at(rival.position + Vector3.UP * 0.9)
	await step(game, 20)
	await shot(prefix + "-5-desanimo.png")
	rules.phase = "finished"
	await step(game, 45)
	await shot(prefix + "-6-derrota.png")
	cam.position = me.position + Vector3(0.3, 1.7, -4.2)
	cam.look_at(me.position + Vector3.UP * 1.0)
	await step(game, 10)
	await shot(prefix + "-7-vitoria.png")
	quit()
