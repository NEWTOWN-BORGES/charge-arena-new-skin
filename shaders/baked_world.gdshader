shader_type spatial;
// A world with its lighting baked in Blender (tools/blender/bake_world.py): the colour is the
// Cycles light itself, so nothing is lit again here. The light arrives halved and sRGB-encoded,
// because vertex colours are kept in 8 bits. `lift` and `soften` set it to the bright look of
// version 3.8 under the game's AgX grade.
render_mode unshaded, cull_disabled;
const float BAKE_RANGE = 2.0;
uniform float lift = 1.6;
uniform float soften = 0.8;

vec3 decode(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 light = decode(COLOR.rgb) * BAKE_RANGE * lift;
	float grey = dot(light, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(grey), light, soften);
}
