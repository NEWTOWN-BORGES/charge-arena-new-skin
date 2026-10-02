shader_type spatial;
// Robot parts in the studio look, with real surfaces: glossy lacquered paint with a clear coat,
// polished metal, graphite chassis and lit sensors. A fine grain in the finish (orange peel on
// the paint, brushing on the metal) and a rim of light on the silhouettes keep them from
// reading as matte rubber.
render_mode diffuse_burley, specular_schlick_ggx;

// Colour and finish come from the vertices (see robots.gd): rgb is the paint in linear
// colour, alpha the finish: 1 glow, 0.75 metal, 0.5 dark chassis, 0.45 rubber, 0.25 paint.
uniform float wear : hint_range(0.0, 1.0) = 0.4;
uniform sampler2D surface_grain : filter_linear_mipmap, repeat_enable;
uniform float surface_detail = 1.0;
// The colour of the air far away (scenery fades into it).
uniform vec3 haze = vec3(0.55, 0.68, 0.82);
// Towards the sun (world space) and the strength of the painted scenery.
uniform vec3 sun_dir = vec3(-0.45, 0.75, 0.48);
uniform float paint_gain = 1.25;
varying vec3 model_position;
// Preserve the roster's saturated paint instead of mixing it into milky grey.
vec3 studio(vec3 paint, float finish) {
 return paint * (finish > 0.9 ? 1.0 : 1.12);
}

varying vec3 model_normal;
varying vec3 world_position;
varying vec3 world_normal;
// Foliage and clouds are lit as one volume: the normal of the whole crown (from its middle,
// about 1.6 m above the tree's base at its scale) blended with the tuft's own.
varying vec3 volume_normal;

