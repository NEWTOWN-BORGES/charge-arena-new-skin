extends SceneTree
# The 3 v 3 arena as a phone shows it (needs a GPU): the squad match started from the menu,
# twenty seconds of the six robots playing each other, then one frame.
# Usage: godot -s tests/capture_squad.gd -- <output.png> [seconds of play] [width] [height] [watch/play]
const Rules = preload("res://scripts/arena_rules.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var seconds: float = float(args[1]) if args.size() > 1 else 20.0
	root.size = Vector2i(int(args[2]) if args.size() > 2 else 540, int(args[3]) if args.size() > 3 else 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/style-preview.tmp"
	game.game_settings.tutorial_match = true
	await create_timer(0.3).timeout
	game.start_squad(not (args.size() > 4 and args[4] == "play"))
	await create_timer(0.5).timeout
	# Play it forward here, faster than the software renderer would.
	var rules = game.rules
	rules.phase = "play"
	var dt = 1.0 / 60.0
	for tick in range(int(seconds / dt)):
		var commands: Array = []
		for index in range(rules.players.size()):
			commands.append(rules.squad_command(index))
		game.arena.capture_motion(rules)
		rules.step(dt, commands)
		if rules.phase != "play":
			rules.phase = "play"
	print("SQUAD bricks %d / %d, shots in the air %d" % [rules.brick_count(0), rules.brick_count(1), rules.balls.size()])
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	print("SAVED ", args[0])
	quit(0)
