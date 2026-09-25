extends SceneTree
# Every screen of the interface on one contact sheet, phone held upright: the lobby and its
# mode sheet, skins,
# powers, options, levels, PvP, pause, a match with its cards and stick, a goal, a won level
# with its unlock notification and the defence warning (needs a GPU; omit --headless).
# Usage: godot -s tests/capture_ui.gd -- <output.png> [landscape|portrait] [folder for each screen]
const TMP = "res://tests/ui-capture.tmp"
const W = 540
const H = 1080

var shots: Array = []

func _initialize() -> void:
	call_deferred("run")

func grab() -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	shots.append(root.get_texture().get_image())

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var path = args[0] if args.size() > 0 else "res://preview-ui.png"
	var wide = args.size() > 1 and args[1] == "landscape"
	root.size = Vector2i(H, W) if wide else Vector2i(W, H)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.skins.config_path = TMP
	game.campaign.config_path = TMP
	game.game_settings.config_path = TMP
	await create_timer(0.6).timeout
	var hud = game.hud
	await grab()
	hud.lobby.open_sheet()
	await grab()
	hud.lobby.close_sheet()
	hud.open_skins()
	hud.preview_skin(3)
	await create_timer(0.4).timeout
	await grab()
	hud.close_skins()
	hud.open_powers()
	await grab()
	hud.close_powers()
	hud.open_video()
	await grab()
	hud.close_video()
	hud.open_levels()
	await grab()
	hud.close_levels()
	hud.open_pvp()
	await grab()
	hud.close_pvp()
	game.start_level(2)
	game.rules.phase = "play"
	for i in range(40):
		game._physics_process(1.0 / 60.0)
		await process_frame
	hud.defense_notice = "A TUA BALIZA ESTÁ DESPROTEGIDA!"
	hud.defense_notice_time = 2.0
	hud.queue_redraw()
	await grab()
	game.pause_pve()
	await grab()
	game.resume_pve()
	game.rules.phase = "goal"
	game.rules.winner = game.local_team
	hud.update_match(game.rules, "")
	hud.queue_redraw()
	await grab()
	game.rules.phase = "finished"
	game.rules.winner = game.local_team
	game.finish_level()
	hud.announce_power("volley", "SALVA")
	hud.update_match(game.rules, "")
	hud.queue_redraw()
	await create_timer(0.3).timeout
	await grab()
	if args.size() > 2:
		for i in range(shots.size()):
			shots[i].save_png(args[2].path_join("ui-%02d.png" % i))
	var cols = 5
	var rows = int(ceil(shots.size() / float(cols)))
	var cell: Vector2i = shots[0].get_size()
	var sheet = Image.create(cell.x * cols, cell.y * rows, false, shots[0].get_format())
	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, cell), Vector2i(i % cols * cell.x, i / cols * cell.y))
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	print("UI_SHEET ", shots.size(), " ", sheet.save_png(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	quit()
