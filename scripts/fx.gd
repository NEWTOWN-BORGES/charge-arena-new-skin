extends Node3D
## GPU particle batches for the arena: glows, sparks, stars, floor rings, smoke and debris.
## A particle is written into a ring buffer once when it is born; its shader animates it
## from the launch packed into the instance (see shaders/fx_particle.gdshader). Every kind is
## one MultiMesh, one draw, however many particles are alive.
const PARTICLE = preload("res://shaders/fx_particle.gdshader")
const SMOKE = preload("res://shaders/fx_smoke.gdshader")
const DEBRIS = preload("res://shaders/fx_debris.gdshader")
const KINDS = {"glow": 0, "spark": 1, "star": 2, "ring": 3}
const CAPACITY = {"glow": 384, "spark": 320, "star": 64, "ring": 48, "smoke": 160, "debris": 128}

var now = 0.0
var quality = 2
var batches = {}
var heads = {}
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 7
	for name in CAPACITY:
		var batch = MultiMeshInstance3D.new()
		batch.name = "Fx_" + name
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		if name == "debris":
			var cube = BoxMesh.new()
			cube.size = Vector3.ONE
			multi.mesh = cube
		else:
			var card = QuadMesh.new()
			card.size = Vector2.ONE
			multi.mesh = card
		multi.instance_count = CAPACITY[name]
		# Instances move far from their launch point: never let the batch be culled.
		multi.custom_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 60, 120))
		for i in range(multi.instance_count):
			multi.set_instance_custom_data(i, Color(-100.0, 1.0, 0.0, 0.0))
		batch.multimesh = multi
		var mat = ShaderMaterial.new()
		mat.shader = SMOKE if name == "smoke" else (DEBRIS if name == "debris" else PARTICLE)
		if KINDS.has(name):
			mat.set_shader_parameter("kind", KINDS[name])
		batch.material_override = mat
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		batches[name] = batch
		heads[name] = 0

func tick(time: float) -> void:
	now = time
	for batch in batches.values():
		batch.material_override.set_shader_parameter("now", now)

func scale_count(count: int) -> int:
	return maxi(1, int(round(count * [0.45, 0.75, 1.0][clampi(quality, 0, 2)])))

func emit(kind: String, at: Vector3, velocity: Vector3, color: Color, size_from: float, size_to: float, life: float, gravity: float = 0.0, drag: float = 0.0, stretch: float = 0.0, rise: float = 0.0, spin: float = 0.0) -> void:
	var multi: MultiMesh = batches[kind].multimesh
	var slot: int = heads[kind]
	heads[kind] = (slot + 1) % multi.instance_count
	multi.set_instance_transform(slot, Transform3D(Basis(velocity, Vector3(size_from, size_to, gravity), Vector3(drag, stretch, rise)), at))
	multi.set_instance_color(slot, color)
	multi.set_instance_custom_data(slot, Color(now, life, rng.randf(), spin))

# --- building blocks ---------------------------------------------------------------------
func glow(at: Vector3, color: Color, size: float, life: float, grow: float = 1.6) -> void:
	emit("glow", at, Vector3.ZERO, color, size * 0.5, size * grow, life)

func star(at: Vector3, color: Color, size: float, life: float) -> void:
	emit("star", at, Vector3.ZERO, color, size * 0.4, size, life, 0.0, 0.0, 0.0, 0.0, rng.randf_range(-2.0, 2.0))

func ring(at: Vector3, color: Color, radius: float, life: float) -> void:
	emit("ring", Vector3(at.x, maxf(at.y, 0.03), at.z), Vector3.ZERO, color, radius * 0.35, radius * 2.0, life)

func sparks(at: Vector3, color: Color, count: int, speed: float, size: float, life: float, direction: Vector3 = Vector3.UP, cone: float = 180.0, gravity: float = -6.0) -> void:
	for i in range(scale_count(count)):
		var dir = cone_direction(direction, cone)
		emit("spark", at, dir * speed * rng.randf_range(0.4, 1.0), color, size, size * 0.2, life * rng.randf_range(0.65, 1.2), gravity, 2.5, 0.09)

