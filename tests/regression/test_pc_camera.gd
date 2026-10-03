extends SceneTree
# Exercise the real viewport input route: mouse/keyboard events must reach the match
# camera without pretending to be a touchscreen, and the settings UI selects every view.
const Settings = preload("res://scripts/settings/game_settings.gd")
const Main = preload("res://scripts/main.gd")
var failures = 0

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func mouse_button(index: int, at: Vector2, down: bool, emulated: bool = false) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = index
	event.position = at
	event.global_position = at
	event.pressed = down
	event.factor = 1.0
	if emulated:
		event.device = InputEvent.DEVICE_ID_EMULATION
	root.push_input(event, true)

func mouse_drag(at: Vector2, delta: Vector2, mask: int) -> void:
	var event = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = delta
	event.button_mask = mask
	root.push_input(event, true)

func key(code: int, down: bool, repeat: bool = false) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.echo = repeat
	root.push_input(event, true)

func tick(game, count: int = 1) -> void:
	for frame in range(count):
		game.steer_camera(1.0 / 60.0)
		game.arena.update_state(game.rules, game.local_team, 1.0 / 60.0)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.game_settings.config_path = "user://pc-camera-test.cfg"
	game.start_pve()
	game.pve_paused = false
	game.rules.phase = "play"
	await process_frame
	await process_frame
	var hud = game.hud
	var arena = game.arena
	var middle = Vector2(hud.size.x * 0.5, (hud.score_rect.end.y + hud.touch_top) * 0.5)
	check(hud.on_map(middle), "PC pointer is inside the match camera area")
	check(hud.camera_view_choice.item_count == Settings.VIEW_NAMES.size(), "UI offers all three camera views")

	game.change_camera_view(Settings.VIEW_OVERVIEW)
	tick(game)
	var overview_size: float = arena.camera.size
	# Item selection follows the actual signal used by the choice/chips, while paused.
	hud.video_overlay.show()
	for view in range(Settings.VIEW_NAMES.size()):
		hud.camera_view_choice.select(view)
		hud.camera_view_choice.item_selected.emit(view)
		check(game.game_settings.view_mode == view and hud.camera_view_choice.selected == view, "UI applies and synchronizes camera view %d" % view)
		check(arena.chase == (view == Settings.VIEW_CHASE), "UI camera state matches view %d" % view)
		if view == Settings.VIEW_CLOSE:
			check(arena.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and arena.camera.size < overview_size * 0.7, "Close view really zooms the arena")
		if view == Settings.VIEW_CHASE:
			check(arena.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and arena.camera.global_position.distance_to(arena.units[0].global_position) < 7.0, "Third person starts behind the pilot while settings remain open")
	var seated: Transform3D = arena.camera.global_transform
	game.frame_arena()
	check(arena.camera.global_transform.is_equal_approx(seated), "HUD reframe preserves the third-person camera pose")
	hud.video_overlay.hide()

	var pilot_before: Vector3 = arena.units[0].global_position
	var camera_before: Vector3 = arena.camera.global_position
	game.rules.players[0].p.x += 2.0
	tick(game, 120)
	check(arena.units[0].global_position.distance_to(pilot_before) > 1.9 and arena.camera.global_position.distance_to(camera_before) > 1.9, "Third-person camera follows the local pilot")
	var distance_before: float = arena.camera.global_position.distance_to(arena.units[0].global_position)
	mouse_button(MOUSE_BUTTON_WHEEL_UP, middle, true)
	tick(game, 60)
	check(arena.chase and arena.camera.global_position.distance_to(arena.units[0].global_position) < distance_before - 0.2, "PC wheel changes third-person distance")
	mouse_button(MOUSE_BUTTON_RIGHT, middle, true)
	mouse_drag(middle + Vector2(180, 0), Vector2(180, 0), MOUSE_BUTTON_MASK_RIGHT)
	tick(game)
	check(arena.chase_look < -0.8, "Right mouse drag looks around in third person")
	mouse_button(MOUSE_BUTTON_RIGHT, Vector2(10, 10), false)
	tick(game, 120)
	check(game.camera_mouse_button == 0 and absf(arena.chase_look) < 0.01, "Drag releases over UI and recenters third-person look")

	key(KEY_HOME, true)
	tick(game)
	check(not arena.chase and game.game_settings.view_mode == Settings.VIEW_OVERVIEW and is_equal_approx(game.game_settings.view_zoom, 1.0), "Home restores the general view")
	key(KEY_HOME, false)
	key(KEY_C, true)
	key(KEY_C, true, true)
	check(game.game_settings.view_mode == Settings.VIEW_CLOSE, "C switches to close view once per press")
	key(KEY_C, false)
	key(KEY_C, true)
	check(arena.chase and game.game_settings.view_mode == Settings.VIEW_CHASE, "C selects third person")
	key(KEY_C, false)
	key(KEY_C, true)
	check(not arena.chase and game.game_settings.view_mode == Settings.VIEW_OVERVIEW, "C cycles back to general view")
	key(KEY_C, false)

	mouse_button(MOUSE_BUTTON_WHEEL_UP, middle, true)
	tick(game)
	check(game.game_settings.view_zoom > 1.1 and arena.camera.size < overview_size, "PC wheel really zooms the general view")
	mouse_button(MOUSE_BUTTON_MIDDLE, middle, true)
	mouse_drag(middle + Vector2(120, 0), Vector2(120, 0), MOUSE_BUTTON_MASK_MIDDLE)
	tick(game)
	check(game.game_settings.view_yaw < -0.5, "Middle mouse drag rotates the arena")
	mouse_button(MOUSE_BUTTON_MIDDLE, Vector2(10, 10), false)
	tick(game, 120)
	check(is_zero_approx(game.game_settings.view_yaw), "General-view rotation recenters after release")
	key(KEY_E, true)
	tick(game, 30)
	check(game.game_settings.view_yaw < -0.4, "E rotates the camera while held")
	key(KEY_E, false)
	tick(game, 120)
	check(game.camera_keys.is_empty() and is_zero_approx(game.game_settings.view_yaw), "Camera key releases and rotation recenters")
	for step in range(20):
		mouse_button(MOUSE_BUTTON_WHEEL_UP, middle, true)
		tick(game)
	check(arena.chase and hud.camera_view_choice.selected == Settings.VIEW_CHASE, "Wheel can enter third person past the closest general-view zoom")
	for step in range(4):
		mouse_button(MOUSE_BUTTON_WHEEL_DOWN, middle, true)
		tick(game)
	check(not arena.chase, "Wheel zoom out returns from third person to the arena")
	game.change_camera_view(Settings.VIEW_OVERVIEW)

	var zoom_before: float = game.game_settings.view_zoom
	hud.video_overlay.show()
	mouse_button(MOUSE_BUTTON_WHEEL_UP, middle, true)
	key(KEY_C, true)
	tick(game)
	check(is_equal_approx(game.game_settings.view_zoom, zoom_before) and not arena.chase, "Open settings consumes camera shortcuts and wheel")
	hud.video_overlay.hide()
	mouse_button(MOUSE_BUTTON_WHEEL_UP, Vector2(10, 10), true)
	mouse_button(MOUSE_BUTTON_WHEEL_UP, middle, true, true)
	tick(game)
	check(is_equal_approx(game.game_settings.view_zoom, zoom_before), "Wheel outside the map and emulated touch mouse are ignored")
	var clicks_before: int = game.pending_clicks
	mouse_button(MOUSE_BUTTON_LEFT, middle, true)
	mouse_button(MOUSE_BUTTON_LEFT, middle, false)
	check(game.pending_clicks == clicks_before + 1, "Left mouse click still fires one shot")
	# The guest must follow its own robot from the opposite side as well.
	game.local_team = 1
	arena.set_view_team(1)
	game.change_camera_view(Settings.VIEW_CHASE)
	tick(game, 60)
	check(arena.camera.global_position.distance_to(arena.units[1].global_position) < 7.0, "Third person follows the PvP guest's own pilot")
	game.local_team = 0
	arena.set_view_team(0)

	game.change_camera_view(Settings.VIEW_CHASE)
	var saved = Settings.new()
	saved.config_path = game.game_settings.config_path
	saved.load_preferences()
	check(saved.view_mode == Settings.VIEW_CHASE and saved.view_chase, "Camera selection survives preference reload")
	var legacy = ConfigFile.new()
	legacy.set_value("game", "view_chase", true)
	legacy.set_value("game", "view_zoom_v2", 2.1)
	legacy.save(saved.config_path)
	saved.load_preferences()
	check(saved.view_mode == Settings.VIEW_CHASE and is_equal_approx(saved.view_zoom, 2.1), "Legacy chase and zoom preferences are migrated")
	legacy.set_value("game", "view_chase", false)
	legacy.save(saved.config_path)
	saved.load_preferences()
	check(saved.view_mode == Settings.VIEW_CLOSE and is_equal_approx(saved.view_zoom, 2.1), "Legacy close zoom is retained")

	for usable in [Rect2i(0, 0, 1366, 728), Rect2i(-1920, 0, 1024, 600), Rect2i(0, 0, 1920, 1040)]:
		var fitted = Main.desktop_window_rect(Vector2i(1280, 720), usable)
		check(usable.encloses(fitted) and fitted.size.x <= usable.size.x - 32 and fitted.size.y <= usable.size.y - 56, "PC window and native decorations fit usable screen %s" % usable)
		check(absf(float(fitted.size.x) / fitted.size.y - 1280.0 / 720.0) < 0.005, "Window shrink preserves game aspect ratio")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved.config_path))
	game.queue_free()
	await process_frame
	print("PC_CAMERA_RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
