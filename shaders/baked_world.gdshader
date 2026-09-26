shader_type spatial;
// A world with its lighting baked in Blender (tools/blender/bake_world.py): the colour is the
// Cycles light itself, so nothing is lit again here. The game's grade adds contrast and
// saturation on top of AgX; `lift` and `soften` take that back so it matches the render.
render_mode unshaded, cull_back;
uniform float lift = 1.3;
uniform float soften = 0.72;

void fragment() {
	vec3 light = COLOR.rgb * lift;
	float grey = dot(light, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(grey), light, soften);
}
