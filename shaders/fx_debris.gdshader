shader_type spatial;
// Chunks flung by impacts: little boxes that tumble, fall and settle on the floor, all in
// one draw. Same launch packing as fx_particle; basis z.x holds the tumble speed.
render_mode unshaded, skip_vertex_transform, shadows_disabled;

uniform float now = 0.0;
varying vec4 tint;
varying float lit;

vec3 spin(vec3 v, vec3 axis, float angle) {
	return v * cos(angle) + cross(axis, v) * sin(angle) + axis * dot(axis, v) * (1.0 - cos(angle));
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float age = now - c.x;
	float k = age / max(c.y, 0.001);
	tint = COLOR;
	if (k < 0.0 || k > 1.0) {
		VERTEX = vec3(0.0, 0.0, 100.0);
		lit = 0.0;
	} else {
		vec3 p0 = MODEL_MATRIX[3].xyz;
		vec3 v0 = MODEL_MATRIX[0].xyz;
		vec3 prm = MODEL_MATRIX[1].xyz;
		float size = prm.x * (1.0 - smoothstep(0.75, 1.0, k));
		vec3 p = p0 + v0 * age + vec3(0.0, 0.5 * prm.z * age * age, 0.0);
		// Settle on the floor instead of sinking through it.
		p.y = max(p.y, prm.x * 0.5);
		float rolling = p.y > prm.x * 0.51 ? 1.0 : 0.25;
		vec3 axis = normalize(vec3(sin(c.z * 12.0), 0.6, cos(c.z * 9.0)));
		float angle = c.w * age * rolling + c.z * 6.283;
		vec3 local = spin(VERTEX * size * vec3(1.0, 0.6, 1.3), axis, angle);
		vec3 normal = spin(NORMAL, axis, angle);
		lit = 0.55 + 0.45 * max(dot(normal, normalize(vec3(-0.4, 0.85, 0.35))), 0.0);
		VERTEX = (VIEW_MATRIX * vec4(p + local, 1.0)).xyz;
		NORMAL = (VIEW_MATRIX * vec4(normal, 0.0)).xyz;
	}
}

void fragment() {
	ALBEDO = tint.rgb * lit;
}
