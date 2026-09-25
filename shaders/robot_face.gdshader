shader_type spatial;
// The robot's face: a dark glass screen with glowing eyes drawn as distance fields, so every
// style stays crisp from the gallery close-up down to a few pixels in the arena.
// style: 0 capsule, 1 dots, 2 bars, 3 square, 4 slant, 5 monocle, 6 visor, 7 equalizer,
//        8 single, 9 rings, 10 stars, 11 arcs.  mood: 0 calm, 1 happy, 2 dizzy.
render_mode unshaded, shadows_disabled;

uniform vec4 eye_color : source_color = vec4(0.5, 0.95, 1.0, 1.0);
uniform vec4 glass : source_color = vec4(0.035, 0.05, 0.075, 1.0);
uniform int style = 0;
uniform int mood = 0;
uniform float aspect = 1.45;
uniform float seed = 0.0;
uniform float mouth = 0.0;
uniform float brightness = 1.6;

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_ring(vec2 p, float r, float t) {
	return abs(length(p) - r) - t;
}

float sd_arch(vec2 p, float r, float t) {
	// Upper half ring: the "^" of a smiling eye.
	return p.y > 0.0 ? abs(length(p) - r) - t : length(vec2(abs(p.x) - r, p.y)) - t;
}

float sd_star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

mat2 turn(float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

float eye(vec2 q, float side) {
	if (mood == 1) return sd_arch(q + vec2(0.0, 0.03), 0.09, 0.028);
	if (mood == 2) {
		vec2 r = turn(TIME * 5.0 * side) * q;
		return min(sd_box(r, vec2(0.1, 0.022), 0.02), sd_box(r, vec2(0.022, 0.1), 0.02));
	}
	if (style == 0) return sd_box(q, vec2(0.065, 0.13), 0.065);
	if (style == 1) return length(q) - 0.095;
	if (style == 2) return sd_box(q, vec2(0.13, 0.045), 0.04);
	if (style == 3) return sd_box(q, vec2(0.1, 0.1), 0.025);
	if (style == 4) return sd_box(turn(0.3 * side) * q, vec2(0.13, 0.04), 0.035);
	if (style == 5) return side < 0.0 ? min(sd_ring(q, 0.13, 0.026), length(q) - 0.045) : length(q) - 0.06;
	if (style == 9) return min(sd_ring(q, 0.11, 0.028), length(q) - 0.035);
	if (style == 10) return sd_star(q, 0.13, 0.45);
	if (style == 11) return sd_arch(q + vec2(0.0, 0.03), 0.09, 0.028);
	return length(q) - 0.095;
}

void fragment() {
	vec2 p = vec2((0.5 - UV.x) * aspect, 0.5 - UV.y);
	float gap = clamp(0.21 * aspect, 0.17, 0.33);
	// A blink every few seconds, offset per robot so two never blink together.
	float t = mod(TIME + seed, 3.7);
	float lid = t < 0.14 ? max(abs(t - 0.07) / 0.07, 0.08) : 1.0;
	vec2 at = p - vec2(0.0, 0.03);
	at.y /= lid;
	float d;
	if (mood == 0 && style == 6) {
		// Visor: one bar across with a light running along it.
		d = sd_box(at, vec2(gap + 0.12, 0.05), 0.045);
	} else if (mood == 0 && style == 7) {
		d = 1.0;
		for (int i = 0; i < 5; i++) {
			float x = mix(-gap, gap, float(i) / 4.0);
			float h = 0.04 + 0.09 * abs(sin(TIME * 6.0 + float(i) * 1.7 + seed));
			d = min(d, sd_box(at - vec2(x, 0.0), vec2(0.035, h), 0.025));
		}
	} else if (mood == 0 && style == 8) {
		d = min(length(at) - 0.15, 1.0);
	} else {
		d = min(eye(at - vec2(-gap, 0.0), -1.0), eye(at - vec2(gap, 0.0), 1.0));
	}
	if (mouth > 0.5 && mood != 2) {
		vec2 m = p - vec2(0.0, -0.2);
		d = min(d, m.y < 0.0 ? abs(length(m) - 0.05) - 0.012 : length(vec2(abs(m.x) - 0.05, m.y)) - 0.012);
	}
	vec3 col = glass.rgb * (0.9 + 0.1 * sin(UV.y * 220.0));
	col *= mix(0.55, 1.0, smoothstep(0.78, 0.2, length((UV - 0.5) * vec2(1.0, 1.25))));
	col += vec3(smoothstep(0.035, 0.0, abs(UV.x * 0.8 + UV.y * 0.5 - 0.42)) * 0.07);
	float aa = max(fwidth(d), 0.002);
	float fill = 1.0 - smoothstep(-aa, aa, d);
	float halo = exp(-max(d, 0.0) * 26.0) * 0.4;
	vec3 lit = eye_color.rgb * brightness;
	if (mood == 0 && style == 6) {
		lit *= 1.0 + 0.8 * smoothstep(0.08, 0.0, abs(p.x - sin(TIME * 2.2 + seed) * gap));
	}
	col = mix(col, lit, fill) + eye_color.rgb * halo * (1.0 - fill);
	ALBEDO = col;
}
