extends RefCounted
## Shared surface treatment. Tiny repeatable maps, no runtime texture generation.
const SURFACES = {
	"ceramic": [preload("res://art/materials/ceramic_albedo.png"), preload("res://art/materials/ceramic_roughness.png"), preload("res://art/materials/ceramic_normal.png")],
	"alloy": [preload("res://art/materials/alloy_albedo.png"), preload("res://art/materials/alloy_roughness.png"), preload("res://art/materials/alloy_normal.png")],
	"graphite": [preload("res://art/materials/graphite_albedo.png"), preload("res://art/materials/graphite_roughness.png"), preload("res://art/materials/graphite_normal.png")]
}
static var studio_sky: Sky

# The exposure and the colour push of version 3.8, the light the player chose.
const EXPOSURE = 1.12
const VIVID_SATURATION = 1.18
const VIVID_CONTRAST = 1.12
static var blender_lut: ImageTexture3D

static func blender_colors() -> ImageTexture3D:
	# The table is a strip of 33 slices of 33 x 33 (red across, green down, blue slice by
	# slice), imported without compression so every entry stays exact.
	if blender_lut == null:
		var strip: Image = load("res://art/color/blender_lut.png").get_image()
		strip.convert(Image.FORMAT_RGB8)
		var size = strip.get_height()
		var slices: Array[Image] = []
		for z in range(size):
			slices.append(strip.get_region(Rect2i(z * size, 0, size, size)))
		blender_lut = ImageTexture3D.new()
		blender_lut.create(Image.FORMAT_RGB8, size, size, size, false, slices)
	return blender_lut

static func environment(env: Environment, quality: int) -> void:
	# The studio: a neutral grey dome that lights every side softly and gives the paint and the
	# metal something quiet to reflect, as in the Blender renders the look was designed in.
	if studio_sky == null:
		studio_sky = Sky.new()
		studio_sky.radiance_size = Sky.RADIANCE_SIZE_128
		var sky = ProceduralSkyMaterial.new()
		sky.sky_top_color = Color("d9dee3")
		sky.sky_horizon_color = Color("b8bec5")
		sky.ground_bottom_color = Color("5c6168")
		sky.ground_horizon_color = Color("9da3aa")
		sky.sun_angle_max = 0.0
		studio_sky.sky_material = sky
	env.sky = studio_sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	# The light of version 3.8, the one the game is tuned to: a bright studio dome, AgX with
	# a little more exposure, and a touch more contrast and colour than the raw transform.
	# (Reinhard and the measured Blender transform, tools/color/, both came out darker.)
	env.ambient_light_energy = 0.85
	env.ambient_light_color = Color("c3c9cf")
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = EXPOSURE
	# Glow is several full-screen passes: kept on a computer, left off on a phone, where the
	# particles' own additive glow already carries the light.
	env.glow_enabled = quality == 2 and not OS.has_feature("mobile")
	env.glow_intensity = 0.45
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_scale = 1.1
	env.adjustment_enabled = true
	env.adjustment_contrast = VIVID_CONTRAST
	env.adjustment_saturation = VIVID_SATURATION
	env.adjustment_brightness = 1.0
	env.adjustment_color_correction = null

static func fog(env: Environment, spec: Dictionary) -> void:
	# Distance haze in the world's own colour: the far terraces, the seabed and the street
	# below fade into it, which gives the depth. Depth fog, not height fog: the lobby far
	# below the arena is seen from close up, well inside `begin`, so it stays clear.
	env.fog_enabled = not spec.is_empty()
	if spec.is_empty():
		return
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = spec.color
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = spec.get("density", 1.0)
	env.fog_depth_begin = spec.begin
	env.fog_depth_end = spec.end
	env.fog_depth_curve = spec.get("curve", 1.0)
	env.fog_sky_affect = 0.0

static func surface(mat: StandardMaterial3D, quality: int) -> void:
	# The studio finish: clean semi-matte paint with soft highlights, no grain or grime. Leve
	# lights per vertex, which keeps the soft volume for almost nothing.
	var luminous = bool(mat.get_meta("always_unshaded", false))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if luminous else (BaseMaterial3D.SHADING_MODE_PER_VERTEX if quality == 0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	if luminous:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.2 if mat.albedo_color.a >= 0.7 else 0.6
		return
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
	var kind = "alloy" if mat.metallic > 0.5 else ("graphite" if mat.albedo_color.v < 0.35 else "ceramic")
	mat.set_meta("surface_finish", kind)
	mat.albedo_texture = null
	mat.roughness_texture = null
	mat.normal_enabled = false
	mat.normal_texture = null
	mat.roughness = 0.5 if kind == "graphite" else (0.34 if kind == "alloy" else 0.42)
	mat.metallic = 0.82 if kind == "alloy" else (0.25 if kind == "graphite" else 0.0)
	mat.metallic_specular = 0.5
	mat.clearcoat_enabled = false
