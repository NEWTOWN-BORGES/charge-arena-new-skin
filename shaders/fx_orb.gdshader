shader_type spatial;
// A projectile, lit from within like the first versions of the game: a white-hot core, a
// bright aura in the shooter's colour around it and a soft halo that fades into the air,
// with a spinning ring of energy when it is charged. Drawn as a camera-facing card sized by
// the node's scale.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

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
	float angle = atan(q.y, q.x) + TIME * 9.0;
	float dashes = step(0.5, fract(angle * 6.0 / 6.283));
	float aa = max(fwidth(d), 0.012);
	float ring = (1.0 - smoothstep(0.024, 0.024 + aa, abs(d - 0.76))) * dashes * charged;
	// Vivid colour: pastel skin colours pushed to a saturated light.
	float grey = dot(tint.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = clamp(mix(vec3(grey), tint.rgb, 1.6) * 1.15, 0.0, 1.0);
	// White-hot core, a solid ring of vivid colour around it, the halo fading out.
	float core = smoothstep(0.19, 0.08, d);
	float aura = 1.0 - smoothstep(0.36, 0.36 + aa * 1.5, d);
	float edge = 1.0 - smoothstep(0.43, 0.43 + aa, d);
	float halo = smoothstep(0.66, 0.39, d) * 0.17;
	vec3 hot = vec3(1.0, 0.97, 0.88);
	vec3 color = mix(vivid, hot, core);
	color = mix(vivid * 0.30, color, aura);
	color = mix(color, vivid * 1.05 + hot * 0.15, ring);
	ALBEDO = color;
	EMISSION = vivid * (core * 0.35 + ring * 0.12);
	ALPHA = clamp(edge + halo + ring, 0.0, 1.0);
}
