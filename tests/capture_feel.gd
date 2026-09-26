extends SceneTree
# Game-feel filmstrip: the same beats a player lives through, captured from the match camera
# a few frames apart — fire, the shot leaving the barrel, a brick hit, a brick breaking, the
# last brick opening the goal, and a goal (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_feel.gd -- <output.png>
const W = 432
const H = 768

var frames: Array = []
var labels: Array = []

func _initialize() -> void:
	call_deferred("run")

func tick(game, count: int) -> void:
	for i in range(count):
		game.arena.update_state(game.rules, 0, 1.0 / 60.0)
		await process_frame

func grab(title: String) -> void:
	await RenderingServer.frame_post_draw
	frames.append(root.get_texture().get_image())
	labels.append(title)

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "res://preview-feel.png"
	root.size = Vector2i(W, H)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.4).timeout
	game.start_level(2)
	game.set_process(false)
	game.set_physics_process(false)
	game.rules.phase = "play"
	game.hud.update_match(game.rules, "")
	game.hud.queue_redraw()
	var arena = game.arena
	await tick(game, 10)
	# FIRE
	arena.shot_feedback(0, true)
	await tick(game, 1)
	await grab("tiro +16 ms")
	await tick(game, 3)
	await grab("tiro +66 ms")
	# IMPACT on a brick of the far wall
	var target: Dictionary = game.rules.bricks[game.rules.bricks.size() / 2 + 4]
	var event = {"kind": "brick_hit", "p": target.p, "team": 1, "heading": Vector2(0.2, -1).normalized(), "brick_id": game.rules.bricks.size() / 2 + 4}
	arena.impact_feedback(event)
	await tick(game, 2)
	await grab("impacto +33 ms")
	# DESTROY
	event.kind = "brick"
	arena.impact_feedback(event)
	await tick(game, 3)
	await grab("quebra +50 ms")
	await tick(game, 8)
	await grab("quebra +183 ms")
	# LAST BRICK: the goal opens
	event.defense_open = true
	arena.impact_feedback(event)
	await tick(game, 8)
	await grab("defesa aberta +130 ms")
	await tick(game, 14)
	await grab("defesa aberta +360 ms")
	# GOAL
	arena.goal_scored(0, Vector3(0, 0.1, -(game.Rules.HALF_LENGTH - 1.03)))
	await tick(game, 4)
	await grab("golo +66 ms")
	await tick(game, 16)
	await grab("golo +330 ms")
	var cols = 5
	var rows = int(ceil(frames.size() / float(cols)))
	var sheet = Image.create(W * cols, H * rows, false, frames[0].get_format())
	for i in range(frames.size()):
		sheet.blit_rect(frames[i], Rect2i(0, 0, W, H), Vector2i(i % cols * W, i / cols * H))
	print("FEEL_SHEET ", frames.size(), " ", labels, " ", sheet.save_png(path))
	quit()
