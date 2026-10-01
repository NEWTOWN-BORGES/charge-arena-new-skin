extends RefCounted
## Analytic, pooled shock fronts. Every card shares the arena's existing effect
## limit; particles and lamps still use its prewarmed 2.9.5 pools.
const Rules = preload("res://scripts/arena_rules.gd")
const FRONT = preload("res://shaders/combat_front.gdshader")
const ECLIPSE = preload("res://shaders/combat_eclipse.gdshader")
const POOL_SIZE = 28
const META = "combat_finish_pool"
# Readable silhouettes shared by cast markers, charge feedback and UI previews.
# Basic ultimates retain their kit's silhouette but add a double rank chevron.
const SIGNATURES = {
	"blast": [1, 1], "rapid": [2, 0], "air": [3, 0], "ghost": [4, 4],
	"laser": [5, 2], "rebuild": [6, 3], "mirror": [7, 0], "walls": [8, 0],
	"stun": [9, 2], "weld": [10, 3], "thorns": [11, 3], "freeze": [12, 2],
	"magnet": [13, 2], "pierce": [14, 0], "sniper": [15, 0], "cluster": [16, 1],
	"drain": [17, 4], "ricochet": [18, 0], "emp": [19, 2], "mortar": [20, 1],
	"dome": [21, 0], "slow": [22, 0], "sponge": [23, 0], "immune": [24, 0],
	"sun_ray": [25, 1], "sun_beam": [25, 2], "meteors": [26, 1],
	"thunder": [9, 2], "singularity": [32, 4], "sentries": [27, 0],
	"bloom": [28, 3], "plunder": [29, 0], "surge": [30, 2], "volley": [31, 1],
	"plating": [7, 0], "b_charge": [1, 1], "b_quick": [2, 0], "b_fan": [3, 0],
	"b_salvo": [3, 1], "b_hail": [26, 1], "b_spark": [9, 2], "b_patch": [10, 3],
	"b_bar": [8, 0], "b_push": [19, 2], "b_slow": [12, 2], "b_forge": [31, 1],
	"b_aim": [13, 2], "b_drill": [14, 0],
}

static func signature_for(id: String) -> Dictionary:
	var identity: Array = SIGNATURES.get(id, [0, 0])
	return {
		"emblem": int(identity[0]), "motif": int(identity[1]), "tint": Rules.power_color(id),
		"rank": 1.0 if id.begins_with("b_") else (0.5 if id in ["sun_beam", "plating"] else 0.0),
		"rising": id in ["bloom", "meteors", "b_hail", "sun_ray", "sun_beam", "volley", "sentries"],
		"inward": id in ["singularity", "plunder", "drain", "sponge"],
	}

static func cast(view, at: Vector2, id: String, is_ultimate: bool = false, pilot: int = -1) -> MeshInstance3D:
	var signature = signature_for(id)
	var caster: int = view.cast_pilot(at, pilot)
	var origin: Vector3 = view.cast_origin(at, caster)
	# One shared card carries both the silhouette and its expanding front. A cast
	# never adds a node, even when all six squad pilots cast in the same frame.
	var radius = 1.85 if is_ultimate else 1.2
	var life = 0.76 if is_ultimate else 0.48
	var motif = int(signature.motif)
	# The opaque dark eclipse belongs to the physical vortex. Its cast badge uses
	# the additive front so a buff badge cannot cover a pilot or an enemy bullet.
	var node = card(view, Vector2(origin.x, origin.z), radius, signature.tint, life, 2 if motif == 4 else motif, true, origin.y)
	if node != null:
		view.effects.back()["cast_pilot"] = caster
		var material: ShaderMaterial = node.material_override
		material.set_shader_parameter("emblem", float(signature.emblem))
		material.set_shader_parameter("rank", signature.rank)
		material.set_shader_parameter("strength", 1.05 if is_ultimate else 0.78)
	return node

static func prepare(view) -> void:
	if view.has_meta(META): return
	var pool: Array[MeshInstance3D] = []
	var quad = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	for i in range(POOL_SIZE):
		var card = MeshInstance3D.new()
		card.mesh = quad
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.ignore_occlusion_culling = true
		var front = ShaderMaterial.new()
		front.shader = FRONT
		var eclipse = ShaderMaterial.new()
		eclipse.shader = ECLIPSE
		card.set_meta("front", front)
		card.set_meta("eclipse", eclipse)
		card.material_override = front
		card.hide()
		view.add_child(card)
		pool.append(card)
	view.set_meta(META, pool)
	view.set_meta("combat_finish_last", {})
	# The two shader variants draw transparently during arena preparation, so the
	# first actual ultimate does not also have to compile its render pipeline.
	for is_void in [false, true]:
		var card: MeshInstance3D = pool.pop_back()
		card.material_override = card.get_meta("eclipse" if is_void else "front")
		card.material_override.set_shader_parameter("age", 1.0)
		card.position = Vector3(0, 1, 0)
		card.rotation.x = -PI * 0.5
		card.show()
		view.effects.append({"node": card, "v": Vector3.ZERO, "ttl": 0.1, "life": 0.1, "gravity": false, "base": Vector3.ONE, "keep": true, "combat_finish": true, "warm": true})

