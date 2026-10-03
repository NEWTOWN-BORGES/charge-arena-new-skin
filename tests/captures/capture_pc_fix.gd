extends SceneTree
const Settings = preload("res://scripts/settings/game_settings.gd")
var prefix: String
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
    for frame in range(8): await process_frame
    await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png(prefix + "-" + name + ".png") == OK)
    print("PC_CAPTURE ",name)
func run() -> void:
    prefix = OS.get_cmdline_user_args()[0]
    root.size = Vector2i(1280,720)
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    game.game_settings.config_path = "user://pc-fix-capture-settings.cfg"
    game.game_settings.tutorial_lobby = true
    game.game_settings.tutorial_match = true
    game.skins.unlock_all = true
    game.skins.selected = 5
    game.hud.sync_skins(game.skins)
    game.hud.open_skins()
    game.hud.preview_skin(5)
    await shot("hangar-final")
    game.hud.close_skins()
    game.start_pve(game.Rules.quick_map("aurora"))
    game.rules.phase = "play"
    game.hud.show_game("pve",0)
    for frame in range(20): game.arena.update_state(game.rules,0,1.0/60.0)
    for index in range(Settings.VIEW_NAMES.size()):
        game.change_camera_view(index)
        for frame in range(20): game.arena.update_state(game.rules,0,1.0/60.0)
        await shot(["vista-geral","vista-proxima","terceira-pessoa"][index])
        print("PC_CAMERA_POSE view=",index," chase=",game.arena.chase," position=",game.arena.camera.global_position)
    game.hud.open_video()
    await shot("opcoes-vistas")
    game.queue_free()
    await process_frame
    await process_frame
    print("PC_CAPTURE_RESULT views=3")
    quit(0)