func embers(at: Vector3, color: Color, count: int, speed: float, size: float, life: float, direction: Vector3 = Vector3.UP, cone: float = 180.0, gravity: float = -3.0) -> void:
	for i in range(scale_count(count)):
		var dir = cone_direction(direction, cone)
		emit("glow", at + dir * size * 0.5, dir * speed * rng.randf_range(0.3, 1.0), color, size * rng.randf_range(0.6, 1.2), size * 0.1, life * rng.randf_range(0.6, 1.25), gravity, 3.0)

func smoke(at: Vector3, color: Color, count: int, size: float, life: float, spread: float = 0.4, rise: float = 0.45) -> void:
	for i in range(scale_count(count)):
		var dir = cone_direction(Vector3.UP, 80.0)
		emit("smoke", at + Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread)), dir * rng.randf_range(0.4, 1.2), Color(color, 0.55), size * 0.5, size * rng.randf_range(1.4, 2.2), life * rng.randf_range(0.7, 1.2), 0.0, 2.2, 0.0, rise, rng.randf_range(-0.6, 0.6))

func debris(at: Vector3, colors: Array, count: int, speed: float, size: float, life: float, push: Vector3 = Vector3.ZERO) -> void:
	# `push` tips the spray the way the blow was going, so a break shows where it came from.
	var axis = (Vector3.UP + push).normalized()
	for i in range(scale_count(count)):
		var dir = cone_direction(axis, 70.0 if push == Vector3.ZERO else 50.0)
		var tone: Color = colors[i % colors.size()]
		emit("debris", at, dir * speed * rng.randf_range(0.5, 1.0), tone, size * rng.randf_range(0.7, 1.3), 0.0, life * rng.randf_range(0.8, 1.2), -9.0, 0.0, 0.0, 0.0, rng.randf_range(6.0, 14.0))

