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
	// Film grain so the gradient never bands on a phone screen.
	color += (hash(floor(FRAGCOORD.xy)) - 0.5) * 0.006;
	COLOR = vec4(color, 1.0);
}
