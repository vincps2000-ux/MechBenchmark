shader_type canvas_item;

// Whimsical Industrial Background Shader
// Animated gears, riveted metal panels, floating sparks, and smoky haze

uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform vec4 color_dark : source_color = vec4(0.08, 0.06, 0.1, 1.0);
uniform vec4 color_mid : source_color = vec4(0.18, 0.14, 0.22, 1.0);
uniform vec4 color_accent : source_color = vec4(0.85, 0.55, 0.15, 1.0);
uniform vec4 color_teal : source_color = vec4(0.15, 0.65, 0.6, 1.0);

// --- Utility ---
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
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// --- Cog shape (SDF-ish): blocky square teeth, spokes, and hub ---
float gear(vec2 uv, vec2 center, float radius, float teeth, float tooth_depth, float rotation) {
    vec2 d = uv - center;
    float dist = length(d);
    float angle = atan(d.y, d.x) + rotation;
    // Square teeth: hard-edged crenellation instead of a sine wobble
    float tooth = smoothstep(-0.25, 0.25, sin(angle * teeth));
    float gear_edge = radius + tooth_depth * (tooth * 2.0 - 1.0);
    // Inner hole
    float hole = smoothstep(radius * 0.22, radius * 0.25, dist);
    // Outer body up to the toothed edge
    float ring = 1.0 - smoothstep(gear_edge - 0.004, gear_edge + 0.004, dist);
    // Lighten the rim band so the tooth silhouette reads clearly
    float rim = smoothstep(radius - tooth_depth * 2.5, radius - tooth_depth * 1.2, dist) * ring;
    // Spokes (rotate with the cog)
    float spoke = 1.0 - smoothstep(0.003, 0.006, abs(sin(angle * 3.0)) * dist);
    spoke *= step(radius * 0.25, dist) * step(dist, radius - tooth_depth * 1.5);
    return ring * hole * (0.7 + rim * 0.5) + spoke * 0.3;
}

// --- Arcane core glow at a cog's hub ---
float hub_glow(vec2 uv, vec2 center, float radius, float t) {
    float dist = length(uv - center);
    float pulse = 0.75 + 0.25 * sin(t * 2.0 + center.x * 13.0);
    return (1.0 - smoothstep(0.0, radius * 0.22, dist)) * pulse;
}

// --- Rotating arcane rune ring: dashed glowing circle with tick glyphs ---
float rune_ring(vec2 uv, vec2 center, float radius, float rotation, float t) {
    vec2 d = uv - center;
    float dist = length(d);
    float angle = atan(d.y, d.x) + rotation;
    // Thin base circle
    float circle = 1.0 - smoothstep(0.0015, 0.004, abs(dist - radius));
    // Dashed glyph segments around the ring
    float dashes = step(0.3, fract(angle * 9.0 / 6.28318));
    // Radial tick marks crossing the ring (rune-like)
    float ticks = 1.0 - smoothstep(0.002, 0.005, abs(sin(angle * 12.0)) * dist);
    ticks *= 1.0 - smoothstep(0.012, 0.02, abs(dist - radius));
    // Slow pulsing glow
    float pulse = 0.6 + 0.4 * sin(t * 1.5 + radius * 40.0);
    return (circle * dashes + ticks * 0.7) * pulse;
}

// --- Rivet pattern ---
float rivets(vec2 uv, float spacing) {
    vec2 cell = fract(uv / spacing) - 0.5;
    float d = length(cell);
    float rivet = 1.0 - smoothstep(0.06, 0.09, d);
    return rivet;
}

// --- Metal panel lines ---
float panels(vec2 uv, float scale) {
    vec2 p = uv * scale;
    float line_h = 1.0 - smoothstep(0.0, 0.02, abs(fract(p.y) - 0.5) - 0.48);
    float line_v = 1.0 - smoothstep(0.0, 0.02, abs(fract(p.x * 0.6) - 0.5) - 0.48);
    return max(line_h, line_v) * 0.3;
}

// --- Sparks (tiny floating bright dots) ---
float sparks(vec2 uv, float t) {
    float v = 0.0;
    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        vec2 pos = vec2(
            hash(vec2(fi, 0.0)),
            fract(hash(vec2(fi, 1.0)) - t * (0.05 + 0.03 * hash(vec2(fi, 2.0))))
        );
        float brightness = hash(vec2(fi, 3.0));
        float flicker = 0.5 + 0.5 * sin(t * (8.0 + fi * 2.0));
        float d = length(uv - pos);
        v += (0.0008 / (d * d + 0.0001)) * brightness * flicker;
    }
    return clamp(v, 0.0, 1.0);
}

