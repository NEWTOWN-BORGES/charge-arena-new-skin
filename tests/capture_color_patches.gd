extends SceneTree
# The colour test chart of tools/color/patches.json through the game's own grade, to compare
# with the Blender render of the same chart (tools/color/blender_patches.py). Needs a GPU.
# Usage: godot -s tests/capture_color_patches.gd -- <out.png> [raw]
#   neutral: the game's tonemapping and adjustment pass without the colour table (to build it).
const ArenaFinish = preload("res://scripts/arena_finish.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tools/color/patches.json"))
	var cols: int = data.columns
	var cell: int = data.cell
	var patches: Array = data.patches
	var rows = ceili(patches.size() / float(cols))
	root.size = Vector2i(cols * cell, rows * cell)
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.use_hdr_2d = ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	ArenaFinish.environment(env, 1)
	env.glow_enabled = false
	if args.has("canvas"):
		# The game's own setup: the 3D drawn over a 2D backdrop layer.
		env.background_mode = Environment.BG_CANVAS
		env.background_canvas_max_layer = -1
		var layer = CanvasLayer.new()
		layer.layer = -1
		root.add_child(layer)
		var back = ColorRect.new()
		back.color = Color.BLACK
		back.size = Vector2(4000, 4000)
		layer.add_child(back)
	if args.has("neutral"):
		env.adjustment_color_correction = null
	var world = WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	# The values go in a float texture, one texel per patch: vertex colours are stored in
	# 8 bits, which clipped everything over 1 and lost the darks.
	var values = Image.create_empty(cols, rows, false, Image.FORMAT_RGBF)
	for i in range(patches.size()):
		values.set_pixel(i % cols, i / cols, Color(patches[i][0], patches[i][1], patches[i][2]))
	var quad = QuadMesh.new()
	quad.size = Vector2(cols, rows)
	var shader = Shader.new()
	shader.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform sampler2D values : filter_nearest;\nvoid fragment() { ALBEDO = texture(values, UV).rgb; }\n"
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("values", ImageTexture.create_from_image(values))
	var node = MeshInstance3D.new()
	node.mesh = quad
	node.position = Vector3(cols / 2.0, -rows / 2.0, 0)
	node.material_override = mat
	root.add_child(node)
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rows
	cam.position = Vector3(cols / 2.0, -rows / 2.0, 10)
	root.add_child(cam)
	cam.current = true
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	print("PATCHES ", root.get_texture().get_image().save_png(args[0]))
	quit()
