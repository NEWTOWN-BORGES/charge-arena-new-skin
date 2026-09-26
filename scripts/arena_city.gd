extends RefCounted
## Cidade Alta: the arena on the roof of a skyscraper. A pale roof with a violet working area,
## a parapet with a light strip, floodlights, rooftop plant and a big billboard behind the far
## goal; the tower drops to the street with its windows lit; around it the city's blocks stand
## at every height, some joined by skybridges, their roofs busy with plant, tanks, antennas, a
## helipad and a crane. Haze swallows the street far below. Kit parts and slabs only: static,
## opaque and merged by material after the build.
const Rules = preload("res://scripts/arena_rules.gd")
const ArenaSky = preload("res://scripts/arena_sky.gd")

const STREET = -24.0
const WHITE = Color("f6f4fc")
const CYAN = Color("3fd9e6")
const WARM = Color("ffe49a")
const GLASS = Color("4b4f8f")
const FACADES = [Color("b8a6f2"), Color("ffb48c"), Color("8fdcc0"), Color("8ec5ff"), Color("f6e3c0"), Color("ff9cc9")]
const BLOCKS = [Vector2(6.0, 6.0), Vector2(5.0, 8.0), Vector2(4.0, 4.5)]

static func build(view, theme: Dictionary) -> void:
	var walls: Array = view.walls
	var hull = ArenaSky.hull_of(walls)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(String(view.map.get("id", "cidade")))
	var reach = ArenaSky.reach_of(hull)
	var far = Rules.HALF_LENGTH
	var edge = ArenaSky.offset(hull, 3.2)
	# The roof: violet working area, hazard border, parapet with a light strip on top.
	view.platform(edge, -0.03, 0.5, theme.roof)
	view.platform(ArenaSky.offset(hull, 2.3), -0.026, 0.02, theme.roof_panel)
	view.platform(ArenaSky.offset(hull, 1.0), -0.022, 0.02, theme.roof)
	ArenaSky.hazard_band(view, ArenaSky.offset(hull, 2.7), -0.02)
	var parapet = ArenaSky.offset(hull, 3.08)
	for i in range(parapet.size()):
		var a: Vector2 = parapet[i]
		var b: Vector2 = parapet[(i + 1) % parapet.size()]
		view.segment(view, Vector3(a.x, 0.2, a.y), Vector3(b.x, 0.2, b.y), 0.24, 0.46, WHITE)
		view.segment(view, Vector3(a.x, 0.44, a.y), Vector3(b.x, 0.44, b.y), 0.1, 0.03, CYAN, true)
	ArenaSky.walls_and_towers(view, walls)
	tower(view, edge, rng)
	var neighbours = city(view, rng, reach, far)
	roof_plant(view, rng, reach, far, neighbours)
	view.platform(ArenaSky.circle(90.0, 24), STREET, 0.5, theme.street)

static func tower(view, edge: Array, rng: RandomNumberGenerator) -> void:
	# The arena's own tower, down to the street: violet facade and a band of windows on every
	# floor of the faces the camera can see, lit or dark.
	ArenaSky.slab(view, edge, -0.53, STREET, Color("8f80e6"), Color("8f80e6"))
	var winding = signf(ArenaSky.signed_area(edge))
	for i in range(edge.size()):
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % edge.size()]
		var e = (b - a).normalized()
		var out = Vector2(e.y, -e.x) * winding
		if out.y < -0.3:
			continue
		var a3 = Vector3(a.x + out.x * 0.03, 0, a.y + out.y * 0.03)
		var b3 = Vector3(b.x + out.x * 0.03, 0, b.y + out.y * 0.03)
		var inset = (b3 - a3).normalized() * 0.35
		for k in range(18):
			var y = -1.3 - k * 1.1
			var lit = rng.randf() < 0.6
			view.segment(view, a3 + inset + Vector3.UP * y, b3 - inset + Vector3.UP * y, 0.04, 0.5, WARM if lit else GLASS, lit)

