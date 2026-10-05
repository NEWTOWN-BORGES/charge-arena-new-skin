extends Control
## The conversation scenes of the Modo história, staged like an anime visual novel.
##
## A scene has a painted backdrop (art/story/scenes) that drifts slowly, cinema bars top and
## bottom, and opens on a chapter card after a fade to black. BIT stands on the left and
## whoever he talks to on the right: the one speaking is lit and forward, the one listening
## dimmed; a phone call puts the far speaker inside a phone. Each robot has its own synth
## voice (audio/voices), a syllable every few letters as the line types out; the narrator's
## captions tick like a typewriter. A tap finishes the line or moves on; SALTAR ends it.
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Skins = preload("res://scripts/progression/skins.gd")
const Story = preload("res://scripts/story/story_script.gd")
const FACES = "res://art/story/faces/%s.png"
const SCENES = "res://art/story/scenes/%s.png"
const VOICES = "res://audio/voices/%s_%d.wav"
const TYPE_SPEED = 40.0
const TITLE_SECONDS = 2.2
const FADE_SECONDS = 0.35
const VERSUS_SECONDS = 2.8
const INK = Color("0b0a12")

signal finished(skipped: bool)

var lines: Array = []
var index = 0
var typed = 0.0
var clock = 0.0
var scene_clock = 0.0
var safe_top = 0.0
var safe_bottom = 0.0
var voice_db = 0.0
# "line": a line on screen; "title": a chapter card; "fade": going to black before a card.
var state = "line"
var state_time = 0.0
var fade = 0.0
var shake = 0.0
var accent = UiKit.SUN
var left_who = -99
var right_who = -99
var right_phone = false
var slide_left = 1.0
var slide_right = 1.0
var voiced_upto = 0

var backdrop: TextureRect
# Drawing layers: under the cast (shade, glow, siren, the phone's body) and over it (the
# dialogue box's accent, cinema bars, the chapter card's dimming, fades).
var under: Control
var over: Control
var left_face: TextureRect
var right_holder: Control
var right_face: TextureRect
var box: PanelContainer
var text: Label
var tag: PanelContainer
var tag_label: Label
var caption: Label
var hint: Label
var title_chapter: Label
var title_name: Label
var title_place: Label
var skip_button: Button
var voice: AudioStreamPlayer
var textures: Dictionary = {}
var voices: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	clip_contents = true
	backdrop = TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	under = layer(draw_under)
	left_face = face_rect()
	add_child(left_face)
	right_holder = Control.new()
	right_holder.clip_contents = true
	right_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_holder)
	right_face = face_rect()
	right_face.flip_h = true
	right_holder.add_child(right_face)
	box = PanelContainer.new()
	var glass = StyleBoxFlat.new()
	glass.bg_color = Color(0.04, 0.05, 0.09, 0.9)
	glass.set_corner_radius_all(20)
	glass.border_color = Color(1, 1, 1, 0.08)
	glass.set_border_width_all(1)
	glass.content_margin_left = 28
	glass.content_margin_right = 28
	glass.content_margin_top = 34
	glass.content_margin_bottom = 40
	glass.shadow_color = Color(0, 0, 0, 0.45)
	glass.shadow_size = 18
	box.add_theme_stylebox_override("panel", glass)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_override("font", UiKit.body_font())
	text.add_theme_font_size_override("font_size", 23)
	text.add_theme_color_override("font_color", Color("f2f0ea"))
	text.add_theme_constant_override("line_spacing", 4)
	box.add_child(text)
	tag = PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag)
	tag_label = Label.new()
	tag_label.add_theme_font_override("font", UiKit.title_font())
	tag_label.add_theme_font_size_override("font_size", 21)
	tag.add_child(tag_label)
	caption = label(UiKit.strong_font(), 23, Color("f3eedd"))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	hint = label(UiKit.strong_font(), 15, Color(1, 1, 1, 0.55))
	hint.text = "▼"
	add_child(hint)
	over = layer(draw_over)
	for top in [box, tag, caption, hint, over]:
		top.z_index = 3
	title_chapter = label(UiKit.strong_font(), 18, UiKit.SUN)
	title_name = label(UiKit.title_font(), 54, Color.WHITE)
	title_place = label(UiKit.body_font(), 19, Color(1, 1, 1, 0.75))
	for l in [title_chapter, title_name, title_place]:
		l.z_index = 4
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(l)
	skip_button = Button.new()
	skip_button.text = "SALTAR  ▶▶"
	skip_button.custom_minimum_size = Vector2(140, 46)
	skip_button.add_theme_font_override("font", UiKit.title_font())
	skip_button.add_theme_font_size_override("font_size", 16)
	var skip_style = StyleBoxFlat.new()
	skip_style.bg_color = Color(0, 0, 0, 0.45)
	skip_style.set_corner_radius_all(23)
	skip_style.border_color = Color(1, 1, 1, 0.35)
	skip_style.set_border_width_all(1)
	for s in ["normal", "hover", "pressed", "focus"]:
		skip_button.add_theme_stylebox_override(s, skip_style)
	skip_button.add_theme_color_override("font_color", Color.WHITE)
	skip_button.pressed.connect(func(): close(true))
	skip_button.z_index = 5
	add_child(skip_button)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	resized.connect(arrange)
	hide()

