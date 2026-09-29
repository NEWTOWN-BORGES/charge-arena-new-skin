shader_type spatial;
// A meadow painted the anime way (scripts/art_style.gd "melhorado"): the grass colour broken
// into lighter and darker patches, still (the world does not move). Formerly also blade strokes
// and bright bands of wind that sweep
// across it, as the breeze combs the grass in the Ghibli films. Lit, so shadows fall on it.
render_mode diffuse_burley, specular_disabled;

uniform vec4 grass : source_color = vec4(0.45, 0.65, 0.3, 1.0);
uniform vec2 wind = vec2(0.8, 0.6);
uniform float wind_speed = 1.1;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.3 + noise(p * 4.3 + 1.9) * 0.15;
}

void fragment() {
	vec2 p = world_position.xz;
	vec3 base = grass.rgb;
	// Big patches: sun-warmed, yellower grass and cooler, deeper tufts.
	float patches = noise(p * 0.12);
	vec3 color = mix(base * vec3(0.72, 0.85, 0.9), base * vec3(1.18, 1.14, 0.82), smoothstep(0.35, 0.65, patches));
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
