// testing_ground_bg.gdshader
// Industrial test-facility floor: concrete base, yellow safety grid,
// range-circle markers centred on the world origin.
shader_type canvas_item;

uniform vec2  camera_world_pos = vec2(0.0, 0.0);
uniform vec2  viewport_size    = vec2(1280.0, 720.0);
uniform float grid_size    : hint_range(16.0, 512.0) = 80.0;
uniform float line_thickness : hint_range(0.5, 8.0)  = 2.0;
uniform vec4  bg_color      : source_color = vec4(0.14, 0.15, 0.13, 1.0);
uniform vec4  grid_color    : source_color = vec4(0.22, 0.21, 0.17, 1.0);
uniform vec4  accent_color  : source_color = vec4(0.85, 0.65, 0.10, 1.0);
uniform float accent_every  : hint_range(2.0, 16.0)  = 5.0;

// ─── simple value-noise for concrete texture ────────────────────────────────
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

	// ── Grid lines ──────────────────────────────────────────────────────
	vec2 grid_pos = mod(world_pos, grid_size);
	bool on_x = grid_pos.x < line_thickness || grid_pos.x > (grid_size - line_thickness);
	bool on_y = grid_pos.y < line_thickness || grid_pos.y > (grid_size - line_thickness);

	vec2 cell_index = floor(world_pos / grid_size);
	bool is_accent_x = mod(cell_index.x, accent_every) < 1.0;
	bool is_accent_y = mod(cell_index.y, accent_every) < 1.0;

	bool on_line   = on_x || on_y;
	bool on_accent = (on_x && is_accent_x) || (on_y && is_accent_y);

	// ── Concrete noise ──────────────────────────────────────────────────
	float concrete       = noise(world_pos * 0.015) * 0.05 - 0.025;
	float concrete_fine  = noise(world_pos * 0.08)  * 0.025 - 0.0125;

	// ── Base colour ─────────────────────────────────────────────────────
	vec4 color;
	if (on_accent) {
		color = accent_color;
	} else if (on_line) {
		color = grid_color;
	} else {
		color = bg_color;
		color.rgb += concrete + concrete_fine;
	}

	// ── Range circles (concentric rings centred at world origin) ────────
	float dist = length(world_pos);
	for (int i = 1; i <= 4; i++) {
		float radius = float(i) * grid_size * accent_every;
		float ring   = abs(dist - radius);
		if (ring < line_thickness * 2.0) {
			float blend = 1.0 - ring / (line_thickness * 2.0);
			color = mix(color, accent_color * 0.55, blend * 0.45);
		}
	}

	// ── Crosshair through origin ────────────────────────────────────────
	float cross_x = abs(world_pos.y);
	float cross_y = abs(world_pos.x);
	if (cross_x < line_thickness * 0.75 || cross_y < line_thickness * 0.75) {
		color = mix(color, accent_color * 0.4, 0.25);
	}

	// ── Vignette ────────────────────────────────────────────────────────
	vec2  uv_c    = abs(UV - 0.5) * 2.0;
	float vignette = 1.0 - smoothstep(0.6, 1.0, length(uv_c));
	color.rgb *= mix(0.8, 1.0, vignette);

	COLOR = color;
}
