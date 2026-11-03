#!/usr/bin/env node
// Executes ORIGINAL TypeScript helpers via Node's built-in erasable TS support.
// Never computes expected results using the Godot port or a reimplementation.
import fs from 'node:fs';
import {writeVectors} from './write_vector_chunks.mjs';
import path from 'node:path';
import crypto from 'node:crypto';
import { stripTypeScriptTypes } from 'node:module';
const sourceDir = process.argv[2] ?? path.resolve(import.meta.dirname, '../source');
const output = process.argv[3] ?? path.resolve(import.meta.dirname, '../godot/tests/core/core_vectors.json');
const names = fs.readdirSync(sourceDir).filter(s => s.endsWith('.ts') && !s.includes('.download.')).sort();
function load(name) {
  const text = fs.readFileSync(path.join(sourceDir, name), 'utf8');
  const js = stripTypeScriptTypes(text.replace('export default function', 'function').replace(/^export (?=(?:async )?function|const|let|class)/gm, ''), { mode: 'strip' });
  const helpers = new Function(`${js};return {Px,Rng:typeof Rng==='function'?Rng:null,rgb:typeof rgb==='function'?rgb:null,hex:typeof hex==='function'?hex:null,mix:typeof mix==='function'?mix:null,hash: typeof hash==='function'?hash:null, noise: typeof noise==='function'?noise:null, bayer:typeof bayer==='function'?bayer:null};`)();
  return {text, ...helpers};
}
const oracle=load('explosion.ts');
const f64hex=n=>{const b=Buffer.alloc(8);b.writeDoubleLE(n);return b.toString('hex');};
const seeds=[0,1,2,3,37,12345,-1,2147483648,4294967295,4294967296,4294967297,9007199254740991];
const rng = seeds.map(seed => { const r = new oracle.Rng(seed); const words=Array.from({length:1024},()=>r.next()*4294967296); return {seed,words,state:r.s}; });
const rngMethods = seeds.map(seed => {
 const r=new oracle.Rng(seed), operations=[];
 const ops=[['range',-7.25,49.875],['int',-5,9],['chance',0],['chance',1],['chance',0.3],['sign'],['pick',[1,9,25,77]],['next']];
 for(let repeat=0;repeat<16;repeat++) for(const op of ops){const expected=r[op[0]](...op.slice(1));operations.push({op,expected,expected_bits:typeof expected==='number'?f64hex(expected):'',state:r.s});}
 return {seed,operations};
});
const numeric = [];
for (const n of [-9007199254740991,-4294967297,-4294967296,-2147483648,-123.9,-1,-0.5,0,0.5,1,1.99,255.9,2147483647,2147483648,4294967295,4294967296,4294967297,9007199254740991]) {
  numeric.push({n,u32:n>>>0,i32:n|0,round:Math.round(n),shifts:[0,1,7,15,24,31,32,-1].map(b=>[b,n>>>b,n<<b])});
}
const products=[];
for (const a of [-4294967297,-2147483648,-123.9,-1,0,1,37,65535,65536,2147483647,2147483648,2654435761,4294967295,9007199254740991])
  for (const b of [-1,1,61,65535,65536,2147483647,2654435761,4294967295]) products.push([a,b,Math.imul(a,b)]);
const colors=[];
for (const channels of [[0,0,0,0],[255,128,1,255],[255.9,1.1,-0.9,127.5],[-1,256,257,512],[1000,-1000,2147483648,-1]]) colors.push({channels,value:oracle.rgb(...channels)>>>0});
const mixes=[];
for (const a of [0,0xff0a64ff,0x80ffd011,0xffffffff]) for (const b of [0,0xffaabbcc,0xffffffff]) for(const t of [-0.25,0,0.1,0.5,0.9999,1,1.25]) mixes.push([a,b,t,oracle.mix(a,b,t)>>>0]);
const hashes=[];
for(const n of [-10000.75,-2,-1,0,0.5,1,123.456,10000.75]) for(const k of [-3.5,0,1,7.9,100.25]) hashes.push([n,k,oracle.hash(n,k),load('muzzle-flash.ts').hash(n,k)]);
const noise=[];
for(const x of [-20.5,-2,-1.75,-0.5,0,0.01,0.5,1,10.25,100.99]) for(const seed of [0,1,2.5,70]) noise.push([x,seed,load('fire.ts').noise(x,seed),f64hex(x),f64hex(seed),f64hex(load('fire.ts').noise(x,seed))]);
const pixels=[];
for(const name of names) {
  const src=load(name);
  for(const origin of [[0,0],[-3,-4],[0.5,-1.25]]) {
    const f={w:17,h:13,ox:origin[0],oy:origin[1]};
    const data=new Uint32Array(f.w*f.h);
    const p=new src.Px(f,data);
    const ops=[];
    const base=[['set',-0.5,-0.5,0xffcc8844],['set',0.5,1.75,0x88776655],['set',16.99,12.99,0xff121314],['set',17,13,0xff000000],['blend',0.5,1.75,0xffabcdef,0.4],['blend',2.2,3.1,0x00112233,0.73],['blend',2.2,3.1,0xff995511,0.27],['add',4.5,5.5,0xffccddee,0.63],['add',5,6,0xff123456,1.7],['disc',4.5,6.25,3.6,0xff1234de],['disc',-0.5,2.5,0.5,0xffabcdef],['alphaDisc',4,5,2.2,0xffab7c02,0.39],['ring',10.25,4.75,3.5,1.4,0xff679ace,0.42],['line',-3.5,10.5,18.5,2.5,0xff5566ff],['glow',8.75,6.25,7.4,0xff874dcd,0.79],['glow',-1.5,-0.5,5.2,0xffee9f23,0.33]];
    if(name==='fire.ts') base.push(['disc',8,8,2.4,0xffaabbcc,0.27],['glow',2,2,4.9,0xffcc55aa,0.75]);
    for(const op of base) if(typeof p[op[0]]==='function') {p[op[0]](...op.slice(1));ops.push({op,expected:[...data]});}
    pixels.push({source:name,source_sha256:crypto.createHash('sha256').update(src.text).digest('hex'),frame:f,ops});
  }
}
const result={schema:1,description:'Original Sprite Fusion TS helper outputs. JS Uint32Array words are unsigned ABGR; 25 source variants, 3 origins each.',rng,rngMethods,numeric,products,colors,mixes,hashes,noise,pixels};
writeVectors(output, JSON.stringify(result));
console.log(`Wrote ${output}: ${pixels.length} pixel cases, ${pixels.reduce((n,c)=>n+c.ops.length,0)} raster snapshots, ${rng.length*1024} RNG words.`);
