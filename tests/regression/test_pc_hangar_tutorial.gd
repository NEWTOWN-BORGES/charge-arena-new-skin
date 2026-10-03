extends SceneTree
## First-run lobby timer must not cover the hangar or steal its mouse clicks.
var failures = 0
var checks = 0
var pointer_initialized = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func click_control(target: Control, description: String) -> void:
	if not pointer_initialized:
		root.notify_mouse_entered()
		pointer_initialized = true
	var at = target.get_global_transform_with_canvas() * (target.size * 0.5)
	var motion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	check(root.gui_get_hovered_control() == target, description + " receives mouse hover")
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func first_run_game(suffix: String):
	var game = load("res://scenes/main.tscn").instantiate()
	game.force_tutorials = true
	game.game_settings.config_path = "user://pc-tutorial-%s.cfg" % suffix
	game.skins.config_path = "user://pc-tutorial-skins-%s.cfg" % suffix
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.game_settings.config_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.skins.config_path))
	root.add_child(game)
	game.set_physics_process(false)
	return game

func run() -> void:
	var game = first_run_game("hangar")
	var hud = game.hud
	check(not game.game_settings.tutorial_lobby, "First-run lobby tutorial has not been marked seen")
	game.skins.unlock_all = true
	game.skins.selected = 0
	hud.sync_skins(game.skins)
	# Open during the original startup delay, without disabling or marking the tutorial.
	hud.open_skins()
	hud.preview_skin(6)
	await create_timer(1.4).timeout
	await process_frame
	check(hud.skins_overlay.visible, "Hangar stays open after the startup tutorial delay")
	check(game.lobby_tutorial_pending and not hud.tutorial_running(), "Lobby tutorial waits instead of covering the first-run hangar")
	await click_control(hud.skin_action, "EQUIPAR")
	check(game.skins.selected == 6 and hud.skin_action.text == "EQUIPADA", "Real GUI click equips Rosca after the startup timer")
	check(not hud.tutorial_running(), "Equipping keeps the lobby tutorial off the hangar")
	var back: Control = hud.skin_action.get_parent().get_child(1)
	await click_control(back, "VOLTAR")
	await process_frame
	await process_frame
	check(not hud.skins_overlay.visible and hud.tutorial_running(), "Closing the hangar resumes the pending lobby tutorial")
	check(not game.lobby_tutorial_pending, "Showing the lobby tutorial clears its pending request")
	await click_control(hud.tutorial.skip_button, "SALTAR")
	check(game.game_settings.tutorial_lobby, "The actual tutorial skip button marks it seen")
	game.queue_free()
	await process_frame
	await process_frame

	# Entering a match during the same startup delay must preserve the later lobby tour.
	game = first_run_game("match")
	game.game_settings.tutorial_match = true
	game.start_pve()
	game.pve_paused = false
	await create_timer(1.4).timeout
	check(game.lobby_tutorial_pending and not game.hud.tutorial_running(), "Startup lobby tour also waits during a match")
	game.return_to_menu()
	await process_frame
	await process_frame
	check(game.hud.tutorial_running() and not game.lobby_tutorial_pending, "Returning from the match resumes the pending lobby tutorial")
	game.queue_free()
	await process_frame
	await process_frame
	print("PC_HANGAR_TUTORIAL_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
