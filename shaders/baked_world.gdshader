shader_type spatial;
// A world with its lighting baked in Blender (tools/blender/bake_world.py): the colour is the
// Cycles light itself, so nothing is lit again here, and the game's colour table (the same
// transform as the Blender render) does the rest. The light arrives halved and sRGB-encoded,
// because vertex colours are kept in 8 bits.
render_mode unshaded, cull_disabled;
const float BAKE_RANGE = 2.0;

vec3 decode(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	ALBEDO = decode(COLOR.rgb) * BAKE_RANGE;
}
