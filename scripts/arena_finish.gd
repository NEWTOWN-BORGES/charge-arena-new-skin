extends RefCounted
## Shared surface treatment. Tiny repeatable maps, no runtime texture generation.
const SURFACES = {
	"ceramic": [preload("res://art/materials/ceramic_albedo.png"), preload("res://art/materials/ceramic_roughness.png"), preload("res://art/materials/ceramic_normal.png")],
	"alloy": [preload("res://art/materials/alloy_albedo.png"), preload("res://art/materials/alloy_roughness.png"), preload("res://art/materials/alloy_normal.png")],
	"graphite": [preload("res://art/materials/graphite_albedo.png"), preload("res://art/materials/graphite_roughness.png"), preload("res://art/materials/graphite_normal.png")]
}
static var studio_sky: Sky

static func environment(env: Environment, quality: int) -> void:
	if studio_sky == null:
		studio_sky = Sky.new()
		studio_sky.radiance_size = Sky.RADIANCE_SIZE_128
		var sky = ProceduralSkyMaterial.new()
		sky.sky_top_color = Color("20364f")
		sky.sky_horizon_color = Color("c5e4e5")
		sky.ground_bottom_color = Color("182a34")
		sky.ground_horizon_color = Color("bda586")
		studio_sky.sky_material = sky
	env.sky = studio_sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.ambient_light_color = Color("91b5c5")
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.glow_enabled = quality == 2
	env.glow_intensity = 0.65
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.12
	env.glow_hdr_scale = 1.1
	env.adjustment_enabled = quality > 0
	env.adjustment_saturation = 1.13
	env.adjustment_contrast = 1.04

static func surface(mat: StandardMaterial3D, quality: int) -> void:
	var luminous = bool(mat.get_meta("always_unshaded", false))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if quality == 0 or luminous else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if luminous:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.4 if mat.albedo_color.a >= 0.7 else 0.6
		return
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
	var kind = "alloy" if mat.metallic > 0.5 else ("graphite" if mat.albedo_color.v < 0.35 else "ceramic")
	mat.set_meta("surface_finish", kind)
	mat.albedo_texture = SURFACES[kind][0] if quality > 0 else null
	mat.roughness_texture = SURFACES[kind][1] if quality == 2 else null
	mat.normal_enabled = quality == 2
	mat.normal_texture = SURFACES[kind][2] if quality == 2 else null
	mat.normal_scale = 0.28
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 2.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.65 if kind == "graphite" else (0.52 if kind == "alloy" else 0.7)
	mat.metallic_specular = 0.7
	mat.clearcoat_enabled = quality == 2 and kind != "graphite"
	mat.clearcoat = 0.45
	mat.clearcoat_roughness = 0.25
