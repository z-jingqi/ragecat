shader_type canvas_item;
// The sprite's alpha is untouched: frost never fills transparent pixels.
uniform float freeze_coverage : hint_range(0.0, 1.0) = 0.0;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_color : source_color = vec4(0.737, 0.937, 1.0, 1.0);
uniform float noise_scale = 38.0;
uniform float edge_softness = 0.07;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	// Fragment COLOR already contains the sampled texture and modulate.
	vec4 source = COLOR;
	float grain = hash(floor(UV * noise_scale));
	float front = 1.0 - freeze_coverage * 1.12;
	float shell = smoothstep(front - edge_softness, front + edge_softness, UV.y + (grain - 0.5) * 0.10);
	shell *= step(0.001, freeze_coverage);
	float amount = clamp(frost_amount * 0.35 + shell * 0.7, 0.0, 0.85);
	vec3 iced = mix(source.rgb, frost_color.rgb * (0.8 + grain * 0.2), amount);
	COLOR = vec4(iced, source.a);
}