static func animate(effect: Dictionary, remaining: float, view = null) -> void:
	var material: ShaderMaterial = effect.node.material_override
	material.set_shader_parameter("age", 1.0 if effect.get("warm", false) else 1.0 - remaining)
	if view != null and effect.has("cast_pilot"):
		var pilot: int = int(effect.cast_pilot)
		if pilot >= 0 and pilot < view.units.size():
			var position: Vector3 = view.units[pilot].position
			effect.node.position = view.cast_origin(Vector2(position.x, position.z), pilot)
			effect.node.basis = view.global_basis.inverse() * view.camera.global_basis
			effect.node.scale = effect.base

static func recycle(view, card: MeshInstance3D) -> void:
	card.hide()
	var pool: Array = view.get_meta(META)
	pool.append(card)

static func active_count(view) -> int:
	return POOL_SIZE - (view.get_meta(META) as Array).size() if view.has_meta(META) else 0

static func card(view, at: Vector2, radius: float, tint: Color, life: float, motif: int = 0, billboard: bool = false, height: float = 0.09) -> MeshInstance3D:
	if not view.has_meta(META): prepare(view)
	var pool: Array = view.get_meta(META)
	if pool.is_empty() or view.effects.size() >= view.effect_limit or active_count(view) >= [8, 18, 28][view.quality_level]: return null
	var node: MeshInstance3D = pool.pop_back()
	node.position = Vector3(at.x, height, at.y)
	node.basis = view.global_basis.inverse() * view.camera.global_basis if billboard else Basis(Vector3.RIGHT, -PI * 0.5)
	node.scale = Vector3.ONE * radius
	var material: ShaderMaterial = node.get_meta("eclipse" if motif == 4 else "front")
	node.material_override = material
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("age", 0.0)
	material.set_shader_parameter("seed", fmod(at.x * 1.73 + at.y * 2.13, TAU))
	material.set_shader_parameter("detail_quality", 0.0 if view.quality_level == 0 else 1.0)
	if motif != 4:
		material.set_shader_parameter("motif", float(motif))
		material.set_shader_parameter("emblem", 0.0)
		material.set_shader_parameter("rank", 0.0)
		material.set_shader_parameter("strength", 1.0)
		var core_tint = Color("ffe6a3") if motif == 1 else (Color("d0ffe7") if motif == 3 else Color("edfaff"))
		material.set_shader_parameter("hot", tint.lerp(core_tint, 0.72))
	node.show()
	view.effects.append({"node": node, "v": Vector3.ZERO, "ttl": life, "life": life, "gravity": false, "base": node.scale, "keep": true, "combat_finish": true})
	return node

static func impact(view, at: Vector2, radius: float, tint: Color, motif: int = 1, life: float = 0.48) -> void:
	card(view, at, radius, tint, life, motif)
	if view.quality_level > 0:
		card(view, at, minf(radius * 0.66, 1.2), tint, 0.19, 6, true, 0.44)

static func beam(view, at: Vector2, heading: Vector2, length_value: float, width: float, tint: Color) -> void:
	if length_value < 0.05: return
	var middle = at + heading * length_value * 0.5
	var node = card(view, middle, 1.0, tint, 0.17, 5, false, 0.62)
	if node == null: return
	# Local X spans the beam; local Y follows its path on the arena floor.
	var direction = Vector3(heading.x, 0, heading.y).normalized()
	node.basis = Basis(Vector3(direction.z, 0, -direction.x), direction, Vector3.UP)
	node.scale = Vector3(width, length_value * 0.5, 1.0)

static func wall_center(event_data: Dictionary, rules) -> Vector2:
	var result: Vector2 = event_data.get("p", Vector2.ZERO)
	if rules == null or not event_data.has("bricks") or event_data.bricks.is_empty(): return result
	result = Vector2.ZERO
	for index in event_data.bricks: result += Vector2(rules.bricks[int(index)].p)
	return result / float(event_data.bricks.size())

static func motif_for(id: String) -> int:
	if SIGNATURES.has(id): return int(SIGNATURES[id][1])
	if id in ["shock", "shock_wave"]: return 2
	if id == "swallow": return 4
	return 0

