extends Control
## The lobby around the previewed arena: your profile and wallet on top, a rail of shortcuts
## down the left (hangar, powers, story, PvP), and in the dock at the bottom the mode you
## will play, the AI level and one big PLAY key. The mode card opens a sheet with the four
## ways to play; PLAY then starts whichever is chosen.
const UiKit = preload("res://scripts/ui_kit.gd")
const Skins = preload("res://scripts/skins.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Powers = preload("res://scripts/powers.gd")

# The campaign is the story: the Taça Aurora, round by round. ARENAS keeps the arenas
# already won for free play, with their bosses.
const MODES = [
	{"id": "story", "name": "MODO HISTÓRIA", "about": "A Taça Aurora, 1.024 pilotos"},
	{"id": "quick", "name": "JOGO RÁPIDO", "about": "Uma partida contra a IA, já"},
	{"id": "campaign", "name": "ARENAS", "about": "As arenas que já venceste, em jogo livre"},
	{"id": "pvp", "name": "PvP", "about": "Dois jogadores na mesma rede, ou o Coliseu"},
]
const RAIL_KEY = Vector2(88, 88)

var hud
var mode_id = "story"
# What the story says right now, filled in by main.sync_story().
var story_round = ""
var story_line = ""
var story_boss = -1
var story_news = false
var profile: Button
var gear: Button
var rail: VBoxContainer
var rail_keys: Dictionary = {}
var mode_card: Button
var sheet: ColorRect
var sheet_panel: PanelContainer
var sheet_cards: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile = Button.new()
	profile.focus_mode = Control.FOCUS_NONE
	profile.tooltip_text = "Hangar: muda de piloto"
	profile.add_theme_stylebox_override("normal", UiKit.panel_style(Color(UiKit.PANEL, 0.9), UiKit.PANEL_EDGE, 20))
	profile.add_theme_stylebox_override("hover", UiKit.panel_style(Color(UiKit.CARD, 0.95), UiKit.CARD_EDGE, 20))
	profile.add_theme_stylebox_override("pressed", UiKit.panel_style(UiKit.CARD_HI, UiKit.SUN, 20))
	profile.draw.connect(draw_profile)
	profile.pressed.connect(func(): hud.open_skins())
	add_child(profile)
	gear = Button.new()
	gear.focus_mode = Control.FOCUS_NONE
	gear.tooltip_text = "Opções"
	gear.draw.connect(draw_gear)
	gear.pressed.connect(func(): hud.open_video())
	add_child(gear)
	rail = VBoxContainer.new()
	rail.add_theme_constant_override("separation", 12)
	add_child(rail)
	for entry in [["hangar", "HANGAR"], ["powers", "PODERES"], ["story", "HISTÓRIA"], ["pvp", "PvP"]]:
		var key = Button.new()
		key.custom_minimum_size = RAIL_KEY
		key.focus_mode = Control.FOCUS_NONE
		key.text = entry[1]
		key.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		key.alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_override("font", UiKit.strong_font())
		key.add_theme_font_size_override("font_size", 12)
		for state in ["normal", "hover", "pressed"]:
			var style: StyleBoxFlat = UiKit.key_styles("secondary")[state].duplicate()
			style.content_margin_top = 54 if state != "pressed" else 58
			style.content_margin_left = 4
			style.content_margin_right = 4
			key.add_theme_stylebox_override(state, style)
		var kind: String = entry[0]
		key.draw.connect(draw_rail_icon.bind(key, kind))
		rail.add_child(key)
		rail_keys[kind] = key
	rail_keys.hangar.pressed.connect(func(): hud.open_skins())
	rail_keys.powers.pressed.connect(func(): hud.open_powers())
	rail_keys.story.pressed.connect(func(): hud.cup_requested.emit())
	rail_keys.pvp.pressed.connect(func(): hud.open_pvp())
	build_sheet()

func build_mode_card() -> Button:
	# Lives in the dock (the HUD's menu panel); drawn here because it reads lobby state.
	mode_card = Button.new()
	mode_card.focus_mode = Control.FOCUS_NONE
	mode_card.custom_minimum_size = Vector2(0, 84)
	mode_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_card.tooltip_text = "Escolher o modo de jogo"
	for state in ["normal", "hover", "pressed"]:
		mode_card.add_theme_stylebox_override(state, UiKit.flat(UiKit.CARD if state != "hover" else UiKit.CARD_HI, UiKit.CARD_EDGE, 18, 5, UiKit.LIP))
	mode_card.draw.connect(draw_mode_card)
	mode_card.pressed.connect(open_sheet)
	return mode_card

func build_sheet() -> void:
	sheet = ColorRect.new()
	sheet.color = Color(UiKit.NIGHT, 0.9)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close_sheet())
	add_child(sheet)
	sheet_panel = PanelContainer.new()
	sheet_panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	sheet.add_child(sheet_panel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	sheet_panel.add_child(list)
	list.add_child(hud.label("ESCOLHE O MODO", 28, UiKit.WHITE, true))
	list.add_child(hud.label("O modo fica no lobby: depois é só carregar em JOGAR.", 14, UiKit.MUTED))
	for entry in MODES:
		var card = Button.new()
		card.custom_minimum_size = Vector2(0, 82)
		card.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed"]:
			card.add_theme_stylebox_override(state, UiKit.flat(UiKit.CARD if state == "normal" else UiKit.CARD_HI, UiKit.CARD_EDGE, 18, 5, UiKit.LIP))
		var id: String = entry.id
		card.draw.connect(draw_sheet_card.bind(card, entry))
		card.pressed.connect(func(): choose_mode(id))
		list.add_child(card)
		sheet_cards[id] = card
	var levels = hud.make_button("TODOS OS NÍVEIS", false)
	levels.pressed.connect(func():
		close_sheet()
		hud.open_levels())
	var back = hud.make_button("VOLTAR", false)
	back.pressed.connect(close_sheet)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for button in [levels, back]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	list.add_child(row)
	sheet.hide()

func open_sheet() -> void:
	hud.reset_touch()
	arrange()
	sheet.show()
	for card in sheet_cards.values():
		card.queue_redraw()

func close_sheet() -> void:
	sheet.hide()

func choose_mode(id: String) -> void:
	mode_id = id
	close_sheet()
	hud.refresh_menu_level()

func mode_entry() -> Dictionary:
	for entry in MODES:
		if entry.id == mode_id:
			return entry
	return MODES[0]

func arrange() -> void:
	var top: float = hud.safe_top + 14.0
	profile.position = Vector2(16, top)
	profile.size = Vector2(minf(330.0, size.x * 0.46), 64)
	gear.position = Vector2(size.x - 80, top)
	gear.size = Vector2(64, 64)
	var rail_top = (hud.safe_top + 196.0) if hud.vertical else top + 92.0
	rail.position = Vector2(16, rail_top)
	rail.size = Vector2(RAIL_KEY.x, 0)
	var panel_width = minf(size.x - 48, 560)
	sheet_panel.size = Vector2(panel_width, 0)
	sheet_panel.size = sheet_panel.get_combined_minimum_size().max(Vector2(panel_width, 0))
	sheet_panel.position = hud.thumb_panel_position(sheet_panel.size)
	queue_redraw()

func refresh() -> void:
	# Counts and dots on the rail keys, the profile and the mode card.
	var skins = hud.skins_progress
	var shop = hud.power_shop
	var fresh = skins != null and not skins.unseen().is_empty()
	var buyable = shop != null and not shop.affordable().is_empty()
	rail_keys.hangar.text = "HANGAR"
	rail_keys.powers.text = "PODERES"
	rail_keys.hangar.set_meta("dot", fresh)
	rail_keys.powers.set_meta("dot", buyable)
	rail_keys.hangar.set_meta("count", "%d/%d" % [skins.unlocked_count() if skins != null else 0, Skins.CATALOG.size()])
	rail_keys.powers.set_meta("count", "%d/%d" % [shop.owned.size() if shop != null else 0, Powers.CATALOG.size()])
	for key in rail_keys.values():
		key.queue_redraw()
	profile.queue_redraw()
	if mode_card != null:
		mode_card.queue_redraw()
	queue_redraw()

# --- drawing ---------------------------------------------------------------------------------
func _draw() -> void:
	# The wallet: bricks earned in matches, which buy powers.
	var shop = hud.power_shop
	var bricks: int = shop.bricks if shop != null else 0
	var text = str(bricks)
	var f = UiKit.title_font()
	var width = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 62
	var chip = Rect2(gear.position.x - width - 12, gear.position.y + 8, width, 48)
	UiKit.plate(self, chip, Color(UiKit.PANEL, 0.9), UiKit.PANEL_EDGE, 4.0)
	brick_glyph(self, chip.position + Vector2(24, 24), 1.0)
	draw_string(f, chip.position + Vector2(44, 33), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.SUN)

func brick_glyph(c: CanvasItem, at: Vector2, k: float) -> void:
	UiKit.box(c, Rect2(at + Vector2(-11, -6) * k, Vector2(22, 14) * k), UiKit.SUN_LIP, Color.TRANSPARENT, true)
	UiKit.box(c, Rect2(at + Vector2(-11, -9) * k, Vector2(22, 13) * k), UiKit.SUN, Color.TRANSPARENT, true)
	UiKit.fill(c, Rect2(at + Vector2(-1, -9) * k, Vector2(2, 13) * k), UiKit.SUN_LIP)

func draw_profile() -> void:
	var skins = hud.skins_progress
	var skin: int = skins.selected if skins != null else 0
	var at = Vector2(36, 32)
	UiKit.disc(profile, at, 26, UiKit.FIELD)
	var picture: Texture2D = hud.robot_portrait(skin, false)
	if picture != null:
		profile.draw_texture_rect(picture, Rect2(at - Vector2(31, 35), Vector2(62, 62)), false)
	UiKit.ring(profile, at, 26, Color(UiKit.CYAN, 0.8))
	var name = String(Skins.CATALOG[clampi(skin, 0, Skins.CATALOG.size() - 1)].name)
	profile.draw_string(UiKit.title_font(), Vector2(72, 28), name, HORIZONTAL_ALIGNMENT_LEFT, profile.size.x - 86, 21, UiKit.WHITE)
	var state = hud.campaign_state
	var done: int = state.completed.size() if state != null else 0
	var total: int = Campaign.menu_levels().size()
	profile.draw_string(UiKit.strong_font(), Vector2(72, 46), "CAMPANHA %d/%d" % [mini(done, total), total], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.MUTED)
	var bar = Rect2(72, 51, profile.size.x - 90, 6)
	UiKit.box(profile, bar, UiKit.FIELD, Color.TRANSPARENT, true)
	UiKit.box(profile, Rect2(bar.position, Vector2(bar.size.x * clampf(float(done) / maxi(total, 1), 0, 1), bar.size.y)), UiKit.SUN, Color.TRANSPARENT, true)

func draw_gear() -> void:
	# A cog: eight teeth round a ring, drawn from the kit's shapes.
	var c = gear.size * 0.5 + Vector2(0, -2 if not gear.button_pressed else 1)
	for i in range(8):
		var angle = i * TAU / 8.0
		gear.draw_set_transform(c, angle, Vector2.ONE)
		UiKit.box(gear, Rect2(-4, -17, 8, 9), UiKit.WHITE, Color.TRANSPARENT, true)
	gear.draw_set_transform(Vector2.ZERO)
	UiKit.disc(gear, c, 12, UiKit.WHITE)
	UiKit.disc(gear, c, 5, UiKit.CARD)

func draw_rail_icon(key: Button, kind: String) -> void:
	var c = Vector2(key.size.x * 0.5, 30 + (3 if key.button_pressed else 0))
	var ink = UiKit.WHITE
	match kind:
		"hangar":
			# A TV head with two eyes.
			UiKit.box(key, Rect2(c + Vector2(-17, -13), Vector2(34, 26)), UiKit.CYAN, Color.TRANSPARENT, true)
			UiKit.box(key, Rect2(c + Vector2(-13, -9), Vector2(26, 18)), UiKit.INK, Color.TRANSPARENT, true)
			UiKit.disc(key, c + Vector2(-5, 0), 3, UiKit.CYAN)
			UiKit.disc(key, c + Vector2(5, 0), 3, UiKit.CYAN)
			UiKit.fill(key, Rect2(c + Vector2(-1, -19), Vector2(2, 6)), UiKit.CYAN)
			UiKit.disc(key, c + Vector2(0, -20), 3, UiKit.SUN)
		"powers":
			var bolt = PackedVector2Array([c + Vector2(4, -16), c + Vector2(-9, 2), c + Vector2(0, 2), c + Vector2(-4, 16), c + Vector2(10, -3), c + Vector2(1, -3), c + Vector2(6, -16)])
			key.draw_colored_polygon(bolt, UiKit.SUN)
		"story":
			# A cup on a plinth.
			UiKit.box(key, Rect2(c + Vector2(-12, -15), Vector2(24, 18)), UiKit.GOLD, Color.TRANSPARENT, true)
			UiKit.ring(key, c + Vector2(-13, -8), 6, UiKit.GOLD)
			UiKit.ring(key, c + Vector2(13, -8), 6, UiKit.GOLD)
			UiKit.fill(key, Rect2(c + Vector2(-2, 2), Vector2(4, 8)), UiKit.GOLD)
			UiKit.box(key, Rect2(c + Vector2(-10, 9), Vector2(20, 6)), UiKit.GOLD, Color.TRANSPARENT, true)
		"pvp":
			for side in [-1.0, 1.0]:
				key.draw_line(c + Vector2(-13 * side, -13), c + Vector2(13 * side, 13), UiKit.CORAL if side > 0 else UiKit.CYAN, 5.0, true)
			UiKit.disc(key, c, 4, ink)
	if key.has_meta("count"):
		var count: String = key.get_meta("count")
		var f = UiKit.strong_font()
		var width = f.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		key.draw_string(f, Vector2((key.size.x - width) * 0.5, key.size.y - 12), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.MUTED)
	if key.get_meta("dot", false):
		UiKit.disc(key, Vector2(key.size.x - 12, 12), 7, UiKit.DANGER)
		UiKit.ring(key, Vector2(key.size.x - 12, 12), 7, UiKit.WHITE)

func mode_glyph(c: CanvasItem, at: Vector2, id: String, color: Color) -> void:
	UiKit.disc(c, at, 24, UiKit.FIELD)
	UiKit.ring(c, at, 24, Color(color, 0.7))
	match id:
		"campaign":
			UiKit.fill(c, Rect2(at + Vector2(-7, -12), Vector2(3, 24)), color)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -12), at + Vector2(11, -7), at + Vector2(-4, -1)]), color)
		"quick":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(3, -13), at + Vector2(-8, 2), at + Vector2(0, 2), at + Vector2(-3, 13), at + Vector2(9, -3), at + Vector2(1, -3)]), color)
		"story":
			UiKit.box(c, Rect2(at + Vector2(-8, -11), Vector2(16, 12)), color, Color.TRANSPARENT, true)
			UiKit.fill(c, Rect2(at + Vector2(-1.5, 1), Vector2(3, 6)), color)
			UiKit.box(c, Rect2(at + Vector2(-7, 7), Vector2(14, 4)), color, Color.TRANSPARENT, true)
		"pvp":
			c.draw_line(at + Vector2(-9, -9), at + Vector2(9, 9), UiKit.CORAL, 4.0, true)
			c.draw_line(at + Vector2(9, -9), at + Vector2(-9, 9), UiKit.CYAN, 4.0, true)

