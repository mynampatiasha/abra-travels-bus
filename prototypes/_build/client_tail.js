
/* ===================== 4d. CONNECTED MODE (client) =====================
   Shares one demo database with the admin, customer and driver prototypes (shared/abra_store.js). */
Object.assign(EDIT_MAP,{busList:'bus_edit',fares:'fare_edit',schedules:'sch_edit',opStaff:'rec_edit_ops',routes:'rt_edit'});
['commissions','cities','places','busTypes','docTypes','questions','faqs','pages','banners','offers','staff'].forEach(k=>delete EDIT_MAP[k]);
Object.assign(NO_DEL,{trips:'Cancel a trip instead, so passengers get their refunds.',busList:'Mark the bus for maintenance instead, so trip history stays.',routes:'Routes are kept for trip history.',opUsers:'Deactivate users instead.',placeReqs:'Requests stay for the record.'});
['offers','inbox'].forEach(k=>NO_ADD.add(k));
['cm_calc','dop','d_reset','open_app','au_in','au_inv','au_back','au_acc','up_ex','up_go','kstep','cs_stmt','tr_man','lay_bus','ltool'].forEach(a=>SAFE_A.add(a));
const _rtEdit=A.rt_edit;A.rt_edit=v=>{if(byId(DB.routes,v).operatorId!==S.op)return toast('This is a shared Abra route. Copy it to change the stops.');_rtEdit(v)};
const _rC=render;render=function(){_rC();AbraStore.set(DB);AbraStore.save('client')};
AbraStore.on(d=>{DB=d;if(!S.op)return render();const ae=document.activeElement;if(ae&&ae.matches('.scroll input,.scroll textarea,.scroll select')){S._pend=1;return}render();if(d._by&&!/live|client/.test(d._by))toast('Updated by the '+d._by+' app')});
document.addEventListener('focusout',()=>{if(S._pend){S._pend=0;setTimeout(render,0)}});
const _rA=render;render=function(){if(!S.op||!ME()){S.op=null;CH.length=0;document.documentElement.setAttribute('data-theme',S.theme);$('#app').innerHTML=authHtml();translate($('#app'));$('#demoBtn').textContent='Demo controls';translate($('#demoBtn'));if(S.demo)drawDemo();return}_rA()};
A.signout=()=>{S.op=null;S.pop=null;S.authInv=null;persist();render();toast('Signed out')};
A.open_app=v=>window.open(AbraStore.apps[v],'abra_'+v);
A.dop=v=>{S.op=v;S.role='SUPER_ADMIN';persist();S.ui={};navigate(approved()?'dashboard':'kyc')};
A.d_reset=()=>confirmD({t:'Reset the shared demo data?',msg:'All four apps go back to the starting data. Open apps refresh by themselves.',ok:'Reset',tone:'dg',run:()=>{DB=AbraStore.reset();if(S.op&&!ME())S.op=null;S.t={};S.ui={};render();toast('Shared data reset')}});
drawDemo=function(){$('#demo').innerHTML=`<div class="row bt"><b>Demo controls</b><button class="ib" data-a="demo_toggle" aria-label="Close">${ic('x')}</button></div>
<h4>Signed in as</h4><div class="fd"><label for="f_dop">Bus company</label><select id="f_dop" data-ch="dop">${S.op?'':'<option value="">Not signed in</option>'}${DB.operators.map(o=>`<option value="${o.id}" ${o.id===S.op?'selected':''}>${esc(o.name)} · ${o.kyc==='APPROVED'?lab(o.status):'KYC '+lab(o.kyc).toLowerCase()}</option>`).join('')}</select></div>
<h4>Role (changes menus and buttons)</h4><div class="row rw">${Object.entries(ROLES).map(([k,l])=>`<button class="ch ${S.role===k?'on':''}" data-a="role" data-v="${k}">${esc(l)}</button>`).join('')}</div>
<h4>Screen layout</h4><div class="row rw">${[['auto','Auto (fits screen)'],['h','Horizontal'],['v','Vertical']].map(([k,l])=>`<button class="ch ${S.orient===k?'on':''}" data-a="orient" data-v="${k}">${l}</button>`).join('')}</div>
<h4>Appearance and language</h4><div class="row rw"><button class="ch ${S.theme==='light'?'on':''}" data-a="theme">Light</button><button class="ch ${S.theme==='dark'?'on':''}" data-a="theme">Dark</button>${[['en','English'],['te','Telugu'],['hi','Hindi']].map(([k,l])=>`<button class="ch ${S.lang===k?'on':''}" data-a="lang" data-v="${k}">${l}</button>`).join('')}</div>
<h4>Screen state</h4><div class="row rw">${[['ok','Normal'],['loading','Slow load'],['empty','Empty lists'],['error','Error + retry']].map(([k,l])=>`<button class="ch ${S.sim===k?'on':''}" data-a="sim" data-v="${k}">${l}</button>`).join('')}</div>
<h4>Connected apps</h4><div class="row rw">${[['admin','Admin app'],['customer','Customer app'],['driver','Driver app'],['website','Website']].map(([k,l])=>`<button class="ch" data-a="open_app" data-v="${k}">${l} ${ic('chevR',12)}</button>`).join('')}</div>
<h4>Data</h4><div class="row rw"><button class="ch" data-a="d_reset">Reset shared data</button>${S.op?'<button class="ch" data-a="signout">Sign out</button>':''}</div>
<p class="sm m mt2">All four apps share one demo database in this browser. Open them in other tabs: a change in one shows in the others.</p>`;translate($('#demo'))};
A.gs_run=q=>{q=q.toLowerCase().trim();const out=$('#gres');if(!out)return;if(q.length<2){out.innerHTML='<p class="m sm">Type at least 2 characters.</p>';return}
const m=(x,...f)=>f.some(k=>String(x[k]||'').toLowerCase().includes(q)),R=[];
myBk().filter(x=>m(x,'pnr','customer','phone','route')).slice(0,5).forEach(x=>R.push(['Booking',x.pnr+' - '+x.customer+' - '+x.route,'bookings','ticket']));
myTrips().filter(x=>m(x,'id','route','bus','driver')).slice(0,5).forEach(x=>R.push(['Trip',x.id+' - '+x.route+' - '+fd(x.depart),'trips','cal']));
myBuses().filter(x=>m(x,'reg','name')).slice(0,4).forEach(x=>R.push(['Bus',x.reg+' - '+x.name,'buses','bus']));
myCrew().filter(x=>m(x,'name','phone')).slice(0,4).forEach(x=>R.push(['Crew',x.name+' - '+lab(x.role),'crew','users']));
out.innerHTML=R.length?R.map(r=>`<button class="cta gh" style="justify-content:flex-start" data-a="gs_go" data-v="${esc(r[2])}">${ic(r[3],16)}<b>${r[0]}</b> <span class="m" style="font-weight:400">${esc(r[1])}</span></button>`).join(''):empty('No match','Search by PNR, phone, trip, bus or driver.')};

