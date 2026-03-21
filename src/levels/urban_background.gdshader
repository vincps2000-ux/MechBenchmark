// urban_background.gdshader
// Dark city streets: asphalt base with road markings, crosswalks,
// manhole covers, and subtle pavement cracks.
shader_type canvas_item;

uniform vec2  camera_world_pos = vec2(0.0, 0.0);
uniform vec2  viewport_size    = vec2(1280.0, 720.0);
uniform float grid_size    : hint_range(16.0, 512.0) = 120.0;
uniform float line_thickness : hint_range(0.5, 8.0)  = 1.5;
uniform vec4  bg_color      : source_color = vec4(0.12, 0.12, 0.13, 1.0);
uniform vec4  grid_color    : source_color = vec4(0.16, 0.16, 0.17, 1.0);
uniform vec4  accent_color  : source_color = vec4(0.85, 0.75, 0.2, 1.0);
uniform float accent_every  : hint_range(2.0, 16.0)  = 4.0;
uniform vec4  road_line_color : source_color = vec4(0.9, 0.85, 0.3, 0.6);
uniform float road_width : hint_range(40.0, 300.0) = 90.0;

// ─── simple value-noise for asphalt texture ─────────────────────────────────
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2  i = floor(p);
	vec2  f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2  u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 pixel_pos = UV * viewport_size;
	vec2 world_pos = pixel_pos + camera_world_pos;

	// ── Sidewalk grid (city blocks) ─────────────────────────────────────
	vec2 grid_pos = mod(world_pos, grid_size);
	bool on_x = grid_pos.x < line_thickness || grid_pos.x > (grid_size - line_thickness);
	bool on_y = grid_pos.y < line_thickness || grid_pos.y > (grid_size - line_thickness);

	vec2 cell_index = floor(world_pos / grid_size);
	bool is_accent_x = mod(cell_index.x, accent_every) < 1.0;
	bool is_accent_y = mod(cell_index.y, accent_every) < 1.0;

	bool on_line   = on_x || on_y;
	bool on_accent = (on_x && is_accent_x) || (on_y && is_accent_y);

	// ── Asphalt noise ───────────────────────────────────────────────────
	float asphalt      = noise(world_pos * 0.012) * 0.06 - 0.03;
	float asphalt_fine = noise(world_pos * 0.06)  * 0.03 - 0.015;

	// ── Roads: horizontal and vertical main roads ───────────────────────
	float block_size = grid_size * accent_every;
	float road_half = road_width * 0.5;

	// Position within the block
	float mod_x = mod(world_pos.x, block_size);
	float mod_y = mod(world_pos.y, block_size);
	bool on_road_h = mod_y < road_width || mod_y > (block_size - road_width);
	bool on_road_v = mod_x < road_width || mod_x > (block_size - road_width);
	bool on_road = on_road_h || on_road_v;

	// ── Dashed center line on roads ─────────────────────────────────────
	float center_line_h = abs(mod_y - block_size * 0.5);
	float center_line_v = abs(mod_x - block_size * 0.5);
	// Dash pattern: 20px on, 15px off
	bool dash_h = mod(world_pos.x, 35.0) < 20.0 && center_line_h < 1.5;
	bool dash_v = mod(world_pos.y, 35.0) < 20.0 && center_line_v < 1.5;
	// Edge lines
	float edge_h_top = abs(mod_y - road_half);
	float edge_h_bot = abs(mod_y - (block_size - road_half));
	float edge_v_left = abs(mod_x - road_half);
	float edge_v_right = abs(mod_x - (block_size - road_half));
	bool on_edge = (on_road_h && (edge_h_top < 1.2 || edge_h_bot < 1.2)) ||
	               (on_road_v && (edge_v_left < 1.2 || edge_v_right < 1.2));

	// ── Crosswalk at intersections ──────────────────────────────────────
	bool at_intersection = on_road_h && on_road_v;
	bool crosswalk = false;
	if (at_intersection) {
		// Zebra stripes
		crosswalk = mod(world_pos.x + world_pos.y, 16.0) < 8.0;
	}

	// ── Manhole covers (circles at certain positions) ───────────────────
	vec2 manhole_cell = floor(world_pos / (block_size * 0.5));
	vec2 manhole_center = (manhole_cell + 0.5) * block_size * 0.5;
	float manhole_dist = length(world_pos - manhole_center);
	// Only show manholes near road centers
	bool near_road_center = (abs(mod(manhole_center.y, block_size)) < road_half ||
	                         abs(mod(manhole_center.x, block_size)) < road_half);
	bool on_manhole = manhole_dist < 8.0 && near_road_center && hash(manhole_cell) > 0.7;
	bool on_manhole_ring = abs(manhole_dist - 8.0) < 1.0 && near_road_center && hash(manhole_cell) > 0.7;

	// ── Compose final colour ────────────────────────────────────────────
	vec4 color;
	if (on_road) {
		// Darker asphalt for roads
		color = vec4(bg_color.rgb * 0.85, 1.0);
		color.rgb += asphalt * 0.7 + asphalt_fine * 0.5;

		if (crosswalk) {
			color = mix(color, vec4(0.9, 0.9, 0.85, 1.0), 0.35);
		} else if (dash_h || dash_v) {
			color = mix(color, road_line_color, 0.7);
		} else if (on_edge) {
			color = mix(color, vec4(0.8, 0.8, 0.8, 1.0), 0.3);
		}
	} else if (on_accent) {
		// Sidewalk curb accent
		color = accent_color * 0.5;
		color.a = 1.0;
	} else if (on_line) {
		// Sidewalk tile lines
		color = grid_color;
	} else {
		// Sidewalk concrete
		color = vec4(bg_color.rgb * 1.15, 1.0);
		color.rgb += asphalt + asphalt_fine;
	}

	// Manhole
	if (on_manhole) {
		color = vec4(0.08, 0.08, 0.09, 1.0);
	} else if (on_manhole_ring) {
		color = vec4(0.2, 0.2, 0.22, 1.0);
	}

	// ── Pavement cracks ─────────────────────────────────────────────────
	float crack = noise(world_pos * 0.04);
	if (crack > 0.72 && crack < 0.725) {
		color.rgb *= 0.8;
	}

	// ── Vignette ────────────────────────────────────────────────────────
	vec2  uv_c    = abs(UV - 0.5) * 2.0;
	float vignette = 1.0 - smoothstep(0.6, 1.0, length(uv_c));
	color.rgb *= mix(0.75, 1.0, vignette);

	COLOR = color;
}
