// Crescent taper and sweep adapted from Sprite Fusion slash, MIT, Copyright (c) 2026 Hugo Duprez.
// An original Xing Tian study using PixelFX painter primitives; no stock effect or actor is shipped.
import { fit, smooth, Rng } from '../../core/index.js';
export const meta={name:'Xing Tian copper cut',desc:'A thick chipped copper crescent snaps forward, then sparse dark-red sparks and blood drops settle.',tags:['melee','slash','copper'],size:[180,132],origin:[70,72],duration:0.5,loop:false,fps:60,bg:'dark',options:{palette:['#62242c','#a33c2e','#cc6942','#efb079'],seed:19}};
export function draw(p,t,o){
 const C=fit(o.palette,4), radius=52, thick=16, onset=.05, hold=.035, duration=.25, sweep=148*Math.PI/180, tilt=-12*Math.PI/180;
 const c=Math.cos(tilt),s=Math.sin(tilt),head=t>=onset?1:1-Math.pow(2,-10*Math.max(t,0)/onset),tail=smooth(onset+hold,duration,t),span=head-tail;
 const fract=x=>x-Math.floor(x),hash=n=>fract(Math.sin(n*127.1+o.seed*9.31)*43758.5453);
 if(t>0 && t<duration && span>.003) for(let y=-64;y<64;y++)for(let x=-64;x<64;x++){
  const px=x+.5,py=y+.5,lx=px*c+py*s,ly=(-px*s+py*c)/.78,a=Math.atan2(ly,lx),u=(a+sweep*.5)/sweep;
  if(u<tail||u>head)continue;
  const v=(u-tail)/span,chip=hash(Math.floor((a+Math.PI)*26)),out=radius-1.4*chip,w=thick*(1-tail*.65)*Math.pow(Math.max(Math.sin(Math.PI*Math.pow(v,1.8)),0),.6),q=(out-Math.hypot(lx,ly))/Math.max(w,.001),nick=1.4*(hash(Math.floor((a+Math.PI)*42))-.25);
  if(w<=.4||q<0||q>1-nick/Math.max(w,1))continue;
  const cool=smooth(onset+hold,duration,t);let tone=q<.13&&cool<.35?3:q<.46-cool*.25?2:q<.82-cool*.2?1:0;
  if(q>.7&&chip<.19)tone=0;
  p.dot(x,y,C[tone]);
 }
 const age=t-onset;if(age<=0)return;
 for(const blood of [false,true]){
  const R=new Rng(o.seed+(blood?127:31)),n=blood?9:6,lifeMax=blood?.42:.24,speed=blood?92:76;
  const D=fit(blood?['#722337','#ba2e42']:['#62242c','#cb5c40'],2);
  for(let i=0;i<n;i++){
   const a=tilt+R.range(-.85,.70),sp=speed*R.range(.55,1.15),vx=Math.cos(a)*sp,vy=Math.sin(a)*sp-R.range(5,24),life=lifeMax*R.range(.60,.93),delay=R.range(0,.02),tt=age-delay;
   if(tt<=0||tt>=life)continue;const drag=blood?2:3.2,k=(1-Math.exp(-drag*tt))/drag,px=(radius-thick*.4)*c+vx*k,py=(radius-thick*.4)*s+vy*k+(blood?85:45)*tt*tt;
   const dx=vx*Math.exp(-drag*tt),dy=vy*Math.exp(-drag*tt)+(blood?170:90)*tt,mag=Math.hypot(dx,dy),fraction=tt/life,len=(blood?3.8:5.2)*(1-fraction),side=blood&&i%3===0&&fraction<.65?2:1;
   p.line(px-dx/mag*len,py-dy/mag*len,px,py,D[0]);
   for(let y=0;y<side;y++)for(let x=0;x<side;x++)p.dot(Math.floor(px)+x,Math.floor(py)+y,D[fraction>.68||i%3===0?0:1]);
  }
 }
}
