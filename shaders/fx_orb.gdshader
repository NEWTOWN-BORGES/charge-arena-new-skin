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
	float ring = smoothstep(0.07, 0.0, abs(d - 0.78)) * dashes * charged;
	// Vivid colour: pastel skin colours pushed to a saturated light.
	float grey = dot(tint.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = clamp(mix(vec3(grey), tint.rgb, 1.6) * 1.15, 0.0, 1.0);
	// White-hot core, a solid ring of vivid colour around it, the halo fading out.
	float core = smoothstep(0.24, 0.1, d);
	float aura = smoothstep(0.58, 0.46, d);
	float halo = pow(max(1.0 - d, 0.0), 1.4);
	vec3 hot = vec3(1.0, 0.97, 0.88);
	vec3 color = mix(vivid, hot, core);
	color = mix(vivid * 0.9, color, aura);
	color += vec3(ring * 0.6);
	ALBEDO = color;
	ALPHA = clamp(aura + halo * 0.85 + ring, 0.0, 1.0);
}
