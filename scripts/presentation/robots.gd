extends RefCounted
## The robot cast. Parts are modelled in Blender (tools/blender/robot_kit.py writes
## art/robots/kit.glb), recipes live in art/robots/roster.json, and this script assembles
## a pilot from them. Each moving group (body, legs, weapon, spinning crest) becomes ONE mesh
## with the colours baked into its vertices, so a robot costs a handful of draws: that mesh,
## an ink outline per group and a face screen of its own.
const KIT = preload("res://art/robots/kit.glb")
const HEROIC_KIT = preload("res://art/robots/heroic_cast.glb")
# ECLIPSE 16: the executor, built joint by joint like BIT
# (tools/blender/eclipse_mech.py).
const ECLIPSE_KIT = preload("res://art/robots/eclipse16.glb")
# BATIDA 13: the circuit's medic (tools/blender/batida_medic.py).
const BATIDA_KIT = preload("res://art/robots/batida13.glb")
# ROSCA 13: the workshop engineer (tools/blender/rosca_engineer.py).
const ROSCA_KIT = preload("res://art/robots/rosca13.glb")
# OFICINA brick styles for the player's wall (tools/blender/brick_styles.py).
const BRICK_STYLES_KIT = preload("res://art/robots/bricks13.glb")
const COSMETICS = preload("res://scripts/progression/cosmetics.gd")
const ROSTER = preload("res://art/robots/roster.json")
# Where each leg bends: the knee height in leg space (tools/blender/robot_kit.py writes it).
const KNEES = preload("res://art/robots/knees.json")
const PAINT = preload("res://shaders/robot_paint.gdshader")
const PAINT_LOW = preload("res://shaders/robot_paint_low.gdshader")
const ArtStyle = preload("res://scripts/presentation/art_style.gd")
const FACE = preload("res://shaders/robot_face.gdshader")
const OUTLINE = preload("res://shaders/robot_outline.gdshader")
const LEG_PIVOT = Vector3(0.19, 0.40, 0.0)
const MUZZLE = Vector3(0.29, 0.70, -0.86)
const STATION_SKIN = 100
# Each robot's wall brick, by cast index: a mechanical block on its theme (see
# tools/blender/mech_cast.py). A hard skin uses its boss's brick in its own colours, with the
# neon kit on top.
const BRICKS = ["brick_bit_mech", "brick_salvo_mech", "brick_orbita_mech", "brick_broto", "brick_bigorna_mech",
	"brick_eclipse_mech", "brick_rosca_mech", "brick_faisca_mech", "batida13_brick", "brick_gancho_mech",
	"brick_helio_mech", "brick_magnus_mech"]
const EYES = ["capsule", "dots", "bars", "square", "slant", "monocle", "visor", "equalizer", "single", "rings", "stars", "arcs", "slits"]
# Tops and crests are modelled for a head whose top is at HEAD_TOP and centre at HEAD_CENTER;
# the roster's "heads" table says where each real head sits, and the parts follow it.
const HEAD_TOP = 1.8
const HEAD_CENTER = 1.44
# Crests that turn in their own plane, behind the head, pivot about these centres.
const DISC_SPINS = {"spin_rays": Vector3(0, 1.44, 0.42), "spin_halo": Vector3(0, 1.5, 0.45)}
const CENTRED_SPINS = ["spin_rays", "spin_halo", "spin_orbit"]
# Vertex alpha tells the paint shader what a surface is made of.
const FINISH = {"glow": 1.0, "metal": 0.75, "dark": 0.5, "rubber": 0.45, "leaf": 0.35, "leaf2": 0.35, "cloud": 0.15, "rock": 0.05, "rock2": 0.05, "grass": 0.22, "turf": 0.27}
# Foliage takes its own colour when the paint names one, else the part's two main colours.
const LEAF_FALLBACK = {"leaf": "shell", "leaf2": "label", "cloud": "shell", "rock": "shell", "rock2": "trim", "grass": "shell", "turf": "shell"}
# The studio look has no ink line: soft light and the dark seams between panels carry the
# shapes. Leave the hull code for a stylised mode, off by default.
const INK = false
# Small hardware (bolts, axles, seals, cables) gets no ink hull: outlined, every bolt read as
# a dot and the hull doubled their triangles.
const NO_INK = ["glow", "metal", "rubber"]
const PAINTED = 0.25
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
			"scale": [1.0, 1.0, 1.0], "wear": station.get("wear", 0.4), "mouth": false, "hip": LEG_PIVOT, "muzzle": MUZZLE}
	var index = clampi(skin, 0, data.cast.size() - 1)
	var entry: Dictionary = data.cast[index]
	if entry.has("base"):
		# A hard-mode skin: its boss, repainted, with a few pieces added ("parts_add").
		var merged_entry: Dictionary = data.cast[int(entry.base)].duplicate()
		var parts: Dictionary = merged_entry.parts.duplicate()
		parts.merge(entry.get("parts_add", {}), true)
		merged_entry.parts = parts
		merged_entry.palette = entry.palette
		entry = merged_entry
	# Robots built with the mechanical kit (v2) say where their hips and muzzle are.
	return {"parts": entry.parts, "palette": entry.palette, "eye_style": entry.eye_style, "key": "cast%d" % index,
		"scale": entry.get("scale", [1.0, 1.0, 1.0]), "wear": entry.get("wear", 0.4), "mouth": entry.get("mouth", false),
		"hip": _vector(entry.get("hip", []), LEG_PIVOT), "muzzle": _vector(entry.get("muzzle", []), MUZZLE)}

