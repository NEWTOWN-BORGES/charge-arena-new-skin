extends RefCounted
## The interface's look: its palette, its type and the shapes every panel, key and badge is
## cut from. Panels follow the studio look of the robots: navy combat plates with a strong
## shadow and a chunky lip under them, so the main action reads clearly over the arena.
##
## Shapes are drawn from one small generated atlas (`atlas()`), so a whole screen of discs,
## rings and rounded boxes lands in a single batch instead of one draw call per shape.
const TITLE_FILE = preload("res://art/fonts/LilitaOne-Regular.ttf")
const BODY_FILE = preload("res://art/fonts/Rubik-Variable.ttf")

# Stadium blues for the plates, bright ink for the words, one warm sun for the action that
# matters, the teams' own colours for everything that belongs to a side. The names keep
# their roles: WHITE is the main text colour and PANEL the plates, whatever their tone.
const NIGHT = Color("0d1b35")
const PANEL = Color("18365d")
const PANEL_EDGE = Color("477db4")
const CARD = Color("24558a")
const CARD_HI = Color("326eaa")
const CARD_EDGE = Color("4687c4")
const FIELD = Color("102442")
const LIP = Color("08152d")
const EMPTY = Color("1a2d49")
const INK = Color("101b30")
const WHITE = Color("f4f9ff")
const MUTED = Color("b2c9e4")
const SUN = Color("ffd23f")
const SUN_LIP = Color("d7931d")
# The sun as ink: gold that reads on the dark plates, for accent words.
const SUN_INK = Color("ffd05a")
const MINT = Color("38dfa3")
const MINT_LIP = Color("147554")
const GOLD = Color("ffb703")
const DANGER = Color("ff2a4b")
const CYAN = Color("00caff")
const CORAL = Color("ff2a4b")

# Where each shape sits in the atlas.
const DISC = Rect2(0, 0, 128, 128)
const RING = Rect2(128, 0, 128, 128)
const BOX = Rect2(0, 128, 64, 64)
const BOX_RIM = Rect2(64, 128, 64, 64)
const SMALL = Rect2(128, 128, 24, 24)
const SMALL_RIM = Rect2(152, 128, 24, 24)
const SHADOW = Rect2(176, 128, 64, 64)
const SOLID = Rect2(242, 130, 4, 4)
const BOX_CORNER = 14.0
const SMALL_CORNER = 8.0
const SHADOW_CORNER = 28.0

static var _atlas: Texture2D
# The engine's own font stays behind ours for the symbols the game fonts lack (arrows, stars).
static var _symbols: Font
static var _fonts: Dictionary = {}
static var _theme: Theme
static var _styles: Dictionary = {}

# --- type ----------------------------------------------------------------------------------
static func _prepare(file: FontFile) -> FontFile:
	# Plain rasterised glyphs. A distance-field font looked like the cheaper choice — one
	# atlas for every size — but once the menus had used a few hundred glyphs they spread
	# over many texture pages and the HUD's words broke into a batch every few letters.
	file.multichannel_signed_distance_field = false
	if _symbols == null:
		_symbols = ThemeDB.fallback_font
	file.fallbacks = [_symbols]
	return file

static func title_font() -> Font:
	# Chunky rounded capitals for titles, keys, the score and the big moments.
	if not _fonts.has("title"):
		_fonts["title"] = _prepare(TITLE_FILE)
	return _fonts["title"]

static func _weight(value: int) -> Font:
	var key = "body%d" % value
	if not _fonts.has(key):
		var variation = FontVariation.new()
		variation.base_font = _prepare(BODY_FILE)
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): value}
		_fonts[key] = variation
	return _fonts[key]

static func body_font() -> Font:
	return _weight(430)

static func strong_font() -> Font:
	# Captions and small labels in capitals: heavier, so they hold up at ten pixels.
	return _weight(640)

