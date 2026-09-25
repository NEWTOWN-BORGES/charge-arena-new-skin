shader_type spatial;
// The Leve profile: no per-light passes. A fixed key light baked from the world normal keeps
// the robots readable in flat colour.
render_mode unshaded;

uniform vec4 paint : source_color = vec4(0.9, 0.88, 0.8, 1.0);
uniform float metal : hint_range(0.0, 1.0) = 0.0;
uniform float gloss : hint_range(0.0, 1.0) = 0.5;
uniform float glow : hint_range(0.0, 4.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float rim : hint_range(0.0, 1.0) = 0.22;
uniform float wear : hint_range(0.0, 1.0) = 0.4;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float key = clamp(dot(world_normal, normalize(vec3(-0.35, 0.85, 0.4))), 0.0, 1.0);
	float shade = mix(0.62, 1.0, smoothstep(0.1, 0.45, key));
	ALBEDO = paint.rgb * (glow > 0.0 ? 1.0 + glow * 0.5 : shade);
}
