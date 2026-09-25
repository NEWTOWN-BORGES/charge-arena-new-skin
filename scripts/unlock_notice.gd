extends Control
## Non-modal, queued reward banners. Only the close button consumes touches.
const UiKit = preload("res://scripts/ui_kit.gd")
var painter
var pending: Array = []
var current: Dictionary = {}
var remaining = 0.0
var card: Panel
var icon: Control
var heading: Label
var title: Label
var close: Button
var badge: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	card = Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A reward, so it wears the sun: a gold rim over the usual plate, and a NOVO! tab.
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL, UiKit.SUN, 20))
	add_child(card)
	icon = Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(12, 12)
	icon.size = Vector2(60, 60)
	icon.draw.connect(draw_item)
	card.add_child(icon)
	badge = Label.new()
	badge.text = "NOVO!"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font", UiKit.title_font())
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", UiKit.INK)
	var tab = UiKit.flat(UiKit.SUN, Color.TRANSPARENT, 9, 3, UiKit.SUN_LIP).duplicate()
	tab.content_margin_top = 1
	tab.content_margin_bottom = 3
	tab.content_margin_left = 8
	tab.content_margin_right = 8
	badge.add_theme_stylebox_override("normal", tab)
	card.add_child(badge)
	heading = Label.new()
	heading.position = Vector2(84, 14)
	heading.add_theme_font_override("font", UiKit.strong_font())
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", UiKit.SUN)
	card.add_child(heading)
	title = Label.new()
	title.position = Vector2(84, 32)
	title.add_theme_font_override("font", UiKit.title_font())
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UiKit.WHITE)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(title)
	for label in [heading, title, badge]: label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close = Button.new()
	close.text = "×"
	close.tooltip_text = "Fechar notificação"
	close.flat = true
	close.size = Vector2(44, 44)
	close.add_theme_font_size_override("font_size", 26)
	close.add_theme_color_override("font_color", UiKit.MUTED)
	close.pressed.connect(dismiss)
	card.add_child(close)
	resized.connect(arrange)
	arrange()
	card.hide()
	set_process(false)

func arrange() -> void:
	var width = minf(380, maxf(260, size.x - 24))
	card.size = Vector2(width, 84)
	card.position = Vector2((size.x - width) * 0.5, painter.safe_top + 14)
	close.position = Vector2(width - 48, 20)
	title.size = Vector2(width - 138, 34)
	heading.size = Vector2(width - 138, 18)
	badge.position = Vector2(width - 118, -11)

func enqueue(item: Dictionary) -> void:
	if item == current or pending.has(item): return
	pending.append(item.duplicate())
	if current.is_empty(): show_next()

func show_next() -> void:
	if pending.is_empty():
		current = {}
		card.hide()
		set_process(false)
		return
	current = pending.pop_front()
	heading.text = "SKIN DESBLOQUEADA" if current.kind == "skin" else "PODER DESBLOQUEADO"
	title.text = current.name
	remaining = 4.0
	arrange()
	icon.queue_redraw()
	card.show()
	set_process(true)

func dismiss() -> void:
	show_next()

func _process(dt: float) -> void:
	remaining -= dt
	# A short fade with a small drop into place; it never slides across other controls.
	var shown = minf(clampf((4.0 - remaining) / 0.18, 0, 1), clampf(remaining / 0.2, 0, 1))
	card.modulate.a = shown
	card.position.y = painter.safe_top + 14 - (1.0 - shown) * 10.0
	if remaining <= 0: show_next()

func draw_item() -> void:
	if current.is_empty(): return
	UiKit.disc(icon, Vector2(30, 30), 30, UiKit.FIELD)
	if current.kind == "skin":
		painter.portrait(Vector2(30, 31), UiKit.SUN, false, int(current.id), icon, false, 0.6)
	else:
		UiKit.ring(icon, Vector2(30, 30), 30, UiKit.SUN)
		painter.power_icon(current.id, Vector2(30, 30), UiKit.SUN, icon, 1.0)
