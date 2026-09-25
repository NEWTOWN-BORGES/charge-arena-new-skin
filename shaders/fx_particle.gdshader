shader_type spatial;
// GPU particles for the arena's effects. Each instance is written once when it is born and
// the shader animates it from then on, so a burst costs nothing per frame on the CPU.
// Instance transform packs the launch: origin = position, basis x = velocity,
// basis y = (size at birth, size at death, gravity), basis z = (drag, stretch, rise).
// INSTANCE_CUSTOM = (birth time, lifetime, seed, spin). COLOR = tint.
// kind: 0 glow, 1 spark (stretched along its motion), 2 star, 3 ring on the floor.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

uniform float now = 0.0;
uniform int kind = 0;
varying vec4 tint;
varying float age_k;
varying vec2 quad;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float age = now - c.x;
	float k = age / max(c.y, 0.001);
	tint = COLOR;
	age_k = k;
	quad = UV;
	if (k < 0.0 || k > 1.0) {
		VERTEX = vec3(0.0, 0.0, 100.0);
	} else {
		vec3 p0 = MODEL_MATRIX[3].xyz;
		vec3 v0 = MODEL_MATRIX[0].xyz;
		vec3 prm = MODEL_MATRIX[1].xyz;
		vec3 ext = MODEL_MATRIX[2].xyz;
		float drag = max(ext.x, 0.0001);
		float travel = (1.0 - exp(-drag * age)) / drag;
		vec3 p = p0 + v0 * travel + vec3(0.0, 0.5 * prm.z * age * age + ext.z * age, 0.0);
		// Sizes swell quickly then ease towards their end size.
		float size = mix(prm.x, prm.y, 1.0 - pow(1.0 - k, 2.0));
		vec2 corner = VERTEX.xy;
		vec3 view_p;
		if (kind == 3) {
			view_p = (VIEW_MATRIX * vec4(p + vec3(corner.x, 0.0, corner.y) * size, 1.0)).xyz;
		} else {
			view_p = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
			if (kind == 1) {
				vec3 vel = v0 * exp(-drag * age) + vec3(0.0, prm.z * age + ext.z, 0.0);
				vec2 dir = (VIEW_MATRIX * vec4(vel, 0.0)).xy;
				float speed = length(dir);
				vec2 ax = speed > 0.001 ? dir / speed : vec2(1.0, 0.0);
				vec2 ay = vec2(-ax.y, ax.x);
				view_p.xy += ax * corner.x * size * (1.0 + speed * ext.y) + ay * corner.y * size * 0.3;
			} else {
				float turn = c.w * age + c.z * 6.283;
				mat2 r = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
				view_p.xy += r * corner * size;
			}
		}
		VERTEX = view_p;
	}
}

void fragment() {
	vec2 q = quad * 2.0 - 1.0;
	float d = length(q);
	float shape;
	float core;
	if (kind == 1) {
		shape = exp(-q.y * q.y * 7.0) * smoothstep(1.0, 0.1, abs(q.x));
		core = exp(-q.y * q.y * 30.0) * smoothstep(0.8, 0.0, abs(q.x));
	} else if (kind == 2) {
		float arms = max(1.0 - abs(q.x) * 7.0 - abs(q.y), 0.0) + max(1.0 - abs(q.y) * 7.0 - abs(q.x), 0.0);
		shape = clamp(arms, 0.0, 1.0) + pow(max(1.0 - d, 0.0), 3.0);
		core = pow(max(1.0 - d * 2.2, 0.0), 2.0);
	} else if (kind == 3) {
		shape = smoothstep(0.16, 0.0, abs(d - 0.84)) + smoothstep(0.9, 0.2, d) * 0.12;
		core = smoothstep(0.05, 0.0, abs(d - 0.84));
	} else {
		shape = pow(max(1.0 - d, 0.0), 2.2);
		core = pow(max(1.0 - d * 1.8, 0.0), 2.0);
	}
	float fade = kind == 3 ? pow(1.0 - age_k, 1.5) : (1.0 - age_k) * smoothstep(0.0, 0.08, age_k + 0.02);
	ALBEDO = mix(tint.rgb, vec3(1.0), core * 0.4) * 1.2;
	ALPHA = clamp(shape * fade * tint.a, 0.0, 1.0);
}
