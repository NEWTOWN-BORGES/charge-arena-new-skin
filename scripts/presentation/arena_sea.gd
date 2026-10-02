extends RefCounted
## Base Submarina: the arena on a lit steel deck on the seabed. Reef shelves step up round
## three sides, sand on top and turquoise rock below; kelp, coral and bubble streams grow on
## them; habitat domes with their tunnels, a yellow submarine hovering over the far shelf,
## pipes, sonar, floodlights, an anchor and sunken cargo make the base. Blue-green water haze
## does the rest. Kit parts and flat slabs only: static, opaque and merged by material.
const Rules = preload("res://scripts/gameplay/arena_rules.gd")
const ArenaSky = preload("res://scripts/presentation/arena_sky.gd")
const Ground = preload("res://scripts/presentation/arena_ground.gd")

const WHITE = Color("f4f8fa")
const YELLOW = Color("ffd23f")
const CORALS = [[Color("ff6f91"), Color("ffc2d1")], [Color("ff9f43"), Color("ffd9a6")], [Color("a56eff"), Color("dcc4ff")], [Color("ff5c7a"), Color("ffe08a")]]
const KELP = [[Color("3fcf8e"), Color("2fae74"), Color("ffd23f")], [Color("62d65a"), Color("3fb34a"), Color("ff9f43")], [Color("2fc4a5"), Color("249f86"), Color("ff6f91")]]

static func build(view, theme: Dictionary) -> void:
	var walls: Array = view.walls
	var hull = ArenaSky.hull_of(walls)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(String(view.map.get("id", "oceano")))
	var reach = ArenaSky.reach_of(hull)
	var far = Rules.HALF_LENGTH
	# Sand, then the deck: teal working area, hazard border and a lit rim.
	view.platform(ArenaSky.circle(90.0, 24), Ground.FLOOR, 0.5, theme.sand)
	view.platform(ArenaSky.offset(hull, 2.6), -0.03, 0.4, theme.deck)
	view.platform(ArenaSky.offset(hull, 1.8), -0.026, 0.02, theme.deck_panel)
	view.platform(ArenaSky.offset(hull, 1.0), -0.022, 0.02, theme.deck)
	ArenaSky.hazard_band(view, ArenaSky.offset(hull, 2.2), -0.02)
	var rim = ArenaSky.offset(hull, 2.62)
	for i in range(rim.size()):
		var a: Vector2 = rim[i]
		var b: Vector2 = rim[(i + 1) % rim.size()]
		view.segment(view, Vector3(a.x, -0.2, a.y), Vector3(b.x, -0.2, b.y), 0.05, 0.05, ArenaSky.LIGHT, true)
	ArenaSky.walls_and_towers(view, walls)
	# Reef shelves.
	var tiers: Array = []
	var below = Ground.FLOOR
	for spec in [[reach + 6.0, far + 5.2, 0.8, theme.sand_high], [reach + 12.5, far + 11.5, 2.2, theme.sand], [reach + 20.0, far + 19.0, 3.8, theme.sand_high]]:
		var outline = Ground.valley(rng, spec[0], spec[1])
		ArenaSky.slab(view, outline, spec[2], below - 0.05, spec[3], theme.shelf, 0.14)
		tiers.append([outline, spec[2]])
		below = spec[2]
	var taken = base(view, tiers, reach, far)
	taken.append_array(pressure_stations(view, tiers, reach))
	reef(view, rng, tiers, hull, reach, far, taken)

