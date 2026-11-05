// Elemental adaptation of the accepted crescent: wider forward light core. Original file unchanged.
// MIT Copyright (c) 2026 Hugo Duprez. Own shader, warm palette, restrained light and chips.
shader_type canvas_item;
render_mode unshaded;
uniform float radius = 52.0;
uniform float thickness = 12.0;
uniform float squash = 0.6;
uniform float sweep = 3.490659;
uniform float direction = -0.383972;
uniform float sweep_center = -0.802851;
uniform bool reverse = false;
uniform bool facing_left = false;
uniform float roughness = 0.45;
uniform float pixel_size = 1.0;
uniform float duration = 0.36;
uniform float onset = 0.06;
uniform float hold = 0.06;
uniform float thread_duration = 0.12;
uniform bool echo_enabled = true;
uniform bool thread_enabled = true;
uniform bool glint_enabled = true;
uniform float glow_strength = 0.16;
uniform float age = 0.0;
uniform float intensity = 1.0;
uniform float shape_seed = 19.0;
uniform vec4 edge_color : source_color = vec4(1.0,0.96,0.85,1);
uniform vec4 highlight_color : source_color = vec4(1.0,0.83,0.58,1);
uniform vec4 body_color : source_color = vec4(0.94,0.60,0.33,1);
uniform vec4 inner_color : source_color = vec4(0.78,0.34,0.20,1);
uniform vec4 shade_color : source_color = vec4(0.52,0.19,0.18,1);
uniform vec4 tail_color : source_color = vec4(0.34,0.15,0.20,1);
uniform vec4 dark_color : source_color = vec4(0.21,0.12,0.18,1);
varying vec2 local_position;
float hash(float n) { return fract(sin(n*127.1+shape_seed*9.31)*43758.5453); }
float bayer(vec2 p) {
	ivec2 i=ivec2(mod(floor(p),4.0));
	int m[16] = {0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
	return float(m[i.y*4+i.x])/16.0;
}
vec4 ramp(float index) {
	if(index<0.5) return edge_color;
	if(index<1.5) return highlight_color;
	if(index<2.5) return body_color;
	if(index<3.5) return inner_color;
	if(index<4.5) return shade_color;
	if(index<5.5) return tail_color;
	return dark_color;
}
// Returns opaque palette pixels or transparent. No image/spritesheet sampling.
vec4 blade(vec2 q, vec2 pixel, float t, bool echo) {
	float delay=echo ? min(0.017,hold*0.5+max(duration-onset-hold,0.0)/6.0) : 0.0;
	float time=t-delay;
	float trailing=max(duration-onset-hold,0.001)*(echo ? 5.0/6.0 : 1.0);
	float holding=hold*(echo ? 0.5 : 1.0);
	float total=onset+holding+trailing;
	float head=time>=onset ? 1.0 : 1.0-pow(2.0,-10.0*max(time,0.0)/onset);
	float tail=smoothstep(onset+holding,total,time);
	float span=head-tail;
	float R=radius*(echo ? 33.0/42.0 : 1.0);
	float W=echo ? radius*(4.5/42.0) : thickness;
	float start=sweep_center-sweep*0.5+(echo ? sweep*0.1 : 0.0);
	float angle_span=sweep*(echo ? 1.0-0.1-0.15/3.5 : 1.0);
	float u=mod(atan(q.y,q.x)-start+TAU,TAU)/angle_span;
	float dist=length(q);
	float fade=clamp(time/total,0.0,1.0);
	float dith=bayer(pixel);
	vec4 col=vec4(0.0);
	if(time>0.0 && time<total && span>0.003 && u>=tail && u<=head) {
		float v=(u-tail)/span;
		float taper=pow(max(sin(PI*pow(v,2.2)),0.0),0.6);
		float outer=R-roughness*hash(floor(u*73.0))*(echo ? 0.3 : 1.0);
		float width=W*(1.0-tail*0.55)*taper;
		float band=(outer-dist)/max(width,0.001);
		if(width>0.35 && band>=0.0 && band<=1.0 && min(1.0,v/0.4)>dith) {
			float ci=band<(0.18+0.28*smoothstep(0.5,0.94,v)) && fade<0.5 ? 0.0 : floor(band*(echo?5.0:6.0)*0.75+fade*2.4-v*0.8+0.9);
			col=ramp(clamp(ci+(echo?1.0:0.0),0.0,6.0));
		}
	}
	float thread_fade=0.7*(1.0-clamp((time-onset-holding)/(trailing+thread_duration),0.0,1.0));
	if(thread_enabled && tail>0.02 && u>=0.0 && u<=tail && abs(dist-(R-0.5))<0.55 && thread_fade*(0.4+0.6*u)>dith && col.a==0.0) col=tail_color;
	return col;
}
void vertex() { local_position=VERTEX; }
void fragment() {
	vec2 p=(floor(local_position/pixel_size)+0.5)*pixel_size;
	if(facing_left) p.x=-p.x;
	float c=cos(direction), s=sin(direction);
	vec2 q=vec2(p.x*c+p.y*s,(-p.x*s+p.y*c)/squash);
	if(reverse) q.y=-q.y;
	vec4 col=vec4(0.0);
	if(age>0.0 && age<duration+thread_duration) {
		float head=age>=onset ? 1.0 : 1.0-pow(2.0,-10.0*age/onset);
		float a=sweep_center-sweep*0.5+sweep*head;
		vec2 head_local=vec2(cos(a),sin(a)*squash)*(radius-thickness*0.3);
		vec2 oriented=vec2(q.x,q.y*squash);
		float light_age=max(0.0,1.0-age/min(duration,0.30));
		float glow=pow(max(0.0,1.0-distance(oriented,head_local)/18.0),2.0)*glow_strength*light_age;
		col=vec4(body_color.rgb,glow);
		vec4 echo=echo_enabled ? blade(q,p/pixel_size,age,true) : vec4(0.0);
		if(echo.a>0.0) col=echo;
		vec4 main=blade(q,p/pixel_size,age,false);
		if(main.a>0.0) col=main;
		// Compact warm glint belongs to the blade. Hit particles still require play_hit.
		float gt=age-onset*0.6;
		if(glint_enabled && gt>0.0 && gt<0.16) {
			float end_angle=sweep_center+sweep*0.5;
			vec2 end=vec2(cos(end_angle),sin(end_angle)*squash)*(radius-thickness*0.3);
			vec2 g=abs(oriented-end);
			float arm=floor(4.0*min(1.0,gt/0.025)*(1.0-gt/0.16));
			if((g.x<0.65 && g.y<=arm)||(g.y<0.65 && g.x<=arm)) col=highlight_color;
			if(max(g.x,g.y)<0.7) col=edge_color;
		}
	}
	col.rgb=clamp(col.rgb*intensity,vec3(0.0),vec3(1.0));
	COLOR=col;
}
