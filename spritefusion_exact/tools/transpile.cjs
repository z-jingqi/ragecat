#!/usr/bin/env node
// Offline TypeScript AST -> native GDScript translator for the MIT Sprite Fusion sources.
// This is an authoring tool only. No JavaScript/TypeScript runtime is used by Godot.
const ts = require('typescript'), fs=require('fs'), path=require('path');
const input=process.argv[2], output=process.argv[3];
if(!input||!output) throw Error('Usage: node transpile.cjs INPUT.ts OUTPUT.gd');
const slug=path.basename(input).replace(/\.ts$/,'');
const ROOT='SFExact'+slug.split(/[-_]/).map(s=>s[0].toUpperCase()+s.slice(1)).join('');
const program=ts.createProgram([input],{target:ts.ScriptTarget.ES2022,noLib:true});
const checker=program.getTypeChecker(), src=program.getSourceFile(input);
const F=new Map(), B=new Map(), globals=new Map(); let seq=0, tmp=0;
const isFn=n=>ts.isFunctionDeclaration(n)||ts.isArrowFunction(n)||ts.isFunctionExpression(n)||ts.isMethodDeclaration(n)||ts.isConstructorDeclaration(n)||ts.isGetAccessor(n);
const safe=s=>s.replace(/[^A-Za-z0-9_]/g,'_');
function sym(n){if(ts.isIdentifier(n)&&ts.isShorthandPropertyAssignment(n.parent))return checker.getShorthandAssignmentValueSymbol(n.parent);return checker.getSymbolAtLocation(n)}
function binding(n,owner,kind='local'){
 if(ts.isIdentifier(n)){const s=sym(n); if(s&&!B.has(s)) B.set(s,{s,name:n.text,id:++seq,owner,kind,cap:false});return;}
 if(ts.isBindingPattern(n))for(const el of n.elements)if(ts.isBindingElement(el))binding(el.name,owner,kind);
}
function scan(n,owner=null,cls=null){
 if(isFn(n)){const f={id:++seq,node:n,parent:owner,cls,bindings:[],fnDecls:[]};F.set(n,f);if(ts.isFunctionDeclaration(n)&&n.name)binding(n.name,owner,owner?'local':'function');owner=f;for(const p of n.parameters)binding(p.name,owner);}
 if(ts.isClassDeclaration(n)){binding(n.name,null,'class');cls=n;}
 if(ts.isVariableDeclaration(n))binding(n.name,owner,owner?'local':'global');
 if(ts.isPropertyDeclaration(n)&&n.name&&ts.isIdentifier(n.name))binding(n.name,null,'field');
 ts.forEachChild(n,c=>scan(c,owner,cls));
}
scan(src);
for(const b of B.values()){if(b.owner)b.owner.bindings.push(b);else if(b.kind==='global'||b.kind==='function'||b.kind==='class')globals.set(b.name,b);}
function scanRefs(n,owner=null){
 if(isFn(n))owner=F.get(n);
 if(ts.isIdentifier(n)) {const b=B.get(sym(n));if(b&&b.owner&&owner!==b.owner)b.cap=true;}
 if(ts.isBinaryExpression(n)&&n.operatorToken.kind>=ts.SyntaxKind.FirstAssignment&&n.operatorToken.kind<=ts.SyntaxKind.LastAssignment&&ts.isIdentifier(n.left)){
  let p=n.parent;while(ts.isParenthesizedExpression(p))p=p.parent;
  if(!ts.isExpressionStatement(p)){const b=B.get(sym(n.left));if(b)b.cap=true;}
 }
 ts.forEachChild(n,c=>scanRefs(c,owner));
}
scanRefs(src);
function bname(b){if(b.kind==='global')return ROOT+'._g_'+safe(b.name);if(b.kind==='function')return ROOT+'._f_'+safe(b.name);if(b.kind==='class')return ROOT+'.C_'+safe(b.name);if(b.kind==='field')return '_sf_f_'+safe(b.name);if(b.cap)return `_cap${b.owner.id}[${JSON.stringify(b.name+'_'+b.id)}]`;return '_v_'+safe(b.name)+'_'+b.id;}
const J=ROOT+'.JS';
class Ctx{constructor(f=null,indent=0,out=[]){this.f=f;this.indent=indent;this.out=out;this.loop=[];this.switches=0;} line(s){this.out.push('\t'.repeat(this.indent)+s)} child(){let c=new Ctx(this.f,this.indent+1,this.out);c.loop=[...this.loop];c.switches=this.switches;return c;} temp(code){let n='_tmp'+(++tmp);this.line('var '+n+' = '+code);return n;}}
function fail(n,msg){const pos=src.getLineAndCharacterOfPosition(n.pos);throw Error(`${slug}:${pos.line+1}: ${msg||ts.SyntaxKind[n.kind]}: ${n.getText(src).slice(0,160)}`)}
function id(n){if(n.text==='undefined'||n.text==='null')return 'null';if(n.text==='Infinity')return 'INF';if(n.text==='NaN')return 'NAN';const b=B.get(sym(n));if(b)return bname(b);if(n.text==='console')return 'null';return '_unknown_'+safe(n.text);}
function classMember(p){const s=sym(p.name);return s?.declarations?.find(d=>(ts.isMethodDeclaration(d)||ts.isPropertyDeclaration(d)||ts.isGetAccessor(d))&&ts.isClassDeclaration(d.parent));}
function propKey(n,c){return ts.isIdentifier(n)||ts.isStringLiteral(n)?JSON.stringify(n.text):E(n,c)}
function lhs(n,c){while(ts.isParenthesizedExpression(n)||ts.isNonNullExpression(n))n=n.expression;if(ts.isIdentifier(n))return {code:id(n),b:B.get(sym(n))};if(ts.isPropertyAccessExpression(n))return {obj:E(n.expression,c),key:JSON.stringify(n.name.text)};if(ts.isElementAccessExpression(n))return {obj:E(n.expression,c),key:E(n.argumentExpression,c)};fail(n,'Assignment target');}
function assign(n,r,c,op='='){
 if(ts.isArrayLiteralExpression(n)){const a=c.temp(r);for(let i=0;i<n.elements.length;i++){const el=n.elements[i];if(el.kind===ts.SyntaxKind.OmittedExpression)continue;c.line(assign(el,J+'.getv('+a+', '+i+')',c));}return a;}
 const l=lhs(n,c);if(op!=='='){const v=l.code??`${J}.getv(${l.obj}, ${l.key})`;r=bin(op.slice(0,-1),v,r);}
 if(l.code){if(l.b?.cap)return `${J}.setv(_cap${l.b.owner.id}, ${JSON.stringify(l.b.name+'_'+l.b.id)}, ${r})`;c.line(l.code+' = '+r);return l.code;}
 return `${J}.setv(${l.obj}, ${l.key}, ${r})`;
}
function bin(op,a,b){
 const bits={'>>>':'ushr','>>':'shr','<<':'shl','&':'band','|':'bor','^':'bxor'};
 if(bits[op])return `${J}.${bits[op]}(${a}, ${b})`;
 if(op==='%')return `${J}.opmod(${a}, ${b})`;
 if(op==='**')return `pow(${a}, ${b})`;
 op=({'===':'==','!==':'!=','==':'==','!=':'!='}[op]||op);
 return `(${a} ${op} ${b})`;
}
function E(n,c){
 if(!n)return 'null';
 if(ts.isIdentifier(n))return id(n);
 if(ts.isNumericLiteral(n)){const v=Number(n.text);return Number.isInteger(v)?v+'.0':String(v);}
 if(ts.isStringLiteral(n)||ts.isNoSubstitutionTemplateLiteral(n))return JSON.stringify(n.text);
 if(n.kind===ts.SyntaxKind.TrueKeyword)return 'true';if(n.kind===ts.SyntaxKind.FalseKeyword)return 'false';if(n.kind===ts.SyntaxKind.NullKeyword)return 'null';if(n.kind===ts.SyntaxKind.ThisKeyword)return 'self';
 if(ts.isParenthesizedExpression(n)||ts.isNonNullExpression(n)||ts.isAsExpression(n)||ts.isTypeAssertionExpression(n))return E(n.expression,c);
 if(ts.isTypeOfExpression(n))return `${J}.typeofv(${E(n.expression,c)})`;
 if(ts.isVoidExpression(n)){c.line(E(n.expression,c));return 'null';}
 if(ts.isPropertyAccessExpression(n)){
  if(ts.isIdentifier(n.expression)&&n.expression.text==='Math'){return ({PI:'PI',E:'exp(1.0)',SQRT2:'sqrt(2.0)'}[n.name.text]||fail(n,'Math property'));}
  if(n.expression.kind===ts.SyntaxKind.ThisKeyword)return 'self._sf_f_'+safe(n.name.text);if(process.argv.includes('--direct-members')){const m=classMember(n);if(m)return E(n.expression,c)+'.'+(ts.isMethodDeclaration(m)?'_sf_m_':'_sf_f_')+safe(n.name.text);const ps=sym(n.name);if(!n.questionDotToken&&ps?.declarations?.some(d=>(ts.isPropertySignature(d)&&!d.questionToken)||ts.isPropertyAssignment(d)||ts.isShorthandPropertyAssignment(d)))return E(n.expression,c)+'['+JSON.stringify(n.name.text)+']';}
  return `${J}.getv(${E(n.expression,c)}, ${JSON.stringify(n.name.text)})`;
 }
 if(ts.isElementAccessExpression(n))return `${J}.getv(${E(n.expression,c)}, ${E(n.argumentExpression,c)})`;
 if(ts.isArrayLiteralExpression(n)){
  if(n.elements.some(ts.isSpreadElement)){return `${J}.array_concat([${n.elements.map(x=>ts.isSpreadElement(x)?E(x.expression,c):'['+E(x,c)+']').join(', ')}])`;}
  return '['+n.elements.map(x=>x.kind===ts.SyntaxKind.OmittedExpression?'null':E(x,c)).join(', ')+']';
 }
 if(ts.isObjectLiteralExpression(n)){
  let parts=[], merges=[];if(ts.isReturnStatement(n.parent)&&c.f?.bindings.some(b=>b.cap)&&n.properties.some(p=>ts.isMethodDeclaration(p)||(ts.isPropertyAssignment(p)&&(ts.isArrowFunction(p.initializer)||ts.isFunctionExpression(p.initializer)))))parts.push('"_sf_scope": _cap'+c.f.id);for(const p of n.properties){if(ts.isSpreadAssignment(p)){if(parts.length){merges.push('{'+parts.join(', ')+'}');parts=[];}merges.push(E(p.expression,c));continue;}
   if(ts.isShorthandPropertyAssignment(p))parts.push(JSON.stringify(p.name.text)+': '+id(p.name));
   else if(ts.isPropertyAssignment(p))parts.push(propKey(p.name,c)+': '+E(p.initializer,c));
   else if(ts.isMethodDeclaration(p))parts.push(propKey(p.name,c)+': '+lambda(p,c));
   else fail(p,'Object member');
  }if(parts.length||!merges.length)merges.push('{'+parts.join(', ')+'}');return merges.length===1?merges[0]:`${J}.object_merge([${merges.join(', ')}])`;
 }
 if(ts.isArrowFunction(n)||ts.isFunctionExpression(n))return lambda(n,c);
 if(ts.isConditionalExpression(n)){
  let test=E(n.condition,c);const a=new Ctx(c.f,c.indent+1,[]),b=new Ctx(c.f,c.indent+1,[]);let x=E(n.whenTrue,a),y=E(n.whenFalse,b);
  if(!a.out.length&&!b.out.length)return `(${x} if ${J}.truthy(${test}) else ${y})`;
  const t=c.temp('null');c.line(`if ${J}.truthy(${test}):`);c.out.push(...a.out);c.child().line(t+' = '+x);c.line('else:');c.out.push(...b.out);c.child().line(t+' = '+y);return t;
 }
 if(ts.isBinaryExpression(n)){
  const op=n.operatorToken.getText(src);
  if(op===','){c.line(E(n.left,c));return E(n.right,c);}
  if(op==='='||(/=$/.test(op)&&!['===','!==','==','!=','<=','>='].includes(op)))return assign(n.left,E(n.right,c),c,op);
  let a=E(n.left,c);
  if(['&&','||','??'].includes(op)){
   const rc=new Ctx(c.f,c.indent+1,[]),b=E(n.right,rc);let cond=op==='??'?`${a} == null`:`${J}.truthy(${a})`;if(op==='||')cond='not '+cond;
   // Any evaluation with side effects on the left happens exactly once.
   if(ts.isCallExpression(n.left)||ts.isBinaryExpression(n.left)){a=c.temp(a);cond=op==='??'?`${a} == null`:`${J}.truthy(${a})`;if(op==='||')cond='not '+cond;}
   if(!rc.out.length)return `(${b} if ${cond} else ${a})`;
   const t=c.temp(a);c.line('if '+cond+':');c.out.push(...rc.out);c.child().line(t+' = '+b);return t;
  }
  return bin(op,a,E(n.right,c));
 }
 if(ts.isPrefixUnaryExpression(n)||ts.isPostfixUnaryExpression(n)){
  const op=n.operator;if(op===ts.SyntaxKind.PlusPlusToken||op===ts.SyntaxKind.MinusMinusToken){const old=E(n.operand,c);const v=ts.isPostfixUnaryExpression(n)?c.temp(old):null;let a=assign(n.operand,'1.0',c,op===ts.SyntaxKind.PlusPlusToken?'+=':'-=');if(a!==v)c.line(a);return v||a;}
  const v=E(n.operand,c);if(op===ts.SyntaxKind.ExclamationToken)return `(not ${J}.truthy(${v}))`;if(op===ts.SyntaxKind.TildeToken)return `${J}.bnot(${v})`;if(op===ts.SyntaxKind.MinusToken)return `(-${v})`;if(op===ts.SyntaxKind.PlusToken)return `float(${v})`;fail(n,'Unary');
 }
 if(ts.isNewExpression(n)){
  const args=n.arguments?.map(x=>E(x,c)).join(', ')||'';if(ts.isIdentifier(n.expression)&&/^(Uint32Array|Uint8Array|Float32Array|Float64Array|Int32Array)$/.test(n.expression.text))return `${J}.typed_array(${JSON.stringify(n.expression.text)}, ${args||'0'})`;if(ts.isIdentifier(n.expression)&&n.expression.text==='Array')return `${J}.new_array(${args})`;
  return E(n.expression,c)+'.new('+args+')';
 }
 if(ts.isCallExpression(n)){
  if(ts.isPropertyAccessExpression(n.expression)){
   const p=n.expression,key=p.name.text;
   if(ts.isIdentifier(p.expression)&&p.expression.text==='Number'){const a=E(n.arguments[0],c);if(key==='isFinite')return '(('+a+' is int or '+a+' is float) and is_finite('+a+'))';if(key==='isNaN')return '(('+a+' is int or '+a+' is float) and is_nan('+a+'))';fail(n,'Number call');}
   if(ts.isIdentifier(p.expression)&&p.expression.text==='Math'){
    const spread=n.arguments.some(ts.isSpreadElement);const args=n.arguments.map(x=>ts.isSpreadElement(x)?E(x.expression,c):E(x,c));if(spread){const av=J+'.array_concat(['+n.arguments.map((x,i)=>ts.isSpreadElement(x)?args[i]:'['+args[i]+']').join(', ')+'])';if(key==='min'||key==='max')return J+'.math_'+key+'('+av+')';fail(n,'Math spread '+key);}const funcs={sin:'sin',cos:'cos',tan:'tan',asin:'asin',acos:'acos',atan:'atan',atan2:'atan2',exp:'exp',log:'log',sqrt:'sqrt',pow:'pow',floor:'floor',ceil:'ceil',abs:'abs',min:'min',max:'max',sign:'sign',trunc:'float(int',round:J+'.roundv',imul:J+'.imul',random:'randf',hypot:J+'.hypotv',cbrt:J+'.cbrtv'};
    if(!funcs[key])fail(n,'Math call');if(process.argv.includes('--v8-trig')&&(key==='sin'||key==='cos'))return ROOT+'.V8.'+key+'v('+args.join(', ')+')';if(key==='hypot')return J+'.hypotv(['+args.join(', ')+'])';return funcs[key]+'('+args.join(', ')+')'+(key==='trunc'?')':'');
   }
   if(ts.isIdentifier(p.expression)&&p.expression.text==='Array'&&key==='from'){
    const source=n.arguments[0],len=ts.isObjectLiteralExpression(source)?E(source.properties.find(x=>x.name?.text==='length').initializer,c):E(source,c);
    return `${J}.array_from(${len}, ${n.arguments[1]?E(n.arguments[1],c):'null'})`;
   }
   const obj=E(p.expression,c);const spread=n.arguments.some(ts.isSpreadElement);const args=n.arguments.map(x=>ts.isSpreadElement(x)?E(x.expression,c):E(x,c));const argarray=spread?J+'.array_concat(['+n.arguments.map((x,i)=>ts.isSpreadElement(x)?args[i]:'['+args[i]+']').join(', ')+'])':'['+args.join(', ')+']';
   if(!spread&&p.expression.kind===ts.SyntaxKind.ThisKeyword){const ms=sym(p.name);if(ms?.declarations?.some(ts.isMethodDeclaration))return `self._sf_m_${safe(key)}(${args.join(', ')})`;return `${J}.invoke(self._sf_f_${safe(key)}, [${args.join(', ')}])`;}
   const nativeMember=process.argv.includes('--direct-members')&&classMember(p);const call=nativeMember&&!spread&&ts.isMethodDeclaration(nativeMember)?`${obj}._sf_m_${safe(key)}(${args.join(', ')})`:`${J}.call_method(${obj}, ${JSON.stringify(key)}, ${argarray})`;
   return n.questionDotToken||p.questionDotToken?`(${call} if ${obj} != null else null)`:call;
  }
  if(ts.isIdentifier(n.expression)&&n.expression.text==='parseInt')return `${J}.parse_int(${n.arguments.map(x=>E(x,c)).join(', ')})`;
  if(ts.isIdentifier(n.expression)&&n.expression.text==='Number')return 'float('+E(n.arguments[0],c)+')';
  const fn=E(n.expression,c),args=n.arguments.map(x=>E(x,c)).join(', '),b=ts.isIdentifier(n.expression)?B.get(sym(n.expression)):null;
  const call=b?.kind==='function'?fn+'('+args+')':`${J}.invoke(${fn}, [${args}])`;
  return n.questionDotToken?`(${call} if ${fn} != null else null)`:call;
 }
 if(ts.isTemplateExpression(n)){let parts=[JSON.stringify(n.head.text)];for(const s of n.templateSpans)parts.push('str('+E(s.expression,c)+')',JSON.stringify(s.literal.text));return '('+parts.join(' + ')+')';}
 fail(n);
}
function decl(pattern,value,c){
 if(ts.isIdentifier(pattern)){let b=B.get(sym(pattern));if(!b)fail(pattern,'No binding');const name=bname(b);c.line((b.cap?'':'var ')+name+' = '+value);return;}
 const v=c.temp(value);if(ts.isArrayBindingPattern(pattern)){pattern.elements.forEach((x,i)=>{if(!ts.isBindingElement(x))return;let val=x.dotDotDotToken?`${J}.call_method(${v}, "slice", [${i}])`:`${J}.getv(${v}, ${i})`;if(x.initializer)val=`(${val} if ${val} != null else ${E(x.initializer,c)})`;decl(x.name,val,c);});return;}
 if(ts.isObjectBindingPattern(pattern)){for(const x of pattern.elements){let key=x.propertyName?propKey(x.propertyName,c):JSON.stringify(x.name.text);let val=`${J}.getv(${v}, ${key})`;if(x.initializer)val=`(${val} if ${val} != null else ${E(x.initializer,c)})`;decl(x.name,val,c);}return;}fail(pattern,'Binding');
}
function params(n,f){return n.parameters.map(p=>{let b=ts.isIdentifier(p.name)?B.get(sym(p.name)):null;let name=b&&!b.cap?bname(b):'_arg'+(++tmp);p._gdarg=name;return name+(p.initializer?' = '+simpleDefault(p.initializer):p.questionToken?' = null':'');}).join(', ');}
function simpleDefault(n){const c=new Ctx();const e=E(n,c);if(c.out.length)fail(n,'Complex default');return e;}
function functionBody(n,c){
 const f=F.get(n);c.f=f;
 if(f.bindings.some(b=>b.cap))c.line(`var _cap${f.id} = {"_sf_capture_scope": true}`);
 for(const p of n.parameters){if(!ts.isIdentifier(p.name)){decl(p.name,p._gdarg,c);continue;}const b=B.get(sym(p.name));if(b.cap)c.line(bname(b)+' = '+p._gdarg);}
 // Hoist named local functions, preserving shared dictionary references.
 const statements=ts.isBlock(n.body)?n.body.statements:[];
 for(const s of statements)if(ts.isFunctionDeclaration(s)){const b=B.get(sym(s.name));const fn=lambda(s,c);c.line((b.cap?'':'var ')+bname(b)+' = '+fn);}
 if(ts.isBlock(n.body))for(const s of n.body.statements)if(!ts.isFunctionDeclaration(s))S(s,c);else{}else c.line('return '+E(n.body,c));
 if(!n.body||ts.isBlock(n.body)&&!n.body.statements.length)c.line('pass');
}
function lambda(n,c){const name='_lambda'+(++tmp),f=F.get(n);let p=params(n,f);c.line(`var ${name} = func(${p}):`);functionBody(n,c.child());return name;}
function block(n,c){const before=c.out.length;if(ts.isBlock(n)){for(const s of n.statements)S(s,c);}else S(n,c);if(before===c.out.length)c.line('pass');}
function S(n,c){
 if(ts.isVariableStatement(n)){for(const d of n.declarationList.declarations)decl(d.name,E(d.initializer,c),c);return;}
 if(ts.isExpressionStatement(n)){
  if(ts.isBinaryExpression(n.expression)&&ts.isIdentifier(n.expression.left)&&n.expression.operatorToken.kind>=ts.SyntaxKind.FirstAssignment&&n.expression.operatorToken.kind<=ts.SyntaxKind.LastAssignment){const l=n.expression.left,op=n.expression.operatorToken.getText(src),r=E(n.expression.right,c);const b=B.get(sym(l));c.line(id(l)+' = '+(op==='='?r:bin(op.slice(0,-1),id(l),r)));return;}
  const x=E(n.expression,c);if(x&&!/^_v_[A-Za-z0-9_]+$/.test(x))c.line(x);return;
 }
 if(ts.isReturnStatement(n)){
  // ice.cracksOf returns only numeric point arrays. Its recursive local walk
  // closes over its own capture dictionary, but never escapes this function.
  // Break that transient cycle without releasing the caller-owned RNG/body.
  if(slug==='ice'&&c.f?.node?.name?.text==='cracksOf'&&c.f.bindings.some(b=>b.cap)){
   if(!n.expression||!ts.isIdentifier(n.expression)||n.expression.text!=='out')fail(n,'Review changed ice.cracksOf return lifetime');
   const value=c.temp(E(n.expression,c));c.line('_cap'+c.f.id+'.clear()');c.line('return '+value);return;
  }
  c.line('return'+(n.expression?' '+E(n.expression,c):''));return;
 }
 if(ts.isIfStatement(n)){const e=E(n.expression,c);c.line(`if ${J}.truthy(${e}):`);block(n.thenStatement,c.child());if(n.elseStatement){c.line('else:');block(n.elseStatement,c.child());}return;}
 if(ts.isBlock(n)){for(const s of n.statements)S(s,c);return;}
 if(ts.isForStatement(n)){
  if(n.initializer){if(ts.isVariableDeclarationList(n.initializer)){for(const d of n.initializer.declarations)decl(d.name,E(d.initializer,c),c);}else c.line(E(n.initializer,c));}
  c.line('while true:');let d=c.child();d.loop.push(n.incrementor);if(n.condition){let test=E(n.condition,d);d.line(`if not ${J}.truthy(${test}):`);d.child().line('break');}block(n.statement,d);if(n.incrementor){let e=E(n.incrementor,d);if(e&&!/^_v_[A-Za-z0-9_]+$/.test(e))d.line(e);}return;
 }
 if(ts.isWhileStatement(n)){c.line('while true:');let d=c.child();d.loop.push(null);let test=E(n.expression,d);d.line(`if not ${J}.truthy(${test}):`);d.child().line('break');block(n.statement,d);return;}
 if(ts.isForOfStatement(n)){const it='_iter'+(++tmp);c.line(`for ${it} in ${E(n.expression,c)}:`);let d=c.child();d.loop.push(null);if(ts.isVariableDeclarationList(n.initializer))decl(n.initializer.declarations[0].name,it,d);else d.line(assign(n.initializer,it,d));block(n.statement,d);return;}
 if(ts.isContinueStatement(n)){const inc=c.loop[c.loop.length-1];if(inc){let e=E(inc,c);if(e&&!/^_v_[A-Za-z0-9_]+$/.test(e))c.line(e);}c.line('continue');return;}
 if(ts.isBreakStatement(n)){c.line('break');return;}
 if(ts.isSwitchStatement(n)){
  const test=c.temp(E(n.expression,c));c.line('while true:');const w=c.child();let groups=[],pending=[];
  for(const cl of n.caseBlock.clauses){pending.push(cl);if(cl.statements.length){groups.push({clauses:pending,statements:cl.statements});pending=[];}}
  if(pending.length)groups.push({clauses:pending,statements:[]});let i=0;
  for(const g of groups){const conditions=g.clauses.filter(ts.isCaseClause).map(cl=>test+' == '+E(cl.expression,w));const def=g.clauses.some(ts.isDefaultClause);w.line(def?'else:':(i++?'elif ':'if ')+conditions.join(' or ')+':');const d=w.child();for(const st of g.statements)S(st,d);if(!g.statements.length)d.line('pass');}
  w.line('break');return;
 }

 if(ts.isFunctionDeclaration(n)||ts.isInterfaceDeclaration(n)||ts.isTypeAliasDeclaration(n)||ts.isEmptyStatement(n))return;
 fail(n,'Statement '+ts.SyntaxKind[n.kind]);
}
const c=new Ctx();c.line('# Made by Sprite Fusion. MIT License. Copyright (c) 2026 Hugo Duprez.');c.line('# Mechanical native GDScript port. Source algorithm port; differential coverage is recorded separately.');c.line('# Generated by spritefusion_exact/tools/transpile.cjs; differential coverage is recorded separately.');c.line('extends RefCounted');c.line('class_name '+ROOT);c.line('const JS = preload("res://scripts/core/sf_js.gd")');if(process.argv.includes('--v8-trig'))c.line('const V8 = preload("res://scripts/core/sf_v8_math.gd")');if(process.argv.includes('--native-px'))c.line('const C_Px = preload("res://scripts/core/'+(slug==='fire'?'sf_px_fire_source.gd':'sf_px_source.gd')+'")');
for(const n of src.statements){
 if(ts.isExpressionStatement(n)){const en='_init_expr_'+(++tmp);c.line('static var _top_expr_'+tmp+' = '+en+'()');c.line('static func '+en+'():');S(n,c.child());c.child().line('return null');}
 if(ts.isVariableStatement(n)){for(const d of n.declarationList.declarations){if(!ts.isIdentifier(d.name))fail(d,'Global destructuring');const b=B.get(sym(d.name));const ec=new Ctx();const e=E(d.initializer,ec);if(ec.out.length){const name='_init_global_'+b.id;c.line('static var _g_'+safe(b.name)+' = '+name+'()');c.line('static func '+name+'():');c.out.push(...ec.out.map(x=>'\t'+x));c.child().line('return '+e);}else c.line('static var _g_'+safe(b.name)+' = '+e);}}
}
for(const n of src.statements){
 if(ts.isFunctionDeclaration(n)&&process.argv.includes('--skip='+n.name.text))continue;
 if(ts.isFunctionDeclaration(n)){const name='_f_'+safe(n.name.text);c.line('');c.line('static func '+name+'('+params(n,F.get(n))+'):');functionBody(n,c.child());}
 if(ts.isClassDeclaration(n)){
  if(n.name.text==='Px'&&process.argv.includes('--native-px'))continue;
  c.line('');c.line('class C_'+safe(n.name.text)+':');let cc=c.child();cc.line('extends RefCounted');
  if(n.heritageClauses?.length)fail(n,'Class inheritance');
  for(const m of n.members)if(ts.isPropertyDeclaration(m)){const ec=new Ctx(null,cc.indent,[]);const e=E(m.initializer,ec);if(ec.out.length)fail(m,'Field init prelude');cc.line('var _sf_f_'+safe(m.name.text)+' = '+e);}
  cc.line('func _sf_release():');const fields=n.members.filter(ts.isPropertyDeclaration);for(const m of fields)cc.child().line('self._sf_f_'+safe(m.name.text)+' = null');if(!fields.length)cc.child().line('pass');
  for(const m of n.members){if(ts.isConstructorDeclaration(m)||ts.isMethodDeclaration(m)){cc.line('func '+(ts.isConstructorDeclaration(m)?'_init':'_sf_m_'+safe(m.name.text))+'('+params(m,F.get(m))+'):');functionBody(m,cc.child());}else if(ts.isGetAccessor(m)){cc.line('var _sf_f_'+safe(m.name.text)+':');cc.child().line('get:');functionBody(m,cc.child().child());}}
 }
}
const def=src.statements.find(n=>ts.isFunctionDeclaration(n)&&n.modifiers?.some(m=>m.kind===ts.SyntaxKind.DefaultKeyword));
if(def){c.line('');c.line('var _effect = {}');c.line('func configure(options = {}):');c.child().line('dispose()');c.child().line('_effect = _f_'+safe(def.name.text)+'(options)');c.child().line('return self');c.line('func update(dt):');c.child().line('return JS.call_method(_effect, "update", [dt])');c.line('func draw(frame, layer = ""):');c.child().line('var source = frame.as_source() if frame is Object and frame.has_method("as_source") else frame');c.child().line('return JS.call_method(_effect, "draw", [source, layer])');c.line('func done():');c.child().line('return JS.call_method(_effect, "done", [])');c.line('func invoke(method, args = []):');c.child().line('return JS.call_method(_effect, method, args)');c.line('func dispose():');c.child().line('JS.release_scopes(_effect)');c.child().line('_effect.clear()');c.line('func stop():');c.child().line('return JS.call_method(_effect, "stop", [])');}
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,c.out.join('\n')+'\n');console.log(`${slug}: ${c.out.length} lines -> ${output}`);
