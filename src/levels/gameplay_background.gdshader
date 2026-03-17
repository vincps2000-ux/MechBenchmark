// gameplay_background.gdshader
// Infinite tiling grid for the gameplay world background.
// The ColorRect lives in a CanvasLayer at layer -10 (full-screen),
// and this shader offsets the grid by the player's world position
// so the grid appears to scroll with the camera.
shader_type canvas_item;

uniform vec2 camera_world_pos = vec2(0.0, 0.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float grid_size : hint_range(16.0, 512.0) = 80.0;
uniform float line_thickness : hint_range(0.5, 8.0) = 1.2;
uniform vec4 bg_color : source_color = vec4(0.04, 0.05, 0.07, 1.0);
uniform vec4 grid_color : source_color = vec4(0.10, 0.13, 0.18, 1.0);
uniform vec4 accent_color : source_color = vec4(0.15, 0.20, 0.28, 1.0);
uniform float accent_every : hint_range(2.0, 16.0) = 5.0;

void fragment() {
	// Convert UV to viewport pixel coords, then offset by camera world position
	vec2 pixel_pos = UV * viewport_size;
	vec2 world_pos = pixel_pos + camera_world_pos;

	// Compute grid position
	vec2 grid_pos = mod(world_pos, grid_size);

	// Determine if on a line
	bool on_x = grid_pos.x < line_thickness || grid_pos.x > (grid_size - line_thickness);
	bool on_y = grid_pos.y < line_thickness || grid_pos.y > (grid_size - line_thickness);

	// Determine if this is an accent (major) grid line
	vec2 cell_index = floor(world_pos / grid_size);
	bool accent_x = mod(cell_index.x, accent_every) < 1.0;
	bool accent_y = mod(cell_index.y, accent_every) < 1.0;

	bool on_line = on_x || on_y;
	bool on_accent = (on_x && accent_x) || (on_y && accent_y);

	// Apply color
	if (on_accent) {
		COLOR = accent_color;
	} else if (on_line) {
		COLOR = grid_color;
	} else {
		COLOR = bg_color;
	}

	// Subtle vignette darkening at screen edges
	vec2 uv_center = abs(UV - 0.5) * 2.0;
	float vignette = 1.0 - smoothstep(0.6, 1.0, length(uv_center));
	COLOR.rgb *= mix(0.75, 1.0, vignette);
}