static func base(view, tiers: Array, reach: float, far: float) -> Array:
	var dark = ArenaSky.GRAPHITE
	var steel = ArenaSky.STEEL
	var dome_paint = {"shell": WHITE, "trim": YELLOW, "dark": dark, "metal": steel, "glow": ArenaSky.LIGHT}
	# Two habitats on the shelves, their tunnels running along them, with pipes and sonar.
	Ground.put(view, "env_habitat", Vector2(-(reach * 0.55 + 2.6), -(far + 8.0)), tiers, Vector3.BACK, dome_paint, 1.3)
	Ground.put(view, "env_habitat", Vector2(reach + 8.8, -1.5), tiers, Vector3.RIGHT, dome_paint, 1.1)
	Ground.put(view, "env_pipes", Vector2(0.4, -(far + 6.9)), tiers, Vector3.FORWARD, {"shell": WHITE, "trim": YELLOW, "dark": dark, "metal": steel, "hazard": ArenaSky.HAZARD})
	Ground.put(view, "env_sonar", Vector2(reach * 0.5 + 3.2, -(far + 9.4)), tiers, Vector3.FORWARD, {"dark": dark, "metal": steel, "shell": WHITE, "glow": ArenaSky.LIGHT})
	Ground.put(view, "env_sonar", Vector2(-(reach + 9.2), 3.0), tiers, Vector3.FORWARD, {"dark": dark, "metal": steel, "shell": WHITE, "glow": ArenaSky.LIGHT})
	# The submarine hangs over the far shelf, side on to the camera.
	var sub_at = Vector2(reach * 0.35 + 0.6, -(far + 7.9))
	var hover = ArenaSky.facing(Vector3(sub_at.x, Ground.height_at(sub_at, tiers) + 1.3, sub_at.y), Vector3.RIGHT)
	hover.basis = hover.basis.scaled(Vector3.ONE * 1.15)
	ArenaSky.place(view, "env_submarine", hover, {"shell": YELLOW, "trim": Color("ff9f43"), "glow": Color("bff6ff"), "metal": steel, "dark": dark})
	# Floodlights at the corners of the deck, an anchor and sunken cargo on the sand.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var q = Vector2(sx * (reach + 3.1), sz * (far - 1.2))
			Ground.put(view, "env_lamp", q, tiers, Vector3(q.x, 0, q.y), {"dark": dark, "metal": steel, "shell": WHITE, "glow": Color("dffcff")})
	Ground.put(view, "env_anchor", Vector2(reach + 3.9, -(far + 3.6)), tiers, Vector3(1, 0, 0.4), {"dark": Color("5d6b78"), "metal": Color("8d99a6")})
	var side_x = reach + 2.2
	ArenaSky.place(view, "prop_crates", ArenaSky.facing(Vector3(-side_x - 0.2, -0.03, -2.4), Vector3.RIGHT), {"shell": YELLOW, "trim": Color("2fa6e0"), "dark": dark})
	ArenaSky.place(view, "prop_barrels", ArenaSky.facing(Vector3(side_x + 0.1, -0.03, 2.8), Vector3.LEFT), {"shell": Color("ff5c4d"), "trim": WHITE, "dark": dark, "metal": steel})
	Ground.put(view, "prop_scrap_b", Vector2(-(reach + 4.2), -(far + 3.4)), tiers, Vector3.BACK, {"shell": Color("9fb8c4"), "trim": Color("c9794a"), "label": Color("7f97a3"), "dark": dark, "metal": steel, "rubber": ArenaSky.RUBBER, "glow": ArenaSky.LIGHT})
	return [Vector2(-(reach * 0.55 + 2.6), -(far + 8.0)), Vector2(-(reach * 0.55 + 0.6), -(far + 8.0)), Vector2(reach + 8.8, -1.5), Vector2(reach + 8.8, -3.5),
		Vector2(0.4, -(far + 6.9)), Vector2(reach * 0.5 + 3.2, -(far + 9.4)), Vector2(-(reach + 9.2), 3.0), sub_at, sub_at + Vector2(1.6, 0), sub_at - Vector2(1.6, 0),
		Vector2(reach + 3.9, -(far + 3.6)), Vector2(-(reach + 4.2), -(far + 3.4))]

