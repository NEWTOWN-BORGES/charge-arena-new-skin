extends SceneTree
# The lobby as the phone shows it, portrait (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_lobby.gd -- <output.png>
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "res://preview-lobby.png"
	root.size = Vector2i(720, 1560)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.5).timeout
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	print("LOBBY ", path, " ", root.get_texture().get_image().save_png(path))
	quit()
