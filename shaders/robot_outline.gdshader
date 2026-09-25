shader_type spatial;
// Inverted hull: the back faces of a slightly inflated copy draw the ink line around a robot.
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float width = 0.014;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = ink.rgb;
}
