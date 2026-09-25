extends RefCounted
## Everything around the playing surface: the armoured perimeter blocks and the stadium that
## surrounds the floating platform. All of it sits outside the collision outline and is
## merged by material after the build, so it costs a handful of draws.
const Rules = preload("res://scripts/arena_rules.gd")

static func perimeter(view, theme: Dictionary) -> void:
	var walls: Array = view.walls
	for i in range(walls.size()):
		var a2: Vector2 = walls[i]
		var b2: Vector2 = walls[(i + 1) % walls.size()]
		var a = Vector3(a2.x, 0.0, a2.y)
		var b = Vector3(b2.x, 0.0, b2.y)
		var edge = b - a
		var length_value = edge.length()
		var inward = Vector3(-edge.z, 0, edge.x).normalized()
		if inward.dot(-(a + b) * 0.5) < 0:
			inward = -inward
		var team = view.CYAN if (a.z + b.z) > 0 else view.CORAL
		var angle = -atan2(edge.z, edge.x)
		# A dark plinth under the whole run, then armoured blocks in two alternating tones.
		view.segment(view, a + Vector3.UP * 0.05, b + Vector3.UP * 0.05, 0.64, 0.1, theme.frame)
		var count = maxi(1, int(round(length_value / 0.95)))
		for n in range(count):
			var from = a.lerp(b, float(n) / count)
			var to = a.lerp(b, float(n + 1) / count)
			var block = view.box(view, (from + to) * 0.5 + Vector3.UP * 0.27, Vector3(from.distance_to(to) - 0.06, 0.36, 0.52), theme.block if (n + i) % 2 == 0 else theme.block_alt, false, 0.06)
			block.rotation.y = angle
			# Bolted face plate towards the players and a tread plate on top.
			var plate = view.box(view, (from + to) * 0.5 + Vector3.UP * 0.27 + inward * 0.262, Vector3(from.distance_to(to) * 0.5, 0.16, 0.02), theme.frame, false, 0.01)
			plate.rotation.y = angle
		view.segment(view, a + Vector3.UP * 0.47, b + Vector3.UP * 0.47, 0.3, 0.045, theme.frame)
		# The neon strip on the inner face tells whose half this is.
		var strip = view.box(view, (a + b) * 0.5 + Vector3.UP * 0.33 + inward * 0.275, Vector3(length_value * 0.94, 0.045, 0.02), team, true, 0.008)
		strip.rotation.y = angle
		# Outer trim light, below the rim, in the theme accent.
		view.segment(view, a * Vector3(1.1, 0, 1.04) - Vector3.UP * 0.35, b * Vector3(1.1, 0, 1.04) - Vector3.UP * 0.35, 0.07, 0.04, theme.accent, true)
	# Corner posts: dark pillars capped with a team light.
	for i in range(walls.size()):
		var c: Vector2 = walls[i]
		var at = Vector3(c.x, 0, c.y)
		var team = view.CYAN if c.y > 0 else view.CORAL
		view.box(view, at + Vector3.UP * 0.36, Vector3(0.34, 0.72, 0.34), theme.frame, false, 0.06)
		view.box(view, at + Vector3.UP * 0.76, Vector3(0.28, 0.08, 0.28), theme.accent, true, 0.02)
		view.box(view, at + Vector3.UP * 0.5, Vector3(0.36, 0.05, 0.36), team, true, 0.01)

static func stadium(view, theme: Dictionary, quality: int) -> void:
	# Low stands on both long sides, stepping down and away from the platform, with a crowd
	# of little coloured figures and floodlight towers at the corners.
	var reach = Rules.HALF_LENGTH * 0.9
	for side in [-1, 1]:
		var base_x = side * (Rules.outline_x_at(view.walls, 0) + 2.2)
		for tier in range(3):
			var x = base_x + side * tier * 0.8
			var y = -2.6 + tier * 0.42
			view.box(view, Vector3(x, y, 0), Vector3(0.76, 0.4, reach * 2.0), theme.stand, false, 0.05)
			view.box(view, Vector3(x - side * 0.34, y + 0.21, 0), Vector3(0.06, 0.04, reach * 2.0), theme.accent if tier == 0 else theme.stand.lightened(0.15), tier == 0, 0.01)
		for z in [-1, 1]:
			# Team banners on poles at the ends of each stand.
			var pole = Vector3(base_x + side * 1.2, -1.2, z * (reach + 0.3))
			view.box(view, pole, Vector3(0.08, 2.6, 0.08), theme.frame, false, 0.02)
			view.box(view, pole + Vector3(-side * 0.02, 0.8, -z * 0.35), Vector3(0.04, 0.9, 0.62), view.CYAN if z > 0 else view.CORAL, false, 0.01)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var foot = Vector3(sx * (Rules.outline_x_at(view.walls, 0) + 4.8), -2.4, sz * (Rules.HALF_LENGTH + 0.6))
			view.box(view, foot + Vector3.UP * 1.8, Vector3(0.24, 3.6, 0.24), theme.frame, false, 0.05)
			view.box(view, foot + Vector3.UP * 3.7 + Vector3(-sx * 0.25, 0, 0), Vector3(0.8, 0.46, 0.14), theme.frame, false, 0.04)
			for k in range(3):
				view.box(view, foot + Vector3(-sx * (k * 0.24 - 0.02), 3.72, -sz * 0.09), Vector3(0.19, 0.32, 0.02), Color("fff4d6"), true, 0.01)
	crowd(view, theme, reach, quality)

static func crowd(view, theme: Dictionary, reach: float, quality: int) -> void:
	var spots: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = 2026
	for side in [-1, 1]:
		var base_x = side * (Rules.outline_x_at(view.walls, 0) + 2.2)
		for tier in range(3):
			var x = base_x + side * tier * 0.8
			var y = -2.6 + tier * 0.42 + 0.33
			var z = -reach + 0.2
			while z < reach - 0.2:
				if rng.randf() < 0.7:
					var tone: Color = theme.crowd[rng.randi() % theme.crowd.size()]
					spots.append([Vector3(x + rng.randf_range(-0.12, 0.12), y, z), tone.lerp(theme.stand, 0.35)])
				z += rng.randf_range(0.26, 0.4)
	var shape = BoxMesh.new()
	shape.size = Vector3(0.16, 0.26, 0.16)
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = shape
	multi.instance_count = spots.size()
	for i in range(spots.size()):
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, spots[i][0]))
		multi.set_instance_color(i, spots[i][1])
	var people = MultiMeshInstance3D.new()
	people.name = "Crowd"
	people.multimesh = multi
	people.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	people.material_override = mat
	people.set_meta("crowd", true)
	view.add_child(people)
