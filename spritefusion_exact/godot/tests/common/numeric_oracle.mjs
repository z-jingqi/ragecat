import fs from 'node:fs';
const hex=x=>{const b=Buffer.alloc(8); b.writeDoubleLE(x); return b.toString('hex')};
let s=42;const rand=()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296};
const cases=[];
const special=[0,-0,NaN,Infinity,-Infinity,1,-1,.5,-.5,1.5,-1.5,4294967295,4294967296,4294967297,-4294967297,9007199254740991,-9007199254740991,2147483648,-2147483648,2**54];
for(let i=0;i<4000;i++){
 const a=i<special.length?special[i]:(rand()-.5)*(i%3?1e14:1e3),b=i<special.length?special.at(-i-1):(rand()-.5)*1e12;
 cases.push({a:hex(a),b:hex(b),u:a>>>0,i:a|0,m:Math.imul(a,b),sh:a>>>b,round:hex(Math.round(a)),rem:hex(a%b)});
}
fs.writeFileSync(new URL('./numeric_cases.json',import.meta.url),JSON.stringify(cases));
