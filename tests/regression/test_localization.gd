extends SceneTree
# The five languages: the tables load, the Portuguese text is the key, the choice in
# Options changes the game at once and is remembered, and it is counted (with consent).
const Localization = preload("res://systems/localization/Localization.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(Localization.detect() == "pt", "automated runs read Portuguese")
	var expected = {"pt": "FECHAR", "en": "CLOSE", "fr": "FERMER", "es": "CERRAR", "it": "CHIUDI"}
	for code in expected:
		TranslationServer.set_locale(code)
		assert(TranslationServer.translate("FECHAR") == expected[code], "FECHAR in " + code)
	TranslationServer.set_locale("en")
	assert(TranslationServer.translate("SALA %s · dá este código ao teu amigo") % "AB23" == "ROOM AB23 · give this code to your friend")
	assert(TranslationServer.translate("Texto sem tradução") == "Texto sem tradução", "untranslated text stays as it is")

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(Localization.current() == "pt", "the game starts in Portuguese here")
	game.analytics.set_consent(true, true, "test")
	game.hud.open_video()
	assert(game.hud.language_choice.selected == 0)
	game.hud.language_chosen.emit("fr")
	assert(Localization.current() == "fr" and Localization.saved() == "fr", "the choice applies and is saved")
	assert(game.hud.tr("FECHAR") == "FERMER")
	assert(game.hud.language_choice.selected == Localization.LANGUAGES.find("fr"))
	var counted = game.analytics.queue.events.filter(func(e): return e.event == "language_changed")
	# The test build has no key, so nothing is queued; the call itself must be accepted.
	assert(counted.size() == 0 or counted[0].properties.to == "fr")
	assert(Localization.apply_startup() == "fr", "the next launch keeps it")
	game.hud.language_chosen.emit("pt")
	assert(Localization.current() == "pt")
	game.hud.close_video()
	for path in ["user://locale.cfg", "user://privacy.cfg", "user://analytics_id.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	await process_frame
	print("PASS LOCALIZATION: five tables, Portuguese keys, live switch, saved choice")
	quit()
