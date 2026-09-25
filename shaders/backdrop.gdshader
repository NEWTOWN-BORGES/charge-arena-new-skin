shader_type canvas_item;
// The sky behind the floating arena: a dusk gradient from the theme, the glow of the stadium
// lights sweeping across it and a sprinkle of stars near the top.
render_mode unshaded;
uniform vec4 sky_top : source_color = vec4(0.04, 0.06, 0.19, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.23, 0.16, 0.43, 1.0);
uniform vec4 sky_low : source_color = vec4(1.0, 0.54, 0.36, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = UV;
	float h = p.y;
	vec3 color = mix(sky_top.rgb, sky_mid.rgb, smoothstep(0.0, 0.62, h));
	color = mix(color, sky_low.rgb, smoothstep(0.55, 1.0, h) * 0.75);
	// Two floodlight beams crossing the sky, drifting slowly.
	for (int i = 0; i < 2; i++) {
		float side = i == 0 ? -1.0 : 1.0;
		vec2 origin = vec2(0.5 + side * 0.62, 1.05);
		vec2 dir = normalize(vec2(-side * (0.55 + 0.08 * sin(TIME * 0.2 + float(i))), -1.0));
		vec2 d = p - origin;
		float along = dot(d, dir);
		float across = abs(d.x * dir.y - d.y * dir.x);
		float beam = smoothstep(0.09 + along * 0.08, 0.0, across) * smoothstep(0.0, 0.2, along) * smoothstep(1.3, 0.4, along);
		color += sky_low.rgb * beam * 0.12;
	}
	// Stars thin out towards the glow.
	vec2 grid = p * vec2(90.0, 160.0);
	vec2 cell = floor(grid);
	vec2 spot = vec2(hash(cell + 1.7), hash(cell + 5.3)) * 0.6 + 0.2;
	float dot_size = 0.06 + 0.06 * hash(cell + 9.1);
	float star = step(0.985, hash(cell)) * (1.0 - smoothstep(dot_size * 0.5, dot_size, length(fract(grid) - spot)));
	star *= 1.0 - smoothstep(0.1, 0.55, h);
	color += vec3(star) * (0.5 + 0.5 * sin(TIME * 2.0 + hash(cell + 3.0) * 20.0)) * 0.6;
	float vignette = smoothstep(0.35, 0.9, length((p - 0.5) * vec2(1.0, 1.1)));
	color *= 1.0 - vignette * 0.4;
	float grain = hash(floor(FRAGCOORD.xy));
	color += (grain - 0.5) * 0.008;
	COLOR = vec4(color, 1.0);
}
