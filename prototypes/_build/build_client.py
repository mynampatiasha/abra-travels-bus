import io,sys,re,os
sp=os.path.dirname(os.path.abspath(__file__))  # sources live next to this script
os.chdir(r'D:\New_project\abra-travels\prototypes')
s=io.open('admin_demo_model.html',encoding='utf-8').read()
pages=io.open(sp+'/client_pages.js',encoding='utf-8').read()
tail=io.open(sp+'/client_tail.js',encoding='utf-8').read()
def rep(a,b,c=1):
    global s
    assert s.count(a)==c,(a[:80],s.count(a))
    s=s.replace(a,b)
# --- sections
A0='/* ===================== 3. MOCK DATA ===================== */'
A1='DB=window.AbraStore?AbraStore.init():seed();\n'
i=s.index(A0);j=s.index(A1,i)
s=s[:i]+'/* ===================== 3. DATA: shared with the other prototypes ===================== */\nlet DB=AbraStore.init();\n'+s[j+len(A1):]
i=s.index('/* ===================== 4. SCREENS (part A) ===================== */')
k=s.index('/* ---------- import dialog')
hdr='\n'.join(l for l in s[i:k].split('\n') if not l.startswith('const audit='))
m=s.index('/* ---------- DASHBOARD ---------- */',k)
imp=s[k:m]
e=s.index('/* ===================== 4b. ENHANCEMENTS')
s=s[:i]+hdr+imp+pages+'\n'+s[e:]
i=s.index('/* ===================== 4c. AI ASSISTANT');j=s.index('/* ===================== 5. BOOT ===================== */')
s=s[:i]+tail+'\n'+s[j:]
# --- roles, pages, groups for the operator portal
s=re.sub(r"^const ROLES=.*$","const ROLES={SUPER_ADMIN:'Owner',ADMIN:'Manager',SUPPORT:'Booking staff',ACCOUNTS:'Accounts'};",s,count=1,flags=re.M)
s=re.sub(r"^const ALLP=.*$","const ALLP=['dashboard','kyc','company','buses','layouts','crew','routes','places','fares','schedules','trips','bookings','offers','earnings','commission','live','notifications','staff'];",s,count=1,flags=re.M)
s=re.sub(r"^const VIEW=.*$","const VIEW={SUPER_ADMIN:ALLP,ADMIN:ALLP.filter(p=>p!=='staff'),SUPPORT:['dashboard','kyc','company','buses','crew','routes','trips','bookings','live','notifications'],ACCOUNTS:['dashboard','kyc','company','bookings','fares','earnings','commission','notifications']};",s,count=1,flags=re.M)
s=re.sub(r"^const EDIT=.*$","const EDIT={SUPER_ADMIN:ALLP,ADMIN:ALLP.filter(p=>p!=='staff'),SUPPORT:['bookings','notifications','trips'],ACCOUNTS:['earnings','notifications']};",s,count=1,flags=re.M)
s=re.sub(r"^const GROUPS=.*$","const GROUPS=[['Overview',['dashboard']],['Company',['kyc','company']],['Fleet',['buses','layouts','crew']],['Network',['routes','places']],['Sales setup',['fares','schedules','trips']],['Sales',['bookings','offers']],['Money',['earnings','commission']],['Operations',['live']],['System',['notifications','staff']]];",s,count=1,flags=re.M)
rep("const lvl=(p,r)=>{r=r||S.role;","const lvl=(p,r)=>{if(typeof gateOk==='function'&&!gateOk(p))return'NONE';r=r||S.role;")
# --- state kept per app
s=s.replace("'abra_admin_demo'","'abra_client_demo'").replace("'abra_admin_perm'","'abra_client_perm'")
rep("JSON.stringify({role:S.role,theme:S.theme,lang:S.lang,orient:S.orient,vw:S.vw})","JSON.stringify({role:S.role,theme:S.theme,lang:S.lang,orient:S.orient,vw:S.vw,op:S.op})")
rep("S.orient=sv.orient||'auto';S.vw=sv.vw||{}}catch(e){","S.orient=sv.orient||'auto';S.vw=sv.vw||{};S.op=sv.op||null}catch(e){S.op=null;")
# --- notifications use the client inbox
rep("const un=DB.notifs.filter(n=>!n.read).length","const un=myInbox().filter(n=>!n.read).length")
rep("const l=DB.notifs.slice(0,6)","const l=myInbox().sort((a,b)=>new Date(b.at)-new Date(a.at)).slice(0,6)")
rep("A.n_all=()=>{DB.notifs.forEach(n=>n.read=true);render()};","A.n_all=()=>{myInbox().forEach(n=>n.read=true);render()};")
rep("const n=DB.notifs.find(x=>x.id===v)","const n=myInbox().find(x=>x.id===v)")
# --- top bar and brand
s,nn=re.subn(r"\$\{aiOn\(\)\?`.*?`:''\}",lambda m:"<button class=\"ib aibtn\" data-a=\"cai_open\" aria-label=\"AI assistant\" title=\"AI assistant\">${ic('spark')}</button>",s,count=1)
assert nn==1
rep('<div class="sl">Admin portal</div>','<div class="sl">${esc(ME()?ME().name:"Partner portal")}</div>')
rep('admin@abratravels.in','${esc(ME()?ME().email:"")}')
rep("document.title='Abra Travels Admin Demo - '+pg.t","document.title='Abra Partner Demo - '+pg.t")
rep("<title>Abra Travels Admin Demo</title>","<title>Abra Partner Demo</title>")
rep("document.title='Abra Travels Admin Demo';","document.title='Abra Partner Demo';")
s=s.replace("Search PNR, operator, bus...","Search PNR, trip, bus, driver...")
s=s.replace('Super Admin','Owner')
# --- fixes in the new pages
rep("fld('pn','Place name',' ',","fld('pn','Place name','',")
rep("fld('pa','Address',' ',","fld('pa','Address','',")
rep("if(n>=2&&!gv('kcn')&&S.ui.kstep===1)return setErr('kcn','Company name is required');if(S.ui.kstep===1&&gv('kcn'))","if(n>=2&&(S.ui.kstep||1)===1&&!gv('kcn'))return setErr('kcn','Company name is required');if((S.ui.kstep||1)===1&&gv('kcn'))")
# --- generic add keeps the record on this operator
rep("if(isNew){t.id=uid(String(sm.id).replace(/[-]?\\d+$/,'')||'ID');","if(isNew){t.id=uid(String(sm.id).replace(/[-]?\\d+$/,'')||'ID');if('operatorId' in t&&window.CUR_OP)t.operatorId=CUR_OP();if('operator' in t&&window.CUR_OPN)t.operator=CUR_OPN();")
css=io.open(sp+'/client.css',encoding='utf-8').read()
rep('/* forced layouts from Demo controls',css+'/* forced layouts from Demo controls')
io.open('client_demo_model.html','w',encoding='utf-8',newline='').write(s)
print('written',len(s))
