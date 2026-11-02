shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform vec4 path_points[128];
uniform int point_count = 0;
uniform float trail_width = 2.4;
uniform float trail_length = 26.0;
uniform float taper = 0.75;
uniform float display_scale = 1.0;
uniform int body_kind = 0;
uniform float body_scale = 1.0;
uniform bool body_visible = true;
uniform vec2 facing = vec2(1.0,0.0);
uniform vec4 trail_color : source_color;
uniform vec4 trail_edge : source_color;
uniform vec4 metal_light : source_color;
uniform vec4 metal_dark : source_color;
uniform vec4 wood_color : source_color;
varying vec2 local_position;
void vertex() { local_position = VERTEX/display_scale; }
void fragment() {
    vec2 p = floor(local_position)+vec2(0.5);
    float best = 9999.0;
    float life = 0.0;
    float local_width = 0.0;
    for (int i=1; i<128; i++) {
        if (i>=point_count) { break; }
        vec2 a=path_points[i-1].xy;
        vec2 b=path_points[i].xy;
        vec2 ab=b-a;
        float t=clamp(dot(p-a,ab)/max(dot(ab,ab),0.0001),0.0,1.0);
        float s=mix(path_points[i-1].z,path_points[i].z,t);
        float remaining=mix(path_points[i-1].w,path_points[i].w,t);
        float width=trail_width*0.5*pow(max(0.0,1.0-s/max(trail_length,0.01)),taper)*pow(remaining,0.45);
        // Keep a subpixel-thin diagonal connected until the final tapered tip.
        float coverage = width > 0.16 ? max(width,0.54) : width;
        float d=length(p-(a+ab*t))-coverage;
        if (d<best) { best=d; life=remaining; local_width=width; }
    }
    vec4 ink = best < -0.45 ? trail_color : trail_edge;
    float alpha = best <= 0.0 ? ceil(life*3.0)/3.0 : 0.0;
    vec2 q=vec2(dot(p,facing),dot(p,vec2(-facing.y,facing.x)))/body_scale-vec2(0.5);
    if (body_visible) {
        bool metal=false;
        bool wood=false;
        bool guard=false;
        if (body_kind==0) {
            metal = q.x>=-6.0 && q.x<=0.0 && abs(q.y)<=(-q.x*0.5+0.1);
            wood = q.x>=-19.0 && q.x<=-5.0 && abs(q.y)<=0.55;
            bool feather = q.x>=-19.0 && q.x<=-14.0 && abs(q.y)>=0.65 && abs(q.y)<(-q.x-14.0)*0.58;
            metal = metal || feather;
        } else {
            metal = q.x>=-10.0 && q.x<=0.0 && abs(q.y)<=(-q.x*0.34+0.1);
            guard = q.x>=-12.0 && q.x<=-10.0 && abs(q.y)<=2.7;
            wood = q.x>=-17.0 && q.x<=-12.0 && abs(q.y)<=0.75;
        }
        if (wood) { ink=wood_color; alpha=1.0; }
        if (metal) { ink=q.y<=0.0 ? metal_light : metal_dark; alpha=1.0; }
        if (guard) { ink=metal_dark; alpha=1.0; }
    }
    COLOR=vec4(ink.rgb, alpha*ink.a);
}
