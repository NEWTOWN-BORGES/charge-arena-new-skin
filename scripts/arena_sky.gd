extends RefCounted
## The floating sky arena, modelled like the robots (tools/blender/arena_kit.py shows the
## design): a steel deck around the field with hazard stripes, edge lights and landing pads, a
## stepped hull underneath with thrusters, armoured wall modules and corner towers from the
## robot kit, and the deck furniture (scrap, crates, barrels, containers, a crane, drones, a
## scoreboard, antennas) painted like the cast. Everything sits outside the collision outline
## and is merged by material after the build, so it costs a handful of draws.
const Rules = preload("res://scripts/arena_rules.gd")
const Robots = preload("res://scripts/robots.gd")

const STEEL = Color("b9c2cc")
const GRAPHITE = Color("36404f")
const RUBBER = Color("15171c")
const HAZARD = Color("f2c230")
const LIGHT = Color("8ff6e2")

static func signed_area(points: Array) -> float:
	var total = 0.0
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return total * 0.5

static func hull_of(walls: Array) -> Array:
	# The deck follows the convex hull of the field, in the field's own winding, so pinched
	# and bowed maps get a clean platform around them.
	var hull: Array = Array(Geometry2D.convex_hull(PackedVector2Array(walls)))
	hull.pop_back()
	if signed_area(hull) * signed_area(walls) < 0:
		hull.reverse()
	return hull

static func offset(points: Array, distance: float) -> Array:
	# A convex outline pushed out by `distance` along every edge, corners mitred.
	var n = points.size()
	var lines: Array = []
	for i in range(n):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % n]
		var e = (b - a).normalized()
		var normal = Vector2(e.y, -e.x)
		if normal.dot((a + b) * 0.5) < 0:
			normal = -normal
		lines.append([a + normal * distance, e])
	var out: Array = []
	for i in range(n):
		var p1: Vector2 = lines[i - 1][0]
		var d1: Vector2 = lines[i - 1][1]
		var p2: Vector2 = lines[i][0]
		var d2: Vector2 = lines[i][1]
		var den = d1.x * d2.y - d1.y * d2.x
		if absf(den) < 0.00001:
			out.append(p2)
			continue
		var t = ((p2.x - p1.x) * d2.y - (p2.y - p1.y) * d2.x) / den
		out.append(p1 + d1 * t)
	return out

static func inside(point: Vector2, polygon: Array) -> bool:
	return Geometry2D.is_point_in_polygon(point, PackedVector2Array(polygon))

static func facing(position: Vector3, forward: Vector3, scale_x: float = 1.0) -> Transform3D:
	# A frame at `position` with local +Z along `forward` (flattened) and +Y up.
	var z = Vector3(forward.x, 0, forward.z).normalized()
	var x = Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x * scale_x, Vector3.UP, z), position)

static func along(position: Vector3, direction: Vector3, scale: float = 1.0) -> Transform3D:
	# A frame at `position` with local +X along `direction` (flattened) and +Y up: for the
	# parts modelled lengthwise, trusses, solar wings and modules.
	var x = Vector3(direction.x, 0, direction.z).normalized()
	return Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)).scaled(Vector3.ONE * scale), position)

static func place(view, key: String, transform: Transform3D, paint: Dictionary) -> Node3D:
	var node = Node3D.new()
	node.transform = transform
	view.add_child(node)
	Robots.prop(view, node, key, [key], paint)
	return node

static func circle(radius: float, sides: int = 32, center: Vector2 = Vector2.ZERO) -> Array:
	var points: Array = []
	for i in range(sides):
		var a = TAU * i / sides
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points

