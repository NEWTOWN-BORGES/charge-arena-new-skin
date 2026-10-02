shader_type spatial;
// GPU particles for the arena's effects. Each instance is written once when it is born and
// the shader animates it from then on, so a burst costs nothing per frame on the CPU.
// Instance transform packs the launch: origin = position, basis x = velocity,
// basis y = (size at birth, size at death, gravity), basis z = (drag, stretch, rise).
// INSTANCE_CUSTOM = (birth time, lifetime, seed, spin). COLOR = tint.
// kind: 0 glow, 1 spark (stretched along its motion), 2 star, 3 ring on the floor.
// Blended, not added: added light vanishes over the bright arenas. Each particle is a
// saturated colour with a hot core, so embers and sparks read on any floor.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

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
		// A tapered streak, with a bright leading tip and a coloured trailing edge.
		float width = mix(0.10, 0.38, smoothstep(-1.0, 0.65, q.x));
		float edge = abs(q.y) / width + abs(q.x) * 0.52;
		float aa = max(fwidth(edge), 0.035);
		shape = (1.0 - smoothstep(0.88 - aa, 0.88 + aa, edge)) * smoothstep(-1.0, -0.72, q.x);
		core = (1.0 - smoothstep(0.10, 0.20, abs(q.y))) * smoothstep(-0.65, 0.4, q.x) * shape;
	} else if (kind == 2) {
		float cross_shape = min(abs(q.x) * 5.5 + abs(q.y), abs(q.y) * 5.5 + abs(q.x));
		float aa = max(fwidth(cross_shape), 0.025);
		shape = 1.0 - smoothstep(0.83 - aa, 0.83 + aa, cross_shape);
		core = 1.0 - smoothstep(0.10, 0.25, d);
	} else if (kind == 3) {
		float aa = max(fwidth(d), 0.012);
		shape = 1.0 - smoothstep(0.055, 0.055 + aa, abs(d - 0.84));
		// A slim second band gives a readable shockwave without filling the floor.
		shape += (1.0 - smoothstep(0.018, 0.018 + aa, abs(d - 0.70))) * 0.23;
		core = 1.0 - smoothstep(0.012, 0.028, abs(d - 0.84));
	} else {
		shape = smoothstep(0.76, 0.29, d) * 0.75 + smoothstep(0.36, 0.18, d) * 0.25;
		core = smoothstep(0.26, 0.08, d);
	}
	float age = clamp(age_k, 0.0, 1.0);
	float fade = kind == 3 ? pow(1.0 - age, 1.2) : (1.0 - age) * smoothstep(0.0, 0.05, age + 0.02);
	float grey = dot(tint.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = clamp(mix(vec3(grey), tint.rgb, 1.4), 0.0, 1.0);
	// Sparks flicker as they fly.
	float flicker = kind == 1 ? 0.94 + 0.06 * sin(TIME * 40.0 + age * 25.0) : 1.0;
	ALBEDO = mix(vivid, vec3(1.0, 0.98, 0.88), clamp(core * 0.87, 0.0, 1.0)) * flicker;
	EMISSION = vivid * core * 0.2 * fade;
	ALPHA = clamp(shape * fade * tint.a, 0.0, 1.0);
}
