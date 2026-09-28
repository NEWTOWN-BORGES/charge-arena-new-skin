extends Control
## The conversation cards of the Modo história, in the style of an anime visual novel: the
## speaker's inked portrait rises from the bottom over speed lines in its colour, a speech
## bubble with its name tag carries the line, typed out; the narrator speaks in a caption
## with no portrait. A tap finishes the line or moves on; SALTAR ends the scene.
const UiKit = preload("res://scripts/ui_kit.gd")
const Skins = preload("res://scripts/skins.gd")
const Story = preload("res://scripts/story_script.gd")
const FACES = "res://art/story/faces/%s.png"
const TYPE_SPEED = 42.0

signal finished(skipped: bool)

var lines: Array = []
var index = 0
var typed = 0.0
var clock = 0.0
var slide = 1.0
var portrait: TextureRect
var bubble: PanelContainer
var tag: PanelContainer
var tag_label: Label
var text: Label
var caption: PanelContainer
var caption_text: Label
var hint: Label
var skip_button: Button
var safe_top = 0.0
var safe_bottom = 0.0
var faces: Dictionary = {}
var accent = UiKit.SUN

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	bubble = PanelContainer.new()
	var bubble_style = UiKit.panel_style(Color("fbfbfd"), Color("15131d"), 26)
	bubble_style.set_border_width_all(5)
	bubble_style.content_margin_left = 26
	bubble_style.content_margin_right = 26
	bubble_style.content_margin_top = 30
	bubble_style.content_margin_bottom = 34
	bubble.add_theme_stylebox_override("panel", bubble_style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_override("font", UiKit.body_font())
	text.add_theme_font_size_override("font_size", 23)
	text.add_theme_color_override("font_color", Color("1c1a26"))
	bubble.add_child(text)
	tag = PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag)
	tag_label = Label.new()
	tag_label.add_theme_font_override("font", UiKit.title_font())
	tag_label.add_theme_font_size_override("font_size", 22)
	tag.add_child(tag_label)
	caption = PanelContainer.new()
	var caption_style = UiKit.panel_style(Color(0.06, 0.06, 0.1, 0.92), UiKit.SUN, 10)
	caption_style.set_border_width_all(2)
	caption_style.content_margin_left = 26
	caption_style.content_margin_right = 26
	caption_style.content_margin_top = 22
	caption_style.content_margin_bottom = 22
	caption.add_theme_stylebox_override("panel", caption_style)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	caption_text = Label.new()
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_text.add_theme_font_override("font", UiKit.strong_font())
	caption_text.add_theme_font_size_override("font_size", 22)
	caption_text.add_theme_color_override("font_color", Color("f3eedd"))
	caption.add_child(caption_text)
	hint = Label.new()
	hint.text = "toca para continuar  ▼"
	hint.add_theme_font_override("font", UiKit.strong_font())
	hint.add_theme_font_size_override("font_size", 15)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	skip_button = Button.new()
	skip_button.text = "SALTAR  ▶▶"
	skip_button.custom_minimum_size = Vector2(150, 52)
	skip_button.add_theme_font_override("font", UiKit.title_font())
	skip_button.add_theme_font_size_override("font_size", 18)
	UiKit.paint_key(skip_button, "secondary")
	skip_button.pressed.connect(func(): close(true))
	add_child(skip_button)
	resized.connect(arrange)
	hide()

func start(new_lines: Array) -> void:
	# Each line: [speaker, text]; the speaker is a skin index or a Story constant.
	lines = new_lines
	index = 0
	if lines.is_empty():
		finished.emit(false)
		return
	show()
	move_to_front()
	show_line()

func speaker() -> int:
	return int(lines[index][0])

func face(who: int) -> Texture2D:
	var key = "agente" if who == Story.AGENTE else str(who)
	if not faces.has(key):
		var path = FACES % key
		faces[key] = load(path) if ResourceLoader.exists(path) else null
	return faces[key]

func accent_of(who: int) -> Color:
	if who == Story.AGENTE:
		return Color("3b6fe0")
	if who < 0:
		return UiKit.SUN
	var entry: Dictionary = Skins.CATALOG[who]
	return Color(String(entry.get("light", "ffd23f")))

func show_line() -> void:
	var who = speaker()
	var narrator = who == Story.NARRADOR
	var changed = index == 0 or int(lines[index - 1][0]) != who
	accent = accent_of(who)
	typed = 0.0
	caption.visible = narrator
	bubble.visible = not narrator
	tag.visible = not narrator
	portrait.visible = not narrator
	var line = String(lines[index][1])
	if narrator:
		caption_text.text = line
		caption_text.visible_characters = 0
	else:
		text.text = line
		text.visible_characters = 0
		tag_label.text = Story.speaker_name(who)
		var ink = Color("15131d")
		tag_label.add_theme_color_override("font_color", ink if accent.get_luminance() > 0.45 else Color.WHITE)
		var tag_style = UiKit.panel_style(accent, ink, 14)
		tag_style.set_border_width_all(4)
		tag_style.content_margin_left = 18
		tag_style.content_margin_right = 18
		tag_style.content_margin_top = 6
		tag_style.content_margin_bottom = 6
		tag.add_theme_stylebox_override("panel", tag_style)
		portrait.texture = face(who)
		if changed:
			slide = 0.0
	hint.visible = false
	arrange()
	call_deferred("arrange")
	queue_redraw()

