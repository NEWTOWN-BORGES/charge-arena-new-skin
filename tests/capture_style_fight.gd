extends SceneTree
# An art direction in a live fight (scripts/art_style.gd): both robots under AI control until
# rounds are in the air, then the frame from above and over the shoulder, with a blast.
# Usage: godot -s tests/capture_style_fight.gd -- <output prefix> <style or "atual"> [world]
const Rules = preload("res://scripts/arena_rules.gd")
const ArtStyle = preload("res://scripts/art_style.gd")

func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	print("FIGHT ", path, " ", root.get_texture().get_image().save_png(path))

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var prefix = args[0]
	ArtStyle.current = "" if args[1] == "atual" else args[1]
	var world = args[2] if args.size() > 2 else "aurora"
	root.size = Vector2i(720, 1280)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.focus_exited.disconnect(game.pause_pve)
	game.game_settings.config_path = "res://tests/style-preview.tmp"
	game.game_settings.tutorial_match = true
	await create_timer(0.3).timeout
	game.video.configure(60, 2, false, false)
	game.video.apply(root, game.arena)
	game.start_pve(Rules.quick_map(world))
	game.pve_paused = false
	game.arena.set_skin(0, 5)
	game.arena.set_skin(1, 11)
	await create_timer(0.8).timeout
	game.rules.phase = "play"
	game.set_physics_process(false)
	# Both sides on the AI until several rounds fly.
	for f in range(600):
		var mine = {"move": Vector2(sin(f * 0.04), 0), "fire": f % 9 == 0, "tap": f % 9 == 0, "clicks": 1 if f % 9 == 0 else 0, "manual": true, "power": -1}
		game.rules.step(1.0 / 60.0, [mine, game.rules.ai_command()])
		game.arena.update_state(game.rules, 0, 1.0 / 60.0)
		await process_frame
		if f > 120 and game.rules.balls.size() >= 4:
			break
	print("balls in the air: ", game.rules.balls.size())
	for l in game.arena.find_children("Lamp", "OmniLight3D", true, false):
		print("lamp ", l.is_visible_in_tree(), " ", l.light_energy, " ", l.omni_range, " ", l.global_position)
	var lamps = game.arena.find_children("Lamp", "OmniLight3D", true, false)
	for l in lamps:
		print("lamp ", l.visible, " ", l.is_visible_in_tree(), " ", l.light_energy, " ", l.omni_range, " ", l.global_position)
	game.hud.visible = false
	game.arena.explosion(Vector2(1.0, -2.5), 1.5)
	game.arena.CombatFinish.event(game.arena, {"kind": "explosion", "p": Vector2(1.0, -2.5), "radius": 1.5, "team": 0}, game.rules)
	game.arena.update_state(game.rules, 0, 0.05)
	await shot(prefix + "-luta-cima.png")
	root.size = Vector2i(1280, 720)
	var cam = Camera3D.new()
	game.arena.add_child(cam)
	cam.current = true
	cam.fov = 55
	var me: Node3D = game.arena.units[0]
	cam.global_position = me.global_position + Vector3(1.4, 2.4, 3.8)
	cam.look_at(Vector3(0, 0.4, -1.0))
	await shot(prefix + "-luta-3pessoa.png")
	quit()
