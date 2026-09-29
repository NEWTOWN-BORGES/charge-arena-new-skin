extends RefCounted
## The game's art direction. "melhorado" is the shipped look: the robots and colours of the
## studio look with real shadows, a polished stone court, lit rounds and a Ghibli-painted
## nature (trees, clouds, sky and a wind-combed meadow). "" is the old plain studio look; the
## other names are looks that were tried (tests/capture_style.gd renders any of them).
##   "militar": worn military mecha: matte olive and sand paint with chipped edges and dust,
##   bare gunmetal, visor faces, a hard low sun and a dusty, desaturated grade.
##   "neon": dark sci-fi at night: black glossy armour with the trims burning in neon, a
##   cyan and magenta rim, a dark court ringed with neon tubes, glow and a violet night sky.
##   "premium": a pro sports broadcast: deep metallic car paint under a clear coat, carbon
##   fibre, chrome and team livery, a glossy court with crisp white lines under floodlights.
##   "adulto": stylized but grown-up, like the hero shooters: painted two-tone shading, bright
##   bevels and a lit rim, bone and slate armour with one strong accent, golden-hour light.
static var current := "melhorado"

const SHADERS = {
	"militar": preload("res://shaders/robot_paint_militar.gdshader"),
	"neon": preload("res://shaders/robot_paint_neon.gdshader"),
	"premium": preload("res://shaders/robot_paint_premium.gdshader"),
	"adulto": preload("res://shaders/robot_paint_adulto.gdshader"),
}

const LOOKS = {
	"militar": {
		"eyes": "visor", "shadows": true,
		"env": {"tonemap": Environment.TONE_MAPPER_ACES, "exposure": 1.15, "white": 6.0, "ambient": 0.7, "ambient_color": Color("a9a391"), "contrast": 1.18, "saturation": 0.78},
		"key": {"rotation": Vector3(-38, -40, 0), "color": Color("ffe0b0"), "energy": 1.35},
		"baked": {"lift": 0.8, "soften": 0.72, "tint": Color("a8a384")},
	},
	"neon": {
		"eyes": "visor", "shadows": false, "glow_trim": true,
		"env": {"tonemap": Environment.TONE_MAPPER_AGX, "exposure": 1.05, "contrast": 1.16, "saturation": 1.12, "glow": true, "glow_intensity": 0.8, "glow_bloom": 0.05, "glow_threshold": 0.85},
		"key": {"rotation": Vector3(-58, 35, 0)},
		"baked": {"lift": 0.5, "soften": 0.5, "tint": Color("4a4f86")},
		"court_gloss": 0.8,
	},
	"premium": {
		# The stadium by day: a high white sun with shadows, the shots still lighting the court.
		"eyes": "visor", "shadows": true, "lit_shots": true,
		"env": {"tonemap": Environment.TONE_MAPPER_AGX, "exposure": 1.08, "ambient": 0.6, "ambient_color": Color("b9c8e0"), "contrast": 1.12, "saturation": 1.1, "glow": true, "glow_intensity": 0.45, "glow_bloom": 0.03, "glow_threshold": 1.1},
		"key": {"rotation": Vector3(-58, -30, 0), "energy_scale": 0.45},
		"baked": {"lift": 1.4, "soften": 0.85, "tint": Color("ffffff")},
		"court_gloss": 0.7,
	},
	"premium_noite": {
		"eyes": "visor", "shadows": true, "lit_shots": true,
		"env": {"tonemap": Environment.TONE_MAPPER_AGX, "exposure": 1.12, "ambient": 0.42, "ambient_color": Color("7f93bb"), "contrast": 1.12, "saturation": 1.08, "glow": true, "glow_intensity": 0.45, "glow_bloom": 0.03, "glow_threshold": 1.1},
		"key": {"rotation": Vector3(-50, 30, 0)}, "floodlights": true,
		"baked": {"lift": 0.95, "soften": 0.85, "tint": Color("8f9bbd")},
		"court_gloss": 0.7,
	},
	"melhorado": {
		# The shipped look, improved: real shadows and the premium court, a polished dark
		# stone that mirrors the lights, everything else as it is.
		"shadows": true, "lit_shots": true, "day_sky": true, "key": {"energy_scale": 0.3}, "court_gloss": 0.7,
		"env": {"tonemap": Environment.TONE_MAPPER_AGX, "exposure": 1.12, "ambient": 0.5, "ambient_color": Color("c3c9cf"), "contrast": 1.12, "saturation": 1.18},
	},
	"sombras": {
		# The shipped look, only with real shadows: the sun casts the robots, the bricks and
		# the arena furniture onto the court.
		"shadows": true, "key": {"energy_scale": 0.33},
	},
	"adulto": {
		"eyes": "slant", "shadows": true,
		"env": {"tonemap": Environment.TONE_MAPPER_AGX, "exposure": 1.1, "ambient": 0.55, "ambient_color": Color("9fb3d9"), "contrast": 1.14, "saturation": 1.0},
		"key": {"rotation": Vector3(-26, -58, 0)},
		"baked": {"lift": 1.35, "soften": 0.72, "tint": Color("f3e3cc")},
	},
}

