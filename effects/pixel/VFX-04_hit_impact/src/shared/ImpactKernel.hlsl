// VFX-04 engine-independent analytic pixel mask. Authored for Ragecat.
// Input: local sample p in logical pixels, +X incoming, +Y up; age seconds.
// Return: 0 transparent, 1 edge, 2 body, 3 core. No textures, AA or alpha fade.
float impactSat(float x) { return clamp(x, 0.0, 1.0); }
float impactHash(float seed, float channel) {
    // Small integer arithmetic stays exact in float32 for supported seed 0..4095.
    float n = seed * 17.0 + channel * 131.0 + 71.0;
    n = n - floor(n / 4093.0) * 4093.0;
    n = n * 37.0 + 101.0;
    return (n - floor(n / 4093.0) * 4093.0) / 4093.0;
}
float2 impactRotate(float2 p, float a) {
    float c = cos(a), s = sin(a);
    return float2(c * p.x + s * p.y, -s * p.x + c * p.y);
}
float impactDiamond(float2 p, float front, float back, float halfWidth) {
    return abs(p.y) / max(halfWidth, 0.1) + max(p.x, 0.0) / max(front, 0.1) + max(-p.x, 0.0) / max(back, 0.1);
}
float impactSample(float2 p, float age, float duration, float size, float coreSize,
    float count, float shardLength, float spreadRadians, float speed, float seed, float shock) {
    if (age < 0.0 || age >= duration || duration <= 0.0) return 0.0;
    float t = age / duration;
    p /= max(size, 0.01);
    float result = 0.0;
    // Optional short broken shoulder, never a complete expanding clock/ring.
    if (shock > 0.5 && t > 0.08 && t < 0.32) {
        float r = coreSize * (0.9 + t * 1.3);
        float2 e = float2(p.x + coreSize * 0.1, p.y * 1.25);
        float d = length(e);
        if (abs(d - r) < 0.48 && e.x < -r * 0.45 && abs(e.y) > r * 0.70 && abs(e.y) < r * 0.93) result = 1.0;
    }
    // Fixed seed/channel samples; angles, lengths and lifetimes do NOT reroll per frame.
    for (int i = 0; i < 8; i++) {
        if (float(i) >= count) break;
        float k = float(i);
        float h = impactHash(seed, k * 3.0);
        float h2 = impactHash(seed, k * 3.0 + 1.0);
        float h3 = impactHash(seed, k * 3.0 + 2.0);
        float slot = count > 1.0 ? k / (count - 1.0) : 0.5;
        float a = (slot - 0.5) * spreadRadians + (h - 0.5) * 0.24;
        float life = 0.72 + h3 * 0.28;
        float st = t / life;
        if (st >= 1.0 || t < 0.04) continue;
        float travelTime = age * (1.0 - 0.42 * st);
        float r = coreSize * 0.60 + speed * travelTime * (0.70 + h2 * 0.45);
        float len = shardLength * (0.72 + h * 0.40) * (1.0 - st * 0.78);
        float width = max(0.48, (1.0 - st * 0.75) * (1.0 + h2 * 0.65));
        float2 q = impactRotate(p, a) - float2(r, 0.0);
        float shape = impactDiamond(q, len * 0.62, len * 0.38, width);
        if (shape <= 1.0) {
            float band = st < 0.30 && shape < 0.42 ? 3.0 : (st < 0.73 ? 2.0 : 1.0);
            result = max(result, band);
        }
    }
    // Compact off-centre main wedge and one unequal shoulder: not a radial sunburst.
    if (t < 0.52) {
        float pop = t < 0.10 ? 0.65 + t * 3.5 : max(0.0, 1.0 - (t - 0.10) / 0.42);
        float2 q = p / max(pop, 0.001);
        float mainShape = impactDiamond(float2(q.x, q.y + q.x * 0.13), coreSize * 1.62, coreSize * 0.60, coreSize * 0.72);
        float2 shoulder = impactRotate(q, 1.05) - float2(coreSize * 0.1, 0.0);
        float sideShape = impactDiamond(shoulder, coreSize * 1.03, coreSize * 0.27, coreSize * 0.25);
        float d = min(mainShape, sideShape);
        if (d < 1.0) result = max(result, d < 0.48 && t < 0.30 ? 3.0 : (d < 0.82 ? 2.0 : 1.0));
    }
    return result;
}
