extends RefCounted
## The interface's look: its palette, its type and the shapes every panel, key and badge is
## cut from. Panels read like the robots' own shells — deep indigo plates with a lit rim and
## a chunky lip under them, so each key looks like a toy button you could press in.
##
## Shapes are drawn from one small generated atlas (`atlas()`), so a whole screen of discs,
## rings and rounded boxes lands in a single batch instead of one draw call per shape.
const TITLE_FILE = preload("res://art/fonts/LilitaOne-Regular.ttf")
const BODY_FILE = preload("res://art/fonts/Rubik-Variable.ttf")

# Night indigo for the plates, one warm sun for the action that matters, the teams' own
# colours for everything that belongs to a side.
const NIGHT = Color("0c0d22")
const PANEL = Color("1a1c42")
const PANEL_EDGE = Color("3d4292")
const CARD = Color("23285c")
const CARD_HI = Color("2f367a")
const CARD_EDGE = Color("4a52ad")
const FIELD = Color("12143a")
const LIP = Color("0a0b20")
const EMPTY = Color("2c3066")
const INK = Color("1b1433")
const WHITE = Color("fff7ea")
const MUTED = Color("a6abd9")
const SUN = Color("ffd23f")
const SUN_LIP = Color("d7731d")
const MINT = Color("4fe3c9")
const MINT_LIP = Color("1d8e86")
const GOLD = Color("ffc44d")
const DANGER = Color("ff5d6c")
const CYAN = Color("72ddc6")
const CORAL = Color("ef947e")

# Where each shape sits in the atlas.
const DISC = Rect2(0, 0, 128, 128)
const RING = Rect2(128, 0, 128, 128)
const BOX = Rect2(0, 128, 64, 64)
const BOX_RIM = Rect2(64, 128, 64, 64)
const SMALL = Rect2(128, 128, 24, 24)
const SMALL_RIM = Rect2(152, 128, 24, 24)
const SHADOW = Rect2(176, 128, 64, 64)
const SOLID = Rect2(242, 130, 4, 4)
const BOX_CORNER = 22.0
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
	slice(canvas, rect.grow(10).grow_side(SIDE_BOTTOM, lip), SHADOW, SHADOW_CORNER, Color(0, 0, 0, 0.35))
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
	# A toy key: a face on a thick lip that sinks when it is pressed. `kind` is "primary"
	# (the sun: one per screen), "toggle" (a chosen option) or "secondary". Built once per
	# kind: fresh boxes on every call made each repaint count as a theme change.
	if _keys.has(kind):
		return _keys[kind]
	var face = CARD
	var lip = LIP
	match kind:
		"primary":
			face = SUN
			lip = SUN_LIP
		"toggle":
			face = MINT
			lip = MINT_LIP
		"danger":
			face = DANGER
			lip = Color("9c2440")
	var normal = flat(face, Color.TRANSPARENT, 18, 6, lip)
	var hover = flat(face.lightened(0.08), Color.TRANSPARENT, 18, 6, lip)
	var pressed: StyleBoxFlat = flat(face.darkened(0.08), Color.TRANSPARENT, 18, 2, lip).duplicate()
	pressed.expand_margin_top = -4
	pressed.content_margin_top = 16
	var disabled = flat(Color(CARD, 0.55), Color.TRANSPARENT, 18, 6, Color(LIP, 0.6))
	var focus = flat(Color.TRANSPARENT, Color(SUN, 0.8), 20)
	focus.set_border_width_all(3)
	focus.draw_center = false
	_keys[kind] = {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": pressed, "disabled": disabled, "focus": focus}
	return _keys[kind]

static func text_on(kind: String) -> Color:
	return INK if kind == "primary" or kind == "toggle" else WHITE

static func paint_key(button: Button, kind: String) -> void:
	# Every override is a theme change, and a theme change sends the whole screen back
	# through layout: the HUD asked for the same colours 30 times a second and that alone
	# cost a phone more than the rest of the frame. Paint only when the kind changes.
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
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, flat(Color(FIELD, 0.6), Color.TRANSPARENT, 6))
		t.set_stylebox("grabber", bar, flat(CARD_EDGE, Color.TRANSPARENT, 6))
		t.set_stylebox("grabber_highlight", bar, flat(MUTED, Color.TRANSPARENT, 6))
		t.set_stylebox("grabber_pressed", bar, flat(SUN, Color.TRANSPARENT, 6))
	t.set_stylebox("panel", "TooltipPanel", flat(PANEL, CARD_EDGE, 10))
	t.set_color("font_color", "TooltipLabel", WHITE)
	t.set_color("font_color", "CheckButton", WHITE)
	t.set_color("font_hover_color", "CheckButton", WHITE)
	t.set_color("font_pressed_color", "CheckButton", WHITE)
	t.set_font("font", "CheckButton", strong_font())
	_theme = t
	return t
