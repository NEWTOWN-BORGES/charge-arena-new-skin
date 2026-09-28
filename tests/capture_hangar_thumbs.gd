extends SceneTree
# Captures the hangar with its skin thumbnails on a phone-sized screen, everything locked
# (needs a GPU):  godot -s tests/capture_hangar_thumbs.gd -- <output.png>
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(540, 1170)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	if game.hud.tutorial_running():
		game.hud.tutorial.close(true)
	game.hud.open_skins()
	await create_timer(0.4).timeout
	# Scroll the thumbnails down to the hard skins at the end of the list.
	for scroll in game.hud.find_children("*", "ScrollContainer", true, false):
		if scroll.is_visible_in_tree():
			scroll.scroll_vertical = 100000
			scroll.scroll_horizontal = 100000
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("CAPTURE_HANGAR_THUMBS done")
	quit()