static func city(view, rng: RandomNumberGenerator, reach: float, far: float) -> Array:
	# A grid of blocks round the tower, streets between them. Lower towards the camera so
	# nothing stands between it and the field; taller behind the far goal.
	var keep_out = Rect2(-(reach + 3.2) - 4.6, -(far + 3.2) - 4.6, (reach + 3.2 + 4.6) * 2.0, (far + 3.2 + 4.6) * 2.0)
	var roofs: Array = []
	for gx in range(-3, 4):
		for gz in range(-5, 3):
			var center = Vector2(gx * 9.0 + rng.randf_range(-0.8, 0.8), gz * 9.0 + 2.0 + rng.randf_range(-0.8, 0.8))
			var kind = rng.randi() % BLOCKS.size()
			var size: Vector2 = BLOCKS[kind]
			var turned = rng.randf() < 0.5
			if turned:
				size = Vector2(size.y, size.x)
			if keep_out.intersects(Rect2(center - size * 0.5, size)):
				continue
			var top: float
			if center.y > far - 1.0:
				top = rng.randf_range(-15.0, -9.0)
			elif center.y < -(far + 4.0):
				top = rng.randf_range(-5.0, 5.0)
			else:
				top = rng.randf_range(-9.0, 1.5)
			var facade: Color = FACADES[rng.randi() % FACADES.size()]
			var paint = {"shell": facade, "trim": facade.lightened(0.45), "glow": WARM if rng.randf() < 0.7 else Color("9ff3ff"), "label": GLASS, "rubber": Color("d9d5e6")}
			var basis = Basis(Vector3.UP, PI * 0.5) if turned else Basis.IDENTITY
			ArenaSky.place(view, "env_block_%d" % kind, Transform3D(basis, Vector3(center.x, top, center.y)), paint)
			roofs.append({"center": center, "size": size, "top": top})
	# Two skybridges from the arena tower to the blocks beside it.
	for side in [-1, 1]:
		var x = side * (reach + 3.2 + 2.3)
		var bridge = ArenaSky.along(Vector3(x, -5.2 + side * 0.8, -2.0), Vector3.RIGHT, 1.25)
		ArenaSky.place(view, "env_skybridge", bridge, {"shell": WHITE, "metal": ArenaSky.STEEL, "dark": ArenaSky.GRAPHITE, "glow": CYAN})
	return roofs

static func roof_plant(view, rng: RandomNumberGenerator, reach: float, far: float, roofs: Array) -> void:
	var dark = ArenaSky.GRAPHITE
	var steel = ArenaSky.STEEL
	# On the arena roof: the billboard behind the far goal, floodlights, plant beside the field.
	var board = ArenaSky.facing(Vector3(0, -0.03, -(far + 2.5)), Vector3.FORWARD)
	board.basis = board.basis.scaled(Vector3.ONE * 1.2)
	ArenaSky.place(view, "env_billboard", board, {"dark": dark, "glow": Color("ff7fd4"), "label": CYAN, "hazard": WARM})
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var q = Vector2(sx * (reach + 2.4), sz * (far + 0.6))
			ArenaSky.place(view, "env_lamp", ArenaSky.facing(Vector3(q.x, -0.03, q.y), Vector3(q.x, 0, q.y)), {"dark": dark, "metal": steel, "shell": WHITE, "glow": Color("fff4d6")})
	for spot in [Vector3(-(reach + 2.2), -0.03, -2.6), Vector3(reach + 2.2, -0.03, 1.8)]:
		ArenaSky.place(view, "env_ac", ArenaSky.facing(spot, Vector3(-spot.x, 0, 0)), {"shell": Color("e9e6f2"), "dark": dark, "metal": steel})
	ArenaSky.place(view, "env_water_tank", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), Vector3(reach + 2.3, -0.03, -3.4)), {"trim": Color("c9794a"), "dark": dark})
	ArenaSky.place(view, "prop_crates", ArenaSky.facing(Vector3(-(reach + 2.2), -0.03, 2.8), Vector3.RIGHT), {"shell": Color("ffae3d"), "trim": CYAN, "dark": dark})
	# On the other roofs: plant, water tanks and antennas; a helipad and a crane on the
	# big ones in view.
	var pad_done = false
	var crane_done = false
	for roof in roofs:
		var c: Vector2 = roof.center
		if absf(c.x) > reach + 24.0 or c.y < -(far + 30.0):
			continue
		var size: Vector2 = roof.size
		var top: float = roof.top
		if not pad_done and size.x >= 6.0 and size.y >= 6.0 and c.y < 0.0:
			ArenaSky.place(view, "prop_pad", Transform3D(Basis.IDENTITY, Vector3(c.x, top + 0.04, c.y)), {"dark": dark, "hazard": ArenaSky.HAZARD, "glow": CYAN})
			pad_done = true
			continue
		if not crane_done and c.y < -(far + 4.0) and absf(c.x) < 10.0:
			ArenaSky.place(view, "prop_crane", ArenaSky.facing(Vector3(c.x, top, c.y), Vector3(0.3, 0, 1)), {"shell": WHITE, "trim": Color("ff7a3c"), "dark": dark, "metal": steel, "hazard": ArenaSky.HAZARD, "label": Color("c9794a")})
			crane_done = true
			continue
		for k in range(rng.randi_range(1, 2)):
			var spot = Vector3(c.x + rng.randf_range(-size.x * 0.28, size.x * 0.28), top + 0.04, c.y + rng.randf_range(-size.y * 0.28, size.y * 0.28))
			match rng.randi() % 3:
				0:
					ArenaSky.place(view, "env_ac", ArenaSky.facing(spot, Vector3(rng.randf_range(-1, 1), 0, 1)), {"shell": Color("e9e6f2"), "dark": dark, "metal": steel})
				1:
					ArenaSky.place(view, "env_water_tank", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.7), spot), {"trim": Color("c9794a"), "dark": dark})
				_:
					ArenaSky.place(view, "prop_antenna", Transform3D(Basis.IDENTITY, spot), {"dark": dark, "glow": Color("ff5c7a"), "hazard": ArenaSky.HAZARD})
