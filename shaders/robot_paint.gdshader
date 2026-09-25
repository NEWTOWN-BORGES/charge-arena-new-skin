shader_type spatial;
// Painted robot armour: soft two-tone toon light, a crisp highlight, a cool rim so the
// silhouette separates from the arena floor, and worn paint on the edges.
render_mode diffuse_toon, specular_toon;

// Colour and finish come from the vertices (see robots.gd): rgb is the paint in linear
// colour, alpha the finish: 1 glow, 0.75 metal, 0.5 dark rubber, 0.25 painted armour.
uniform vec4 rim_color : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float wear : hint_range(0.0, 1.0) = 0.4;
varying vec3 model_position;
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	model_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 paint = COLOR.rgb;
	float finish = COLOR.a;
	float glow = finish > 0.9 ? 1.4 : 0.0;
	float metal = finish > 0.65 && finish < 0.9 ? 0.85 : 0.0;
	float gloss = finish > 0.9 ? 0.0 : (finish > 0.65 ? 0.8 : (finish > 0.4 ? 0.25 : 0.58));
	float rim = finish > 0.9 ? 0.0 : (finish > 0.4 && finish < 0.65 ? 0.1 : 0.16);
	float worn = finish > 0.65 ? 0.0 : wear;
	vec3 n = normalize(world_normal);
	// Curvature: how fast the normal turns per unit of surface. Bevels and rims are the
	// edges that get knocked in a match; flat panels stay clean.
	float span = max(length(fwidth(world_position)), 1e-4);
	float bend = length(fwidth(n)) / span;
	float edge = smoothstep(11.0, 22.0, bend) * worn;
	// Chips and scratches only where a pixel is small enough to hold them.
	float detail = 1.0 - smoothstep(0.012, 0.03, span);
	float chips = 0.0;
	float scratch = 0.0;
	if (detail > 0.0 && worn > 0.0) {
		chips = smoothstep(0.58, 0.64, noise(model_position * 26.0) + edge * 0.35) * edge * detail;
		scratch = smoothstep(0.965, 0.99, noise(model_position * vec3(160.0, 12.0, 160.0))) * (0.15 + edge) * worn * 0.6 * detail;
	}
	// Faint grime towards the feet grounds the figure.
	float grime = smoothstep(0.9, 0.0, model_position.y) * (0.08 + worn * 0.1);
	// A fixed key from the upper left gives every robot the same readable volume, whatever
	// the arena lights do; the scene light then adds the toon highlight on top.
	float key = clamp(dot(n, normalize(vec3(-0.45, 0.8, 0.4))), 0.0, 1.0);
	float form = mix(0.6, 1.0, smoothstep(0.05, 0.55, key));
	vec3 base = paint;
	base = mix(base, base * 1.2 + 0.05, edge * 0.55);
	base = mix(base, vec3(0.5, 0.5, 0.52), max(chips, scratch) * 0.85);
	ALBEDO = base * (1.0 - grime) * (glow > 0.0 ? 1.0 : form);
	METALLIC = mix(metal, 0.7, chips);
	ROUGHNESS = mix(mix(0.72, 0.28, gloss), 0.35, chips);
	SPECULAR = 0.4 + gloss * 0.3;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = paint * glow + rim_color.rgb * fresnel * rim;
}
