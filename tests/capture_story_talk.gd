extends SceneTree
# Captures the Modo história conversation cards on a phone-sized screen (needs a GPU):
#   godot -s tests/capture_story_talk.gd -- <output folder>
func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	root.size = Vector2i(540, 1170)
	var game = load("res://scenes/main.tscn").instantiate()
	game.skins.config_path = "user://story-capture-skins.cfg"
	root.add_child(game)
	await create_timer(0.6).timeout
	# A fresh player, so the story opens with its prologue.
	game.skins.defeated.clear()
	game.skins.story_won.clear()
	if game.hud.tutorial_running():
		game.hud.tutorial.close(true)
	var out = OS.get_cmdline_user_args()[0]
	game.start_story(0, false)
	var talk = game.hud.story_talk
	for i in [0, 2, 3, 7]:
		while talk.index < i:
			talk.typed = 999
			talk.advance()
		await shot(out + "/talk%d.png" % i)
	talk.close(true)
	await create_timer(0.3).timeout
	var teach = game.StoryScript.lines(10, "teach")
	game.hud.play_story_talk([teach[1], teach[4]])
	await shot(out + "/talk_h.png")
	talk.typed = 999
	talk.advance()
	await shot(out + "/talk_e.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://story-capture-skins.cfg"))
	print("CAPTURE_STORY_TALK done")
	quit()