const OLIVE = Color("5d5f45")
const KHAKI = Color("8a7f63")

static func look() -> Dictionary:
	return LOOKS.get(current, {})

static func militar() -> bool:
	return current == "militar"

static func family() -> String:
	# The look a variant belongs to ("premium_noite" is the premium look at night).
	return current.trim_suffix("_noite")

static func lit_shots() -> bool:
	# Shots and powers carry real lights that fall on the court and the robots.
	return bool(look().get("lit_shots", false))

static func paint_shader() -> Shader:
	return SHADERS.get(family(), null)

static func eyes() -> String:
	return String(look().get("eyes", ""))

static func shadows() -> bool:
	return bool(look().get("shadows", false))

static func finish(role: String, value: float) -> float:
	# Neon: the trims are lights, not paint.
	if role == "trim" and bool(look().get("glow_trim", false)):
		return 1.0
	return value

static func environment(env: Environment) -> void:
	var grade: Dictionary = look().get("env", {})
	if grade.is_empty():
		return
	env.tonemap_mode = grade.tonemap
	env.tonemap_exposure = grade.exposure
	env.tonemap_white = grade.get("white", 1.0)
	if grade.has("ambient"):
		env.ambient_light_energy = grade.ambient
		env.ambient_light_color = grade.ambient_color
	env.adjustment_contrast = grade.contrast
	env.adjustment_saturation = grade.saturation
	if grade.get("glow", false):
		env.glow_enabled = true
		env.glow_intensity = grade.glow_intensity
		env.glow_bloom = grade.glow_bloom
		env.glow_hdr_threshold = grade.glow_threshold

static func key_light(light: DirectionalLight3D, quality: int = 2) -> void:
	if not look().has("key"):
		return
	# Real shadows cost a depth pass: a phone on Leve keeps the soft contact discs instead.
	var cast = shadows() and not (OS.has_feature("mobile") and quality == 0)
	var key: Dictionary = look().key
	if key.has("rotation"):
		light.rotation_degrees = key.rotation
	if key.has("color"):
		light.light_color = key.color
		light.light_energy = key.energy
	# A shadowed sun lights the Compatibility renderer several times stronger than a plain
	# one: its energy is scaled back so the look keeps the same brightness.
	if cast:
		light.light_energy *= float(key.get("energy_scale", 1.0))
	if cast:
		light.shadow_enabled = true
		light.shadow_blur = 0.6
		light.directional_shadow_max_distance = 60.0

static func floodlights(view) -> void:
	# Premium: four stadium masts beyond the corners of the court light the field; the world
	# around it stays in the evening dark.
	if not bool(look().get("floodlights", false)):
		return
	var half = Vector2.ZERO
	for p in view.walls:
		half = Vector2(maxf(half.x, absf(p.x)), maxf(half.y, absf(p.y)))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lamp = SpotLight3D.new()
			var at = Vector3(sx * (half.x + 3.0), 13.0, sz * (half.y + 2.0))
			var target = Vector3(sx * half.x * 0.15, 0.0, sz * half.y * 0.3)
			lamp.transform = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)
			lamp.light_color = Color("f4f7ff")
			lamp.light_energy = 6.0
			lamp.spot_range = 30.0
			lamp.spot_angle = 40.0
			lamp.spot_attenuation = 0.6
			view.add_child(lamp)

static func painted_nature() -> bool:
	# The Ghibli-painted meadow and grass tufts.
	return bool(look().get("day_sky", false))

static func day_sky(theme: Dictionary) -> bool:
	# Sun and cirrus in the sky: the improved look, on the open-air worlds by day.
	return bool(look().get("day_sky", false)) and not theme.has("neon") and not theme.get("night", false) and theme.get("stars", 0.0) == 0.0 and not theme.has("fog")

