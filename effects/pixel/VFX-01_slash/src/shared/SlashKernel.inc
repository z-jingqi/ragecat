// Canonical VFX-01 shape and timing kernel. Pixel coordinates, seconds, radians.
// Pure scalar/vector math; build_shaders.py translates its small C-like subset for Godot.
// Crescent taper adapted from Sprite Fusion slash.ts, Copyright (c) 2026 Hugo Duprez.
// See ../../THIRD_PARTY_NOTICES.md for the retained MIT license and modifications.
float slash_smooth(float x) {
    x = clamp(x, 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}

// Output: 0 transparent, 1 amber inner band, 2 gold body, 3 ivory cutting edge.
// Caller quantizes a WORLD-ALIGNED pixel grid before passing p (world sample minus pivot).
float slash_band(float2 p, float t, float reach, float thickness, float sweep,
                 float bend, float direction, float sign_dir,
                 float t_start, float t_burst, float t_decay) {
    float total = t_start + t_burst + t_decay;
    if (t <= 0.0 || t >= total) return 0.0;
    float c = cos(direction);
    float s = sin(direction);
    float2 q = float2(p.x * c + p.y * s, (-p.x * s + p.y * c) * sign_dir);
    q.y /= bend;
    float radius = length(q);
    if (radius > reach || radius < reach - thickness) return 0.0;

    float head = 0.0;
    float tail = 0.0;
    float width = 0.0;
    float decay = 0.0;
    if (t < t_start) {
        float u = slash_smooth(t / t_start);
        head = 0.10 * u;
        width = 0.22 * u;
    } else if (t < t_start + t_burst) {
        float u = clamp((t - t_start) / t_burst, 0.0, 1.0);
        float v = 1.0 - u;
        head = 0.10 + 0.90 * (1.0 - v * v * v);
        width = 0.22 + 0.78 * (1.0 - v * v);
    } else {
        decay = clamp((t - t_start - t_burst) / t_decay, 0.0, 1.0);
        head = 1.0;
        tail = slash_smooth(decay);
        width = 1.0 - 0.88 * decay;
    }
    float span = (head - tail) * sweep;
    if (span < 0.00001) return 0.0;
    float theta = atan2(q.y, q.x);
    float v = (theta + sweep * 0.5 - tail * sweep) / span;
    if (v <= 0.0 || v >= 1.0) return 0.0;
    // Deliberately asymmetric: a long needle tail, broad shoulder, sharp leading point.
    float profile = pow(max(0.0, sin(3.14159265359 * pow(v, 2.2))), 0.6);
    float local_width = thickness * width * profile;
    if (local_width < 0.00001) return 0.0;
    float depth = (reach - radius) / local_width;
    if (depth < 0.0 || depth > 1.0) return 0.0;
    // No alpha fade, glow, dither or decorative residue: geometry retracts to zero.
    if (depth < 0.24 && decay < 0.48) return 3.0;
    if (depth < 0.74 && decay < 0.82) return 2.0;
    return 1.0;
}
