import { launch } from './cdp.mjs';
export const P = 'file:///D:/New_project/abra-travels/prototypes/';
export async function mk(w=420,h=860){const b=await launch(w,h);await b.resize(w,h);await b.eval('try{localStorage.clear()}catch(e){}');return b}
export const labels=b=>b.eval(`[...document.querySelectorAll('[data-a],[data-go],button,input,select,textarea')].filter(e=>{const r=e.getBoundingClientRect();return r.width>2&&r.height>2}).map(e=>(e.tagName==='INPUT'||e.tagName==='SELECT'||e.tagName==='TEXTAREA'?'<'+e.tagName.toLowerCase()+' #'+e.id+' '+(e.placeholder||e.getAttribute('aria-label')||'')+'>':(e.dataset.a||'')+':'+(e.textContent||'').trim().slice(0,28))).join(' | ')`);
export const clickA=(b,a,v)=>b.eval(`(function(){const e=[...document.querySelectorAll('[data-a="${a}"]')].find(x=>${v==null?'true':`x.dataset.v==="${v}"`}&&x.getBoundingClientRect().width>0);if(!e)return 'NOT FOUND ${a}';e.dispatchEvent(new MouseEvent('click',{bubbles:true}));return 'ok'})()`);
export const clickT=(b,t)=>b.eval(`(function(){const e=[...document.querySelectorAll('button,[data-a],a')].find(x=>x.getBoundingClientRect().width>0&&(x.textContent||'').trim().toLowerCase().includes(${JSON.stringify(t.toLowerCase())}));if(!e)return 'NOT FOUND ${t}';e.dispatchEvent(new MouseEvent('click',{bubbles:true}));return 'ok'})()`);
export const text=b=>b.eval('document.body.innerText');
