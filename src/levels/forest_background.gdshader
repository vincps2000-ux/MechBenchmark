// forest_background.gdshader
// Dense forest floor: mossy earth base with grass tufts, leaf litter,
// and dappled light patches to evoke a woodland clearing.
shader_type canvas_item;

uniform vec2 camera_world_pos = vec2(0.0, 0.0);
uniform vec2 viewport_size    = vec2(1280.0, 720.0);
uniform vec4 bg_color         : source_color = vec4(0.17, 0.22, 0.12, 1.0);
uniform vec4 moss_color       : source_color = vec4(0.22, 0.30, 0.14, 1.0);
uniform vec4 earth_color      : source_color = vec4(0.24, 0.19, 0.13, 1.0);
uniform vec4 grass_color      : source_color = vec4(0.30, 0.42, 0.18, 1.0);
uniform float grass_density   : hint_range(0.5, 8.0) = 2.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * amp;
		p *= 2.1;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 pixel_pos = UV * viewport_size;
	vec2 world_pos = pixel_pos + camera_world_pos;

	// Base earth/moss texture using fBm.
	float ground = fbm(world_pos * 0.008);
	vec3 color = mix(earth_color.rgb, moss_color.rgb, smoothstep(0.38, 0.62, ground));

	// Blend in background green.
	float large_patch = noise(world_pos * 0.004);
	color = mix(color, bg_color.rgb, smoothstep(0.40, 0.65, large_patch) * 0.6);

	// Grass tufts: small random bright green specks.
	vec2 grass_cell = floor(world_pos * grass_density / 32.0);
	vec2 grass_local = fract(world_pos * grass_density / 32.0);
	float grass_pick = hash(grass_cell + vec2(3.7, 8.2));
	if (grass_pick > 0.52) {
		vec2 grass_center = vec2(hash(grass_cell + vec2(1.1, 0.3)), hash(grass_cell + vec2(0.5, 2.7)));
		float gd = distance(grass_local, grass_center);
		float grass_r = mix(0.08, 0.22, hash(grass_cell + vec2(6.1, 4.4)));
		float grass_mask = 1.0 - smoothstep(grass_r * 0.4, grass_r, gd);
		color = mix(color, grass_color.rgb, grass_mask * 0.75);
	}

	// Leaf litter: tiny darker flecks.
	vec2 leaf_cell = floor(world_pos * 5.0 / 28.0);
	float leaf_pick = hash(leaf_cell + vec2(9.9, 1.3));
	if (leaf_pick > 0.68) {
		vec2 leaf_local = fract(world_pos * 5.0 / 28.0);
		vec2 leaf_center = vec2(hash(leaf_cell + vec2(2.2, 7.1)), hash(leaf_cell + vec2(5.5, 0.8)));
		float ld = distance(leaf_local, leaf_center);
		float leaf_mask = 1.0 - smoothstep(0.06, 0.14, ld);
		color = mix(color, earth_color.rgb * 0.65, leaf_mask * 0.55);
	}

	// Dappled light patches (large, soft, rare).
	float dapple = noise(world_pos * 0.0035 + vec2(12.5, 7.3));
	float dapple2 = noise(world_pos * 0.006 + vec2(3.1, 19.7));
	float light_mask = smoothstep(0.60, 0.80, dapple) * smoothstep(0.55, 0.75, dapple2);
	color = mix(color, color * 1.28 + vec3(0.04, 0.06, 0.01), light_mask * 0.45);

	COLOR = vec4(color, 1.0);
}
