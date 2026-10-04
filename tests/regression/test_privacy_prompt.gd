extends SceneTree
# The first-launch privacy question and the switches in Options › Jogo, in the real game.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var analytics = game.analytics
	assert(analytics != null and game.Analytics.instance() == analytics)
	assert(analytics.needs_prompt() and not game.hud.privacy_prompt_open())
	game.force_tutorials = true
	game.maybe_privacy_prompt()
	assert(game.hud.privacy_prompt_open())
	# The lobby tour waits for the answer.
	game.maybe_lobby_tutorial()
	assert(not game.hud.tutorial_running())
	game.hud.answer_privacy(true)
	assert(not game.hud.privacy_prompt_open() and not analytics.needs_prompt())
	assert(analytics.privacy.analytics_allowed() and analytics.privacy.errors_allowed())
	assert(game.hud.analytics_choice.button_pressed and game.hud.errors_choice.button_pressed)
	assert(game.hud.privacy_id_label.text.contains(analytics.anonymous_id))
	# Options: statistics off, reports kept; both switches are independent.
	game.hud.analytics_choice.button_pressed = false
	assert(not analytics.privacy.analytics_allowed() and analytics.privacy.errors_allowed())
	game.hud.errors_choice.button_pressed = false
	assert(not analytics.privacy.errors_allowed())
	game.maybe_privacy_prompt()
	assert(not game.hud.privacy_prompt_open())
	for path in ["user://privacy.cfg", "user://analytics_id.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	await process_frame
	print("PASS PRIVACY PROMPT: first-launch question, tour waits, options switches")
	quit()
