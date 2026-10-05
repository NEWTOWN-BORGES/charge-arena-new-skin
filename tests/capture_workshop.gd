extends SceneTree
## GPU preview of the OFICINA: the hangar workshop and paints worn in the lobby.
## xvfb-run godot --path . -s tests/capture_workshop.gd -- <absolute output prefix>
const Cosmetics = preload("res://scripts/progression/cosmetics.gd")
const Skins = preload("res://scripts/progression/skins.gd")

func _initialize() -> void:
	call_deferred("run")

func grab(path: String) -> void:
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(path)
	assert(error == OK, "Could not save " + path)
	print("CAPTURE ", path)

func run() -> void:
	var prefix = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.cosmetics.path = "user://workshop-preview.cfg"
	game.cosmetics.unlock_all = true
	game.skins.unlock_all = true
	game.power_shop.bricks = 900
	game.hud.sync_powers(game.power_shop)
	await create_timer(0.6).timeout
	TranslationServer.set_locale("pt")
	if game.hud.privacy_prompt_open():
		game.hud.answer_privacy(false)
	game.hud.open_skins()
	game.hud.preview_skin(1)
	game.hud.set_workshop(true)
	game.hud.pick_workshop("paint", "lava")
	await create_timer(0.4).timeout
	await grab(prefix + "-hangar-lava.png")
	var hard = Skins.hard_of_boss(5)
	game.hud.preview_skin(hard)
	game.hud.pick_workshop("paint", "veneno")
	await create_timer(0.4).timeout
	await grab(prefix + "-hangar-veneno.png")
	for id in ["sangue", "vazio", "espectro"]:
		game.hud.pick_workshop("paint", id)
		await create_timer(0.3).timeout
		await grab(prefix + "-hangar-" + id + ".png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.cosmetics.path))
	quit()
