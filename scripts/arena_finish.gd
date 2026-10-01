extends RefCounted
## Shared surface treatment. Tiny repeatable maps, no runtime texture generation.
const SURFACES = {
	"ceramic": [preload("res://art/materials/ceramic_albedo.png"), preload("res://art/materials/ceramic_roughness.png"), preload("res://art/materials/ceramic_normal.png")],
	"alloy": [preload("res://art/materials/alloy_albedo.png"), preload("res://art/materials/alloy_roughness.png"), preload("res://art/materials/alloy_normal.png")],
	"graphite": [preload("res://art/materials/graphite_albedo.png"), preload("res://art/materials/graphite_roughness.png"), preload("res://art/materials/graphite_normal.png")],
	"panel": [preload("res://art/materials/panel_albedo.png"), preload("res://art/materials/panel_roughness.png"), preload("res://art/materials/panel_normal.png")],
	"grass": [preload("res://art/materials/grass_albedo.png"), preload("res://art/materials/grass_roughness.png"), preload("res://art/materials/grass_normal.png")],
	"stone": [preload("res://art/materials/stone_albedo.png"), preload("res://art/materials/stone_roughness.png"), preload("res://art/materials/stone_normal.png")]
}
# How many metres one tile of each texture covers in the world.
const TILE_METRES = {"panel": 2.0, "alloy": 1.5, "graphite": 1.2, "grass": 2.5, "stone": 3.0}
const ArtStyle = preload("res://scripts/art_style.gd")
static var studio_sky: Sky
# A weak phone GPU (two-core Mali, old Adreno): the surfaces keep their texture but drop the
# normal and roughness maps and the anisotropic filter, which were most of the fill cost.
static var lean := false

# Heroic grade: saturated team colours and deeper cool shadows.
const EXPOSURE = 1.12
const VIVID_SATURATION = 1.26
const VIVID_CONTRAST = 1.14
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
		sky.sky_top_color = Color("729dd4")
		sky.sky_horizon_color = Color("b9d5ef")
		sky.ground_bottom_color = Color("273e5b")
		sky.ground_horizon_color = Color("708aad")
		sky.sun_angle_max = 0.0
		studio_sky.sky_material = sky
	env.sky = studio_sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	# The light of version 3.8, the one the game is tuned to: a bright studio dome, AgX with
	# a little more exposure, and a touch more contrast and colour than the raw transform.
	# (Reinhard and the measured Blender transform, tools/color/, both came out darker.)
	env.ambient_light_energy = 0.65
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
	ArtStyle.environment(env)

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
	# Real surfaces for the worlds: every material gets the texture of what it is (painted
	# plates, brushed metal, dark rubber, grass, rock), projected in world space so nothing
	# stretches and one texture serves every colour. Leve lights per vertex and stays plain.
	var luminous = bool(mat.get_meta("always_unshaded", false))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if luminous else (BaseMaterial3D.SHADING_MODE_PER_VERTEX if quality == 0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	if luminous:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.2 if mat.albedo_color.a >= 0.7 else 0.6
		return
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
	var kind = surface_kind(mat)
	mat.set_meta("surface_finish", kind)
	mat.roughness = {"graphite": 0.5, "alloy": 0.26, "grass": 0.85, "stone": 0.8}.get(kind, 0.34)
	mat.metallic = 0.85 if kind == "alloy" else (0.2 if kind == "graphite" else (0.15 if kind == "panel" else 0.0))
	mat.metallic_specular = 0.55
	mat.clearcoat_enabled = quality == 2 and kind in ["ceramic", "panel"]
	mat.clearcoat = 0.22
	mat.clearcoat_roughness = 0.32
	if quality == 0 or not SURFACES.has(kind):
		mat.albedo_texture = null
		mat.roughness_texture = null
		mat.normal_enabled = false
		mat.normal_texture = null
		return
	var maps: Array = SURFACES[kind]
	mat.albedo_texture = maps[0]
	mat.roughness_texture = null if lean else maps[1]
	mat.normal_enabled = not lean
	mat.normal_texture = null if lean else maps[2]
	# Small lacquer/plate relief, rather than deep concrete cracks on painted armour.
	mat.normal_scale = 0.35 if kind in ["ceramic", "panel"] else 0.65
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / float(TILE_METRES.get(kind, 2.0))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if OS.has_feature("mobile") else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

static func surface_kind(mat: StandardMaterial3D) -> String:
	var c: Color = mat.albedo_color
	if mat.metallic > 0.5:
		return "alloy"
	if c.v < 0.35:
		return "graphite"
	# Greens are grass; warm earth tones (cliffs, dirt, sand, rocks) are stone.
	if c.h > 0.18 and c.h < 0.45 and c.s > 0.3:
		return "grass"
	if c.h > 0.03 and c.h < 0.16 and c.s > 0.2 and c.s < 0.75:
		return "stone"
	return "panel"
