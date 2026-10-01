shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// A single two-triangle card: the shock front is drawn analytically, never a
// stack of transparent spheres. Narrow feathered edges hold up on phone screens.
uniform vec4 tint : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.97, 0.85, 1.0);
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float motif = 0.0;
uniform float seed = 0.0;
// Exact cast identity comes from CombatFinish.SIGNATURES. Damage fronts leave
// emblem at zero, so a reused pooled card can never retain the last cast badge.
uniform float emblem = 0.0;
uniform float rank : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.2) = 1.0;
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

float stroke(vec2 p, vec2 a, vec2 b, float width, float aa) {
	vec2 line = b - a;
	float t = clamp(dot(p - a, line) / max(dot(line, line), 0.00001), 0.0, 1.0);
	return 1.0 - smoothstep(width, width + aa, length(p - a - line * t));
}

float box_line(vec2 p, vec2 size, float width, float aa) {
	vec2 d = abs(p) - size;
	float edge = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	return band(edge, 0.0, width, aa);
}

float chevron(vec2 p, float width, float aa) {
	return max(stroke(p, vec2(-0.19, -0.12), vec2(0.0, 0.1), width, aa), stroke(p, vec2(0.0, 0.1), vec2(0.19, -0.12), width, aa));
}

float bolt(vec2 p, float aa) {
	float a = stroke(p, vec2(0.08, 0.34), vec2(-0.15, 0.03), 0.032, aa);
	float b = stroke(p, vec2(-0.15, 0.03), vec2(0.13, 0.03), 0.032, aa);
	return max(max(a, b), stroke(p, vec2(0.13, 0.03), vec2(-0.08, -0.34), 0.032, aa));
}

float shield_edge(vec2 p, float aa) {
	float boundary = max(abs(p.x) - 0.29, max(p.y - 0.29, max(-p.y - 0.35, abs(p.x) * 0.62 - p.y - 0.32)));
	return band(boundary, 0.0, 0.024, aa);
}