static func court(mat: ShaderMaterial) -> void:
	if look().has("court_gloss"):
		mat.set_shader_parameter("gloss", look().court_gloss)

static func baked(mat: ShaderMaterial) -> void:
	var grade: Dictionary = look().get("baked", {})
	for key in grade:
		mat.set_shader_parameter(key, grade[key])

static func field(c: Color) -> Color:
	# A colour as field paint: its hue kept, the candy taken out, a share of olive drab.
	var paint = Color.from_hsv(c.h, clampf(c.s * 0.5, 0.06, 0.38), clampf(0.3 + c.v * 0.35, 0.34, 0.66))
	# Pale and grey paint (BIT's cream, FAÍSCA's white) turns olive drab; strong colours keep
	# most of their hue.
	return paint.lerp(OLIVE.lightened(0.15), 0.25 + 0.35 * (1.0 - clampf(c.s * 3.0, 0.0, 1.0)))

static func robot(out: Dictionary, team: Color) -> void:
	# A robot's roles in the chosen look. The team colour always stays clear: it is how the
	# two sides tell each other apart.
	match family():
		"militar":
			_militar_robot(out, team)
		"neon":
			_neon_robot(out, team)
		"premium":
			_premium_robot(out, team)
		"adulto":
			_adulto_robot(out, team)

static func _team_roles(out: Dictionary, team: Color, unit: Color) -> Array:
	# The roles that follow the team colour, recoloured; returns them.
	var roles: Array = []
	for role in ["trim", "glow", "eyes", "team"]:
		if Color(out[role]) == team:
			out[role] = unit
			roles.append(role)
	return roles

static func _militar_robot(out: Dictionary, team: Color) -> void:
	var followed = _team_roles(out, team, Color.from_hsv(team.h, team.s * 0.85, team.v * 0.72))
	out.shell = field(out.shell)
	if not "trim" in followed:
		out.trim = field(out.trim).lightened(0.12)
	out.dark = Color(out.dark).lerp(Color("3a3c35"), 0.7)
	out.metal = Color("5e605f")
	out.rubber = Color("141512")
	out.hazard = Color("c7901c")
	out.label = Color("bdb49a")

static func _neon_robot(out: Dictionary, team: Color) -> void:
	# Black armour tinted by the robot's own colour; its trims and lights burn in neon.
	var unit = Color.from_hsv(team.h, 0.85, 1.0)
	var followed = _team_roles(out, team, unit)
	var shell: Color = out.shell
	out.shell = Color.from_hsv(shell.h, clampf(shell.s * 0.5, 0.04, 0.35), 0.1 + shell.v * 0.07)
	if not "trim" in followed:
		var trim: Color = out.trim
		out.trim = Color.from_hsv(trim.h, maxf(trim.s, 0.7), 1.0) if trim.s > 0.25 else unit
	out.glow = unit
	out.eyes = unit
	out.dark = Color("0b0c11")
	out.metal = Color("30333d")
	out.rubber = Color("07070a")
	out.hazard = Color("24262f")
	out.label = Color("16171e")

static func _premium_robot(out: Dictionary, team: Color) -> void:
	# Deep metallic paint (pearl white where the robot was pale), carbon fibre chassis, chrome,
	# the team colour as livery and white decals.
	var livery = Color.from_hsv(team.h, 0.9, 0.92)
	var followed = _team_roles(out, team, livery)
	out.shell = _car_paint(out.shell)
	if not "trim" in followed:
		out.trim = _car_paint(out.trim)
	out.dark = Color("141519")
	out.metal = Color("d6dbe2")
	out.rubber = Color("101113")
	out.hazard = Color("ffc81e")
	out.label = Color("f7f7f5")

static func _car_paint(c: Color) -> Color:
	if c.v < 0.45:
		return Color.from_hsv(c.h, c.s, 0.2)
	if c.s < 0.2:
		return Color("ecebe6")
	return Color.from_hsv(c.h, clampf(c.s * 1.15, 0.5, 0.92), clampf(c.v * 0.85, 0.35, 0.8))

static func _adulto_robot(out: Dictionary, team: Color) -> void:
	# Bone or slate armour, brass fittings, one strong accent: the team.
	var accent = Color.from_hsv(team.h, 0.8, 0.88)
	var followed = _team_roles(out, team, accent)
	out.shell = _hero_paint(out.shell)
	if not "trim" in followed:
		out.trim = _hero_paint(out.trim)
	out.dark = Color("2b2e36")
	out.metal = Color("c9a45c")
	out.rubber = Color("1c1d22")
	out.hazard = Color("ff8a2a")
	out.label = Color("f0ebe0")

