shader_type canvas_item;
render_mode unshaded;
uniform float u_age=-1.0;
uniform float u_extent=128.0;
uniform int u_count=5;
uniform float u_spacing=12.0;
uniform float u_height=34.0;
uniform float u_width=5.0;
uniform float u_grow=.14;
uniform float u_hold=.28;
uniform float u_shatter=.38;
uniform float u_stagger=.055;
uniform float u_speed=42.0;
uniform float u_angle=0.0;
uniform float u_seed=19.0;
uniform float u_irregularity=.75;
uniform vec4 u_light:source_color=vec4(.91,1.,1.,1.);
uniform vec4 u_body:source_color=vec4(.51,.85,.94,1.);
uniform vec4 u_shade:source_color=vec4(.25,.53,.73,1.);
uniform vec4 u_dark:source_color=vec4(.15,.3,.53,1.);
float hash(float n){return fract(sin(n*127.1+u_seed*31.7)*43758.5453);}
vec2 rot(vec2 p,float a){return vec2(cos(a)*p.x-sin(a)*p.y,sin(a)*p.x+cos(a)*p.y);}
float cross2(vec2 a,vec2 b){return a.x*b.y-a.y*b.x;}
bool tri(vec2 p,vec2 a,vec2 b,vec2 c){if(abs(cross2(b-a,c-a))<.0001)return false;float x=cross2(b-a,p-a);float y=cross2(c-b,p-b);float z=cross2(a-c,p-c);return (x>=0.&&y>=0.&&z>=0.)||(x<=0.&&y<=0.&&z<=0.);}
void fragment(){
 vec2 p=floor((UV*2.-1.)*u_extent)+vec2(.5); vec4 col=vec4(0.);
 if(u_age>=0.){
 float maxx=float(u_count-1)*u_spacing*.5;
 float travel=clamp(u_age/max(.06,float(u_count-1)*u_stagger+u_grow),0.,1.);
 if(abs(p.y)<1.&&p.x>=-maxx-4.&&p.x< mix(-maxx-4.,maxx+4.,travel)&&u_age<u_grow+u_hold+float(u_count-1)*u_stagger)col=u_shade;
 for(int i=0;i<7;i++){
  if(i>=u_count)break;
  float t=u_age-float(i)*u_stagger; float life=u_grow+u_hold+u_shatter;
  if(t<0.||t>=life)continue;
  float irregular=u_irregularity;
  float h=u_height*mix(1.,.58+.42*hash(float(i)+2.),irregular);
  float w=u_width*mix(1.,.66+.54*hash(float(i)+8.),irregular);
  vec2 base=vec2((float(i)-float(u_count-1)*.5)*u_spacing+irregular*(hash(float(i)+17.)-.5)*u_spacing*.32,0.);
  float g=1.-pow(1.-clamp(t/u_grow,0.,1.),3.);
  float bt=max(0.,t-u_grow-u_hold);float f=clamp(bt/u_shatter,0.,1.);
  // Main prism and a short attached crystal: different axes and unequal shoulders.
  for(int cluster=0;cluster<2;cluster++){
   float id=float(i*17+cluster*53);
   float hh=h*(cluster==0?1.:.32+.18*hash(id+4.));
   float ww=w*(cluster==0?1.:.48);
   float lean=irregular*(hash(id+6.)-.5)*.38;
   if(cluster==1)lean=(hash(id+7.)>.5?1.:-1.)*(.4+.24*irregular);
   vec2 origin=base+vec2(cluster==0?0.:w*(hash(id+7.)>.5?1.:-1.)*.85,0.);
   vec2 v[6];
   v[0]=vec2(-ww,0.);
   v[1]=vec2(-ww*(.65+.25*hash(id+9.)),-hh*(.35+.2*hash(id+10.))*g);
   v[2]=vec2(-ww*.32+hh*lean*.65,-hh*(.77+.12*hash(id+11.))*g);
   v[3]=vec2(hh*lean,-hh*g);
   v[4]=vec2(ww*(.5+.4*hash(id+12.))+hh*lean*.5,-hh*(.37+.32*hash(id+13.))*g);
   v[5]=vec2(ww,0.);
   vec2 center=vec2(ww*(hash(id+14.)-.5)*.65+hh*lean*.35,-hh*(.32+.19*hash(id+15.))*g);
   for(int j=0;j<6;j++){
    vec2 a=v[j];vec2 b=v[(j+1)%6];vec2 pivot=(a+b+center)/3.;
    float r=hash(id+float(j)+29.);
    vec2 velocity=vec2((r-.5)*u_speed*1.7,-u_speed*(.35+.45*hash(id+float(j)+91.)));
    vec2 shift=velocity*bt+vec2(0.,100.*bt*bt);
    float spin=(r-.5)*bt*5.;float shrink=1.-smoothstep(.55,1.,f);
    vec2 q=rot(p-origin,-u_angle)-shift;
    a=pivot+rot((a-pivot)*shrink,spin);b=pivot+rot((b-pivot)*shrink,spin);vec2 c=pivot+rot((center-pivot)*shrink,spin);
    if(tri(q,a,b,c)){
     col=j==0?u_shade:(j==1?u_body:(j==2?u_light:(j==3?u_body:(j==4?u_shade:u_dark))));
     // Refracture detail lives in original facet coordinates, so it travels with the shard.
     vec2 local=pivot+rot(q-pivot,-spin)/max(.001,shrink);
     float depth=-local.y/max(1.,hh*g);
     float ridge=local.x-hh*lean*depth;
     float seam=abs(ridge-ww*(.08+.15*sin(depth*9.+id)));
     if(seam<.53&&depth>.16&&depth<.86&&j<4)col=u_light;
     float cut=local.y+hh*g*(.3+.23*hash(id+22.))+local.x*(1.2+.5*hash(id+23.));
     if(abs(cut)<.58&&j!=2&&depth>.2&&depth<.75)col=u_shade;
     float glint=local.y+hh*g*.72+local.x*.6;
     if(abs(glint)<.65&&ridge<ww*.25&&depth>.45&&j<4)col=u_light;
    }
   }
  }
  // A few 1px frost chips erupt with each crystal, then fall and retire.
  for(int k=0;k<3;k++){
   float a=hash(float(i*3+k)+131.)*3.14159;
   vec2 cp=base+vec2(cos(a)*18.*t,-sin(a)*27.*t+60.*t*t);
   if(t<.24&&max(abs(p.x-cp.x),abs(p.y-cp.y))<.65)col=u_body;
  }
 }
 }
 COLOR=col;
}
