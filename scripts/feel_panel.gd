extends ColorRect
## LAB only: every game-feel number on a slider, live. Moving a slider changes the next
## shot; GUARDAR keeps the values on this device (user://game_feel.cfg), REPOR brings back
## the defaults. Game feel needs iterating on a real phone, not numbers hidden in scripts.
const UiKit = preload("res://scripts/ui_kit.gd")
const GameFeel = preload("res://scripts/game_feel.gd")

var feel
var rows: Dictionary = {}
var panel: PanelContainer

func _ready() -> void:
	color = Color(UiKit.NIGHT, 0.9)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	add_child(panel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)
	var title = Label.new()
	title.text = "AFINAR SENSAÇÃO · LAB"
	title.add_theme_font_override("font", UiKit.title_font())
	title.add_theme_font_size_override("font_size", 26)
	list.add_child(title)
	var note = Label.new()
	note.text = "Cada valor muda já o próximo disparo. Só apresentação: a partida não muda."
	note.add_theme_color_override("font_color", UiKit.MUTED)
	note.add_theme_font_size_override("font_size", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(scroll)
	var sliders = VBoxContainer.new()
	sliders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sliders.add_theme_constant_override("separation", 4)
	scroll.add_child(sliders)
	for key in GameFeel.DEFAULTS:
		var base = float(GameFeel.DEFAULTS[key])
		var row = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = key
		name_label.custom_minimum_size.x = 250
		name_label.add_theme_font_size_override("font_size", 13)
		row.add_child(name_label)
		var slider = HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 36
		# From nothing to three times the default (negatives, like the duck, the other way).
		slider.min_value = minf(0.0, base * 3.0)
		slider.max_value = maxf(0.0, base * 3.0) if base != 0.0 else 1.0
		slider.step = 1.0 if base == roundf(base) and absf(base) >= 1.0 else absf(base) / 50.0
		row.add_child(slider)
		var value_label = Label.new()
		value_label.custom_minimum_size.x = 70
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 13)
		row.add_child(value_label)
		slider.value_changed.connect(func(value):
			feel.values[key] = value
			value_label.text = str(snappedf(value, 0.001)))
		sliders.add_child(row)
		rows[key] = [slider, value_label]
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	list.add_child(buttons)
	for entry in [["GUARDAR", "primary"], ["REPOR", "secondary"], ["FECHAR", "secondary"]]:
		var button = Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 56
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.paint_key(button, entry[1])
		buttons.add_child(button)
		match entry[0]:
			"GUARDAR":
				button.pressed.connect(func(): feel.save_values())
			"REPOR":
				button.pressed.connect(func():
					feel.reset()
					sync())
			"FECHAR":
				button.pressed.connect(hide)
	resized.connect(arrange)
	arrange()

func open(new_feel) -> void:
	feel = new_feel
	sync()
	show()

func sync() -> void:
	for key in rows:
		rows[key][0].set_value_no_signal(feel.get_value(key))
		rows[key][1].text = str(snappedf(feel.get_value(key), 0.001))

func arrange() -> void:
	var margin = 16.0
	panel.position = Vector2(margin, margin + 20)
	panel.size = Vector2(size.x - margin * 2, size.y - margin * 2 - 40)
