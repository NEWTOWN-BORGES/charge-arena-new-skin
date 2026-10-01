shader_type spatial;
// Soft smoke and dust puffs: the same launch packing as fx_particle, alpha-blended, and
// swelling as they rise and fade.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

uniform float now = 0.0;
varying vec4 tint;
varying float age_k;
varying vec2 quad;
varying float grain;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float age = now - c.x;
	float k = age / max(c.y, 0.001);
	tint = COLOR;
	age_k = k;
	quad = UV;
	grain = c.z;
	if (k < 0.0 || k > 1.0) {
		VERTEX = vec3(0.0, 0.0, 100.0);
	} else {
		vec3 p0 = MODEL_MATRIX[3].xyz;
		vec3 v0 = MODEL_MATRIX[0].xyz;
		vec3 prm = MODEL_MATRIX[1].xyz;
		vec3 ext = MODEL_MATRIX[2].xyz;
		float drag = max(ext.x, 0.0001);
		vec3 p = p0 + v0 * (1.0 - exp(-drag * age)) / drag + vec3(0.0, ext.z * age, 0.0);
		float size = mix(prm.x, prm.y, 1.0 - pow(1.0 - k, 1.6)) * 0.84;
		float turn = c.w * age + c.z * 6.283;
		mat2 r = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
		vec3 view_p = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
		view_p.xy += r * VERTEX.xy * size;
		VERTEX = view_p;
	}
}

void fragment() {
	vec2 q = quad * 2.0 - 1.0;
	// Defined lobes and a cool underside suggest volume without a noise texture.
	float s = grain * 6.283;
	vec2 a = q - 0.23 * vec2(cos(s), sin(s));
	vec2 b = q - 0.27 * vec2(cos(s + 2.1), sin(s + 2.1));
	vec2 c = q - 0.21 * vec2(cos(s + 4.2), sin(s + 4.2));
	float cloud = min(min(length(a) - 0.55, length(b) - 0.49), length(c) - 0.52);
	float aa = max(fwidth(cloud), 0.02);
	float silhouette = 1.0 - smoothstep(-0.055, aa, cloud);
	float volume = max(max(1.0 - dot(a, a) / 0.3025, 1.0 - dot(b, b) / 0.2401), 1.0 - dot(c, c) / 0.2704);
	float top_light = clamp(0.45 + q.y * 0.30 - q.x * 0.18 + max(volume, 0.0) * 0.24, 0.0, 1.0);
	vec3 shade = mix(vec3(0.38, 0.48, 0.63), vec3(1.05, 1.02, 0.92), smoothstep(0.25, 0.78, top_light));
	float age = clamp(age_k, 0.0, 1.0);
	float fade = smoothstep(0.0, 0.08, age) * pow(1.0 - age, 1.45);
	ALBEDO = mix(tint.rgb, vec3(0.24, 0.29, 0.38), 0.28) * shade;
	ALPHA = silhouette * fade * tint.a * 0.9;
}
