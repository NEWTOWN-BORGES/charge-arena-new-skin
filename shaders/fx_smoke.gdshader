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
		float size = mix(prm.x, prm.y, 1.0 - pow(1.0 - k, 1.6));
		float turn = c.w * age + c.z * 6.283;
		mat2 r = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
		vec3 view_p = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
		view_p.xy += r * VERTEX.xy * size;
		VERTEX = view_p;
	}
}

void fragment() {
	vec2 q = quad * 2.0 - 1.0;
	// Three overlapping lobes make a cloud rather than a disc.
	float s = grain * 6.283;
	float lobes = max(max(smoothstep(0.75, 0.1, length(q - 0.28 * vec2(cos(s), sin(s)))),
		smoothstep(0.7, 0.1, length(q - 0.3 * vec2(cos(s + 2.1), sin(s + 2.1))))),
		smoothstep(0.72, 0.1, length(q - 0.26 * vec2(cos(s + 4.2), sin(s + 4.2)))));
	float fade = smoothstep(0.0, 0.12, age_k) * (1.0 - age_k);
	ALBEDO = tint.rgb * mix(1.1, 0.75, age_k);
	ALPHA = lobes * fade * tint.a;
}
