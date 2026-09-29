shader_type spatial;
// Robot parts in the pro sports look (scripts/art_style.gd "premium"): deep metallic car
// paint with flakes under a hard clear coat, chrome, a carbon fibre chassis and matte rubber.
// Same vertex encoding as robot_paint.gdshader: rgb the paint, alpha the finish (1 glow,
// 0.75 metal, 0.5 dark chassis, 0.45 rubber, 0.25 paint).
render_mode diffuse_burley, specular_schlick_ggx;

uniform float wear : hint_range(0.0, 1.0) = 0.4;
varying vec3 model_position;
varying vec3 model_normal;

void vertex() {
	model_position = VERTEX;
	model_normal = NORMAL;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float weave(vec2 uv) {
	// Twill carbon: two sets of tows crossing, each tow shaded across its width.
	vec2 g = uv * 55.0;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	bool along = mod(cell.x + cell.y, 2.0) < 1.0;
	float across = along ? f.y : f.x;
	return 0.55 + 0.45 * sin(across * 3.14159);
}

void fragment() {
	float finish = COLOR.a;
	bool glow = finish > 0.9;
	bool metal = finish > 0.65 && finish < 0.9;
	bool rubber = finish > 0.4 && finish < 0.48;
	bool dark = finish >= 0.48 && finish < 0.65;
	vec3 base = COLOR.rgb;
	if (glow) {
		ALBEDO = base;
		EMISSION = base * 2.0;
		ROUGHNESS = 0.3;
	} else if (metal) {
		// Polished chrome.
		ALBEDO = base;
		METALLIC = 1.0;
		ROUGHNESS = 0.06;
	} else if (dark) {
		// Carbon fibre, projected on the face's main axis, under lacquer.
		vec3 n = abs(model_normal);
		vec2 uv = n.x > max(n.y, n.z) ? model_position.yz : (n.y > n.z ? model_position.xz : model_position.xy);
		ALBEDO = base * (0.7 + 0.9 * weave(uv));
		METALLIC = 0.35;
		ROUGHNESS = 0.32;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.04;
	} else if (rubber) {
		ALBEDO = base;
		ROUGHNESS = 0.78;
		SPECULAR = 0.3;
	} else {
		// Metallic paint: flakes that sparkle as the view moves, a mirror clear coat on top.
		float flake = hash3(floor(model_position * 520.0));
		ALBEDO = base * (0.92 + 0.12 * flake);
		METALLIC = 0.5;
		ROUGHNESS = 0.26 - 0.14 * step(0.9, flake);
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.02;
		SPECULAR = 0.6;
	}
}
