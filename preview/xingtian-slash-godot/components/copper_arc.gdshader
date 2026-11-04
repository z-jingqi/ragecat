// Crescent taper, exponential sweep and chasing tail adapted from Sprite Fusion slash.
// https://www.spritefusion.com/pixel-art-vfx/slash, MIT, Copyright (c) 2026 Hugo Duprez.
// New copper ramp, angular chips and compact no-glow timing for Xing Tian.
shader_type canvas_item;
render_mode unshaded;
uniform float radius = 52.0;
uniform float thickness = 16.0;
uniform float squash = 0.78;
uniform float sweep = 2.583;
uniform float direction = -0.2094;
uniform bool reverse = false;
uniform float roughness = 1.4;
uniform float pixel_size = 1.0;
uniform float duration = 0.25;
uniform float onset = 0.05;
uniform float hold = 0.035;
uniform float age = 0.0;
uniform float intensity = 1.0;
uniform float shape_seed = 19.0;
uniform vec4 edge_color : source_color = vec4(0.937,0.69,0.475,1);
uniform vec4 body_color : source_color = vec4(0.8,0.412,0.259,1);
uniform vec4 inner_color : source_color = vec4(0.639,0.235,0.18,1);
uniform vec4 shade_color : source_color = vec4(0.384,0.141,0.173,1);
varying vec2 local_position;

float hash(float n) { return fract(sin(n*127.1+shape_seed*9.31)*43758.5453); }
void vertex() { local_position=VERTEX; }
void fragment() {
	vec4 col=vec4(0.0);
	// Quantize before the orientation transform: art pixels stay square when aiming.
	vec2 p=(floor(local_position/pixel_size)+0.5)*pixel_size;
	float c=cos(direction), s=sin(direction);
	vec2 q=vec2(p.x*c+p.y*s,(-p.x*s+p.y*c)/squash);
	if(reverse) q.y=-q.y;
	float angle=atan(q.y,q.x);
	float u=(angle+sweep*0.5)/sweep;
	float head=age>=onset ? 1.0 : 1.0-pow(2.0,-10.0*max(age,0.0)/onset);
	float tail=smoothstep(onset+hold,duration,age);
	float span=head-tail;
	if(age>0.0 && age<duration && span>0.003 && u>=tail && u<=head) {
		float v=(u-tail)/span;
		float taper=pow(max(sin(3.14159265*pow(v,1.8)),0.0),0.6);
		float chip=hash(floor((angle+3.14159265)*26.0));
		float outside=radius-roughness*chip;
		float width=thickness*(1.0-tail*0.65)*taper;
		float r=length(q);
		float band=(outside-r)/max(width,0.001);
		float nick=roughness*(hash(floor((angle+3.14159265)*42.0))-0.25);
		if(width>0.4 && band>=0.0 && band<=1.0-nick/max(width,1.0)) {
			float cooling=smoothstep(onset+hold,duration,age);
			if(band<0.13 && cooling<0.35) col=edge_color;
			else if(band<0.46-cooling*0.25) col=body_color;
			else if(band<0.82-cooling*0.2) col=inner_color;
			else col=shade_color;
			// Coherent shallow grooves on the inner edge, not full-surface noise.
			if(band>0.70 && chip<0.19) col=shade_color;
		}
	}
	col.rgb=clamp(col.rgb*intensity,vec3(0.0),vec3(1.0));
	COLOR=col;
}