func on_left(who: int) -> bool:
	# BIT is always on the left; whoever talks to him faces him from the right.
	return who == Story.BIT or who == Story.BIT_ELITE

func arrange() -> void:
	if lines.is_empty():
		return
	var who = speaker()
	var width = minf(size.x - 32.0, 640.0)
	var left = (size.x - width) * 0.5
	skip_button.position = Vector2(size.x - skip_button.size.x - 16.0, safe_top + 16.0)
	if who == Story.NARRADOR:
		caption_text.custom_minimum_size = Vector2(width - 52.0, 0)
		caption.custom_minimum_size = Vector2(width, 0)
		caption.size = Vector2(width, 0)
		caption.size = Vector2(width, caption.get_combined_minimum_size().y)
		caption.position = Vector2(left, size.y * 0.5 - caption.size.y * 0.5)
		hint.position = Vector2(size.x * 0.5 - hint.size.x * 0.5, caption.position.y + caption.size.y + 14.0)
		return
	text.custom_minimum_size = Vector2(width - 62.0, 0)
	bubble.custom_minimum_size = Vector2(width, 150)
	bubble.size = Vector2(width, 0)
	bubble.size = Vector2(width, bubble.get_combined_minimum_size().y)
	bubble.position = Vector2(left, size.y - safe_bottom - 24.0 - bubble.size.y)
	var side_left = on_left(who)
	tag.size = tag.get_combined_minimum_size()
	tag.position = Vector2(left + 22.0 if side_left else left + width - 22.0 - tag.size.x, bubble.position.y - tag.size.y * 0.55)
	# The portrait stands on the bubble, big, on the speaker's side.
	var tall = minf(bubble.position.y - safe_top - 40.0, size.y * 0.62)
	var wide = tall * 0.8
	var ease = 1.0 - pow(1.0 - slide, 3.0)
	var offset = (1.0 - ease) * 80.0 * (-1.0 if side_left else 1.0)
	portrait.size = Vector2(wide, tall)
	portrait.flip_h = not side_left
	portrait.position = Vector2((left - 20.0 if side_left else left + width - wide + 20.0) + offset, bubble.position.y - tall + 26.0)
	portrait.modulate.a = ease
	hint.add_theme_color_override("font_color", Color("6a6878"))
	hint.position = Vector2(bubble.position.x + width - hint.size.x - 26.0, bubble.position.y + bubble.size.y - hint.size.y - 10.0)

func _process(delta: float) -> void:
	if not visible or lines.is_empty():
		return
	clock += delta
	if slide < 1.0:
		slide = minf(1.0, slide + delta * 4.0)
		arrange()
	var label = caption_text if speaker() == Story.NARRADOR else text
	var total = label.get_total_character_count()
	if typed < total:
		typed = minf(total, typed + delta * TYPE_SPEED)
		label.visible_characters = int(typed)
	else:
		hint.visible = true
		hint.modulate.a = 0.55 + 0.45 * sin(clock * 5.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var tapped = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		advance()

func advance() -> void:
	if lines.is_empty():
		return
	var label = caption_text if speaker() == Story.NARRADOR else text
	var total = label.get_total_character_count()
	if typed < total:
		# First tap shows the whole line; the next one moves on.
		typed = total
		label.visible_characters = -1
		return
	if index + 1 >= lines.size():
		close(false)
		return
	index += 1
	show_line()

func close(skipped: bool) -> void:
	hide()
	lines = []
	finished.emit(skipped)

func _draw() -> void:
	if lines.is_empty():
		return
	# A dark scene with the speaker's colour bursting out behind it, anime style.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.08, 0.86))
	if speaker() == Story.NARRADOR:
		return
	var side_left = on_left(speaker())
	var center = Vector2(size.x * (0.28 if side_left else 0.72), size.y * 0.52)
	var reach = size.length()
	var rays = 44
	for i in range(rays):
		var a0 = TAU * i / rays + clock * 0.05
		var a1 = a0 + TAU / rays * 0.45
		var tint = Color(accent, 0.22 if i % 2 == 0 else 0.1)
		draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a0) * reach, center + Vector2.from_angle(a1) * reach]), tint)
	draw_circle(center, size.x * 0.34, Color(accent, 0.16))
	draw_circle(center, size.x * 0.22, Color(accent, 0.14))
