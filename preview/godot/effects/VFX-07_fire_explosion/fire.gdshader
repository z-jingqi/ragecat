shader_type canvas_item;
render_mode unshaded;
uniform float u_age = 0.0;
uniform float u_duration = 0.48;
uniform float u_radius = 18.0;
uniform float u_rise = 22.0;
uniform int u_lobes = 7;
uniform int u_embers = 6;
uniform float u_spread = 1.0;
uniform float u_seed = 37.0;
uniform float u_extent = 80.0;
uniform vec4 u_core_color : source_color;
uniform vec4 u_body_color : source_color;
uniform vec4 u_flame_color : source_color;
uniform vec4 u_edge_color : source_color;
// Stable per-element shape, never rerolled per frame. Original analytic mask.
float rnd(float n) { return fract(sin(n*127.1+u_seed*31.7)*43758.5453); }
float oval(vec2 p, vec2 c, vec2 r) { return length((p-c)/max(r,vec2(0.05))); }
void fragment() {
 vec2 p=floor(UV*u_extent*2.0)-vec2(u_extent)+vec2(0.5);
 float t=clamp(u_age/u_duration,0.0,1.0);
 float burst=1.0-pow(1.0-clamp(t/0.24,0.0,1.0),3.0);
 float shrink=1.0-smoothstep(0.30,0.89,t);
 float heat=1.0-smoothstep(0.10,0.68,t);
 float mask=99.0;
 // A compact merging mass, then separated rising tongues. Not a scaled image.
 for(int i=0;i<10;i++) {
  if(i>=u_lobes) { break; }
  float f=float(i);
  float a=(f+0.21+rnd(f+1.0)*0.48)/float(u_lobes)*6.2831853;
  vec2 axis=vec2(cos(a),sin(a)*0.76);
  float reach=u_radius*burst*(0.28+0.42*rnd(f+17.0))*u_spread;
  vec2 c=axis*reach+vec2((rnd(f+60.0)-0.5)*t*6.0,-u_rise*t*t);
  float rr=u_radius*(0.32+0.17*rnd(f+30.0))*(0.28+0.72*burst)*shrink;
  float v=oval(p,c,vec2(rr,rr*(1.02+0.7*t)));
  mask=min(mask,v);
 }
 // One early inner mass connects the blast; late gaps expose genuine breakup.
 float center=oval(p,vec2(-u_radius*0.08,-u_rise*t*t),vec2(u_radius*0.57*(0.28+burst)*shrink));
 if(t<0.24) { mask=min(mask,center); }
 float cut=0.0;
 if(t>0.36) {
  for(int j=0;j<4;j++) {
   float f=float(j);
   vec2 c=vec2((rnd(f+90.0)-0.5)*u_radius*1.3,-u_rise*t*t+(rnd(f+98.0)-0.5)*u_radius);
   float r=u_radius*smoothstep(0.36,0.84,t)*(0.16+0.15*rnd(f+110.0));
   if(oval(p,c,vec2(r,r*1.25))<1.0) { cut=1.0; }
  }
 }
 vec4 col=vec4(0.0);
 if(mask<1.0 && cut<0.5 && t<0.89) {
  col=u_edge_color;
  if(mask<0.86) { col=u_flame_color; }
  if(mask<0.64 && heat>0.14) { col=u_body_color; }
  if(mask<0.36 && heat>0.56) { col=u_core_color; }
 }
 // Short outward embers decelerate, lift, and shrink instead of alpha drifting.
 for(int i=0;i<12;i++) {
  if(i>=u_embers) { break; }
  float f=float(i);
  float a=(f+rnd(f+120.0)*0.75)/float(max(u_embers,1))*6.2831853;
  vec2 axis=vec2(cos(a),sin(a)*0.75);
  float start=0.09+rnd(f+130.0)*0.08;
  float life=0.43+rnd(f+140.0)*0.30;
  float q=(t-start)/life;
  if(q>=0.0 && q<1.0) {
   float travel=u_radius*(0.4+(0.8+0.45*rnd(f+150.0))*(1.0-pow(1.0-q,2.0)))*u_spread;
   vec2 c=axis*travel+vec2(0.0,-u_rise*q*q*0.65);
   float w=q<0.5?1.4:0.75;
   float len=mix(3.6,0.7,q)*(u_radius/18.0);
   vec2 d=p-c;
   vec2 along=normalize(axis);
   if(abs(dot(d,vec2(-along.y,along.x)))<w && abs(dot(d,along))<len) {
    col=q<0.30?u_body_color:(q<0.65?u_flame_color:u_edge_color);
   }
  }
 }
 if(u_age<0.0 || t>=1.0) {col=vec4(0.0);}
 COLOR=col;
}
