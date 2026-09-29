extends RefCounted
## Life around the arenas, on top of each world's own dressing: copses of broad-leaved trees,
## flowering bushes and tufts of flowers, a ring of snow-capped mountains on the horizon,
## clouds that drift slowly round the sky, floating islands off the sky deck, fish schools
## circling the seabed and asteroids tumbling past the station. Repeated pieces are drawn in
## batches (one MultiMesh per part and material), so a world can hold hundreds of them; the
## light profile gets fewer. Everything that moves turns on a pivot the arena spins each frame.
const Rules = preload("res://scripts/arena_rules.gd")
const ArenaSky = preload("res://scripts/arena_sky.gd")
const Robots = preload("res://scripts/robots.gd")
const ArtStyle = preload("res://scripts/art_style.gd")
const CLOUD_SEA = preload("res://shaders/cloud_sea.gdshader")
const GROUND_BELOW = preload("res://shaders/ground_below.gdshader")
const LAND_BELOW = preload("res://art/worlds/ground_below.png")

const LEAVES = [[Color("5f8f3e"), Color("8ab25e")], [Color("4f7f3a"), Color("7fa656")], [Color("6b8f35"), Color("9ab65a")], [Color("587a34"), Color("86a24e")]]
const BLOSSOM = [Color("ff6fa8"), Color("ffd84a"), Color("ffffff"), Color("b58cff"), Color("ff8a3d")]
const BARK = Color("7d6741")

static func scatter(view, key: String, transforms: Array, paint: Dictionary, parent: Node3D = null) -> Node3D:
	# Every copy of one kit part in one batch: build it once, then hand its meshes to a
	# MultiMesh with all the transforms.
	var holder = Node3D.new()
	(parent if parent != null else view).add_child(holder)
	if transforms.is_empty():
		return holder
	var template = Node3D.new()
	Robots.prop(view, template, key, [key], paint.duplicate())
	for child in template.get_children():
		if not child is MeshInstance3D:
			continue
		var batch = MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = child.mesh
		batch.multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			batch.multimesh.set_instance_transform(i, transforms[i])
		batch.material_override = child.material_override
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(batch)
	template.free()
	return holder

static func drifter(view, speed: float) -> Node3D:
	# A pivot at the centre of the world that the arena turns every frame.
	var pivot = Node3D.new()
	view.add_child(pivot)
	view.drifters.append([pivot, speed])
	return pivot

static func pose(at: Vector3, turn: float, size: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), at)

static func dark_world(theme: Dictionary) -> bool:
	return theme.has("neon") or theme.get("night", false)

static func mountains(view, theme: Dictionary, rng: RandomNumberGenerator, radius: float, floor_y: float, behind_only: bool = false) -> void:
	# A ring of peaks on the horizon, round the back and both sides (the near end is where the
	# camera sits); snow on the tops, in the world's haze colour.
	var night = dark_world(theme)
	var stone = Color("2c3148") if night else Color(theme.get("sky_low", Color("a9c6d8"))).lerp(Color("8a929c"), 0.7)
	var snow = Color("5a5f80") if night else Color("f4f7fb")
	var sets: Array = [[], []]
	var count = ArenaSky.rich(view, 9)
	for k in range(count):
		var a = lerpf(-PI * 0.95, PI * 0.95, (k + rng.randf_range(0.2, 0.8)) / count) if not behind_only else lerpf(-PI * 0.55, PI * 0.55, (k + 0.5) / count)
		# Angle 0 is straight behind the far goal (-Z).
		var at = Vector3(sin(a) * radius, floor_y, -cos(a) * radius) * rng.randf_range(0.92, 1.1)
		at.y = floor_y
		# Each range lies along the horizon, its long side to the arena.
		sets[k % 2].append(pose(at, -a + rng.randf_range(-0.25, 0.25), rng.randf_range(1.4, 2.1)))
	for i in range(2):
		# Bare rock on the steep faces, forest on the gentle slopes (no snow).
		var forest = Color("24283c") if night else Color("4f6b45")
		var rock = stone if night else Color("7a7266")
		scatter(view, "env_mountain_%d" % i, sets[i], {"shell": stone, "trim": snow, "rock": rock, "rock2": forest})

