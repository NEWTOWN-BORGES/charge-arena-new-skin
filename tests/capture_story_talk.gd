extends SceneTree
# Captures the Modo história scenes on a phone-sized screen (needs a GPU):
#   godot -s tests/capture_story_talk.gd -- <output folder>
# A chapter card, a narrator caption, the police siren, the phone call and VOLTZ.
func _initialize() -> void:
	call_deferred("run")

func shot(path: String, frames: int = 40) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	root.size = Vector2i(540, 1170)
	var game = load("res://scenes/main.tscn").instantiate()
	game.skins.config_path = "user://story-capture-skins.cfg"
	root.add_child(game)
	await create_timer(0.6).timeout
	game.skins.defeated.clear()
	game.skins.story_won.clear()
	if game.hud.tutorial_running():
		game.hud.tutorial.close(true)
	var out = OS.get_cmdline_user_args()[0]
	var Story = game.StoryScript
	var talk
	var intro: Array = Story.INTRO
	var find = func(lines: Array, test: Callable) -> int:
		for i in range(lines.size()):
			if test.call(lines[i]):
				return i
		return 0
	var opts = func(l): return l[2] if l.size() > 2 and l[2] is Dictionary else {}
	var picks = [
		["card", intro, 0],
		["narrator", intro, find.call(intro, func(l): return int(l[0]) == Story.NARRADOR)],
		["siren", intro, find.call(intro, func(l): return int(l[0]) == Story.AGENTE)],
		["bit", intro, find.call(intro, func(l): return int(l[0]) == Story.BIT and opts.call(l).get("mood", "") == "hit")],
		["phone", intro, find.call(intro, func(l): return bool(opts.call(l).get("phone", false)))],
		["voltz", Story.OPENING, 2],
	]
	for pick in picks:
		var lines: Array = pick[1]
		var from = pick[2]
		while from > 0 and int(lines[from][0]) != Story.SCENE:
			from -= 1
		game.hud.play_story_talk(lines.slice(from))
		talk = game.hud.story_talk
		if pick[0] == "card":
			await create_timer(1.0).timeout
			await shot(out + "/talk_card.png", 2)
		else:
			# Let the chapter card play out (it sets the backdrop), then step to the line.
			await create_timer(3.0).timeout
			while talk.index < pick[2] - from:
				talk.typed = 999
				talk.next_entry()
			await create_timer(4.0).timeout
			await shot(out + "/talk_%s.png" % pick[0])
		talk.close(true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://story-capture-skins.cfg"))
	print("CAPTURE_STORY_TALK done")
	quit()