void vertex() {
	if (COLOR.a > 0.2 && COLOR.a < 0.24) {
		// Grass: the blades sway in the wind, the tips most, each tuft a little out of step.
		vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float sway = sin(TIME * 2.1 + root.x * 0.7 + root.z * 0.45) * 0.6 + sin(TIME * 3.4 + root.x * 1.3 - root.z) * 0.25;
		float bend = max(VERTEX.y, 0.0);
		VERTEX.x += sway * bend * bend * 1.6;
		VERTEX.z += sway * bend * bend * 0.9;
	}
	model_position = VERTEX;
	model_normal = NORMAL;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 middle = (MODEL_MATRIX * vec4(0.0, COLOR.a < 0.2 ? 0.5 : 1.6, 0.0, 1.0)).xyz;
	vec3 outward = normalize(world_position - middle + vec3(0.0, 0.0001, 0.0));
	volume_normal = normalize(mix(world_normal, outward, 0.65));
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float grain(vec3 p) {
	// Value noise: the grain of the finish.
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void fragment() {
	if (COLOR.a < 0.1) {
		// Rock: matte stone in strata and blotches, darker in the cracks facing down.
		float strata = 0.5 + 0.5 * sin(world_position.y * 3.1);
		float blotch = 0.5;
		float up = normalize(world_normal).y;
		vec3 stone = COLOR.rgb * (0.78 + 0.22 * strata + 0.2 * (blotch - 0.5)) * mix(0.7, 1.05, smoothstep(-0.5, 0.6, up));
		// Aerial perspective: far stone fades into the blue of the air.
		float far = smoothstep(25.0, 110.0, length(world_position - CAMERA_POSITION_WORLD));
		ALBEDO = mix(stone, haze, far * 0.6);
		// Light bounced up from the ground and the clouds below: undersides are never black.
		EMISSION = haze * far * 0.25 + stone * 0.22 * smoothstep(0.3, -0.8, up);
		ROUGHNESS = 0.92;
		SPECULAR = 0.2;
	} else if (COLOR.a < 0.2) {
		// Cloud, painted the anime way: warm white where the sun falls, a cool lavender-blue
		// shade underneath, the edge between them broken like brush strokes.
		vec3 n = normalize(mix(world_normal, volume_normal, 0.5));
		float brush = 0.5;
		float lit = dot(n, sun_dir) * 0.55 + n.y * 0.45 + (brush - 0.5) * 0.7;
		vec3 shade = vec3(0.56, 0.64, 0.8);
		vec3 mid = vec3(0.83, 0.87, 0.94);
		vec3 bright = vec3(1.0, 0.97, 0.9);
		vec3 cloud = mix(shade, mid, smoothstep(-0.12, -0.02, lit));
		cloud = mix(cloud, bright, smoothstep(0.3, 0.4, lit));
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = cloud * COLOR.rgb * paint_gain;
	} else if (COLOR.a > 0.26 && COLOR.a < 0.29) {
		// Turf: a meadow painted on the top of an island, sunlit and shaded patches.
		float patches = 0.5;
		vec3 turf = COLOR.rgb * mix(vec3(0.74, 0.86, 0.9), vec3(1.2, 1.16, 0.84), smoothstep(0.35, 0.7, patches));
		ALBEDO = turf;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else if (COLOR.a > 0.2 && COLOR.a < 0.24) {
		// Grass blades: deep at the root, sunlit and warm at the tips.
		float t = clamp(model_position.y / 0.45, 0.0, 1.0);
		ALBEDO = COLOR.rgb * mix(vec3(0.55, 0.72, 0.74), vec3(1.28, 1.22, 0.86), t);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else if (COLOR.a > 0.3 && COLOR.a < 0.4) {
		// Foliage, painted the anime way: three flat tones (a teal shade, the leaf green and a
		// warm sunlit green), the borders between them broken into leaf-clump strokes, and the
		// underside of the crown in deep shade.
		vec3 n = normalize(volume_normal);
		float brush = 0.5;
		float lit = dot(n, sun_dir) * 0.8 + (brush - 0.5) * 1.0 + 0.1;
		vec3 base = COLOR.rgb;
		vec3 shade = base * vec3(0.5, 0.64, 0.7);
		vec3 mid = base * 0.95;
		vec3 bright = base * vec3(1.3, 1.26, 0.82) + vec3(0.02, 0.02, 0.0);
		vec3 leaves = mix(shade, mid, smoothstep(-0.14, -0.06, lit));
		leaves = mix(leaves, bright, smoothstep(0.42, 0.5, lit));
		leaves *= mix(0.72, 1.0, smoothstep(-0.8, 0.1, n.y));
		float far = smoothstep(25.0, 110.0, length(world_position - CAMERA_POSITION_WORLD));
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = mix(leaves, haze, far * 0.5) * paint_gain;
	} else {
		vec3 paint = studio(COLOR.rgb, COLOR.a);
		float finish = COLOR.a;
		bool glow = finish > 0.9;
		bool metal = finish > 0.65 && finish < 0.9;
		bool rubber = finish > 0.4 && finish < 0.48;
		bool dark = finish >= 0.48 && finish < 0.65;
		// A breath of dust towards the feet grounds the figure without dirtying it.
		float grime = smoothstep(0.5, 0.0, model_position.y) * 0.06 * (0.5 + wear);
		// One filtered lookup, shared by the roster: lacquer grain and brushed alloy.
		// Dominant-axis projection avoids stretching on the kit's differently oriented parts.
		vec3 axis = abs(normalize(model_normal));
		vec2 surface_uv = axis.y > max(axis.x, axis.z) ? model_position.xz : (axis.x > axis.z ? model_position.zy : model_position.xy);
		float texture_amount = 0.5;
		if (surface_detail > 0.5 && !glow) {
			vec2 repeat_scale = metal ? vec2(4.0, 0.7) : vec2(2.0);
			texture_amount = texture(surface_grain, surface_uv * repeat_scale).r;
		}
		ALBEDO = paint * (1.0 - grime) * (0.96 + 0.06 * texture_amount);
		METALLIC = metal ? 0.9 : (dark ? 0.35 : 0.0);
		ROUGHNESS = (metal ? 0.24 : (rubber ? 0.64 : (dark ? 0.42 : 0.28))) + (texture_amount - 0.5) * (metal ? 0.16 : 0.10);
		SPECULAR = rubber ? 0.35 : 0.62;
		// A clear-coat sheen on the silhouettes: the lacquer catching the sky.
		float fresnel = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		vec3 rim_color = mix(vec3(0.22, 0.55, 0.85), paint, 0.45);
		CLEARCOAT = rubber || glow ? 0.0 : 0.35;
		CLEARCOAT_ROUGHNESS = 0.25;
		EMISSION = glow ? paint * 2.1 : rim_color * (pow(fresnel, 3.0) * 0.42 + pow(fresnel, 7.0) * 0.28);
	}
}