static func _hero_paint(c: Color) -> Color:
	if c.s < 0.2 and c.v > 0.6:
		return Color("e3dccb")
	if c.v < 0.45:
		return Color.from_hsv(c.h, c.s * 0.6, 0.3)
	return Color.from_hsv(c.h, c.s * 0.75, clampf(c.v * 0.9, 0.45, 0.85))

static func world(theme: Dictionary) -> Dictionary:
	# A world's colours, court and light in the chosen look.
	var out = {}
	match current:
		"militar":
			for key in theme:
				out[key] = _graded(theme[key], func(c: Color): return Color.from_hsv(c.h, c.s * 0.5, c.v * 0.82, c.a).lerp(KHAKI, 0.15))
			out.merge({"floor": Color("615e58"), "floor_alt": Color("5a5752"), "seam": Color("3a3833"), "line": Color("c9a227"),
				"sky_top": Color("6f808e"), "sky_mid": Color("a3a8a3"), "sky_low": Color("d3c9b2"),
				"fog": {"color": Color("8f8775"), "begin": 60.0, "end": 220.0, "density": 0.5}}, true)
		"neon":
			for key in theme:
				out[key] = _graded(theme[key], func(c: Color): return Color.from_hsv(c.h, c.s * 0.6, c.v * 0.3, c.a))
			out.merge({"floor": Color("15161d"), "floor_alt": Color("121319"), "seam": Color("2c2f40"), "line": Color("3ff0ff"),
				"sky_top": Color("04040b"), "sky_mid": Color("140a2a"), "sky_low": Color("3a1452"), "stars": 0.5,
				"neon": Color("3ff0ff"), "neon_alt": Color("ff2a8a"),
				"key": Color("8fa8ff"), "key_energy": 0.55, "fill": Color("ff3fbf"), "fill_energy": 0.75,
				"ambient": Color("3a3060"), "ambient_energy": 0.6,
				"fog": {"color": Color("120a24"), "begin": 35.0, "end": 160.0}}, true)
		"premium":
			for key in theme:
				out[key] = theme[key]
			out.merge({"floor": Color("24324d"), "floor_alt": Color("21304a"), "seam": Color("3a4d70"), "line": Color("f4f6fa"),
				"sky_top": Color("2a7bd6"), "sky_mid": Color("78b6ee"), "sky_low": Color("e4f1fb"),
				"key": Color("fffaf0"), "key_energy": 1.3, "fill": Color("cfe0ff"), "fill_energy": 0.35}, true)
		"premium_noite":
			for key in theme:
				out[key] = _graded(theme[key], func(c: Color): return Color.from_hsv(c.h, c.s * 0.85, c.v * 0.72, c.a))
			out.merge({"floor": Color("1e2636"), "floor_alt": Color("1b2231"), "seam": Color("2c3850"), "line": Color("f4f6fa"),
				"sky_top": Color("0a1224"), "sky_mid": Color("22335a"), "sky_low": Color("7a8fb5"), "night": true,
				"key": Color("9fb4ff"), "key_energy": 0.4, "fill": Color("c9d8ff"), "fill_energy": 0.3,
				"fog": {"color": Color("1a2540"), "begin": 45.0, "end": 200.0, "density": 0.6}}, true)
		"adulto":
			for key in theme:
				out[key] = _graded(theme[key], func(c: Color): return Color.from_hsv(c.h, c.s * 0.8, c.v * 0.95, c.a).lerp(Color("f1d9b5"), 0.08))
			out.merge({"floor": Color("c9c2b4"), "floor_alt": Color("bfb8aa"), "seam": Color("7d766a"), "line": Color("ff7a2e"),
				"sky_top": Color("2f5d93"), "sky_mid": Color("9cb3cf"), "sky_low": Color("ffc98f"),
				"key": Color("ffc98f"), "key_energy": 1.6, "fill": Color("8fb0ff"), "fill_energy": 0.45}, true)
		"melhorado":
			out = theme.duplicate()
			out.merge({"floor": Color("24324d"), "floor_alt": Color("21304a"), "seam": Color("3a4d70"), "line": Color("f4f6fa")}, true)
		_:
			return theme
	return out

static func _graded(value, grade: Callable):
	if value is Color:
		return grade.call(value)
	if value is Array:
		var list = []
		for item in value:
			list.append(_graded(item, grade))
		return list
	return value
