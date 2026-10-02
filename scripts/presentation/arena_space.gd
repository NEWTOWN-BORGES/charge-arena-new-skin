extends RefCounted
## Estação Orbital: the arena on the deck of a space station. A white deck with an indigo
## working area and a lit rim over a stepped hull; a truss spine behind the far goal carries
## the solar wings and two modules; side arms hold a landing pad with a shuttle and a big
## dish; satellites and asteroids drift below, and a ringed planet fills the far distance
## against the starfield. Kit parts and flat slabs only: static, opaque and merged by material.
const Rules = preload("res://scripts/gameplay/arena_rules.gd")
const ArenaSky = preload("res://scripts/presentation/arena_sky.gd")

const WHITE = Color("f4f5fa")
const ORANGE = Color("ff8a3d")
const CYAN = Color("7fe6ff")
const CELLS = Color("3558e0")
const SPINE_Y = -0.5

static func build(view, theme: Dictionary) -> void:
	var walls: Array = view.walls
	var hull = ArenaSky.hull_of(walls)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(String(view.map.get("id", "orbita")))
	var reach = ArenaSky.reach_of(hull)
	var far = Rules.HALF_LENGTH
	# The deck, its dark lip, the indigo working area; the stepped hull underneath.
	# Rings, not slabs: the field is glass (arena_theme "glass_floor") and the stars show
	# through it, so nothing may sit underneath.
	var rim_in = ArenaSky.offset(hull, 0.02)
	ArenaSky.ring(view, rim_in, ArenaSky.offset(hull, 3.4), -0.03, 0.3, theme.deck)
	ArenaSky.ring(view, ArenaSky.offset(hull, 3.0), ArenaSky.offset(hull, 3.5), -0.33, 0.22, ArenaSky.GRAPHITE)
	ArenaSky.ring(view, ArenaSky.offset(hull, 1.0), ArenaSky.offset(hull, 2.6), -0.026, 0.02, theme.deck_panel)
	ArenaSky.ring(view, ArenaSky.offset(hull, 1.2), ArenaSky.offset(hull, 3.0), -0.55, 0.75, theme.hull)
	ArenaSky.ring(view, ArenaSky.offset(hull, 1.4), ArenaSky.offset(hull, 2.0), -1.3, 0.8, ArenaSky.GRAPHITE.lightened(0.15))
	var rim = ArenaSky.offset(hull, 3.5)
	for i in range(rim.size()):
		var a: Vector2 = rim[i]
		var b: Vector2 = rim[(i + 1) % rim.size()]
		view.segment(view, Vector3(a.x, -0.44, a.y), Vector3(b.x, -0.44, b.y), 0.05, 0.04, CYAN, true)
	ArenaSky.hazard_band(view, ArenaSky.offset(hull, 3.1), -0.02)
	ArenaSky.walls_and_towers(view, walls, {"glow": CYAN})
	dock_architecture(view, hull)
	station(view, theme, reach, far)
	drifting(view, rng, reach, far)