float cast_emblem(vec2 p, float kind, float aa, float t) {
	float r = length(p);
	float angle = atan(p.y, p.x);
	float icon = 0.0;
	if (kind < 1.5) {
		// Demolition: eight-point blast rather than a plain circular flash.
		float teeth = 0.27 + 0.095 * pow(abs(cos(angle * 4.0)), 4.0);
		icon = band(r, teeth, 0.026, aa) + band(r, 0.11, 0.023, aa);
	} else if (kind < 2.5) {
		// Three ammunition cells, with one displaced to read as a burst.
		vec2 q = vec2(mod(p.x + 0.36, 0.24) - 0.12, p.y + abs(p.x) * 0.3);
		icon = box_line(q, vec2(0.045, 0.18), 0.018, aa) * (1.0 - smoothstep(0.32, 0.34, abs(p.x)));
		icon += stroke(p, vec2(-0.28, -0.28), vec2(0.28, -0.28), 0.015, aa);
	} else if (kind < 3.5) {
		// Fan: five separated trajectories, visible even on the low profile.
		float rays = pow(max(cos((angle - 1.570796) * 8.0), 0.0), 20.0);
		icon = rays * smoothstep(0.09, 0.13, r) * (1.0 - smoothstep(0.35, 0.39, r)) * step(0.0, p.y);
		icon += band(r, 0.24, 0.018, aa) * step(0.0, p.y);
	} else if (kind < 4.5) {
		// Ghost shell: arch, scalloped hem and two cutout optics.
		icon = band(length(p - vec2(0.0, 0.07)), 0.23, 0.022, aa) * smoothstep(-0.01, 0.02, p.y);
		icon += stroke(p, vec2(-0.23, 0.06), vec2(-0.23, -0.2), 0.022, aa) + stroke(p, vec2(0.23, 0.06), vec2(0.23, -0.2), 0.022, aa);
		icon += band(p.y, -0.19 + cos(p.x * 28.0) * 0.03, 0.022, aa) * (1.0 - smoothstep(0.22, 0.24, abs(p.x)));
		icon += (1.0 - smoothstep(0.029, 0.029 + aa, length(vec2(abs(p.x) - 0.08, p.y - 0.08))));
	} else if (kind < 5.5) {
		icon = stroke(p, vec2(0.0, -0.35), vec2(0.0, 0.34), 0.022, aa) + chevron(p - vec2(0.0, 0.22), 0.027, aa);
		icon += box_line(p + vec2(0.0, 0.2), vec2(0.08, 0.06), 0.016, aa);
	} else if (kind < 6.5) {
		icon = box_line(p + vec2(0.0, 0.12), vec2(0.27, 0.14), 0.02, aa);
		icon += stroke(p, vec2(0.0, -0.26), vec2(0.0, 0.01), 0.016, aa) + chevron(p - vec2(0.0, 0.24), 0.023, aa);
	} else if (kind < 7.5) {
		icon = shield_edge(p, aa);
		icon += rank > 0.0 ? chevron(p, 0.022, aa) : stroke(p, vec2(-0.12, -0.15), vec2(0.14, 0.16), 0.023, aa);
	} else if (kind < 8.5) {
		// Crenellations and separate masonry courses.
		icon = box_line(p + vec2(0.0, 0.065), vec2(0.29, 0.20), 0.022, aa);
		icon += box_line(vec2(mod(p.x + 0.3, 0.20) - 0.1, p.y - 0.2), vec2(0.065, 0.055), 0.018, aa) * step(abs(p.x), 0.3);
		icon += stroke(p, vec2(-0.26, -0.08), vec2(0.26, -0.08), 0.016, aa);
	} else if (kind < 9.5) {
		icon = bolt(p, aa) + band(r, 0.39, 0.015, aa) * smoothstep(0.1, 0.35, abs(p.x));
	} else if (kind < 10.5) {
		icon = cross_mask(p, 0.26, aa) - cross_mask(p, 0.21, aa);
		icon += band(r, 0.38, 0.015, aa) * smoothstep(0.1, 0.35, abs(p.x));
	} else if (kind < 11.5) {
		float spine = pow(max(0.0, cos(angle * 8.0)), 16.0);
		icon = band(r, 0.24, 0.021, aa) + spine * smoothstep(0.2, 0.24, r) * (1.0 - smoothstep(0.35, 0.39, r));
	} else if (kind < 12.5) {
		// Six-spoke ice crystal with forked tips.
		float spoke = pow(abs(cos(angle * 3.0)), 28.0);
		icon = spoke * (1.0 - smoothstep(0.32, 0.36, r));
		float forks = pow(abs(cos(angle * 3.0 + 0.35)), 28.0) + pow(abs(cos(angle * 3.0 - 0.35)), 28.0);
		icon += forks * band(r, 0.24, 0.036, aa) * 0.75;
	} else if (kind < 13.5) {
		icon = band(length(p + vec2(0.0, 0.04)), 0.23, 0.033, aa) * (1.0 - smoothstep(0.035, 0.06, p.y));
		icon += box_line(vec2(abs(p.x) - 0.23, p.y - 0.13), vec2(0.033, 0.11), 0.017, aa);
	} else if (kind < 14.5) {
		icon = chevron(p - vec2(0.0, 0.17), 0.028, aa) + chevron(p + vec2(0.0, 0.06), 0.025, aa);
		icon += stroke(p, vec2(0.0, -0.32), vec2(0.0, 0.1), 0.022, aa);
	} else if (kind < 15.5) {
		icon = band(r, 0.25, 0.019, aa);
		icon += (stroke(p, vec2(-0.37, 0.0), vec2(0.37, 0.0), 0.015, aa) + stroke(p, vec2(0.0, -0.37), vec2(0.0, 0.37), 0.015, aa)) * smoothstep(0.1, 0.13, r);
		icon += 1.0 - smoothstep(0.029, 0.029 + aa, r);
	} else if (kind < 16.5) {
		float shards = pow(max(cos(angle * 6.0), 0.0), 24.0);
		icon = band(r, 0.11, 0.022, aa) + shards * band(r, 0.30, 0.065, aa);
	} else if (kind < 17.5) {
		float spiral = band(r, 0.19 + angle * 0.024, 0.024, aa);
		icon = spiral + chevron(p + vec2(0.0, 0.22), 0.024, aa);
		icon += band(r, 0.36, 0.018, aa) * step(0.0, sin(angle * 3.0));
	} else if (kind < 18.5) {
		icon = stroke(p, vec2(-0.33, -0.2), vec2(0.02, 0.25), 0.025, aa) + stroke(p, vec2(0.02, 0.25), vec2(0.32, -0.07), 0.025, aa);
		icon += box_line(p - vec2(0.02, 0.29), vec2(0.30, 0.02), 0.015, aa);
	} else if (kind < 19.5) {
		icon = band(r, 0.20, 0.022, aa) + band(r, 0.34, 0.018, aa) * step(0.2, sin(angle * 8.0));
		icon += bolt(p * 1.6, aa) * 0.7;
	} else if (kind < 20.5) {
		// Artillery trajectory: a clean parabolic arc ending in a strike cross.
		icon = band(p.y, 0.24 - (p.x + 0.05) * (p.x + 0.05) * 3.2, 0.023, aa) * (1.0 - smoothstep(0.32, 0.35, abs(p.x)));
		icon += cross_mask(p - vec2(0.3, -0.16), 0.1, aa);
	} else if (kind < 21.5) {
		icon = band(r, 0.30, 0.025, aa) * step(0.0, p.y) + stroke(p, vec2(-0.33, 0.0), vec2(0.33, 0.0), 0.025, aa);
		icon += band(length(vec2(p.x * 1.8, p.y)), 0.30, 0.014, aa) * step(0.0, p.y);
	} else if (kind < 22.5) {
		icon = box_line(p, vec2(0.24, 0.29), 0.019, aa);
		icon += stroke(p, vec2(-0.21, 0.26), vec2(0.21, -0.26), 0.020, aa) + stroke(p, vec2(0.21, 0.26), vec2(-0.21, -0.26), 0.020, aa);
	} else if (kind < 23.5) {
		icon = band(r, 0.17, 0.026, aa);
		icon += chevron(p + vec2(0.0, 0.28), 0.025, aa) + chevron(-p + vec2(0.0, 0.28), 0.025, aa);
		icon += chevron(vec2(p.y, p.x) + vec2(0.0, 0.28), 0.025, aa) + chevron(vec2(-p.y, -p.x) + vec2(0.0, 0.28), 0.025, aa);
	} else if (kind < 24.5) {
		icon = shield_edge(p, aa) + cross_mask(p, 0.12, aa) * 0.9;
	} else if (kind < 25.5) {
		float rays = pow(max(cos(angle * (rank > 0.0 ? 6.0 : 8.0)), 0.0), 20.0);
		icon = band(r, 0.17, 0.023, aa) + rays * smoothstep(0.24, 0.28, r) * (1.0 - smoothstep(0.36, 0.4, r));
	} else if (kind < 26.5) {
		icon = band(length(p - vec2(-0.09, -0.12)), 0.14, 0.022, aa);
		icon += stroke(p, vec2(0.03, 0.0), vec2(0.30, 0.3), 0.03, aa) + stroke(p, vec2(-0.09, 0.04), vec2(0.16, 0.32), 0.022, aa);
	} else if (kind < 27.5) {
		// Sentry deployment: paired barrels, chassis and a tracking reticle.
		icon = box_line(vec2(abs(p.x) - 0.18, p.y - 0.04), vec2(0.07, 0.21), 0.019, aa);
		icon += stroke(p, vec2(-0.30, -0.23), vec2(0.30, -0.23), 0.024, aa) + band(r, 0.09, 0.016, aa);
	} else if (kind < 28.5) {
		float petals = 0.22 + 0.055 * cos(angle * 6.0);
		icon = band(r, petals, 0.022, aa) + cross_mask(p, 0.11, aa);
	} else if (kind < 29.5) {
		icon = stroke(p, vec2(-0.31, 0.14), vec2(0.22, 0.14), 0.025, aa) + stroke(p, vec2(0.31, -0.14), vec2(-0.22, -0.14), 0.025, aa);
		icon += chevron(vec2(p.y - 0.14, -p.x + 0.26), 0.025, aa) + chevron(vec2(-p.y - 0.14, p.x + 0.26), 0.025, aa);
	} else if (kind < 30.5) {
		icon = bolt(p, aa) + band(r, 0.38, 0.019, aa) * step(0.0, cos(angle * 6.0 - t * 2.0));
	} else if (kind < 31.5) {
		icon = chevron(p - vec2(0.0, 0.22), 0.027, aa) + chevron(p, 0.027, aa) + chevron(p + vec2(0.0, 0.22), 0.027, aa);
	} else {
		// Three bent accretion arms and a negative-space event horizon.
		float arms = pow(max(cos(angle * 3.0 + r * 11.0 - t * 2.0), 0.0), 18.0);
		icon = band(r, 0.11, 0.022, aa) + arms * smoothstep(0.15, 0.19, r) * (1.0 - smoothstep(0.34, 0.38, r));
	}
	return clamp(icon, 0.0, 1.0);
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
	float badge = 0.0;
	if (emblem > 0.5) {
		float pop = mix(0.76, 1.0, smoothstep(0.0, 0.17, age));
		badge = cast_emblem(p / pop, emblem, aa, age);
		// Amplified kit ultimates wear a distinct double chevron below the same
		// ability silhouette, preserving instant recognition of the kit mechanic.
		if (rank > 0.75) badge = max(badge, (chevron(p + vec2(0.0, 0.51), 0.013, aa) + chevron(p + vec2(0.0, 0.62), 0.013, aa)) * 0.72);
		badge *= 1.0 - smoothstep(0.52, 0.93, age);
		core *= 0.16;
		detail *= 0.32;
		edge *= 0.66;
	}
	float light = clamp(edge + tail + core + detail + badge + sparks * detail_quality * 0.65, 0.0, 1.0);
	ALBEDO = mix(tint.rgb, hot.rgb, clamp(edge * 0.45 + core + detail * 0.18 + badge * 0.30, 0.0, 0.86));
	ALPHA = light * fade * mask * tint.a * strength;
}
