extends SceneTree
# One frame of a world from a free camera (needs a GPU), to inspect the scenery up close.
# Usage: godot -s tests/capture_look_at.gd -- <out.png> <world> <x,y,z camera> <x,y,z target> [fov]
const Rules = preload("res://scripts/arena_rules.gd")

func _initialize() -> void:
	call_deferred("run")

func vec(text: String) -> Vector3:
	var p = text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/style-preview.tmp"
	game.game_settings.tutorial_match = true
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve(Rules.quick_map(args[1]))
	await create_timer(0.8).timeout
	game.hud.visible = false
	var cam = Camera3D.new()
	game.arena.add_child(cam)
	cam.fov = float(args[4]) if args.size() > 4 else 55.0
	cam.position = vec(args[2])
	cam.look_at(vec(args[3]))
	cam.current = true
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	print("LOOK_AT ", root.get_texture().get_image().save_png(args[0]))
	quit()
