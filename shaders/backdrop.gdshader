shader_type canvas_item;
// The studio behind the floating arena: a soft, even backdrop in the theme's pale tones,
// brighter behind the platform and falling off gently to the corners, like a photo cyclorama.
render_mode unshaded;
uniform vec4 sky_top : source_color = vec4(0.72, 0.75, 0.78, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.66, 0.69, 0.72, 1.0);
uniform vec4 sky_low : source_color = vec4(0.78, 0.8, 0.82, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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
	// Film grain so the gradient never bands on a phone screen.
	color += (hash(floor(FRAGCOORD.xy)) - 0.5) * 0.006;
	COLOR = vec4(color, 1.0);
}