static func event_pilot(view, data: Dictionary, rules = null) -> int:
	var team = clampi(int(data.get("team", 0)), 0, 1)
	# Events are played before update_state copies the new caster into the view.
	# Read the rules here so a wingman's ultimate cannot flash on its leader.
	var pilot = int(data.get("pilot", team))
	if not data.has("pilot") and String(data.get("kind", "")) == "ultimate" and rules != null:
		pilot = int(rules.caster[team])
	return view.cast_pilot(Vector2(data.get("p", Vector2.ZERO)), pilot)

static func event(view, data: Dictionary, rules = null) -> void:
	if not data.has("p"): return
	if not view.has_meta(META): prepare(view)
	var kind = String(data.get("kind", ""))
	var at: Vector2 = data.p
	var team = clampi(int(data.get("team", 0)), 0, 1)
	var tint: Color = view.shot_colors[team]
	var id = String(data.get("id", kind))
	var pilot = event_pilot(view, data, rules)
	# A machine gun or a mass heal must not turn every brick into a new full-screen
	# effect. Essential gameplay feedback continues through the original callbacks.
	var last: Dictionary = view.get_meta("combat_finish_last")
	# Different powers can be cast by one squad in the same frame. They must each
	# retain their semantic cue rather than throttling each other as "power0".
	var key = kind + str(team) + (id + str(pilot) if kind in ["power", "ultimate"] else "")
	var spacing = 0.08 if kind in ["brick_hit", "brick", "bounce", "spent", "laser"] else 0.035
	var now: float = view.clock
	if now - float(last.get(key, -100.0)) < spacing: return
	last[key] = now
	match kind:
		"player_hit", "mirror":
			card(view, at, 0.42, tint, 0.18, 6, true, 0.54)
		# Bricks get no card: with forty a side breaking all match long, each card was one
		# more transparent draw on a phone. The arena's own flash and ring say enough.
		"boost":
			impact(view, at, 0.8, Color("ffce63"), 2, 0.28)
			view.flash(Vector3(at.x, 0.7, at.y), Color("ffd175"), 2.3, 0.13, 3.2)
		"explosion":
			impact(view, at, float(data.get("radius", 1.2)) * 1.05, Color("ff843c"), 1)
		"meteor":
			var radius = float(data.get("radius", 1.2)) * 1.7
			view.schedule(0.34, func(): impact(view, at, radius, Color("ffad53"), 1, 0.6))
		"thunder":
			var radius = float(data.get("radius", 1.0)) * 1.7
			view.schedule(0.16, func(): impact(view, at, radius, Color("00cfff"), 2, 0.46))
		"bloom", "weld", "rebuild":
			var middle = wall_center(data, rules)
			card(view, middle, 3.0 if kind == "bloom" else 1.75, Color("39f29b"), 0.85, 3)
		"singularity":
			card(view, at, 2.0, Color("a96bff"), minf(float(data.get("seconds", 1.2)), 1.6), 4)
		"singularity_wave", "swallow":
			impact(view, at, 2.3, Color("c5a1ff"), 2, 0.55)
		"laser":
			var path: Array = data.get("path", [])
			if path.size() >= 2:
				for i in range(mini(path.size() - 1, 3)):
					var a: Vector2 = path[i]
					var b: Vector2 = path[i + 1]
					beam(view, a, a.direction_to(b), a.distance_to(b), 0.5, Color("24d8ff"))
			else:
				beam(view, at, data.get("heading", Vector2.UP), float(data.get("length", 8.0)), 0.5, Color("24d8ff"))
		"sun_ray":
			impact(view, at + Vector2(data.get("heading", Vector2.UP)) * 0.9, 1.2, Color("ffcc63"), 1, 0.34)
		"ultimate":
			cast(view, at, id, true, pilot)
		"power":
			cast(view, at, id, false, pilot)
		"plunder_land":
			card(view, at, 1.85, Color("76f6dd"), 0.58, 0)
		"freeze":
			var ice = cast(view, at, "freeze", false, pilot)
			if ice != null:
				ice.scale *= 1.3
				view.effects.back()["base"] = ice.scale
		"shock_wave", "shock":
			card(view, at, 2.2, Color("b2a0ff"), 0.48, 2)
		"emp":
			card(view, at, 2.25, Color("7fb2ff"), 0.52, 2)
			if data.has("target"): cast(view, Vector2(data.target), "emp", false, 1 - team)
		"sniper_hit":
			card(view, at, 0.72, Color("fff17a"), 0.2, 6, true, 0.55)
		"cluster", "mortar":
			impact(view, at, float(data.get("radius", 1.3)) * 1.1, Color("ff9e42"), 1, 0.48)
		"immune_block", "absorb":
			card(view, at, 0.58, Color("b3f5ff") if kind == "immune_block" else Color("ffda62"), 0.24, 0, true, 0.42)
