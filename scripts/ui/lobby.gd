extends Control
## Persistent chrome around the Command Hub. This keeps the player identity, live wallet and
## four touch destinations visible while the arena itself remains the character showroom.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Skins = preload("res://scripts/progression/skins.gd")
const Campaign = preload("res://scripts/progression/campaign.gd")
const Powers = preload("res://scripts/gameplay/powers.gd")

const MODES = [
	{"id": "quick", "name": "JOGO RÁPIDO", "about": "Uma partida contra a IA, já"},
	{"id": "bosses", "name": "MODO HISTÓRIA", "about": "A aventura do BIT na Taça"},
	{"id": "marathon", "name": "MARATONA", "about": "Rivais seguidos até perderes"},
	{"id": "campaign", "name": "ARENAS", "about": "As arenas que já venceste, em jogo livre"},
	{"id": "pvp", "name": "PvP", "about": "Dois jogadores na mesma rede, ou o Coliseu"},
]
const RAIL_KEY := Vector2(96, 84)
const NAV_HEIGHT := 88.0
const NAV_ITEMS = [
	["hangar", "HANGAR"],
	["powers", "PODERES"],
	["home", "INÍCIO"],
	["settings", "AJUSTES"],
]

var hud
var mode_id := "bosses"
var profile: Button
var wallet: Button
var gear: Button
var rail: VBoxContainer
var navbar: HBoxContainer
var rail_keys: Dictionary = {}
var mode_card: Button
var sheet: ColorRect
var sheet_cards: Dictionary = {}
var active_destination := "home"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_header()
	_build_navigation()
	# Kept as a harmless compatibility layer for older callers. The Command Hub does not use a
	# mode sheet: every tile opens its actual destination directly.
	sheet = ColorRect.new()
	sheet.color = Color.TRANSPARENT
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	sheet.hide()
	arrange()

func set_hub(hub) -> void:
	if hub == null:
		return
	mode_card = hub.story_button
	sheet_cards = hub.mode_buttons.duplicate()
	# Backward compatibility: "campaign" is the old name for arenas in tests and external code.
	if sheet_cards.has("arenas") and not sheet_cards.has("campaign"):
		sheet_cards["campaign"] = sheet_cards["arenas"]

func _build_header() -> void:
	profile = Button.new()
	profile.name = "PilotProfile"
	profile.focus_mode = Control.FOCUS_ALL
	profile.tooltip_text = tr("Abrir hangar e escolher piloto")
	profile.add_theme_stylebox_override("normal", UiKit.flat(Color(UiKit.PANEL, 0.95), Color(UiKit.CARD_EDGE, 0.75), 13))
	profile.add_theme_stylebox_override("hover", UiKit.flat(Color(UiKit.CARD, 0.98), UiKit.CYAN, 13))
	profile.add_theme_stylebox_override("pressed", UiKit.flat(UiKit.FIELD, UiKit.SUN, 13))
	profile.add_theme_stylebox_override("focus", UiKit.key_styles("secondary").focus)
	profile.draw.connect(draw_profile)
	profile.pressed.connect(func(): _open_destination("hangar"))
	UiKit.add_bounce(profile)
	add_child(profile)

	wallet = Button.new()
	wallet.name = "Currency"
	wallet.focus_mode = Control.FOCUS_ALL
	wallet.tooltip_text = tr("Abrir poderes")
	wallet.add_theme_stylebox_override("normal", UiKit.flat(Color(UiKit.PANEL, 0.95), Color(UiKit.SUN, 0.7), 13))
	wallet.add_theme_stylebox_override("hover", UiKit.flat(Color(UiKit.CARD, 0.98), UiKit.SUN, 13))
	wallet.add_theme_stylebox_override("pressed", UiKit.flat(UiKit.FIELD, UiKit.SUN, 13))
	wallet.add_theme_stylebox_override("focus", UiKit.key_styles("secondary").focus)
	wallet.draw.connect(draw_wallet)
	wallet.pressed.connect(func(): _open_destination("powers"))
	UiKit.add_bounce(wallet)
	add_child(wallet)

	gear = Button.new()
	gear.name = "Settings"
	gear.focus_mode = Control.FOCUS_ALL
	gear.tooltip_text = tr("Abrir ajustes")
	gear.add_theme_stylebox_override("normal", UiKit.flat(Color(UiKit.PANEL, 0.95), Color(UiKit.CARD_EDGE, 0.75), 13))
	gear.add_theme_stylebox_override("hover", UiKit.flat(Color(UiKit.CARD, 0.98), UiKit.CYAN, 13))
	gear.add_theme_stylebox_override("pressed", UiKit.flat(UiKit.FIELD, UiKit.SUN, 13))
	gear.add_theme_stylebox_override("focus", UiKit.key_styles("secondary").focus)
	gear.draw.connect(draw_gear)
	gear.pressed.connect(func(): _open_destination("settings"))
	UiKit.add_bounce(gear)
	add_child(gear)

