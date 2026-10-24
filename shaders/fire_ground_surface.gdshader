shader_type canvas_item;
// Continuous heat/ash density marks the exact existing hazard footprint.
// The simulation clock drives motion; no wall-clock drift, outline, expanding disk or timer arc.
uniform vec4 arena_rect = vec4(0.0);
uniform float hazard_radius = 120.0;
uniform float phase = 0.0;
uniform float burn_progress : hint_range(0.0, 1.0) = 0.0;
uniform bool active = false;
uniform float ground_opacity : hint_range(0.0, 1.0) = 0.64;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.10;
varying vec2 local_position;
varying vec2 world_position;
float fire_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float fire_noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(fire_hash(i),fire_hash(i+vec2(1,0)),f.x),mix(fire_hash(i+vec2(0,1)),fire_hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 local_position=VERTEX;
 world_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}
void fragment() {
 if (!active) { discard; }
 if (arena_rect.z>0.0 && arena_rect.w>0.0 && (any(lessThan(world_position,arena_rect.xy)) || any(greaterThan(world_position,arena_rect.xy+arena_rect.zw)))) { discard; }
 vec2 p=local_position/max(hazard_radius,0.01);
 float r=length(p);
 float envelope=1.0-smoothstep(1.0-edge_softness,1.0,r);
 if (r>=1.0) { discard; }
 // Fixed fine material scale in world pixels avoids large camouflage islands
 // as the main hazard grows. The bed remains continuous through its center.
 vec2 q=local_position*.21;
 vec2 drift=vec2(sin(phase*.75),cos(phase*.75))*.16;
 float ash=fire_noise(q+vec2(2.1,-.4));
 float grain=fire_noise(q*2.8);
 float carbon=fire_noise(q*.43+vec2(-1.7,2.3));
 float convection=fire_noise(q*.9+drift+vec2(ash*.5,grain*.25));
 // Thin ridges form distributed broken charcoal fissures, not broad blobs.
 float fissure=1.0-smoothstep(.018,.072,abs(convection-.5));
 fissure*=smoothstep(.35,.70,grain*.65+ash*.35);
 float ember=smoothstep(.76,.91,grain)*smoothstep(.48,.72,ash);
 vec3 tint;
 float alpha;
 if (active) {
  // Hot distributed material remains readable for the entire damage window.
  // Tiny ember fissures cool gently; the continuous bed never becomes smoke.
  float heat=fissure*(.58-.18*burn_progress)+ember*.35;
  tint=mix(vec3(.30,.075,.019),vec3(.46,.14,.032),.35+.35*ash);
  tint=mix(tint,vec3(.90,.33,.052),clamp(heat,0.0,.78));
  alpha=envelope*(.53+.10*ash+.06*grain)*ground_opacity;
 }
 COLOR=vec4(tint,alpha);
}