static func _vector(values: Array, fallback: Vector3) -> Vector3:
	return Vector3(values[0], values[1], values[2]) if values.size() == 3 else fallback

static func head(name: String) -> Dictionary:
	return ROSTER.data.heads.get(name, {"top": HEAD_TOP, "center": HEAD_CENTER, "aspect": 1.45})

# Set around a build to draw a locked pilot as a silhouette: everything near black, eyes out,
# and only a hard-mode skin's neon still faintly alight - a hint, not a look.
static var shadow_build = false
const SHADOW_BLACK = Color("050507")

static func colors(skin: int, team: Color, tint: bool = false, override: Dictionary = {}) -> Dictionary:
	# Every role resolved to a colour. Empty entries in the roster follow the team colour.
	var palette: Dictionary = recipe(skin).palette
	var out = {}
	for role in ["shell", "trim", "dark", "metal", "glow", "eyes"]:
		var hex = String(palette.get(role, ""))
		out[role] = Color(hex) if hex != "" else team
	# Seals, sleeves and cables: near-black polymer unless the recipe says otherwise.
	var rubber = String(palette.get("rubber", ""))
	out["rubber"] = Color(rubber) if rubber != "" else Color(out.dark).darkened(0.45)
	# Warning yellow and the paper of inspection labels: the same on every machine.
	out["hazard"] = Color(String(palette.get("hazard", "f2c230")))
	out["label"] = Color(String(palette.get("label", "f4f1e8")))
	if String(palette.get("glow", "")) == "":
		out.glow = team.lightened(0.3)
	if String(palette.get("eyes", "")) == "":
		out.eyes = team.lightened(0.45)
	out["team"] = team
	if shadow_build:
		# In the dark: the body black and drawn unlit (see _mount). Only a hard skin carries
		# neon - its lights and colour accents burn and trace its shape; a standard pilot is
		# a plain black silhouette.
		var entry: Dictionary = ROSTER.data.cast[clampi(skin, 0, ROSTER.data.cast.size() - 1)] if skin < STATION_SKIN else {}
		var hard: bool = entry.has("base")
		var neon: Color = Color(out.glow) if hard else SHADOW_BLACK
		var accent: Color = Color(out.trim).darkened(0.7) if hard else SHADOW_BLACK
		for role in ["shell", "dark", "metal", "rubber", "hazard", "label", "team"]:
			out[role] = SHADOW_BLACK
		out.trim = accent
		out.glow = neon
		out.eyes = neon
		return out
	if ArtStyle.current != "":
		ArtStyle.robot(out, team)
	# A paint from the OFICINA: hull, trim, metal and lights in other colours. Seals and
	# labels follow the new darks.
	if not tint and not override.is_empty():
		for role in override:
			out[role] = Color(String(override[role]))
		out.rubber = Color(out.dark).darkened(0.45)
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
		for library in [KIT, HEROIC_KIT, ECLIPSE_KIT, BATIDA_KIT, ROSCA_KIT, BRICK_STYLES_KIT]:
			var scene: Node = library.instantiate()
			for root in scene.get_children():
				var items: Array = []
				for child in root.get_children():
					if child is MeshInstance3D:
						items.append([child.mesh, child.mesh.surface_get_material(0).resource_name])
				_parts[String(root.name)] = items
			scene.free()
	return _parts.get(name, [])