func _build_navigation() -> void:
	rail = VBoxContainer.new()
	rail.add_theme_constant_override("separation", 10)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rail)
	navbar = HBoxContainer.new()
	navbar.add_theme_constant_override("separation", 8)
	navbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(navbar)
	for item in NAV_ITEMS:
		var kind: String = item[0]
		var key := Button.new()
		key.name = "%sNavigation" % kind.capitalize()
		key.focus_mode = Control.FOCUS_ALL
		key.tooltip_text = tr(String(item[1]))
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.draw.connect(draw_nav_key.bind(key, kind, String(item[1])))
		key.pressed.connect(func(): _open_destination(kind))
		UiKit.add_bounce(key)
		rail.add_child(key)
		rail_keys[kind] = key
	set_active_destination("home")

func _open_destination(destination: String) -> void:
	set_active_destination(destination)
	if hud == null:
		return
	match destination:
		"hangar": hud.open_skins()
		"powers": hud.open_powers()
		"settings": hud.open_video()
		"home":
			if hud.command_hub != null:
				hud.command_hub.refresh()

func set_active_destination(destination: String) -> void:
	active_destination = destination
	for kind in rail_keys:
		var key: Button = rail_keys[kind]
		var chosen: bool = kind == destination
		var face = Color("143d5f") if chosen else Color(UiKit.PANEL, 0.96)
		var edge = UiKit.CYAN if chosen else Color(UiKit.CARD_EDGE, 0.42)
		key.add_theme_stylebox_override("normal", UiKit.flat(face, edge, 11, 2 if chosen else 0, UiKit.LIP))
		key.add_theme_stylebox_override("hover", UiKit.flat(face.lightened(0.09), UiKit.CYAN, 11, 2 if chosen else 0, UiKit.LIP))
		key.add_theme_stylebox_override("pressed", UiKit.flat(UiKit.FIELD, UiKit.SUN if chosen else UiKit.CYAN, 11))
		key.add_theme_stylebox_override("focus", UiKit.key_styles("secondary").focus)
		key.queue_redraw()

func choose_mode(id: String) -> void:
	mode_id = id
	set_active_destination("home")
	if hud != null:
		hud.refresh_menu_level()

func mode_entry() -> Dictionary:
	for entry in MODES:
		if entry.id == mode_id:
			return entry
	return MODES[0]

func open_sheet() -> void:
	# The previous menu opened a full mode sheet. The stable hub exposes every mode directly.
	if sheet != null:
		sheet.hide()

func close_sheet() -> void:
	if sheet != null:
		sheet.hide()

func arrange() -> void:
	if hud == null or profile == null:
		return
	var top: float = float(hud.safe_top) + 12.0
	var gear_w := 62.0
	var wallet_w := clampf(size.x * 0.25, 92.0, 142.0)
	var profile_w := clampf(size.x - 48.0 - gear_w - wallet_w - 16.0, 136.0, 276.0)
	profile.position = Vector2(16, top)
	profile.size = Vector2(profile_w, 70)
	wallet.position = Vector2(profile.position.x + profile.size.x + 8, top)
	wallet.size = Vector2(wallet_w, 70)
	gear.position = Vector2(size.x - gear_w - 16, top)
	gear.size = Vector2(gear_w, 70)

	var bar: Container = navbar if hud.vertical else rail
	for item in NAV_ITEMS:
		var key: Button = rail_keys[item[0]]
		if key.get_parent() != bar:
			key.get_parent().remove_child(key)
			bar.add_child(key)
		key.custom_minimum_size = Vector2(0, NAV_HEIGHT) if hud.vertical else RAIL_KEY
	navbar.visible = hud.vertical
	rail.visible = not hud.vertical
	navbar.position = Vector2(16, size.y - hud.safe_bottom - NAV_HEIGHT - 12)
	navbar.size = Vector2(size.x - 32, NAV_HEIGHT)
	rail.position = Vector2(16, top + 84)
	rail.size = Vector2(RAIL_KEY.x, 0)
	queue_redraw()

func refresh() -> void:
	if hud == null or profile == null:
		return
	var skins = hud.skins_progress
	var shop = hud.power_shop
	rail_keys.hangar.set_meta("dot", skins != null and not skins.unseen().is_empty())
	rail_keys.powers.set_meta("dot", shop != null and not shop.affordable().is_empty())
	rail_keys.hangar.set_meta("count", "%d/%d" % [skins.unlocked_count() if skins != null else 0, Skins.CATALOG.size()])
	rail_keys.powers.set_meta("count", "%d/%d" % [shop.owned.size() if shop != null else 0, Powers.CATALOG.size()])
	profile.queue_redraw()
	wallet.queue_redraw()
	gear.queue_redraw()
	for key in rail_keys.values():
		key.queue_redraw()