func layer(painter: Callable) -> Control:
	var c = Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(painter)
	add_child(c)
	return c

func face_rect() -> TextureRect:
	var r = TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func label(font: Font, font_size: int, color: Color) -> Label:
	var l = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ------------------------------------------------------------------------------ lines

func start(new_lines: Array) -> void:
	# Each entry: [speaker, text] or [speaker, text, options]; see story_script.gd.
	lines = new_lines
	index = 0
	left_who = -99
	right_who = -99
	right_phone = false
	if lines.is_empty():
		finished.emit(false)
		return
	show()
	move_to_front()
	fade = 0.0
	if backdrop.texture == null:
		backdrop.texture = texture(SCENES % "estadio")
	show_entry()

func who() -> int:
	return int(lines[index][0])

func options() -> Dictionary:
	var entry: Array = lines[index]
	if entry.size() > 2:
		if entry[2] is Dictionary:
			return entry[2]
		if entry[2] is String:
			return {"mood": entry[2]}
	return {}

func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path]

func face(speaker: int, mood: String = "", dark: bool = false) -> Texture2D:
	var key = Story.face_key(speaker) + ("_dark" if dark else "")
	var picture = texture(FACES % (key + ("_" + mood if mood != "" else "")))
	return picture if picture != null else texture(FACES % key)

func dark_line() -> bool:
	return String(options().get("face", "")) == "dark"

func corrupted(speaker: int) -> int:
	# A corrupted friend of season two is its hard skin, as it already is in the game. MAGNUS
	# is the twist: corrupted in his usual skin, IMPERADOR only once freed.
	if speaker < 0 or speaker == Story.MAGNUS or speaker >= Skins.CATALOG.size() or Skins.CATALOG[speaker].has("hard_of"):
		return speaker
	var hard = Skins.hard_of_boss(speaker)
	return hard if hard >= 0 else speaker

func accent_of(speaker: int) -> Color:
	match speaker:
		Story.AGENTE: return Color("3b6fe0")
		Story.LOCUTOR: return Color("b27cff")
	if speaker < 0:
		return UiKit.SUN
	var light = String(Skins.CATALOG[speaker].get("light", ""))
	# Skins in the team's colours (BIT) have no light of their own: jade, as they play.
	return Color(light) if light != "" else Color("4fd3b9")

func on_left(speaker: int) -> bool:
	return speaker == Story.BIT or speaker == Story.BIT_ELITE

