shader_type spatial;
// Robot parts in the studio look: smooth semi-matte paint with broad soft highlights on the
// bevels, graphite chassis, polished metal joints, matte rubber and lit sensors. No ink line
// and no grunge: a maintained competition machine under studio light.
render_mode diffuse_burley, specular_schlick_ggx;

// Colour and finish come from the vertices (see robots.gd): rgb is the paint in linear
// colour, alpha the finish: 1 glow, 0.75 metal, 0.5 dark chassis, 0.45 rubber, 0.25 paint.
uniform float wear : hint_range(0.0, 1.0) = 0.4;
varying vec3 model_position;
const float SOFT_SAT = 0.6;
const float SOFT_LIFT = 0.26;
const float SOFT_GAIN = 1.9;

// The Blender mockups' look: AgX there lifts and softens saturated paint into light, milky
// pastels. The same grade is applied here so the game matches the renders: paint and metal
// move part of the way to their own grey and the darks lift a little. Chassis, rubber and
// lights keep their colour.
vec3 studio(vec3 paint, float finish) {
	bool dark = finish >= 0.4 && finish < 0.65;
	if (finish > 0.9 || dark) return paint;
	float luma = dot(paint, vec3(0.2126, 0.7152, 0.0722));
	bool metal = finish > 0.65;
	vec3 soft = mix(vec3(luma), paint, metal ? 0.85 : SOFT_SAT);
	vec3 x = soft * SOFT_GAIN + vec3(metal ? 0.12 : SOFT_LIFT);
	// Light paint rolls off softly instead of burning out to white.
	float peak = max(x.r, max(x.g, x.b));
	float over = max(peak - 0.72, 0.0);
	return x * ((min(peak, 0.72) + over / (1.0 + over / 0.24)) / max(peak, 1e-4));
}

void vertex() {
	model_position = VERTEX;
}

void fragment() {
	vec3 paint = studio(COLOR.rgb, COLOR.a);
	float finish = COLOR.a;
	bool glow = finish > 0.9;
	bool metal = finish > 0.65 && finish < 0.9;
	bool rubber = finish > 0.4 && finish < 0.48;
	bool dark = finish >= 0.48 && finish < 0.65;
	// A breath of dust towards the feet grounds the figure without dirtying it.
	float grime = smoothstep(0.5, 0.0, model_position.y) * 0.06 * (0.5 + wear);
	ALBEDO = paint * (1.0 - grime);
	METALLIC = metal ? 0.82 : (dark ? 0.3 : 0.0);
	ROUGHNESS = metal ? 0.3 : (rubber ? 0.85 : (dark ? 0.52 : 0.4));
	SPECULAR = rubber ? 0.3 : 0.5;
	EMISSION = glow ? paint * 1.8 : vec3(0.0);
}
