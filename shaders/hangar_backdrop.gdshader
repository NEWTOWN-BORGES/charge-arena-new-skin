shader_type canvas_item;
// The hangar's backdrop behind the pilot: a soft studio gradient, a halo of the skin's own
// colour behind the model, a faint hexagon grid fading out towards the top and a few thin
// rings on the floor under the turntable. Everything stays quiet so the pilot is the subject.
uniform vec4 accent : source_color = vec4(0.45, 0.87, 0.78, 1.0);
uniform vec4 top : source_color = vec4(0.93, 0.95, 0.97, 1.0);
uniform vec4 bottom : source_color = vec4(0.82, 0.86, 0.9, 1.0);
uniform float aspect = 1.0;

float hex_edge(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}

void fragment() {
	vec2 uv = UV;
	vec3 color = mix(top.rgb, bottom.rgb, smoothstep(0.0, 1.0, uv.y));
	// The halo behind the pilot.
	vec2 centre = vec2(0.5, 0.52);
	float d = length((uv - centre) * vec2(aspect, 1.0));
	color = mix(color, mix(color, accent.rgb, 0.55), smoothstep(0.55, 0.0, d) * 0.45);
	// Hexagons, a hair darker at their seams, strongest low down.
	vec2 q = vec2(uv.x * aspect, uv.y) * 11.0;
	const vec2 r = vec2(1.0, 1.7320508);
	vec2 a = mod(q, r) - r * 0.5;
	vec2 b = mod(q - r * 0.5, r) - r * 0.5;
	vec2 cell = dot(a, a) < dot(b, b) ? a : b;
	float seam = 1.0 - smoothstep(0.02, 0.05, 0.5 - hex_edge(cell));
	color -= seam * 0.035 * smoothstep(0.1, 0.9, uv.y);
	// Thin rings on the floor under the turntable, seen in perspective.
	vec2 floor_p = (uv - vec2(0.5, 0.86)) * vec2(aspect, 3.2);
	float ring_r = length(floor_p);
	float rings = 0.0;
	for (int i = 1; i <= 3; i++) {
		rings += 1.0 - smoothstep(0.0, 0.006 + 0.002 * float(i), abs(ring_r - 0.22 * float(i)));
	}
	color = mix(color, accent.rgb, rings * 0.18 * smoothstep(0.75, 0.0, ring_r));
	// A soft vignette to hold the eye in the middle.
	color *= 1.0 - smoothstep(0.45, 1.05, length((uv - 0.5) * vec2(aspect * 0.8, 1.1))) * 0.12;
	COLOR = vec4(color, 1.0);
}