static func merged(key: String, placed: Array, paint: Dictionary, outline: bool = true) -> Dictionary:
	# `placed`: [part name, Transform3D] pairs (identity, translation or uniform scale).
	# Returns "paint": every painted part in one mesh, its colour and finish in the vertex
	# colours; "screen" when there is a face; and "outline": the group with smooth normals,
	# so the inflated ink hull has no cracks along hard edges.
	if _merged.has(key):
		return _merged[key]
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var tints = PackedColorArray()
	var index = PackedInt32Array()
	var screen: Array = []
	var hull_verts = PackedVector3Array()
	var hull_index = PackedInt32Array()
	for entry in placed:
		var at: Transform3D = entry[1]
		for item in part(entry[0]):
			var role: String = item[1]
			if role == "screen":
				screen.append([item[0], at])
				continue
			var arrays: Array = item[0].surface_get_arrays(0)
			var points: PackedVector3Array = at * PackedVector3Array(arrays[Mesh.ARRAY_VERTEX])
			var faces = PackedInt32Array(arrays[Mesh.ARRAY_INDEX]) if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(points.size()))
			var tone: Color = Color(paint.get(role, paint.get(LEAF_FALLBACK.get(role, role), Color.WHITE))).srgb_to_linear()
			tone.a = ArtStyle.finish(role, FINISH.get(role, PAINTED))
			var fill = PackedColorArray()
			fill.resize(points.size())
			fill.fill(tone)
			var base = verts.size()
			verts.append_array(points)
			normals.append_array(arrays[Mesh.ARRAY_NORMAL])
			tints.append_array(fill)
			var start = index.size()
			index.append_array(faces)
			for i in range(start, index.size()):
				index[i] += base
			if outline and not role in NO_INK:
				var hull_base = hull_verts.size()
				hull_verts.append_array(points)
				var hull_start = hull_index.size()
				hull_index.append_array(faces)
				for i in range(hull_start, hull_index.size()):
					hull_index[i] += hull_base
	var out: Dictionary = {}
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tints
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out["paint"] = mesh
	if not screen.is_empty():
		var tool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in screen:
			tool.append_from(piece[0], 0, piece[1])
		out["screen"] = tool.commit()
	if outline and not hull_verts.is_empty():
		var shell = []
		shell.resize(Mesh.ARRAY_MAX)
		shell[Mesh.ARRAY_VERTEX] = hull_verts
		shell[Mesh.ARRAY_INDEX] = hull_index
		var hull = SurfaceTool.new()
		hull.create_from_arrays(shell)
		# Weld every copy of a position so the normals average across hard edges.
		hull.deindex()
		hull.index()
		hull.generate_normals()
		out["outline"] = hull.commit()
	_merged[key] = out
	return out

