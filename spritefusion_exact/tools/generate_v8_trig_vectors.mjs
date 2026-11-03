#!/usr/bin/env node
// V8 numerical output is stored as IEEE754 bytes, never decimal JSON numbers.
import fs from 'node:fs';
import {writeVectors} from './write_vector_chunks.mjs';
import path from 'node:path';
const target = process.argv[2] ?? path.resolve(import.meta.dirname, '../godot/tests/core/v8_trig_vectors.json');
const hex = x => { const b=Buffer.alloc(8); b.writeDoubleLE(x); return b.toString('hex'); };
const value = h => Buffer.from(h,'hex').readDoubleLE();
let seed=0xa1972e61;
const u32 = () => { seed^=seed<<13; seed^=seed>>>17; seed^=seed<<5; return seed>>>0; };
const inputs = [0,-0,NaN,Infinity,-Infinity,Number.MIN_VALUE,-Number.MIN_VALUE,Number.MAX_VALUE,-Number.MAX_VALUE,1e300,-1e300,Math.PI,-Math.PI,0.29011028540118844];
function adjacent(x,direction) { const b=Buffer.alloc(8); b.writeDoubleLE(x); let word=b.readBigUInt64LE(); word += BigInt(direction); b.writeBigUInt64LE(word); return b.readDoubleLE(); }
// Uniform binary64 bit patterns exercise every exponent and the large reducer.
for(let i=0;i<8192;i++){ const b=Buffer.alloc(8);b.writeUInt32LE(u32(),0);b.writeUInt32LE(u32(),4);inputs.push(b.readDoubleLE()); }
// Typical effect angles plus medium-range reduction.
for(let i=0;i<8192;i++) inputs.push((u32()/4294967296*2-1)*1e6);
// Near every argument-reduction boundary, both directions and both signs.
for(const x of [0.3,0.4375,0.5,0.6875,0.78125,Math.PI/4,Math.PI/2,Math.PI*3/4,Math.PI,Math.PI*1.5,Math.PI*2,2**-27,2**-24,2**19*Math.PI/2])
 for(const sign of [-1,1]) for(let delta=-3;delta<=3;delta++) inputs.push(adjacent(sign*x,delta));
for(let i=0;i<4096;i++) { const n = u32()%1048576; const x=n*Math.PI/2; inputs.push(x,adjacent(x,-1),adjacent(x,1),-x); }
inputs.push(value('f21f02bb2a91d23f')); // Black-hole frame55: native sin changes alpha255 to254.
const seen=new Set();
const cases=[];
for(const x of inputs) {const a=hex(x);if(seen.has(a))continue;seen.add(a);cases.push({a,sin:hex(Math.sin(x)),cos:hex(Math.cos(x))});}
writeVectors(target,JSON.stringify({schema:1,node:process.version,v8:process.versions.v8,seed:'0xa1972e61',source:'https://raw.githubusercontent.com/v8/v8/13.6.233/src/base/ieee754.cc',cases}));
console.log(`Wrote ${cases.length} binary64 sin/cos vectors: ${target}`);
