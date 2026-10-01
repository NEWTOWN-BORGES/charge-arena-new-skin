shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// A single two-triangle card: the shock front is drawn analytically, never a
// stack of transparent spheres. Narrow feathered edges hold up on phone screens.
uniform vec4 tint : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.97, 0.85, 1.0);
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float motif = 0.0;
uniform float seed = 0.0;
// Small animated chips are part of this card, never spawned particle nodes.
uniform float detail_quality : hint_range(0.0, 1.0) = 1.0;

float band(float value, float center, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(value - center));
}

float cross_mask(vec2 p, float size, float aa) {
	vec2 q = abs(p);
	float cross_distance = min(max(q.x - size * 0.26, q.y - size), max(q.x - size, q.y - size * 0.26));
	return 1.0 - smoothstep(0.0, aa, cross_distance);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float aa = max(fwidth(radius) * 1.2, 0.008);
	float travel = 1.0 - pow(1.0 - age, 2.4);
	float front = mix(0.13, 0.91, travel);
	float fade = smoothstep(0.0, 0.06, age + 0.025) * pow(1.0 - age, 1.35);
	float edge = band(radius, front, mix(0.033, 0.012, age), aa);
	float tail = band(radius, front - 0.052, 0.023, aa * 2.0) * 0.21;
	float core = (1.0 - smoothstep(0.06, 0.26, radius)) * pow(1.0 - age, 7.0);
	float detail = 0.0;
	float sparks = 0.0;
	if (motif > 0.5 && motif < 1.5) {
		// A bold comic crown, with triangular teeth and separated radial flecks.
		float tooth = abs(fract(angle * 1.90986 + seed * 0.1) - 0.5) * 2.0;
		float crown = front + (tooth - 0.5) * 0.16 * (1.0 - age);
		edge = band(radius, crown, 0.027, aa);
		float rays = pow(max(0.0, cos(angle * 12.0 + seed)), 12.0);
		detail = rays * smoothstep(front * 0.35, front * 0.56, radius) * (1.0 - smoothstep(front * 0.7, max(crown, front * 0.8) + aa, radius)) * 0.6;
		sparks = pow(max(0.0, cos(angle * 8.0 + seed)), 32.0) * band(radius, min(0.88, front + 0.14), 0.04, aa);
		core *= 1.5;
	} else if (motif > 1.5 && motif < 2.5) {
		// Electrical spokes fracture into an angular ionisation ring.
		float jagged = abs(fract(angle * 2.54648 + seed * 0.1) - 0.5);
		edge = band(radius, front + (jagged - 0.25) * 0.15, 0.018, aa);
		float zigzag = abs(fract(radius * 6.0 - age * 2.0) - 0.5) * 1.3;
		float branch = pow(max(0.0, cos(angle * 8.0 + zigzag + seed)), 30.0);
		detail = branch * (1.0 - smoothstep(front * 0.74, front, radius)) * smoothstep(0.1, 0.21, radius) * 0.84;
		sparks = pow(max(0.0, cos(angle * 6.0 - seed)), 32.0) * band(radius, min(0.9, front + 0.11), 0.025, aa);
		fade *= 0.86 + 0.14 * sin(age * 32.0);
	} else if (motif > 2.5 && motif < 3.5) {
		// Repair reads immediately as a plus sign surrounded by four rising motes.
		float turn = age * 0.6 + seed;
		mat2 spin = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn)));
		vec2 repair = spin * p;
		detail = cross_mask(p, 0.12 + age * 0.06, aa) * (1.0 - age) * 0.85;
		float axis = min(abs(repair.x), abs(repair.y));
		sparks = (1.0 - smoothstep(0.027, 0.027 + aa, axis)) * band(radius, front * 0.72, 0.065, aa);
		edge *= 0.62;
		tail *= 0.6;
		core *= 0.3;
	} else if (motif > 4.5 && motif < 5.5) {
		// A compact bright ribbon and separated charge ticks retain the shot's colour.
		float crossline = abs(p.x);
		float along = 1.0 - smoothstep(0.81, 1.0, abs(p.y));
		edge = (1.0 - smoothstep(0.045, 0.085, crossline)) * along;
		tail = (1.0 - smoothstep(0.11, 0.22, crossline)) * along * 0.43;
		float pulses = pow(max(0.0, cos(p.y * 25.0 - age * 17.0)), 8.0);
		detail = band(crossline, 0.29, 0.022, aa) * pulses * along * 0.58 * detail_quality;
		core = 0.0;
	} else if (motif > 5.5) {
		// Four sharply tapered rays make the hit readable without a cloudy bloom.
		vec2 q = abs(p);
		float star = min(q.x * 4.5 + q.y, q.y * 4.5 + q.x);
		edge = 1.0 - smoothstep(0.56, 0.62, star);
		tail = (1.0 - smoothstep(0.14, 0.3, radius)) * 0.25;
		detail = 0.0;
		core *= 0.55;
		fade = pow(1.0 - age, 2.8);
	} else {
		// Four restrained sparks accompany regular impacts on the higher profiles.
		sparks = pow(max(0.0, cos(angle * 4.0 + seed)), 28.0) * band(radius, min(0.9, front + 0.12), 0.025, aa);
	}
	float mask = 1.0 - smoothstep(0.95, 1.0, radius);
	if (motif > 4.5 && motif < 5.5) mask = 1.0;
	float light = clamp(edge + tail + core + detail + sparks * detail_quality * 0.65, 0.0, 1.0);
	ALBEDO = mix(tint.rgb, hot.rgb, clamp(edge * 0.45 + core + detail * 0.18, 0.0, 0.86));
	ALPHA = light * fade * mask * tint.a;
}
