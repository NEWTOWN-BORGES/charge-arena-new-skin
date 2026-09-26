extends SceneTree
# The Ilha Jardim from the comparison camera of tools/color/blender_world_view.py, through the
# game's colour pipeline, to set beside the Blender view. Needs a GPU.
# Usage: godot -s tests/capture_world_view.gd -- <out.png>
const EYE = Vector3(9.5, 13.5, 17.0)
const TARGET = Vector3(0.0, 0.8, 0.0)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(900, 700)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.5).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve(game.Rules.quick_map("jardim"))
	await create_timer(1.0).timeout
	game.hud.visible = false
	var cam = Camera3D.new()
	cam.fov = 40.0
	game.arena.add_child(cam)
	cam.global_position = EYE
	cam.look_at(TARGET)
	cam.current = true
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	print("VIEW ", root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]))
	quit()