static func face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	# One flat triangle, wound so that it faces along `want`.
	var normal = (c - a).cross(b - a)
	if normal.dot(want) < 0:
		var swap = b
		b = c
		c = swap
		normal = -normal
	st.set_normal(normal.normalized())
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func slab(view, outline: Array, top: float, bottom: float, cap: Color, side: Color, lip: float = 0.0) -> void:
	# A solid block of ground over any simple outline, concave or not: a flat cap, walls down
	# to `bottom` and, `lip` deep along the top of the walls, a band in the cap colour (the
	# grass over a cliff). Two meshes, one per colour, merged with the rest after the build.
	var shape = PackedVector2Array(outline)
	var order = Geometry2D.triangulate_polygon(shape)
	var cap_st = SurfaceTool.new()
	cap_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, order.size(), 3):
		var a: Vector2 = shape[order[i]]
		var b: Vector2 = shape[order[i + 1]]
		var c: Vector2 = shape[order[i + 2]]
		face(cap_st, Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(c.x, top, c.y), Vector3.UP)
	var winding = signf(signed_area(outline))
	var wall_st = SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var e = (b - a).normalized()
		var out = Vector3(e.y, 0, -e.x) * winding
		var bands = [[top - lip, bottom, wall_st]]
		if lip > 0.0:
			bands.append([top, top - lip, cap_st])
		for band in bands:
			var p0 = Vector3(a.x, band[0], a.y)
			var p1 = Vector3(b.x, band[0], b.y)
			var p2 = Vector3(b.x, band[1], b.y)
			var p3 = Vector3(a.x, band[1], a.y)
			face(band[2], p0, p1, p2, out)
			face(band[2], p0, p2, p3, out)
	view.mesh(view, cap_st.commit(), Vector3.ZERO, cap)
	view.mesh(view, wall_st.commit(), Vector3.ZERO, side)

static func spots(rng: RandomNumberGenerator, count: int, sample: Callable, gap: float, taken: Array = []) -> Array:
	# Up to `count` points drawn from `sample` (which returns null to reject a draw), each at
	# least `gap` from the others and from `taken`.
	var found: Array = []
	var tries = 0
	while found.size() < count and tries < count * 300:
		tries += 1
		var q = sample.call(rng)
		if q == null:
			continue
		var clear = true
		for other in taken:
			if q.distance_to(other) < gap:
				clear = false
				break
		if clear:
			for other in found:
				if q.distance_to(other) < gap:
					clear = false
					break
		if clear:
			found.append(q)
	return found

static func reach_of(hull: Array) -> float:
	var reach = 0.0
	for point in hull:
		reach = maxf(reach, absf(point.x))
	return reach

static func hazard_band(view, outline: Array, height: float) -> void:
	# Yellow and graphite chevrons along an outline, as on the sky deck.
	for i in range(outline.size()):
		var s0: Vector2 = outline[i]
		var s1: Vector2 = outline[(i + 1) % outline.size()]
		var count = int(s0.distance_to(s1) / 0.3)
		var angle = -atan2(s1.y - s0.y, s1.x - s0.x)
		for k in range(count):
			var q = s0.lerp(s1, (k + 0.5) / count)
			var tile = view.box(view, Vector3(q.x, height, q.y), Vector3(0.26, 0.02, 0.3), HAZARD if k % 2 == 0 else GRAPHITE, false, 0.0)
			tile.rotation.y = angle + 0.5

static func build(view, theme: Dictionary) -> void:
	var walls: Array = view.walls
	var hull = hull_of(walls)
	var deck: Color = theme.get("deck", Color("c9d6e2"))
	var panel: Color = theme.get("deck_panel", Color("5d7fa3"))
	var hull_color: Color = theme.get("hull", Color("e9edf1"))
	# Deck, its dark lip and the blue working area, then the stepped hull underneath.
	view.platform(offset(hull, 3.6), -0.03, 0.3, deck)
	view.platform(offset(hull, 3.7), -0.33, 0.22, GRAPHITE)
	view.platform(offset(hull, 2.9), -0.026, 0.02, panel)
	view.platform(offset(hull, 1.0), -0.022, 0.02, deck)
	view.platform(offset(hull, 3.2), -0.55, 0.75, hull_color)
	view.platform(offset(hull, 2.2), -1.3, 0.8, GRAPHITE.lightened(0.15))
	view.platform(offset(hull, 0.9), -2.1, 0.7, hull_color)
	var rim = offset(hull, 3.7)
	var stripe = offset(hull, 3.35)
	for i in range(hull.size()):
		# Edge light along the lip, hazard chevrons along the deck border.
		var a: Vector2 = rim[i]
		var b: Vector2 = rim[(i + 1) % rim.size()]
		view.segment(view, Vector3(a.x, -0.44, a.y), Vector3(b.x, -0.44, b.y), 0.05, 0.04, LIGHT, true)
	hazard_band(view, stripe, -0.02)
	walls_and_towers(view, walls)
	furniture(view, walls, hull, theme)

