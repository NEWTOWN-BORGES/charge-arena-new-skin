shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 tint : source_color = vec4(0.67, 0.40, 1.0, 1.0);
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float detail_quality : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float aa = max(fwidth(radius) * 1.2, 0.008);
	float envelope = smoothstep(0.0, 0.13, age) * (1.0 - smoothstep(0.70, 1.0, age));
	// The horizon breathes as its accretion streams gather. Keep the centre dark
	// enough that this unique ultimate reads as a gravity well, even without glow.
	float horizon = 0.45 + sin(age * 5.0) * 0.035;
	float ring = 1.0 - smoothstep(0.022, 0.022 + aa, abs(radius - horizon));
	float spiral = sin(angle * 3.0 + radius * 16.0 - age * 14.0 + seed);
	float stream = pow(max(0.0, spiral), 12.0) * smoothstep(horizon, horizon + 0.07, radius) * (1.0 - smoothstep(0.72, 0.92, radius));
	// A segmented outer corona preserves the silhouette around the dark core.
	float corona = (1.0 - smoothstep(0.013, 0.013 + aa, abs(radius - horizon - 0.12))) * smoothstep(-0.1, 0.25, sin(angle * 8.0 - age * 4.0 + seed));
	float dark_core = 1.0 - smoothstep(horizon - 0.07, horizon, radius);
	float outer_arc = (1.0 - smoothstep(0.009, 0.009 + aa, abs(radius - horizon - 0.23))) * smoothstep(0.38, 0.72, sin(angle * 3.0 + age * 7.0));
	float falling_motes = pow(max(0.0, cos(angle * 9.0 + radius * 8.0 + age * 11.0)), 42.0) * (1.0 - smoothstep(0.016, 0.016 + aa, abs(radius - 0.78 + age * 0.21)));
	vec3 rim_color = mix(tint.rgb, vec3(0.88, 0.92, 1.0), clamp(ring * 0.46 + stream * 0.24, 0.0, 0.7));
	ALBEDO = mix(rim_color, vec3(0.018, 0.012, 0.037), dark_core);
	ALPHA = clamp(dark_core * 0.86 + ring + stream * 0.74 + corona * 0.7 + (outer_arc * 0.5 + falling_motes * 0.55) * detail_quality, 0.0, 1.0) * envelope * tint.a;
}
