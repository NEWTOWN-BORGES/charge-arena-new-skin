extends RefCounted
## The 3 v 3 stadium: a bowl of stands all round the field, pitch-side LED boards, two giant
## screens, floodlight towers and a crowd of robot fans that jump when the match heats up.
##
## Built for a phone: the bowl is one mesh with vertex colours, the boards and screens are a
## handful of boxes, and the whole crowd (up to ~1500 fans, four different robots) is drawn by
## four MultiMeshes, one draw call each. Nothing here casts a shadow or runs per frame on the
## CPU: the fans' cheering is done in the vertex shader.

const TIERS = 6
const TIER_DEPTH = 0.95
const TIER_RISE = 0.55
const FIRST_GAP = 1.5
const SEAT_STEP = 0.46

const SHELL = Color("e9eef6")
const DARK = Color("232c3c")
const STAND_A = Color("33415e")
const STAND_B = Color("2b3750")
const RISER = Color("1b2333")

static func build(view, quality: int) -> void:
	var half = field_half(view.walls)
	var tiers: int = TIERS if quality > 0 else 4
	var bowl = bowl_mesh(half, tiers, view.CYAN, view.CORAL)
	var bowl_node = MeshInstance3D.new()
	bowl_node.name = "StadiumBowl"
	bowl_node.mesh = bowl
	bowl_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bowl_node.material_override = mat
	view.add_child(bowl_node)
	# The ground the stadium stands on, so it never floats in the sky.
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(240, 240)
	ground.mesh = plane
	ground.position.y = -0.32
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color("2a3a33")
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(ground)
	boards(view, half)
	screens(view, half, tiers)
	towers(view, half, tiers)
	crowd(view, half, tiers, quality)

static func field_half(walls: Array) -> Vector2:
	var half = Vector2.ZERO
	for p in walls:
		half.x = maxf(half.x, absf(p.x))
		half.y = maxf(half.y, absf(p.y))
	return half

# A rounded rectangle round the field, `offset` out from its edge, sampled evenly.
static func ring(half: Vector2, offset: float, samples: int) -> Array:
	var corner = 3.0 + offset
	var a = Vector2(half.x + offset - corner, half.y + offset - corner)
	var straight_x = a.x * 2.0
	var straight_y = a.y * 2.0
	var arc = PI * 0.5 * corner
	var total = 2.0 * (straight_x + straight_y) + 4.0 * arc
	var points: Array = []
	for i in range(samples):
		var d = total * i / float(samples)
		points.append(perimeter_point(a, corner, d, straight_x, straight_y, arc))
	return points

static func perimeter_point(a: Vector2, corner: float, d: float, sx: float, sy: float, arc: float) -> Array:
	# Walked anticlockwise from the middle of the near side: [position, outward normal].
	var legs = [sx * 0.5, arc, sy, arc, sx, arc, sy, arc, sx * 0.5]
	var k = 0
	while k < legs.size() - 1 and d > legs[k]:
		d -= legs[k]
		k += 1
	match k:
		0: return [Vector2(d, a.y + corner), Vector2(0, 1)]
		1: return corner_point(Vector2(a.x, a.y), corner, PI * 0.5 - d / corner)
		2: return [Vector2(a.x + corner, a.y - d), Vector2(1, 0)]
		3: return corner_point(Vector2(a.x, -a.y), corner, -d / corner)
		4: return [Vector2(a.x - d, -a.y - corner), Vector2(0, -1)]
		5: return corner_point(Vector2(-a.x, -a.y), corner, -PI * 0.5 - d / corner)
		6: return [Vector2(-a.x - corner, -a.y + d), Vector2(-1, 0)]
		7: return corner_point(Vector2(-a.x, a.y), corner, -PI - d / corner)
	return [Vector2(-a.x + d, a.y + corner), Vector2(0, 1)]

static func corner_point(center: Vector2, radius: float, angle: float) -> Array:
	var n = Vector2(cos(angle), sin(angle))
	return [center + n * radius, n]

