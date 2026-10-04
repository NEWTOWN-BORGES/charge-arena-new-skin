extends SceneTree
const View = preload("res://scripts/presentation/arena_view.gd")
const Video = preload("res://scripts/settings/video_settings.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(Video.AA_LEVELS[2] == Viewport.MSAA_4X)
	assert(Video.SCREEN_AA[2] == Viewport.SCREEN_SPACE_AA_DISABLED)
	var view = View.new()
	var dimensions = Vector3(0.7, 0.9, 0.4)
	var mesh = view.rounded_pilot_shape(dimensions, 0.07)
	assert(mesh == view.rounded_pilot_shape(dimensions, 0.07))
	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == 900 and normals.size() == vertices.size())
	for i in range(vertices.size()):
		assert(vertices[i].is_finite() and normals[i].is_normalized())
		assert(vertices[i].abs().x <= dimensions.x * 0.5 + 0.0001)
	for i in range(0, vertices.size(), 3):
		var outward = (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i])
		assert(outward.dot(normals[i]) > 0)
	view.free()
	print("PASS REFINADO: outward smooth geometry, and caching")
	quit()
