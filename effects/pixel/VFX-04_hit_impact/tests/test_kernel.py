#!/usr/bin/env python3
"""Compile the actual pure-math kernel with a tiny host float2 shim; no engine emulation claim."""
from pathlib import Path
import subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
PRELUDE = r'''
#include <cmath>
#include <iostream>
#include <algorithm>
#include <cstdint>
#include <cstdlib>
float max(float a,float b) { return std::max(a,b); }
float min(float a,float b) { return std::min(a,b); }
float clamp(float x,float a,float b) { return max(a,min(b,x)); }
struct float2 {
 float x,y;
 float2(float a,float b):x(a),y(b){}
 float2 operator/(float v) const { return {x/v,y/v}; }
 float2& operator/=(float v) { x/=v;y/=v;return *this; }
 float2 operator-(float2 v) const {return {x-v.x,y-v.y};}
};
float length(float2 p) { return std::sqrt(p.x*p.x+p.y*p.y); }
'''
TESTS = r'''
int checks=0;
void check(bool ok,const char* msg) { checks++; if(!ok) {std::cerr<<"FAIL "<<msg<<"\n";std::exit(1);} }
struct Config {float size=1,core=6,count=5,len=8,spread=125*3.14159265f/180,speed=78,duration=.2f,seed=23,shock=0;};
float sample(int x,int y,float age,Config c,float angle=0) {
 return impactSample(impactRotate(float2(x+.5f,y+.5f),angle),age,c.duration,c.size,c.core,c.count,c.len,c.spread,c.speed,c.seed,c.shock);
}
std::uint64_t hash(float age,Config c,float angle=0) {
 std::uint64_t h=1469598103934665603ULL;
 for(int y=-64;y<64;y++) for(int x=-64;x<64;x++) {h^=int(sample(x,y,age,c,angle));h*=1099511628211ULL;}
 return h;
}
int coverage(float age,Config c) {int n=0;for(int y=-64;y<64;y++)for(int x=-64;x<64;x++)n+=sample(x,y,age,c)>0;return n;}
int main() {
 Config c;
 check(coverage(-.01,c)==0,"negative age clear");
 check(coverage(0,c)>0,"instant readable onset");
 check(coverage(c.duration,c)==0,"exact end clear");
 check(coverage(5,c)==0,"late age clear");
 check(coverage(.02,c)>coverage(.18,c),"strong early peak / reduced tail");
 auto h=hash(.04,c);
 check(h==hash(.04,c),"fixed seed repeatable");
 c.seed=24;check(h!=hash(.04,c),"seed changes arrangement");c.seed=23;
 check(h!=hash(.04,c,1.5707963f),"incoming direction rotates shape");
 for(float angle:{0.f,.3f,1.5707963f,3.14159265f})
  for(float t:{0.f,.02f,.06f,.10f,.15f,.199f,.2f})
   for(int y=-64;y<64;y++)for(int x=-64;x<64;x++) {
    float v=sample(x,y,t,c,angle);
    if(v!=0&&v!=1&&v!=2&&v!=3) { check(false,"discrete mask bands"); }
   }
 check(true,"discrete mask bands at directions/ages");
 Config largest; largest.size=2;largest.core=12;largest.count=8;largest.len=20;largest.speed=180;largest.duration=.5;largest.shock=1;
 int e=int(std::ceil(largest.size*(largest.core*2+largest.speed*largest.duration+largest.len*1.2+4)));
 for(int f=0;f<=60;f++)for(float a:{0.f,.785398f,1.570796f})for(int i=-e;i<=e;i++){
  float t=f/120.f;
  check(sample(e,i,t,largest,a)==0&&sample(-e,i,t,largest,a)==0&&sample(i,e,t,largest,a)==0&&sample(i,-e,t,largest,a)==0,"maximum bound stays clear");
 }
 c.count=0;check(coverage(.02,c)>0,"zero shards keeps core");check(coverage(.15,c)==0,"zero shards has no hidden particles");
 std::cout<<"PASS: actual shared kernel "<<checks<<" checks; binary palette mask; stable seed; directional shape; conservative extreme bounds\n";
}
'''
with tempfile.TemporaryDirectory(prefix='impact-kernel-') as d:
    path=Path(d)/'test.cpp'; exe=Path(d)/'test'
    path.write_text(PRELUDE + '\n' + (ROOT/'src/shared/ImpactKernel.hlsl').read_text() + '\n' + TESTS)
    subprocess.run(['g++','-std=c++17','-O2',str(path),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