static func walls_and_towers(view, walls: Array, look: Dictionary = {}) -> void:
	# `look` recolours the armour for a world: "shell" (the plates), "trim" (the tower domes)
	# and "glow" (the edge lights).
	var shell: Color = look.get("shell", Color("fff4e2"))
	var trim: Color = look.get("trim", Color("ff7a3c"))
	var glow: Color = look.get("glow", LIGHT)
	for i in range(walls.size()):
		var a2: Vector2 = walls[i]
		var b2: Vector2 = walls[(i + 1) % walls.size()]
		var a = Vector3(a2.x, 0.0, a2.y)
		var b = Vector3(b2.x, 0.0, b2.y)
		var edge = b - a
		var inward = Vector3(-edge.z, 0, edge.x).normalized()
		if inward.dot(-(a + b) * 0.5) < 0:
			inward = -inward
		var count = maxi(1, int(round(edge.length() / 1.05)))
		var span = edge.length() / count
		for n in range(count):
			var middle = a.lerp(b, (n + 0.5) / count)
			var team = view.CYAN if middle.z > 0 else view.CORAL
			var paint = {"shell": shell, "dark": GRAPHITE, "metal": STEEL, "glow": glow, "team": team, "rubber": RUBBER}
			place(view, "arena_wall", facing(middle, inward, span - 0.02), paint)
	for i in range(walls.size()):
		var c: Vector2 = walls[i]
		var at = Vector3(c.x, 0, c.y)
		var paint = {"shell": shell, "trim": trim, "dark": GRAPHITE, "metal": STEEL, "glow": Color("fff4d6"), "hazard": HAZARD}
		place(view, "arena_pylon", facing(at, -at), paint)

