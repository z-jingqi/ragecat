shader_type canvas_item;
// Uncullable textured flame/ember density in the exact unchanged collision band.
// Broad material gradients replace mechanical outline strokes. At no angle is
// the band erased by random holes, decorative atlas budgets, or repeating seams.
uniform vec4 arena_rect = vec4(0.0);
uniform float ring_radius = 42.0;
uniform float band_width = 28.0;
uniform float phase = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.78;
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
 if (arena_rect.z>0.0 && arena_rect.w>0.0 && (any(lessThan(world_position,arena_rect.xy)) || any(greaterThan(world_position,arena_rect.xy+arena_rect.zw)))) { discard; }
 float distance_from_band=abs(length(local_position)-ring_radius);
 float half_width=max(.01,band_width*.5);
 if (distance_from_band>half_width) { discard; }
 float across=distance_from_band/half_width;
 // Cartesian convection is seamless at the annulus's 0/TAU join.
 vec2 convection=local_position*.055+vec2(phase*.27,-phase*.36);
 float folds=fire_noise(convection+vec2(fire_noise(convection*1.8),0.0));
 float flecks=fire_noise(local_position*.29+vec2(phase*.7,-phase*.5));
 float heat=.65*folds+.35*flecks;
 // Only the last few pixels vary, always inward from the exact boundary.
 // A continuous center and faint full-width bed survive atlas budget exhaustion.
 float edge_reach=.76+.24*fire_noise(local_position*.24+vec2(phase*.4,-phase*.3));
 float irregular_flame=1.0-smoothstep(edge_reach-.15,edge_reach,across);
 // This low-density material envelope always reaches the original half-width.
 // It is not an outline: it fills the whole band and only softly fades inward
 // at the exact boundary. Irregular tongues remain the prominent silhouette.
 float full_width_envelope=1.0-smoothstep(.86,1.0,across);
 float continuous_bed=full_width_envelope*(.20+.06*flecks);
 float envelope=max(continuous_bed,irregular_flame);
 float core=smoothstep(.58,.86,heat)*(1.0-across*.68);
 vec3 tint=mix(vec3(.35,.035,.006),vec3(.95,.28,.035),core);
 COLOR=vec4(tint,envelope*(.35+.45*heat)*opacity);
}
