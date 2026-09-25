shader_type spatial;
// Painted robot armour: soft two-tone toon light, a crisp highlight and a cool rim so the
// silhouette separates from the arena floor even at gameplay size.
render_mode diffuse_toon, specular_toon;

uniform vec4 paint : source_color = vec4(0.9, 0.88, 0.8, 1.0);
uniform float metal : hint_range(0.0, 1.0) = 0.0;
uniform float gloss : hint_range(0.0, 1.0) = 0.5;
uniform float glow : hint_range(0.0, 4.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float rim : hint_range(0.0, 1.0) = 0.16;
varying vec3 model_position;
varying vec3 world_normal;

void vertex() {
	model_position = VERTEX;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Faint panel grime towards the feet grounds the figure without any texture fetch.
	float grime = smoothstep(0.9, 0.0, model_position.y) * 0.12;
	// A fixed key from the upper left gives every robot the same readable volume, whatever
	// the arena lights do; the scene light then adds the toon highlight on top.
	float key = clamp(dot(world_normal, normalize(vec3(-0.45, 0.8, 0.4))), 0.0, 1.0);
	float form = mix(0.6, 1.0, smoothstep(0.05, 0.55, key));
	ALBEDO = paint.rgb * (1.0 - grime) * (glow > 0.0 ? 1.0 : form);
	METALLIC = metal;
	ROUGHNESS = mix(0.72, 0.28, gloss);
	SPECULAR = 0.4 + gloss * 0.3;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = paint.rgb * glow + rim_color.rgb * fresnel * rim;
}
