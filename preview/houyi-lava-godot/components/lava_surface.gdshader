shader_type canvas_item;
render_mode unshaded;
uniform float extent = 76.0;
uniform float radius = 54.0;
uniform float perspective = 0.62;
uniform float pixel_size = 1.0;
uniform int shape_seed = 37;
uniform float age = 0.0;
uniform float opening_time = 0.65;
uniform float hold_time = 3.6;
uniform float cooling_time = 1.1;
uniform float fade_time = 0.8;
uniform float flow_speed = 0.22;
uniform float channel_width = 0.31;
uniform float crust_scale = 15.0;
uniform float lava_opacity = 0.94;
uniform vec4 lava_dark : source_color = vec4(0.388,0.137,0.149,1.0);
uniform vec4 lava_red : source_color = vec4(0.678,0.239,0.165,1.0);
uniform vec4 lava_orange : source_color = vec4(0.894,0.467,0.216,1.0);
uniform vec4 crust_color : source_color = vec4(0.161,0.149,0.169,1.0);
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)) + float(shape_seed)*0.91)*43758.5453); }
vec2 h2(vec2 p) { return vec2(hash(p),hash(p+17.7)); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.-2.*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
vec2 cells(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); float d1=8.; float d2=8.;
	for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) { vec2 o=vec2(float(x),float(y)); vec2 v=o+0.2+0.6*h2(i+o)-f; float d=dot(v,v); if(d<d1){d2=d1; d1=d;}else{d2=min(d2,d);} }
	return vec2(sqrt(d1),sqrt(d2)-sqrt(d1));
}
void fragment() {
	vec2 p = floor(((UV*2.-1.)*extent)/pixel_size)*pixel_size;
	vec2 q = p / vec2(1.,perspective);
	float n = noise(q*0.055);
	float angle = atan(q.y,q.x);
	float edge = radius*(0.91 + 0.055*sin(angle*5. + float(shape_seed)) + 0.035*sin(angle*9.-2.) + 0.06*(n-0.5));
	float dist = length(q);
	float depth = edge-dist;
	float open = smoothstep(0.08,opening_time,age);
	float cooling = smoothstep(opening_time+hold_time,opening_time+hold_time+cooling_time,age);
	float fade = 1.-smoothstep(opening_time+hold_time+cooling_time,opening_time+hold_time+cooling_time+fade_time,age);
	vec2 flow = vec2(age*flow_speed, -age*flow_speed*0.35);
	vec2 warp = vec2(noise(q*0.06+flow*0.2),noise(q*0.06+16.+flow*0.2))-0.5;
	vec2 cell = cells(q/crust_scale + warp*1.15 + flow*0.09);
	float vein = channel_width*(0.72+0.55*noise(q*0.11+flow));
	float fissure = 1.-smoothstep(vein*0.66,vein,cell.y);
	fissure = max(fissure,smoothstep(0.55,0.72,noise(q*0.045+flow*0.22))*0.90);
	float revealed = step(dist, edge*open);
	float initial = step(dist,edge*smoothstep(0.,opening_time*0.65,age))*step(cell.y,0.045);
	float visible = max(revealed,initial);
	float hot = clamp((fissure-cooling*1.15),0.,1.);
	float stream = noise(q*vec2(0.15,0.20) + flow*1.2 + warp*2.);
	vec3 c = crust_color.rgb*(0.82+0.32*floor(n*4.)/3.);
	// Rock facets are small clusters, not screen-space speckle.
	c += vec3(0.045,0.022,0.012)*step(cell.y,vein*1.5)*(1.-cooling);
	vec3 molten = mix(lava_dark.rgb,lava_red.rgb,step(0.28,stream));
	molten = mix(molten,lava_orange.rgb,step(0.68,stream)*step(0.7,hot)*0.8);
	c = mix(c,molten,hot);
	// Carved shadow, fractured warm rim and front-facing rock lip.
	float border=step(depth,3.5)*step(0.,depth);
	vec3 rim = mix(vec3(0.08,0.066,0.078),vec3(0.23,0.15,0.15),step(0.0,p.y));
	rim = mix(rim,lava_red.rgb*0.8,step(1.4,depth)*(1.-cooling)*0.7);
	c=mix(c,rim,border);
	float outside=step(depth,0.)*step(-2.0,depth);
	c=mix(c,vec3(0.06,0.05,0.07),outside);
	float alpha = step(-2.,depth)*visible*fade*lava_opacity;
	COLOR=vec4(c,alpha);
}
