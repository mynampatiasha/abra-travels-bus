import { launch } from './cdp.mjs';
import fs from 'fs';
const base = 'file:///D:/New_project/abra-travels/prototypes/';
const which = process.argv[2];            // admin | client
const outFile = process.argv[3];
const file = which + '_demo_model.html';
const b = await launch(1366, 900); await b.resize(1366, 900);
const login = async () => {
  if (which !== 'client') return;
  await b.eval(`(function(){const s=document.getElementById('f_so');s.value=s.options[0].value;s.dispatchEvent(new Event('change',{bubbles:true}));document.getElementById('f_spw').value='x';document.querySelector('[data-a=au_in]').dispatchEvent(new MouseEvent('click',{bubbles:true}))})()`);
  await b.sleep(1300);
};
await b.goto(base + file, 1200); await b.eval('try{localStorage.clear()}catch(e){}');
await b.goto(base + file, 1500); await login();
for (let i = 0; i < 40; i++) { const ok = await b.eval(`typeof PAGES!=='undefined'&&Object.keys(PAGES).length>5`); if (ok === true) break; await b.sleep(500); }
const meta = await b.eval(`(function(){const g={};(typeof GROUPS!=='undefined'?GROUPS:[]).forEach(([n,ids])=>ids.forEach(i=>g[i]=n));return {pages:Object.keys(PAGES).map(k=>({id:k,title:PAGES[k].t,group:g[k]||''})),roles:typeof ROLES!=='undefined'?ROLES:null,perm:typeof PERM!=='undefined'?PERM:null}})()`);
const result = { app: which, roles: meta.roles, perm: meta.perm, pages: [] };
const grab = fs.readFileSync(new URL('./grab.js', import.meta.url), 'utf8');
const lo = Number(process.argv[4] || 0), hi = Number(process.argv[5] || 999);
for (const p of meta.pages.slice(lo, hi)) {
  await b.goto(base + file, 900); await b.eval('try{localStorage.clear()}catch(e){}');
  await b.goto(base + file, 1400); await login();
  await b.eval(`location.hash='#/${p.id}'`); await b.sleep(700);
  b.errors.length = 0;
  const pg = await b.eval(grab);
  if (pg && pg.__err) { console.log('ERR', p.id, pg.__err.slice(0, 120)); result.pages.push({ ...p, error: pg.__err.slice(0, 200) }); continue; }
  result.pages.push({ ...p, ...pg, jsErrors: b.errors.slice(0, 3) });
  console.log(p.id, 'tables', pg.tables.length, 'actions', pg.actions.length, 'dialogs', pg.actions.filter(a => a.kind === 'dialog').length);
}
fs.writeFileSync(outFile, JSON.stringify(result, null, 1));
b.close(); process.exit(0);
