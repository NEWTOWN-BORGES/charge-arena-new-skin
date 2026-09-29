shader_type spatial;
// The sea of clouds far below the sky arena, painted: soft rolling tops, warm white where the
// sun catches them and lavender-blue in the troughs, drifting slowly, fading into the haze of
// the horizon. One flat sheet: the serras and islands rise out of it.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 top_color = vec3(1.0, 0.98, 0.94);
uniform vec3 shade_color = vec3(0.58, 0.66, 0.84);
uniform vec3 haze_color = vec3(0.78, 0.86, 0.95);
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

void fragment() {
	vec2 p = world_position.xz * 0.03 + vec2(TIME * 0.004, TIME * 0.002);
	// Rolls of cloud: big swells, smaller puffs on them.
	float swell = noise(p) * 0.6 + noise(p * 2.3 + 5.1) * 0.3 + noise(p * 5.2 + 1.7) * 0.1;
	// Light from the sun's side of each roll: the difference with a sample towards it.
	float toward = noise((p + vec2(-0.08, -0.05))) * 0.6 + noise((p + vec2(-0.08, -0.05)) * 2.3 + 5.1) * 0.3;
	float lit = clamp((swell - toward) * 6.0 + swell, 0.0, 1.0);
	vec3 color = mix(shade_color, top_color, smoothstep(0.4, 0.62, lit));
	// Far away the sea melts into the haze of the horizon.
	float far = smoothstep(40.0, 180.0, length(world_position.xz));
	ALBEDO = mix(color, haze_color, far);
}
