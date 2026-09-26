extends SceneTree
# A quick match on each chosen world, portrait, HUD hidden (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_quick.gd -- <output prefix> <world ...>
const Rules = preload("res://scripts/arena_rules.gd")
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0] if args.size() > 0 else "res://preview-quick"
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	await create_timer(0.5).timeout
	for i in range(1, args.size()):
		game.start_pve(Rules.quick_map(args[i]))
		await create_timer(1.0).timeout
		game.rules.phase = "play"
		for f in range(20):
			game._physics_process(1.0 / 60.0)
			await process_frame
		game.hud.visible = false
		await RenderingServer.frame_post_draw
		var path = "%s-%s.png" % [prefix, args[i]]
		print("QUICK ", path, " ", root.get_texture().get_image().save_png(path))
		game.hud.visible = true
	quit()
