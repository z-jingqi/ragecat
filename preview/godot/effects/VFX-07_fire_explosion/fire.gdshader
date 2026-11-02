shader_type canvas_item;
render_mode unshaded;
uniform float u_age = 0.0;
uniform float u_duration = 0.60;
uniform float u_radius = 18.0;
uniform float u_rise = 22.0;
uniform int u_lobes = 7;
uniform int u_embers = 10;
uniform float u_spread = 1.0;
uniform float u_ember_length = 4.5;
uniform float u_smoke = 0.65;
uniform vec4 u_smoke_color : source_color;
uniform vec4 u_smoke_light : source_color;
uniform vec4 u_ash_color : source_color;
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
 float total=clamp(u_age/u_duration,0.0,1.0);
 float t=clamp(total/0.76,0.0,1.0);
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
 // Short cooling cloud behind the fire. Unequal puffs expand and lift;
 // coherent holes eat their mass, rather than uniform alpha fading.
 float sq=(total-0.22)/0.78;
 if(sq>0.0 && sq<1.0 && u_smoke>0.0) {
  float sm=99.0;
  for(int j=0;j<5;j++) {
   float f=float(j);
   float a=(f+rnd(f+210.0)*0.7)*1.256637;
   vec2 c=vec2(cos(a),sin(a)*0.6)*u_radius*(0.18+0.2*sq);
   c.y-=u_rise*(0.2+0.95*sq);
   float r=u_radius*(0.45+0.12*rnd(f+220.0))*(0.8+0.6*sqrt(sq))*u_smoke;
   sm=min(sm,oval(p,c,vec2(r,r*(1.0+0.2*sq))));
  }
  float erosion=smoothstep(0.40,1.0,sq);
  // Large, stable cavities grow across the cloud, leaving only a few chunks.
  bool hole=false;
  for(int j=0;j<6;j++) {
   float f=float(j);
   vec2 c=vec2((rnd(f+230.0)-0.5)*u_radius*1.15,-u_rise*(0.2+0.95*sq)+(rnd(f+240.0)-0.5)*u_radius*0.8);
   float r=u_radius*erosion*(0.18+0.12*rnd(f+250.0));
   if(oval(p,c,vec2(r,r*1.2))<1.0) {hole=true;}
  }
  if(sm<1.0-erosion*0.96 && !hole) {
   col=sm<0.70?u_smoke_color:u_ash_color;
   if(sm<0.52 && sq<0.70) {col=u_smoke_light;}
   if(sq<0.20 && sm<0.45) {col=u_edge_color;}
  }
 }
 if(mask<1.0 && cut<0.5 && t<0.89) {
  col=u_edge_color;
  if(mask<0.86) { col=u_flame_color; }
  if(mask<0.64 && heat>0.14) { col=u_body_color; }
  if(mask<0.36 && heat>0.56) { col=u_core_color; }
 }
 // Staggered fine sparks: sharp bright heads with tapered, cooling tails.
 // Sparse and asymmetric; no large rectangular dots or equal radial spokes.
 for(int i=0;i<16;i++) {
  if(i>=u_embers) { break; }
  float f=float(i);
  float a=(f+rnd(f+120.0)*0.90)/float(max(u_embers,1))*6.2831853;
  vec2 axis=vec2(cos(a),sin(a)*0.85);
  float start=0.035+rnd(f+130.0)*0.075;
  float life=0.29+rnd(f+140.0)*0.35;
  float q=(total-start)/life;
  if(q>=0.0 && q<1.0) {
   float travel=u_radius*(0.5+(0.65+0.55*rnd(f+150.0))*(1.0-pow(1.0-q,2.0)))*u_spread;
   vec2 c=axis*travel+vec2(0.0,(rnd(f+160.0)*10.0-2.0)*q*q);
   vec2 along=normalize(axis+vec2(0.0,q*0.25));
   float len=max(0.7,u_ember_length*(0.65+0.35*rnd(f+170.0))*pow(1.0-q,0.65));
   vec2 d=p-c;
   float longitudinal=dot(d,along);
   float lateral=abs(dot(d,vec2(-along.y,along.x)));
   float width=(0.30+0.45*rnd(f+180.0))*clamp((longitudinal+len)/len,0.0,1.0);
   if(longitudinal>-len && longitudinal<0.85 && lateral<max(0.27,width)) {
    col=q<0.35?u_body_color:(q<0.7?u_flame_color:u_edge_color);
    if(longitudinal>0.0 && q<0.28) {col=u_core_color;}
   }
  }
 }
 if(u_age<0.0 || total>=1.0) {col=vec4(0.0);}
 COLOR=col;
}
