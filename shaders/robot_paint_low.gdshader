shader_type spatial;
// The Leve profile: no per-light passes. The studio light is baked from the world normal: a
// wrapped key from the upper left, a soft sky-to-floor fill and a small highlight, so the
// robots keep their soft, polished volume at the cost of an unlit material.
render_mode unshaded;

// Colour and finish come from the vertices (see robots.gd); alpha 1 marks lights.
uniform float wear : hint_range(0.0, 1.0) = 0.4;
varying vec3 world_normal;
// Preserve the roster's saturated paint instead of mixing it into milky grey.
vec3 studio(vec3 paint, float finish) {
 return paint * (finish > 0.9 ? 1.0 : 1.12);
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
	float band = smoothstep(0.34, 0.44, wrap);
    lit = studio(COLOR.rgb, finish) * mix(vec3(0.32, 0.43, 0.62), vec3(1.0, 0.97, 0.88), band) + vec3(shine * gloss);
    float fresnel = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    lit += vec3(0.18, 0.45, 0.7) * pow(fresnel, 3.0) * 0.35;
    ALBEDO = finish > 0.9 ? COLOR.rgb * 1.9 : lit;
	float sun = dot(n, key_dir);
	if (finish < 0.1) {
		ALBEDO = COLOR.rgb * (fill * 0.6 + vec3(1.0, 0.97, 0.9) * wrap * 0.65);
	} else if (finish < 0.2) {
		// Cloud, painted: warm white in the sun, a cool blue shade underneath.
		float lit = sun * 0.55 + n.y * 0.45;
		vec3 cloud = mix(vec3(0.56, 0.64, 0.8), vec3(0.83, 0.87, 0.94), smoothstep(-0.12, -0.02, lit));
		ALBEDO = COLOR.rgb * mix(cloud, vec3(1.0, 0.97, 0.9), smoothstep(0.3, 0.4, lit)) * 1.2;
	} else if (finish > 0.26 && finish < 0.29) {
		ALBEDO = COLOR.rgb * (fill * 0.6 + vec3(1.0, 0.97, 0.9) * wrap * 0.7);
	} else if (finish > 0.3 && finish < 0.4) {
		// Foliage, painted: a teal shade, the leaf green and a warm sunlit green.
		float lit = sun * 0.8 + 0.1;
		vec3 leaves = mix(COLOR.rgb * vec3(0.5, 0.64, 0.7), COLOR.rgb * 0.95, smoothstep(-0.14, -0.06, lit));
		leaves = mix(leaves, COLOR.rgb * vec3(1.3, 1.26, 0.82), smoothstep(0.42, 0.5, lit));
		ALBEDO = leaves * mix(0.72, 1.0, smoothstep(-0.8, 0.1, n.y)) * 1.25;
	}
}
