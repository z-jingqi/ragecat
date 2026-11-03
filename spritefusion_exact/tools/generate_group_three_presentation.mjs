// Original TS oracle for the official shared Frame presentation contract.
import fs from 'node:fs';import path from 'node:path';import{pathToFileURL}from'node:url';import{createHash}from'node:crypto';
const [source,casesFile,output]=process.argv.slice(2);if(!output)throw Error('sources cases.json output-dir');fs.mkdirSync(output,{recursive:true});
const selected=new Set(Array.from({length:61},(_,i)=>i*3));const actorData=new Uint32Array(512);
for(let y=0;y<32;y++)for(let x=0;x<16;x++){const head=y>=1&&y<8&&x>=5&&x<11,body=y>=8&&y<22&&x>=4&&x<12,arms=y>=11&&y<17&&x>=1&&x<15,legs=y>=22&&y<31&&((x>=3&&x<6)||(x>=10&&x<13));if(head||body||arms||legs)actorData[y*16+x]=(head?0xff75bdff:legs?0xff795433:0xffd6a54e)>>>0;}
const digest=data=>createHash('sha256').update(Buffer.from(data.buffer)).digest('hex');
for(const c of JSON.parse(fs.readFileSync(casesFile,'utf8'))){const module=(await import(pathToFileURL(path.join(source,c.slug+'.ts')))).default;let n=0,index=0;const live=[],calls=c.calls??[{at:0}],rows=[];const actor={feet:()=>[160,300],head:()=>[160,238]};
const f={w:320,h:200,ox:0,oy:0,color:new Uint32Array(64000),light:new Uint32Array(64000)};
function spawn(){while(index<calls.length&&calls[index].at<=n/60+1e-12){const o={...c.options,...calls[index].options};if(o.actor===true)o.actor=actor;o.shake=()=>{};live.push(module(o));index++;}}
function draw(){f.color.fill(0);f.light.fill(0);for(const fx of live)fx.draw(f,'back');if(c.options.actor)for(let y=0;y<32;y++)for(let x=0;x<16;x++){const word=actorData[y*16+x];if(word>>>24)f.color[(118+y)*320+72+x]=word;}for(const fx of live)fx.draw(f,'front');}
spawn();for(let k=0;k<(c.warmup??0);k++){for(const fx of live)fx.update(1/60);draw();}
for(n=0;n<=180;n++){if(n){spawn();if(n===c.stopFrame)for(const fx of live)fx.stop?.();for(const fx of live)fx.update(1/60);}draw();if(selected.has(n))rows.push({frame:n,color:digest(f.color),light:digest(f.light)});}
fs.writeFileSync(path.join(output,c.id+'.json'),JSON.stringify({id:c.id,slug:c.slug,source:'Original TypeScript; shared Frame: back draw, opaque synthetic actor color blit, front draw. Combined light then combined color.',rows},null,2)+'\n');console.log(c.id,rows.length*2,'combined hashes');}
