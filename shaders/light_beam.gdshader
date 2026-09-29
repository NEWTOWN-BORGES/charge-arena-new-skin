shader_type spatial;
// A searchlight beam over a goal: a soft shaft of light, brightest at its foot and along its
// middle, fading out as it climbs. Added to the scene, never lit, never in the depth buffer.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float intensity = 0.6;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = 1.0 - UV.y;
	float shaft = pow(across, 2.2) * pow(along, 1.6);
	// Motes drifting up the beam.
	float motes = 0.85 + 0.15 * sin(UV.y * 40.0 - TIME * 6.0);
	ALBEDO = tint.rgb * shaft * motes * intensity * 1.6;
}