// --- Smoke wisps ---
float smoke(vec2 uv, float t) {
    vec2 p = uv * 3.0;
    p.y -= t * 0.15;
    float s = fbm(p + fbm(p + t * 0.1));
    return s * 0.4;
}

void fragment() {
    float t = TIME * time_scale;
    vec2 uv = UV;
    float aspect = 1280.0 / 720.0;
    vec2 uv_a = vec2(uv.x * aspect, uv.y);

    // --- Background gradient (dark edges, slightly lighter center) ---
    float vignette = 1.0 - length(uv - 0.5) * 1.1;
    vignette = clamp(vignette, 0.0, 1.0);
    vec3 bg = mix(color_dark.rgb, color_mid.rgb, vignette * 0.7);

    // --- Metal panel texture ---
    float metal_noise = fbm(uv_a * 8.0) * 0.08;
    bg += metal_noise;

    // --- Panel seam lines ---
    float p = panels(uv_a, 4.0);
    bg = mix(bg, color_dark.rgb * 0.5, p);

    // --- Rivets along panel edges ---
    float r = rivets(uv_a, 0.25);
    bg += r * 0.06 * color_accent.rgb;

    // --- Cogs (brass-toned, square teeth) ---
    vec3 brass = mix(color_mid.rgb, color_accent.rgb, 0.65);

    // Large cog, top-left
    float g1 = gear(uv_a, vec2(0.35, 0.25), 0.18, 12.0, 0.022, t * 0.3);
    bg = mix(bg, brass, g1 * 0.5);
    bg += color_teal.rgb * hub_glow(uv_a, vec2(0.35, 0.25), 0.18, t) * 0.35;

    // Medium cog, right side
    float g2 = gear(uv_a, vec2(1.5, 0.7), 0.12, 9.0, 0.018, -t * 0.5);
    bg = mix(bg, brass, g2 * 0.45);
    bg += color_teal.rgb * hub_glow(uv_a, vec2(1.5, 0.7), 0.12, t + 1.7) * 0.3;

    // Small cog, bottom-left
    float g3 = gear(uv_a, vec2(0.2, 0.82), 0.07, 7.0, 0.014, t * 0.8);
    bg = mix(bg, brass * 0.85, g3 * 0.4);

    // Tiny cog, top-right
    float g4 = gear(uv_a, vec2(1.6, 0.15), 0.05, 8.0, 0.012, -t * 1.2);
    bg = mix(bg, brass * 0.9, g4 * 0.35);

    // Medium cog, center-bottom (partially hidden)
    float g5 = gear(uv_a, vec2(0.9, 0.95), 0.14, 10.0, 0.018, t * 0.4);
    bg = mix(bg, brass * 0.8, g5 * 0.35);

    // --- Arcane rune rings (magic circles driving the machinery) ---
    // Counter-rotating rings encircle the two largest cogs
    float r1 = rune_ring(uv_a, vec2(0.35, 0.25), 0.24, -t * 0.2, t);
    bg += color_teal.rgb * r1 * 0.45;
    float r1b = rune_ring(uv_a, vec2(0.35, 0.25), 0.285, t * 0.12, t + 2.0);
    bg += color_teal.rgb * r1b * 0.3;

    float r2 = rune_ring(uv_a, vec2(1.5, 0.7), 0.17, t * 0.25, t + 1.0);
    bg += color_teal.rgb * r2 * 0.4;

    // Free-floating faint magic circle, mid-screen upper area
    float r3 = rune_ring(uv_a, vec2(0.9, 0.18), 0.10, -t * 0.35, t + 3.0);
    bg += mix(color_teal.rgb, color_accent.rgb, 0.4) * r3 * 0.25;

    // --- Arcane mist wisps (steam tinged with mana) ---
    float s = smoke(uv, t);
    bg = mix(bg, mix(vec3(0.55, 0.55, 0.52), color_teal.rgb, 0.3), s * 0.25);

    // --- Mana motes (drifting magical embers, teal with warm flecks) ---
    float sp = sparks(uv, t);
    bg += sp * mix(color_teal.rgb, color_accent.rgb, 0.35) * 0.8;

    // --- Subtle scan-line effect for industrial feel ---
    float scanline = 0.97 + 0.03 * sin(uv.y * 720.0 * 3.14159);
    bg *= scanline;

    // --- Final vignette ---
    bg *= (0.7 + 0.3 * vignette);

    COLOR = vec4(bg, 1.0);
}
