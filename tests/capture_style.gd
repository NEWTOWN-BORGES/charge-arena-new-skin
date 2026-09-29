extends SceneTree
# Trial of an art direction (scripts/art_style.gd): the same match frame, a third-person view
# over the shoulder and a close-up of the pilot, to compare looks side by side (needs a GPU).
# Usage: godot -s tests/capture_style.gd -- <output prefix> <style or "atual"> [world]
const Rules = preload("res://scripts/arena_rules.gd")
const ArtStyle = preload("res://scripts/art_style.gd")

func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	print("STYLE ", path, " ", root.get_texture().get_image().save_png(path))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0]
	ArtStyle.current = "" if args[1] == "atual" else args[1]
	var world = args[2] if args.size() > 2 else "terra"
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/style-preview.tmp"
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve(Rules.quick_map(world))
	game.arena.set_skin(0, 0)
	game.arena.set_skin(1, 11)
	await create_timer(1.0).timeout
	game.rules.phase = "play"
	for f in range(40):
		game._physics_process(1.0 / 60.0)
		await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.hud.visible = false
	await shot(prefix + "-1-cima.png")
	# Over the shoulder of the near robot, looking up the field at the rival and its wall.
	root.size = Vector2i(1280, 720)
	var cam = Camera3D.new()
	game.arena.add_child(cam)
	cam.current = true
	cam.fov = 50
	var me: Node3D = game.arena.units[0]
	var rival: Node3D = game.arena.units[1]
	cam.global_position = me.global_position + Vector3(1.6, 2.6, 4.2)
	cam.look_at(rival.global_position.lerp(me.global_position, 0.35) + Vector3.UP * 0.6)
	await shot(prefix + "-2-terceira-pessoa.png")
	# The pilot up close.
	root.size = Vector2i(900, 1100)
	me.get_node("Body").rotation.y = PI + 0.45
	cam.fov = 30
	cam.global_position = me.global_position + Vector3(0.4, 1.7, 4.6)
	cam.look_at(me.global_position + Vector3.UP * 0.95)
	await shot(prefix + "-3-piloto.png")
	rival.get_node("Body").rotation.y = 0.5
	cam.global_position = rival.global_position + Vector3(-0.4, 1.8, -5.0)
	cam.look_at(rival.global_position + Vector3.UP * 1.0)
	await shot(prefix + "-4-rival.png")
	quit()
