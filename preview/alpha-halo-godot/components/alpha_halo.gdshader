shader_type canvas_item;
render_mode unshaded;
uniform sampler2D source_texture : filter_linear, repeat_disable;
uniform vec4 source_rect = vec4(0.0,0.0,1.0,1.0);
uniform vec2 source_texel = vec2(1.0);
uniform vec2 display_size = vec2(76.0);
uniform float padding = 4.0;
uniform float width = 2.8;
uniform float strength = 0.0;
uniform vec4 glow_color : source_color = vec4(0.937,0.475,0.396,1.0);
uniform bool flip_h = false;
uniform bool flip_v = false;
varying vec4 inherited_color;
void vertex() { inherited_color = COLOR; }

float alpha_at(vec2 p) {
	if (p.x < 0.0 || p.y < 0.0 || p.x > 1.0 || p.y > 1.0) return 0.0;
	if (flip_h) p.x = 1.0-p.x;
	if (flip_v) p.y = 1.0-p.y;
	// Half-texel inset prevents bilinear reads from adjacent atlas frames.
	vec2 lo = source_rect.xy + source_texel*0.5;
	vec2 hi = source_rect.xy + source_rect.zw - source_texel*0.5;
	return texture(source_texture, clamp(source_rect.xy+p*source_rect.zw,lo,hi)).a;
}

void fragment() {
	vec2 p = (UV*(display_size+vec2(2.0*padding))-vec2(padding))/display_size;
	float center = alpha_at(p);
	float near_mask=0.0;
	float mid_mask=0.0;
	float far_mask=0.0;
	for (int i=0; i<16; i++) {
		float angle = float(i)*0.3926990817;
		vec2 delta = vec2(cos(angle),sin(angle))*width/display_size;
		near_mask=max(near_mask,alpha_at(p+delta*0.28));
		mid_mask=max(mid_mask,alpha_at(p+delta*0.58));
		far_mask=max(far_mask,alpha_at(p+delta));
	}
	// Three restrained, soft dilation bands; no ring geometry or interior tint.
	float halo = (near_mask*0.52+mid_mask*0.30+far_mask*0.18)*(1.0-center);
	COLOR = vec4(glow_color.rgb*inherited_color.rgb,clamp(halo*strength*inherited_color.a,0.0,1.0));
}
