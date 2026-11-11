extends VBoxContainer
## The fixed mobile command hub. It presents the persistent arena/showroom behind a compact
## set of real game actions: Story, Quick Match, Marathon, PvP and Arenas.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Campaign = preload("res://scripts/progression/campaign.gd")
const Skins = preload("res://scripts/progression/skins.gd")

signal story_requested
signal quick_requested
signal marathon_requested
signal pvp_requested
signal arenas_requested
signal difficulty_requested(level: int)

var hud
var story_button: Button
var status_panel: PanelContainer
var status_label: Label
var mode_buttons: Dictionary = {}
var mode_faces: Dictionary = {}
var difficulty_buttons: Array = []
var story_face: Control

func _init() -> void:
	name = "CommandHub"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_build()

func _build() -> void:
	story_button = Button.new()
	story_button.name = "StoryOperation"
	story_button.custom_minimum_size = Vector2(0, 138)
	story_button.focus_mode = Control.FOCUS_ALL
	story_button.tooltip_text = tr("Continuar o Modo História")
	story_button.text = "JOGAR"
	_story_styles(story_button)
	add_child(story_button)
	story_face = Control.new()
	story_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_face.draw.connect(_draw_story_operation)
	story_button.add_child(story_face)

	var difficulty_row := HBoxContainer.new()
	difficulty_row.name = "DifficultyRow"
	difficulty_row.add_theme_constant_override("separation", 8)
	add_child(difficulty_row)
	var difficulty_label := _label("NÍVEL DA IA", 12, UiKit.MUTED, true)
	difficulty_label.custom_minimum_size = Vector2(98, 44)
	difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	difficulty_row.add_child(difficulty_label)
	var group := ButtonGroup.new()
	for index in range(3):
		var names = ["FÁCIL", "NORMAL", "DIFÍCIL"]
		var pick := Button.new()
		pick.text = tr(String(names[index]))
		pick.custom_minimum_size = Vector2(0, 48)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.toggle_mode = true
		pick.button_group = group
		pick.focus_mode = Control.FOCUS_ALL
		pick.add_theme_font_override("font", UiKit.strong_font())
		pick.add_theme_font_size_override("font_size", 13)
		UiKit.paint_key(pick, "toggle")
		pick.pressed.connect(func(): difficulty_requested.emit(index))
		difficulty_row.add_child(pick)
		difficulty_buttons.append(pick)

	var modes_caption := _label("MODOS DE COMBATE", 13, UiKit.MUTED, true)
	modes_caption.custom_minimum_size.y = 18
	add_child(modes_caption)
	var grid := GridContainer.new()
	grid.name = "ModeGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)
	_add_mode(grid, "quick", "JOGO RÁPIDO", "Escolhe a arena e entra já.", UiKit.CYAN, quick_requested)
	_add_mode(grid, "marathon", "MARATONA", "Uma sequência até perderes.", UiKit.DANGER, marathon_requested)
	_add_mode(grid, "pvp", "PvP", "Duelo local e sala online.", Color("a88cff"), pvp_requested)
	_add_mode(grid, "arenas", "ARENAS", "Revê desafios já abertos.", UiKit.SUN, arenas_requested)

	status_panel = PanelContainer.new()
	status_panel.name = "CommandNotice"
	status_panel.add_theme_stylebox_override("panel", UiKit.flat(Color(UiKit.FIELD, 0.92), Color(UiKit.CARD_EDGE, 0.45), 10))
	add_child(status_panel)
	status_label = _label("", 13, UiKit.SUN_INK, false)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.y = 24
	status_panel.add_child(status_label)
	status_panel.hide()

func _label(text_value: String, font_size: int, color: Color, strong: bool = false) -> Label:
	var item := Label.new()
	item.text = tr(text_value)
	item.add_theme_font_override("font", UiKit.strong_font() if strong else UiKit.body_font())
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	return item

