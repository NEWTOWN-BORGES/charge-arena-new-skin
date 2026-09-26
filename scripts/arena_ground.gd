extends RefCounted
## Posto Terrestre: the arena on a concrete pad in a green valley. Sandstone terraces climb
## round three sides with the grass running over their edges; the valley floor has pines,
## rocks, a dirt track with a rover and floodlights; the terraces carry the outpost (a solar
## farm, silos and pipes, a hangar, a radar, power pylons) and, higher up, the wind turbines.
## Kit parts and flat slabs only: static, opaque and merged by material after the build.
const Rules = preload("res://scripts/arena_rules.gd")
const ArenaSky = preload("res://scripts/arena_sky.gd")

const WHITE = Color("f4f6f8")
const ORANGE = Color("ff7a3c")
const TEAL = Color("2fc4a5")
const SOLAR = Color("2d5bd6")
const FLOOR = -0.36

static func valley(rng: RandomNumberGenerator, half_width: float, far: float) -> Array:
	# The inside edge of a terrace: up both sides of the valley and round behind the far
	# goal, a little ragged, then closed through the open country outside.
	var edge: Array = [Vector2(half_width, 40.0)]
	for z in [20.0, 8.0, -2.0]:
		edge.append(Vector2(half_width + rng.randf_range(-0.9, 0.9), z))
	edge.append(Vector2(half_width - 1.6, -far + 2.2))
	for k in range(5):
		edge.append(Vector2(lerpf(half_width * 0.62, -half_width * 0.62, k / 4.0), -far + rng.randf_range(-1.1, 1.1)))
	edge.append(Vector2(-half_width + 1.6, -far + 2.2))
	for z in [-2.0, 8.0, 20.0]:
		edge.append(Vector2(-half_width + rng.randf_range(-0.9, 0.9), z))
	edge.append(Vector2(-half_width, 40.0))
	edge.append_array([Vector2(-120, 40), Vector2(-120, -120), Vector2(120, -120), Vector2(120, 40)])
	return edge

