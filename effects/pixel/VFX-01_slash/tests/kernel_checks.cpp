// Executes the unchanged scalar kernel as C++ for math checks; not an engine or GPU compile.
#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <vector>
float clamp(float x,float a,float b) { return std::clamp(x,a,b); }
struct float2 { float x, y; float2(float a, float b):x(a),y(b){} };
float length(float2 p) { return std::hypot(p.x,p.y); }
using std::max;
#include "../src/shared/SlashKernel.inc"

float sample(float x,float y,float age,float direction=0,float reverse=1,float reach=46,float thick=13,float sweep=112,float curve=.82) {
    return slash_band(float2(x,y),age,reach,thick,sweep*3.14159265359f/180,curve,direction,reverse,.025,.065,.09);
}
int count(float t,float direction=0,float reverse=1,float reach=46,float thick=13,float sweep=112,float curve=.82) {
    int n=0;
    for(int y=-90;y<90;y++) for(int x=-90;x<90;x++) {
        float b=sample(x+.5,y+.5,t,direction,reverse,reach,thick,sweep,curve);
        assert(std::isfinite(b)); assert(b==0||b==1||b==2||b==3); n+=b>0;
        if(b) assert(std::hypot(x+.5,y+.5)<=reach+.01);
    }
    return n;
}
int main() {
    assert(count(-1)==0); assert(count(0)==0); assert(count(.18)==0); assert(count(5)==0);
    int initial=count(.018), broad=count(.089), retract=count(.140), last=count(.179);
    assert(initial<broad/10); assert(broad>200); assert(retract<broad/2); assert(last<broad/20);
    // Equal analytic taper at both ends, with an unchanged full-width midpoint.
    assert(slash_profile(0)==0 && slash_profile(1)==0);
    assert(std::abs(slash_profile(.5)-1)<1e-6);
    for(float v : {.01f,.02f,.05f,.1f,.2f,.35f}) {
        assert(std::abs(slash_profile(v)-slash_profile(1-v))<1e-6);
        assert(slash_profile(v)<slash_profile(v+.01f));
    }
    assert(slash_profile(.05)<.12 && slash_profile(.1)<.25);
    // Tip inside/outside geometry survives rotations, reversal and width/ellipse limits.
    for(int degrees=0;degrees<360;degrees+=15) for(float reverse : {-1.f,1.f})
    for(float reach : {16.f,46.f,80.f}) for(float thick : {2.f,13.f,28.f})
    for(float curve : {.35f,.82f,1.f}) for(float v : {.02f,.05f,.1f,.9f,.95f,.98f}) {
        float w=std::min(thick,reach*.65f), angle=degrees*3.14159265359f/180;
        float theta=(v-.5f)*112.f*3.14159265359f/180;
        for(float depth : {.4f,1.2f}) {
            float r=reach-depth*w*slash_profile(v);
            float x=r*std::cos(theta), y=r*std::sin(theta)*curve*reverse;
            float px=x*std::cos(angle)-y*std::sin(angle);
            float py=x*std::sin(angle)+y*std::cos(angle);
            float band=sample(px,py,.09f,angle,reverse,reach,w,112,curve);
            assert((depth<1)==(band>0));
        }
    }
    // Reflection is exact on pixel centers; arbitrary rotation does not change pixel size.
    for(float t : {.012f,.03f,.06f,.09f,.12f,.16f}) {
        for(int y=-80;y<80;y++) for(int x=-80;x<80;x++) {
            assert(sample(x+.5,y+.5,t,0,1)==sample(x+.5,-y-.5,t,0,-1));
        }
    }
    for(int degrees=0;degrees<360;degrees+=15) {
        int n=count(.089,degrees*3.14159265359/180);
        assert(std::abs(n-broad)<broad*.08); // raster coverage stays stable through 360 degrees
    }
    // All exposed shape boundaries, lifecycle phases and valid timing boundaries stay finite.
    for(float reach : {16.f,46.f,80.f}) for(float thick : {2.f,10.f,28.f})
    for(float sweep : {30.f,112.f,220.f}) for(float curve : {.35f,.82f,1.f}) {
        float w=std::min(thick,reach*.65f);
        for(float t : {0.f,.01f,.025f,.05f,.09f,.14f,.18f}) count(t,2.1,-1,reach,w,sweep,curve);
    }
    // Independent phases must remain visible for their own durations, no fixed-frame dependency.
    for(float start : {.005f,.08f}) for(float burst : {.015f,.16f}) for(float decay : {.025f,.25f}) {
        float total=start+burst+decay;
        assert(slash_band(float2(40,0),-1,46,13,2,.82,0,1,start,burst,decay)==0);
        assert(slash_band(float2(40,0),total,46,13,2,.82,0,1,start,burst,decay)==0);
        bool visible=false;
        for(int y=-50;y<50;y++) for(int x=-50;x<50;x++)
            visible |= slash_band(float2(x+.5,y+.5),start+burst,46,13,2,.82,0,1,start,burst,decay)>0;
        assert(visible);
    }
    std::cout << "Kernel checks passed; coverage start="<<initial<<" peak="<<broad<<" retract="<<retract<<" last="<<last<<"\n";
}