/* ===================== 4e. AI ASSISTANT (client portal, scripted demo) =====================
   Sees only this operator's data. Changes need the portal role's Edit access and a Confirm click.
   Real app: same NestJS ai-assistant module and Groq as the admin app, with operator-scoped tools. */
P.spark='M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9zM19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9z';P.mic='M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3zM19 10v2a7 7 0 01-14 0v-2M12 19v4M8 23h8';
const CAI={open:false,msgs:[],pend:{},pn:0,busy:false};
['cai_open','cai_x','cai_new','cai_send','cai_q','cai_ok','cai_no','cai_go','cai_mic'].forEach(a=>SAFE_A.add(a));
const CAL=(lg,en,te,hi)=>lg==='te'?te:lg==='hi'?hi:en;
const cdet=q=>/[ఀ-౿]/.test(q)?'te':/[ऀ-ॿ]/.test(q)?'hi':/\b(chupinchu|cheyyi|enti|kavali)\b/i.test(q)?'te':/\b(dikhao|batao|karo|kya|kitne)\b/i.test(q)?'hi':'en';
const cpend=o=>{const id='CP'+(++CAI.pn);CAI.pend[id]=Object.assign({st:'wait'},o);return id};
const cgo=(p,a,l)=>`<button class="cta gh sm" data-a="cai_go" data-v="${p}${a?'|'+a:''}">${esc(l)} ${ic('chevR',14)}</button>`;
const cdeny=(p,lg)=>CAL(lg,`Your portal role (${esc(ROLES[S.role])}) cannot change ${esc(PAGES[p].t)}, so I won't do this.`,`మీ పాత్ర (${esc(ROLES[S.role])}) ${esc(PAGES[p].t)} మార్చలేదు, కాబట్టి నేను ఇది చేయను.`,`आपकी भूमिका (${esc(ROLES[S.role])}) ${esc(PAGES[p].t)} नहीं बदल सकती, इसलिए मैं यह नहीं करूँगा।`);
const ctbl=(h,rows)=>`<div class="tw"><table class="dt"><thead><tr>${h.map(x=>`<th>${x}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${r.map(c=>`<td>${c}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
function routeIn(q){const R=myRoutes(),low=q.toLowerCase(),C=DB.cities.map(c=>c.name).filter(n=>low.includes(n.toLowerCase())).sort((a,b)=>low.indexOf(a.toLowerCase())-low.indexOf(b.toLowerCase()));if(C.length>=2)return R.find(r=>r.from===C[0]&&r.to===C[1])||null;if(C.length===1)return R.find(r=>r.from===C[0]||r.to===C[0])||null;return null}
function nextDay(){for(let k=1;k<8;k++){const d=new Date(NOW+k*DAY),L=myTrips().filter(t=>sameDay(t.depart,d)&&!['CANCELLED','ARRIVED'].includes(t.status));if(L.length)return{d,L}}return{d:new Date(NOW+DAY),L:[]}}
function cUnassigned(lg){const{d,L}=nextDay(),un=L.filter(t=>!t.driver),D=myDrivers(),plan=[];un.forEach(t=>{const f=D.find(x=>!conflict(x.name,t.depart,t.id)&&!plan.some(p=>p.drv===x.name&&Math.abs(new Date(byId(DB.trips,p.t).depart)-new Date(t.depart))<10*36e5));plan.push({t:t.id,drv:f?f.name:''})});
if(!un.length)return{html:CAL(lg,`Every trip on ${fd(d)} has a driver.`,`${fd(d)} న ప్రతి ట్రిప్‌కు డ్రైవర్ ఉన్నారు.`,`${fd(d)} की हर ट्रिप में ड्राइवर है।`),steps:[`get_my_trips(${d.toISOString().slice(0,10)}) → ${L.length}`]};
const k=plan.filter(p=>p.drv).length;let pend=null;if(k){if(!canEdit('trips'))return{html:cdeny('trips',lg)};pend=cpend({lg,page:'trips',desc:CAL(lg,`Assign ${k} driver(s) as suggested.`,`సూచించిన విధంగా ${k} డ్రైవర్లను కేటాయించాలి.`,`सुझाव के अनुसार ${k} ड्राइवर असाइन करें।`),run:()=>{plan.forEach(p=>{if(p.drv){byId(DB.trips,p.t).driver=p.drv;audit('AI: assigned driver '+p.drv,p.t)}});render();return CAL(lg,`Assigned ${k} driver(s). They see the trips in the driver app now.`,`${k} డ్రైవర్లను కేటాయించాను. వారు డ్రైవర్ యాప్‌లో చూస్తారు.`,`${k} ड्राइवर असाइन किए। वे ड्राइवर ऐप में देखेंगे।`)}})}
return{html:CAL(lg,`<b>${un.length}</b> trip(s) on ${fd(d)} have no driver. Suggested drivers (no clashes):`,`${fd(d)} న <b>${un.length}</b> ట్రిప్‌లకు డ్రైవర్ లేరు. సూచించిన డ్రైవర్లు:`,`${fd(d)} को <b>${un.length}</b> ट्रिप में ड्राइवर नहीं। सुझाए गए ड्राइवर:`)+ctbl(['Trip','Route','Departs','Suggested driver'],plan.map(p=>{const t=byId(DB.trips,p.t);return[t.id,esc(t.route),ft(t.depart),p.drv?esc(p.drv):chip('No free driver','r')]})),pend,steps:[`get_my_trips(${d.toISOString().slice(0,10)}) → ${L.length}`,`find_free_drivers() → ${D.length} drivers checked`,'check_conflicts() → done']}}
function cSchedule(q,lg){const r=routeIn(q);if(!r)return{html:CAL(lg,'Which route? For example: "Create a daily schedule Bengaluru to Hyderabad at 21:30".','ఏ మార్గం? ఉదా: "బెంగళూరు నుండి హైదరాబాద్ రోజూ 21:30 కి షెడ్యూల్".','कौन सा रूट? जैसे: "बेंगलुरु से हैदराबाद रोज़ 21:30 बजे शेड्यूल"।')};
let tm=(q.match(/\b(\d{1,2})[:.](\d{2})\b/)||[]);let time=tm.length?String(tm[1]).padStart(2,'0')+':'+tm[2]:null;const pm=q.match(/\b(\d{1,2})\s*(am|pm)\b/i);if(!time&&pm){let h=+pm[1]%12+(pm[2].toLowerCase()==='pm'?12:0);time=String(h).padStart(2,'0')+':00'}time=time||'21:30';
const days=/weekend/i.test(q)?['Sat','Sun']:/weekday/i.test(q)?['Mon','Tue','Wed','Thu','Fri']:(q.match(/\b(mon|tue|wed|thu|fri|sat|sun)/gi)||[]).map(d=>d[0].toUpperCase()+d.slice(1,3).toLowerCase());const D=days.length?days:WD.slice();
const reg=(q.toUpperCase().match(/[A-Z]{2}\s?\d{2}\s?[A-Z]{1,3}\s?\d{4}/)||[])[0],B=myBuses().filter(b=>b.status==='ACTIVE'),bus=reg?B.find(b=>b.reg.replace(/\s/g,'')===reg.replace(/\s/g,'')):B[0];if(!bus)return{html:CAL(lg,'You need an approved bus first.','ముందుగా ఆమోదించిన బస్సు కావాలి.','पहले एक स्वीकृत बस चाहिए।')};
if(!canEdit('schedules'))return{html:cdeny('schedules',lg)};const f=DB.fares.find(x=>x.operatorId===S.op&&x.routeId===r.id&&x.seatType===bus.type);
return{html:CAL(lg,'Here is the schedule I will create. Trips are made as drafts; you publish them in Trips.','నేను సృష్టించే షెడ్యూల్ ఇది. ట్రిప్‌లు డ్రాఫ్ట్‌గా తయారవుతాయి.','मैं यह शेड्यूल बनाऊँगा। ट्रिप ड्राफ़्ट के रूप में बनेंगी।'),steps:['find_route() → '+r.name,'find_bus() → '+bus.reg,'get_fare() → '+(f?money(f.weekday):'none')],
pend:cpend({lg,page:'schedules',desc:`${esc(r.name)} · ${time} · ${D.length===7?'every day':D.join(', ')} · ${esc(bus.reg)} · ${f?money(f.weekday):'Rs 1,000 (no fare set)'}`,run:()=>{const s={id:uid('SC'),operatorId:S.op,routeId:r.id,route:r.name,busId:bus.id,bus:bus.reg,time,days:D,from:new Date().toISOString().slice(0,10),to:new Date(NOW+60*DAY).toISOString().slice(0,10),status:'ACTIVE',fare:f?f.weekday:100000};DB.schedules.push(s);audit('AI: created schedule '+r.name,s.id);A.sc_gen(s.id);return CAL(lg,'Schedule saved and draft trips created for the next 14 days. Publish them in Trips.','షెడ్యూల్ సేవ్ అయింది, 14 రోజుల డ్రాఫ్ట్ ట్రిప్‌లు తయారయ్యాయి.','शेड्यूल सेव हुआ और 14 दिन की ड्राफ़्ट ट्रिप बनीं।')+`<div>${cgo('trips','','Open trips')}</div>`}})}}
function cFare(q,lg){const r=routeIn(q),amt=Number((q.match(/(?:rs\.?|₹|to)\s*(\d{3,5})/i)||q.match(/\b(\d{3,5})\b/)||[])[1]),kind=/weekend/i.test(q)?'weekend':/festival/i.test(q)?'festival':'weekday';
if(!r||!amt)return{html:CAL(lg,'Tell me the route and the amount, for example: "Set the weekend fare Bengaluru to Hyderabad to 1200".','మార్గం, మొత్తం చెప్పండి, ఉదా: "బెంగళూరు నుండి హైదరాబాద్ వీకెండ్ ఛార్జీ 1200".','रूट और राशि बताइए, जैसे: "बेंगलुरु से हैदराबाद वीकेंड किराया 1200"।')};
if(!canEdit('fares'))return{html:cdeny('fares',lg)};const L=DB.fares.filter(f=>f.operatorId===S.op&&f.routeId===r.id&&f.status==='ACTIVE');const tp=(myBuses()[0]||{}).type;
const p=price(amt*100,r.name,(L[0]||{}).seatType||tp);
return{html:CAL(lg,`Customers will then pay <b>${money(p.total)}</b> per seat (your fare ${money(p.fare)} + commission ${money(p.cm)} + GST + fee).`,`కస్టమర్లు ఒక్కో సీటుకు <b>${money(p.total)}</b> చెల్లిస్తారు.`,`ग्राहक प्रति सीट <b>${money(p.total)}</b> देंगे।`),steps:['get_fares('+r.name+') → '+L.length,'price_preview() → '+money(p.total)],
pend:cpend({lg,page:'fares',desc:CAL(lg,`Set the <b>${kind}</b> fare on ${esc(r.name)} to <b>${money(amt*100)}</b>${L.length?' for '+L.map(f=>esc(f.seatType)).join(', '):' (new fare for '+esc(tp)+')'}.`,`${esc(r.name)} లో <b>${kind}</b> ఛార్జీ <b>${money(amt*100)}</b> చేయాలి.`,`${esc(r.name)} पर <b>${kind}</b> किराया <b>${money(amt*100)}</b> करें।`),run:()=>{if(L.length)L.forEach(f=>f[kind]=amt*100);else DB.fares.push({id:uid('FR'),operatorId:S.op,routeId:r.id,route:r.name,seatType:tp,weekday:amt*100,weekend:Math.round(amt*110),festival:Math.round(amt*125),from:new Date().toISOString().slice(0,10),status:'ACTIVE',[kind]:amt*100});audit('AI: changed '+kind+' fare '+r.name,'');render();return CAL(lg,'Fare saved. New trips use it.','ఛార్జీ సేవ్ అయింది.','किराया सेव हो गया।')}})}}
function cOcc(lg){const up=myTrips().filter(t=>new Date(t.depart)>NOW&&new Date(t.depart)-NOW<7*DAY&&!['CANCELLED','DRAFT'].includes(t.status)),m={};up.forEach(t=>{m[t.route]=m[t.route]||{r:t.route,b:0,s:0,n:0};m[t.route].b+=t.booked;m[t.route].s+=t.seats;m[t.route].n++});const L=Object.values(m).map(x=>({...x,o:Math.round(x.b/x.s*100)})).sort((a,b)=>a.o-b.o);
if(!L.length)return{html:CAL(lg,'No trips in the next 7 days.','రాబోయే 7 రోజుల్లో ట్రిప్‌లు లేవు.','अगले 7 दिनों में कोई ट्रिप नहीं।')};const lo=L[0];
return{html:CAL(lg,`Occupancy for the next 7 days. Lowest: <b>${esc(lo.r)}</b> at ${lo.o}%. Ideas: request an offer for that route, lower the weekday fare a little, or run fewer trips on quiet days.`,`రాబోయే 7 రోజుల ఆక్యుపెన్సీ. తక్కువ: <b>${esc(lo.r)}</b> ${lo.o}%. సూచనలు: ఆఫర్ అభ్యర్థించండి, ఛార్జీ కొంచెం తగ్గించండి.`,`अगले 7 दिनों की ऑक्यूपेंसी। सबसे कम: <b>${esc(lo.r)}</b> ${lo.o}%। सुझाव: ऑफ़र माँगें, किराया थोड़ा घटाएँ।`)+ctbl(['Route','Trips','Booked','Occupancy'],L.map(x=>[esc(x.r),x.n,x.b+'/'+x.s,x.o+'%'])),chips:['Draft a 10% offer for '+lo.r],steps:['get_my_trips(next 7 days) → '+up.length,'group_by(route)']}}
function cEarn(lg,days){const B=myBk().filter(b=>(NOW-new Date(b.at))/DAY<=days&&b.status!=='CANCELLED'),G=B.reduce((a,b)=>a+b.amount,0),C=B.reduce((a,b)=>a+b.commission,0),RF=DB.refunds.filter(r=>r.operator===ME().name&&r.bearer==='Operator'&&(NOW-new Date(r.at))/DAY<=days).reduce((a,r)=>a+r.amount,0);
return{html:CAL(lg,`Last ${days} days: <b>${B.length}</b> bookings, gross ${money(G)}, Abra commission ${money(C)}, refunds you bore ${money(RF)}. <b>Your net: ${money(G-C-RF)}</b>.`,`గత ${days} రోజులు: <b>${B.length}</b> బుకింగ్‌లు, స్థూల ${money(G)}, కమీషన్ ${money(C)}, రీఫండ్‌లు ${money(RF)}. <b>మీ నికరం: ${money(G-C-RF)}</b>.`,`पिछले ${days} दिन: <b>${B.length}</b> बुकिंग, सकल ${money(G)}, कमीशन ${money(C)}, रिफंड ${money(RF)}। <b>आपका शुद्ध: ${money(G-C-RF)}</b>।`)+`<div>${cgo('earnings','','Open earnings')}</div>`,steps:['get_my_bookings(last '+days+' days) → '+B.length,'get_my_refunds() → '+money(RF)]}}
function cDocs(lg){const bi=myBuses().filter(b=>new Date(b.insExp)-NOW<30*DAY),dl=myCrew().filter(s=>s.licExp&&new Date(s.licExp)-NOW<30*DAY);if(!bi.length&&!dl.length)return{html:CAL(lg,'Nothing expires in the next 30 days.','రాబోయే 30 రోజుల్లో ఏదీ గడువు ముగియదు.','अगले 30 दिनों में कुछ भी खत्म नहीं हो रहा।')};
return{html:CAL(lg,'Expiring within 30 days:','30 రోజుల్లో గడువు ముగిసేవి:','30 दिनों में खत्म होने वाले:')+ctbl(['Item','Name','Valid till'],bi.map(b=>['Insurance',esc(b.reg),fd(b.insExp)]).concat(dl.map(s=>['Driving licence',esc(s.name),fd(s.licExp)]))),steps:['get_my_buses()','get_my_crew()']}}
function cOffer(q,lg){const r=routeIn(q),pc=Number((q.match(/(\d{1,2})\s*%/)||[])[1]||10);if(!canEdit('offers'))return{html:cdeny('offers',lg)};const code=((r?r.from.slice(0,3)+r.to.slice(0,3):ME().name.split(' ')[0].slice(0,6))+pc).toUpperCase();
return{html:CAL(lg,'Here is a draft. You pay the discount; Abra reviews it before customers see it.','ఇది డ్రాఫ్ట్. తగ్గింపు మీరు భరిస్తారు; అబ్రా సమీక్షిస్తుంది.','यह ड्राफ़्ट है। छूट आप देंगे; अब्रा पहले जाँचेगा।'),pend:cpend({lg,page:'offers',desc:`<b>${esc(code)}</b>: ${pc}% off up to ₹150${r?' on '+esc(r.name):' on '+esc(ME().name)+' buses'}, valid 30 days, 300 uses.`,run:()=>{DB.offers.unshift({id:uid('OF'),code,desc:pc+'% off up to Rs 150'+(r?' on '+r.name:' on '+ME().name+' buses'),type:'PERCENT',value:pc*100,maxDisc:15000,minAmt:0,status:'DRAFT',funder:'OPERATOR',perUser:1,limit:300,used:0,from:new Date().toISOString().slice(0,10),to:new Date(NOW+30*DAY).toISOString().slice(0,10),scope:'Operator: '+ME().name,newOnly:false,terms:['Valid on '+ME().name+' buses only.']});audit('AI: requested offer '+code,'');render();return CAL(lg,'Sent to Abra for approval. You will be notified.','ఆమోదం కోసం అబ్రాకు పంపాను.','अनुमोदन के लिए अब्रा को भेजा।')}})}}
function cToday(lg){const T=myTrips().filter(t=>sameDay(t.depart,NOW)),B=myBk().filter(b=>sameDay(b.at,NOW)),run=T.filter(t=>['BOARDING','IN_TRANSIT','DELAYED'].includes(t.status));
return{html:CAL(lg,`Today: <b>${T.length}</b> trip(s), <b>${run.length}</b> running, <b>${T.filter(t=>t.status==='DELAYED').length}</b> delayed, <b>${B.length}</b> new booking(s).`,`ఈరోజు: <b>${T.length}</b> ట్రిప్‌లు, <b>${run.length}</b> నడుస్తున్నాయి, <b>${T.filter(t=>t.status==='DELAYED').length}</b> ఆలస్యం, <b>${B.length}</b> కొత్త బుకింగ్‌లు.`,`आज: <b>${T.length}</b> ट्रिप, <b>${run.length}</b> चल रही, <b>${T.filter(t=>t.status==='DELAYED').length}</b> देरी से, <b>${B.length}</b> नई बुकिंग।`)+(T.length?ctbl(['Trip','Route','Departs','Driver','Booked','Status'],T.map(t=>[t.id,esc(t.route),ft(t.depart),esc(t.driver||'-'),t.booked+'/'+t.seats,chip(t.status)])):''),chips:['Which trips tomorrow have no driver?','Earnings this week'],steps:['get_my_trips(today) → '+T.length,'get_my_bookings(today) → '+B.length]}}
function caiAnswer(q,lg){const H=r=>r.test(q);
if(H(/\b(help|what can you)\b|ఏమి చేయగల|क्या कर सक/i))return{html:CAL(lg,'I can show today\'s trips, find trips without a driver and assign drivers, create schedules, change fares, explain occupancy, show earnings and expiring documents, and draft offers. I only see your company, and I ask before changing anything.','నేను మీ కంపెనీ ట్రిప్‌లు, డ్రైవర్ కేటాయింపు, షెడ్యూల్‌లు, ఛార్జీలు, ఆక్యుపెన్సీ, ఆదాయం, పత్రాల గడువు, ఆఫర్‌లలో సహాయం చేస్తాను.','मैं आपकी कंपनी की ट्रिप, ड्राइवर असाइनमेंट, शेड्यूल, किराया, ऑक्यूपेंसी, कमाई, दस्तावेज़ और ऑफ़र में मदद करता हूँ।')};
if(H(/no driver|without (a )?driver|unassigned|assign|డ్రైవర్ లేని|ड्राइवर नहीं/i))return cUnassigned(lg);
if(H(/schedule|షెడ్యూల్|शेड्यूल/i))return cSchedule(q,lg);
if(H(/fare|price|ఛార్జీ|ధర|किराया/i)&&H(/set|change|make|update|చేయ|మార్చ|करो|बदलो|\d{3,}/i))return cFare(q,lg);
if(H(/occupan|full|empty|low|ఆక్యుపెన్సీ|ఖాళీ|ऑक्यूपेंसी|खाली/i))return cOcc(lg);
if(H(/earn|revenue|income|money|ఆదాయం|సంపాదన|कमाई|आय/i))return cEarn(lg,H(/month|నెల|महीन/i)?30:7);
if(H(/expir|insurance|licen|document|గడువు|बीमा|लाइसेंस|दस्तावेज़/i))return cDocs(lg);
if(H(/offer|discount|coupon|ఆఫర్|ऑफ़र|छूट/i))return cOffer(q,lg);
if(H(/today|running|delay|live|ఈరోజు|ఆలస్య|आज|देरी/i))return cToday(lg);
return{html:CAL(lg,'I did not catch that. Try one of these:','నాకు అర్థం కాలేదు. వీటిలో ఒకటి ప్రయత్నించండి:','मैं समझ नहीं पाया। इनमें से कोई आज़माएँ:'),chips:caiSugg().slice(0,4)}}
const caiSugg=()=>['What is happening today?','Which trips tomorrow have no driver?','Create a daily schedule Bengaluru to Hyderabad at 21:30','Set the weekend fare Bengaluru to Hyderabad to 1200','Why is occupancy low this week?','Earnings this week','Which documents expire soon?','Draft a 10% offer'];
function caiPendHtml(id){const p=CAI.pend[id];if(!p)return'';const lg=p.lg;if(p.st==='wait')return`<div class="pend"><b>${ic('alert',14)} ${CAL(lg,'Needs your confirmation','మీ నిర్ధారణ అవసరం','आपकी पुष्टि चाहिए')}</b><p class="mt2">${p.desc}</p><div class="row mt2"><button class="cta sm" data-a="cai_ok" data-v="${id}">${CAL(lg,'Confirm','నిర్ధారించు','पुष्टि करें')}</button><button class="cta gh sm" data-a="cai_no" data-v="${id}">${CAL(lg,'Cancel','రద్దు','रद्द करें')}</button></div></div>`;
if(p.st==='run')return`<div class="pend"><span class="dots"><i></i><i></i><i></i></span></div>`;if(p.st==='done')return`<div class="pend ok">${ic('check',14)} ${p.res}</div>`;if(p.st==='fail')return`<div class="pend no">${esc(p.res)}</div>`;return`<div class="pend no">${CAL(lg,'Cancelled. Nothing was changed.','రద్దు చేశారు.','रद्द किया।')}</div>`}
function caiMsg(m){if(m.who==='me')return`<div class="msg me">${m.html}</div>`;if(m.typing)return`<div class="msg ai"><span class="dots"><i></i><i></i><i></i></span></div>`;
return`<div class="msg ai">${m.html}${m.pend?caiPendHtml(m.pend):''}${m.steps&&m.steps.length?`<details class="steps"><summary>What I checked (${m.steps.length})</summary><ol>${m.steps.map(s=>`<li><code>${esc(s)}</code></li>`).join('')}</ol></details>`:''}${m.chips&&m.chips.length?`<div class="chips">${m.chips.map(c=>`<button data-a="cai_q" data-v="${esc(c)}">${esc(c)}</button>`).join('')}</div>`:''}</div>`}
function drawCAI(){const r=$('#ai');if(!r)return;document.body.classList.toggle('ai-open',CAI.open);if(!CAI.open||!S.op){r.className='';r.innerHTML='';return}const keep=$('#cai_in')?$('#cai_in').value:'';r.className='open';
r.innerHTML=`<div class="aihd"><div class="row"><span class="aiic">${ic('spark',18)}</span><div><b>Partner AI assistant</b><div class="sm m">${esc(ME().name)}</div></div></div><div class="row"><button class="ib" data-a="cai_new" aria-label="New chat">${ic('plus',18)}</button><button class="ib" data-a="cai_x" aria-label="Close">${ic('x')}</button></div></div>
<div class="aibody" id="caib">${CAI.msgs.length?CAI.msgs.map(caiMsg).join(''):`<div class="msg ai">${CAL(S.lang,'Hi! I help you run your buses: drivers, schedules, fares, occupancy, earnings and offers. I only see your company, and I ask before changing anything.','నమస్తే! డ్రైవర్లు, షెడ్యూల్‌లు, ఛార్జీలు, ఆక్యుపెన్సీ, ఆదాయం, ఆఫర్‌లలో సహాయం చేస్తాను. మీ కంపెనీ డేటా మాత్రమే చూస్తాను.','नमस्ते! ड्राइवर, शेड्यूल, किराया, ऑक्यूपेंसी, कमाई और ऑफ़र में मदद करता हूँ। सिर्फ़ आपकी कंपनी का डेटा देखता हूँ।')}</div>`}</div>
<div class="aisug">${caiSugg().map(c=>`<button data-a="cai_q" data-v="${esc(c)}">${esc(c)}</button>`).join('')}</div>
<div class="aiin"><button class="ib" data-a="cai_mic" aria-label="Speak">${ic('mic',18)}</button><textarea id="cai_in" rows="1" placeholder="Ask in English, తెలుగు or हिन्दी..." aria-label="Message"></textarea><button class="cta sm" data-a="cai_send" aria-label="Send">${ic('send',16)}</button></div><div class="aift">Groq (demo answers) · Your role: ${esc(ROLES[S.role])}</div>`;
translate(r);const i=$('#cai_in');i.value=keep;const b=$('#caib');b.scrollTop=b.scrollHeight;if(!CAI.busy)i.focus()}
function caiAsk(q,force,label){q=String(q||'').trim();if(!q||CAI.busy)return;const lg=force||cdet(q);CAI.msgs.push({who:'me',html:esc(label||q)});const m={who:'ai',typing:true};CAI.msgs.push(m);CAI.busy=true;const e=$('#cai_in');if(e)e.value='';drawCAI();
setTimeout(()=>{try{Object.assign(m,caiAnswer(q,lg))}catch(err){console.error(err);m.html=CAL(lg,'Something went wrong. Nothing was changed.','లోపం వచ్చింది. ఏమీ మారలేదు.','गड़बड़ी हुई। कुछ नहीं बदला।')}m.typing=false;CAI.busy=false;drawCAI()},550+Math.random()*450)}
Object.assign(A,{cai_open:()=>{S.pop=null;CAI.open=!CAI.open;drawCAI()},cai_x:()=>{CAI.open=false;drawCAI()},cai_new:()=>{CAI.msgs=[];drawCAI()},cai_send:()=>{const e=$('#cai_in');caiAsk(e?e.value:'')},
cai_q:(v,el)=>caiAsk(v,S.lang==='en'?null:S.lang,el&&el.textContent!==v?el.textContent:v),
cai_ok:v=>{const p=CAI.pend[v];if(!p||p.st!=='wait')return;if(!canEdit(p.page)){p.st='fail';p.res=cdeny(p.page,p.lg).replace(/<[^>]+>/g,'');return drawCAI()}p.st='run';drawCAI();setTimeout(()=>{try{p.res=p.run();p.st='done'}catch(e){p.st='fail';p.res=e.message}drawCAI();render()},700)},
cai_no:v=>{const p=CAI.pend[v];if(p&&p.st==='wait'){p.st='no';drawCAI()}},
cai_go:v=>{const[p,a]=v.split('|');if(innerWidth<760||S.orient==='v'){CAI.open=false;drawCAI()}navigate(p,a)},
cai_mic:()=>{const SR=window.SpeechRecognition||window.webkitSpeechRecognition;if(!SR)return toast('Voice input is not supported in this browser');const r=new SR();r.lang={te:'te-IN',hi:'hi-IN'}[S.lang]||'en-IN';r.onresult=e=>caiAsk(e.results[0][0].transcript);r.onerror=()=>toast('Could not hear you');r.start();toast('Listening...')}});
document.addEventListener('keydown',e=>{if(e.target.id==='cai_in'&&e.key==='Enter'&&!e.shiftKey){e.preventDefault();A.cai_send()}});
const _rCAI=render;render=function(){_rCAI();if(CAI.open&&!S.op){CAI.open=false;drawCAI()}};

/* ---------- client portal words (added to the shared translation list) ---------- */
`Company|కంపెనీ|कंपनी
Fleet|ఫ్లీట్|बेड़ा
Network|నెట్‌వర్క్|नेटवर्क
Sales setup|అమ్మకాల సెటప్|बिक्री सेटअप
Money|డబ్బు|पैसा
KYC verification|KYC ధృవీకరణ|KYC सत्यापन
Company profile|కంపెనీ ప్రొఫైల్|कंपनी प्रोफ़ाइल
Seat layouts|సీట్ లేఅవుట్‌లు|सीट लेआउट
Drivers and crew|డ్రైవర్లు మరియు సిబ్బంది|ड्राइवर और स्टाफ़
Routes and stops|మార్గాలు మరియు స్టాప్‌లు|रूट और स्टॉप
Fares|ఛార్జీలు|किराये
Schedules|షెడ్యూల్‌లు|शेड्यूल
Earnings and settlements|ఆదాయం మరియు సెటిల్‌మెంట్‌లు|कमाई और सेटलमेंट
Live buses and safety|లైవ్ బస్సులు మరియు భద్రత|लाइव बसें और सुरक्षा
Partner portal|పార్ట్‌నర్ పోర్టల్|पार्टनर पोर्टल
Owner|యజమాని|मालिक
Manager|మేనేజర్|मैनेजर
Booking staff|బుకింగ్ సిబ్బంది|बुकिंग स्टाफ़
New trip|కొత్త ట్రిప్|नई ट्रिप
New route|కొత్త మార్గం|नया रूट
New fare|కొత్త ఛార్జీ|नया किराया
New schedule|కొత్త షెడ్యూల్|नया शेड्यूल
Add bus|బస్సు జోడించు|बस जोड़ें
Request a place|ప్రదేశం అభ్యర్థించు|स्थान का अनुरोध करें
Request an offer|ఆఫర్ అభ్యర్థించు|ऑफ़र का अनुरोध करें
Raise a query|ప్రశ్న అడగండి|सवाल उठाएँ
Create trips|ట్రిప్‌లు సృష్టించు|ट्रिप बनाएँ
Publish selected|ఎంచుకున్నవి ప్రచురించు|चुने हुए प्रकाशित करें
Save layout|లేఅవుట్ సేవ్|लेआउट सहेजें
Save route|మార్గం సేవ్|रूट सहेजें
Save fare|ఛార్జీ సేవ్|किराया सहेजें
Send for approval|ఆమోదం కోసం పంపు|स्वीकृति के लिए भेजें
Send to Abra|అబ్రాకు పంపు|अब्रा को भेजें
Send corrections|సవరణలు పంపు|सुधार भेजें
Submit for verification|ధృవీకరణకు సమర్పించు|सत्यापन के लिए जमा करें
Under verification|ధృవీకరణలో ఉంది|सत्यापन में
Bookings today|ఈరోజు బుకింగ్‌లు|आज की बुकिंग
Your earnings, 7 days|మీ ఆదాయం, 7 రోజులు|आपकी कमाई, 7 दिन
Upcoming trips|రాబోయే ట్రిప్‌లు|आगामी ट्रिप
Active buses|యాక్టివ్ బస్సులు|सक्रिय बसें
Drivers on duty|డ్యూటీలో డ్రైవర్లు|ड्यूटी पर ड्राइवर
Customer rating|కస్టమర్ రేటింగ్|ग्राहक रेटिंग
On sale|అమ్మకంలో|बिक्री पर
Drafts|డ్రాఫ్ట్‌లు|ड्राफ़्ट
Running now|ఇప్పుడు నడుస్తున్నాయి|अभी चल रही
Without a driver|డ్రైవర్ లేకుండా|बिना ड्राइवर
Not assigned|కేటాయించలేదు|असाइन नहीं
You get|మీకు వచ్చేది|आपको मिलेगा
Your share|మీ వాటా|आपका हिस्सा
Weekday|వారం రోజులు|सप्ताह के दिन
Weekend|వీకెండ్|सप्ताहांत
Festival|పండుగ|त्योहार
Customer pays (weekday)|కస్టమర్ చెల్లించేది (వారం రోజు)|ग्राहक देता है (सप्ताह के दिन)
Seat type|సీటు రకం|सीट प्रकार
Valid till|వరకు చెల్లుతుంది|तक मान्य
Days|రోజులు|दिन
Every day|ప్రతి రోజు|हर दिन
Distance|దూరం|दूरी
Duration|వ్యవధి|अवधि
Your trips|మీ ట్రిప్‌లు|आपकी ट्रिप
Your requests|మీ అభ్యర్థనలు|आपके अनुरोध
Places you can use|మీరు వాడగల ప్రదేశాలు|इस्तेमाल योग्य स्थान
Rules that apply to you|మీకు వర్తించే నియమాలు|आप पर लागू नियम
Portal users|పోర్టల్ వినియోగదారులు|पोर्टल उपयोगकर्ता
Add user|వినియోగదారుని జోడించు|उपयोगकर्ता जोड़ें
Running now (0)|ఇప్పుడు నడుస్తున్నవి (0)|अभी चल रही (0)
SOS history|SOS చరిత్ర|SOS इतिहास
Bank account for payouts|చెల్లింపుల కోసం బ్యాంక్ ఖాతా|भुगतान के लिए बैंक खाता
Save bank details|బ్యాంక్ వివరాలు సేవ్|बैंक विवरण सहेजें
Partner AI assistant|పార్ట్‌నర్ AI అసిస్టెంట్|पार्टनर AI असिस्टेंट
What is happening today?|ఈరోజు ఏమి జరుగుతోంది?|आज क्या हो रहा है?
Which trips tomorrow have no driver?|రేపు ఏ ట్రిప్‌లకు డ్రైవర్ లేరు?|कल किन ट्रिप में ड्राइवर नहीं है?
Why is occupancy low this week?|ఈ వారం ఆక్యుపెన్సీ ఎందుకు తక్కువ?|इस हफ़्ते ऑक्यूपेंसी कम क्यों है?
Earnings this week|ఈ వారం ఆదాయం|इस हफ़्ते की कमाई
Which documents expire soon?|ఏ పత్రాల గడువు త్వరలో ముగుస్తుంది?|कौन से दस्तावेज़ जल्द खत्म होंगे?
Draft a 10% offer|10% ఆఫర్ డ్రాఫ్ట్ చేయి|10% ऑफ़र का ड्राफ़्ट बनाओ
Sign in|సైన్ ఇన్|साइन इन
Continue with Google|Google తో కొనసాగించండి|Google से जारी रखें
Invited by Abra?|అబ్రా ఆహ్వానించిందా?|अब्रा ने आमंत्रित किया?
Accept your invitation|మీ ఆహ్వానాన్ని అంగీకరించండి|अपना आमंत्रण स्वीकार करें
Create account|ఖాతా సృష్టించు|खाता बनाएँ
Your company|మీ కంపెనీ|आपकी कंपनी
Review and submit|సమీక్షించి సమర్పించు|समीक्षा करें और जमा करें
Edit answers|సమాధానాలు సవరించు|उत्तर बदलें
Upload|అప్‌లోడ్|अपलोड
Replace|మార్చు|बदलें
Uploaded|అప్‌లోడ్ అయింది|अपलोड हुआ
Not uploaded|అప్‌లోడ్ కాలేదు|अपलोड नहीं हुआ
Needs your attention|మీ దృష్టి అవసరం|आपका ध्यान चाहिए`.trim().split('\n').forEach(l=>{const p=l.split('|');if(p.length===3)I18N[p[0].trim()]=[p[1].trim(),p[2].trim()]});

A.tel=v=>toast('Calling '+v+'... (demo)');