func _story_styles(button: Button) -> void:
	button.add_theme_stylebox_override("normal", UiKit.flat(Color("0c2b49"), UiKit.CYAN, 14, 4, Color("041425")))
	button.add_theme_stylebox_override("hover", UiKit.flat(Color("123b60"), UiKit.WHITE, 14, 4, Color("041425")))
	button.add_theme_stylebox_override("pressed", UiKit.flat(Color("09213a"), UiKit.SUN, 14, 1, Color("041425")))
	button.add_theme_stylebox_override("focus", UiKit.key_styles("secondary").focus)
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	UiKit.add_bounce(button)

func _add_mode(grid: GridContainer, id: String, title: String, description: String, accent: Color, action: Signal) -> void:
	var card := Button.new()
	card.name = "%sMode" % id.capitalize()
	card.custom_minimum_size = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.tooltip_text = tr(description)
	card.add_theme_stylebox_override("normal", UiKit.flat(Color(UiKit.CARD, 0.96), Color(accent, 0.58), 12, 3, UiKit.LIP))
	card.add_theme_stylebox_override("hover", UiKit.flat(Color(UiKit.CARD_HI, 0.98), accent, 12, 3, UiKit.LIP))
	card.add_theme_stylebox_override("pressed", UiKit.flat(Color(UiKit.FIELD, 1.0), accent, 12, 1, UiKit.LIP))
	card.add_theme_stylebox_override("focus", UiKit.key_styles("secondary").focus)
	UiKit.add_bounce(card)
	var face := Control.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func(): _draw_mode_card(face, id, title, description, accent))
	card.add_child(face)
	card.pressed.connect(func(): action.emit())
	grid.add_child(card)
	mode_buttons[id] = card
	mode_faces[id] = face

func set_news(text_value: String) -> void:
	if status_label == null:
		return
	status_label.text = tr(text_value)
	status_panel.visible = not text_value.strip_edges().is_empty()

func set_difficulty(level: int) -> void:
	for index in range(difficulty_buttons.size()):
		difficulty_buttons[index].set_pressed_no_signal(index == clampi(level, 0, difficulty_buttons.size() - 1))

func refresh() -> void:
	if is_instance_valid(story_face):
		story_face.queue_redraw()
	for face in mode_faces.values():
		if is_instance_valid(face):
			face.queue_redraw()

func _campaign_count() -> Array:
	var total := Campaign.menu_levels().size()
	var complete := 0
	if hud != null and hud.campaign_state != null:
		for index in Campaign.menu_levels():
			if hud.campaign_state.is_completed(index):
				complete += 1
	return [complete, total]

func _featured_boss() -> int:
	if hud == null or hud.campaign_state == null:
		return 0
	var level = hud.campaign_state.suggested_level()
	return int(Campaign.LEVELS[clampi(level, 0, Campaign.LEVELS.size() - 1)].boss)

