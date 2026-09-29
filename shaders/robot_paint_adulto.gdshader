shader_type spatial;
// Robot parts in the grown-up stylized look (scripts/art_style.gd "adulto"), the way hero
// shooters paint them: light in two soft bands instead of a smooth falloff, a crisp painted
// highlight, bevels picked out in a lighter tone, a warm rim on the lit side and the armour a
// touch lighter towards the top. Same vertex encoding as robot_paint.gdshader: rgb the paint,
// alpha the finish (1 glow, 0.75 metal, 0.5 dark chassis, 0.45 rubber, 0.25 paint).
render_mode diffuse_burley, specular_schlick_ggx;

uniform float wear : hint_range(0.0, 1.0) = 0.4;
uniform vec3 rim_color = vec3(1.0, 0.86, 0.66);
varying vec3 model_position;
varying vec3 model_normal;

void vertex() {
	model_position = VERTEX;
	model_normal = NORMAL;
}

void fragment() {
	float finish = COLOR.a;
	bool glow = finish > 0.9;
	bool metal = finish > 0.65 && finish < 0.9;
	bool rubber = finish > 0.4 && finish < 0.48;
	vec3 base = COLOR.rgb;
	if (glow) {
		ALBEDO = base;
		EMISSION = base * 1.8;
	} else {
		// Painted bevels: where the normal turns fast, a lighter stroke.
		float edge = clamp(length(fwidth(model_normal)) * 2.5, 0.0, 1.0);
		float height = smoothstep(-0.1, 2.3, model_position.y);
		vec3 color = base * mix(0.86, 1.06, height);
		color = mix(color, min(color * 1.45 + 0.06, vec3(1.0)), edge * (rubber ? 0.2 : 0.6));
		ALBEDO = color;
		METALLIC = metal ? 0.8 : 0.0;
		ROUGHNESS = metal ? 0.3 : (rubber ? 0.75 : 0.45);
		SPECULAR = rubber ? 0.2 : 0.5;
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		EMISSION = rim_color * rim * 0.22 * (rubber ? 0.3 : 1.0);
	}
}

void light() {
	// Two painted bands: shade and light, with a soft step between them.
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.05, 0.12, ndl) * 0.78 + smoothstep(0.55, 0.7, ndl) * 0.22;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / 3.14159;
	// A crisp highlight, the kind that is painted on.
	vec3 halfway = normalize(VIEW + LIGHT);
	float spot = smoothstep(0.9 + ROUGHNESS * 0.06, 0.93 + ROUGHNESS * 0.06, dot(NORMAL, halfway));
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spot * (0.5 - ROUGHNESS * 0.4) * step(0.0, ndl);
}
