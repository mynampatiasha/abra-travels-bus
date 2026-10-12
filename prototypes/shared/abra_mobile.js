/* =====================================================================
   ABRA TRAVELS - SHARED KIT FOR THE PHONE PROTOTYPES (customer and driver apps)
   Design tokens, phone frame (portrait / landscape), sheets, toasts, icons,
   English / Telugu / Hindi, and the demo bar. Data comes from abra_store.js.
   ===================================================================== */
(function(){
const css=`
:root{--n:#12304A;--b:#1677C8;--s:#36BDF5;--db:#0B4EA2;--lb:#E8F6FD;--lb2:#DDF3FC;--g:#1B8A5A;--gbg:#E1F4EA;--gtx:#12663F;--r:#EF4444;--rbg:#FDE8E8;--rtx:#B91C1C;--a:#F59E0B;--abg:#FEF3C7;--atx:#7A4B00;--bg:#F3F5F7;--card:#fff;--ln:#D7E0E7;--m:#66798A;--tx:#183247;--fld:#fff;--hov:#E8F6FD;--sh:0 8px 24px rgba(18,48,74,.08);--gr:linear-gradient(135deg,#12304A,#1677C8 58%,#36BDF5);--outer:#E4EAEF}
:root[data-theme=dark]{--bg:#0B1620;--card:#13222F;--ln:#2A3E50;--m:#9FB6C9;--tx:#E6EEF5;--fld:#0F1C27;--hov:#1B3347;--lb:#16314A;--lb2:#1D4268;--gbg:#123B2A;--gtx:#7EE0B0;--rbg:#4A1D1D;--rtx:#FFA6A6;--abg:#4A3A12;--atx:#FFD98A;--sh:0 8px 24px rgba(0,0,0,.35);--outer:#060E15}
*{box-sizing:border-box}html,body{margin:0;height:100%}
body{background:var(--outer);color:var(--tx);font:400 14px/1.45 Inter,system-ui,Arial,sans-serif}
button,input,select,textarea{font:inherit;color:inherit}button{cursor:pointer;border:0;background:none;padding:0}
:focus-visible{outline:3px solid #7DD8F7;outline-offset:2px}h1,h2,h3,h4,p{margin:0}
.m{color:var(--m)}.sm{font-size:12px}.bd{font-weight:800}.tc{text-align:center}.hide{display:none!important}
.row{display:flex;align-items:center;gap:8px}.rw{flex-wrap:wrap}.bt{justify-content:space-between}.grow{flex:1;min-width:0}.col{display:flex;flex-direction:column;gap:10px}.mt{margin-top:14px}.mt2{margin-top:8px}
/* stage and phone frame */
.stage{min-height:100vh;display:flex;flex-direction:column;align-items:center;gap:12px;padding:12px}
.dbar{display:flex;gap:6px;flex-wrap:wrap;justify-content:center;align-items:center;max-width:900px}
.dbar button,.dbar select{min-height:34px;padding:0 12px;border:1px solid var(--ln);border-radius:99px;background:var(--card);font-weight:600;font-size:12px;color:var(--tx)}
.dbar button.on{background:var(--n);color:#fff;border-color:var(--n)}
.phone{width:390px;height:min(844px,calc(100vh - 80px));border:10px solid #0d2236;border-radius:36px;overflow:hidden;position:relative;background:var(--bg);box-shadow:0 20px 50px rgba(18,48,74,.3);display:flex;flex-direction:column;transform:translateZ(0)}
.phone.land{width:min(844px,96vw);height:min(390px,calc(100vh - 80px))}
@media(max-width:640px){.stage{padding:0;gap:0}.phone,.phone.land{width:100vw;height:100vh;border:0;border-radius:0}.dbar{position:fixed;left:8px;bottom:84px;z-index:60;flex-direction:column;align-items:flex-start}.dbar.closed>*:not(.dtog){display:none}}
@media(min-width:641px){.dtog{display:none}}
.dtog{background:var(--gr)!important;color:#fff!important;border:0!important}
.scr{flex:1;overflow:auto;position:relative}
.hd{background:var(--gr);color:#fff;padding:14px 16px;display:flex;align-items:center;gap:10px;flex:none}
.hd h1{font-size:17px;flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ib{width:44px;height:44px;display:grid;place-items:center;border-radius:12px;position:relative;flex:none}.ib:hover{background:#ffffff22}
.hd .ib{color:#fff}.dot{position:absolute;top:6px;right:6px;background:var(--r);color:#fff;border-radius:99px;font-size:10px;font-weight:800;min-width:16px;height:16px;display:grid;place-items:center;padding:0 4px}
.pad{padding:14px;display:flex;flex-direction:column;gap:12px}
.lay{display:flex;flex-direction:column;flex:1;min-height:0}.main{flex:1;display:flex;flex-direction:column;min-height:0;min-width:0}
.tabs{display:flex;background:var(--card);border-top:1px solid var(--ln);flex:none}
.tabs button{flex:1;min-height:58px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;font-size:11px;font-weight:600;color:var(--m);position:relative}
.tabs button.on{color:var(--b)}
.phone.land .lay{display:flex;flex-direction:row;flex:1;min-height:0}.phone.land .tabs{flex-direction:column;width:88px;flex:none;border-top:0;border-right:1px solid var(--ln);order:-1;overflow:auto}.phone.land .tabs button{min-height:0;flex:1}

.c{background:var(--card);border:1px solid var(--ln);border-radius:16px;padding:14px;box-shadow:var(--sh)}.c>*+*{margin-top:8px}
.cta{min-height:48px;padding:0 16px;border-radius:12px;background:var(--b);color:#fff;font-weight:800;display:inline-flex;align-items:center;justify-content:center;gap:8px;transition:.15s}
.cta:active{transform:scale(.98)}.cta.gh{background:var(--card);color:var(--tx);border:1px solid var(--ln)}.cta.dg{background:var(--r)}.cta.ok{background:var(--g)}.cta.sm{min-height:36px;padding:0 12px;font-size:13px;border-radius:10px}.cta.full{width:100%}
.cta[disabled]{opacity:.45;pointer-events:none}
.fd{background:var(--fld);border:1px solid var(--ln);border-radius:12px;padding:6px 12px;min-height:52px;display:block}.fd:focus-within{border-color:var(--s);box-shadow:0 0 0 3px #7DD8F7}
.fd label{display:block;font-size:12px;color:var(--m)}.fd input,.fd select,.fd textarea{width:100%;border:0;outline:0;background:transparent;min-height:28px;padding:0}
.st{display:inline-block;border-radius:99px;padding:3px 10px;font-size:12px;font-weight:800;white-space:nowrap}
.st.g{background:var(--gbg);color:var(--gtx)}.st.n{background:#E5EAEE;color:#183247}.st.r{background:var(--rbg);color:var(--rtx)}.st.a{background:var(--abg);color:var(--atx)}.st.b{background:var(--lb2);color:var(--db)}
:root[data-theme=dark] .st.n{background:#243A4D;color:#E6EEF5}
.hb{border-radius:12px;padding:10px 12px;display:flex;gap:8px;align-items:flex-start;font-weight:600;background:var(--lb);color:var(--db)}.hb.a{background:var(--abg);color:var(--atx)}.hb.r{background:var(--rbg);color:var(--rtx)}.hb.g{background:var(--gbg);color:var(--gtx)}
.ch{min-height:38px;padding:0 14px;border:1px solid var(--ln);border-radius:99px;background:var(--card);display:inline-flex;align-items:center;gap:6px;font-weight:600;white-space:nowrap}.ch.on{background:var(--lb2);border-color:var(--b);color:var(--db)}
.hs{display:flex;gap:10px;overflow-x:auto;padding-bottom:4px;scrollbar-width:thin}
.empty{text-align:center;padding:30px 12px;color:var(--m)}.empty .big{width:64px;height:64px;border-radius:50%;background:var(--lb2);color:var(--db);display:grid;place-items:center;margin:0 auto 10px}
.tl{border-left:2px solid var(--ln);margin-left:6px;padding-left:14px}.tl .ev{position:relative;padding:0 0 12px}.tl .ev:before{content:"";position:absolute;left:-21px;top:4px;width:12px;height:12px;border-radius:50%;background:var(--ln);border:2px solid var(--card)}.tl .ev.d:before{background:var(--g)}.tl .ev.c:before{background:var(--b);box-shadow:0 0 0 4px var(--lb2)}
.bar{height:8px;border-radius:99px;background:var(--lb2);overflow:hidden}.bar i{display:block;height:100%;background:var(--b);border-radius:99px}
.kv{display:grid;grid-template-columns:120px 1fr;gap:6px 10px}.kv dt{color:var(--m)}.kv dd{margin:0;font-weight:600}
.scrim{position:absolute;inset:0;background:rgba(18,48,74,.55);display:flex;align-items:flex-end;z-index:40}
.sheet{background:var(--card);width:100%;max-height:92%;overflow:auto;border-radius:20px 20px 0 0;padding:16px;animation:up .2s}.phone.land .scrim{align-items:center;justify-content:center}.phone.land .sheet{width:min(560px,92%);border-radius:20px}
@keyframes up{from{transform:translateY(30px);opacity:0}}
.sheet h3{font-size:17px;display:flex;justify-content:space-between;align-items:center}
.toast{position:absolute;left:12px;right:12px;bottom:76px;background:var(--n);color:#fff;border-radius:12px;padding:11px 14px;font-weight:600;z-index:50;box-shadow:0 10px 30px #0004;animation:up .2s}
.map{position:relative;background:linear-gradient(135deg,#DDF3FC,#E8F6FD);border:1px solid var(--ln);border-radius:14px;overflow:hidden;min-height:200px}:root[data-theme=dark] .map{background:linear-gradient(135deg,#143049,#102536)}
.map svg{position:absolute;inset:0;width:100%;height:100%}.pin{position:absolute;transform:translate(-50%,-100%);background:var(--n);color:#fff;border-radius:10px;padding:3px 8px;font-size:11px;font-weight:800;white-space:nowrap;box-shadow:0 4px 12px #0004}.pin.grn{background:var(--g)}.pin.red{background:var(--r)}
.pulse{animation:pl 1.2s infinite}@keyframes pl{50%{opacity:.4}}
@media(prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
`;
const st=document.createElement('style');st.textContent=css;document.head.appendChild(st);
const P={home:'M3 11l9-8 9 8v10a1 1 0 01-1 1h-5v-7H9v7H4a1 1 0 01-1-1z',user:'M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2M12 11a4 4 0 100-8 4 4 0 000 8z',bus:'M4 16V6a2 2 0 012-2h12a2 2 0 012 2v10M2 16h20v3H2zM7 19v2M17 19v2M4 11h16',ticket:'M2 9a3 3 0 010-6h20a3 3 0 010 6v6a3 3 0 010 6H2a3 3 0 010-6zM13 5v2M13 17v2M13 11v2',bell:'M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 01-3.4 0',search:'M11 19a8 8 0 100-16 8 8 0 000 16zM21 21l-4.3-4.3',back:'M15 18l-6-6 6-6',chevR:'M9 18l6-6-6-6',x:'M18 6L6 18M6 6l12 12',check:'M20 6L9 17l-5-5',alert:'M10.3 3.9L1.8 18a2 2 0 001.7 3h17a2 2 0 001.7-3L13.7 3.9a2 2 0 00-3.4 0zM12 9v4M12 17h.01',nav:'M3 11l19-9-9 19-2-8z',pin:'M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0118 0zM12 13a3 3 0 100-6 3 3 0 000 6z',clock:'M12 22a10 10 0 100-20 10 10 0 000 20zM12 6v6l4 2',tag:'M20.6 13.4l-7.2 7.2a2 2 0 01-2.8 0L2 12V2h10l8.6 8.6a2 2 0 010 2.8zM7 7h.01',phone:'M22 16.9v3a2 2 0 01-2.2 2 19.8 19.8 0 01-8.6-3.1 19.5 19.5 0 01-6-6A19.8 19.8 0 012.1 4.2 2 2 0 014.1 2h3a2 2 0 012 1.7c.1 1 .4 1.9.7 2.8a2 2 0 01-.5 2.1L8 9.9a16 16 0 006 6l1.3-1.3a2 2 0 012.1-.4c.9.3 1.8.6 2.8.7a2 2 0 011.7 2z',help:'M12 22a10 10 0 100-20 10 10 0 000 20zM9.1 9a3 3 0 015.8 1c0 2-3 3-3 3M12 17h.01',share:'M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8M16 6l-4-4-4 4M12 2v13',download:'M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M7 10l5 5 5-5M12 15V3',swap:'M7 16V4M7 4L3 8M7 4l4 4M17 8v12M17 20l4-4M17 20l-4-4',card:'M21 4H3a2 2 0 00-2 2v12a2 2 0 002 2h18a2 2 0 002-2V6a2 2 0 00-2-2zM1 10h22',shield:'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',users:'M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2M9 11a4 4 0 100-8 4 4 0 000 8zM23 21v-2a4 4 0 00-3-3.9M16 3.1a4 4 0 010 7.8',qr:'M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h3v3h-3zM20 14v.01M14 20h.01M17 17h4v4',play:'M5 3l14 9-14 9z',flag:'M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1zM4 22v-7',logout:'M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9',moon:'M21 12.8A9 9 0 1111.2 3a7 7 0 009.8 9.8z',globe:'M12 22a10 10 0 100-20 10 10 0 000 20zM2 12h20M12 2a15 15 0 010 20 15 15 0 010-20z',star:'M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z',info:'M12 22a10 10 0 100-20 10 10 0 000 20zM12 16v-4M12 8h.01',refresh:'M23 4v6h-6M1 20v-6h6M3.5 9a9 9 0 0114.9-3.4L23 10M1 14l4.6 4.4A9 9 0 0020.5 15',send:'M22 2L11 13M22 2l-7 20-4-9-9-4z',cal:'M19 4H5a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2V6a2 2 0 00-2-2zM16 2v4M8 2v4M3 10h18'};
const M=window.M={};
M.$=(s,r=document)=>r.querySelector(s);M.$$=(s,r=document)=>[...r.querySelectorAll(s)];
M.esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
M.money=p=>'₹'+(Math.round(p)/100).toLocaleString('en-IN',{maximumFractionDigits:0});
M.fd=s=>new Date(s).toLocaleDateString('en-IN',{weekday:'short',day:'numeric',month:'short'});
M.ft=s=>new Date(s).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit',hour12:true});
M.fdt=s=>M.fd(s)+', '+M.ft(s);
M.rel=s=>{const d=(Date.now()-new Date(s))/6e4;if(d<0){const f=-d;return f<60?'in '+Math.round(f)+' min':f<1440?'in '+Math.round(f/60)+' h':'in '+Math.round(f/1440)+' d'}return d<1?'just now':d<60?Math.round(d)+' min ago':d<1440?Math.round(d/60)+' h ago':Math.round(d/1440)+' d ago'};
M.ic=(k,z=20)=>`<svg width="${z}" height="${z}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${P[k]||P.info}"/></svg>`;
const TONE={CONFIRMED:'g',COMPLETED:'g',ARRIVED:'g',SUCCESS:'g',RESOLVED:'g',ACTIVE:'g',LIVE:'g',SCHEDULED:'b',BOARDING:'b',IN_TRANSIT:'b',DEPARTED:'b',ACKNOWLEDGED:'b',RESPONDING:'b',IN_PROGRESS:'b',DELAYED:'a',PENDING:'a',INITIATED:'a',PROCESSING:'a',OPEN:'a',CANCELLED:'n',CLOSED:'n',FAILED:'r',NEW:'r',SIGNAL_LOST:'r'};
M.lab=s=>String(s).replace(/_/g,' ').toLowerCase().replace(/^\w/,c=>c.toUpperCase());
M.chip=(s,t)=>`<span class="st ${t||TONE[s]||'n'}">${M.esc(M.lab(s))}</span>`;
M.hb=(t,tone,i)=>`<div class="hb ${tone||''}">${M.ic(i||'info',18)}<div>${t}</div></div>`;
M.kv=o=>`<dl class="kv">${Object.entries(o).map(([k,v])=>`<dt>${M.esc(k)}</dt><dd>${v==null||v===''?'-':v}</dd>`).join('')}</dl>`;
M.empty=(t,s,b)=>`<div class="empty"><div class="big">${M.ic('info',30)}</div><b>${M.esc(t)}</b><p class="sm">${M.esc(s||'')}</p>${b||''}</div>`;
M.fld=(id,l,v='',o={})=>{const t=o.type||'text';const inp=t==='select'?`<select id="f_${id}">${(o.opts||[]).map(x=>{const a=Array.isArray(x)?x:[x,x];return`<option value="${M.esc(a[0])}" ${String(a[0])===String(v)?'selected':''}>${M.esc(a[1])}</option>`}).join('')}</select>`:t==='textarea'?`<textarea id="f_${id}" rows="3" placeholder="${M.esc(o.ph||'')}">${M.esc(v)}</textarea>`:`<input id="f_${id}" type="${t}" value="${M.esc(v)}" placeholder="${M.esc(o.ph||'')}" ${o.min!=null?`min="${o.min}"`:''} ${o.max!=null?`max="${o.max}"`:''} ${o.inputmode?`inputmode="${o.inputmode}"`:''}>`;return`<div class="fd"><label for="f_${id}">${M.esc(l)}</label>${inp}</div>`};
M.gv=id=>{const e=document.getElementById('f_'+id);return e?e.value:''};
M.toast=m=>{const ph=M.$('.phone');if(!ph)return;M.$$('.toast',ph).forEach(x=>x.remove());const d=document.createElement('div');d.className='toast';d.textContent=M.t(m);ph.appendChild(d);setTimeout(()=>d.remove(),2600)};
M.sheet=(title,body,foot)=>{M.closeSheet();const ph=M.$('.phone');const d=document.createElement('div');d.className='scrim';d.id='scrim';d.innerHTML=`<div class="sheet" role="dialog" aria-modal="true" aria-label="${M.esc(title)}"><h3>${M.esc(title)}<button class="ib" data-a="sheet_x" aria-label="Close" style="color:var(--tx)">${M.ic('x')}</button></h3><div class="col mt2">${body}</div>${foot?`<div class="row mt" style="justify-content:flex-end">${foot}</div>`:''}</div>`;d.addEventListener('click',e=>{if(e.target===d)M.closeSheet()});ph.appendChild(d);M.translate(d)};
M.closeSheet=()=>{const s=M.$('#scrim');if(s)s.remove()};
M.mapBox=(pins,h,line)=>`<div class="map" style="min-height:${h||200}px"><svg viewBox="0 0 100 100" preserveAspectRatio="none"><defs><pattern id="gp" width="8" height="8" patternUnits="userSpaceOnUse"><path d="M8 0H0V8" fill="none" stroke="var(--ln)" stroke-width=".2"/></pattern></defs><rect width="100" height="100" fill="url(#gp)"/>${line?`<polyline fill="none" stroke="#1677C8" stroke-width=".8" stroke-dasharray="1.5 1" points="${line.map(p=>p.join(',')).join(' ')}"/>`:''}</svg>${pins.map(p=>`<div class="pin ${p.c||''}" style="left:${p.x}%;top:${p.y}%">${M.esc(p.l)}</div>`).join('')}<div class="sm m" style="position:absolute;left:8px;bottom:6px;background:var(--card);padding:2px 8px;border-radius:8px">Map placeholder</div></div>`;
/* QR-like square drawn from the PNR (placeholder for the real QR code) */
M.qr=(txt,z=150)=>{let h=2166136261;for(const c of String(txt)){h^=c.charCodeAt(0);h=Math.imul(h,16777619)>>>0}let r='';const fin=(x,y)=>{for(let i=0;i<7;i++)for(let j=0;j<7;j++)if(i===0||i===6||j===0||j===6||(i>=2&&i<=4&&j>=2&&j<=4))r+=`<rect x="${x+i}" y="${y+j}" width="1" height="1"/>`};fin(0,0);fin(14,0);fin(0,14);
for(let y=0;y<21;y++)for(let x=0;x<21;x++){if((x<8&&y<8)||(x>12&&y<8)||(x<8&&y>12))continue;h=(Math.imul(h,1103515245)+12345)>>>0;if(h&0x40000000)r+=`<rect x="${x}" y="${y}" width="1" height="1"/>`}
return`<svg viewBox="-1 -1 23 23" width="${z}" height="${z}" style="background:#fff;border-radius:8px" role="img" aria-label="Ticket QR code"><g fill="#12304A">${r}</g></svg>`};

/* ---------- languages ---------- */
M.lang=localStorage.getItem('abra_m_lang')||'en';
M.dict={};
M.addDict=txt=>txt.trim().split('\n').forEach(l=>{const p=l.split('|');if(p.length===3)M.dict[p[0].trim()]=[p[1].trim(),p[2].trim()]});
M.t=s=>{if(M.lang==='en')return s;const k=String(s).trim(),t=ABRA_L.tr(k,M.lang,M.dict[k]);return t!==k?t:s};
M.translate=root=>{if(!root||M.lang==='en')return;const j=M.lang==='te'?0:1,w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT,{acceptNode:n=>n.parentNode&&/^(SCRIPT|STYLE|TEXTAREA)$/.test(n.parentNode.nodeName)?2:1}),ns=[];while(w.nextNode())ns.push(w.currentNode);
ns.forEach(n=>{const k=n.nodeValue.trim();if(!k)return;const t=ABRA_L.tr(k,M.lang,M.dict[k]);if(t!==k)n.nodeValue=n.nodeValue.replace(k,t)});
M.$$('[placeholder],[aria-label],[title]',root).forEach(el=>['placeholder','aria-label','title'].forEach(a=>{const v=el.getAttribute(a);if(v){const k=v.trim(),t=ABRA_L.tr(k,M.lang,M.dict[k]);if(t!==k)el.setAttribute(a,t)}}))};
M.addDict(`Home|హోమ్|होम
My trips|నా ట్రిప్‌లు|मेरी ट्रिप
Account|ఖాతా|खाता
Alerts|హెచ్చరికలు|सूचनाएँ
Notifications|నోటిఫికేషన్లు|सूचनाएँ
Search buses|బస్సులు వెతకండి|बसें खोजें
From|నుండి|से
To|వరకు|तक
Date|తేదీ|तारीख
Today|ఈరోజు|आज
Tomorrow|రేపు|कल
Offers|ఆఫర్లు|ऑफ़र
Popular routes|ప్రసిద్ధ మార్గాలు|लोकप्रिय रूट
Select seats|సీట్లు ఎంచుకోండి|सीटें चुनें
Seats left|మిగిలిన సీట్లు|सीटें बाकी
Boarding point|బోర్డింగ్ పాయింట్|बोर्डिंग पॉइंट
Dropping point|డ్రాపింగ్ పాయింట్|ड्रॉपिंग पॉइंट
Passenger details|ప్రయాణికుల వివరాలు|यात्री विवरण
Continue|కొనసాగించు|जारी रखें
Pay now|ఇప్పుడు చెల్లించండి|अभी भुगतान करें
Payment|చెల్లింపు|भुगतान
Booking confirmed|బుకింగ్ నిర్ధారించబడింది|बुकिंग पक्की हुई
Your ticket|మీ టికెట్|आपका टिकट
Upcoming|రాబోయేవి|आगामी
Completed|పూర్తయినవి|पूर्ण
Cancelled|రద్దయినవి|रद्द
Track bus|బస్సును ట్రాక్ చేయండి|बस ट्रैक करें
Cancel booking|బుకింగ్ రద్దు|बुकिंग रद्द करें
Share trip|ట్రిప్ షేర్ చేయండి|ट्रिप शेयर करें
Help and support|సహాయం మరియు మద్దతు|सहायता
Sign in|సైన్ ఇన్|साइन इन
Sign out|సైన్ అవుట్|साइन आउट
Language|భాష|भाषा
Close|మూసివేయి|बंद करें
Cancel|రద్దు|रद्द करें
Confirm|నిర్ధారించు|पुष्टि करें
Save|సేవ్ చేయి|सहेजें
Apply|వర్తింపజేయి|लागू करें
Coupon code|కూపన్ కోడ్|कूपन कोड
Fare|ఛార్జీ|किराया
Total|మొత్తం|कुल
Hold to send SOS|SOS పంపడానికి నొక్కి పట్టుకోండి|SOS भेजने के लिए दबाए रखें
Emergency|అత్యవసరం|आपातकाल
Today's trips|ఈరోజు ట్రిప్‌లు|आज की ट्रिप
Passengers|ప్రయాణికులు|यात्री
Check in|చెక్ ఇన్|चेक इन
Checked in|చెక్ ఇన్ అయ్యారు|चेक इन हुआ
Start boarding|బోర్డింగ్ ప్రారంభించండి|बोर्डिंग शुरू करें
Start trip|ట్రిప్ ప్రారంభించండి|ट्रिप शुरू करें
Report delay|ఆలస్యం నివేదించండి|देरी बताएँ
End trip|ట్రిప్ ముగించండి|ट्रिप खत्म करें
Resume trip|ట్రిప్ కొనసాగించండి|ट्रिप फिर शुरू करें
Scan ticket|టికెట్ స్కాన్ చేయండి|टिकट स्कैन करें
Profile|ప్రొఫైల్|प्रोफ़ाइल
No trips today|ఈరోజు ట్రిప్‌లు లేవు|आज कोई ट्रिप नहीं
Next trips|తదుపరి ట్రిప్‌లు|अगली ट्रिप
Stops|స్టాప్‌లు|स्टॉप
Live|లైవ్|लाइव
Scheduled|షెడ్యూల్ అయింది|निर्धारित
Boarding|బోర్డింగ్|बोर्डिंग
In transit|ప్రయాణంలో|रास्ते में
Delayed|ఆలస్యమైంది|देरी से
Arrived|చేరుకుంది|पहुँच गई
Confirmed|నిర్ధారించబడింది|पुष्ट
Open|తెరిచి ఉంది|खुला
Acknowledged|గుర్తించబడింది|स्वीकार किया
Resolved|పరిష్కరించబడింది|हल हुआ
Mark all read|అన్నీ చదివినట్లు గుర్తించు|सभी को पढ़ा हुआ करें
Demo|డెమో|डेमो
Portrait|నిలువు|लंबवत
Landscape|అడ్డం|क्षैतिज
Light|లైట్|लाइट
Dark|డార్క్|डार्क
Reset data|డేటా రీసెట్|डेटा रीसेट
Admin app|అడ్మిన్ యాప్|एडमिन ऐप
Client portal|క్లయింట్ పోర్టల్|क्लाइंट पोर्टल
Customer app|కస్టమర్ యాప్|ग्राहक ऐप
Driver app|డ్రైవర్ యాప్|ड्राइवर ऐप`);

/* ---------- stage, demo bar, live sync ---------- */
M.theme=localStorage.getItem('abra_m_theme')||'light';M.land=false;
M.boot=(app,render)=>{document.documentElement.setAttribute('data-theme',M.theme);document.documentElement.lang=M.lang;
document.body.innerHTML=`<div class="stage"><div class="dbar closed" id="dbar"></div><div class="phone" id="phone"></div></div>`;
M.drawBar=()=>{const others=Object.entries({admin:'Admin app',client:'Client portal',customer:'Customer app',driver:'Driver app',website:'Website'}).filter(([k])=>k!==app);
M.$('#dbar').innerHTML=`<button class="dtog" data-a="m_bar">${M.ic('info',14)} Demo</button><button class="${M.land?'':'on'}" data-a="m_or" data-v="p">Portrait</button><button class="${M.land?'on':''}" data-a="m_or" data-v="l">Landscape</button><button data-a="m_theme">${M.theme==='dark'?'Light':'Dark'}</button><select data-ch="m_lang" aria-label="Language">${ABRA_L.OPTS.map(([k,l])=>`<option value="${k}" ${M.lang===k?'selected':''}>${l}</option>`).join('')}</select>${others.map(([k,l])=>`<button data-a="m_open" data-v="${k}">${l} ${M.ic('chevR',12)}</button>`).join('')}<button data-a="m_reset">Reset data</button>`;M.translate(M.$('#dbar'))};
M.render=()=>{const ph=M.$('#phone');ph.classList.toggle('land',M.land);const keep=M.$('#scrim');const sc=M.$('.scr',ph),top=sc?sc.scrollTop:0;const st=M.beforeRender?M.beforeRender(ph):null;ph.innerHTML=render();if(keep)ph.appendChild(keep);const sc2=M.$('.scr',ph);if(sc2&&M.keepScroll)sc2.scrollTop=top;M.keepScroll=false;M.translate(ph);if(M.afterRender)M.afterRender(ph,st)};
M.drawBar();M.render();
AbraStore.on(()=>{const ae=document.activeElement;if(ae&&ae.matches('input,textarea,select')&&M.$('#phone').contains(ae)){M.pend=1;return}M.keepScroll=true;M.render()});
document.addEventListener('focusout',()=>{if(M.pend){M.pend=0;setTimeout(()=>{M.keepScroll=true;M.render()},0)}})};
M.save=src=>{AbraStore.save(src)};
M.A={m_bar:()=>M.$('#dbar').classList.toggle('closed'),m_or:v=>{M.land=v==='l';M.render();M.drawBar()},m_theme:()=>{M.theme=M.theme==='dark'?'light':'dark';localStorage.setItem('abra_m_theme',M.theme);document.documentElement.setAttribute('data-theme',M.theme);M.drawBar()},
m_lang:v=>{M.lang=v;localStorage.setItem('abra_m_lang',v);document.documentElement.lang=v;M.render();M.drawBar()},m_open:v=>window.open(AbraStore.apps[v],'abra_'+v),
m_reset:()=>{if(confirm('Reset the shared demo data for all four apps?')){AbraStore.reset();M.render()}},sheet_x:()=>M.closeSheet()};
/* ---------- proof attachments for the phone apps (shared with the admin and client through DB.files) ---------- */
M.PF_MAX=600*1024;M.PF_TYPES=['image/png','image/jpeg','image/webp','image/gif','application/pdf','text/plain','text/csv'];
M.fsize=n=>n<1024?n+' B':n<1048576?Math.round(n/1024)+' KB':(n/1048576).toFixed(1)+' MB';
M.proofField=(id,req,label)=>`<div class="doc"><b>${M.esc(label||'Screenshot or file')}${req?' *':''}</b><div class="sm m">Picture, PDF or text file, up to 5 files and 600 KB each. You and Abra can view or download it later.</div><input type="file" id="f_${id}" multiple accept="image/*,application/pdf,.txt,.csv" data-ch="pf_pick" style="margin-top:6px;max-width:100%"><div id="pfl_${id}" class="sm"></div><div class="err hide" id="e_${id}"></div></div>`;
M.pfErr=(id,m)=>{const e=document.getElementById('e_'+id);if(e){e.textContent=m||'';e.classList.toggle('hide',!m)}return!m};
M.fileToData=f=>new Promise((res,rej)=>{const rd=new FileReader();rd.onerror=()=>rej(new Error('Could not read '+f.name));rd.onload=()=>{if(!/^image\/(png|jpeg|webp)$/.test(f.type)||f.size<250*1024)return res({data:rd.result,type:f.type,size:f.size});
 const im=new Image();im.onerror=()=>res({data:rd.result,type:f.type,size:f.size});im.onload=()=>{const k=Math.min(1,1280/Math.max(im.width,im.height)),c=document.createElement('canvas');c.width=Math.round(im.width*k);c.height=Math.round(im.height*k);c.getContext('2d').drawImage(im,0,0,c.width,c.height);const d=c.toDataURL('image/jpeg',.72);res({data:d,type:'image/jpeg',size:Math.round(d.length*.75)})};im.src=rd.result};rd.readAsDataURL(f)});
M.readProofs=async(id,req,by)=>{const inp=document.getElementById('f_'+id),fs=inp?[...inp.files]:[];
if(req&&!fs.length){M.pfErr(id,'Attach at least one file');return null}
if(fs.length>5){M.pfErr(id,'Attach 5 files at most');return null}
const out=[];for(const f of fs){if(!M.PF_TYPES.includes(f.type)){M.pfErr(id,f.name+': use a picture, PDF or text file');return null}
 let r;try{r=await M.fileToData(f)}catch(e){M.pfErr(id,e.message);return null}
 if(r.size>M.PF_MAX){M.pfErr(id,f.name+' is '+M.fsize(r.size)+'. The limit is 600 KB.');return null}out.push({name:f.name,...r})}
M.pfErr(id,'');const d=AbraStore.get();d.files=d.files||[];return out.map(o=>{const fid=AbraStore.uid('FL');d.files.push({id:fid,name:o.name,type:o.type,size:o.size,data:o.data,by:by||'App user',at:new Date().toISOString()});return fid})};
M.fchips=ids=>(ids||[]).map(id=>{const f=((AbraStore.get()||{}).files||[]).find(x=>x.id===id);return f?`<button class="ch" data-a="file_view" data-v="${M.esc(id)}">${M.esc(f.name)} (${M.fsize(f.size)})</button>`:''}).join(' ');
M.blobUrl=f=>{try{const p=f.data.split(','),b=atob(p[1]),a=new Uint8Array(b.length);for(let i=0;i<b.length;i++)a[i]=b.charCodeAt(i);return URL.createObjectURL(new Blob([a],{type:f.type}))}catch(e){return f.data}};
Object.assign(M.A,{
pf_pick:(v,el)=>{const l=document.getElementById('pfl_'+el.id.slice(2));if(l)l.innerHTML=[...el.files].map(f=>`<div>${M.esc(f.name)} <span class="m">${M.fsize(f.size)}</span></div>`).join('')},
file_view:v=>{const f=((AbraStore.get()||{}).files||[]).find(x=>x.id===v);if(!f)return M.toast('This file is no longer available');const u=M.blobUrl(f);
 const body=/^image\//.test(f.type)?`<img src="${f.data}" alt="${M.esc(f.name)}" style="max-width:100%;border-radius:12px">`:f.type==='application/pdf'?`<iframe src="${u}" title="${M.esc(f.name)}" style="width:100%;height:300px;border:1px solid var(--ln);border-radius:12px"></iframe>`:`<pre class="doc" style="white-space:pre-wrap">${M.esc((()=>{try{return atob(f.data.split(',')[1]||'')}catch(e){return''}})())}</pre>`;
 M.sheet(f.name,`<div class="sm m">${M.fsize(f.size)} · ${M.esc(f.by||'')}</div>${body}`,`<button class="cta gh" data-a="sheet_x">Close</button><a class="cta" download="${M.esc(f.name)}" href="${u}">Download</a>`)}});
document.addEventListener('click',e=>{const el=e.target.closest('[data-a]');if(!el||el.hasAttribute('disabled'))return;const f=M.A[el.dataset.a];if(f)f(el.dataset.v,el,e);else console.warn('No action',el.dataset.a)});
document.addEventListener('change',e=>{const t=e.target;if(t.dataset&&t.dataset.ch&&M.A[t.dataset.ch])M.A[t.dataset.ch](t.type==='checkbox'?t.checked:t.value,t)});
document.addEventListener('keydown',e=>{if(e.key==='Escape')M.closeSheet()});
})();
