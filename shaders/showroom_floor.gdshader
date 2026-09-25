shader_type spatial;
// The lobby's stage floor: a dark disc under the pedestal with a hex grid and light rings
// that fade out towards the edge, so the pilot seems to stand on a pool of light in the sky.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

uniform vec4 base_color : source_color = vec4(0.05, 0.055, 0.15, 1.0);
uniform vec4 line_color : source_color = vec4(0.45, 0.87, 0.78, 1.0);
uniform vec4 warm_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform float radius = 9.0;
varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hex_edge(vec2 p) {
	// Distance to the nearest edge of a hexagon grid of unit size.
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
}

void fragment() {
	float r = length(local.xz) / radius;
	float fade = 1.0 - smoothstep(0.35, 1.0, r);
	float hex = 1.0 - smoothstep(0.0, 0.05, hex_edge(local.xz * 0.9));
	// Rings travelling outwards from the pedestal, slowly.
	float wave = fract(r * 5.0 - TIME * 0.18);
	float rings = smoothstep(0.06, 0.0, abs(wave - 0.5) - 0.44) * (1.0 - r);
	vec3 color = base_color.rgb * (0.7 + 0.5 * fade);
	color += line_color.rgb * hex * 0.12 * fade;
	color += line_color.rgb * rings * 0.18;
	color += warm_color.rgb * smoothstep(0.2, 0.0, r) * 0.08;
	ALBEDO = color;
	ALPHA = clamp(fade * 1.6, 0.0, 1.0);
}
