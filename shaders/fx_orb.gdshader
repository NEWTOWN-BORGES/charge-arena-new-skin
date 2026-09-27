shader_type spatial;
// A projectile: a white-hot core in a halo of its colour, and a spinning ring of energy
// when it is charged. Drawn as a camera-facing card sized by the node's scale.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float charged = 0.0;
varying vec2 quad;

void vertex() {
	vec3 center = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	VERTEX = center + vec3(VERTEX.xy * size, 0.0);
	quad = UV;
}

void fragment() {
	vec2 q = quad * 2.0 - 1.0;
	float d = length(q);
	float halo = pow(max(1.0 - d, 0.0), 1.5);
	float core = smoothstep(0.24, 0.08, d);
	float angle = atan(q.y, q.x) + TIME * 9.0;
	float dashes = step(0.5, fract(angle * 6.0 / 6.283));
	float ring = smoothstep(0.07, 0.0, abs(d - 0.72)) * dashes * charged;
	vec3 col = tint.rgb * (halo * 1.25 + ring * 1.5) + vec3(1.0, 0.97, 0.9) * core * 1.2;
	ALBEDO = col;
	ALPHA = clamp(halo * 0.85 + core + ring, 0.0, 1.0);
}