static func clouds(view, theme: Dictionary, rng: RandomNumberGenerator, count: int, radius: Vector2, height: Vector2, speed: float) -> void:
	# Puffy clouds on a slow carousel round the sky.
	var night = dark_world(theme)
	var white = Color("3b3656") if night else Color("ffffff")
	var belly = Color("2a2640") if night else Color("dde6f0")
	var pivot = drifter(view, speed)
	var sets: Array = [[], [], []]
	for k in range(ArenaSky.rich(view, count)):
		var a = rng.randf_range(0, TAU)
		var r = rng.randf_range(radius.x, radius.y)
		sets[k % 3].append(pose(Vector3(sin(a) * r, rng.randf_range(height.x, height.y), cos(a) * r), -a + PI * 0.5, rng.randf_range(1.2, 2.6)))
	for i in range(3):
		scatter(view, "env_cloud_%d" % i, sets[i], {"shell": white, "glow": white.darkened(0.04), "trim": belly}, pivot)

static func woods(view, rng: RandomNumberGenerator, spots: Array, heights: Callable) -> void:
	# Broad-leaved trees, bushes and flower tufts on the given spots, each on the ground height
	# `heights` gives for it.
	var oaks: Array = [[], [], []]
	var bushes: Array = [[], []]
	var tufts: Array = [[], []]
	for q in spots:
		var y: float = heights.call(q)
		var roll = rng.randf()
		if roll < 0.5:
			oaks[rng.randi() % 3].append(pose(Vector3(q.x, y, q.y), rng.randf_range(0, TAU), rng.randf_range(0.8, 1.25)))
		elif roll < 0.78:
			bushes[rng.randi() % 2].append(pose(Vector3(q.x, y, q.y), rng.randf_range(0, TAU), rng.randf_range(0.8, 1.3)))
		else:
			tufts[rng.randi() % 2].append(pose(Vector3(q.x, y, q.y), rng.randf_range(0, TAU), rng.randf_range(0.9, 1.4)))
	for i in range(3):
		var leaves = LEAVES[i % LEAVES.size()]
		scatter(view, "env_oak_%d" % i, oaks[i], {"shell": leaves[0], "label": leaves[1], "trim": BARK})
	for i in range(2):
		var leaves = LEAVES[(i + 2) % LEAVES.size()]
		scatter(view, "env_bush_%d" % i, bushes[i], {"shell": leaves[0], "label": leaves[1], "hazard": BLOSSOM[i]})
		scatter(view, "env_flowers_%d" % i, tufts[i], {"shell": LEAVES[i][1], "hazard": BLOSSOM[2 + i], "label": BLOSSOM[i]})

static func meadow(view, rng: RandomNumberGenerator, sample: Callable, heights: Callable, count: int, green: Color) -> void:
	# Tufts of grass everywhere the sample allows, no spacing needed: they are small and batched.
	# Tufts of grass are left out: the meadow is painted, and phones need the triangles.
	return
	var sets: Array = [[], []]
	var tries = 0
	var wanted = ArenaSky.rich(view, count)
	while sets[0].size() + sets[1].size() < wanted and tries < wanted * 6:
		tries += 1
		var q = sample.call(rng)
		if q == null:
			continue
		sets[rng.randi() % 2].append(pose(Vector3(q.x, heights.call(q), q.y), rng.randf_range(0, TAU), rng.randf_range(0.8, 1.5)))
	for i in range(2):
		scatter(view, "env_grass_%d" % i, sets[i], {"grass": green.lerp(Color("9ac26a"), 0.2 * i)})

