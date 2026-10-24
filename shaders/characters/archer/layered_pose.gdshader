shader_type canvas_item;
render_mode unshaded;
// Matching fixed-canvas pose layers share an orthographic camera and depth range.
// Zero depth is nearest. No per-pass normalization, mirrors or character rotations.
uniform sampler2D upper_color : source_color, filter_linear, repeat_disable;
uniform sampler2D lower_color : source_color, filter_linear, repeat_disable;
uniform sampler2D upper_depth : filter_nearest, repeat_disable;
uniform sampler2D lower_depth : filter_nearest, repeat_disable;
uniform vec4 upper_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 lower_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 upper_depth_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 lower_depth_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool upper_packed_depth = false;
uniform bool lower_packed_depth = false;
varying vec4 item_color;
void vertex() {
	item_color = COLOR;
}
void fragment() {
	vec2 u = upper_region.xy + UV * upper_region.zw;
	vec2 l = lower_region.xy + UV * lower_region.zw;
	vec4 top = texture(upper_color, u);
	vec4 bottom = texture(lower_color, l);
	vec2 ud = texture(upper_depth, upper_depth_region.xy + UV * upper_depth_region.zw).rg;
	vec2 ld = texture(lower_depth, lower_depth_region.xy + UV * lower_depth_region.zw).rg;
	float du = upper_packed_depth ? dot(ud, vec2(65280.0, 255.0)) / 65535.0 : ud.r;
	float dl = lower_packed_depth ? dot(ld, vec2(65280.0, 255.0)) / 65535.0 : ld.r;
	bool upper_front = du <= dl;
	vec4 front = upper_front ? top : bottom;
	vec4 back = upper_front ? bottom : top;
	float alpha = front.a + back.a * (1.0 - front.a);
	vec3 rgb = front.rgb * front.a + back.rgb * back.a * (1.0 - front.a);
	COLOR = vec4(rgb / max(alpha, 0.000001), alpha) * item_color;
}