static func bowl_mesh(half: Vector2, tiers: int, near_team: Color, far_team: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples = 160
	# The profile, from the field outwards: a low wall, then step after step up and back,
	# then the tall back wall the roof hangs from.
	var profile: Array = [[FIRST_GAP - 0.4, -0.3], [FIRST_GAP - 0.4, 0.25], [FIRST_GAP, 0.25]]
	for k in range(tiers):
		var o = FIRST_GAP + k * TIER_DEPTH
		var y = 0.25 + k * TIER_RISE
		profile.append([o, y + TIER_RISE])
		profile.append([o + TIER_DEPTH, y + TIER_RISE])
	var back = FIRST_GAP + tiers * TIER_DEPTH
	var top = 0.25 + tiers * TIER_RISE
	profile.append([back, top + 1.8])
	profile.append([back + 0.4, top + 1.8])
	profile.append([back + 0.4, -0.3])
	var rows: Array = []
	for step in profile:
		rows.append(ring(half, step[0], samples))
	for r in range(profile.size() - 1):
		var tread = absf(profile[r + 1][1] - profile[r][1]) < 0.01
		for i in range(samples):
			var j = (i + 1) % samples
			var p0: Vector2 = rows[r][i][0]
			var p1: Vector2 = rows[r][j][0]
			var q0: Vector2 = rows[r + 1][i][0]
			var q1: Vector2 = rows[r + 1][j][0]
			var y0: float = profile[r][1]
			var y1: float = profile[r + 1][1]
			# The near half is the cyan side's end of the ground, the far half the coral's.
			var mid = (p0 + p1) * 0.5
			var team = near_team if mid.y > 0 else far_team
			var tier = clampi(r / 2 - 1, 0, tiers)
			var color: Color
			if tread:
				color = (STAND_A if tier % 2 == 0 else STAND_B).lerp(team, 0.18 if tier % 3 == 0 else 0.08)
			else:
				color = RISER.lerp(team, 0.12)
			if r == 1:
				color = team.darkened(0.25)
			quad(st, Vector3(p0.x, y0, p0.y), Vector3(p1.x, y0, p1.y), Vector3(q1.x, y1, q1.y), Vector3(q0.x, y1, q0.y), color)
	st.generate_normals()
	return st.commit()

static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for v in [a, c, b, a, d, c]:
		st.set_color(color)
		st.add_vertex(v)

static func boards(view, half: Vector2) -> void:
	# Pitch-side LED boards on the low wall, glowing in the two team colours.
	var offset = FIRST_GAP - 0.42
	var pts = ring(half, offset, 96)
	for i in range(pts.size()):
		if i % 2 == 1:
			continue
		var p: Vector2 = pts[i][0]
		var n: Vector2 = pts[i][1]
		var color: Color = view.CYAN if p.y > 0 else view.CORAL
		if i % 8 == 0:
			color = Color("ffd23f")
		var board = view.box(view, Vector3(p.x, 0.36, p.y) - Vector3(n.x, 0, n.y) * 0.02, Vector3(0.9, 0.22, 0.04), color, true, 0.01)
		board.rotation.y = atan2(n.x, n.y)
		board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func screens(view, half: Vector2, tiers: int) -> void:
	# A giant screen over each end, above the top of the stands.
	var back = FIRST_GAP + tiers * TIER_DEPTH + 3.0
	var top = 0.25 + tiers * TIER_RISE + 3.2
	# Only over the far end: the near one stood between the camera and the field.
	for side in [-1]:
		var z = side * (half.y + back)
		var team: Color = view.CYAN if side > 0 else view.CORAL
		var frame = view.box(view, Vector3(0, top, z), Vector3(7.4, 3.2, 0.4), DARK, false, 0.08)
		frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var panel = view.box(view, Vector3(0, top, z - side * 0.22), Vector3(6.9, 2.7, 0.04), team.darkened(0.55), true, 0.01)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for leg in [-1, 1]:
			view.box(view, Vector3(leg * 2.8, top - 3.0, z), Vector3(0.3, 3.4, 0.3), DARK, false, 0.04)
		var label = view.world_label("CHARGE ARENA", Vector3(0, top + 0.35, z - side * 0.26), Color("ffd23f"), 96, false)
		label.rotation_degrees.y = 0 if side < 0 else 180
		var sub = view.world_label("3 VS 3", Vector3(0, top - 0.6, z - side * 0.26), Color.WHITE, 84, false)
		sub.rotation_degrees.y = label.rotation_degrees.y

static func towers(view, half: Vector2, tiers: int) -> void:
	# Floodlight towers at the four corners, their lamp banks facing the field.
	var reach = FIRST_GAP + tiers * TIER_DEPTH + 1.2
	var height = 0.25 + tiers * TIER_RISE + 5.5
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var foot = Vector3(sx * (half.x + reach), 0, sz * (half.y + reach))
			var mast = view.box(view, foot + Vector3.UP * height * 0.5, Vector3(0.35, height, 0.35), DARK, false, 0.05)
			mast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var head = Node3D.new()
			view.add_child(head)
			head.position = foot + Vector3.UP * height
			head.look_at_from_position(head.position, Vector3(0, 0, 0), Vector3.UP)
			view.box(head, Vector3.ZERO, Vector3(2.2, 1.2, 0.25), DARK, false, 0.05)
			for row in range(2):
				for col in range(4):
					view.box(head, Vector3((col - 1.5) * 0.5, (row - 0.5) * 0.5, -0.14), Vector3(0.4, 0.38, 0.04), Color("fff6dc"), true, 0.01)

# --- The crowd ------------------------------------------------------------------------------

const FAN_SHADER = """
shader_type spatial;
render_mode cull_back;
// COLOR (vertex): rgb = the part's own colour, a = what kind of part it is:
//   1.0 shell, painted with the fan's own colour (INSTANCE_CUSTOM.rgb)
//   0.5 a fixed part (screens, joints, the flag pole)
//   0.0 glowing (eyes, lamps), in the fan's colour lightened
// INSTANCE_CUSTOM.a = the fan's own phase, so the stand never jumps as one block.
uniform float cheer = 1.0;
varying vec4 part;
varying vec4 tint;
void vertex() {
	part = COLOR;
	tint = INSTANCE_CUSTOM;
	float ph = INSTANCE_CUSTOM.a * 6.2831;
	float jump = max(0.0, sin(TIME * (5.0 + INSTANCE_CUSTOM.a * 3.0) + ph * 3.0));
	VERTEX.y += jump * jump * 0.09 * cheer;
	VERTEX.x += sin(TIME * 2.0 + ph) * 0.012 * VERTEX.y;
}
void fragment() {
	if (part.a > 0.75) {
		ALBEDO = part.rgb * tint.rgb * 0.85;
		ROUGHNESS = 0.55;
	} else if (part.a > 0.25) {
		ALBEDO = part.rgb;
		ROUGHNESS = 0.6;
	} else {
		ALBEDO = mix(tint.rgb, vec3(1.0), 0.35);
		EMISSION = ALBEDO * 0.7;
	}
}
"""

const FAN_COLORS = ["ffd23f", "ff8a3d", "6fcf3f", "9b6bff", "3fb8ff", "ff5f95", "ff4d4d", "2fd6a8", "f2f5f7", "ffb21a", "4f6bff", "c86bff"]

static func crowd(view, half: Vector2, tiers: int, quality: int) -> void:
	var meshes = [screen_fan(), dome_fan(), chunky_fan(), flag_fan()]
	var spots: Array = [[], [], [], []]
	var rng = RandomNumberGenerator.new()
	rng.seed = 3303
	var step = SEAT_STEP if quality > 0 else SEAT_STEP * 1.4
	for k in range(tiers):
		var o = FIRST_GAP + k * TIER_DEPTH + TIER_DEPTH * 0.5
		var y = 0.25 + (k + 1) * TIER_RISE
		var corner = 3.0 + o
		var perimeter = 2.0 * ((half.x + o - corner) * 2.0 + (half.y + o - corner) * 2.0) + TAU * corner
		var count = int(perimeter / step)
		var pts = ring(half, o, count)
		for i in range(count):
			if rng.randf() < 0.14:
				continue
			var p: Vector2 = pts[i][0]
			var n: Vector2 = pts[i][1]
			var variant = rng.randi() % 4
			if variant == 3 and rng.randf() < 0.6:
				variant = rng.randi() % 3
			var team: Color = view.CYAN if p.y > 0 else view.CORAL
			var color = Color(FAN_COLORS[rng.randi() % FAN_COLORS.size()])
			# A third of each end wears its team's colour.
			if rng.randf() < 0.35:
				color = team.lightened(0.15)
			var scale = rng.randf_range(0.9, 1.15)
			var basis = Basis(Vector3.UP, atan2(-n.x, -n.y) + rng.randf_range(-0.25, 0.25)).scaled(Vector3.ONE * scale)
			var at = Vector3(p.x + rng.randf_range(-0.05, 0.05), y, p.y)
			spots[variant].append([Transform3D(basis, at), Color(color.r, color.g, color.b, rng.randf())])
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = FAN_SHADER
	mat.shader = shader
	for v in range(4):
		if spots[v].is_empty():
			continue
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = meshes[v]
		multi.instance_count = spots[v].size()
		for i in range(spots[v].size()):
			multi.set_instance_transform(i, spots[v][i][0])
			multi.set_instance_custom_data(i, spots[v][i][1])
		var node = MultiMeshInstance3D.new()
		node.name = "Fans%d" % v
		node.multimesh = multi
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("crowd", true)
		view.add_child(node)

# Four fans, each a few boxes and prisms merged into one mesh (~70-110 triangles), facing -Z.

static func cube(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h = size * 0.5
	var c = [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var faces = [[0, 3, 2, 1], [5, 6, 7, 4], [4, 7, 3, 0], [1, 2, 6, 5], [3, 7, 6, 2], [4, 0, 1, 5]]
	for f in faces:
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.set_color(color)
			st.add_vertex(center + c[idx])

static func prism(st: SurfaceTool, center: Vector3, radius: float, height: float, sides: int, color: Color) -> void:
	# An upright n-sided column (a low-poly cylinder) with its caps.
	var top = center.y + height * 0.5
	var bottom = center.y - height * 0.5
	for i in range(sides):
		var a0 = TAU * i / sides
		var a1 = TAU * (i + 1) / sides
		var p0 = Vector3(cos(a0) * radius, 0, sin(a0) * radius) + Vector3(center.x, 0, center.z)
		var p1 = Vector3(cos(a1) * radius, 0, sin(a1) * radius) + Vector3(center.x, 0, center.z)
		var tri = [Vector3(p0.x, bottom, p0.z), Vector3(p0.x, top, p0.z), Vector3(p1.x, top, p1.z),
			Vector3(p0.x, bottom, p0.z), Vector3(p1.x, top, p1.z), Vector3(p1.x, bottom, p1.z),
			Vector3(center.x, top, center.z), Vector3(p1.x, top, p1.z), Vector3(p0.x, top, p0.z)]
		for v in tri:
			st.set_color(color)
			st.add_vertex(v)

static func finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

static func shell(c := Color.WHITE) -> Color:
	return Color(c.r, c.g, c.b, 1.0)

static func fixed(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.5)

static func glow() -> Color:
	return Color(1, 1, 1, 0.0)

static func screen_fan() -> ArrayMesh:
	# BIT's cousins: a box body, a screen head with two glowing eyes and a signal antenna.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cube(st, Vector3(0, 0.13, 0), Vector3(0.26, 0.24, 0.18), shell())
	cube(st, Vector3(0, 0.04, 0), Vector3(0.2, 0.08, 0.14), fixed(DARK))
	cube(st, Vector3(0, 0.37, 0), Vector3(0.3, 0.22, 0.22), shell())
	cube(st, Vector3(0, 0.37, -0.112), Vector3(0.24, 0.15, 0.01), fixed(Color("10141c")))
	cube(st, Vector3(-0.055, 0.38, -0.12), Vector3(0.04, 0.05, 0.01), glow())
	cube(st, Vector3(0.055, 0.38, -0.12), Vector3(0.04, 0.05, 0.01), glow())
	cube(st, Vector3(0.08, 0.53, 0), Vector3(0.02, 0.12, 0.02), fixed(DARK))
	cube(st, Vector3(0.08, 0.6, 0), Vector3(0.05, 0.05, 0.05), glow())
	# Arms up, cheering.
	cube(st, Vector3(-0.17, 0.28, 0), Vector3(0.06, 0.22, 0.06), shell())
	cube(st, Vector3(0.17, 0.28, 0), Vector3(0.06, 0.22, 0.06), shell())
	return finish(st)

static func dome_fan() -> ArrayMesh:
	# Round ones: a barrel body, a domed head with a visor band.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	prism(st, Vector3(0, 0.13, 0), 0.13, 0.24, 8, shell())
	prism(st, Vector3(0, 0.27, 0), 0.1, 0.04, 8, fixed(DARK))
	prism(st, Vector3(0, 0.38, 0), 0.14, 0.18, 8, shell())
	prism(st, Vector3(0, 0.49, 0), 0.1, 0.05, 8, shell())
	cube(st, Vector3(0, 0.39, -0.12), Vector3(0.2, 0.06, 0.04), glow())
	cube(st, Vector3(-0.17, 0.4, 0), Vector3(0.05, 0.1, 0.1), fixed(DARK))
	cube(st, Vector3(0.17, 0.4, 0), Vector3(0.05, 0.1, 0.1), fixed(DARK))
	return finish(st)

static func chunky_fan() -> ArrayMesh:
	# The heavy ones: wide shoulders, a small head with one big eye.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cube(st, Vector3(0, 0.12, 0), Vector3(0.34, 0.22, 0.2), shell())
	cube(st, Vector3(-0.2, 0.22, 0), Vector3(0.1, 0.1, 0.14), fixed(DARK))
	cube(st, Vector3(0.2, 0.22, 0), Vector3(0.1, 0.1, 0.14), fixed(DARK))
	cube(st, Vector3(0, 0.33, 0), Vector3(0.18, 0.16, 0.16), shell())
	prism(st, Vector3(0, 0.34, -0.06), 0.045, 0.06, 6, glow())
	cube(st, Vector3(-0.22, 0.36, -0.02), Vector3(0.06, 0.2, 0.06), shell())
	cube(st, Vector3(0.22, 0.36, -0.02), Vector3(0.06, 0.2, 0.06), shell())
	return finish(st)

static func flag_fan() -> ArrayMesh:
	# A screen fan waving a flag in its own colour.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cube(st, Vector3(0, 0.13, 0), Vector3(0.24, 0.24, 0.18), shell())
	cube(st, Vector3(0, 0.36, 0), Vector3(0.26, 0.2, 0.2), shell())
	cube(st, Vector3(0, 0.36, -0.102), Vector3(0.2, 0.13, 0.01), fixed(Color("10141c")))
	cube(st, Vector3(-0.05, 0.37, -0.11), Vector3(0.035, 0.045, 0.01), glow())
	cube(st, Vector3(0.05, 0.37, -0.11), Vector3(0.035, 0.045, 0.01), glow())
	cube(st, Vector3(0.18, 0.45, 0), Vector3(0.025, 0.7, 0.025), fixed(Color("c9d2de")))
	cube(st, Vector3(0.36, 0.68, 0), Vector3(0.34, 0.22, 0.015), shell())
	return finish(st)