static func roof_gardens(view, rng: RandomNumberGenerator, roofs: Array, reach: float, far: float) -> void:
	# Green roofs across the city: a lawn with painted trees and bushes on some of the roofs in
	# view, all the trees batched together.
	if not ArtStyle.painted_nature():
		return
	var trees: Array = [[], []]
	var shrubs: Array = []
	var lawn = Color("7fae52")
	for roof in roofs:
		var c: Vector2 = roof.center
		if absf(c.x) > reach + 24.0 or c.y < -(far + 30.0) or rng.randf() > 0.4:
			continue
		var size: Vector2 = roof.size
		var top: float = roof.top
		var half = size * 0.3
		view.platform([Vector2(c.x - half.x, c.y - half.y), Vector2(c.x + half.x, c.y - half.y), Vector2(c.x + half.x, c.y + half.y), Vector2(c.x - half.x, c.y + half.y)], top + 0.06, 0.1, lawn)
		for k in range(rng.randi_range(1, 3)):
			var at = Vector3(c.x + rng.randf_range(-half.x, half.x) * 0.8, top + 0.08, c.y + rng.randf_range(-half.y, half.y) * 0.8)
			if rng.randf() < 0.6:
				trees[rng.randi() % 2].append(pose(at, rng.randf_range(0, TAU), rng.randf_range(0.6, 0.85)))
			else:
				shrubs.append(pose(at, rng.randf_range(0, TAU), rng.randf_range(0.9, 1.3)))
	for i in range(2):
		scatter(view, "env_oak_%d" % i, trees[i], {"leaf": LEAVES[i][0], "leaf2": LEAVES[i][1], "trim": BARK})
	scatter(view, "env_bush_0", shrubs, {"leaf": LEAVES[2][0], "leaf2": LEAVES[2][1], "hazard": BLOSSOM[0]})

static func cloud_sea(view, height: float) -> void:
	# One wide sheet far below, painted as rolling cloud tops.
	var sea = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(460, 460)
	sea.mesh = plane
	sea.position = Vector3(0, height, 0)
	var mat = ShaderMaterial.new()
	mat.shader = CLOUD_SEA
	var theme: Dictionary = view.theme
	# It melts into the bottom of the sky behind it, so no seam shows on the horizon.
	var air: Color = Color(theme.get("sky_low", Color("e4f1fb")))
	mat.set_shader_parameter("haze_color", Vector3(air.r, air.g, air.b))
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(sea)

static func ground_below(view, height: float) -> void:
	# Far below the deck, the land the arena floats over (fields, forests, rivers, a town),
	# painted flat and seen through the mist of the height.
	var land = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	land.mesh = plane
	land.position = Vector3(0, height, 0)
	var mat = ShaderMaterial.new()
	mat.shader = GROUND_BELOW
	mat.set_shader_parameter("land", LAND_BELOW)
	var theme: Dictionary = view.theme
	# It melts into the bottom of the sky behind it, so no seam shows on the horizon.
	var air: Color = Color(theme.get("sky_low", Color("e4f1fb")))
	mat.set_shader_parameter("haze_color", Vector3(air.r, air.g, air.b))
	land.material_override = mat
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(land)

static func ring_spots(rng: RandomNumberGenerator, count: int, inner: float, outer: float, keep_out: Array, gap: float = 1.1) -> Array:
	# Points in a band round the arena, clear of `keep_out` (the pad and whatever stands there).
	var sample = func(r: RandomNumberGenerator):
		var a = r.randf_range(0, TAU)
		var d = r.randf_range(inner, outer)
		var q = Vector2(sin(a) * d * 0.85, -cos(a) * d)
		if Geometry2D.is_point_in_polygon(q, PackedVector2Array(keep_out)):
			return null
		return q
	return ArenaSky.spots(rng, count, sample, gap)

