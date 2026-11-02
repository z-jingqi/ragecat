shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.3) = 0.07;
uniform float direction = -1.5707963;
uniform float cluster_size = 2.0;
uniform float seed_value = 17.0;
uniform vec4 edge_color : source_color = vec4(0.93, 0.79, 0.65, 1.0);
uniform float flash = 0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
float hash_cell(vec2 p) { float n = mod(p.x*73.0+p.y*151.0+seed_value*19.0,997.0); return mod(n*n+17.0*n+19.0,997.0)/997.0; }
void fragment() {
 vec4 base = texture(TEXTURE, UV) * vertex_tint;
 vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
 vec2 pixel_uv = (floor(UV * size) + 0.5) / size;
 vec2 cell = floor(floor(UV * size) / cluster_size);
 vec2 dir = vec2(cos(direction),sin(direction));
 float projected = dot(pixel_uv-0.5,dir)/(abs(dir.x)+abs(dir.y)) + 0.5;
 float threshold = 0.07 + 0.86*(projected*0.64+hash_cell(cell)*0.36);
 float visible = progress < threshold ? 1.0 : 0.0;
 float edge = progress > 0.0 && threshold-progress < edge_width ? 1.0 : 0.0;
 vec3 rgb = mix(base.rgb,edge_color.rgb,max(edge,flash));
 COLOR = vec4(rgb,base.a*visible);
}