static func build(view, body: Node3D, skin: int, team: Color, tint: bool = false, override: Dictionary = {}) -> void:
	var plan = recipe(skin)
	var parts: Dictionary = plan.parts
	var paint = colors(skin, team, tint, override)
	paint["wear"] = float(plan.wear)
	body.set_meta("design_signature", plan.key)
	body.set_meta("robot_skin", skin)
	var size: Array = plan.scale
	body.scale = Vector3(size[0], size[1], size[2])
	# A fused hull (no head part) keeps its face in the trunk and says where it is itself.
	var shape = head(String(parts.head) if String(parts.head) != "" else String(parts.torso))
	var lift = Transform3D(Basis.IDENTITY, Vector3(0, float(shape.top) - HEAD_TOP, 0))
	var centre = Transform3D(Basis.IDENTITY, Vector3(0, float(shape.center) - HEAD_CENTER, 0))
	# The trunk is one piece; the head (with whatever sits on it) turns on the neck and the
	# free arm swings from the shoulder, each on a joint of its own (Body/Head, Body/Arm).
	var core: Array = []
	for slot in ["torso", "shoulders", "back", "extra"]:
		if String(parts.get(slot, "")) != "":
			core.append([parts[slot], Transform3D.IDENTITY])
	_mount(view, body, plan.key + ":core", core, paint)
	var head_parts: Array = []
	if String(parts.get("head", "")) != "":
		head_parts.append([parts.head, Transform3D.IDENTITY])
	if String(parts.get("top", "")) != "":
		head_parts.append([parts.top, lift])
	if String(parts.get("hat", "")) != "":
		# Hard-mode pieces are modelled in place on their robot, like the head itself.
		head_parts.append([parts.hat, Transform3D.IDENTITY])
	var head_joint = _joint(view, body, "Head", plan.key + ":head", head_parts, paint, true)
	if String(parts.get("arm", "")) != "":
		_joint(view, body, "Arm", plan.key + ":arm", [[parts.arm, Transform3D.IDENTITY]], paint, false)
	var hip: Vector3 = plan.hip
	for side in [-1, 1]:
		var leg = Node3D.new()
		leg.name = "LegL" if side == -1 else "LegR"
		leg.position = Vector3(side * hip.x, hip.y, hip.z)
		body.add_child(leg)
		# A mechanical leg has an outside (bearing caps, vents) and comes as a left and right pair.
		var leg_part = String(parts.legs) + ("_l" if side == -1 else "_r")
		if part(leg_part).is_empty():
			leg_part = String(parts.legs)
		if not part(leg_part + "_thigh").is_empty() and KNEES.data.has(leg_part):
			# Two pieces on two joints: the thigh swings from the hip, the shin from the knee
			# (LegL/Knee), so the leg can bend as the robot runs.
			_mount(view, leg, plan.key + ":" + leg_part + "_thigh", [[leg_part + "_thigh", Transform3D.IDENTITY]], paint)
			var knee = Node3D.new()
			knee.name = "Knee"
			knee.position = Vector3(0, float(KNEES.data[leg_part]), 0)
			leg.add_child(knee)
			_mount(view, knee, plan.key + ":" + leg_part + "_shin", [[leg_part + "_shin", Transform3D.IDENTITY]], paint)
		else:
			_mount(view, leg, plan.key + ":" + leg_part, [[leg_part, Transform3D.IDENTITY]], paint)
	var gun = Node3D.new()
	gun.name = "Gun"
	body.add_child(gun)
	# The gun arm swings from the shoulder, not from the feet: the Gun joint sits at the
	# shoulder and everything in it is drawn back by the same amount.
	var shoulder = Vector3(float(plan.muzzle.x), 1.2, 0.0)
	gun.position = shoulder
	var placed_gun = _mount(view, gun, plan.key + ":gun", [[parts.gun, Transform3D.IDENTITY]], paint)
	for node in placed_gun:
		node.position -= shoulder
	var flash = view.sphere(gun, plan.muzzle - shoulder, Vector3.ONE * 0.01, Color("fff1c7"), true)
	flash.name = "Flash"
	gun.set_meta("rest", shoulder)
	var crest = String(parts.get("spin", ""))
	if crest != "":
		# The crest rides on the head: a mount that undoes the neck's offset, so the crest
		# keeps its modelled place and turns with the head.
		var crest_base = Node3D.new()
		crest_base.name = "CrestMount"
		crest_base.position = -head_joint.position
		head_joint.add_child(crest_base)
		var holder: Node3D = crest_base
		var inverse = Transform3D.IDENTITY
		# v2 crests are modelled in place on their own robot, so they need no offset.
		var offset: Transform3D = Transform3D.IDENTITY if (crest.ends_with("2_spin") or crest.ends_with("3_spin")) else (centre if crest in CENTRED_SPINS else lift)
		if DISC_SPINS.has(crest):
			# Turn in the disc's own plane: a mount tipped onto its side, the Spin inside it.
			holder = Node3D.new()
			holder.name = "KeyMount"
			holder.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), offset * DISC_SPINS[crest])
			crest_base.add_child(holder)
			inverse = holder.transform.affine_inverse()
		var spin = Node3D.new()
		spin.name = "Spin"
		holder.add_child(spin)
		for node in _mount(view, spin, plan.key + ":spin", [[crest, offset]], paint):
			node.transform = inverse
	var face: ShaderMaterial = _face(body)
	face.set_shader_parameter("eye_color", paint.eyes)
	face.set_shader_parameter("style", EYES.find(ArtStyle.eyes()) if ArtStyle.eyes() != "" else maxi(EYES.find(String(plan.eye_style)), 0))
	face.set_shader_parameter("aspect", float(shape.aspect))
	face.set_shader_parameter("seed", float(hash(plan.key) % 997) * 0.01 + randf() * 3.0)
	face.set_shader_parameter("mouth", 1.0 if plan.mouth and ArtStyle.eyes() == "" else 0.0)
	# A robot may tint the glass of its screen (the roster's "glass"); the rest keep it dark.
	var glass = String(plan.palette.get("glass", ""))
	if glass != "":
		face.set_shader_parameter("glass", Color(glass))