func show_entry() -> void:
	var speaker = who()
	var opts = options()
	typed = 0.0
	voiced_upto = 0
	state_time = 0.0
	if speaker == Story.VERSUS:
		# The fight card: it plays by itself and hands over to the match.
		state = "versus"
		voice.stop()
		arrange()
		return
	if speaker == Story.SCENE and bool(opts.get("quiet", false)):
		# Just the backdrop, no card: the talk after a match, in the arena it was played in.
		backdrop.texture = texture(SCENES % String(opts.get("bg", "estadio")))
		scene_clock = 0.0
		left_who = -99
		right_who = -99
		right_phone = false
		next_entry()
		return
	if speaker == Story.SCENE:
		# To black, change the backdrop, show the chapter card; the cast leaves the stage.
		state = "fade"
		arrange()
		return
	state = "line"
	accent = accent_of(speaker)
	shake = 0.35 if String(opts.get("fx", "")) == "shake" else 0.0
	var narrator = speaker == Story.NARRADOR
	# The script is written in Portuguese; each line is translated as it is shown.
	var line = tr(String(lines[index][1]))
	if narrator:
		caption.text = line
		caption.visible_characters = 0
	else:
		text.text = line
		text.visible_characters = 0
		var dark = String(opts.get("face", "")) == "dark"
		# Corrupted: the friend shows up in its hard skin, with that skin's name and colour.
		var shown = corrupted(speaker) if dark else speaker
		if dark:
			accent = accent_of(shown)
		tag_label.text = Story.speaker_name(shown)
		tag_label.add_theme_color_override("font_color", INK if accent.get_luminance() > 0.5 else Color.WHITE)
		var tag_style = StyleBoxFlat.new()
		tag_style.bg_color = accent
		tag_style.set_corner_radius_all(8)
		tag_style.content_margin_left = 18
		tag_style.content_margin_right = 18
		tag_style.content_margin_top = 5
		tag_style.content_margin_bottom = 5
		tag.add_theme_stylebox_override("panel", tag_style)
		var mood = String(opts.get("mood", ""))
		if dark and mood == "":
			# Corrupted friends glare.
			mood = "angry"
		if on_left(speaker):
			if left_who != speaker:
				slide_left = 0.0
			left_who = speaker
			left_face.texture = face(shown, mood)
		else:
			var phone = bool(opts.get("phone", false))
			if right_who != speaker or right_phone != phone:
				slide_right = 0.0
			right_who = speaker
			right_phone = phone
			right_face.texture = face(shown, mood)
	arrange()
	call_deferred("arrange")

func begin_scene() -> void:
	var opts = options()
	backdrop.texture = texture(SCENES % String(opts.get("bg", "estadio")))
	scene_clock = 0.0
	left_who = -99
	right_who = -99
	right_phone = false
	left_face.texture = null
	right_face.texture = null
	title_chapter.text = tr(String(opts.get("chapter", ""))).to_upper()
	title_name.text = tr(String(lines[index][1]))
	title_place.text = tr(String(opts.get("place", "")))
	state = "title"
	state_time = 0.0
	fade = 1.0
	arrange()

# ------------------------------------------------------------------------------ layout

func arrange() -> void:
	if lines.is_empty():
		return
	var bar = cinema_bar()
	# The backdrop drifts in slowly over the first seconds of a scene.
	var drift = 1.0 + 0.06 * (1.0 - clampf(scene_clock / 14.0, 0.0, 1.0))
	backdrop.size = size * drift
	backdrop.position = (size - backdrop.size) * Vector2(0.5, 0.35)
	skip_button.position = Vector2(size.x - skip_button.size.x - 14.0, safe_top + bar + 12.0)
	var width = minf(size.x - 28.0, 680.0)
	var left = (size.x - width) * 0.5
	for l in [title_chapter, title_name, title_place]:
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, 0)
		l.visible = state == "title"
	title_chapter.position = Vector2(left, size.y * 0.42 - 72)
	title_name.position = Vector2(left, size.y * 0.42 - 44)
	title_place.position = Vector2(left, size.y * 0.42 + 42)
	var speaker = who()
	var line_up = state == "line"
	var narrator = speaker == Story.NARRADOR
	caption.visible = line_up and narrator
	box.visible = line_up and not narrator
	tag.visible = box.visible
	hint.visible = line_up and typed >= (caption if narrator else text).get_total_character_count()
	left_face.visible = line_up and left_who != -99 and not narrator
	right_holder.visible = line_up and right_who != -99 and not narrator
	if not line_up:
		return
	if narrator:
		caption.custom_minimum_size = Vector2(width - 40.0, 0)
		caption.size = Vector2(width - 40.0, 0)
		var tall_caption = caption.get_combined_minimum_size().y
		caption.position = Vector2(left + 20.0, size.y * 0.5 - tall_caption * 0.5)
		hint.position = Vector2(size.x * 0.5 - 6.0, caption.position.y + tall_caption + 16.0 + sin(clock * 6.0) * 3.0)
		return
	text.custom_minimum_size = Vector2(width - 56.0, 0)
	box.custom_minimum_size = Vector2(width, 170)
	box.size = Vector2(width, 0)
	box.size = Vector2(width, box.get_combined_minimum_size().y)
	box.position = Vector2(left, size.y - safe_bottom - bar - 18.0 - box.size.y)
	tag.size = tag.get_combined_minimum_size()
	var speaking_left = on_left(speaker)
	tag.position = Vector2(left + 22.0 if speaking_left else left + width - 22.0 - tag.size.x, box.position.y - tag.size.y * 0.6)
	hint.position = Vector2(left + width - 34.0, box.position.y + box.size.y - 34.0 + sin(clock * 6.0) * 3.0)
	# The stage: BIT on the left, the other on the right; the speaker lit and in front.
	var tall = minf(box.position.y - safe_top - bar - 30.0, size.y * 0.5)
	var wide = tall * 0.8
	var floor_y = box.position.y + 30.0
	# Whoever speaks stands in front; the listener steps back, smaller and in shadow.
	left_face.z_index = 1 if speaking_left else 0
	right_holder.z_index = 0 if speaking_left else 1
	var back = 0.86
	var ease_l = 1.0 - pow(1.0 - slide_left, 3.0)
	var ease_r = 1.0 - pow(1.0 - slide_right, 3.0)
	var k_left = 1.0 if speaking_left else back
	left_face.size = Vector2(wide, tall) * k_left
	left_face.position = Vector2(-wide * (0.08 if speaking_left else 0.24) - (1.0 - ease_l) * 90.0, floor_y - tall * k_left)
	left_face.modulate = lit(speaking_left) * Color(1, 1, 1, ease_l)
	if right_phone:
		# Over the phone: a handset floating top right, the caller on its screen.
		var phone = Vector2(wide * 0.62, wide * 1.1)
		right_holder.size = phone
		right_holder.position = Vector2(size.x - phone.x - 26.0 + (1.0 - ease_r) * 90.0, safe_top + bar + 90.0)
		right_face.size = Vector2(phone.x * 1.6, phone.x * 2.0)
		right_face.position = Vector2(-phone.x * 0.3, phone.y * 0.12)
	else:
		var k_right = back if speaking_left else 1.0
		right_holder.size = Vector2(wide, tall) * k_right
		right_holder.position = Vector2(size.x - wide * k_right * (0.92 if not speaking_left else 0.76) + (1.0 - ease_r) * 90.0, floor_y - tall * k_right)
		right_face.size = Vector2(wide, tall) * k_right
		right_face.position = Vector2.ZERO
	right_holder.modulate = lit(not speaking_left) * Color(1, 1, 1, ease_r)

