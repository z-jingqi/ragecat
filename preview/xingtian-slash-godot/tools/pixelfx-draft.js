// Reference-led primitive draft from the accepted SpriteFusion Slash study.
// MIT Copyright (c) 2026 Hugo Duprez. Original copper adaptation, not a stock effect.
import { fit, smooth, Rng } from '../../core/index.js';
export const meta={name:'Xing Tian reference-led slash',desc:'Tilted warm blade, delayed inner echo and a short dither thread, with optional hit droplets in the native component.',tags:['melee','slash','copper'],size:[180,132],origin:[70,72],duration:0.54,loop:false,fps:60,bg:'dark',options:{palette:['#fff5d9','#ffd494','#ef9954','#c75733','#85312e','#572633','#361f2e'],seed:19}};
export function draw(p,t,o){
 const C=fit(o.palette,7), radius=52, thick=12, onset=.06, hold=.06, duration=.36, sweep=200*Math.PI/180, tilt=-22*Math.PI/180, center=-46*Math.PI/180;
 const c=Math.cos(tilt),s=Math.sin(tilt),fract=x=>x-Math.floor(x),hash=n=>fract(Math.sin(n*127.1+o.seed*9.31)*43758.5453);
 const B=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5],mod=(x,n)=>((x%n)+n)%n;
 const onArc=(r,a)=>[r*Math.cos(a)*c-r*Math.sin(a)*.6*s,r*Math.cos(a)*s+r*Math.sin(a)*.6*c];
 const end=onArc(radius-thick*.3,center+sweep*.5);
 const head=Math.min(1,1-Math.pow(2,-10*Math.max(t,0)/onset));
 if(t>0&&t<.3){const pt=onArc(radius-thick*.3,center-sweep*.5+sweep*head);p.glow(pt[0],pt[1],18,C[2],.16*(1-t/.3));}
 for(const echo of [true,false]){
  const time=t-(echo?.017:0),R=radius*(echo?33/42:1),W=echo?radius*4.5/42:thick,H=hold*(echo?.5:1),trail=(duration-onset-hold)*(echo?5/6:1),total=onset+H+trail;
  const h=time>=onset?1:1-Math.pow(2,-10*Math.max(time,0)/onset),tail=smooth(onset+H,total,time),span=h-tail,start=center-sweep*.5+(echo?sweep*.1:0),length=sweep*(echo?1-.1-.15/3.5:1),age=Math.max(0,Math.min(1,time/total));
  const bound=Math.ceil(R+2);
  for(let y=-bound;y<=bound;y++)for(let x=-bound;x<=bound;x++){
   const px=x+.5,py=y+.5,lx=px*c+py*s,ly=(-px*s+py*c)/.6,dist=Math.hypot(lx,ly);
   if(dist>R+.5||dist<R-W-1)continue;
   const u=mod(Math.atan2(ly,lx)-start,Math.PI*2)/length,dither=B[mod(y,4)*4+mod(x,4)]/16;
   let tone=-1;
   if(time>0&&time<total&&span>.003&&u>=tail&&u<=h){
    const v=(u-tail)/span,w=W*(1-tail*.55)*Math.pow(Math.max(Math.sin(Math.PI*Math.pow(v,2.2)),0),.6),outer=R-.45*hash(Math.floor(u*73))*(echo?.3:1),q=(outer-dist)/Math.max(w,.001);
    if(w>.35&&q>=0&&q<=1&&Math.min(1,v/.4)>dither){const index=q<.22&&age<.5?0:Math.floor(q*(echo?5:6)*.75+age*2.4-v*.8+.9);tone=Math.min(6,Math.max(0,index+(echo?1:0)));}
   }
   const f=.7*(1-Math.min(1,Math.max(0,(time-onset-H)/(trail+.12))));
   if(tone<0&&tail>.02&&u>=0&&u<=tail&&Math.abs(dist-(R-.5))<.55&&f*(.4+.6*u)>dither)tone=5;
   if(tone>=0)p.dot(x,y,C[tone]);
  }
 }
 const gt=t-onset*.6;if(gt>0&&gt<.16){const arm=Math.floor(4*Math.min(1,gt/.025)*(1-gt/.16));p.line(end[0]-arm,end[1],end[0]+arm,end[1],C[1]);p.line(end[0],end[1]-arm,end[0],end[1]+arm,C[1]);p.dot(Math.round(end[0]),Math.round(end[1]),C[0]);}
 const age=t-onset;if(age<=0)return;
 for(const blood of [false,true]){
  const R=new Rng(o.seed+(blood?127:31)),n=blood?9:6,lifeMax=blood?.42:.24,speed=blood?92:76;
  const D=fit(blood?['#722337','#ba2e42']:['#62242c','#cb5c40'],2);
  for(let i=0;i<n;i++){
   const a=tilt+R.range(-.85,.70),sp=speed*R.range(.55,1.15),vx=Math.cos(a)*sp,vy=Math.sin(a)*sp-R.range(5,24),life=lifeMax*R.range(.60,.93),delay=R.range(0,.02),tt=age-delay;
   if(tt<=0||tt>=life)continue;const drag=blood?2:3.2,k=(1-Math.exp(-drag*tt))/drag,px=end[0]+vx*k,py=end[1]+vy*k+(blood?85:45)*tt*tt;
   const dx=vx*Math.exp(-drag*tt),dy=vy*Math.exp(-drag*tt)+(blood?170:90)*tt,mag=Math.hypot(dx,dy),fraction=tt/life,len=(blood?3.8:5.2)*(1-fraction),side=blood&&i%3===0&&fraction<.65?2:1;
   p.line(px-dx/mag*len,py-dy/mag*len,px,py,D[0]);
   for(let y=0;y<side;y++)for(let x=0;x<side;x++)p.dot(Math.floor(px)+x,Math.floor(py)+y,D[fraction>.68||i%3===0?0:1]);
  }
 }
}