static func brick_part(skin: int, tint: bool = false) -> String:
	# The themed brick of a cast skin (a hard skin takes its boss's); "" for the station pilots
	# and single-colour builds, which keep the soft arena brick.
	if tint or skin < 0 or skin >= ROSTER.data.cast.size():
		return ""
	var base = int(ROSTER.data.cast[skin].get("base", skin))
	return String(BRICKS[base]) if base >= 0 and base < BRICKS.size() else ""

static func brick(view, node: Node3D, skin: int, team: Color, tint: bool = false, style: String = "") -> bool:
	# The wall of whoever defends it: that robot's mechanical brick in its own colours, with
	# the team's colour on the lid and the band of the plinth (blue near, red far) so the two
	# walls always read as the two teams. A hard skin adds its neon. Returns false when the
	# soft arena brick was used instead (station pilots): a rubbery block in the team colour
	# with a cream cushion on top.
	var part = brick_part(skin, tint)
	# An OFICINA brick style replaces the robot's own brick.
	if style != "" and part != "" and not part(style).is_empty():
		part = style
	var strong = Color.from_hsv(team.h, maxf(team.s * 1.6, 0.76), team.v * 0.88)
	if part != "":
		var themed = colors(skin, team, tint)
		if part == style:
			# A brick style wears its own colours, whoever's wall it is.
			for entry in COSMETICS.BRICKS:
				if entry.part == style:
					for role in entry.palette:
						themed[role] = Color(entry.palette[role])
		themed["wear"] = 0.15
		themed["team"] = strong
		var placed = [[detail_name(view, part), Transform3D.IDENTITY]]
		var hard = ROSTER.data.cast[skin].has("base")
		if hard:
			placed.append(["brick_neon", Transform3D.IDENTITY])
		_mount(view, node, "brick:%s:%s" % [placed[0][0], "neon" if hard else ""], placed, themed, false)
		return true
	var paint = colors(0, team, tint)
	paint["wear"] = 0.0
	# The rubber of the Blender island: the team colour at full strength under the cream
	# cushion (the pale pilot tints read as white once the colours are Blender's).
	paint["team"] = strong
	# The cushion takes the world's tint (arena_theme "cushion"); cream on the island.
	var cushion: Color = view.theme.get("cushion", Color("fff4e2")) if "theme" in view else Color("fff4e2")
	paint["shell"] = cushion
	_mount(view, node, "brick:soft", [["brick_soft", Transform3D.IDENTITY]], paint, false)
	return false

# Tests set this to see the phone's half-detail scenery on a computer.
static var light_parts := false

static func detail_name(view, name: String) -> String:
	# The half-detail copy of a scenery part (kit "lo_" parts) on a phone below the top profile.
	if (OS.has_feature("mobile") or light_parts) and not part("lo_" + name).is_empty():
		return "lo_" + name
	return name

static func prop(view, node: Node3D, key: String, parts: Array, paint: Dictionary) -> Array:
	# Arena furniture from the same kit (bumpers, goal posts), painted like the robots.
	var placed: Array = []
	for name in parts:
		placed.append([detail_name(view, name), Transform3D.IDENTITY])
	if not paint.has("wear"):
		paint["wear"] = 0.4
	return _mount(view, node, key, placed, paint)

static func _mount(view, parent: Node3D, key: String, placed: Array, paint: Dictionary, outline: bool = true) -> Array:
	var signature = ""
	for role in ["shell", "trim", "dark", "metal", "glow", "team", "rubber", "hazard", "label", "leaf", "leaf2", "cloud", "rock", "rock2", "grass", "turf"]:
		signature += Color(paint.get(role, Color.WHITE)).to_html(false)
	var meshes = merged(key + ":" + signature, placed, paint, outline and INK)
	# Real shadows only from what stands by the court (robots, bricks, goal furniture).
	var casts = ArtStyle.shadows() and (not parent.is_inside_tree() or Vector2(parent.global_position.x, parent.global_position.z).length() < 18.0)
	var nodes: Array = []
	for role in meshes:
		var node = MeshInstance3D.new()
		node.mesh = meshes[role]
		node.name = "Robot_" + role
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if role == "outline":
			node.material_override = _outline(view)
			node.add_to_group(OUTLINE_GROUP)
			node.visible = view.quality_level > 0
		elif shadow_build:
			# Unlit: no highlight, no reflection gives the body away; only the vertex colours
			# (black and neon) are drawn.
			node.material_override = _shadow_material(role == "screen")
		elif role == "screen":
			var face = ShaderMaterial.new()
			face.shader = FACE
			node.material_override = face
		else:
			node.material_override = paint_material(view, paint.wear)
		parent.add_child(node)
		nodes.append(node)
	return nodes

