shader_type spatial;
// The Leve profile: no per-light passes. A fixed key light baked from the world normal keeps
// the robots readable in flat colour.
render_mode unshaded;

// Colour and finish come from the vertices (see robots.gd); alpha 1 marks lights.
uniform float wear : hint_range(0.0, 1.0) = 0.4;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float key = clamp(dot(world_normal, normalize(vec3(-0.35, 0.85, 0.4))), 0.0, 1.0);
	float shade = mix(0.62, 1.0, smoothstep(0.1, 0.45, key));
	ALBEDO = COLOR.rgb * (COLOR.a > 0.9 ? 1.7 : shade);
}