func lit(speaking: bool) -> Color:
	return Color.WHITE if speaking else Color(0.42, 0.44, 0.52)

func cinema_bar() -> float:
	return size.y * 0.035

# ------------------------------------------------------------------------------ time

func _process(delta: float) -> void:
	if not visible or lines.is_empty():
		return
	clock += delta
	scene_clock += delta
	state_time += delta
	shake = maxf(0.0, shake - delta)
	if slide_left < 1.0:
		slide_left = minf(1.0, slide_left + delta * 3.5)
	if slide_right < 1.0:
		slide_right = minf(1.0, slide_right + delta * 3.5)
	match state:
		"fade":
			fade = minf(1.0, state_time / FADE_SECONDS)
			if state_time >= FADE_SECONDS:
				begin_scene()
		"title":
			if state_time >= TITLE_SECONDS:
				next_entry()
		"versus":
			fade = 0.0
			if state_time >= VERSUS_SECONDS:
				next_entry()
		"line":
			fade = maxf(0.0, fade - delta / FADE_SECONDS)
			type_line(delta)
	arrange()
	under.queue_redraw()
	over.queue_redraw()

func type_line(delta: float) -> void:
	var target = caption if who() == Story.NARRADOR else text
	var total = target.get_total_character_count()
	if typed < total:
		typed = minf(total, typed + delta * TYPE_SPEED)
		target.visible_characters = int(typed)
		speak(target.text, int(typed))
	else:
		target.visible_characters = -1

func speak(line: String, upto: int) -> void:
	# A syllable every few letters (a tick every three for the narrator), never on spaces.
	var every = 3 if who() == Story.NARRADOR else 2
	while voiced_upto < upto:
		var ch = line.substr(voiced_upto, 1)
		voiced_upto += 1
		if ch == " " or ".,!?…—-:;".contains(ch):
			continue
		if voiced_upto % every != 0:
			continue
		var path = VOICES % [Story.voice_key(who()), randi() % 6]
		if not voices.has(path):
			voices[path] = load(path) if ResourceLoader.exists(path) else null
		if voices[path] == null:
			return
		voice.stream = voices[path]
		# A corrupted robot speaks lower and slower.
		voice.pitch_scale = randf_range(0.76, 0.84) if dark_line() else randf_range(0.93, 1.08)
		voice.volume_db = voice_db + (-6.0 if who() == Story.NARRADOR else 2.0)
		voice.play()
		return

