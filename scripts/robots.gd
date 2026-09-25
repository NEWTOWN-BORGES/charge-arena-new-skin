extends RefCounted
## The robot cast. Parts are modelled in Blender (tools/blender/robot_kit.py writes
## art/robots/kit.glb), recipes live in art/robots/roster.json, and this script assembles
## a pilot from them: one merged mesh per colour role for each moving group (body, legs,
## weapon, spinning crest), an ink outline per group and a face screen of its own.
const KIT = preload("res://art/robots/kit.glb")
const ROSTER = preload("res://art/robots/roster.json")
const PAINT = preload("res://shaders/robot_paint.gdshader")
const PAINT_LOW = preload("res://shaders/robot_paint_low.gdshader")
const FACE = preload("res://shaders/robot_face.gdshader")
const OUTLINE = preload("res://shaders/robot_outline.gdshader")
const LEG_PIVOT = Vector3(0.19, 0.40, 0.0)
const MUZZLE = Vector3(0.29, 0.70, -0.86)
const STATION_SKIN = 100
const EYES = ["capsule", "dots", "bars", "square", "slant", "monocle", "visor", "equalizer", "single", "rings", "stars", "arcs"]
# Tops and crests are modelled for a head whose top is at HEAD_TOP and centre at HEAD_CENTER;
# the roster's "heads" table says where each real head sits, and the parts follow it.
const HEAD_TOP = 1.8
const HEAD_CENTER = 1.44
# Crests that turn in their own plane, behind the head, pivot about these centres.
const DISC_SPINS = {"spin_rays": Vector3(0, 1.44, 0.42), "spin_halo": Vector3(0, 1.5, 0.45)}
const CENTRED_SPINS = ["spin_rays", "spin_halo", "spin_orbit"]
const GLOSS = {"shell": 0.6, "trim": 0.55, "dark": 0.25, "metal": 0.8, "team": 0.55, "glow": 0.0}
const OUTLINE_GROUP = "robot_outline"

static var _parts: Dictionary = {}
static var _merged: Dictionary = {}

static func cast() -> Array:
	return ROSTER.data.cast

static func recipe(skin: int) -> Dictionary:
	var data: Dictionary = ROSTER.data
	if skin >= STATION_SKIN:
		# The road between the bosses: ten heads over five chassis families.
		var variant: int = skin - STATION_SKIN
		var kind: int = posmod(variant, 10)
		var family: int = clampi(variant / 10, 0, 4)
		var station: Dictionary = data.station
		var parts: Dictionary = station.families[family].duplicate()
		parts["head"] = station.heads[kind % 5]
		parts["top"] = station.tops[kind]
		parts["spin"] = ""
		return {"parts": parts, "palette": station.palette, "eye_style": station.eyes[kind], "key": "road%d" % variant,
			"scale": [1.0, 1.0, 1.0], "wear": station.get("wear", 0.4), "mouth": false}
	var index = clampi(skin, 0, data.cast.size() - 1)
	var entry: Dictionary = data.cast[index]
	return {"parts": entry.parts, "palette": entry.palette, "eye_style": entry.eye_style, "key": "cast%d" % index,
		"scale": entry.get("scale", [1.0, 1.0, 1.0]), "wear": entry.get("wear", 0.4), "mouth": entry.get("mouth", false)}

static func head(name: String) -> Dictionary:
	return ROSTER.data.heads.get(name, {"top": HEAD_TOP, "center": HEAD_CENTER, "aspect": 1.45})

static func colors(skin: int, team: Color, tint: bool = false) -> Dictionary:
	# Every role resolved to a colour. Empty entries in the roster follow the team colour.
	var palette: Dictionary = recipe(skin).palette
	var out = {}
	for role in ["shell", "trim", "dark", "metal", "glow", "eyes"]:
		var hex = String(palette.get(role, ""))
		out[role] = Color(hex) if hex != "" else team
	if String(palette.get("glow", "")) == "":
		out.glow = team.lightened(0.3)
	if String(palette.get("eyes", "")) == "":
		out.eyes = team.lightened(0.45)
	out["team"] = team
	if tint:
		# A boss not yet beaten fights in gunmetal and its team's colour.
		out.shell = Color("3d404a")
		out.trim = team
		out.glow = team.lightened(0.3)
		out.eyes = team.lightened(0.4)
	return out

