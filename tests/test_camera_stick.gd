extends SceneTree
# Joystick de câmara: para o lado roda a câmara à volta da arena (no máximo 61 graus para
# cada lado, nunca do lado do rival), para cima aproxima, para baixo afasta, e dois toques
# repõem a câmara de origem. A escolha fica guardada para a partida seguinte.
var failures = 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _initialize() -> void:
	call_deferred("run")

func touch(hud, at: Vector2, down: bool, index: int = 3) -> void:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	hud._input(event)

func drag(hud, at: Vector2, index: int = 3) -> void:
	var event = InputEventScreenDrag.new()
	event.index = index
	event.position = at
	hud._input(event)

func hold(game, hud, push: Vector2, seconds: float) -> void:
	# Separate holds, not a double tap.
	hud.camera_tap_ms = -1000
	touch(hud, hud.camera_home, true)
	drag(hud, hud.camera_home + push * 30.0)
	for f in range(int(seconds * 60)):
		game.steer_camera(1.0 / 60.0)
		game.arena.update_state(game.rules, game.local_team, 1.0 / 60.0)
	touch(hud, hud.camera_home + push * 30.0, false)
	game.steer_camera(1.0 / 60.0)
	game.arena.update_state(game.rules, game.local_team, 1.0 / 60.0)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_pve()
	await process_frame
	await process_frame
	var hud = game.hud
	var arena = game.arena
	game.game_settings.view_yaw = 0.0
	game.game_settings.view_zoom = 1.0
	game.frame_arena()
	arena.update_state(game.rules, game.local_team, 1.0 / 60.0)
	var seat: Transform3D = arena.camera.global_transform
	var size: float = arena.camera.size
	check(arena.match_seat and arena.seat_size > 0.0, "A partida tem um lugar de câmara para o joystick")
	check(hud.camera_home.x > hud.size.x * 0.5 and hud.camera_home.y < hud.arena_rect.get_center().y, "O joystick de câmara fica em cima, à direita")

	hold(game, hud, Vector2(1, 0), 0.4)
	var now_z: Vector3 = arena.camera.global_transform.basis.z
	var turned: float = Vector2(now_z.x, now_z.z).angle_to(Vector2(seat.basis.z.x, seat.basis.z.z))
	check(absf(arena.view_yaw) > 0.3 and absf(turned) > 0.3, "Arrastar para o lado roda a câmara (%.2f rad)" % arena.view_yaw)
	check(hud.camera_vector == Vector2.ZERO, "Largar o joystick para a câmara")

	hold(game, hud, Vector2(1, 0), 5.0)
	check(absf(arena.view_yaw) <= arena.VIEW_YAW_MAX + 0.001, "A rotação pára nos 61 graus")
	var ahead: Vector3 = -arena.camera.global_transform.basis.z
	var home_ahead: Vector3 = -seat.basis.z
	check(Vector2(ahead.x, ahead.z).dot(Vector2(home_ahead.x, home_ahead.z)) > 0.0, "Nem no máximo a câmara passa para o lado do rival")
	hold(game, hud, Vector2(-1, 0), 10.0)
	check(arena.view_yaw <= arena.VIEW_YAW_MAX + 0.001 and arena.view_yaw > 1.0, "Roda o mesmo para o outro lado")

	hold(game, hud, Vector2(0, -1), 0.6)
	check(arena.view_zoom > 1.3 and arena.camera.size < size, "Para cima aproxima (zoom %.2f)" % arena.view_zoom)
	hold(game, hud, Vector2(0, -1), 5.0)
	check(arena.view_zoom <= arena.VIEW_ZOOM_MAX + 0.001, "O zoom tem limite")
	check(game.game_settings.view_zoom == arena.view_zoom, "A escolha fica nas opções guardadas")
	hold(game, hud, Vector2(0, 1), 5.0)
	check(arena.view_zoom < 1.0 and arena.view_zoom >= arena.VIEW_ZOOM_MIN, "Para baixo afasta, até um limite")

	touch(hud, hud.camera_home, true)
	touch(hud, hud.camera_home, false)
	touch(hud, hud.camera_home, true)
	touch(hud, hud.camera_home, false)
	game.steer_camera(1.0 / 60.0)
	arena.update_state(game.rules, game.local_team, 1.0 / 60.0)
	check(arena.view_yaw == 0.0 and arena.view_zoom == 1.0, "Dois toques repõem a câmara")
	check(arena.camera.global_transform.basis.z.is_equal_approx(seat.basis.z) and is_equal_approx(arena.camera.size, size), "E ela volta exatamente ao lugar de origem")

	print("CAMERA_STICK_RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