static func pressure_stations(view, tiers: Array, reach: float) -> Array:
	# Compact pressure machinery frames the close view; the lenses are solid painted
	# geometry, not transparent glass or real lights. Twelve-sided rings stay light on mobile.
	var occupied: Array = []
	var shell = ArenaSky.scenery_color(view.theme, "shell", WHITE)
	var dark = ArenaSky.scenery_color(view.theme, "dark", ArenaSky.GRAPHITE)
	var steel = ArenaSky.scenery_color(view.theme, "metal", ArenaSky.STEEL)
	var accent = ArenaSky.scenery_color(view.theme, "accent", YELLOW)
	var signal_color = ArenaSky.scenery_color(view.theme, "signal", Color("249f86"))
	for side in [-1, 1]:
		var q = Vector2(side * (reach + 3.9), -side * 6.2)
		if not Ground.flat_at(q, tiers, 1.0):
			continue
		occupied.append_array([q, q + Vector2(0, 0.9), q - Vector2(0, 0.9)])
		var station = Node3D.new()
		station.name = "ReefPressureStation%d" % side
		station.transform = ArenaSky.facing(Vector3(q.x, Ground.height_at(q, tiers), q.y), Vector3(-side, 0, 0))
		view.add_child(station)
		view.box(station, Vector3(0, 0.16, 0), Vector3(1.88, 0.32, 1.2), dark, false, 0.1)
		view.box(station, Vector3(0, 0.9, -0.07), Vector3(1.56, 1.5, 0.86), shell, false, 0.16)
		view.box(station, Vector3(0, 1.71, -0.07), Vector3(1.9, 0.23, 1.05), accent, false, 0.08)
		# Concentric bevels around a deep teal pressure window, with a broad highlight.
		for spec in [[0.67, 0.22, 0.42, steel], [0.56, 0.23, 0.46, accent], [0.45, 0.24, 0.5, dark], [0.37, 0.25, 0.515, signal_color]]:
			var port = view.cylinder(station, Vector3(0, 0.98, spec[2]), spec[0], spec[1], spec[3], false, 12)
			port.rotation.x = PI * 0.5
		view.box(station, Vector3(-0.1, 1.15, 0.655), Vector3(0.36, 0.07, 0.025), shell, false, 0.02)
		for x in [-0.83, 0.83]:
			view.cylinder(station, Vector3(x, 0.77, -0.04), 0.12, 1.28, steel, false, 8)
			view.cylinder(station, Vector3(x, 1.15, -0.04), 0.16, 0.18, accent, false, 8)
			view.box(station, Vector3(x * 0.63, 0.28, 0.66), Vector3(0.29, 0.13, 0.14), accent, false, 0.02)
		for x in [-0.48, 0.0, 0.48]:
			view.box(station, Vector3(x, 1.845, -0.07), Vector3(0.22, 0.03, 0.64), dark, false, 0.0)
	return occupied

static func reef_gardens(view, tiers: Array, reach: float) -> Array:
	# Curated coral silhouettes at two near corners replace a few scattered specimens.
	# There are no new mesh assets or material variants, just an intentional composition.
	var occupied: Array = []
	for side in [-1, 1]:
		var center = Vector2(side * (reach + 4.15), side * 6.2)
		if not Ground.flat_at(center, tiers, 1.1):
			continue
		occupied.append_array([center, center + Vector2(0, 1.1), center - Vector2(0, 1.1)])
		for i in range(2):
			var q = center + Vector2(side * 0.35, (i - 0.5) * 1.1)
			Ground.put(view, "env_rock_%d" % i, q, tiers, Vector3(side, 0, 0.3), {"shell": Color("5f7d99"), "trim": Color("a9c4d6")}, 1.1 + 0.2 * i)
		for i in range(3):
			var q = center + Vector2(-side * 0.4, (i - 1) * 0.95)
			var tone = CORALS[0 if side < 0 else 1]
			var key = "env_coral_fan_0" if i == 1 else "env_coral_tubes_0"
			Ground.put(view, key, q, tiers, Vector3(-side, 0, 0.4), {"shell": tone[0], "trim": tone[1].darkened(0.1), "label": tone[1]}, 1.9 if i == 1 else 1.15)
	return occupied

