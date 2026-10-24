shader_type canvas_item;
// Frost follows each sprite's own UVs. Never changes source alpha or extends
// into transparent pixels, and never samples screen space or a global clock.
uniform float freeze_coverage : hint_range(0.0, 1.0) = 0.0;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_color : source_color = vec4(0.60, 0.70, 0.75, 1.0);
uniform float noise_scale = 28.0;
uniform float edge_softness = 0.08;
uniform float tint_strength = 0.55;
uniform float edge_strength = 0.20;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	// Fragment COLOR already includes sampled texture and modulate, exactly once.
	vec4 source = COLOR;
	vec2 cells = UV * noise_scale;
	vec2 cell = floor(cells + vec2(floor(cells.y) * 0.31, 0.0));
	float grain = hash(cell);
	float front = 1.0 - freeze_coverage * 1.12;
	float shell = smoothstep(front - edge_softness, front + edge_softness, UV.y + (grain - 0.5) * 0.12);
	shell *= step(0.001, freeze_coverage);
	float amount = clamp(frost_amount * tint_strength * 0.40 + shell * tint_strength, 0.0, 0.85);
	// Large desaturated planes retain the actor underneath; only a sparse subset
	// of facet edges receives a white frost catch, never an emissive blue wash.
	float gray = dot(frost_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 gray_blue = mix(vec3(gray), frost_color.rgb, 0.42);
	vec3 iced = mix(source.rgb, gray_blue * (0.61 + grain * 0.31), amount);
	vec2 edge_uv = fract(cells + vec2(floor(cells.y) * 0.31, 0.0));
	float facet_edge = (1.0 - smoothstep(0.0, 0.06, edge_uv.x)) * step(0.78, grain);
	iced = mix(iced, gray_blue, shell * facet_edge * edge_strength);
	COLOR = vec4(iced, source.a);
}
