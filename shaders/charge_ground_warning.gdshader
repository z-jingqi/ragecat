shader_type canvas_item;
uniform vec4 arena_rect=vec4(0.0);
uniform vec2 path_start=vec2(0.0);
uniform vec2 path_end=vec2(1.0,0.0);
uniform float path_width=96.0;
uniform float clock=0.0;
uniform float opacity : hint_range(0.0,1.0)=0.48;
uniform vec4 dust_color : source_color=vec4(.60,.43,.29,1);
varying vec2 at;
varying vec2 world;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float grain(vec2 p) { vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() { at=VERTEX;world=(MODEL_MATRIX*vec4(VERTEX,0,1)).xy; }
void fragment() {
 if (arena_rect.z>0.0 && arena_rect.w>0.0 && (any(lessThan(world,arena_rect.xy))||any(greaterThan(world,arena_rect.xy+arena_rect.zw)))) {discard;}
 vec2 delta=path_end-path_start;float span=max(length(delta),.01);vec2 axis=delta/span;vec2 side=vec2(-axis.y,axis.x);
 vec2 p=vec2(dot(at-path_start,axis),dot(at-path_start,side));
 float lateral=abs(p.y)/max(path_width*.5,.01);
 float bound=(1.0-smoothstep(.78,1.0,lateral))*smoothstep(0.0,min(18.0,span*.1),p.x)*(1.0-smoothstep(span-min(24.0,span*.1),span,p.x));
 float grit=grain(vec2(p.x*.09-clock*.6,p.y*.13));
 float scuff=grain(vec2(p.x*.012-clock*1.6,p.y*.34+grain(vec2(p.x*.016,1.0))*.8));
 float density=.20+.12*grit+.46*smoothstep(.50,.88,scuff);
 COLOR=vec4(dust_color.rgb,bound*density*opacity);
}
