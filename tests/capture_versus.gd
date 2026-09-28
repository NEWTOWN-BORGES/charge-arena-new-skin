extends SceneTree
# Captures the story's BIT vs rival fight cards (needs a GPU):
#   godot -s tests/capture_versus.gd -- <output folder>
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(540, 1170)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	if game.hud.tutorial_running():
		game.hud.tutorial.close(true)
	var out = OS.get_cmdline_user_args()[0]
	var Story = game.StoryScript
	for card in [["vs_rosca", Story.versus(Story.BIT, Story.ROSCA, 0, 11, "Oficina do Relógio")], ["vs_magnus", Story.versus(Story.BIT_ELITE, Story.MAGNUS_IMP, 0, 11, "Centro de Voltara", true)]]:
		game.hud.play_story_talk([card[1]])
		await create_timer(1.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/%s.png" % card[0])
		game.hud.story_talk.close(true)
	print("CAPTURE_VERSUS done")
	quit()