static var _shadow_materials: Dictionary = {}

static func _shadow_material(screen: bool) -> Material:
	if not _shadow_materials.has(screen):
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = SHADOW_BLACK if screen else Color.WHITE
		mat.vertex_color_use_as_albedo = not screen
		_shadow_materials[screen] = mat
	return _shadow_materials[screen]

static func _joint(view, body: Node3D, joint_name: String, key: String, placed: Array, paint: Dictionary, below: bool) -> Node3D:
	# A jointed piece: mounted in body space, then its node moved to the pivot (the bottom of
	# a head, the top of an arm) and its meshes moved back, so rotating the node turns the
	# piece about that joint.
	var joint = Node3D.new()
	joint.name = joint_name
	body.add_child(joint)
	if placed.is_empty():
		return joint
	var meshes = _mount(view, joint, key, placed, paint)
	var bounds := AABB()
	var first = true
	for node in meshes:
		if node is MeshInstance3D and node.mesh != null:
			var box: AABB = node.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
	var centre = bounds.get_center()
	var pivot = Vector3(centre.x, bounds.position.y + bounds.size.y * 0.12, centre.z) if below else Vector3(centre.x, bounds.end.y - bounds.size.y * 0.12, centre.z)
	joint.position = pivot
	for node in meshes:
		node.position -= pivot
	return joint

static func _face(body: Node3D) -> ShaderMaterial:
	var screen: MeshInstance3D = body.get_node_or_null("Head/Robot_screen")
	if screen == null:
		screen = body.get_node_or_null("Robot_screen")
	# A silhouette's screen is plain black: its face settings go to a throwaway material.
	if screen != null and screen.material_override is ShaderMaterial:
		return screen.material_override
	return ShaderMaterial.new()

static func set_mood(body: Node3D, mood: int) -> void:
	# 0 calm, 1 happy, 2 dizzy, 3 angry. Cheap to call every frame: only writes on change.
	if body.get_meta("robot_mood", 0) == mood:
		return
	body.set_meta("robot_mood", mood)
	_face(body).set_shader_parameter("mood", mood)

static func paint_material(view, wear: float = 0.4) -> ShaderMaterial:
	# One material for every robot, brick and prop with the same wear: colours live in the
	# vertices, so the whole cast shares a handful of materials.
	var key = "robot:paint:%.2f" % wear
	if view.materials.has(key):
		return view.materials[key]
	var mat = ShaderMaterial.new()
	mat.set_meta("robot_paint", true)
	mat.set_shader_parameter("wear", wear)
	mat.shader = _paint_shader(view.quality_level)
	mat.set_shader_parameter("surface_grain", preload("res://art/materials/alloy_roughness.png"))
	mat.set_shader_parameter("surface_detail", 1.0 if view.quality_level == 2 else 0.0)
	if "theme" in view and view.theme.has("sky_low"):
		# Far scenery fades into the world's own air.
		var air: Color = Color(view.theme.sky_mid).lerp(view.theme.sky_low, 0.55).srgb_to_linear()
		mat.set_shader_parameter("haze", Vector3(air.r, air.g, air.b))
	if "key_light" in view and is_instance_valid(view.key_light):
		# The painted scenery takes its light and shade from the world's sun.
		mat.set_shader_parameter("sun_dir", view.key_light.transform.basis.z.normalized())
	view.materials[key] = mat
	return mat

static func _paint_shader(level: int) -> Shader:
	if ArtStyle.paint_shader() != null:
		return ArtStyle.paint_shader()
	return PAINT_LOW if level == 0 else PAINT

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
			mat.shader = _paint_shader(level)
			mat.set_shader_parameter("surface_detail", 1.0 if level == 2 else 0.0)
	if view.is_inside_tree():
		for node in view.get_tree().get_nodes_in_group(OUTLINE_GROUP):
			node.visible = level > 0
