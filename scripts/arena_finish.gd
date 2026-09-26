extends RefCounted
## Shared surface treatment. Tiny repeatable maps, no runtime texture generation.
const SURFACES = {
	"ceramic": [preload("res://art/materials/ceramic_albedo.png"), preload("res://art/materials/ceramic_roughness.png"), preload("res://art/materials/ceramic_normal.png")],
	"alloy": [preload("res://art/materials/alloy_albedo.png"), preload("res://art/materials/alloy_roughness.png"), preload("res://art/materials/alloy_normal.png")],
	"graphite": [preload("res://art/materials/graphite_albedo.png"), preload("res://art/materials/graphite_roughness.png"), preload("res://art/materials/graphite_normal.png")]
}
static var studio_sky: Sky

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
	env.ambient_light_energy = 0.85
	env.ambient_light_color = Color("c3c9cf")
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	# Glow is several full-screen passes: kept on a computer, left off on a phone, where the
	# particles' own additive glow already carries the light.
	env.glow_enabled = quality == 2 and not OS.has_feature("mobile")
	env.glow_intensity = 0.45
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_scale = 1.1
	# A touch more contrast and colour than the raw AgX, like the tuned Blender renders.
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.18
	env.adjustment_brightness = 1.0

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
