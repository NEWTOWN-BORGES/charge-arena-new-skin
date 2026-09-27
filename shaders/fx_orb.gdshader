shader_type spatial;
// A projectile: a round rubber ball in its colour, lit like the Blender renders (a soft key
// from the upper left, a glossy highlight, a darker rim), in a halo of the same colour, with
// a spinning ring of energy when it is charged. Drawn as a camera-facing card sized by the
// node's scale.
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
	float halo = pow(max(1.0 - d, 0.0), 1.5);
	float angle = atan(q.y, q.x) + TIME * 9.0;
	float dashes = step(0.5, fract(angle * 6.0 / 6.283));
	float ring = smoothstep(0.07, 0.0, abs(d - 0.72)) * dashes * charged;
	// The ball: a sphere of radius 0.52 on the card.
	float r = d / 0.52;
	vec3 n = vec3(q.x / 0.52, -q.y / 0.52, sqrt(max(1.0 - r * r, 0.0)));
	vec3 key = normalize(vec3(-0.5, 0.65, 0.75));
	float lit = 0.62 + 0.48 * max(dot(n, key), 0.0);
	float shine = pow(max(dot(reflect(-key, n), vec3(0.0, 0.0, 1.0)), 0.0), 24.0);
	// Pastel skin colours pushed to a vivid paint, so the ball reads against any floor.
	float grey = dot(tint.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 paint = clamp(mix(vec3(grey), tint.rgb, 1.7) * 1.05, 0.0, 1.0);
	vec3 ball = paint * lit * mix(1.0, 0.72, smoothstep(0.72, 1.0, r)) + vec3(1.0) * shine * 0.7;
	float inside = smoothstep(1.0, 0.94, r);
	vec3 glow = tint.rgb * 1.2 + vec3(ring * 0.5);
	ALBEDO = mix(glow, ball, inside);
	ALPHA = max(inside, clamp(halo * 0.75 + ring, 0.0, 1.0));
}
