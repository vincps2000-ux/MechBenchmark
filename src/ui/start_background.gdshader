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

// --- Gear shape (SDF-ish) ---
float gear(vec2 uv, vec2 center, float radius, float teeth, float tooth_depth, float rotation) {
    vec2 d = uv - center;
    float dist = length(d);
    float angle = atan(d.y, d.x) + rotation;
    float gear_edge = radius + tooth_depth * sin(angle * teeth);
    // Inner hole
    float hole = smoothstep(radius * 0.25, radius * 0.28, dist);
    // Outer ring
    float ring = 1.0 - smoothstep(gear_edge - 0.004, gear_edge + 0.004, dist);
    // Spokes
    float spoke = 1.0 - smoothstep(0.003, 0.006, abs(sin(angle * 3.0)) * dist);
    spoke *= step(radius * 0.28, dist) * step(dist, gear_edge - tooth_depth * 0.5);
    return ring * hole + spoke * 0.3;
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

    // --- Gears ---
    // Large gear, top-left
    float g1 = gear(uv_a, vec2(0.35, 0.25), 0.18, 12.0, 0.025, t * 0.3);
    bg = mix(bg, mix(color_mid.rgb, color_teal.rgb, 0.4), g1 * 0.5);

    // Medium gear, right side
    float g2 = gear(uv_a, vec2(1.5, 0.7), 0.12, 8.0, 0.02, -t * 0.5);
    bg = mix(bg, mix(color_mid.rgb, color_accent.rgb, 0.5), g2 * 0.45);

    // Small gear, bottom-left
    float g3 = gear(uv_a, vec2(0.2, 0.82), 0.07, 6.0, 0.015, t * 0.8);
    bg = mix(bg, color_teal.rgb * 0.6, g3 * 0.4);

    // Tiny gear, top-right
    float g4 = gear(uv_a, vec2(1.6, 0.15), 0.05, 10.0, 0.01, -t * 1.2);
    bg = mix(bg, color_accent.rgb * 0.7, g4 * 0.35);

    // Medium gear, center-bottom (partially hidden)
    float g5 = gear(uv_a, vec2(0.9, 0.95), 0.14, 10.0, 0.02, t * 0.4);
    bg = mix(bg, mix(color_mid.rgb, color_teal.rgb, 0.3), g5 * 0.35);

    // --- Smoke / steam wisps ---
    float s = smoke(uv, t);
    bg = mix(bg, vec3(0.6, 0.55, 0.5), s * 0.25);

    // --- Sparks ---
    float sp = sparks(uv, t);
    bg += sp * color_accent.rgb * 0.7;

    // --- Subtle scan-line effect for industrial feel ---
    float scanline = 0.97 + 0.03 * sin(uv.y * 720.0 * 3.14159);
    bg *= scanline;

    // --- Final vignette ---
    bg *= (0.7 + 0.3 * vignette);

    COLOR = vec4(bg, 1.0);
}
