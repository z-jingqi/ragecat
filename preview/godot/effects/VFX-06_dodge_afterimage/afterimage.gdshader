shader_type canvas_item;
render_mode unshaded;
uniform vec4 tone : source_color=vec4(0.48,0.87,0.92,1);
uniform float fade=0.6;
uniform float color_mix=0.85;
varying vec4 host_modulation;
void vertex(){host_modulation=COLOR;}
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 vec4 modulation=host_modulation;
 COLOR=vec4(mix(tex.rgb,tone.rgb,color_mix)*modulation.rgb,tex.a*modulation.a*fade*tone.a);
}
