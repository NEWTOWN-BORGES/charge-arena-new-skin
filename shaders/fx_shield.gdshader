shader_type spatial;
// A shield of light: a hexagon lattice over the surface, brightest on the edges it is seen
// through, a scan band sweeping up it, a build-up that raises it from the ground and a
// ripple that runs out from where it is struck. Used by the dome over a wall and by the
// bubble of an immune pilot.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
// 0..1: how much of the shield has risen from the ground (by height in the mesh).
uniform float rise = 1.0;
uniform float cells = 9.0;
// World position and start time of the last blow it took (time < 0: none).
uniform vec3 ripple_at = vec3(0.0);
uniform float ripple_time = -10.0;
varying vec3 local_pos;
varying vec3 world_pos;

float hex_edge(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Latitude and longitude on the (scaled) sphere give a lattice that wraps it.
	vec3 n = normalize(local_pos);
	vec2 sph = vec2(atan(n.z, n.x) / 6.2831853 * cells * 2.0, asin(clamp(n.y, -1.0, 1.0)) / 3.14159 * cells);
	const vec2 r = vec2(1.0, 1.7320508);
	vec2 a = mod(sph, r) - r * 0.5;
	vec2 b = mod(sph - r * 0.5, r) - r * 0.5;
	vec2 cell = dot(a, a) < dot(b, b) ? a : b;
	float edge_dist = 0.5 - hex_edge(cell);
	float aa = max(fwidth(edge_dist), 0.004);
	float lattice = 1.0 - smoothstep(0.018, 0.018 + aa * 1.5, edge_dist);
	float facing = abs(dot(normalize(NORMAL), VIEW));
	float rim = pow(1.0 - facing, 2.2);
	// The band of light running up the shield.
	float height = n.y * 0.5 + 0.5;
	float scan = smoothstep(0.08, 0.0, abs(height - fract(TIME * 0.45)));
	// Rising from the ground: everything above the current height is not there yet, and the
	// growing edge burns bright.
	float front = smoothstep(rise + 0.02, rise - 0.02, height);
	float lip = smoothstep(0.06, 0.0, abs(height - rise)) * step(rise, 0.999);
	// The ripple from the last blow.
	float since = TIME - ripple_time;
	float ring = 0.0;
	if (since >= 0.0 && since < 1.2) {
		float d = distance(world_pos, ripple_at);
		ring = smoothstep(0.35, 0.0, abs(d - since * 5.0)) * (1.0 - since / 1.2);
	}
	float grey = dot(tint.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 vivid = clamp(mix(vec3(grey), tint.rgb, 1.35), 0.0, 1.0);
	vec3 hot = mix(vivid, vec3(1.0, 0.99, 0.95), 0.7);
	// A clear centre keeps the robot visible; the perimeter and hits carry the shield.
	float light = 0.045 + lattice * 0.42 + rim * 0.82 + scan * 0.22 + ring * 1.2 + lip * 1.5;
	ALBEDO = mix(vivid, hot, clamp(lattice * 0.4 + ring + lip + scan * 0.3, 0.0, 1.0));
	ALPHA = clamp(light * strength * front, 0.0, 1.0);
}
