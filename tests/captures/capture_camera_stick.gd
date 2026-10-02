extends SceneTree
# The camera stick in a real match: the framed seat, turned all the way each side, pulled in
# and pushed back (needs a GPU; omit --headless).
# Usage: godot -s tests/captures/capture_camera_stick.gd -- <output prefix>
const SEATS = {"home": [0.0, 1.0], "left": [1.065, 1.0], "right": [-1.065, 1.0], "close": [0.0, 1.8], "close-left": [0.7, 2.4], "far": [0.0, 0.8]}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "user://preview-camera"
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.5).timeout
	game.start_level(0)
	game.set_physics_process(false)
	game.set_process(false)
	for f in range(20):
		game._process(1.0 / 60.0)
		await process_frame
	for seat in SEATS:
		game.game_settings.view_yaw = SEATS[seat][0]
		game.game_settings.view_zoom = SEATS[seat][1]
		game.arena.steer_view(SEATS[seat][0], SEATS[seat][1])
		for f in range(3):
			game._process(1.0 / 60.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var path = "%s-%s.png" % [prefix, seat]
		print("CAMERA ", path, " ", root.get_texture().get_image().save_png(path))
	game.game_settings.view_yaw = 0.0
	game.game_settings.view_zoom = 1.0
	quit()
