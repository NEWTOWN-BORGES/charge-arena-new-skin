shader_type spatial;
// Arena floor: large bevelled hexagon plates, each half tinted towards its team, neon
// centre rings and a few plates that breathe with light. Colours come from the arena theme.
render_mode cull_disabled;
varying vec3 world_pos;
uniform vec4 floor_color : source_color = vec4(0.14, 0.23, 0.4, 1.0);
uniform vec4 floor_alt : source_color = vec4(0.17, 0.27, 0.46, 1.0);
uniform vec4 seam_color : source_color = vec4(0.06, 0.1, 0.2, 1.0);
uniform vec4 line_color : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform vec4 team_near : source_color = vec4(0.45, 0.87, 0.78, 1.0);
uniform vec4 team_far : source_color = vec4(0.94, 0.58, 0.49, 1.0);
uniform float finish_quality = 2.0;
uniform sampler2D surface_grain : filter_linear_mipmap_anisotropic, repeat_enable;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hex_edge(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}

float ring_line(float r, float target, float width) {
	float aa = max(fwidth(r), 0.008);
	return 1.0 - smoothstep(max(0.0, width - aa), width + aa, abs(r - target));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = world_pos.xz;
	// Hex grid, one plate ~1.1 units across.
	vec2 q = p / 0.64;
	const vec2 r = vec2(1.0, 1.7320508);
	vec2 a = mod(q, r) - r * 0.5;
	vec2 b = mod(q - r * 0.5, r) - r * 0.5;
	vec2 cell = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = floor((q - cell) * 2.0 + 0.5);
	float edge = 0.5 - hex_edge(cell);
	float aa = max(fwidth(edge), 0.001);
	float seam = 1.0 - smoothstep(0.015, 0.015 + aa * 1.5, edge);
	float bevel = (1.0 - smoothstep(0.03, 0.075, edge)) * (1.0 - seam);
	float pick = hash(id);
	vec3 base = mix(floor_color.rgb, floor_alt.rgb, step(0.5, pick));
	base *= 0.94 + 0.12 * pick;
	// Each half leans towards its team, strongest in front of the goals.
	float side = p.y > 0.0 ? 1.0 : 0.0;
	vec3 team = mix(team_far.rgb, team_near.rgb, side);
	float reach = smoothstep(1.5, 7.5, abs(p.y));
	base = mix(base, team * 0.42, reach * 0.35);
	base = mix(base, seam_color.rgb, seam * 0.9);
	base += vec3(0.05) * bevel;
	float grain = finish_quality > 0.5 ? texture(surface_grain, p * 0.75).r : 0.94;
	base *= 0.94 + grain * 0.1;
	// Centre medallion: two neon rings, a tick dial and the dashed half-way line.
	float rad = length(p);
	float rings = ring_line(rad, 2.12, 0.03) + ring_line(rad, 2.34, 0.012);
	float ticks = step(0.78, fract(atan(p.y, p.x) * 24.0 / 6.28318)) * ring_line(rad, 2.55, 0.07);
	float mid = (1.0 - smoothstep(0.012, 0.012 + fwidth(p.y), abs(p.y))) * step(0.45, fract(p.x * 1.3));
	float neon = clamp(rings + ticks * 0.7 + mid * 0.8, 0.0, 1.0);
	base = mix(base, line_color.rgb, neon * 0.75);
	// A few plates near each goal pulse softly in the team colour.
	float lit = step(0.9, hash(id + 7.3)) * reach;
	float pulse = 0.5 + 0.5 * sin(TIME * 1.6 + pick * 12.0);
	ALBEDO = base;
	METALLIC = 0.3;
	ROUGHNESS = mix(0.5, 0.78, seam);
	SPECULAR = 0.6;
	CLEARCOAT = finish_quality > 1.5 ? 0.3 : 0.0;
	CLEARCOAT_ROUGHNESS = 0.35;
	EMISSION = line_color.rgb * neon * 0.55 + team * lit * pulse * 0.18 * (1.0 - seam);
}
