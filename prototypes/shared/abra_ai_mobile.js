/* =====================================================================
   ABRA TRAVELS - AI ASSISTANT PANEL FOR THE PHONE APPS (customer, driver)
   Demo only: answers are scripted on the shared mock data. In the real apps the
   panel talks to the NestJS ai-assistant module, which calls Groq with tool calling
   and runs every tool with the signed-in person's own permissions.
   Each app sets M.ai.answer(q, lang) and M.ai.sugg(); actions that change data
   return a pending card that runs only after Confirm.
   ===================================================================== */
(function(){
const css=`
.aifab{position:absolute;right:14px;bottom:76px;width:56px;height:56px;border-radius:50%;background:var(--gr);color:#fff;display:grid;place-items:center;z-index:31;box-shadow:0 10px 24px rgba(22,119,200,.4)}
.aifab.left{right:auto;left:14px}.phone.land .aifab{bottom:14px}
.aiov{position:absolute;inset:0;z-index:36;background:var(--bg);display:flex;flex-direction:column}
.aihd2{background:var(--gr);color:#fff;display:flex;align-items:center;gap:8px;padding:10px 12px;flex:none}.aihd2 .ib{color:#fff}
.aibody2{flex:1;overflow:auto;padding:12px;display:flex;flex-direction:column;gap:10px}
.am{max-width:92%;border-radius:14px;padding:10px 12px;line-height:1.45;overflow-wrap:anywhere}.am.me{align-self:flex-end;background:var(--b);color:#fff;border-bottom-right-radius:4px}
.am.ai{align-self:flex-start;background:var(--card);border:1px solid var(--ln);border-bottom-left-radius:4px;width:94%}.am.ai>*+*{margin-top:8px}
.aisug2{display:flex;gap:6px;overflow-x:auto;padding:8px 12px;border-top:1px solid var(--ln);flex:none;scrollbar-width:thin}
.aisug2 button,.aichips button{white-space:nowrap;border:1px solid var(--ln);border-radius:99px;padding:6px 11px;font-size:12px;background:var(--card);font-weight:600;color:var(--db)}
.aichips{display:flex;flex-wrap:wrap;gap:6px}
.aiin2{display:flex;gap:6px;align-items:center;padding:8px 12px 12px;flex:none;background:var(--card);border-top:1px solid var(--ln)}
.aiin2 input{flex:1;min-height:44px;border:1px solid var(--ln);border-radius:12px;padding:0 12px;background:var(--fld);outline:0;min-width:0}
.aimic{width:48px;height:48px;border-radius:50%;background:var(--lb2);color:var(--db);display:grid;place-items:center;flex:none}.aimic.on{background:var(--r);color:#fff;animation:pl 1s infinite}
.aimic.big{width:72px;height:72px}
.pend2{border:1px solid var(--a);background:var(--abg);color:var(--atx);border-radius:12px;padding:10px}.pend2.ok{border-color:var(--g);background:var(--gbg);color:var(--gtx)}.pend2.no{border-color:var(--ln);background:var(--bg);color:var(--m)}
.aisteps{font-size:12px;color:var(--m)}.aisteps summary{cursor:pointer;font-weight:600}.aisteps ol{margin:4px 0 0;padding-left:18px}
.aicard{border:1px solid var(--ln);border-radius:12px;padding:10px;display:flex;flex-direction:column;gap:4px;background:var(--bg)}
.tdots i{display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--m);margin-right:3px;animation:pl 1s infinite}.tdots i:nth-child(2){animation-delay:.2s}.tdots i:nth-child(3){animation-delay:.4s}`;
const st=document.createElement('style');st.textContent=css;document.head.appendChild(st);
M.addDict(`AI assistant|AI అసిస్టెంట్|AI असिस्टेंट
Ask in your own language|English, తెలుగు లేదా हिन्दी లో అడగండి|English, తెలుగు या हिन्दी में पूछें
Needs your confirmation|మీ నిర్ధారణ అవసరం|आपकी पुष्टि चाहिए
Confirm|నిర్ధారించు|पुष्टि करें
Cancel|రద్దు|रद्द करें
What I checked|నేను తనిఖీ చేసినవి|मैंने क्या जाँचा
Speak replies|సమాధానాలు చదివి వినిపించు|जवाब बोलकर सुनाएँ
Tap and speak|నొక్కి మాట్లాడండి|दबाएँ और बोलें`);
const AI=M.ai={enabled:false,open:false,msgs:[],pend:{},pn:0,busy:false,title:'Abra AI assistant',speak:false,voiceFirst:false,fabLeft:false,answer:null,sugg:()=>[],welcome:''};
const esc=M.esc,ic=M.ic;
M.AL=(lg,en,te,hi)=>lg==='te'?te:lg==='hi'?hi:lg==='en'?en:ABRA_L.tr(en,lg);
M.detLang=q=>{const sc=ABRA_L.det(q,M.lang);if(sc)return sc;if(/\b(chupinchu|chupi|cheyyi|cheyandi|enti|ivvu|kavali|unnayi|evaru|ela|ekkada|eppudu)\b/i.test(q))return'te';if(/\b(dikhao|batao|karo|kya|chahiye|kitne|kaun|hai|mujhe|kahan|kab)\b/i.test(q))return'hi';return M.lang||'en'};
function pendHtml(id){const p=AI.pend[id];if(!p)return'';const lg=p.lg;
if(p.st==='wait')return`<div class="pend2"><b>${ic('alert',14)} ${M.AL(lg,'Needs your confirmation','మీ నిర్ధారణ అవసరం','आपकी पुष्टि चाहिए')}</b><p style="margin-top:6px">${p.desc}</p><div class="row mt2"><button class="cta sm ${p.danger?'dg':''}" data-a="mai_ok" data-v="${id}">${M.AL(lg,'Confirm','నిర్ధారించు','पुष्टि करें')}</button><button class="cta gh sm" data-a="mai_no" data-v="${id}">${M.AL(lg,'Cancel','రద్దు','रद्द करें')}</button></div></div>`;
if(p.st==='run')return`<div class="pend2"><span class="tdots"><i></i><i></i><i></i></span> ${M.AL(lg,'Working, waiting for the server...','పని జరుగుతోంది...','काम हो रहा है...')}</div>`;
if(p.st==='done')return`<div class="pend2 ok">${ic('check',14)} ${p.res}</div>`;if(p.st==='fail')return`<div class="pend2 no">${esc(p.res)}</div>`;
return`<div class="pend2 no">${M.AL(lg,'Cancelled. Nothing was changed.','రద్దు చేశారు. ఏమీ మారలేదు.','रद्द किया। कुछ नहीं बदला।')}</div>`}
function msg(m){if(m.who==='me')return`<div class="am me">${m.html}</div>`;if(m.typing)return`<div class="am ai"><span class="tdots"><i></i><i></i><i></i></span></div>`;
return`<div class="am ai">${m.html}${m.pend?pendHtml(m.pend):''}${m.steps&&m.steps.length?`<details class="aisteps"><summary>What I checked (${m.steps.length})</summary><ol>${m.steps.map(s=>`<li><code>${esc(s)}</code></li>`).join('')}</ol></details>`:''}${m.chips&&m.chips.length?`<div class="aichips">${m.chips.map(c=>`<button data-a="mai_q" data-v="${esc(c)}">${esc(c)}</button>`).join('')}</div>`:''}</div>`}
function panel(){const S=AI.sugg()||[];return`<div class="aiov" role="dialog" aria-label="AI assistant"><div class="aihd2"><span class="ib">${ic('star',20)}</span><b class="grow">${esc(AI.title)}</b>${AI.voiceFirst?`<button class="ib" data-a="mai_spk" aria-label="Speak replies" title="Speak replies">${ic(AI.speak?'phone':'x',18)}</button>`:''}<button class="ib" data-a="mai_new" aria-label="New chat">${ic('refresh',18)}</button><button class="ib" data-a="mai_x" aria-label="Close">${ic('x')}</button></div>
<div class="aibody2" id="aib">${AI.msgs.length?AI.msgs.map(msg).join(''):`<div class="am ai">${AI.welcome}</div>`}</div>
<div class="aisug2">${S.map(c=>`<button data-a="mai_q" data-v="${esc(c)}">${esc(c)}</button>`).join('')}</div>
${AI.voiceFirst?`<div class="aiin2" style="justify-content:center;flex-direction:column;gap:6px"><button class="aimic big ${AI.listening?'on':''}" data-a="mai_mic" aria-label="Tap and speak">${ic('phone',30)}</button><span class="sm m">${AI.listening?'Listening...':'Tap and speak'}</span><div class="row" style="width:100%"><input id="mai_in" placeholder="Ask in your own language" aria-label="Message"><button class="cta sm" data-a="mai_send" aria-label="Send">${ic('send',16)}</button></div></div>`
:`<div class="aiin2"><button class="aimic ${AI.listening?'on':''}" data-a="mai_mic" aria-label="Speak">${ic('phone',20)}</button><input id="mai_in" placeholder="Ask in your own language" aria-label="Message"><button class="cta sm" data-a="mai_send" aria-label="Send">${ic('send',16)}</button></div>`}</div>`}
M.beforeRender=ph=>{const i=M.$('#mai_in',ph);return{v:i?i.value:'',f:document.activeElement===i}};
M.afterRender=(ph,st)=>{if(!AI.enabled||!AI.enabled())return;ph.insertAdjacentHTML('beforeend',AI.open?panel():`<button class="aifab ${AI.fabLeft?'left':''}" data-a="mai_open" aria-label="AI assistant">${ic('star',26)}</button>`);
if(AI.open){M.translate(M.$('.aiov',ph));const b=M.$('#aib',ph);if(b)b.scrollTop=b.scrollHeight;const i=M.$('#mai_in',ph);if(i&&st){i.value=st.v;if(st.f)i.focus()}}};
const plain=h=>{const d=document.createElement('div');d.innerHTML=h;return d.textContent.replace(/\s+/g,' ').trim()};
function say(m,lg){if(!AI.speak||!window.speechSynthesis)return;try{speechSynthesis.cancel();const u=new SpeechSynthesisUtterance(plain(m.html).slice(0,400));u.lang={te:'te-IN',hi:'hi-IN',kn:'kn-IN',ta:'ta-IN',ml:'ml-IN',mr:'mr-IN',bn:'bn-IN'}[lg]||'en-IN';speechSynthesis.speak(u)}catch(e){}}
AI.ask=(q,force,label)=>{q=String(q||'').trim();if(!q||AI.busy)return;const lg=force||M.detLang(q);AI.msgs.push({who:'me',html:esc(label||q)});const m={who:'ai',typing:true};AI.msgs.push(m);AI.busy=true;M.render();
setTimeout(()=>{try{Object.assign(m,AI.answer(q,lg)||{html:'...'})}catch(e){console.error(e);m.html=M.AL(lg,'Something went wrong while reading the data. Nothing was changed.','డేటా చదువుతున్నప్పుడు లోపం వచ్చింది. ఏమీ మారలేదు.','डेटा पढ़ते समय गड़बड़ी हुई। कुछ नहीं बदला।')}m.typing=false;AI.busy=false;M.render();say(m,lg)},550+Math.random()*450)};
AI.mkPend=o=>{const id='MP'+(++AI.pn);AI.pend[id]=Object.assign({st:'wait'},o);return id};
Object.assign(M.A,{mai_open:()=>{AI.open=true;M.render()},mai_x:()=>{AI.open=false;try{speechSynthesis.cancel()}catch(e){}M.render()},mai_new:()=>{AI.msgs=[];M.render()},
mai_send:()=>{const i=M.$('#mai_in');const v=i?i.value:'';if(i)i.value='';AI.ask(v)},
mai_q:(v,el)=>AI.ask(v,M.lang==='en'?null:M.lang,el&&el.textContent!==v?el.textContent:v),
mai_spk:()=>{AI.speak=!AI.speak;M.toast(AI.speak?'Replies will be spoken':'Replies will not be spoken');M.render()},
mai_ok:v=>{const p=AI.pend[v];if(!p||p.st!=='wait')return;if(p.check){const e=p.check();if(e){p.st='fail';p.res=e;return M.render()}}p.st='run';M.render();setTimeout(()=>{try{p.res=p.run();p.st='done'}catch(e){p.st='fail';p.res=e.message}M.render()},700)},
mai_no:v=>{const p=AI.pend[v];if(p&&p.st==='wait'){p.st='no';M.render()}},
mai_mic:()=>{const SR=window.SpeechRecognition||window.webkitSpeechRecognition;if(!SR)return M.toast('Voice input is not supported in this browser. Type instead.');if(AI.listening)return;
const r=new SR();r.lang={te:'te-IN',hi:'hi-IN',kn:'kn-IN',ta:'ta-IN',ml:'ml-IN',mr:'mr-IN',bn:'bn-IN'}[M.lang]||'en-IN';r.interimResults=false;AI.listening=true;M.render();r.onresult=e=>{const t=e.results[0][0].transcript;AI.listening=false;AI.ask(t)};r.onerror=()=>{AI.listening=false;M.toast('Could not hear you. Check microphone permission.');M.render()};r.onend=()=>{if(AI.listening){AI.listening=false;M.render()}};r.start()}});
document.addEventListener('keydown',e=>{if(e.target&&e.target.id==='mai_in'&&e.key==='Enter'){e.preventDefault();M.A.mai_send()}});
})();
