extends RefCounted
## The game's art direction. "" is the shipped look (bright studio, pastel paint, cartoon
## faces). The other names are looks under trial, picked only by tests/capture_style.gd until
## one is chosen: every place that draws differently asks this script.
##   "militar": worn military mecha: matte olive and sand paint with chipped edges and dust,
##   bare gunmetal, visor slits, a hard low sun and a dusty, desaturated grade.
static var current := ""

static func militar() -> bool:
	return current == "militar"

const OLIVE = Color("5d5f45")
const KHAKI = Color("8a7f63")

static func field(c: Color) -> Color:
	# A colour as field paint: its hue kept, the candy taken out, a share of olive drab.
	var paint = Color.from_hsv(c.h, clampf(c.s * 0.5, 0.06, 0.38), clampf(0.3 + c.v * 0.35, 0.34, 0.66))
	# Pale and grey paint (BIT's cream, FAÍSCA's white) turns olive drab; strong colours keep
	# most of their hue.
	return paint.lerp(OLIVE.lightened(0.15), 0.25 + 0.35 * (1.0 - clampf(c.s * 3.0, 0.0, 1.0)))

static func robot(out: Dictionary, team: Color) -> void:
	# A robot's roles in the military look. The team colour stays strong: it is how the two
	# sides tell each other apart.
	var trim_is_team = Color(out.trim) == team
	var unit = Color.from_hsv(team.h, team.s * 0.85, team.v * 0.72)
	for role in ["trim", "glow", "eyes", "team"]:
		if Color(out[role]) == team:
			out[role] = unit
	out.shell = field(out.shell)
	if not trim_is_team:
		out.trim = field(out.trim).lightened(0.12)
	out.dark = Color(out.dark).lerp(Color("3a3c35"), 0.7)
	out.metal = Color("5e605f")
	out.rubber = Color("141512")
	out.hazard = Color("c7901c")
	out.label = Color("bdb49a")

static func world(theme: Dictionary) -> Dictionary:
	# A world's colours in the dusty grade, and the court as worn concrete with painted lines.
	var out = {}
	for key in theme:
		out[key] = _dusty(theme[key])
	out.floor = Color("615e58")
	out.floor_alt = Color("5a5752")
	out.seam = Color("3a3833")
	out.line = Color("c9a227")
	out.sky_top = Color("6f808e")
	out.sky_mid = Color("a3a8a3")
	out.sky_low = Color("d3c9b2")
	out.fog = {"color": Color("8f8775"), "begin": 60.0, "end": 220.0, "density": 0.5}
	return out

static func _dusty(value):
	if value is Color:
		return Color.from_hsv(value.h, value.s * 0.5, value.v * 0.82, value.a).lerp(KHAKI, 0.15)
	if value is Array:
		var list = []
		for item in value:
			list.append(_dusty(item))
		return list
	return value
