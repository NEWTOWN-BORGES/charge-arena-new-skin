shader_type spatial;
// The lobby's stage floor: a pale studio floor under the pedestal, a soft contact shade where
// the pedestal stands, fading into the backdrop towards the edge like a photo cyclorama.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

uniform vec4 base_color : source_color = vec4(0.72, 0.75, 0.78, 1.0);
uniform vec4 line_color : source_color = vec4(0.45, 0.87, 0.78, 1.0);
uniform vec4 warm_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform float radius = 9.0;
varying vec3 local;

void fragment() {
	float r = length(local.xz) / radius;
	float fade = 1.0 - smoothstep(0.3, 1.0, r);
	// Soft shade around the pedestal foot, brighter pool further out.
	float shade = smoothstep(0.17, 0.24, r) * 0.12 + 0.88;
	vec3 color = base_color.rgb * shade * (0.96 + 0.06 * fade);
	ALBEDO = color;
	ALPHA = clamp(fade * 1.5, 0.0, 1.0);
}

void vertex() {
	local = VERTEX;
}