# --- shapes ---------------------------------------------------------------------------------
static func atlas() -> Texture2D:
	if _atlas != null:
		return _atlas
	var image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	_round_box(image, DISC, 62.0, -1.0)
	_round_box(image, RING, 62.0, 5.0)
	_round_box(image, BOX, BOX_CORNER, -1.0)
	_round_box(image, BOX_RIM, BOX_CORNER, 2.2)
	_round_box(image, SMALL, SMALL_CORNER, -1.0)
	_round_box(image, SMALL_RIM, SMALL_CORNER, 1.6)
	_shadow(image, SHADOW)
	image.fill_rect(Rect2i(SOLID.grow(2)), Color.WHITE)
	_atlas = ImageTexture.create_from_image(image)
	return _atlas

static func _round_box(image: Image, area: Rect2, radius: float, stroke: float) -> void:
	# A white rounded box (a disc when the radius is half the side), or just its rim, with a
	# one pixel antialiased edge. Written once at start-up.
	var half = area.size * 0.5 - Vector2.ONE
	for y in range(int(area.size.y)):
		for x in range(int(area.size.x)):
			var p = Vector2(x + 0.5, y + 0.5) - area.size * 0.5
			var q = (p.abs() - half + Vector2.ONE * radius).max(Vector2.ZERO)
			var d = q.length() + minf(maxf(absf(p.x) - half.x + radius, absf(p.y) - half.y + radius), 0.0) - radius
			var cover = clampf(0.5 - d, 0.0, 1.0)
			if stroke > 0.0:
				cover = minf(cover, clampf(d + stroke + 0.5, 0.0, 1.0))
			if cover > 0.0:
				image.set_pixel(int(area.position.x) + x, int(area.position.y) + y, Color(1, 1, 1, cover))

static func _shadow(image: Image, area: Rect2) -> void:
	var half = area.size * 0.5
	for y in range(int(area.size.y)):
		for x in range(int(area.size.x)):
			var p = (Vector2(x + 0.5, y + 0.5) - half).abs() - half + Vector2.ONE * SHADOW_CORNER
			var d = p.max(Vector2.ZERO).length() - 4.0
			var cover = clampf(1.0 - d / (SHADOW_CORNER - 4.0), 0.0, 1.0)
			image.set_pixel(int(area.position.x) + x, int(area.position.y) + y, Color(1, 1, 1, cover * cover * (3.0 - 2.0 * cover)))

static func slice(canvas: CanvasItem, rect: Rect2, region: Rect2, corner: float, color: Color, scale: float = 1.0) -> void:
	# Nine plain textured rects instead of a nine-patch command, so they batch with the rest.
	var texture = atlas()
	var c = minf(corner * scale, minf(rect.size.x, rect.size.y) * 0.5)
	var xs = [rect.position.x, rect.position.x + c, rect.end.x - c, rect.end.x]
	var ys = [rect.position.y, rect.position.y + c, rect.end.y - c, rect.end.y]
	var us = [region.position.x, region.position.x + corner, region.end.x - corner, region.end.x]
	var vs = [region.position.y, region.position.y + corner, region.end.y - corner, region.end.y]
	for j in range(3):
		if ys[j + 1] <= ys[j]:
			continue
		for i in range(3):
			if xs[i + 1] <= xs[i]:
				continue
			canvas.draw_texture_rect_region(texture, Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j]), Rect2(us[i], vs[j], us[i + 1] - us[i], vs[j + 1] - vs[j]), color)

static func disc(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_texture_rect_region(atlas(), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), DISC, color)

static func ring(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	# The stroke scales with the ring: about four per cent of its radius.
	canvas.draw_texture_rect_region(atlas(), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), RING, color)