func _gui_input(event: InputEvent) -> void:
	var tapped = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		accept_event()
		advance()

func advance() -> void:
	if lines.is_empty() or state == "fade":
		return
	if state == "versus":
		if state_time > 0.6:
			next_entry()
		return
	if state == "title":
		# A tap cuts the chapter card short.
		if state_time > 0.5:
			next_entry()
		return
	var target = caption if who() == Story.NARRADOR else text
	var total = target.get_total_character_count()
	if typed < total:
		typed = total
		target.visible_characters = -1
		return
	next_entry()

func next_entry() -> void:
	if index + 1 >= lines.size():
		close(false)
		return
	index += 1
	show_entry()

func close(skipped: bool) -> void:
	hide()
	lines = []
	voice.stop()
	finished.emit(skipped)

# ------------------------------------------------------------------------------ drawing

func shake_offset() -> Vector2:
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 22.0

func draw_under() -> void:
	if lines.is_empty():
		return
	var c = under
	c.draw_set_transform(shake_offset())
	# Shade the backdrop: light at the top, dark at the bottom where the text sits.
	var shade = PackedColorArray([Color(0, 0, 0, 0.1), Color(0, 0, 0, 0.1), Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.82)])
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]), shade)
	if state != "line":
		return
	if who() == Story.NARRADOR:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	if String(options().get("fx", "")) == "lineup":
		# The mysterious entrants walk in one by one: dark shapes, eyes and neon alight.
		var cast = [12, 13, 14, 15, 17, 18, 20, 16, 19, 21]
		var w = size.x / 5.0
		for i in range(cast.size()):
			var shown = clampf(state_time * 3.0 - i * 0.6, 0.0, 1.0)
			if shown <= 0.0:
				continue
			var picture = face(cast[i], "", true)
			if picture == null:
				continue
			var row = i / 5
			var r = Rect2(Vector2((i % 5) * w - w * 0.1, size.y * (0.1 + row * 0.2)), Vector2(w * 1.2, w * 1.5))
			c.draw_texture_rect(picture, r, false, Color(1, 1, 1, shown))
	if String(options().get("fx", "")) == "siren":
		var red = fmod(clock * 3.0, 1.0) < 0.5
		c.draw_rect(Rect2(Vector2.ZERO, size), Color("ff2030", 0.2) if red else Color("2050ff", 0.2))
	if right_phone and right_holder.visible:
		# The handset's body behind the caller.
		var body = Rect2(right_holder.position, right_holder.size).grow(12)
		c.draw_rect(body, Color("15161c"), true)
		c.draw_rect(body, Color(1, 1, 1, 0.3), false, 2.0)

