extends SceneTree
## Exercise real GUI mouse dispatch after scaling/resizing; player saves are isolated.
var failures = 0
var checks = 0
var pointer_initialized = false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + message)
    else: print("PASS: " + message)
func click_control(target: Control) -> void:
    # get_global_rect() is in logical canvas units. push_input(..., true) expects
    # those viewport coordinates; native pixel positions also include final stretch.
    var at = target.get_global_transform_with_canvas() * (target.size * 0.5)
    var pixel_at = root.get_final_transform() * at
    if not pointer_initialized:
        root.notify_mouse_entered()
        pointer_initialized = true
    var motion = InputEventMouseMotion.new()
    motion.position = at
    motion.global_position = at
    root.push_input(motion, true)
    var hovered = root.gui_get_hovered_control()
    print("PC_INPUT logical=", at, " pixel=", pixel_at, " final=", root.get_final_transform(), " hover=", hovered.get_path() if hovered != null else "<none>")
    check(hovered == target, "Mouse hover reaches the actual equip button after resize")
    check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(pixel_at), "Equip click lies inside the physical client area")
    for pressed in [true, false]:
        var event = InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
        event.position = at
        event.global_position = at
        root.push_input(event, true)
        await process_frame
func run() -> void:
    root.size = Vector2i(1280, 720)
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    game.set_physics_process(false)
    game.skins.unlock_all = true
    game.skins.config_path = "user://pc-layout-skins.cfg"
    game.game_settings.config_path = "user://pc-layout-settings.cfg"
    # This is a layout/GUI test, so isolate it from the real first-run tutorial's
    # delayed overlay, which would legitimately capture clicks above the hangar.
    game.game_settings.tutorial_lobby = true
    game.game_settings.tutorial_match = true
    game.game_settings.tutorial_shop = true
    game.hud.sync_skins(game.skins)
    for frame in range(8): await process_frame
    if DisplayServer.get_name() != "headless":
        var usable = DisplayServer.screen_get_usable_rect(root.current_screen)
        check(usable.encloses(Rect2i(root.position, root.size)), "Desktop client window fits the monitor work area")
        print("PC_WINDOW usable=",usable," actual=",Rect2i(root.position,root.size))
    game.hud.open_skins()
    for resolution in [Vector2i(1280, 720), Vector2i(1024, 600), Vector2i(800, 600), Vector2i(1920, 1080), Vector2i(720, 1280)]:
        root.size = resolution
        game.fit_content_scale()
        game.skins.selected = 0
        game.hud.preview_skin(6)
        for frame in range(8): await process_frame
        var hud = game.hud
        var bounds = Rect2(Vector2.ZERO, hud.size)
        var button_rect = hud.skin_action.get_global_rect()
        print("PC_LAYOUT size=",resolution," bounds=",bounds," panel=",hud.skins_panel.get_global_rect()," equip=",button_rect)
        check(bounds.encloses(hud.skins_panel.get_global_rect()), "Hangar stays within viewport at %s" % resolution)
        check(bounds.encloses(button_rect), "Equip button stays entirely visible at %s" % resolution)
        check(not hud.skin_action.disabled, "Unlocked Rosca is selectable at %s" % resolution)
        await click_control(hud.skin_action)
        check(game.skins.selected == 6 and hud.skin_action.text == "EQUIPADA", "Mouse click equips Rosca through GUI dispatch at %s" % resolution)
        var back = hud.skin_action.get_parent().get_child(1)
        check(bounds.encloses(back.get_global_rect()), "Back button remains visible at %s" % resolution)
        if OS.get_cmdline_user_args().size() > 0 and resolution == Vector2i(1280, 720):
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "-hangar.png")
    print("PC_LAYOUT_RESULT checks=", checks, " failures=", failures)
    game.queue_free()
    await process_frame
    await process_frame
    quit(failures)