static func fill(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_texture_rect_region(atlas(), rect, SOLID, color)

static func box(canvas: CanvasItem, rect: Rect2, color: Color, rim: Color = Color.TRANSPARENT, small: bool = false) -> void:
	var corner = SMALL_CORNER if small else BOX_CORNER
	slice(canvas, rect, SMALL if small else BOX, corner, color, 1.0 if small else 0.8)
	if rim.a > 0.0:
		slice(canvas, rect, SMALL_RIM if small else BOX_RIM, corner, rim, 1.0 if small else 0.8)

static func plate(canvas: CanvasItem, rect: Rect2, color: Color = PANEL, rim: Color = PANEL_EDGE, lip: float = 5.0) -> void:
	# A panel: soft shadow, a darker lip under it, the face and its lit rim.
	slice(canvas, rect.grow(10).grow_side(SIDE_BOTTOM, lip), SHADOW, SHADOW_CORNER, Color(0.12, 0.15, 0.2, 0.16))
	if lip > 0.0:
		box(canvas, rect.grow_side(SIDE_BOTTOM, lip), LIP)
	box(canvas, rect, color, rim)

# --- controls -------------------------------------------------------------------------------
static func flat(color: Color, border: Color = Color.TRANSPARENT, radius: int = 18, lip: int = 0, lip_color: Color = LIP) -> StyleBoxFlat:
	var key = "%s|%s|%d|%d|%s" % [color, border, radius, lip, lip_color]
	if _styles.has(key):
		return _styles[key]
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border if lip == 0 else lip_color
	s.set_border_width_all(2 if border.a > 0.0 and lip == 0 else 0)
	if lip > 0:
		s.border_width_bottom = lip
		s.shadow_color = Color(0.04, 0.08, 0.16, 0.38)
		s.shadow_size = 3
		s.shadow_offset = Vector2(0, 3)
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12 + lip
	_styles[key] = s
	return s

static func panel_style(color: Color = PANEL, rim: Color = PANEL_EDGE, radius: int = 26) -> StyleBoxFlat:
	# A panel plate: lit rim and a solid dark lip under it, drawn as an offset shadow.
	var key = "panel|%s|%s|%d" % [color, rim, radius]
	if _styles.has(key):
		return _styles[key]
	var s: StyleBoxFlat = flat(color, rim, radius).duplicate()
	s.shadow_color = LIP
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 7)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 20
	_styles[key] = s
	return s

static var _keys: Dictionary = {}

static func key_styles(kind: String) -> Dictionary:
	# Clash Royale style 3D toy keys: vibrant saturated faces, thick extruded lips,
	# specular rim highlights and soft drop shadows that sink with physical weight when pressed.
	if _keys.has(kind):
		return _keys[kind]
	var face = Color("1c4475")
	var rim = Color("4085d4")
	var lip = Color("0c1c36")
	var lip_height = 6
	match kind:
		"primary":
			face = Color("ffcc00")
			rim = Color("fff085")
			lip = Color("9e4e00")
			lip_height = 8
		"toggle":
			face = Color("2cd58a")
			rim = Color("75f5bc")
			lip = Color("106e44")
			lip_height = 6
		"danger":
			face = Color("ff2a4b")
			rim = Color("ff7a90")
			lip = Color("8c1428")
			lip_height = 6

	var normal = StyleBoxFlat.new()
	normal.bg_color = face
	normal.border_color = rim
	normal.set_border_width_all(2)
	normal.border_width_bottom = lip_height
	normal.set_corner_radius_all(18)
	normal.corner_detail = 8
	normal.anti_aliasing = true
	normal.shadow_color = Color(0, 0, 0, 0.42)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12 + lip_height

	var hover = normal.duplicate()
	hover.bg_color = face.lightened(0.12)
	hover.border_color = rim.lightened(0.2)

	var pressed = normal.duplicate()
	pressed.bg_color = face.darkened(0.08)
	pressed.border_width_bottom = 2
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 2)
	pressed.expand_margin_top = -(lip_height - 2)
	pressed.content_margin_top = 12 + (lip_height - 2)
	pressed.content_margin_bottom = 14

	var disabled = normal.duplicate()
	disabled.bg_color = Color(CARD, 0.55)
	disabled.border_color = Color(LIP, 0.4)
	disabled.shadow_size = 0

	var focus = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(SUN, 0.85)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(20)
	focus.corner_detail = 8
	focus.anti_aliasing = true

	_keys[kind] = {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": pressed, "disabled": disabled, "focus": focus}
	return _keys[kind]

static func text_on(kind: String) -> Color:
	return INK if kind == "primary" or kind == "toggle" else WHITE

static func add_bounce(button: Button) -> void:
	if button == null or button.has_meta("has_bounce") or DisplayServer.get_name() == "headless":
		return
	button.set_meta("has_bounce", true)
	button.resized.connect(func():
		button.pivot_offset = button.size * 0.5
	)
	button.button_down.connect(func():
		button.pivot_offset = button.size * 0.5
		var tw = button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(button, "scale", Vector2(0.95, 0.95), 0.06)
	)
	button.button_up.connect(func():
		button.pivot_offset = button.size * 0.5
		var tw = button.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(button, "scale", Vector2.ONE, 0.28)
	)

static func paint_key(button: Button, kind: String) -> void:
	# Every override is a theme change, and a theme change sends the whole screen back
	# through layout: the HUD asked for the same colours 30 times a second and that alone
	# cost a phone more than the rest of the frame. Paint only when the kind changes.
	add_bounce(button)
	if button.get_meta("key_kind", "") == kind:
		return
	button.set_meta("key_kind", kind)
	var styles = key_styles(kind)
	for state in styles:
		button.add_theme_stylebox_override(state, styles[state])
	var ink = text_on(kind)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.7))

