extends SceneTree
var failures = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.hud.open_skins()
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280), Vector2i(360, 640), Vector2i(1600, 720)]:
		root.size = dimensions
		for frame in range(6): await process_frame
		var hud = game.hud
		var screen = Rect2(Vector2.ZERO, hud.size).grow(0.5)
		check(screen.encloses(hud.skins_panel.get_global_rect()), "Hangar fits %s" % dimensions)
		check(screen.encloses(hud.skin_action.get_global_rect()), "Equip action stays on screen at %s" % dimensions)
		var back: Button = hud.skin_action.get_parent().get_child(1)
		check(screen.encloses(back.get_global_rect()) and back.size.y >= 48, "Back action is visible and large enough at %s" % dimensions)
		check(hud.viewer.size.y >= 140 and hud.skins_scroll.size.y >= 110, "Model and description retain usable space at %s" % dimensions)
	game.queue_free()
	await process_frame
	await process_frame
	print("GALLERY_LAYOUT_RESULT failures=", failures)
	quit(failures)
