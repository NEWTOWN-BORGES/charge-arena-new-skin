shader_type spatial;
// Robot parts in the dark neon look (scripts/art_style.gd "neon"): black lacquered armour
// that mirrors the night, trims and lights burning in neon (they arrive as glow), a cyan rim on
// one side of every silhouette and a magenta one on the other. Same vertex encoding as
// robot_paint.gdshader: rgb the paint, alpha the finish (1 glow, 0.75 metal, 0.5 dark chassis,
// 0.45 rubber, 0.25 paint).
render_mode diffuse_burley, specular_schlick_ggx;

uniform float wear : hint_range(0.0, 1.0) = 0.4;
uniform vec3 rim_left = vec3(0.25, 0.95, 1.0);
uniform vec3 rim_right = vec3(1.0, 0.2, 0.62);
varying vec3 model_position;

void vertex() {
	model_position = VERTEX;
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

void fragment() {
	float finish = COLOR.a;
	bool glow = finish > 0.9;
	bool metal = finish > 0.65 && finish < 0.9;
	bool rubber = finish > 0.4 && finish < 0.48;
	bool dark = finish >= 0.48 && finish < 0.65;
	vec3 base = COLOR.rgb;
	if (glow) {
		// A neon tube: a white-hot core, its colour all around.
		float core = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		ALBEDO = base * 0.3;
		EMISSION = mix(base, vec3(1.0), core * 0.35) * 2.4;
		ROUGHNESS = 0.3;
	} else {
		ALBEDO = base;
		METALLIC = metal ? 0.9 : (dark ? 0.55 : 0.4);
		ROUGHNESS = metal ? 0.2 : (rubber ? 0.7 : 0.12 + 0.08 * noise(model_position * 24.0));
		SPECULAR = rubber ? 0.3 : 0.7;
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
		vec3 side = mix(rim_left, rim_right, smoothstep(-0.2, 0.2, NORMAL.x));
		EMISSION = side * rim * (rubber ? 0.2 : 0.55);
	}
}
