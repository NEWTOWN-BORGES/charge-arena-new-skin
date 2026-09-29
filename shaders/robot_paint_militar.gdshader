shader_type spatial;
// Robot parts in the worn military look (scripts/art_style.gd "militar"): matte field paint
// chipped down to bare steel on the edges and scuffed on the flats, a film of dust that
// thickens towards the feet, rain streaks running down the panels and gunmetal that has lost
// its polish. Same vertex encoding as robot_paint.gdshader: rgb the paint, alpha the finish
// (1 glow, 0.75 metal, 0.5 dark chassis, 0.45 rubber, 0.25 paint).
render_mode diffuse_burley, specular_schlick_ggx;

uniform float wear : hint_range(0.0, 1.0) = 0.4;
// How much of its own colour the paint keeps: field paint is dull, never candy.
uniform float muted : hint_range(0.0, 1.0) = 0.62;
uniform vec3 dust = vec3(0.42, 0.36, 0.27);
varying vec3 model_position;
varying vec3 model_normal;

void vertex() {
	model_position = VERTEX;
	model_normal = NORMAL;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.55 + noise(p * 2.03 + 7.1) * 0.3 + noise(p * 4.1 + 3.3) * 0.15;
}

void fragment() {
	float finish = COLOR.a;
	bool glow = finish > 0.9;
	bool metal = finish > 0.65 && finish < 0.9;
	bool rubber = finish > 0.4 && finish < 0.48;
	bool dark = finish >= 0.48 && finish < 0.65;
	vec3 base = COLOR.rgb;
	float luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
	if (glow) {
		ALBEDO = base;
		EMISSION = base * 1.5;
		ROUGHNESS = 0.4;
	} else {
		vec3 p = model_position;
		// Edges: where the smoothed normal turns fast across the screen, the paint has taken
		// the knocks. Plus scattered chips on the flats.
		float edge = clamp(length(fwidth(model_normal)) * 3.2, 0.0, 1.0);
		float chips = fbm(p * 34.0);
		float chipped = smoothstep(0.74, 0.8, chips * 0.9 + edge * 0.8 * (0.4 + wear)) * (metal || rubber ? 0.0 : 1.0);
		// Scratches: thin streaks in one direction, a few in another.
		float scratch = smoothstep(0.93, 0.99, noise(p * vec3(3.0, 180.0, 3.0))) + smoothstep(0.95, 0.995, noise(p * vec3(160.0, 4.0, 160.0)));
		// Rain streaks: dirt running down from every ledge.
		float streaks = smoothstep(0.45, 0.9, noise(vec3(p.x * 40.0, p.y * 2.0, p.z * 40.0))) * 0.5;
		// Dust from the ground up, patchy.
		float ground = smoothstep(0.9, 0.0, p.y) * (0.45 + 0.55 * fbm(p * 7.0));
		vec3 paint = mix(vec3(luma), base, muted) * (dark ? 1.0 : 0.9);
		vec3 steel = vec3(0.46, 0.46, 0.45) * (0.8 + 0.3 * noise(p * 60.0));
		vec3 color = metal ? mix(vec3(luma), base, 0.3) * 0.72 : paint;
		color = mix(color, steel, chipped);
		color = mix(color, color * 0.62 + dust * 0.12, streaks * (metal ? 0.3 : 0.7));
		color = mix(color, dust, clamp(ground * (0.35 + wear * 0.5), 0.0, 0.8));
		color = mix(color, steel * 1.25, clamp(scratch, 0.0, 1.0) * 0.35);
		// Mottling in the paint so no panel is one flat colour.
		color *= 0.93 + 0.14 * fbm(p * 3.5);
		ALBEDO = color;
		METALLIC = metal ? 0.85 : mix(dark ? 0.2 : 0.0, 0.8, chipped);
		ROUGHNESS = metal ? 0.42 + 0.2 * noise(p * 40.0) : (rubber ? 0.8 : mix(0.72, 0.4, chipped) + ground * 0.15);
		SPECULAR = rubber ? 0.25 : 0.45;
	}
}