func draw_mode_card() -> void:
	var entry = mode_entry()
	var sink = 3.0 if mode_card.button_pressed else 0.0
	mode_glyph(mode_card, Vector2(40, 38 + sink), entry.id, UiKit.SUN)
	var f = UiKit.strong_font()
	mode_card.draw_string(f, Vector2(76, 24 + sink), "MODO  ▾", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.MUTED)
	var name: String = entry.name
	var about: String = entry.about
	var room = mode_card.size.x - 84
	if entry.id == "story" and story_line != "":
		name = story_round if story_round != "" else "TAÇA AURORA"
		about = story_line
		if story_boss >= 0:
			var skins_s = hud.skins_progress
			var beaten_s: bool = skins_s != null and story_boss < Skins.CATALOG.size() and skins_s.is_unlocked(story_boss)
			var boss_at_s = Vector2(mode_card.size.x - 42, 38 + sink)
			UiKit.disc(mode_card, boss_at_s, 30, UiKit.FIELD)
			var picture_s: Texture2D = hud.robot_portrait(story_boss, false)
			if picture_s != null:
				mode_card.draw_texture_rect(picture_s, Rect2(boss_at_s - Vector2(36, 40), Vector2(72, 72)), false, Color.WHITE if beaten_s else Color(UiKit.CORAL.darkened(0.55), 1.0))
			UiKit.ring(mode_card, boss_at_s, 30, UiKit.CORAL)
			room -= 80
		if story_news:
			# A new edition is out: the paper has something to say about the last match.
			var tag = Rect2(mode_card.size.x - (190 if story_boss >= 0 else 110), 8, 96, 20)
			UiKit.box(mode_card, tag, UiKit.SUN, Color.TRANSPARENT, true)
			mode_card.draw_string(f, tag.position + Vector2(8, 15), "NOVA EDIÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.INK)
	elif entry.id == "campaign" and hud.campaign_state != null:
		var level: Dictionary = Campaign.LEVELS[hud.menu_level]
		var rival = String(level.name).to_upper() if int(level.boss) >= 100 else String(Skins.CATALOG[int(level.boss)].name)
		about = ("Posto · " if int(level.boss) >= 100 else "Boss · ") + rival
		# The boss of the level waits at the right of the card.
		var station: bool = int(level.boss) >= 100
		var skins = hud.skins_progress
		var beaten: bool = skins != null and int(level.boss) < Skins.CATALOG.size() and skins.is_unlocked(level.boss)
		var boss_at = Vector2(mode_card.size.x - 42, 38 + sink)
		UiKit.disc(mode_card, boss_at, 30, UiKit.FIELD)
		var picture: Texture2D = hud.robot_portrait(int(level.boss), false)
		if picture != null:
			var tone = Color(UiKit.CORAL.darkened(0.55), 1.0) if station or not beaten else Color.WHITE
			mode_card.draw_texture_rect(picture, Rect2(boss_at - Vector2(36, 40), Vector2(72, 72)), false, tone)
		UiKit.ring(mode_card, boss_at, 30, UiKit.CORAL if not beaten else UiKit.SUN)
		mode_card.draw_string(f, boss_at + Vector2(-16, 40), "POSTO" if station else "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiKit.CORAL)
		room -= 80
	mode_card.draw_string(UiKit.title_font(), Vector2(76, 50 + sink), name, HORIZONTAL_ALIGNMENT_LEFT, room, 22, UiKit.WHITE)
	mode_card.draw_string(UiKit.body_font(), Vector2(76, 70 + sink), about, HORIZONTAL_ALIGNMENT_LEFT, room, 13, UiKit.MUTED)

func draw_sheet_card(card: Button, entry: Dictionary) -> void:
	var chosen: bool = entry.id == mode_id
	if chosen:
		UiKit.box(card, Rect2(0, 8, 6, card.size.y - 21), UiKit.SUN, Color.TRANSPARENT, true)
	mode_glyph(card, Vector2(44, 38), entry.id, UiKit.SUN if chosen else UiKit.WHITE)
	card.draw_string(UiKit.title_font(), Vector2(84, 38), entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.WHITE)
	card.draw_string(UiKit.body_font(), Vector2(84, 60), entry.about, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 170, 13, UiKit.MUTED)
	if chosen:
		card.draw_string(UiKit.strong_font(), Vector2(card.size.x - 92, 24), "ESCOLHIDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.SUN)