static func reef(view, rng: RandomNumberGenerator, tiers: Array, hull: Array, reach: float, far: float, taken: Array) -> void:
	var gardens = reef_gardens(view, tiers, reach)
	taken.append_array(gardens)
	var garden_count = int(gardens.size() / 3)
	var deck = ArenaSky.offset(hull, 2.9)
	var sample = func(r: RandomNumberGenerator):
		var q = Vector2(r.randf_range(-(reach + 26.0), reach + 26.0), r.randf_range(-(far + 24.0), far + 9.0))
		if Geometry2D.is_point_in_polygon(q, PackedVector2Array(deck)):
			return null
		if not Ground.flat_at(q, tiers, 0.7):
			return null
		return q
	# Kelp in tall clumps, coral heads and fans, then bubble streams and a few boulders.
	var kelp = ArenaSky.spots(rng, ArenaSky.rich(view, 56), sample, 1.25, taken)
	for q in kelp:
		var tone = KELP[rng.randi() % KELP.size()]
		var turn = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.3, 2.2))
		ArenaSky.place(view, "env_kelp_%d" % (rng.randi() % 2), Transform3D(turn, Vector3(q.x, Ground.height_at(q, tiers), q.y)), {"shell": tone[0], "trim": tone[1], "label": tone[2]})
	taken = taken + kelp
	var corals = ArenaSky.spots(rng, ArenaSky.rich(view, 50) - garden_count * 3, sample, 1.35, taken)
	for q in corals:
		var tone = CORALS[rng.randi() % CORALS.size()]
		var kind = "env_coral_tubes_%d" % (rng.randi() % 2) if rng.randf() < 0.55 else "env_coral_fan_%d" % (rng.randi() % 2)
		var turn = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.3, 2.2))
		ArenaSky.place(view, kind, Transform3D(turn, Vector3(q.x, Ground.height_at(q, tiers), q.y)), {"shell": tone[0], "trim": tone[1].darkened(0.1), "label": tone[1]})
	taken = taken + corals
	for q in ArenaSky.spots(rng, ArenaSky.rich(view, 12), sample, 2.0, taken):
		var turn = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6))
		ArenaSky.place(view, "env_bubbles_%d" % (rng.randi() % 2), Transform3D(turn, Vector3(q.x, Ground.height_at(q, tiers), q.y)), {"label": Color("e6fbff")})
		taken.append(q)
	for q in ArenaSky.spots(rng, ArenaSky.rich(view, 16) - garden_count * 2, sample, 2.0, taken):
		var turn = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5))
		ArenaSky.place(view, "env_rock_%d" % (rng.randi() % 3), Transform3D(turn, Vector3(q.x, Ground.height_at(q, tiers) - 0.05, q.y)), {"shell": Color("5f7d99"), "trim": Color("a9c4d6")})
	# Schools of fish in the open water round the deck, never over the field.
	var schools = [[Color("ffd23f"), Color("2f7fd0"), Color("ff9f43")], [Color("ff7a5c"), Color("ffffff"), Color("ffd23f")], [Color("7fe6ff"), Color("2f5fd0"), Color("ffffff")], [Color("b48cff"), Color("ffd23f"), Color("ff6f91")]]
	for spot in [Vector3(-(reach + 3.8), 2.4, -2.0), Vector3(reach + 4.2, 2.8, 3.5), Vector3(-2.5, 3.0, -(far + 5.0)), Vector3(reach * 0.6 + 2.0, 3.6, -(far + 11.0)), Vector3(-(reach + 9.0), 4.2, -(far + 3.0)), Vector3(reach + 10.0, 4.8, -8.0)]:
		var tone = schools[rng.randi() % schools.size()]
		var swim = ArenaSky.facing(spot, Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
		swim.basis = swim.basis.scaled(Vector3.ONE * rng.randf_range(1.1, 1.5))
		ArenaSky.place(view, "env_school_%d" % (rng.randi() % 2), swim, {"shell": tone[0], "label": tone[1], "trim": tone[2], "dark": Color("1d2430")})