static func height_at(q: Vector2, tiers: Array) -> float:
	for k in range(tiers.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(q, PackedVector2Array(tiers[k][0])):
			return tiers[k][1]
	return FLOOR

static func flat_at(q: Vector2, tiers: Array, room: float) -> bool:
	# True when a prop `room` wide sits wholly on one level, clear of any cliff edge.
	var level = height_at(q, tiers)
	for step in [Vector2(room, 0), Vector2(-room, 0), Vector2(0, room), Vector2(0, -room)]:
		if not is_equal_approx(height_at(q + step, tiers), level):
			return false
	return true

static func put(view, key: String, q: Vector2, tiers: Array, forward: Vector3, paint: Dictionary, scale: float = 1.0) -> void:
	var at = ArenaSky.facing(Vector3(q.x, height_at(q, tiers), q.y), forward)
	at.basis = at.basis.scaled(Vector3.ONE * scale)
	ArenaSky.place(view, key, at, paint)

static func build(view, theme: Dictionary) -> void:
	var walls: Array = view.walls
	var hull = ArenaSky.hull_of(walls)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(String(view.map.get("id", "terra")))
	var reach = ArenaSky.reach_of(hull)
	var far = Rules.HALF_LENGTH
	# The valley floor, then the pad the arena stands on: blue working area, hazard border.
	view.platform(ArenaSky.circle(90.0, 24), FLOOR, 0.5, theme.grass)
	view.platform(ArenaSky.offset(hull, 2.6), -0.03, 0.4, theme.pad)
	view.platform(ArenaSky.offset(hull, 1.8), -0.026, 0.02, theme.pad_panel)
	view.platform(ArenaSky.offset(hull, 1.0), -0.022, 0.02, theme.pad)
	ArenaSky.hazard_band(view, ArenaSky.offset(hull, 2.2), -0.02)
	ArenaSky.walls_and_towers(view, walls, {"trim": ORANGE})
	# Three terraces: sandstone cliffs with the grass lipping over the top.
	var tiers: Array = []
	var below = FLOOR
	for spec in [[reach + 6.0, far + 5.2, 1.0, theme.grass_high], [reach + 12.5, far + 11.5, 2.5, theme.grass], [reach + 20.0, far + 19.0, 4.3, theme.grass_high]]:
		var outline = valley(rng, spec[0], spec[1])
		ArenaSky.slab(view, outline, spec[2], below - 0.05, spec[3], theme.cliff, 0.16)
		tiers.append([outline, spec[2]])
		below = spec[2]
	# A dirt track up the left side and across behind the far goal.
	var track_x = -(reach + 4.1)
	view.box(view, Vector3(track_x, FLOOR + 0.006, 13.0 - (far + 4.2) * 0.5), Vector3(1.8, 0.02, 26.0 + far + 4.2), theme.dirt, false, 0.0)
	view.box(view, Vector3(0, FLOOR + 0.006, -(far + 4.2)), Vector3((reach + 5.0) * 2.0, 0.02, 1.4), theme.dirt, false, 0.0)
	outpost(view, tiers, reach, far)
	nature(view, rng, tiers, hull, reach, far)

static func outpost(view, tiers: Array, reach: float, far: float) -> void:
	var dark = ArenaSky.GRAPHITE
	var steel = ArenaSky.STEEL
	# Behind the far goal, on the first terrace: the hangar, silos with their pipes, and a
	# solar farm, all turned to face the arena.
	put(view, "env_hangar", Vector2(reach * 0.5 + 1.2, -(far + 8.3)), tiers, Vector3.FORWARD, {"shell": WHITE, "trim": Color("dfe5ea"), "dark": dark, "label": Color("5d7f95"), "hazard": ArenaSky.HAZARD, "glow": ArenaSky.LIGHT}, 1.35)
	put(view, "env_silo", Vector2(-reach * 0.3, -(far + 8.4)), tiers, Vector3.FORWARD, {"shell": WHITE, "trim": ORANGE, "dark": dark, "metal": steel}, 1.2)
	put(view, "env_pipes", Vector2(reach * 0.12, -(far + 7.0)), tiers, Vector3.FORWARD, {"shell": TEAL, "trim": ORANGE, "dark": dark, "metal": steel, "hazard": ArenaSky.HAZARD})
	for row in range(2):
		for k in range(3):
			put(view, "env_solar", Vector2(-(reach * 0.62 + 2.4) - k * 3.5, -(far + 6.9) - row * 2.6), tiers, Vector3.FORWARD, {"dark": dark, "metal": steel, "label": SOLAR})
	# Along the sides of the valley: more panels, a radar, containers and pylons.
	for z in [-4.5, -0.6, 3.3]:
		put(view, "env_solar", Vector2(-(reach + 9.3), z), tiers, Vector3.FORWARD, {"dark": dark, "metal": steel, "label": SOLAR})
	put(view, "env_radar", Vector2(reach + 9.0, -far + 2.5), tiers, Vector3(-1, 0, 1), {"dark": dark, "metal": steel, "shell": WHITE, "glow": ArenaSky.LIGHT, "hazard": ArenaSky.HAZARD})
	put(view, "prop_container", Vector2(reach + 8.6, 2.6), tiers, Vector3.LEFT, {"shell": ORANGE, "dark": dark, "hazard": ArenaSky.HAZARD})
	put(view, "prop_container", Vector2(reach + 9.0, 5.4), tiers, Vector3(-1, 0, 0.1), {"shell": TEAL, "dark": dark, "hazard": ArenaSky.HAZARD})
	# Pylons marching along the back of the first terrace.
	for q in [Vector2(-(reach + 2.0), -(far + 10.6)), Vector2(reach + 5.2, -(far + 10.6)), Vector2(reach + 10.8, -7.5), Vector2(-(reach + 11.2), -9.0), Vector2(reach + 10.8, 9.0)]:
		put(view, "env_power", q, tiers, Vector3.FORWARD, {"dark": dark, "metal": steel, "label": Color("dfe5ea")})
	# Up on the high ground, the wind farm.
	for q in [Vector2(-(reach + 6.5), -(far + 15.5)), Vector2(reach + 8.5, -(far + 14.5)), Vector2(reach * 0.15, -(far + 16.5)), Vector2(-(reach + 17.0), -(far + 3.0)), Vector2(reach + 17.5, -(far + 5.0))]:
		put(view, "env_turbine", q, tiers, Vector3.FORWARD, {"shell": WHITE, "trim": Color("dfe5ea"), "hazard": ORANGE}, 1.45)
	# The valley floor: a rover on the track and floodlights at the corners of the pad.
	put(view, "env_rover", Vector2(reach * 0.35, -(far + 4.2)), tiers, Vector3.RIGHT, {"dark": dark, "shell": ORANGE, "trim": WHITE, "glow": ArenaSky.LIGHT, "metal": steel, "rubber": ArenaSky.RUBBER})
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var q = Vector2(sx * (reach + 3.1), sz * (far - 1.2))
			put(view, "env_lamp", q, tiers, Vector3(q.x, 0, q.y), {"dark": dark, "metal": steel, "shell": WHITE, "glow": Color("fff4d6")})
	# Containers, crates and barrels stacked on the pad beside the field.
	var side_x = reach + 2.2
	ArenaSky.place(view, "prop_container", ArenaSky.facing(Vector3(-side_x - 0.3, -0.03, 1.8), Vector3.RIGHT), {"shell": ORANGE, "dark": dark, "hazard": ArenaSky.HAZARD})
	ArenaSky.place(view, "prop_crates", ArenaSky.facing(Vector3(side_x + 0.2, -0.03, -2.6), Vector3.LEFT), {"shell": Color("ffae3d"), "trim": Color("2fa6e0"), "dark": dark})
	ArenaSky.place(view, "prop_barrels", ArenaSky.facing(Vector3(side_x + 0.1, -0.03, 3.4), Vector3.LEFT), {"shell": Color("ff5c4d"), "trim": TEAL, "dark": dark, "metal": steel})
	ArenaSky.place(view, "prop_scrap_a", ArenaSky.facing(Vector3(-side_x - 0.1, -0.03, -3.6), Vector3.RIGHT), {"shell": Color("dfe5ea"), "trim": Color("c9794a"), "label": Color("a39a92"), "dark": dark, "metal": steel, "rubber": ArenaSky.RUBBER, "glow": ArenaSky.LIGHT})

static func nature(view, rng: RandomNumberGenerator, tiers: Array, hull: Array, reach: float, far: float) -> void:
	var pad = ArenaSky.offset(hull, 2.9)
	var taken: Array = [Vector2(reach * 0.5 + 1.2, -(far + 8.3)), Vector2(-reach * 0.3, -(far + 8.4)), Vector2(reach * 0.12, -(far + 7.0))]
	for row in range(2):
		for k in range(3):
			taken.append(Vector2(-(reach * 0.62 + 2.4) - k * 3.5, -(far + 6.9) - row * 2.6))
	for z in [-4.5, -0.6, 3.3]:
		taken.append(Vector2(-(reach + 9.3), z))
	taken.append_array([Vector2(reach + 9.0, -far + 2.5), Vector2(reach + 8.6, 2.6), Vector2(reach + 9.0, 5.4), Vector2(reach * 0.35, -(far + 4.2))])
	taken.append_array([Vector2(-(reach + 2.0), -(far + 10.6)), Vector2(reach + 5.2, -(far + 10.6))])
	# Pines in clumps: on the valley floor beside the pad, and thicker up on the terraces.
	var sample = func(r: RandomNumberGenerator):
		var q = Vector2(r.randf_range(-(reach + 26.0), reach + 26.0), r.randf_range(-(far + 24.0), far + 9.0))
		if Geometry2D.is_point_in_polygon(q, PackedVector2Array(pad)):
			return null
		if absf(q.x - (-(reach + 4.1))) < 1.4 and q.y > -(far + 5.0):
			return null
		if absf(q.y + far + 4.2) < 1.1 and absf(q.x) < reach + 5.2:
			return null
		if q.y > far + 2.0 and q.y < far + 4.6:
			return null
		if not flat_at(q, tiers, 0.8):
			return null
		return q
	var pines = ArenaSky.spots(rng, 90, sample, 1.35, taken)
	var shades = [[Color("2fa35a"), Color("45c46e")], [Color("3aa84f"), Color("5fcf6a")], [Color("23915a"), Color("3db87a")]]
	for q in pines:
		var shade = shades[rng.randi() % shades.size()]
		# Smaller on the near side, where they frame the bottom of the screen.
		var size = rng.randf_range(0.85, 1.3) if q.y < far else rng.randf_range(0.6, 0.85)
		var turn = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * size)
		ArenaSky.place(view, "env_pine_%d" % (rng.randi() % 3), Transform3D(turn, Vector3(q.x, height_at(q, tiers), q.y)), {"shell": shade[0], "label": shade[1], "trim": Color("8a5a3c")})
	taken.append_array(pines)
	# Rocks where the cliffs meet the ground, grey granite and a few sandstone boulders.
	var rocks = ArenaSky.spots(rng, 26, sample, 1.8, taken)
	for q in rocks:
		var sand = rng.randf() < 0.35
		var paint = {"shell": Color("e3b07a") if sand else Color("b9c3cc"), "trim": Color("f3cf98") if sand else Color("e4e9ee")}
		var turn = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4))
		ArenaSky.place(view, "env_rock_%d" % (rng.randi() % 3), Transform3D(turn, Vector3(q.x, height_at(q, tiers) - 0.05, q.y)), paint)
