extends RefCounted
## Ilha Jardim: the grass diorama modelled in Blender (tools/blender/bake_world.py) with the
## Cycles lighting baked into its vertex colours: soft sun, sky fill, the shade in every
## corner. It is drawn unshaded, so it looks like the render and costs less than a lit map:
## one mesh, one material, nothing moving.
const WORLD = "res://art/worlds/jardim.glb"

static var baked_material: ShaderMaterial

static func material() -> ShaderMaterial:
	# glTF colours are linear, and so is the light Cycles baked into them.
	if baked_material == null:
		baked_material = ShaderMaterial.new()
		baked_material.shader = preload("res://shaders/baked_world.gdshader")
	return baked_material

static func baked_path(map_id: String) -> String:
	# The worlds baked for a map, by its id ("torre", "torre_terra"…).
	return "res://art/worlds/%s.glb" % map_id

static func build(view, _theme: Dictionary, path: String = WORLD) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		return
	var world: Node3D = scene.instantiate()
	world.name = "BakedWorld"
	view.add_child(world)
	for node in world.find_children("*", "MeshInstance3D", true, false):
		node.material_override = material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
