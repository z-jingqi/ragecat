// Original body-only seam timing study. Render in Patch pixelfx a841596.
// The real Godot preview binds to the user-approved Xing Tian portrait instead of a stock actor.
import { smooth, fit } from '../../core/index.js';
export const meta={name:'Xing Tian body seam timing',desc:'Dark-red chest seams reveal outward; narrow shoulder flow and complete decay, no floor or actor animation.',tags:['status','body','custom'],size:[144,124],origin:[0,0],duration:12,loop:false,fps:30,bg:'dark',options:{palette:['#721622','#c32a37','#f77360'],strength:1}};
const paths=[
 [.08,[[24,30],[28,36],[36,40],[45,41],[53,38],[59,33]]],
 [.15,[[27,43],[34,47],[42,49],[52,46],[58,43]]],
 [.23,[[29,51],[37,55],[44,54],[52,51]]],
 [.28,[[54,19],[57,25],[60,30],[68,35],[76,38],[83,37]]],
 [.46,[[62,16],[70,17],[79,22],[81,28],[80,32]]],
 [.53,[[65,40],[67,46],[73,50],[79,52],[85,51]]],
 [.60,[[70,54],[76,58],[82,59],[89,55]]],
 [.71,[[84,67],[89,71],[90,77],[87,82],[81,81]]],
 [.82,[[78,88],[84,91],[90,89],[92,85]]]
];
export function draw(p,t,o){
 const amount=t<=1||t>=11?0:t<5?smooth(1,5,t):t<7?1:1-smooth(7,11,t),C=fit(o.palette,3);
 if(amount<=0)return;
 for(const [rank,pts] of paths){
  const reveal=smooth(rank-.075,rank+.075,amount)*(.38+amount*.62)*o.strength;
  for(let i=1;i<pts.length;i++){
   const [x0,y0]=pts[i-1],[x1,y1]=pts[i];
   p.line(x0,y0,x1,y1,C[amount>.55?1:0],reveal);
   if(rank>.45&&amount>.62){
    const u=((t*.7+rank*2)%1),x=x0+(x1-x0)*u,y=y0+(y1-y0)*u;
    p.dot(Math.round(x),Math.round(y),C[2],reveal*.42*smooth(.62,1,amount));
   }
  }
 }
}
