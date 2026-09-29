shader_type spatial;
// The land far below the sky arena: one painted aerial map (fields, forests, rivers, a town)
// seen through the mist of the height. Static and unshaded; it melts into the sky at the
// horizon so no line shows.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform sampler2D land : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 haze_color = vec3(0.78, 0.86, 0.95);
// How much of the height's mist lies over the land even straight down.
uniform float mist = 0.3;
// How many times the painted map repeats across the sheet.
uniform float tiles = 2.5;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = length(world_position.xz);
	vec3 color = texture(land, UV * tiles).rgb;
	ALBEDO = mix(color, haze_color, clamp(mist + smoothstep(60.0, 380.0, d) * (1.0 - mist), 0.0, 1.0));
	ALPHA = 1.0 - smoothstep(380.0, 650.0, d);
}
