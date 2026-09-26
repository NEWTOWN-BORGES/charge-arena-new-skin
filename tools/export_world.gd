extends SceneTree
# Exports the scenery of a world as the game builds it, so Blender can bake its light
# (tools/blender/bake_scene.py). One mesh: the colour of every material in the vertex colours
# (sRGB), and the finish in the alpha (1 = a light, 0.75 metal, 0.5 dark, 0.45 rubber, else
# paint), as the robots' paint already stores it. Headless is fine.
#   godot --headless -s tools/export_world.gd -- aurora terra oceano orbita cidade
# Writes art/worlds/src/<map id>.glb.
const View = preload("res://scripts/indie_arena_view.gd")
const Rules = preload("res://scripts/arena_rules.gd")
const OUT = "res://art/worlds/src/"
const PAINTED = 0.25

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for world in OS.get_cmdline_user_args():
		var layout = Rules.quick_map(world)
		var view = View.new()
		view.bake_export = true
		root.add_child(view)
		view.build(layout)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count = 0
		for node in view.world_nodes:
			count += collect(node, view, st)
		var mesh = st.commit()
		var holder = Node3D.new()
		var instance = MeshInstance3D.new()
		instance.name = "world"
		instance.mesh = mesh
		holder.add_child(instance)
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		doc.append_from_scene(holder, state)
		var path = OUT + String(layout.id) + ".glb"
		print("WORLD ", world, " ", path, " triangles ", count, " ", doc.write_to_filesystem(state, path))
		holder.free()
		view.queue_free()
		await process_frame
	quit()

func collect(node: Node, view: Node3D, st: SurfaceTool) -> int:
	var added = 0
	# The build merges the scenery by material and hides the originals: read them anyway.
	if node is MeshInstance3D and node.mesh != null:
		added += add_mesh(node, view, st)
	for child in node.get_children():
		added += collect(child, view, st)
	return added

func add_mesh(node: MeshInstance3D, view: Node3D, st: SurfaceTool) -> int:
	var mat = node.material_override
	var flat := Color.WHITE
	var finish := PAINTED
	var painted = false
	if mat is StandardMaterial3D:
		# Transparent pieces (soft shadows, glass) are left to the game.
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return 0
		flat = mat.albedo_color
		finish = 1.0 if mat.get_meta("always_unshaded", false) else PAINTED
	elif mat is ShaderMaterial and mat.get_meta("robot_paint", false):
		painted = true
	else:
		return 0
	var xf: Transform3D = view.global_transform.affine_inverse() * node.global_transform
	var basis = xf.basis
	var triangles = 0
	for s in range(node.mesh.get_surface_count()):
		var arrays = node.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var colors = arrays[Mesh.ARRAY_COLOR]
		var index = arrays[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = index if index != null and index.size() > 0 else PackedInt32Array(range(verts.size()))
		for i in order:
			var c: Color = flat
			if painted and colors != null and colors.size() > i:
				var linear: Color = colors[i]
				c = Color(linear.r, linear.g, linear.b).linear_to_srgb()
				c.a = linear.a
			else:
				c.a = finish
			st.set_color(c)
			if normals != null and normals.size() > i:
				st.set_normal((basis * normals[i]).normalized())
			st.add_vertex(xf * verts[i])
		triangles += order.size() / 3
	return triangles