func draw_versus(c: Control) -> void:
	# BIT against the rival: the screen split on a slant in their two colours, the portraits
	# sliding in from the sides, and VS punching in between them.
	var opts = options()
	var left_skin = int(opts.get("left", Story.BIT))
	var right_skin = int(opts.get("right", 0))
	var left_col = accent_of(left_skin)
	var right_col = accent_of(right_skin)
	var t = state_time
	var ease = 1.0 - pow(1.0 - clampf(t / 0.45, 0.0, 1.0), 3.0)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color("07080d"))
	var slant = size.x * 0.18
	var mid = size.y * 0.5
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x * 0.5 + slant, 0), Vector2(size.x * 0.5 - slant, size.y), Vector2(0, size.y)]), left_col.darkened(0.55))
	c.draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 + slant, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x * 0.5 - slant, size.y)]), right_col.darkened(0.55))
	# Speed streaks in each colour.
	for i in range(14):
		var y = fmod(i * 97.0 + t * 900.0 * (1 if i % 2 else -1), size.y)
		c.draw_rect(Rect2(Vector2(0 if i % 2 else size.x * 0.5, y), Vector2(size.x * 0.5, 2)), Color(left_col if i % 2 else right_col, 0.18))
	var tall = size.y * 0.4
	var wide = tall * 0.8
	var left_pic = face(left_skin)
	var right_pic = face(right_skin)
	if left_pic:
		c.draw_texture_rect(left_pic, Rect2(Vector2(-wide * 0.18 - (1.0 - ease) * size.x * 0.6, mid - tall * 0.95), Vector2(wide, tall)), false)
	if right_pic:
		# Mirrored, so the rival faces BIT.
		var r = Rect2(Vector2(size.x - wide * 0.82 + (1.0 - ease) * size.x * 0.6, mid + tall * 0.02), Vector2(wide, tall))
		c.draw_set_transform(Vector2(r.position.x * 2.0 + r.size.x, 0), 0.0, Vector2(-1, 1))
		c.draw_texture_rect(right_pic, r, false)
		c.draw_set_transform(Vector2.ZERO)
	# The white slash between them.
	c.draw_line(Vector2(size.x * 0.5 + slant, 0), Vector2(size.x * 0.5 - slant, size.y), Color.WHITE, 5.0)
	var font = UiKit.title_font()
	var pop = 1.0 + 0.6 * maxf(0.0, 1.0 - (t - 0.35) / 0.25) if t > 0.35 else 0.0
	if pop > 0.0:
		var vs_size = int(120 * pop)
		var at = Vector2(size.x * 0.5, mid + vs_size * 0.35)
		c.draw_string_outline(font, at - Vector2(vs_size * 0.62, 0), tr("VS"), HORIZONTAL_ALIGNMENT_LEFT, -1, vs_size, 18, Color("0b0a12"))
		c.draw_string(font, at - Vector2(vs_size * 0.62, 0), tr("VS"), HORIZONTAL_ALIGNMENT_LEFT, -1, vs_size, UiKit.SUN)
	if t > 0.35 and t < 0.5:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, (0.5 - t) / 0.15 * 0.8))
	# Names and the round.
	var left_name = Story.speaker_name(left_skin)
	var right_name = Story.speaker_name(right_skin)
	c.draw_string_outline(font, Vector2(24, mid + 56), tr(left_name), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, 40, 10, Color.BLACK)
	c.draw_string(font, Vector2(24, mid + 56), tr(left_name), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, 40, left_col.lightened(0.3))
	c.draw_string_outline(font, Vector2(size.x * 0.4 - 24, mid - 30), tr(right_name), HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.6, 40, 10, Color.BLACK)
	c.draw_string(font, Vector2(size.x * 0.4 - 24, mid - 30), tr(right_name), HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.6, 40, right_col.lightened(0.3))
	var bar = cinema_bar()
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, safe_top + bar + 64)), Color(0, 0, 0, 0.85))
	c.draw_string(UiKit.strong_font(), Vector2(0, safe_top + bar + 30), tr(String(opts.get("round", ""))), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UiKit.SUN)
	c.draw_string(UiKit.body_font(), Vector2(0, safe_top + bar + 54), tr(String(opts.get("place", ""))), HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(1, 1, 1, 0.8))
	c.draw_rect(Rect2(Vector2(0, size.y - safe_bottom - bar), Vector2(size.x, safe_bottom + bar + 40)), Color.BLACK)

func draw_over() -> void:
	if lines.is_empty():
		return
	var c = over
	if state == "versus":
		draw_versus(c)
		return
	var bar = cinema_bar()
	if state == "line":
		if right_phone and right_holder.visible:
			var screen = Rect2(right_holder.position, right_holder.size)
			c.draw_rect(Rect2(screen.position, Vector2(screen.size.x, 34)), Color(0.05, 0.06, 0.08, 0.9))
			var seconds = int(scene_clock)
			c.draw_circle(screen.position + Vector2(16, 17), 5, Color("34d399"))
			c.draw_string(UiKit.strong_font(), screen.position + Vector2(28, 23), tr("CHAMADA · %d:%02d") % [seconds / 60, seconds % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		if box.visible:
			# A thin line in the speaker's colour along the top of the dialogue box.
			c.draw_rect(Rect2(box.position + Vector2(20, 0), Vector2(box.size.x - 40, 3)), accent)
	# Cinema bars.
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, safe_top + bar)), Color.BLACK)
	c.draw_rect(Rect2(Vector2(0, size.y - safe_bottom - bar), Vector2(size.x, safe_bottom + bar + 40)), Color.BLACK)
	if state == "title":
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
		var grow = clampf(state_time / 0.5, 0.0, 1.0)
		var half = size.x * 0.32 * grow
		c.draw_rect(Rect2(size.x * 0.5 - half, size.y * 0.42 + 30.0, half * 2.0, 2), UiKit.SUN)
	elif fade > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, fade))
