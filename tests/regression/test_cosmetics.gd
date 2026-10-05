extends SceneTree
# OFICINA: paints per skin (a corrupted set for the story's hard skins), shot colours, the
# brick wallet, the hangar workshop, and the looks worn in a match.
const Cosmetics = preload("res://scripts/progression/cosmetics.gd")
const Skins = preload("res://scripts/progression/skins.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var c = Cosmetics.new()
	c.path = "user://cosmetics-unit.cfg"
	var wallet = {"bricks": 1000}
	# The hard skins of the second season wear the corrupted set; the champions do not.
	var salvo_hard = Skins.hard_of_boss(1)
	assert(Cosmetics.is_corrupted_skin(salvo_hard, Skins.CATALOG) and not Cosmetics.is_corrupted_skin(1, Skins.CATALOG))
	for index in range(Skins.CATALOG.size()):
		var name = String(Skins.CATALOG[index].name)
		if name == "BIT DE ELITE" or name == "MAGNUS IMPERADOR":
			assert(not Cosmetics.is_corrupted_skin(index, Skins.CATALOG), name + " is a champion, not corrupted")
	assert(Cosmetics.paints_for(salvo_hard, Skins.CATALOG).all(func(p): return p.kind == "corrupted"))
	assert(Cosmetics.paints_for(1, Skins.CATALOG).all(func(p): return p.kind == "normal"))
	for paint in Cosmetics.PAINTS:
		if paint.kind == "corrupted":
			# Always dark: the hull under a third of full brightness.
			assert(Color(paint.palette.shell).get_luminance() < 0.3, paint.id + " is dark")
	# Buying: the wallet pays, a second purchase does not, earned looks are not for sale.
	assert(c.buy("lava", wallet) and wallet.bricks == 600 and c.owns("lava"))
	assert(not c.buy("lava", wallet) and wallet.bricks == 600)
	assert(not c.buy("ouro", wallet) and not c.can_buy("ouro"))
	assert(not c.buy("espectro", {"bricks": 10}))
	# Wearing: a normal paint on a normal skin; never across the sets.
	assert(c.equip_paint(1, "lava", Skins.CATALOG) and c.palette_for(1).shell == "3a1d14")
	assert(not c.equip_paint(salvo_hard, "lava", Skins.CATALOG))
	assert(not c.equip_paint(1, "carbono", Skins.CATALOG), "not owned")
	assert(c.award("ouro") and not c.award("ouro"))
	assert(c.buy("toxico", wallet) and c.equip_shot("toxico") and c.shot_color() == "6dff5a")
	assert(c.save_preferences() == OK)
	var again = Cosmetics.new()
	again.path = c.path
	again.load_preferences()
	assert(again.owns("lava") and again.paint_of(1) == "lava" and again.shot == "toxico" and again.owns("ouro"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(c.path))

	# In the game: the hangar workshop, the wallet, the pedestal, the match.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.cosmetics.path = "user://cosmetics-test.cfg"
	game.power_shop.config_path = "user://powers-cosmetics-test.cfg"
	game.power_shop.bricks = 700
	game.hud.sync_powers(game.power_shop)
	game.hud.open_skins()
	game.hud.preview_skin(0)
	game.hud.set_workshop(true)
	assert(game.hud.workshop_mode and game.hud.workshop_scroll.visible and not game.hud.skins_scroll.visible)
	game.hud.pick_workshop("paint", "lava")
	assert(game.hud.viewer_paint == Cosmetics.paint_entry("lava").palette, "the pedestal shows the paint being looked at")
	assert(game.hud.workshop_action.text.contains("400") and not game.hud.workshop_action.disabled)
	game.hud.workshop_act()
	assert(game.cosmetics.owns("lava") and game.power_shop.bricks == 300 and game.cosmetics.paint_of(0) == "lava", "bought and worn")
	assert(game.hud.workshop_action.disabled)
	game.hud.pick_workshop("paint", "real")
	assert(game.hud.workshop_action.disabled, "500 is out of reach with 300")
	game.hud.pick_workshop("shot", "arco_iris")
	game.hud.workshop_act()
	assert(game.cosmetics.shot == "arco_iris" and game.power_shop.bricks == 0)
	game.hud.close_skins()
	assert(not game.hud.workshop_mode)
	game.skins.selected = 0
	game.start_pve()
	await process_frame
	assert(game.arena.unit_paints[0] == Cosmetics.paint_entry("lava").palette and game.arena.unit_paints[1].is_empty())
	var first: Color = game.arena.shot_colors[0]
	await create_timer(0.4).timeout
	assert(game.arena.shot_colors[0] != first, "rainbow shots turn through the colours")
	assert(game.arena.unit_skins[0] == 0)
	for path in [game.cosmetics.path, game.power_shop.config_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	await process_frame
	print("PASS COSMETICS: paints, corrupted set, shots, wallet, workshop, match looks")
	quit()