static func dock_architecture(view, hull: Array) -> void:
	# Exterior docking collars give the station an engineered silhouette at match-camera
	# distance. No structure sits underneath the transparent playing field.
	var shell = ArenaSky.scenery_color(view.theme, "shell", WHITE)
	var accent = ArenaSky.scenery_color(view.theme, "accent", ORANGE)
	var metal = ArenaSky.scenery_color(view.theme, "metal", ArenaSky.STEEL)
	var dark = ArenaSky.scenery_color(view.theme, "dark", ArenaSky.GRAPHITE)
	var signal_color = ArenaSky.scenery_color(view.theme, "signal", CYAN)
	var perimeter = ArenaSky.offset(hull, 2.8)
	var docks = 0
	for i in range(perimeter.size()):
		var a: Vector2 = perimeter[i]
		var b: Vector2 = perimeter[(i + 1) % perimeter.size()]
		var q = a.lerp(b, 0.5)
		if absf(q.x) < 3.2 or a.distance_to(b) < 3.5:
			continue
		if docks >= 6:
			break
		var tangent = (b - a).normalized()
		var dock = Node3D.new()
		dock.name = "DockingCollar%d" % docks
		dock.transform = ArenaSky.along(Vector3(q.x, 0, q.y), Vector3(tangent.x, 0, tangent.y))
		view.add_child(dock)
		# Chunky housing, contrasting armor cap, recessed vents and a cyan status slot.
		# Colours are shared with the existing modules; geometry is merged at build time.
		view.box(dock, Vector3(0, 0.30, 0), Vector3(2.28, 0.56, 0.76), dark, false, 0.09)
		view.box(dock, Vector3(0, 0.66, 0), Vector3(1.82, 0.23, 0.96), shell, false, 0.08)
		view.box(dock, Vector3(0, 0.81, 0), Vector3(1.06, 0.12, 0.63), accent, false, 0.04)
		view.box(dock, Vector3(0, 0.39, -0.395), Vector3(1.35, 0.10, 0.035), signal_color, true, 0.0)
		for side in [-1, 1]:
			view.box(dock, Vector3(side * 0.93, 0.12, 0), Vector3(0.20, 0.70, 1.02), shell, false, 0.045)
			view.box(dock, Vector3(side * 0.94, 0.52, 0), Vector3(0.23, 0.10, 1.05), accent, false, 0.02)
			# Structural outriggers drop below the rim instead of intruding on the field.
			view.box(dock, Vector3(side * 0.94, -0.61, 0), Vector3(0.17, 0.74, 0.42), metal, false, 0.025)
		if int(view.quality_level) > 0:
			for x in [-0.48, -0.24, 0.0, 0.24, 0.48]:
				view.box(dock, Vector3(x, 0.58, 0.41), Vector3(0.075, 0.27, 0.27), metal, false, 0.0)
		docks += 1

static func station(view, theme: Dictionary, reach: float, far: float) -> void:
	var dark = ArenaSky.GRAPHITE
	var steel = ArenaSky.STEEL
	var truss = {"dark": dark, "metal": steel}
	var wing = {"dark": dark, "label": CELLS, "metal": Color("cdd6e0")}
	var module = {"shell": WHITE, "trim": ORANGE, "glow": CYAN, "metal": steel, "dark": dark}
	# The spine behind the far goal, tucked under the deck lip, with solar wings reaching
	# away from the arena and a module at each end.
	var spine_z = -(far + 3.6)
	var half = reach + 11.0
	var pieces = int(ceil(half * 2.0 / 4.0))
	for k in range(pieces):
		var x = -half + (k + 0.5) * half * 2.0 / pieces
		ArenaSky.place(view, "env_truss", ArenaSky.along(Vector3(x, SPINE_Y, spine_z), Vector3.RIGHT), truss)
	for x in [-(reach + 8.0), -(reach + 1.2), -1.6, 1.6, reach + 1.2, reach + 8.0]:
		ArenaSky.place(view, "env_solar_wing", ArenaSky.along(Vector3(x, SPINE_Y, spine_z - 0.4), Vector3.FORWARD), wing)
	for side in [-1, 1]:
		ArenaSky.place(view, "env_module", ArenaSky.along(Vector3(side * (half + 1.2), SPINE_Y - 0.8, spine_z), Vector3.RIGHT), module)
	# Side arms: a landing pad with a parked shuttle on the left, a big dish on the right.
	for side in [-1, 1]:
		ArenaSky.place(view, "env_truss", ArenaSky.along(Vector3(side * (reach + 4.4), SPINE_Y, -1.2), Vector3.RIGHT), truss)
		view.platform(ArenaSky.circle(2.3, 16, Vector2(side * (reach + 8.6), -1.2)), -0.2, 0.35, theme.hull)
		view.platform(ArenaSky.circle(2.4, 16, Vector2(side * (reach + 8.6), -1.2)), -0.5, 0.25, dark)
	var pad_x = -(reach + 8.6)
	ArenaSky.place(view, "prop_pad", Transform3D(Basis.IDENTITY, Vector3(pad_x, -0.2, -1.2)), {"dark": dark, "hazard": ArenaSky.HAZARD, "glow": CYAN})
	var parked = ArenaSky.facing(Vector3(pad_x, -0.2, -1.1), Vector3(0.3, 0, 1))
	parked.basis = parked.basis.scaled(Vector3.ONE * 1.25)
	ArenaSky.place(view, "env_shuttle", parked, {"shell": WHITE, "trim": ORANGE, "dark": dark, "glow": CYAN})
	var dish = ArenaSky.facing(Vector3(reach + 8.6, -0.2, -1.2), Vector3(-1, 0, -1))
	dish.basis = dish.basis.scaled(Vector3.ONE * 1.7)
	ArenaSky.place(view, "env_radar", dish, {"dark": dark, "metal": steel, "shell": WHITE, "glow": CYAN, "hazard": ArenaSky.HAZARD})
	# Antennas and floodlights on the deck corners, a satellite docked near the camera.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var q = Vector2(sx * (reach + 2.6), sz * (far + 0.9))
			ArenaSky.place(view, "env_lamp", ArenaSky.facing(Vector3(q.x, -0.03, q.y), Vector3(q.x, 0, q.y)), {"dark": dark, "metal": steel, "shell": WHITE, "glow": Color("e8fbff")})
	ArenaSky.place(view, "prop_antenna", Transform3D(Basis.IDENTITY, Vector3(reach + 2.3, -0.03, 2.6)), {"dark": dark, "glow": CYAN, "hazard": ArenaSky.HAZARD})
	ArenaSky.place(view, "prop_antenna", Transform3D(Basis.IDENTITY, Vector3(-(reach + 2.3), -0.03, 3.4)), {"dark": dark, "glow": CYAN, "hazard": ArenaSky.HAZARD})
	ArenaSky.place(view, "prop_crates", ArenaSky.facing(Vector3(reach + 2.3, -0.03, -3.2), Vector3.LEFT), {"shell": ORANGE, "trim": WHITE, "dark": dark})
	ArenaSky.place(view, "prop_barrels", ArenaSky.facing(Vector3(-(reach + 2.3), -0.03, 1.6), Vector3.RIGHT), {"shell": CYAN, "trim": ORANGE, "dark": dark, "metal": steel})