func _draw_story_operation() -> void:
	if story_face == null:
		return
	var c := story_face
	var rect := Rect2(Vector2.ZERO, c.size)
	var shift := 3.0 if story_button.button_pressed else 0.0
	# A restrained holographic field: bands make it read as an operation card without adding
	# a heavy image layer over the arena showcase.
	c.draw_rect(Rect2(8, 8 + shift, rect.size.x * 0.58, rect.size.y - 20), Color(UiKit.CYAN, 0.055), true)
	for line in range(4):
		var y := 24.0 + line * 25.0 + shift
		c.draw_line(Vector2(20, y), Vector2(rect.size.x * 0.58, y), Color(UiKit.CYAN, 0.10), 1.0, true)
	var badge := Rect2(18, 16 + shift, 128, 22)
	UiKit.box(c, badge, Color(UiKit.CYAN, 0.16), Color(UiKit.CYAN, 0.55), true)
	c.draw_string(UiKit.strong_font(), badge.position + Vector2(9, 15), tr("OPERAÇÃO ATIVA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.CYAN)
	c.draw_string(UiKit.title_font(), Vector2(18, 70 + shift), tr("MODO HISTÓRIA"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.58, 27, UiKit.WHITE)
	c.draw_string(UiKit.body_font(), Vector2(18, 93 + shift), tr("TAÇA CHARGE ARENA  ·  CONTINUAR"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.58, 13, UiKit.SUN_INK)
	var count := _campaign_count()
	var progress := "%d / %d CONFRONTOS" % [count[0], count[1]]
	c.draw_string(UiKit.strong_font(), Vector2(18, rect.size.y - 22 + shift), tr(progress), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.58, 12, UiKit.MUTED)
	var boss_at := Vector2(rect.size.x - minf(72.0, rect.size.y * 0.50), rect.size.y * 0.5 + shift)
	UiKit.disc(c, boss_at, minf(56.0, rect.size.y * 0.40), Color(UiKit.NIGHT, 0.68))
	UiKit.ring(c, boss_at, minf(56.0, rect.size.y * 0.40), Color(UiKit.SUN, 0.9))
	if hud != null:
		var portrait: Texture2D = hud.robot_portrait(_featured_boss(), false)
		if portrait != null:
			var s := minf(118.0, rect.size.y * 0.92)
			c.draw_texture_rect(portrait, Rect2(boss_at - Vector2(s * 0.5, s * 0.55), Vector2(s, s)), false)
	c.draw_string(UiKit.strong_font(), Vector2(rect.size.x - 120, rect.size.y - 16 + shift), tr("ENTRAR  ›"), HORIZONTAL_ALIGNMENT_LEFT, 104, 11, UiKit.SUN)

func _draw_mode_card(c: Control, id: String, title: String, description: String, accent: Color) -> void:
	var shift := 2.0 if (mode_buttons[id] as Button).button_pressed else 0.0
	var center := Vector2(35, c.size.y * 0.5 + shift)
	UiKit.disc(c, center, 22, Color(accent, 0.16))
	UiKit.ring(c, center, 22, Color(accent, 0.84))
	_draw_mode_icon(c, center, id, accent)
	c.draw_string(UiKit.strong_font(), Vector2(68, 35 + shift), tr(title), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 80, 16, UiKit.WHITE)
	c.draw_string(UiKit.body_font(), Vector2(68, 59 + shift), tr(description), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 78, 12, UiKit.MUTED)
	c.draw_string(UiKit.strong_font(), Vector2(68, c.size.y - 14 + shift), tr("ABRIR  ›"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, accent)

func _draw_mode_icon(c: CanvasItem, at: Vector2, id: String, color: Color) -> void:
	match id:
		"quick":
			c.draw_line(at + Vector2(-11, 8), at + Vector2(11, -8), color, 3.0, true)
			c.draw_line(at + Vector2(-8, 11), at + Vector2(8, -11), Color(UiKit.WHITE, 0.85), 1.2, true)
			UiKit.disc(c, at + Vector2(11, -8), 4, color)
		"marathon":
			c.draw_arc(at, 12, -2.3, 1.8, 20, color, 3.0, true)
			c.draw_line(at + Vector2(-10, 8), at + Vector2(8, 8), color, 3.0, true)
			UiKit.disc(c, at + Vector2(11, 5), 3, color)
		"pvp":
			UiKit.disc(c, at + Vector2(-7, -4), 5, UiKit.CYAN)
			UiKit.disc(c, at + Vector2(7, -4), 5, UiKit.CORAL)
			c.draw_line(at + Vector2(-12, 11), at + Vector2(-2, 4), UiKit.CYAN, 3.0, true)
			c.draw_line(at + Vector2(12, 11), at + Vector2(2, 4), UiKit.CORAL, 3.0, true)
		"arenas":
			c.draw_arc(at, 13, 0, TAU, 24, color, 2.5, true)
			c.draw_line(at + Vector2(-13, 0), at + Vector2(13, 0), color, 2.0, true)
			c.draw_line(at + Vector2(0, -13), at + Vector2(0, 13), color, 2.0, true)
			UiKit.disc(c, at, 3, UiKit.WHITE)
