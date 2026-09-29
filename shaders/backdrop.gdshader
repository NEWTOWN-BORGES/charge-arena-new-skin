shader_type canvas_item;
// The studio behind the floating arena: a soft, even backdrop in the theme's pale tones,
// brighter behind the platform and falling off gently to the corners, like a photo cyclorama.
render_mode unshaded;
uniform vec4 sky_top : source_color = vec4(0.72, 0.75, 0.78, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.66, 0.69, 0.72, 1.0);
uniform vec4 sky_low : source_color = vec4(0.78, 0.8, 0.82, 1.0);
// Space: a starfield over the gradient (0 = none).
uniform float stars = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Day skies: a soft sun and high, thin clouds drawn over the gradient (0 = the plain studio).
uniform float daylight = 0.0;
uniform vec2 sun_at = vec2(0.18, 0.1);

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	// Three octaves: on a phone every one is paid on every pixel of the sky.
	for (int k = 0; k < 3; k++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV;
	vec3 color = mix(sky_top.rgb, sky_mid.rgb, smoothstep(0.0, 0.55, p.y));
	color = mix(color, sky_low.rgb, smoothstep(0.5, 1.0, p.y));
	// A broad pool of light behind the arena.
	float pool = 1.0 - smoothstep(0.0, 0.75, length((p - vec2(0.5, 0.52)) * vec2(1.0, 0.8)));
	color *= 0.93 + pool * 0.1;
	float vignette = smoothstep(0.45, 1.0, length((p - 0.5) * vec2(1.0, 1.1)));
	color *= 1.0 - vignette * 0.14;
	if (stars > 0.0) {
		// Two layers of stars on a pixel grid: many faint points and a few bright ones.
		vec2 fine = floor(FRAGCOORD.xy / 3.0);
		vec2 coarse = floor(FRAGCOORD.xy / 7.0);
		float faint = step(0.9955, hash(fine)) * (0.35 + 0.4 * hash(fine + 3.7));
		float bright = step(0.9985, hash(coarse + 11.3)) * smoothstep(3.5, 0.5, length(FRAGCOORD.xy - (coarse + 0.5) * 7.0));
		color = mix(color, vec3(1.0, 0.97, 0.92), clamp(faint + bright, 0.0, 1.0) * stars);
	}
	if (daylight > 0.0) {
		// The sun: a white core in a wide warm halo.
		float d = length((p - sun_at) * vec2(1.6, 1.0));
		vec3 sun = vec3(1.0, 0.96, 0.86) * (smoothstep(0.05, 0.0, d) * 0.9 + exp(-d * 5.0) * 0.35 + exp(-d * 1.6) * 0.12);
		// Cirrus: streaks of thin cloud, stretched sideways, thinning towards the horizon.
		vec2 q = vec2(p.x * 2.2 + TIME * 0.004, p.y * 7.0);
		float wisps = smoothstep(0.52, 0.85, fbm(q + vnoise(q * 0.7) * 0.8)) * smoothstep(0.75, 0.15, p.y);
		color = mix(color, vec3(1.0), wisps * 0.55 * daylight);
		// Towering cumulus along the horizon, painted: billowing tops of rounded puffs, a flat
		// soft base, warm white where the sun catches them and a cool blue shade on the far side.
		float x = p.x * 2.4 + TIME * 0.002;
		float tower = fbm(vec2(x * 0.8, 3.1)) * 1.3 - 0.25;
		float top = 0.26 - 0.24 * clamp(tower, 0.0, 1.0);
		vec2 c = vec2(x * 3.0, p.y * 6.0);
		float billows = fbm(c + vnoise(c * 0.9 + 4.0) * 0.9);
		float edge = top + (billows - 0.5) * 0.12;
		float base_line = 0.3 + (vnoise(vec2(x * 4.0, 1.0)) - 0.5) * 0.02;
		float body = smoothstep(edge, edge + 0.018, p.y) * smoothstep(base_line + 0.01, base_line - 0.02, p.y);
		// Light: the puffs facing up and towards the sun are lit, the rest in shade.
		float lobes = fbm(c * 2.2 + 11.0);
		float light = clamp((base_line - p.y) / max(base_line - top, 0.05), 0.0, 1.0) * 0.8 + (lobes - 0.5) * 0.9 + (0.5 - abs(p.x - sun_at.x)) * 0.3;
		vec3 shade = vec3(0.5, 0.6, 0.78);
		vec3 lit = vec3(1.0, 0.97, 0.9);
		vec3 puff = mix(shade, mix(vec3(0.86, 0.89, 0.95), lit, smoothstep(0.55, 0.62, light)), smoothstep(0.2, 0.28, light));
		color = mix(color, puff, body * daylight);
		// The horizon hazes to a pale band.
		color = mix(color, vec3(0.92, 0.95, 0.98), smoothstep(0.55, 0.95, p.y) * 0.25 * daylight);
		color += sun * daylight;
	}
	// Film grain so the gradient never bands on a phone screen.
	color += (hash(floor(FRAGCOORD.xy)) - 0.5) * 0.006;
	COLOR = vec4(color, 1.0);
}
