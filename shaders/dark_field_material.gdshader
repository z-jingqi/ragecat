shader_type canvas_item;
render_mode unshaded;
// A sparse locally folded material, not a scene-wide refraction or fake radius.
// Both masks use unwarped local positions. Noise can never move their boundary.
uniform float outer_radius = 160.0;
uniform float core_ratio : hint_range(0.0, 1.0) = 0.40625;
uniform float phase = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.34;
uniform float grain_scale = 7.0;
uniform float warp_strength = 0.16;
uniform float core_density = 1.9;
uniform float outer_density = 0.65;
uniform vec4 fold_color : source_color = vec4(0.42, 0.36, 0.52, 1.0);
uniform float edge_softness = 0.08;
uniform vec4 matter_color : source_color = vec4(0.19, 0.16, 0.24, 1.0);
varying vec2 local_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { local_position = VERTEX; }
void fragment() {
	vec4 tint = COLOR;
	vec2 p = local_position / max(outer_radius, 1.0);
	float radius = length(p);
	float footprint = 1.0 - smoothstep(1.0 - edge_softness, 1.0, radius);
	float damage_core = 1.0 - smoothstep(core_ratio * (1.0 - edge_softness), core_ratio, radius);
	vec2 flow = p * (1.0 + 0.08 * sin(phase));
	vec2 warp = vec2(noise(flow * 3.1 + phase * 0.2), noise(flow * 3.1 - phase * 0.17 + 17.0)) - 0.5;
	vec2 folded = flow * grain_scale + warp * warp_strength * grain_scale;
	float coarse = noise(folded + vec2(phase * 0.15, -phase * 0.18));
	float fine = noise(folded * 2.13 - phase * 0.09);
	float grain = smoothstep(0.30, 0.76, coarse * 0.70 + fine * 0.30);
	// Continuous low-density matter reaches the true attraction footprint.
	// Higher contrast is restricted to broken folds, never a closed bright rim.
	float density = mix(outer_density, core_density, damage_core);
	float alpha = opacity * footprint * density * (0.44 + grain * 0.56);
	float folds = smoothstep(0.34, 0.70, coarse * 0.62 + fine * 0.38);
	vec3 shadow = matter_color.rgb * (0.36 + grain * 0.36);
	vec3 color = mix(shadow, fold_color.rgb, folds * (0.68 + damage_core * 0.22));
	COLOR = vec4(color * tint.rgb, clamp(alpha, 0.0, 0.75) * matter_color.a * tint.a);
}
