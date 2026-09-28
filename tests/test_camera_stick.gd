extends SceneTree
# Câmara no próprio mapa: arrastar um dedo para o lado roda a câmara à volta da arena (no
# máximo 61 graus para cada lado, nunca do lado do rival), para cima aproxima, para baixo
# afasta; dois dedos fazem pinça; dois toques repõem a câmara. Puxar o zoom para lá do
# máximo põe a câmara atrás do robô (3.ª pessoa); afastar sai. A escolha fica guardada.
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

func swipe(game, hud, from: Vector2, by: Vector2) -> void:
	hud.camera_tap_ms = -1000
	touch(hud, from, true)
	for i in range(10):
		drag(hud, from + by * (i + 1) / 10.0)
		game.steer_camera(1.0 / 60.0)
		game.arena.update_state(game.rules, game.local_team, 1.0 / 60.0)
	touch(hud, from + by, false)
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
	var middle = Vector2(hud.size.x * 0.5, (hud.score_rect.end.y + hud.touch_top) * 0.5)
	check(hud.on_map(middle), "O meio da arena é zona de câmara")
	check(not hud.on_map(Vector2(hud.size.x * 0.5, hud.touch_top + 20)), "A faixa dos polegares continua a ser para mover")

	swipe(game, hud, middle, Vector2(160, 0))
	check(game.game_settings.view_yaw < -0.3, "Arrastar para o lado roda a câmara")
	check(not arena.camera.global_transform.origin.is_equal_approx(seat.origin), "A câmara saiu do lugar")
	for i in range(8):
		swipe(game, hud, middle, Vector2(900, 0))
	check(absf(game.game_settings.view_yaw) <= arena.VIEW_YAW_MAX + 0.001, "A rotação para nos 61 graus")

	swipe(game, hud, middle, Vector2(0, -120))
	check(game.game_settings.view_zoom > 1.2, "Arrastar para cima aproxima")
	swipe(game, hud, middle, Vector2(0, 90))
	var zoom_after_out = game.game_settings.view_zoom
	check(zoom_after_out < 1.7, "Arrastar para baixo afasta")

	for i in range(6):
		swipe(game, hud, middle, Vector2(0, -260))
	check(arena.chase, "Puxar para lá do zoom máximo põe a câmara em 3.ª pessoa")
	for i in range(30):
		arena.update_state(game.rules, game.local_team, 1.0 / 60.0)
	var pilot: Vector3 = arena.units[game.local_team].global_position
	check(arena.camera.global_position.distance_to(pilot) < 7.0 and arena.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Em 3.ª pessoa a câmara segue o robô de perto")
	hud.camera_tap_ms = -1000
	touch(hud, middle, true)
	for i in range(10):
		drag(hud, middle + Vector2(18 * (i + 1), 0))
		game.steer_camera(1.0 / 60.0)
		arena.update_state(game.rules, game.local_team, 1.0 / 60.0)
	check(arena.chase and absf(arena.chase_look) > 0.5, "Em 3.ª pessoa arrastar para o lado olha à volta do robô")
	touch(hud, middle + Vector2(180, 0), false)
	for i in range(90):
		game.steer_camera(1.0 / 60.0)
		arena.update_state(game.rules, game.local_team, 1.0 / 60.0)
	check(arena.chase and absf(arena.chase_look) < 0.05, "Ao largar, a vista volta para a frente do robô")
	for i in range(4):
		swipe(game, hud, middle, Vector2(0, 200))
	check(not arena.chase, "Afastar sai da 3.ª pessoa")

	hud.camera_tap_ms = -1000
	touch(hud, middle, true)
	touch(hud, middle, false)
	touch(hud, middle, true)
	touch(hud, middle, false)
	game.steer_camera(1.0 / 60.0)
	check(game.game_settings.view_yaw == 0.0 and game.game_settings.view_zoom == 1.0, "Dois toques repõem a câmara")
	print("CAMERA_STICK_RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
