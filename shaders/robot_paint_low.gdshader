shader_type spatial;
// The Leve profile: no per-light passes. The studio light is baked from the world normal: a
// wrapped key from the upper left, a soft sky-to-floor fill and a small highlight, so the
// robots keep their soft, polished volume at the cost of an unlit material.
render_mode unshaded;

// Colour and finish come from the vertices (see robots.gd); alpha 1 marks lights.
uniform float wear : hint_range(0.0, 1.0) = 0.4;
varying vec3 world_normal;
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

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float finish = COLOR.a;
	vec3 key_dir = normalize(vec3(-0.45, 0.8, 0.45));
	float wrap = clamp(dot(n, key_dir) * 0.5 + 0.5, 0.0, 1.0);
	vec3 fill = mix(vec3(0.42, 0.44, 0.47), vec3(0.78, 0.8, 0.83), n.y * 0.5 + 0.5);
	vec3 half_dir = normalize(key_dir + vec3(0.0, 0.55, 0.85));
	// Glossy: a tighter, brighter highlight than the old semi-matte one.
	float shine = pow(clamp(dot(n, half_dir), 0.0, 1.0), finish > 0.65 && finish < 0.9 ? 40.0 : 22.0);
	float gloss = finish > 0.9 ? 0.0 : (finish > 0.4 && finish < 0.48 ? 0.05 : 0.3);
	vec3 lit = studio(COLOR.rgb, finish) * (fill * 0.55 + vec3(1.0, 0.97, 0.93) * wrap * wrap * 0.75) + vec3(shine * gloss);
	ALBEDO = finish > 0.9 ? COLOR.rgb * 1.7 : lit;
	float sun = dot(n, key_dir);
	if (finish < 0.1) {
		ALBEDO = COLOR.rgb * (fill * 0.6 + vec3(1.0, 0.97, 0.9) * wrap * 0.65);
	} else if (finish < 0.2) {
		// Cloud, painted: warm white in the sun, a cool blue shade underneath.
		float lit = sun * 0.55 + n.y * 0.45;
		vec3 cloud = mix(vec3(0.56, 0.64, 0.8), vec3(0.83, 0.87, 0.94), smoothstep(-0.12, -0.02, lit));
		ALBEDO = COLOR.rgb * mix(cloud, vec3(1.0, 0.97, 0.9), smoothstep(0.3, 0.4, lit)) * 1.2;
	} else if (finish > 0.3 && finish < 0.4) {
		// Foliage, painted: a teal shade, the leaf green and a warm sunlit green.
		float lit = sun * 0.8 + 0.1;
		vec3 leaves = mix(COLOR.rgb * vec3(0.5, 0.64, 0.7), COLOR.rgb * 0.95, smoothstep(-0.14, -0.06, lit));
		leaves = mix(leaves, COLOR.rgb * vec3(1.3, 1.26, 0.82), smoothstep(0.42, 0.5, lit));
		ALBEDO = leaves * mix(0.72, 1.0, smoothstep(-0.8, 0.1, n.y)) * 1.25;
	}
}
