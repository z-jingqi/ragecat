shader_type canvas_item;
render_mode unshaded;
// Captured by a padded local BackBufferCopy BEFORE actors and UI draw.
// Never sample an uncopied region, use mipmaps, or animate with the wall clock.
uniform sampler2D ground_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float outer_radius = 160.0;
uniform float phase = 0.0;
uniform float pull_pixels = 13.0;
uniform float swirl_pixels = 4.0;
// Continuous advected material, not a separate opaque disc and line geometry.
uniform float body_opacity = 0.94;
uniform float body_extent = 0.87;
uniform float body_scale = 6.5;
uniform float body_shear = 3.4;
uniform float body_phase = 0.0;
uniform vec4 body_mid_color : source_color = vec4(0.16, 0.135, 0.205, 1.0);
uniform vec4 body_edge_color : source_color = vec4(0.40, 0.36, 0.46, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float folds(vec2 p) {
	return noise(p) * 0.60 + noise(p * 2.07 + vec2(13.0, 7.0)) * 0.28 + noise(p * 4.11 - vec2(5.0, 9.0)) * 0.12;
}
varying vec2 local_position;
varying vec2 screen_axis_x;
varying vec2 screen_axis_y;
void vertex() {
	local_position = VERTEX;
	// Canvas-space basis preserves screen-pixel displacement under arrow
	// rotation, viewport stretching and an arena/camera transform.
	screen_axis_x = (CANVAS_MATRIX * MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xy;
	screen_axis_y = (CANVAS_MATRIX * MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xy;
}
void fragment() {
	vec2 p = local_position / max(outer_radius, 1.0);
	float radius = length(p);
	if (radius >= 1.0) {
		discard;
	}
	// Zero at the exact singularity, strong near the core, smoothly zero at
	// the true outer radius. The actual attraction footprint stays unwarped.
	float envelope = smoothstep(0.0, 0.12, radius) * (1.0 - smoothstep(0.08, 1.0, radius));
	float breath = 0.96 + 0.04 * sin(phase);
	vec2 radial = p / max(radius, 0.0001);
	vec2 tangent = vec2(-radial.y, radial.x);
	// Sampling outward makes the visible ground converge inward.
	vec2 offset = (radial * pull_pixels + tangent * swirl_pixels) * envelope * breath;
	vec2 screen_offset = (screen_axis_x * offset.x + screen_axis_y * offset.y) * SCREEN_PIXEL_SIZE;
	vec2 safe_uv = clamp(SCREEN_UV + screen_offset, SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
	vec3 ground = textureLod(ground_texture, safe_uv, 0.0).rgb;
	float footprint = 1.0 - smoothstep(0.78, 1.0, radius);
	// Logarithmic differential rotation shears the *whole* material, while
	// increasing the sampled radius transports folds inward through the body.
	float angle = atan(p.y, p.x);
	float sheared_angle = angle + log(radius + 0.09) * body_shear - body_phase * 0.72;
	vec2 flowing = vec2(cos(sheared_angle), sin(sheared_angle)) * (radius * body_scale + body_phase * 0.48);
	float broad_noise = folds(flowing * vec2(1.0, 0.80));
	float torn_noise = folds(flowing * vec2(2.2, 3.6) + vec2(body_phase * 0.12, 5.1));
	// Broad open density lobes, broken by material variation. No drawn arcs,
	// separate line segments, or radial-only black silhouette exist here.
	float arm_density = 0.5 + 0.5 * sin(sheared_angle * 3.0 + broad_noise * 2.1);
	// Uneven advected body detail continues through the troughs and breaks
	// the broad arms into shaded folds rather than a polished rotating logo.
	float broken_arm = arm_density * (0.55 + torn_noise * 0.45);
	float material_density = smoothstep(0.17, 0.80, broken_arm * 0.34 + broad_noise * 0.46 + torn_noise * 0.20);
	float radial_depth = 1.0 - smoothstep(0.0, body_extent, radius);
	float ragged_radius = radius + (broad_noise - 0.5) * 0.12;
	float body_mask = 1.0 - smoothstep(body_extent * 0.48, body_extent, ragged_radius);
	float trough_detail = (1.0 - arm_density) * smoothstep(0.28, 0.72, torn_noise);
	float density = (0.34 + material_density * 0.54 + radial_depth * 0.22 + trough_detail * 0.06) * body_mask;
	float fold_lighting = smoothstep(0.34, 0.80, torn_noise * 0.55 + material_density * 0.45);
	float lit_edges = pow(fold_lighting, 2.6) * (0.42 + radial_depth * 0.25) * smoothstep(0.28, 0.72, broad_noise * 0.4 + torn_noise * 0.6);
	vec3 deep_matter = vec3(0.018, 0.020, 0.032);
	vec3 matter = mix(deep_matter, body_mid_color.rgb, material_density * 0.72 + torn_noise * 0.28);
	matter = mix(matter, body_edge_color.rgb, lit_edges);
	// Dark troughs and luminous folded faces belong to the same advected
	// volume. There is deliberately no independent black centre primitive.
	matter = mix(matter, body_mid_color.rgb * 0.74, trough_detail * 0.16);
	matter *= 0.60 + broad_noise * 0.30 + torn_noise * 0.30;
	float alpha = clamp(body_opacity * density * footprint, 0.0, 0.98);
	COLOR = vec4(mix(ground, matter, alpha), 1.0);
}