static func build(view, theme: Dictionary, dressing: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(String(view.map.get("id", "life")) + dressing)
	var hull = ArenaSky.hull_of(view.walls)
	var reach = ArenaSky.reach_of(hull)
	var far = Rules.HALF_LENGTH
	match dressing:
		"ground":
			mountains(view, theme, rng, far + 70.0, -0.4)
			clouds(view, theme, rng, 14, Vector2(30, 70), Vector2(14, 24), 0.012)
		"sky":
			# Floating islands round the deck (meadow, trees, strata of rock, hanging roots),
			# clouds above and below, and far down a sea of clouds the serras rise out of.
			var islands: Array = [[], []]
			var count = ArenaSky.rich(view, 7)
			for k in range(count):
				var a = lerpf(-PI * 0.92, PI * 0.92, (k + rng.randf_range(0.25, 0.75)) / count)
				var r = rng.randf_range(reach + 16.0, reach + 38.0)
				islands[k % 2].append(pose(Vector3(sin(a) * r, rng.randf_range(-5.0, 4.0), -cos(a) * r), rng.randf_range(0, TAU), rng.randf_range(0.9, 1.6)))
			var green = LEAVES[0]
			for i in range(2):
				scatter(view, "env_island_%d" % i, islands[i], {"turf": Color("7fae52"), "leaf": green[0], "leaf2": green[1], "trim": BARK, "dark": Color("5a4430"), "rock": Color("c2ab8c"), "rock2": Color("9a7650"), "hazard": BLOSSOM[i]})
			if ArtStyle.painted_nature():
				ground_below(view, -55.0)
			clouds(view, theme, rng, 12, Vector2(reach + 10.0, reach + 45.0), Vector2(-9.0, -3.0), 0.02)
			clouds(view, theme, rng, 10, Vector2(35, 80), Vector2(10, 22), -0.01)
			mountains(view, theme, rng, far + 90.0, -55.0 if ArtStyle.painted_nature() else -14.0)
		"city":
			# High above the rooftops: never between a pulled-back camera and the field.
			clouds(view, theme, rng, 12, Vector2(45, 90), Vector2(48, 62), 0.012)
		"diorama":
			mountains(view, theme, rng, far + 60.0, -2.0)
			clouds(view, theme, rng, 12, Vector2(28, 70), Vector2(12, 22), 0.014)
		"sea":
			# Fish schools circling the seabed at two depths, in opposite directions.
			for turn in [0.05, -0.035]:
				var pivot = drifter(view, turn)
				var schools: Array = [[], []]
				for k in range(ArenaSky.rich(view, 6)):
					var a = rng.randf_range(0, TAU)
					var r = rng.randf_range(reach + 6.0, reach + 22.0)
					schools[k % 2].append(pose(Vector3(sin(a) * r, rng.randf_range(1.5, 6.0), cos(a) * r), -a + (PI * 0.5 if turn > 0 else -PI * 0.5), rng.randf_range(1.0, 1.8)))
				for i in range(2):
					scatter(view, "env_school_%d" % i, schools[i], {"shell": [Color("ffb03d"), Color("7fe6ff")][i], "trim": Color("ffffff"), "dark": Color("1c2b3a")}, pivot)
		"space":
			# Asteroids tumbling slowly round the station.
			var pivot = drifter(view, 0.03)
			var rocks: Array = [[], [], []]
			for k in range(ArenaSky.rich(view, 18)):
				var a = rng.randf_range(0, TAU)
				var r = rng.randf_range(reach + 9.0, reach + 30.0)
				var at = Vector3(sin(a) * r, rng.randf_range(-6.0, 5.0), cos(a) * r)
				var tumble = Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.6, 1.8))
				rocks[k % 3].append(Transform3D(tumble, at))
			for i in range(3):
				scatter(view, "env_rock_%d" % i, rocks[i], {"shell": Color("8a8698"), "trim": Color("b7b3c4")}, pivot)