static func drifting(view, rng: RandomNumberGenerator, reach: float, far: float) -> void:
	# The ringed planet far below and ahead, satellites and a field of asteroids.
	var planet = Transform3D(Basis.from_euler(Vector3(0.1, 0.5, 0.25)).scaled(Vector3.ONE * 5.5), Vector3(reach + 9.0, -16.0, -(far + 58.0)))
	ArenaSky.place(view, "env_planet", planet, {"shell": Color("ff9d5c"), "trim": Color("ffd9a8"), "label": Color("e0663e")})
	for spot in [Vector3(-(reach + 13.0), -3.0, -(far + 12.0)), Vector3(reach + 15.0, -5.0, 5.0)]:
		var sat = ArenaSky.facing(spot, Vector3(rng.randf_range(-1, 1), 0, 1))
		sat.basis = sat.basis.scaled(Vector3.ONE * 1.3)
		ArenaSky.place(view, "env_satellite", sat, {"trim": WHITE, "label": CELLS, "shell": Color("e6e9f2"), "metal": ArenaSky.STEEL, "dark": ArenaSky.GRAPHITE})
	var placed: Array = []
	var tries = 0
	var rocks: int = ArenaSky.rich(view, 18)
	while placed.size() < rocks and tries < 2000:
		tries += 1
		var at = Vector3(rng.randf_range(-(reach + 30.0), reach + 30.0), rng.randf_range(-16.0, -3.0), rng.randf_range(-(far + 40.0), far + 6.0))
		# Well clear of the station and never between the camera and the field.
		if absf(at.x) < reach + 13.0 and at.z > -(far + 11.0) and at.y > -9.0:
			continue
		if absf(at.x) < reach + 4.0 and at.z > -far:
			continue
		# Never under the field: its floor is glass and a rock there would cover the stars.
		if absf(at.x) < reach + 7.0 and absf(at.z) < far + 8.0:
			continue
		var clear = true
		for other in placed:
			if at.distance_to(other) < 5.0:
				clear = false
				break
		if not clear:
			continue
		placed.append(at)
		var turn = Basis.from_euler(Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU))).scaled(Vector3.ONE * rng.randf_range(1.4, 3.6))
		ArenaSky.place(view, "env_rock_%d" % (rng.randi() % 3), Transform3D(turn, at), {"shell": Color("a9a3c2"), "trim": Color("d6d1ea")})
