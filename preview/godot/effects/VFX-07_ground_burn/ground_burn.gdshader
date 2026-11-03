shader_type canvas_item;
render_mode unshaded;
uniform bool outline_pass = false;
uniform float extent = 50.0;
uniform float radius = 46.0;
uniform float duration = 4.0;
uniform float age = 0.0;
uniform float pixel_size = 2.0;
uniform float flame_height = 14.0;
uniform int flame_count = 16;
uniform float intensity = 0.8;
uniform float ground_opacity = 0.22;
uniform float outline_width = 2.0;
uniform float seed = 37.0;
uniform float enter_time = 0.1;
uniform float exit_time = 0.25;
uniform vec4 core_color : source_color = vec4(1.0,0.90,0.63,1.0);
uniform vec4 body_color : source_color = vec4(1.0,0.70,0.29,1.0);
uniform vec4 flame_color : source_color = vec4(0.91,0.40,0.20,1.0);
uniform vec4 coal_color : source_color = vec4(0.33,0.18,0.16,1.0);
uniform vec4 outline_color : source_color = vec4(0.93,0.60,0.29,1.0);

float rnd(float n) { return fract(sin(n*127.1+seed*31.7)*43758.5453); }

void fragment() {
 vec4 modulation = COLOR;
 vec2 p = (floor((UV*2.0-1.0)*extent/pixel_size)+0.5)*pixel_size;
 float distance_to_center = length(p);
 float edge = radius-distance_to_center;
 float life = clamp((duration-age)/max(exit_time,0.0001),0.0,1.0);
 float ignition = enter_time > 0.0 ? clamp(age/enter_time,0.0,1.0) : 1.0;
 float energy = min(ignition,life)*intensity;
 vec4 result = vec4(0.0);
 if(age >= 0.0 && age < duration && edge >= 0.0) {
  if(outline_pass) {
   // A complete thin boundary survives the full logical lifetime. All zone
   // outlines draw above all body fills, including at overlap intersections.
   if(edge <= max(outline_width,pixel_size)) {
    float angle = atan(p.y,p.x);
    float glint = step(0.82,fract(angle*3.0+age*0.20+seed*0.031));
    result = vec4(mix(outline_color.rgb,core_color.rgb,glint*0.35),0.74);
   }
  } else {
   // Translucent, porous coal bed. No opaque disk or luminous full-area wash.
   vec2 cell = floor(p/(pixel_size*3.0));
   float coals = rnd(dot(cell,vec2(7.0,19.0))+400.0);
   if(edge > pixel_size && coals > 0.23) {
    result = vec4(coal_color.rgb,ground_opacity*life);
    float seam = fract((p.x+p.y*0.65)/(pixel_size*7.0)+coals*2.0);
    if(coals > 0.68 && seam < 0.15 && energy > 0.2) {
     result = vec4(flame_color.rgb,0.34*energy);
    }
   }
   // Analytic, staggered short flame tongues. Fixed upper bound; no particle
   // history, global TIME, frame-dependent random calls, timers or textures.
   for(int i=0;i<24;i++) {
    if(i >= flame_count) { break; }
    float n = float(i);
    float theta = n*2.39996323+seed*0.17;
    float radial = sqrt((n+0.5)/float(max(flame_count,1)))*radius*0.80;
    vec2 anchor = vec2(cos(theta),sin(theta))*radial;
    float phase = fract(age*(0.95+rnd(n+60.0)*0.45)+rnd(n+11.0));
    float pulse = sin(phase*3.14159265);
    float height = min(flame_height,radius*0.40)*(0.55+0.45*rnd(n+24.0))*pulse*energy;
    float width = max(pixel_size*1.2,height*0.31);
    vec2 q = p-anchor;
    float up = -q.y;
    if(height > pixel_size && up >= -pixel_size && up < height) {
     float v = clamp(up/height,0.0,1.0);
     float lean = sin(v*3.8+age*3.0+n)*v*height*0.22;
     float waist = width*pow(1.0-v,0.72);
     float side = abs(q.x-lean)/max(waist,0.01);
     if(side < 1.0) {
      result = flame_color;
      if(side < 0.66 && v < 0.72) { result = body_color; }
      if(side < 0.31 && v < 0.34) { result = core_color; }
      result.a = 0.92;
     }
    }
   }
  }
 }
 COLOR = result*modulation;
}
