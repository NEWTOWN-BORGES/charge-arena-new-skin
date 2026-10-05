extends Control
## A written, step-by-step tutorial over whatever screen is showing: the rest of the screen
## dims, the thing each step talks about is ringed in gold, and a card says what it is.
## SEGUINTE moves on, SALTAR ends it; either way `finished` says whether it was skipped.
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal finished(skipped: bool)

var steps: Array = []
var index = 0
var card: PanelContainer
var counter: Label
var heading: Label
var body: Label
var next_button: Button
var skip_button: Button
var safe_top = 0.0
var safe_bottom = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL, UiKit.SUN, 22))
	add_child(card)
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	card.add_child(stack)
	counter = label(13, UiKit.SUN_INK, UiKit.strong_font())
	stack.add_child(counter)
	heading = label(24, UiKit.WHITE, UiKit.title_font())
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(heading)
	body = label(18, UiKit.WHITE, UiKit.body_font())
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	stack.add_child(row)
	skip_button = key("SALTAR", "secondary")
	skip_button.pressed.connect(func(): close(true))
	row.add_child(skip_button)
	next_button = key("SEGUINTE", "primary")
	next_button.pressed.connect(advance)
	row.add_child(next_button)
	resized.connect(arrange)
	hide()

func label(font_size: int, color: Color, font: Font) -> Label:
	var l = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func key(text: String, kind: String) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 62)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", UiKit.title_font())
	b.add_theme_font_size_override("font_size", 20)
	UiKit.paint_key(b, kind)
	return b

func start(new_steps: Array) -> void:
	# Each step: {"title", "text", "target": Callable -> Rect2 in screen coordinates, or none}.
	steps = new_steps
	index = 0
	show()
	move_to_front()
	show_step()

func show_step() -> void:
	var step: Dictionary = steps[index]
	counter.text = tr("PASSO %d DE %d") % [index + 1, steps.size()]
	heading.text = String(step.title)
	body.text = String(step.text)
	next_button.text = tr("COMEÇAR") if index == steps.size() - 1 else tr("SEGUINTE  →")
	skip_button.visible = index < steps.size() - 1
	arrange()
	# Labels settle their wrapped height a frame later: arrange once more then.
	call_deferred("arrange")
	queue_redraw()

func advance() -> void:
	if index + 1 >= steps.size():
		close(false)
		return
	index += 1
	show_step()

func close(skipped: bool) -> void:
	hide()
	steps = []
	finished.emit(skipped)

func target_rect() -> Rect2:
	if steps.is_empty():
		return Rect2()
	var target = steps[index].get("target", null)
	if target is Callable and target.is_valid():
		var r = target.call()
		if r is Rect2 and r.has_area():
			return r.grow(8)
	return Rect2()

func arrange() -> void:
	if card == null or steps.is_empty():
		return
	var width = minf(size.x - 32.0, 560.0)
	# Wrapped text must be told how wide it may be; left to itself it measures one letter
	# per line and the card grows taller than the screen, with the words pushed out of it.
	var inner = width - 48.0
	for text_label in [counter, heading, body]:
		text_label.custom_minimum_size = Vector2(inner, 0)
	card.custom_minimum_size = Vector2(width, 0)
	card.size = Vector2(width, 0)
	var wanted = card.get_combined_minimum_size()
	card.size = Vector2(width, minf(wanted.y, size.y - safe_top - safe_bottom - 32.0))
	# The card keeps clear of what it points at: above it when it is low, below when high.
	var focus = target_rect()
	var y = size.y * 0.5 - card.size.y * 0.5
	if focus.has_area():
		if focus.get_center().y > size.y * 0.5:
			y = maxf(safe_top + 16.0, focus.position.y - card.size.y - 24.0)
		else:
			y = minf(size.y - safe_bottom - card.size.y - 16.0, focus.end.y + 24.0)
	card.position = Vector2((size.x - width) * 0.5, y)

func _draw() -> void:
	if steps.is_empty():
		return
	var shade = Color(0.04, 0.05, 0.08, 0.62)
	var focus = target_rect()
	if not focus.has_area():
		draw_rect(Rect2(Vector2.ZERO, size), shade)
		return
	# Dim everything around the spotlight, then ring it.
	draw_rect(Rect2(0, 0, size.x, focus.position.y), shade)
	draw_rect(Rect2(0, focus.end.y, size.x, size.y - focus.end.y), shade)
	draw_rect(Rect2(0, focus.position.y, focus.position.x, focus.size.y), shade)
	draw_rect(Rect2(focus.end.x, focus.position.y, size.x - focus.end.x, focus.size.y), shade)
	draw_rect(focus, UiKit.SUN, false, 5.0)
	draw_rect(focus.grow(6), Color(UiKit.SUN, 0.35), false, 3.0)
