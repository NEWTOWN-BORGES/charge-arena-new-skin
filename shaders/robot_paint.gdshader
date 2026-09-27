shader_type spatial;
// Robot parts in the studio look, with real surfaces: glossy lacquered paint with a clear coat,
// polished metal, graphite chassis and lit sensors. A fine grain in the finish (orange peel on
// the paint, brushing on the metal) and a rim of light on the silhouettes keep them from
// reading as matte rubber.
render_mode diffuse_burley, specular_schlick_ggx;

// Colour and finish come from the vertices (see robots.gd): rgb is the paint in linear
// colour, alpha the finish: 1 glow, 0.75 metal, 0.5 dark chassis, 0.45 rubber, 0.25 paint.
uniform float wear : hint_range(0.0, 1.0) = 0.4;
varying vec3 model_position;
const float SOFT_SAT = 0.85;
const float SOFT_LIFT = 0.12;
const float SOFT_GAIN = 1.55;

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

varying vec3 model_normal;

void vertex() {
	model_position = VERTEX;
	model_normal = NORMAL;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float grain(vec3 p) {
	// Value noise: the grain of the finish.
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
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
	// Fine grain: orange peel on the paint, brushed streaks on the metal.
	float fine = grain(model_position * 90.0);
	float streak = grain(model_position * vec3(6.0, 140.0, 6.0));
	float texture_amount = metal ? streak : fine;
	ALBEDO = paint * (1.0 - grime) * (0.96 + 0.06 * texture_amount);
	METALLIC = metal ? 0.9 : (dark ? 0.35 : 0.0);
	ROUGHNESS = (metal ? 0.18 : (rubber ? 0.55 : (dark ? 0.34 : 0.2))) + (texture_amount - 0.5) * (metal ? 0.12 : 0.06);
	SPECULAR = rubber ? 0.35 : 0.62;
	// A clear-coat sheen on the silhouettes: the lacquer catching the sky.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow ? paint * 1.8 : vec3(0.9, 0.95, 1.0) * rim * (rubber ? 0.03 : 0.1);
}
