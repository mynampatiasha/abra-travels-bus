import {mk,P} from './flow.mjs';
import fs from 'fs';
const b=await mk(1200,800);await b.goto(P+'admin_demo_model.html',1800);
const cols=await b.eval(`(function(){const d=AbraStore.get();const ty=v=>v===null?'null':Array.isArray(v)?'array':typeof v;
return Object.keys(d).map(k=>{const v=d[k];if(Array.isArray(v)){const s=v.find(x=>x&&typeof x==='object')||v[0];return {key:k,kind:'list',count:v.length,fields:s&&typeof s==='object'?Object.keys(s).map(f=>f+':'+ty(s[f])):[ty(s)]}}
 if(v&&typeof v==='object')return {key:k,kind:'object',count:Object.keys(v).length,fields:Object.keys(v).slice(0,30).map(f=>f+':'+ty(v[f]))};return {key:k,kind:ty(v),count:1,fields:[]}})})()`);
fs.writeFileSync(process.argv[2],JSON.stringify(cols,null,1));console.log(cols.length,'keys');console.log(cols.map(c=>c.key+'('+c.count+')').join(' '));
b.close();process.exit(0);
