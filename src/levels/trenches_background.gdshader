// trenches_background.gdshader
// Muddy battlefield floor with layered trench lines, shell craters,
// and subtle directional texture to support northward progression.
shader_type canvas_item;

uniform vec2 camera_world_pos = vec2(0.0, 0.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float grid_size : hint_range(16.0, 512.0) = 128.0;
uniform float line_thickness : hint_range(0.5, 16.0) = 3.0;
uniform vec4 bg_color : source_color = vec4(0.18, 0.17, 0.14, 1.0);
uniform vec4 grid_color : source_color = vec4(0.24, 0.22, 0.18, 1.0);
uniform vec4 accent_color : source_color = vec4(0.40, 0.45, 0.28, 1.0);
uniform float accent_every : hint_range(2.0, 16.0) = 4.0;

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

void fragment() {
	vec2 pixel_pos = UV * viewport_size;
	vec2 world_pos = pixel_pos + camera_world_pos;

	// Base mud texture.
	float mud_large = noise(world_pos * 0.010) * 0.10 - 0.05;
	float mud_fine = noise(world_pos * 0.055) * 0.05 - 0.025;
	vec3 color = bg_color.rgb + vec3(mud_large + mud_fine);

	// Horizontal trench bands every few major cells.
	float major_span = grid_size * accent_every;
	float trench_phase = mod(world_pos.y + major_span * 0.5, major_span);
	float trench_center = major_span * 0.5;
	float trench_dist = abs(trench_phase - trench_center);
	float trench_width = grid_size * 0.32;
	float trench_mask = 1.0 - smoothstep(trench_width * 0.6, trench_width, trench_dist);
	color = mix(color, grid_color.rgb * 0.78, trench_mask * 0.85);

	// Duckboard stripes in some trenches for visual rhythm.
	float stripe = step(0.5, fract((world_pos.x + world_pos.y * 0.12) / 22.0));
	float stripe_mask = trench_mask * (0.18 + 0.22 * stripe);
	color = mix(color, accent_color.rgb * 0.80, stripe_mask * 0.35);

	// Crater field: random circular depressions per coarse cell.
	vec2 crater_cell = floor(world_pos / (grid_size * 1.8));
	vec2 local = fract(world_pos / (grid_size * 1.8));
	vec2 crater_center = vec2(hash(crater_cell + vec2(1.7, 0.1)), hash(crater_cell + vec2(0.2, 2.3)));
	float crater_pick = hash(crater_cell + vec2(8.3, 5.9));
	float d = distance(local, crater_center);
	if (crater_pick > 0.62) {
		float crater_r = mix(0.14, 0.26, hash(crater_cell + vec2(4.1, 3.3)));
		float crater = 1.0 - smoothstep(crater_r * 0.65, crater_r, d);
		float rim = 1.0 - smoothstep(crater_r, crater_r + 0.03, d);
		color *= mix(1.0, 0.72, crater * 0.75);
		color = mix(color, accent_color.rgb * 0.55, rim * 0.25);
	}

	// Subtle northward lighting gradient to reinforce upward objective.
	float north = smoothstep(1.0, -1.0, UV.y);
	color *= mix(0.90, 1.05, north * 0.35);

	// Vignette.
	vec2 uv_c = abs(UV - 0.5) * 2.0;
	float vignette = 1.0 - smoothstep(0.58, 1.0, length(uv_c));
	color *= mix(0.76, 1.0, vignette);

	COLOR = vec4(color, 1.0);
}