static func theme() -> Theme:
	# Everything that is a Control picks this up from the window: every Button, Label, list,
	# slider and field in the game shares the look without asking for it.
	if _theme != null:
		return _theme
	var t = Theme.new()
	t.default_font = body_font()
	t.default_font_size = 16
	for state in key_styles("secondary").keys():
		t.set_stylebox(state, "Button", key_styles("secondary")[state])
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", 20)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", WHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.7))
	t.set_color("font_color", "Label", WHITE)
	t.set_stylebox("panel", "PanelContainer", flat(PANEL, PANEL_EDGE, 26))
	t.set_stylebox("panel", "Panel", flat(PANEL, PANEL_EDGE, 26))
	var field = flat(FIELD, CARD_EDGE, 14)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", flat(FIELD, SUN, 14))
	t.set_color("font_color", "LineEdit", WHITE)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", SUN)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "OptionButton", flat(CARD if state != "hover" else CARD_HI, CARD_EDGE, 14) if state != "focus" else key_styles("secondary").focus)
	t.set_color("font_color", "OptionButton", WHITE)
	t.set_color("font_hover_color", "OptionButton", WHITE)
	t.set_color("font_pressed_color", "OptionButton", WHITE)
	t.set_font("font", "OptionButton", strong_font())
	t.set_font_size("font_size", "OptionButton", 15)
	t.set_stylebox("panel", "PopupMenu", flat(PANEL, CARD_EDGE, 14))
	t.set_stylebox("hover", "PopupMenu", flat(CARD_HI, Color.TRANSPARENT, 10))
	t.set_color("font_color", "PopupMenu", WHITE)
	t.set_color("font_hover_color", "PopupMenu", SUN)
	t.set_font("font", "PopupMenu", strong_font())
	t.set_font_size("font_size", "PopupMenu", 16)
	var track = flat(FIELD, Color.TRANSPARENT, 8)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", flat(SUN, Color.TRANSPARENT, 8))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(SUN.lightened(0.1), Color.TRANSPARENT, 8))
	# Slim scroll bars: flat() carries 18 px of padding, which made them as wide as a thumb
	# and pushed over the controls beside them.
	for bar in ["VScrollBar", "HScrollBar"]:
		for part in [["scroll", Color(FIELD, 0.6)], ["grabber", CARD_EDGE], ["grabber_highlight", MUTED], ["grabber_pressed", SUN]]:
			var slim = StyleBoxFlat.new()
			slim.bg_color = part[1]
			slim.set_corner_radius_all(4)
			slim.set_content_margin_all(3)
			t.set_stylebox(part[0], bar, slim)
	t.set_stylebox("panel", "TooltipPanel", flat(PANEL, CARD_EDGE, 10))
	t.set_color("font_color", "TooltipLabel", WHITE)
	t.set_color("font_color", "CheckButton", WHITE)
	t.set_color("font_hover_color", "CheckButton", WHITE)
	t.set_color("font_pressed_color", "CheckButton", WHITE)
	t.set_font("font", "CheckButton", strong_font())
	_theme = t
	return t