func cone_direction(direction: Vector3, cone: float) -> Vector3:
	# A random direction within `cone` degrees of `direction`.
	var axis = direction.normalized()
	var spread = deg_to_rad(cone) * sqrt(rng.randf())
	var around = rng.randf() * TAU
	var side = axis.cross(Vector3.RIGHT if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var up = axis.cross(side)
	return (axis * cos(spread) + (side * cos(around) + up * sin(around)) * sin(spread)).normalized()

# --- composed moments ----------------------------------------------------------------------
func muzzle(at: Vector3, direction: Vector3, color: Color, duration: float, spark_count: int, size: float = 0.85) -> void:
	# The shot leaving the barrel, with a shape and a direction: a white-hot core for a
	# frame or two, a coloured bloom opening a little ahead of it, one bright streak down
	# the line of fire and a few sparks in a narrow cone. Gone in about a tenth of a second.
	var forward = direction.normalized()
	star(at, Color(1.0, 0.97, 0.9), size, duration)
	glow(at + forward * 0.18, color.lightened(0.2), size * 1.2, duration * 1.9, 1.4)
	glow(at, Color(1.0, 0.95, 0.85), size * 0.5, duration * 0.9, 1.2)
	emit("spark", at, forward * 12.0, color.lightened(0.45), size * 0.3, size * 0.06, duration * 2.4, 0.0, 5.0, 0.2)
	for i in range(scale_count(spark_count)):
		var dir = cone_direction(forward, 24.0)
		emit("spark", at, dir * rng.randf_range(4.5, 8.0), color.lightened(0.25), 0.06, 0.015, rng.randf_range(0.07, 0.13), -2.0, 6.0, 0.1)

func impact(at: Vector3, heading: Vector3, color: Color, material: String, amount: int, size: float = 0.7) -> void:
	# Where a shot lands, in the language of what it hit. `heading` is the shot's direction
	# at the moment of contact; sparks leave against it (back towards the shooter) or along
	# it after a bounce, never in a plain round puff.
	var back = (-heading).normalized() if heading != Vector3.ZERO else Vector3.UP
	match material:
		"brick":
			# THOCK: one short flash on the face. Nothing else - bricks are hit constantly and
			# a phone pays for every transparent pixel.
			star(at, color.lightened(0.5), size, 0.07)
		"metal":
			# TANG: bright sparks raking off in the direction the shot bounced away.
			star(at, Color(1.0, 0.95, 0.8), size, 0.07)
			var along = heading.normalized() if heading != Vector3.ZERO else Vector3.UP
			for i in range(scale_count(amount + 2)):
				var dir = cone_direction((along + Vector3.UP * 0.25).normalized(), 30.0)
				emit("spark", at, dir * rng.randf_range(6.0, 10.0), Color(1.0, 0.82, 0.45), 0.08, 0.015, rng.randf_range(0.12, 0.22), -9.0, 3.5, 0.14)
		"shield":
			# BWOM: a ripple standing up off the surface and a soft glow, no chips.
			ring(Vector3(at.x, maxf(at.y - 0.4, 0.04), at.z), color, 0.5, 0.3)
			glow(at, color, 0.7, 0.2, 1.8)
			star(at, color.lightened(0.4), size * 0.8, 0.1)
		"wall":
			# A dry knock: a small flash and a few sparks along the new line.
			var along = heading.normalized() if heading != Vector3.ZERO else Vector3.UP
			star(at, color.lightened(0.3), size * 0.7, 0.06)
			for i in range(scale_count(maxi(2, amount / 2))):
				var dir = cone_direction(along, 28.0)
				emit("spark", at, dir * rng.randf_range(4.0, 7.0), color.lightened(0.3), 0.06, 0.015, rng.randf_range(0.08, 0.14), -4.0, 4.0, 0.12)
		_:
			hit(at, color, 0.8)

func break_apart(at: Vector3, heading: Vector3, colors: Array, amount: int) -> void:
	# CRACK, kept light on purpose: a white flash and a ring on the floor, two particles in
	# all. No chunks, sparks or smoke - breaking bricks is the most frequent event of a
	# match and those were costing frames on phones.
	var tint: Color = colors[1] if colors.size() > 1 else Color.WHITE
	star(at, Color(1.0, 0.96, 0.88), 0.9, 0.09)
	ring(Vector3(at.x, 0.05, at.z), tint.lightened(0.2), 0.42, 0.26)

func pulse(at: Vector3, color: Color, radius: float, life: float) -> void:
	# A wave of energy on the floor, for the defence falling and the goal.
	ring(Vector3(at.x, 0.06, at.z), color, radius, life)
	glow(Vector3(at.x, 0.5, at.z), color, radius * 0.7, life * 0.6, 1.8)

func hit(at: Vector3, color: Color, strength: float = 1.0) -> void:
	# A shot landing: a hot star, a flash and a spray of sparks.
	star(at, color.lightened(0.3), 0.55 * strength, 0.16)
	glow(at, color, 0.7 * strength, 0.2)
	sparks(at, color.lightened(0.2), int(7 * strength), 5.5 * strength, 0.12, 0.3)

func blast(at: Vector3, color: Color, radius: float) -> void:
	# An explosion: white core, coloured fireball, shock ring on the floor, embers and smoke.
	glow(at, Color(1, 0.96, 0.85), radius * 0.9, 0.18, 1.8)
	glow(at, color, radius * 1.3, 0.38, 1.5)
	star(at, color.lightened(0.4), radius * 1.4, 0.22)
	ring(Vector3(at.x, 0.05, at.z), color, radius, 0.45)
	sparks(at, color.lightened(0.25), 20, 9.0, 0.16, 0.45, Vector3.UP, 95.0)
	embers(at, color, 14, 4.0, 0.22, 0.6, Vector3.UP, 90.0, -2.5)
	smoke(Vector3(at.x, 0.3, at.z), Color("3a3440").lerp(color, 0.15), 6, radius * 0.6, 1.1, radius * 0.4)