func draw_profile() -> void:
	var skins = hud.skins_progress
	var skin: int = int(skins.selected) if skins != null else 0
	var at := Vector2(37, profile.size.y * 0.5)
	UiKit.disc(profile, at, 26, UiKit.FIELD)
	UiKit.ring(profile, at, 26, UiKit.CYAN)
	var picture: Texture2D = hud.robot_portrait(skin, false)
	if picture != null:
		profile.draw_texture_rect(picture, Rect2(at - Vector2(29, 32), Vector2(58, 58)), false)
	var name := String(Skins.CATALOG[clampi(skin, 0, Skins.CATALOG.size() - 1)].name).to_upper()
	profile.draw_string(UiKit.strong_font(), Vector2(73, 29), tr(name), HORIZONTAL_ALIGNMENT_LEFT, profile.size.x - 82, 17, UiKit.WHITE)
	var done := 0
	var total := Campaign.menu_levels().size()
	if hud.campaign_state != null:
		for index in Campaign.menu_levels():
			if hud.campaign_state.is_completed(index):
				done += 1
	profile.draw_string(UiKit.strong_font(), Vector2(73, 48), tr("TAÇA  %d/%d") % [done, total], HORIZONTAL_ALIGNMENT_LEFT, profile.size.x - 82, 11, UiKit.MUTED)
	var bar := Rect2(73, 55, maxf(22, profile.size.x - 88), 5)
	UiKit.box(profile, bar, UiKit.FIELD, Color.TRANSPARENT, true)
	UiKit.box(profile, Rect2(bar.position, Vector2(bar.size.x * clampf(float(done) / maxf(total, 1.0), 0.0, 1.0), bar.size.y)), UiKit.SUN, Color.TRANSPARENT, true)

func draw_wallet() -> void:
	var bricks: int = int(hud.power_shop.bricks) if hud != null and hud.power_shop != null else 0
	var c := Vector2(22, wallet.size.y * 0.5)
	UiKit.box(wallet, Rect2(c - Vector2(10, 7), Vector2(20, 14)), UiKit.SUN, UiKit.WHITE, true)
	UiKit.fill(wallet, Rect2(c + Vector2(-1, -7), Vector2(2, 14)), UiKit.SUN_LIP)
	wallet.draw_string(UiKit.strong_font(), Vector2(39, 31), tr("TIJOLOS"), HORIZONTAL_ALIGNMENT_LEFT, wallet.size.x - 46, 10, UiKit.MUTED)
	wallet.draw_string(UiKit.strong_font(), Vector2(39, 51), str(bricks), HORIZONTAL_ALIGNMENT_LEFT, wallet.size.x - 46, 18, UiKit.SUN)

func draw_gear() -> void:
	var c := gear.size * 0.5
	for i in range(8):
		var angle := i * TAU / 8.0
		gear.draw_set_transform(c, angle, Vector2.ONE)
		UiKit.box(gear, Rect2(-3, -18, 6, 10), UiKit.WHITE, Color.TRANSPARENT, true)
	gear.draw_set_transform(Vector2.ZERO)
	UiKit.ring(gear, c, 14, UiKit.WHITE)
	UiKit.disc(gear, c, 5, UiKit.CARD)

func draw_nav_key(key: Button, kind: String, caption: String) -> void:
	var center := Vector2(key.size.x * 0.5, 30 + (2 if key.button_pressed else 0))
	var accent := UiKit.CYAN if kind == active_destination else UiKit.MUTED
	_draw_nav_icon(key, center, kind, accent)
	key.draw_string(UiKit.strong_font(), Vector2(0, key.size.y - 13), tr(caption), HORIZONTAL_ALIGNMENT_CENTER, key.size.x, 10, UiKit.WHITE if kind == active_destination else UiKit.MUTED)
	if key.has_meta("count"):
		var count: String = key.get_meta("count")
		key.draw_string(UiKit.body_font(), Vector2(0, key.size.y - 27), tr(count), HORIZONTAL_ALIGNMENT_CENTER, key.size.x, 9, Color(UiKit.MUTED, 0.82))
	if key.get_meta("dot", false):
		UiKit.disc(key, Vector2(key.size.x * 0.5 + 22, 17), 6, UiKit.DANGER)
		UiKit.ring(key, Vector2(key.size.x * 0.5 + 22, 17), 6, UiKit.WHITE)

func _draw_nav_icon(canvas: CanvasItem, at: Vector2, kind: String, color: Color) -> void:
	match kind:
		"hangar":
			UiKit.box(canvas, Rect2(at + Vector2(-13, -10), Vector2(26, 20)), color, Color(UiKit.WHITE, 0.6), true)
			UiKit.disc(canvas, at + Vector2(-5, 0), 3, UiKit.NIGHT)
			UiKit.disc(canvas, at + Vector2(5, 0), 3, UiKit.NIGHT)
		"powers":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(3, -16), at + Vector2(-9, 1), at + Vector2(-1, 1), at + Vector2(-5, 16), at + Vector2(11, -3), at + Vector2(2, -3)]), color)
		"home":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-15, -1), at, at + Vector2(15, -1), at + Vector2(11, 14), at + Vector2(-11, 14)]), color)
			UiKit.box(canvas, Rect2(at + Vector2(-3, 5), Vector2(6, 9)), UiKit.NIGHT, Color.TRANSPARENT, true)
		"settings":
			UiKit.ring(canvas, at, 13, color)
			UiKit.disc(canvas, at, 5, color)
