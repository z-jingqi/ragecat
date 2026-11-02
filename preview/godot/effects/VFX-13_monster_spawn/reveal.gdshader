shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.83,1.0,0.93,1.0);
varying vec4 host_modulate;
void vertex(){host_modulate=COLOR;}
void fragment(){
 vec4 source = texture(TEXTURE,UV) * host_modulate;
 float row = floor(UV.y / TEXTURE_PIXEL_SIZE.y);
 float threshold = floor((1.0-progress)/TEXTURE_PIXEL_SIZE.y);
 float visible = step(threshold,row) * step(0.00001,progress);
 float edge = (1.0-step(threshold+2.0,row))*step(progress,0.99999);
 COLOR=vec4(mix(source.rgb,edge_color.rgb,edge*0.8),source.a*visible);
}