static func part(name: String) -> Array:
	# [mesh, role] pairs of one kit part, read once from the imported scene.
	if _parts.is_empty():
		var scene: Node = KIT.instantiate()
		for root in scene.get_children():
			var items: Array = []
			for child in root.get_children():
				if child is MeshInstance3D:
					items.append([child.mesh, child.mesh.surface_get_material(0).resource_name])
			_parts[String(root.name)] = items
		scene.free()
	return _parts.get(name, [])

static func merged(key: String, placed: Array) -> Dictionary:
	# `placed`: [part name, Transform3D] pairs. Returns role -> one mesh with every part of
	# that role, plus "outline": the whole group with smooth normals, so the inflated ink hull
	# has no cracks along hard edges.
	if _merged.has(key):
		return _merged[key]
	var by_role: Dictionary = {}
	for entry in placed:
		for item in part(entry[0]):
			if not by_role.has(item[1]):
				by_role[item[1]] = []
			by_role[item[1]].append([item[0], entry[1]])
	var out: Dictionary = {}
	var hull = SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	for role in by_role:
		var tool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in by_role[role]:
			var at: Transform3D = piece[1]
			tool.append_from(piece[0], 0, at)
			if role != "screen" and role != "glow":
				var arrays: Array = piece[0].surface_get_arrays(0)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var index = arrays[Mesh.ARRAY_INDEX]
				if index == null or index.is_empty():
					for point in points:
						hull.add_vertex(at * point)
				else:
					for i in index:
						hull.add_vertex(at * points[i])
		out[role] = tool.commit()
	hull.index()
	hull.generate_normals()
	out["outline"] = hull.commit()
	_merged[key] = out
	return out

static func build(view, body: Node3D, skin: int, team: Color, tint: bool = false) -> void:
	var plan = recipe(skin)
	var parts: Dictionary = plan.parts
	var paint = colors(skin, team, tint)
	paint["wear"] = float(plan.wear)
	body.set_meta("design_signature", plan.key)
	body.set_meta("robot_skin", skin)
	var size: Array = plan.scale
	body.scale = Vector3(size[0], size[1], size[2])
	var shape = head(String(parts.head))
	var lift = Transform3D(Basis.IDENTITY, Vector3(0, float(shape.top) - HEAD_TOP, 0))
	var centre = Transform3D(Basis.IDENTITY, Vector3(0, float(shape.center) - HEAD_CENTER, 0))
	var core: Array = []
	for slot in ["head", "torso", "shoulders", "back", "arm"]:
		if String(parts.get(slot, "")) != "":
			core.append([parts[slot], Transform3D.IDENTITY])
	if String(parts.get("top", "")) != "":
		core.append([parts.top, lift])
	_mount(view, body, plan.key + ":body", core, paint)
	for side in [-1, 1]:
		var leg = Node3D.new()
		leg.name = "LegL" if side == -1 else "LegR"
		leg.position = Vector3(side * LEG_PIVOT.x, LEG_PIVOT.y, LEG_PIVOT.z)
		body.add_child(leg)
		_mount(view, leg, plan.key + ":leg", [[parts.legs, Transform3D.IDENTITY]], paint)
	var gun = Node3D.new()
	gun.name = "Gun"
	body.add_child(gun)
	_mount(view, gun, plan.key + ":gun", [[parts.gun, Transform3D.IDENTITY]], paint)
	var flash = view.sphere(gun, MUZZLE, Vector3.ONE * 0.01, Color("fff1c7"), true)
	flash.name = "Flash"
	var crest = String(parts.get("spin", ""))
	if crest != "":
		var holder: Node3D = body
		var inverse = Transform3D.IDENTITY
		var offset: Transform3D = centre if crest in CENTRED_SPINS else lift
		if DISC_SPINS.has(crest):
			# Turn in the disc's own plane: a mount tipped onto its side, the Spin inside it.
			holder = Node3D.new()
			holder.name = "KeyMount"
			holder.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), offset * DISC_SPINS[crest])
			body.add_child(holder)
			inverse = holder.transform.affine_inverse()
		var spin = Node3D.new()
		spin.name = "Spin"
		holder.add_child(spin)
		for node in _mount(view, spin, plan.key + ":spin", [[crest, offset]], paint):
			node.transform = inverse
	var face: ShaderMaterial = _face(body)
	face.set_shader_parameter("eye_color", paint.eyes)
	face.set_shader_parameter("style", maxi(EYES.find(String(plan.eye_style)), 0))
	face.set_shader_parameter("aspect", float(shape.aspect))
	face.set_shader_parameter("seed", float(hash(plan.key) % 997) * 0.01 + randf() * 3.0)
	face.set_shader_parameter("mouth", 1.0 if plan.mouth else 0.0)

