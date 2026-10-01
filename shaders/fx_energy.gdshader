shader_type spatial;
// The light of the powers and ultimates: every ring, beam, shell and bolt they are built from
// is drawn as energy rather than a flat solid - saturated light, densest on the edges it is
// seen through, a hot pale core where it faces the camera and a live turbulence running
// through it. Blended rather than added, so it still reads over the bright arenas, where
// added light washes out. `fade` dims it out as the effect ends.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
uniform float fade = 1.0;
uniform float detail_quality = 1.0;
varying vec3 world_pos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), VIEW));
	float edge = pow(1.0 - facing, 1.6);
	float core = pow(facing, 4.0);
	// Broad bands preserve the silhouette. Leve avoids the eight noise samples.
	float flow = 0.5;
	if (detail_quality > 0.5) flow = noise3(world_pos * 2.2 + vec3(0.0, TIME * 1.8, TIME));
	float band = smoothstep(0.50, 0.68, 0.5 + 0.5 * sin(world_pos.y * 8.0 - TIME * 7.0 + world_pos.x * 1.8));
	float live = 0.78 + 0.22 * flow;
	// Saturated body, a bright centre where it faces the camera, soft edges: a beam of light,
	// not a milky tube.
	float grey = dot(tint.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = clamp(mix(vec3(grey), tint.rgb, 1.45), 0.0, 1.0);
	vec3 hot = mix(vivid, vec3(1.0, 0.98, 0.92), 0.75);
	ALBEDO = mix(vivid * (0.62 + 0.38 * live), hot, clamp(core * 0.36 + band * 0.12 + edge * 0.16, 0.0, 0.65));
	// Solid: a dense body with a brighter core, only thinning a little at the very rim.
	ALPHA = clamp(strength * fade * (0.67 + 0.28 * core + 0.24 * edge), 0.0, 1.0);
}
