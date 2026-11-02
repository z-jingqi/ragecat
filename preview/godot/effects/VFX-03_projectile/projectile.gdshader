shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform vec4 path_points[96];
uniform int point_count = 0;
uniform float head_radius = 4.5;
uniform float tail_length = 20.0;
uniform float flow_time = 0.0;
uniform float flow_strength = 0.8;
uniform float envelope = 1.0;
uniform float display_scale = 1.0;
uniform vec2 facing = vec2(1.0, 0.0);
uniform vec4 core_color : source_color = vec4(0.925, 1.0, 0.957, 1.0);
uniform vec4 body_color : source_color = vec4(0.478, 0.906, 0.773, 1.0);
uniform vec4 edge_color : source_color = vec4(0.137, 0.545, 0.565, 1.0);
varying vec2 pixel_position;
void vertex() { pixel_position = VERTEX / display_scale; }
void fragment() {
    vec2 p = floor(pixel_position) + vec2(0.5);
    float radius = max(0.0, head_radius * envelope);
    float d = length(p) - radius;
    float along = -dot(p, facing);
    float side = dot(p, vec2(-facing.y, facing.x));
    float width = radius;
    for (int i = 1; i < 96; i++) {
        if (i >= point_count) { break; }
        vec2 a = path_points[i-1].xy;
        vec2 b = path_points[i].xy;
        vec2 ab = b-a;
        float t = clamp(dot(p-a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
        float s = mix(path_points[i-1].z, path_points[i].z, t);
        float r = radius * pow(max(0.0, 1.0-s / max(tail_length, 0.01)), 0.8);
        float sd = length(p-(a+ab*t))-r;
        if (sd < d) {
            d = sd;
            along = s;
            side = dot(p-(a+ab*t), vec2(ab.y, -ab.x) / max(length(ab), 0.001));
            width = r;
        }
    }
    vec4 ink = body_color;
    if (d > -0.85 || side > width * 0.56) { ink = edge_color; }
    // Two compact migrating slivers inside one silhouette, not radial pulses.
    float flow = fract((along - flow_time * 30.0) / 10.0);
    float sliver = step(0.69, flow) * step(flow, 0.92);
    float inner = abs(side + width * 0.19);
    float lens = length((p - facing * (radius * 0.17)) * vec2(1.0, 1.05));
    bool head_core = lens < radius * (0.50 + 0.05 * flow_strength * sin(flow_time * 15.0)) && dot(p, facing) > -radius * 0.4;
    bool moving_core = sliver > 0.5 && inner < width * (0.22 + 0.25 * flow_strength) && d < -1.15 && flow_strength > 0.01;
    if (head_core || moving_core) { ink = core_color; }
    float alpha = d <= 0.0 && envelope > 0.001 ? 1.0 : 0.0;
    COLOR = vec4(ink.rgb, alpha * ink.a);
}
