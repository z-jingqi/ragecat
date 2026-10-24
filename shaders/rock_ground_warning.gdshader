shader_type canvas_item;
// A continuous dusty footprint, not an extra attack or a stroked timer circle.
// The outer alpha envelope ends exactly at the existing gameplay radius.
uniform vec4 arena_rect = vec4(0.0);
uniform float hazard_radius = 44.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.56;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.10;
uniform vec4 dust_color : source_color = vec4(0.43, 0.40, 0.34, 1.0);
varying vec2 local_position;
varying vec2 world_position;
float noise_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float grain(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(noise_hash(i),noise_hash(i+vec2(1,0)),f.x),mix(noise_hash(i+vec2(0,1)),noise_hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 local_position=VERTEX;
 world_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}
void fragment() {
 if (arena_rect.z>0.0 && arena_rect.w>0.0 && (any(lessThan(world_position,arena_rect.xy)) || any(greaterThan(world_position,arena_rect.xy+arena_rect.zw)))) { discard; }
 vec2 p=local_position/max(hazard_radius,0.01);
 float r=length(p);
 float envelope=1.0-smoothstep(1.0-edge_softness,1.0,r);
 float flecks=grain(p*27.0+vec2(progress*1.6,-progress*.7));
 float haze=(grain(p*4.5*(1.0+progress*.15)+vec2(.4,-.8))+.5*grain(p*10.0)+.25*grain(p*23.0))/1.75;
 float cloud=.45+.55*grain(p*2.8+vec2(3.8,2.1));
 // A continuous subdued base keeps the full danger footprint readable;
 // unequal dusty patches, rather than a brighter rim, describe its surface.
 float dust=.16+.60*smoothstep(.35,.78,haze)*smoothstep(.22,.65,cloud);
 dust+=.10*smoothstep(.72,.95,flecks)*haze;
 float shadow=(1.0-smoothstep(.05,.5,r))*(.10+.30*progress);
 vec3 tint=mix(dust_color.rgb,vec3(.06,.055,.045),shadow);
 float alpha=envelope*opacity*(dust*(.75+.25*progress)+shadow*.45);
 COLOR=vec4(tint,alpha);
}