static func furniture(view, walls: Array, hull: Array, theme: Dictionary) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(String(view.map.get("id", "aurora")))
	var inner = offset(hull, 1.1)
	var outer = offset(hull, 3.1)
	var side_x = Rules.outline_x_at(walls, 0) + 2.1
	# Heavy pieces on the long sides, where they frame the field without covering it.
	var containers = [Color("ff7a3c"), Color("2fc4a5"), Color("8f7cf0")]
	place(view, "prop_container", facing(Vector3(-side_x - 0.3, 0, 1.4), Vector3.RIGHT), {"shell": containers[0], "dark": GRAPHITE, "hazard": HAZARD})
	place(view, "prop_container", facing(Vector3(-side_x - 0.3, 0.9, 1.25), Vector3(1, 0, 0.04)), {"shell": containers[1], "dark": GRAPHITE, "hazard": HAZARD})
	place(view, "prop_container", facing(Vector3(side_x + 0.3, 0, -2.2), Vector3.LEFT), {"shell": containers[2], "dark": GRAPHITE, "hazard": HAZARD})
	place(view, "prop_crane", facing(Vector3(side_x + 0.2, 0, 3.2), Vector3(-0.2, 0, 1)), {"shell": Color("f4f6f8"), "trim": Color("ff7a3c"), "dark": GRAPHITE, "metal": STEEL, "hazard": HAZARD, "label": Color("c9794a")})
	place(view, "prop_scoreboard", facing(Vector3(-side_x - 0.6, 0, -3.8), Vector3.RIGHT), {"shell": Color("f4f6f8"), "dark": GRAPHITE, "metal": STEEL, "team": view.CYAN, "trim": view.CORAL, "glow": LIGHT})
	for spot in [Vector3(-side_x, 0, -Rules.HALF_LENGTH + 1.6), Vector3(side_x, 0, Rules.HALF_LENGTH - 1.4)]:
		place(view, "prop_pad", Transform3D(Basis.IDENTITY, spot), {"dark": GRAPHITE, "hazard": HAZARD, "glow": LIGHT})
	for i in range(0, hull.size(), 2):
		var corner: Vector2 = offset(hull, 3.25)[i]
		place(view, "prop_antenna", Transform3D(Basis.IDENTITY, Vector3(corner.x, 0, corner.y)), {"dark": GRAPHITE, "glow": LIGHT, "hazard": HAZARD})
	# Drones hover over the deck, never over the field.
	for spot in [Vector3(-side_x - 0.9, 2.4, -1.0), Vector3(side_x + 1.0, 2.2, 1.0), Vector3(-side_x - 1.3, 2.7, 4.8)]:
		place(view, "prop_drone", facing(spot, Vector3.FORWARD), {"shell": Color("f4f6f8"), "dark": GRAPHITE, "metal": STEEL, "glow": LIGHT})
	# Scrap, crates and barrels scattered on the deck ring, clear of the goal ends.
	var kinds = ["prop_scrap_a", "prop_scrap_b", "prop_crates", "prop_barrels", "prop_crates", "prop_barrels", "prop_scrap_bits"]
	var placed: Array = []
	var tries = 0
	while placed.size() < 24 and tries < 3000:
		tries += 1
		var q = Vector2(rng.randf_range(-side_x - 2.0, side_x + 2.0), rng.randf_range(-Rules.HALF_LENGTH - 3.0, Rules.HALF_LENGTH + 3.0))
		if inside(q, inner) or not inside(q, outer):
			continue
		if absf(q.x) < 3.0 and absf(q.y) > Rules.HALF_LENGTH - 1.0:
			continue
		if absf(q.x) > side_x - 1.2 and ((q.x < 0 and q.y > -4.6 and q.y < 2.4) or (q.x > 0 and q.y > -3.4 and q.y < 4.8)):
			continue
		var clear = true
		for other in placed:
			if q.distance_to(other) < 1.35:
				clear = false
				break
		if not clear:
			continue
		placed.append(q)
		var kind: String = kinds[rng.randi() % kinds.size()]
		var paint: Dictionary
		match kind:
			"prop_crates":
				paint = {"shell": [Color("ffae3d"), Color("2fa6e0"), Color("f4f6f8")][rng.randi() % 3], "trim": [Color("2fa6e0"), Color("ffae3d")][rng.randi() % 2], "dark": GRAPHITE}
			"prop_barrels":
				paint = {"shell": [Color("ff5c4d"), Color("2fa6e0")][rng.randi() % 2], "trim": [Color("2fc4a5"), Color("ffae3d")][rng.randi() % 2], "dark": GRAPHITE, "metal": STEEL}
			_:
				paint = {"shell": Color("dfe5ea"), "trim": Color("c9794a"), "label": Color("a39a92"), "dark": GRAPHITE, "metal": STEEL, "rubber": RUBBER, "glow": LIGHT}
		var turn = Basis(Vector3.UP, rng.randf_range(0, TAU))
		place(view, kind, Transform3D(turn, Vector3(q.x, 0, q.y)), paint)
	# Thrusters under the hull and clouds drifting past below the deck.
	for spot in [Vector2(-0.45, -0.6), Vector2(0.45, -0.6), Vector2(-0.45, 0.6), Vector2(0.45, 0.6)]:
		place(view, "prop_thruster", Transform3D(Basis.IDENTITY, Vector3(spot.x * side_x * 1.3, -2.8, spot.y * Rules.HALF_LENGTH)), {"dark": GRAPHITE, "metal": STEEL, "glow": Color("ffb35c")})
	for cloud in [Vector3(-side_x - 7.0, -3.5, -6.0), Vector3(side_x + 7.0, -4.0, 4.0), Vector3(-side_x - 5.0, -5.0, 10.0), Vector3(side_x + 5.0, -2.5, -12.0)]:
		var size = rng.randf_range(2.2, 3.2)
		place(view, "prop_cloud", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), cloud), {"shell": Color("ffffff")})