static func _mount(view, parent: Node3D, key: String, placed: Array, paint: Dictionary) -> Array:
	var meshes = merged(key, placed)
	var nodes: Array = []
	for role in meshes:
		var node = MeshInstance3D.new()
		node.mesh = meshes[role]
		node.name = "Robot_" + role
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if role == "outline":
			node.material_override = _outline(view)
			node.add_to_group(OUTLINE_GROUP)
			node.visible = view.quality_level > 0
		elif role == "screen":
			var face = ShaderMaterial.new()
			face.shader = FACE
			node.material_override = face
		else:
			node.material_override = paint_material(view, role, paint.get(role, Color.WHITE), paint.wear)
		parent.add_child(node)
		nodes.append(node)
	return nodes

static func _face(body: Node3D) -> ShaderMaterial:
	var screen: MeshInstance3D = body.get_node_or_null("Robot_screen")
	return screen.material_override if screen != null else ShaderMaterial.new()

static func set_mood(body: Node3D, mood: int) -> void:
	# 0 calm, 1 happy, 2 dizzy. Cheap to call every frame: only writes on change.
	if body.get_meta("robot_mood", 0) == mood:
		return
	body.set_meta("robot_mood", mood)
	_face(body).set_shader_parameter("mood", mood)

static func paint_material(view, role: String, color: Color, wear: float = 0.4) -> ShaderMaterial:
	var worn = 0.0 if role in ["glow", "metal"] else wear
	var key = "robot:%s:%s:%.2f" % [role, color.to_html(), worn]
	if view.materials.has(key):
		return view.materials[key]
	var mat = ShaderMaterial.new()
	mat.set_meta("robot_paint", true)
	mat.set_shader_parameter("paint", color)
	mat.set_shader_parameter("metal", 0.85 if role == "metal" else 0.0)
	mat.set_shader_parameter("gloss", GLOSS.get(role, 0.5))
	mat.set_shader_parameter("glow", 1.4 if role == "glow" else 0.0)
	mat.set_shader_parameter("rim", 0.0 if role == "glow" else (0.1 if role == "dark" else 0.16))
	mat.set_shader_parameter("wear", worn)
	mat.shader = PAINT_LOW if view.quality_level == 0 else PAINT
	view.materials[key] = mat
	return mat

static func _outline(view) -> ShaderMaterial:
	if not view.materials.has("robot:outline"):
		var mat = ShaderMaterial.new()
		mat.shader = OUTLINE
		view.materials["robot:outline"] = mat
	return view.materials["robot:outline"]

static func set_quality(view, level: int) -> void:
	# Leve drops per-light shading and the ink hulls; the other profiles restore both.
	for mat in view.materials.values():
		if mat is ShaderMaterial and mat.get_meta("robot_paint", false):
			mat.shader = PAINT_LOW if level == 0 else PAINT
	if view.is_inside_tree():
		for node in view.get_tree().get_nodes_in_group(OUTLINE_GROUP):
			node.visible = level > 0
