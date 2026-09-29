shader_type spatial;
// The sea of clouds far below the sky arena, painted: soft rolling tops, warm white where the
// sun catches them and lavender-blue in the troughs, drifting slowly, fading into the haze of
// the horizon. One flat sheet: the serras and islands rise out of it.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

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
	// Near the arena the tops of the clouds, further off their shade, then nothing: the sheet
	// melts into the sky so no line shows on the horizon.
	float d = length(world_position.xz);
	vec3 color = mix(top_color, shade_color, smoothstep(30.0, 110.0, d) * 0.5);
	ALBEDO = mix(color, haze_color, smoothstep(60.0, 160.0, d));
	ALPHA = 1.0 - smoothstep(130.0, 225.0, d);
}
