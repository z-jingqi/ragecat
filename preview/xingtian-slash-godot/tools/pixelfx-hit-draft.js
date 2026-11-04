// Compact original copper contact study using the accepted Sprite Fusion Impact/Blood methods.
// MIT License, Copyright (c) 2026 Hugo Duprez; PixelFX primitives MIT 2026 Patch.
import { fit, Rng } from '../../core/index.js';
export const meta={name:'Xing Tian copper impact',desc:'Two-beat contact star detaches into four copper fragments; sparse short blood follows the blow. No actor or game hooks.',tags:['impact','melee','copper'],size:[96,80],origin:[40,42],duration:.48,loop:false,fps:60,bg:'dark',options:{palette:['#85312e','#c75733','#ef9954','#ffd494','#fff5d9'],seed:19,blood:true}};
const B=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5],wrap=a=>Math.atan2(Math.sin(a),Math.cos(a)),mod=(x,n)=>(x%n+n)%n;
export function draw(p,t,o){
 if(t<=0||t>=.48)return;
 const D=fit(["#722337","#ba2e42"],2),C=fit(o.palette,5).slice().reverse(),R=new Rng(o.seed+419),spokes=[];
 for(let i=0;i<6;i++){const a=i*Math.PI/3+R.range(-.09,.09);spokes.push({a,L:12*(1+.35*Math.max(0,Math.cos(a)))*R.range(.8,1),w:R.range(1.35,1.85)});}
 const second=t>.02,core=t<=.04,tail=Math.max(0,Math.min(1,(t-.04)/.12)),tilt=-22*Math.PI/180;
 if(t<.16)for(let y=-30;y<30;y++)for(let x=-30;x<30;x++){
  const px=(x+.5)*Math.cos(tilt)+(y+.5)*Math.sin(tilt),py=-(x+.5)*Math.sin(tilt)+(y+.5)*Math.cos(tilt),r=Math.hypot(px,py),a=Math.atan2(py,px);let tone=-1;
  if(core){for(const s of spokes){const lx=px*Math.cos(s.a)+py*Math.sin(s.a),ly=-px*Math.sin(s.a)+py*Math.cos(s.a),L=s.L*(second?1.22:1);if(lx<0||lx>L)continue;const w=s.w*(second?.55:1)*(1-lx/L)*Math.min(1,.45+lx/2),d=Math.abs(ly);if(d<=w+(second?.32:.65)){let shade=d>w?4:second?2:1;if(d<w*.4&&lx<L*.5)shade=second?1:0;tone=tone<0?shade:Math.min(tone,shade);}}if(r<=1.7)tone=second?1:0;
  }else if((B[mod(y,4)*4+mod(x,4)]+.5)/16<=Math.pow(1-tail,.65)){
   for(const i of [0,1,3,5]){const s=spokes[i],d=s.L*(.68+tail*.95),da=Math.abs(wrap(a-s.a)),span=.28*(1-tail*.5),w=1.35*(1-tail*.55)*(1-da/span);if(da<span&&Math.abs(r-d)<Math.max(.25,w))tone=tail<.35?2:tail<.7?3:4;}
   const rr=12*(.45+.7*(1-Math.pow(1-tail,3)));if((Math.abs(a)<.62||Math.abs(wrap(a-Math.PI))<.32)&&Math.abs(r-rr)<.55*(1-tail*.4))tone=tail<.5?3:4;
  }if(tone>=0)p.dot(x,y,C[tone]);
 }
 for(const blood of [false,true]){
  if(blood&&!o.blood)continue;const rng=new Rng(o.seed+(blood?127:31)),n=blood?9:6;
  for(let i=0;i<n;i++){const a=tilt+rng.range(-.85,.70),sp=(blood?92:76)*rng.range(.55,1.15),vx=Math.cos(a)*sp,vy=Math.sin(a)*sp-rng.range(5,24),life=(blood?.42:.24)*rng.range(.60,.93),tt=t-rng.range(0,.02);if(tt<=0||tt>=life)continue;const drag=blood?2:3.2,k=(1-Math.exp(-drag*tt))/drag,xx=vx*k,yy=vy*k+(blood?85:45)*tt*tt,dx=vx*Math.exp(-drag*tt),dy=vy*Math.exp(-drag*tt)+(blood?170:90)*tt,m=Math.hypot(dx,dy),age=tt/life,len=(blood?3.8:5.2)*(1-age);p.line(xx-dx/m*len,yy-dy/m*len,xx,yy,blood?D[0]:C[4]);p.dot(Math.floor(xx),Math.floor(yy),blood?D[1]:C[age<.2?1:age<.48?2:3]);}
 }
 if(o.blood&&t<.075){const R=new Rng(o.seed+227),head=1-Math.pow(1-Math.min(1,t/.035),3),tail=Math.max(0,Math.min(1,(t-.025)/.05));for(let i=0;i<3;i++){const a=tilt-.45+i*.45+R.range(-.08,.08),L=R.range(7,12);for(let d=Math.ceil(L*tail);d<Math.ceil(L*head);d++)p.dot(Math.floor(Math.cos(a)*d),Math.floor(Math.sin(a)*d),d<L*.35?D[0]:D[1]);}}
}
