// Canonical engine-independent VFX-02 math. Coordinates: world-aligned logical pixels.
// No textures, screen-space AA, derivatives, random values or engine functions.
float trail_cross(float2 a, float2 b) { return a.x * b.y - a.y * b.x; }

// Barycentric interpolation is orientation-independent (both clockwise and reverse work).
// Returns (remaining lifetime, across blade: 0 tip -> 1 inner edge), or (-1, -1).
float2 trail_triangle(float2 p, float2 a, float2 b, float2 c,
                      float2 va, float2 vb, float2 vc) {
    float area = trail_cross(b - a, c - a);
    if (abs(area) < 0.00001) return float2(-1.0, -1.0);
    float wb = trail_cross(p - a, c - a) / area;
    float wc = trail_cross(b - a, p - a) / area;
    float wa = 1.0 - wb - wc;
    if (min(wa, min(wb, wc)) < -0.00001) return float2(-1.0, -1.0);
    return va * wa + vb * wb + vc * wc;
}

// Sweep between two REAL sampled weapon poses, never a generated trajectory.
// base_tip: xy = base, zw = tip. Width is a fraction of the sampled blade length.
float2 trail_segment(float2 p, float4 older, float4 newer,
                     float old_life, float new_life, float width_value, float taper_value) {
    float2 a = older.zw;
    float2 b = a + (older.xy - a) * width_value * pow(max(old_life, 0.0), taper_value);
    float2 d = newer.zw;
    float2 c = d + (newer.xy - d) * width_value * pow(max(new_life, 0.0), taper_value);
    float2 v = trail_triangle(p, a, b, c, float2(old_life, 0.0),
                              float2(old_life, 1.0), float2(new_life, 1.0));
    if (v.x >= 0.0) return v;
    return trail_triangle(p, a, c, d, float2(old_life, 0.0),
                          float2(new_life, 1.0), float2(new_life, 0.0));
}

// Hard-edged palette selection. Old tail loses its bright edge before it disappears.
float trail_band(float2 coverage) {
    if (coverage.x <= 0.0) return 0.0;
    if (coverage.y < 0.20 && coverage.x > 0.50) return 3.0;
    if (coverage.y < 0.72 && coverage.x > 0.20) return 2.0;
    return 1.0;
}
