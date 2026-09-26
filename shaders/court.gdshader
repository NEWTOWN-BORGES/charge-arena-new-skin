shader_type spatial;
// Arena floor in the studio look: large matte hexagon plates in the theme's pale tones, soft
// seams with a rounded bevel, each half leaning gently towards its team, and the centre
// markings painted on, not lit. Colours come from the arena theme.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 world_pos;
uniform vec4 floor_color : source_color = vec4(0.78, 0.81, 0.84, 1.0);
uniform vec4 floor_alt : source_color = vec4(0.75, 0.78, 0.82, 1.0);
uniform vec4 seam_color : source_color = vec4(0.62, 0.66, 0.7, 1.0);
uniform vec4 line_color : source_color = vec4(0.97, 0.98, 0.99, 1.0);
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
	vec2 q = p / 0.64;
	const vec2 r = vec2(1.0, 1.7320508);
	vec2 a = mod(q, r) - r * 0.5;
	vec2 b = mod(q - r * 0.5, r) - r * 0.5;
	vec2 cell = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = floor((q - cell) * 2.0 + 0.5);
	float edge = 0.5 - hex_edge(cell);
	float aa = max(fwidth(edge), 0.001);
	float seam = 1.0 - smoothstep(0.01, 0.01 + aa * 1.5, edge);
	float bevel = (1.0 - smoothstep(0.012, 0.06, edge)) * (1.0 - seam);
	float pick = hash(id);
	vec3 base = mix(floor_color.rgb, floor_alt.rgb, step(0.5, pick));
	base *= 0.985 + 0.03 * pick;
	// Each half leans gently towards its team, most in front of the goals.
	float side = p.y > 0.0 ? 1.0 : 0.0;
	vec3 team = mix(team_far.rgb, team_near.rgb, side);
	float reach = smoothstep(2.0, 8.0, abs(p.y));
	base = mix(base, base * mix(vec3(1.0), team, 0.55), reach * 0.35);
	base = mix(base, seam_color.rgb, seam * 0.85);
	// The rounded edge of each plate catches the light.
	base += vec3(0.04) * bevel;
	// Centre markings: two painted rings, a dial of ticks and the dashed half-way line.
	float rad = length(p);
	float rings = ring_line(rad, 2.12, 0.035) + ring_line(rad, 2.34, 0.014);
	float ticks = step(0.78, fract(atan(p.y, p.x) * 24.0 / 6.28318)) * ring_line(rad, 2.55, 0.06);
	float mid = (1.0 - smoothstep(0.014, 0.014 + fwidth(p.y), abs(p.y))) * step(0.45, fract(p.x * 1.3));
	float paint = clamp(rings + ticks * 0.8 + mid * 0.9, 0.0, 1.0);
	base = mix(base, line_color.rgb, paint * 0.85);
	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.62, 0.8, seam) - paint * 0.15;
	SPECULAR = 0.45;
}
