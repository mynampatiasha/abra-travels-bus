/* =====================================================================
   ABRA TRAVELS - SHARED PROTOTYPE STORE
   One mock database used by all four prototypes:
     admin_demo_model.html, client_demo_model.html, customer_demo_model.html, driver_demo_model.html
   Data lives in the browser's localStorage, so a change made in one tab
   (for example a customer booking) appears live in the other open tabs.
   Real apps: this is what the NestJS backend + MongoDB + socket events will do.
   ===================================================================== */
(function(){
const KEY='abra_proto_db_v2';
const DAY=864e5,NOW=Date.now();
let SEED=7,UID=5000;
const rnd=()=>{SEED=(SEED*16807)%2147483647;return(SEED-1)/2147483646};
const ri=(a,b)=>a+Math.floor(rnd()*(b-a+1));
const pk=a=>a[Math.floor(rnd()*a.length)];
const uid=(p)=>p+'-'+(++UID);
const ago=(d,h=0,m=0)=>new Date(NOW-d*DAY-h*36e5-m*6e4).toISOString();
const fut=(d,h=0)=>new Date(NOW+d*DAY+h*36e5).toISOString();
const DOC_DEF=[['gst','GST certificate',0],['pan','PAN card',0],['reg','Company registration certificate',0],['oid','Owner ID proof',0],['bank','Bank proof (cancelled cheque)',0],['inter','Interstate permit',1]];
function mkDocs(st){return DOC_DEF.map(([k,n,ex],i)=>({key:k,name:n,file:k.toUpperCase()+'_scan.pdf',status:st==='PENDING'?'PENDING':st==='APPROVED'?'ACCEPTED':(i===1||i===4)?'REJECTED':'ACCEPTED',reason:st==='REJECTED'&&(i===1||i===4)?(i===1?'The PAN card image is blurred. Upload a clear photo.':'Account holder name does not match the company name.'):'',expiry:ex?fut(90+i*20).slice(0,10):''}))}
const BUS_DOCS=[['rc','Registration certificate (RC)'],['permit','Route permit'],['ins','Insurance'],['fit','Fitness certificate'],['puc','Pollution certificate'],['photo','Bus photos']];
function seed(){
SEED=11;UID=5000;
const D={};
const cityList=[['Hyderabad','Telangana'],['Bengaluru','Karnataka'],['Chennai','Tamil Nadu'],['Vijayawada','Andhra Pradesh'],['Visakhapatnam','Andhra Pradesh'],['Coimbatore','Tamil Nadu'],['Kochi','Kerala'],['Mumbai','Maharashtra'],['Pune','Maharashtra'],['Tirupati','Andhra Pradesh'],['Madurai','Tamil Nadu'],['Mysuru','Karnataka'],['Nellore','Andhra Pradesh'],['Warangal','Telangana'],['Guntur','Andhra Pradesh'],['Kurnool','Andhra Pradesh'],['Salem','Tamil Nadu'],['Panaji','Goa'],['Nagpur','Maharashtra'],['Ahmedabad','Gujarat']];
D.cities=cityList.map(([n,s],i)=>({id:'CT'+(i+1),name:n,state:s,active:i!==19,popular:i<8,te:['హైదరాబాద్','బెంగళూరు','చెన్నై','విజయవాడ','విశాఖపట్నం'][i]||'',hi:['हैदराबाद','बेंगलुरु','चेन्नई'][i]||'',places:ri(2,6)}));
const places=[];D.cities.forEach(c=>{['Bus Stand','Flyover Pickup','Railway Station'].slice(0,ri(2,3)).forEach((t,k)=>places.push({id:'PL'+(places.length+1),city:c.name,name:c.name+' '+t,address:(k+1)*12+', Main Road, '+c.name,landmark:pk(['Near metro','Opp. petrol bunk','Beside mall','Near temple']),lat:(12+rnd()*8).toFixed(4),lng:(74+rnd()*10).toFixed(4),phone:'+91 9'+ri(100000000,999999999),type:k===0?'BOTH':k===1?'BOARDING':'DROPPING',source:k===2&&rnd()<.5?'Operator request':'Admin',active:rnd()<.92,trips:ri(0,40)}))});D.places=places;
D.placeReqs=[['Kaveri Express','Hosur','Hosur Bus Stand Gate 2','Hosur Main Road','PENDING'],['Godavari Lines','Rajahmundry','Rajahmundry Bypass','NH16 Bypass','PENDING'],['Deccan Voyager','Hyderabad','Miyapur Metro Pickup','Miyapur X Roads','APPROVED'],['Charminar Tours','Hyderabad','Ameerpet Pickup','Ameerpet Metro','APPROVED'],['Nilgiri Travels','Coimbatore','Gandhipuram Stand 4','Gandhipuram','REJECTED'],['Telangana Star','Warangal','Hanamkonda Chowrasta','Hanamkonda','PENDING']].map((x,i)=>({id:'PR-'+(100+i),operator:x[0],city:x[1],name:x[2],address:x[3],status:x[4],at:ago(i+1),reason:x[4]==='REJECTED'?'Too close to an existing point (120 m)':''}));
D.busTypes=[['AC Sleeper','AC_SLEEPER',1,'SLEEPER'],['Non-AC Sleeper','NONAC_SLEEPER',0,'SLEEPER'],['AC Seater','AC_SEATER',1,'SEATER'],['Non-AC Seater','NONAC_SEATER',0,'SEATER'],['Volvo Multi-Axle AC','VOLVO_AC',1,'SEMI_SLEEPER'],['Semi-Sleeper AC','SEMI_AC',1,'SEMI_SLEEPER']].map((x,i)=>({id:'BT'+(i+1),name:x[0],key:x[1],ac:!!x[2],berth:x[3],active:i!==1||true,buses:ri(2,9)}));
D.amenities=['Charging point','Blanket','Water bottle','Reading light','WiFi','Snacks','Live tracking','CCTV','Emergency exit','Entertainment screen'].map((n,i)=>({id:'AM'+(i+1),name:n,active:true}));
const opN=['Kaveri Express','Godavari Lines','Deccan Voyager','Sahyadri Coaches','Nilgiri Travels','Charminar Tours','Tungabhadra Express','Konkan Rider','Vindhya Travels','Malabar Lines','Coromandel Coaches','Araku Express','Telangana Star','Krishna Wheels'];
const owners=['Ramesh Naidu','Suresh Reddy','Anil Kumar','Vijay Patil','Mohan Raj','Syed Imran','Prakash Rao','Nitin Kamat','Dinesh Sharma','Thomas Mathew','Karthik S','Lakshmi Devi','Venkat Rao','Srinivas M'];
D.operators=opN.map((n,i)=>({id:'OP'+(i+1),name:n,owner:owners[i],email:n.toLowerCase().replace(/[^a-z]/g,'')+'@example.com',phone:'+91 9'+ri(100000000,999999999),city:cityList[i%12][0],status:i===5?'SUSPENDED':i>=11?'PENDING_APPROVAL':'ACTIVE',buses:0,trips:ri(10,160),joined:ago(ri(20,400)),payout:i%3===0?'AUTO':'MANUAL',gst:'36'+n.slice(0,5).toUpperCase().replace(/[^A-Z]/g,'X')+ri(1000,9999)+'A1Z'+ri(1,9),rating:(3.6+rnd()*1.3).toFixed(1),bank:{holder:n+' Pvt Ltd',acc:'XXXXXX'+ri(1000,9999),ifsc:'HDFC000'+ri(1000,9999),status:i%5===4?'FAILED':i>=11?'PENDING':'VERIFIED'},kyc:i>=11?'PENDING':'APPROVED',fund:'PLATFORM'}));
D.invitations=[['New Horizon Travels','Arun Verma','arun@newhorizon.example','PENDING',2,5],['Blue Hills Tours','Mala Krishnan','mala@bluehills.example','ACCEPTED',6,1],['Sagar Express','Sagar Jain','sagar@sagarexp.example','PENDING',1,6],['Falcon Coaches','Imtiyaz Ali','imtiyaz@falcon.example','EXPIRED',12,-5],['Lotus Lines','Rani Pillai','rani@lotus.example','REVOKED',8,0],['Pearl Travels','Jose Thomas','jose@pearl.example','PENDING',0,7]].map((x,i)=>({id:'INV-'+(200+i),company:x[0],owner:x[1],email:x[2],status:x[3],sentAt:ago(x[4]),expiresAt:fut(x[5]),email_status:i===2?'FAILED':'SENT'}));
D.submissions=[];const answers=[['Business type','Company'],['Do you own the buses?','Yes'],['Services','Seat bookings, Charters'],['Are you GST registered?','Yes'],['Number of buses','12']];
['PENDING','PENDING','REJECTED','APPROVED','PENDING','APPROVED'].forEach((st,i)=>{const o=D.operators[(i+8)%14];D.submissions.push({id:'SUB-'+(1001+i),operatorId:o.id,operator:o.name,type:i===1||i===4?'BUS':'COMPANY',bus:i===1?'TS09 UB 4521':i===4?'AP39 TX 8812':'',status:st,submittedAt:ago(i%3+0,i*3),docs:i===1||i===4?BUS_DOCS.map(([k,n],j)=>({key:k,name:n,file:k+'_scan.jpg',status:'PENDING',reason:'',expiry:j>0&&j<5?fut(200).slice(0,10):''})):mkDocs(st),answers,history:[['Submitted',ago(i%3,i*3)]].concat(st==='REJECTED'?[['Rejected with reasons',ago(1)]]:st==='APPROVED'?[['Approved',ago(2)]]:[])})});
D.busList=[];
D.operators.forEach((o,i)=>{const n=i>=11?1:ri(2,3);o.buses=n;for(let k=0;k<n;k++){const bt=pk(D.busTypes);D.busList.push({id:'BUS'+(D.busList.length+1),operatorId:o.id,operator:o.name,reg:pk(['TS09','AP39','KA01','TN38','TS07','AP16'])+' '+pk(['UB','TX','AB','CD','EF'])+' '+ri(1000,9999),name:o.name.split(' ')[0]+' '+pk(['Gold','Silver','Royal','Prime','Star'])+' '+ri(1,40),type:bt.name,ac:bt.ac,seats:bt.berth==='SLEEPER'?ri(30,40):ri(40,50),status:i>=11?'PENDING_APPROVAL':pk(['ACTIVE','ACTIVE','ACTIVE','ACTIVE','MAINTENANCE','ACTIVE']),insExp:fut(ri(-5,300)).slice(0,10),layout:pk(['2+1 Sleeper','2+2 Seater','1+2 Sleeper']),added:ago(ri(5,300))})}});
D.buses=D.busList;
const rts=[[0,1],[1,0],[0,2],[2,5],[3,4],[0,3],[1,11],[2,10],[7,8],[0,9],[1,6],[9,2]];
D.routes=rts.map(([a,b],i)=>({id:'RT'+(i+1),from:cityList[a][0],to:cityList[b][0],name:cityList[a][0]+' to '+cityList[b][0],km:ri(180,700),hours:ri(4,13)}));
D.trips=[];for(let i=0;i<42;i++){const r=pk(D.routes),b=pk(D.busList.filter(x=>x.status==='ACTIVE')),off=ri(-6,8);const st=off<-1?'ARRIVED':off<0?pk(['IN_TRANSIT','DEPARTED','ARRIVED']):off===0?pk(['BOARDING','SCHEDULED','IN_TRANSIT','DELAYED']):pk(['SCHEDULED','SCHEDULED','SCHEDULED','CANCELLED','DRAFT']);const booked=ri(4,b.seats-2),held=st==='SCHEDULED'?ri(0,4):0;
D.trips.push({id:'TRP-'+(3001+i),routeId:r.id,route:r.name,operatorId:b.operatorId,operator:b.operator,busId:b.id,bus:b.reg,busName:b.name,type:b.type,depart:fut(off,ri(0,12)),status:st,seats:b.seats,booked,held,blocked:ri(0,2),fare:ri(55000,210000),driver:pk(['Ramesh K','Sunil Y','Anwar S','Prakash M','Naveen B']),conductor:pk(['Mahesh','Kiran','Joseph','Salim'])})}
const nm=['Aarav Sharma','Priya Nair','Rohan Mehta','Ananya Reddy','Vikram Singh','Divya Iyer','Arjun Patel','Kavya Menon','Imran Khan','Sneha Joshi','Rahul Verma','Meera Pillai','Karthik Rao','Pooja Shah','Aditya Kulkarni','Lakshmi Narayan','Sanjay Gupta','Neha Bhat','Manoj Kumar','Isha Agarwal','Suresh Babu','Anjali Das','Harish Chandra','Fatima Begum','Tarun Mishra','Swathi Reddy','Nikhil Jain','Deepa Menon','Gopal Rao','Bhavana S','Yash Thakur','Rekha Devi','Sai Kiran','Zoya Khan','Mohit Arora','Padma Latha'];
D.customers=nm.map((n,i)=>({id:'CU'+(i+1),name:n,email:n.toLowerCase().replace(/[^a-z]+/g,'.')+'@example.com',phone:'+91 9'+ri(100000000,999999999),status:i%11===5?'SUSPENDED':i%13===7?'DEACTIVATED':'ACTIVE',joined:ago(ri(2,500)),bookings:ri(0,24),spent:ri(0,4500000),method:pk(['Google','WhatsApp OTP','Apple','Password']),city:pk(cityList)[0],lastActive:ago(ri(0,40))}));
D.bookings=[];for(let i=0;i<76;i++){const t=pk(D.trips.filter(x=>x.status!=='DRAFT')),c=pk(D.customers),n=ri(1,4),amt=t.fare*n,com=Math.round(amt*pk([.08,.1,.12])),st=t.status==='CANCELLED'?'CANCELLED':t.status==='ARRIVED'?'COMPLETED':rnd()<.1?'CANCELLED':'CONFIRMED';
D.bookings.push({id:'BK-'+(7001+i),pnr:'ABR'+pk(['K','M','Q','T','X'])+ri(1000,9999)+pk(['A','B','C','D','E']),customerId:c.id,customer:c.name,phone:c.phone,tripId:t.id,route:t.route,operator:t.operator,operatorId:t.operatorId,travelDate:t.depart,seatList:Array.from({length:n},(_,k)=>(ri(1,12))+pk(['A','B','C','D'])).join(', '),seatsN:n,amount:amt,commission:com,gst:Math.round(amt*.05),fee:4900,discount:rnd()<.2?ri(5000,25000):0,status:st,mode:pk(['UPI','UPI','CARD','NETBANKING','WALLET']),at:ago(ri(0,25),ri(0,20)),coupon:rnd()<.2?pk(['ABRA100','WEEKEND15']):''})}
D.payments=D.bookings.map((b,i)=>({id:'PAY-'+(9001+i),bookingId:b.id,pnr:b.pnr,customer:b.customer,operator:b.operator,amount:b.amount+b.gst+b.fee-b.discount,mode:b.mode,status:i%17===3?'FAILED':i%23===5?'PENDING':b.status==='CANCELLED'?'REFUNDED':'SUCCESS',gw:'pay_'+ri(100000,999999)+pk(['xK','Qa','Zz']),at:b.at,reason:i%17===3?pk(['Bank declined the payment','UPI collect request expired','Card limit exceeded']):'',settled:rnd()<.7}));
D.refunds=D.bookings.filter(b=>b.status==='CANCELLED').map((b,i)=>({id:'RF-'+(4001+i),bookingId:b.id,pnr:b.pnr,customer:b.customer,operator:b.operator,amount:Math.round(b.amount*pk([1,.9,.75,.5])),pct:pk([100,90,75,50]),status:pk(['INITIATED','PROCESSING','COMPLETED','COMPLETED','COMPLETED','FAILED']),utr:'UTR'+ri(10000000,99999999),at:ago(ri(0,12)),bearer:pk(['Operator','Platform']),reason:pk(['Customer cancelled','Trip cancelled by operator','Duplicate booking'])}));
D.settlements=[];D.operators.filter(o=>o.status!=='PENDING_APPROVAL').forEach((o,i)=>{const g=ri(400000,9800000),cm=Math.round(g*.1),rf=ri(0,Math.round(g*.08));D.settlements.push({id:'ST-'+(6001+i),operatorId:o.id,operator:o.name,cycle:'1 Oct to 7 Oct 2026',gross:g,commission:cm,refunds:rf,adj:i%4===2?-ri(5000,50000):0,net:g-cm-rf-(i%4===2?ri(5000,50000):0),status:pk(['DRAFT','APPROVED','PAID','PAID','ON_HOLD']),mode:o.payout,lines:ri(18,160),paidAt:null,query:i%5===1?'Operator disputes 2 refunds on 3 Oct':''})});
D.commissions=[['OPERATOR','Kaveri Express','PERCENT',1000,'Agreed on call, 2026-08-14'],['OPERATOR','Godavari Lines','PERCENT',900,'Volume discount'],['ROUTE','Hyderabad to Bengaluru','PERCENT',1200,'High demand route'],['BUS_TYPE','AC Sleeper','PERCENT',1100,'Default for AC sleeper'],['OPERATOR','Deccan Voyager','FLAT',6000,'Rs 60 per seat'],['BUS_TYPE','Non-AC Seater','PERCENT',700,'Budget buses'],['OPERATOR','Charminar Tours','PERCENT',800,'Founding partner']].map((x,i)=>({id:'CR-'+(i+1),scope:x[0],target:x[1],mode:x[2],value:x[3],note:x[4],from:ago(10+i*9).slice(0,10),version:1+(i%3),status:i===5?'INACTIVE':'ACTIVE',by:'Super Admin'}));
D.commissionDefault={mode:'PERCENT',value:1000};
D.commissionHist=[['CR-1','Created at 10%','Super Admin',ago(40)],['CR-3','Changed 11% to 12%','Admin',ago(21)],['CR-5','Created flat 60 per seat','Super Admin',ago(12)],['CR-6','Deactivated','Super Admin',ago(3)]];
D.payoutCfg={defaultMode:'MANUAL',cycleDays:7,minPayout:100000,holdDays:2,razorpayRoute:true,gstPct:18,fee:4900,couponFunding:'PLATFORM'};
D.cancelSlabs=[[48,100],[24,75],[12,50],[4,25],[0,0]].map(([h,p],i)=>({id:'CS'+i,hours:h,pct:p}));
D.docTypes=[['gst','GST certificate','OPERATOR',1,0,'PDF, JPG',5,2],['pan','PAN card','OPERATOR',1,0,'PDF, JPG, PNG',5,1],['reg','Company registration','OPERATOR',1,0,'PDF',10,2],['oid','Owner ID proof','OPERATOR',1,0,'PDF, JPG',5,2],['bank','Bank proof','OPERATOR',1,0,'PDF, JPG',5,1],['inter','Interstate permit','OPERATOR',0,1,'PDF',10,3],['rc','Registration certificate','BUS',1,0,'PDF, JPG',5,2],['permit','Route permit','BUS',1,1,'PDF',10,2],['ins','Insurance','BUS',1,1,'PDF',10,1],['fit','Fitness certificate','BUS',1,1,'PDF',10,1],['puc','Pollution certificate','BUS',0,1,'PDF, JPG',5,1],['photo','Bus photos','BUS',1,0,'JPG, PNG',5,8]].map((x,i)=>({id:'DT'+(i+1),key:x[0],name:x[1],applies:x[2],required:!!x[3],expires:!!x[4],types:x[5],maxMb:x[6],maxFiles:x[7],active:true,order:i,instr:'Upload a clear, readable copy.'}));
D.questions=[['business_type','What is your business type?','OPERATOR','SINGLE_CHOICE','Company, Individual, Partnership',1],['own_buses','Do you own the buses you operate?','OPERATOR','BOOLEAN','',1],['services','Which services do you offer?','OPERATOR','MULTI_CHOICE','Seat bookings, Charters, Parcel',0],['gst_reg','Are you GST registered?','OPERATOR','BOOLEAN','',1],['fleet','How many buses do you run?','OPERATOR','NUMBER','',1],['routes_text','Routes you plan to operate','OPERATOR','TEXT','',0]].map((x,i)=>({id:'Q'+(i+1),key:x[0],label:x[1],applies:x[2],type:x[3],opts:x[4],required:!!x[5],active:true,order:i}));
D.rules=[['GST certificate for GST-registered operators','gst','gst_reg = Yes'],['PAN card for everyone','pan','Always'],['Company registration for companies','reg','business_type = Company'],['Partnership deed for partnerships','deed','business_type = Partnership'],['Interstate permit for operators on interstate routes','inter','services includes Seat bookings']].map((x,i)=>({id:'R'+(i+1),name:x[0],doc:x[1],cond:x[2],required:i!==4,active:true}));
D.tickets=[['Refund not received','REFUND','HIGH','OPEN'],['Seat showed available but was taken','BOOKING','MEDIUM','IN_PROGRESS'],['Bus did not arrive at pickup point','BOOKING','URGENT','OPEN'],['Payment deducted but no ticket','PAYMENT','URGENT','IN_PROGRESS'],['How do I change my phone number?','APP','LOW','RESOLVED'],['Driver behaviour complaint','SAFETY','HIGH','OPEN'],['Coupon WEEKEND15 not applying','PAYMENT','LOW','CLOSED'],['Need GST invoice for my trip','BOOKING','LOW','RESOLVED'],['App crashes on payment screen','APP','MEDIUM','IN_PROGRESS'],['Wrong boarding time shown','BOOKING','MEDIUM','OPEN']].map((x,i)=>({id:'TKT-'+(8001+i),customer:D.customers[i*3%36].name,customerId:D.customers[i*3%36].id,subject:x[0],category:x[1],priority:x[2],status:x[3],assignee:i%3===0?'':pk(['Divya (Support)','Kiran (Support)']),at:ago(i%6,i),sla:fut(0,ri(-3,20)),bookingId:D.bookings[i].id,msgs:[['customer','Hello, '+x[0].toLowerCase()+'. Please help.',ago(i%6,i)]].concat(x[3]==='OPEN'?[]:[['agent','Thanks for reaching out. We are checking this for you.',ago(i%6,i-1)]])}));
D.replies=['Sorry for the trouble. We have raised this with the operator and will update you within 24 hours.','Your refund has been initiated. It usually reaches your account in 5 to 7 working days.','Could you share your PNR and a screenshot so we can check?','This has been resolved. Please tell us if you still see the problem.'];
D.faqs=[['How do I cancel a booking?','Bookings','PUBLISHED'],['When will I get my refund?','Refunds','PUBLISHED'],['How do I change my boarding point?','Bookings','PUBLISHED'],['Is my payment safe?','Payments','PUBLISHED'],['What is the seat hold timer?','Bookings','PUBLISHED'],['How does trip sharing work?','Safety','DRAFT'],['What if my bus is late?','Trips','PUBLISHED'],['How do I use a coupon?','Offers','PUBLISHED']].map((x,i)=>({id:'FAQ'+(i+1),q:x[0],cat:x[1],status:x[2],a:'This is the sample answer for: '+x[0],updated:ago(i*3),views:ri(30,900)}));
D.pages=[['Terms and Conditions','PUBLISHED',4],['Privacy Policy','PUBLISHED',3],['Cancellation Policy','PUBLISHED',2],['Safety Information','PUBLISHED',2],['About Abra Travels','DRAFT',1]].map((x,i)=>({id:'PG'+(i+1),title:x[0],status:x[1],version:x[2],updated:ago(i*9)}));
D.contact={phone:'+91 40 4000 1234',whatsapp:'+91 98480 12345',email:'support@abratravels.in',hours:'6 AM to 11 PM, every day',emergency:'+91 98480 99999'};
D.banners=[['Festive special','Flat 15% off on selected routes','WEEKEND15','PUBLISHED',0,12,4120,310],['Travel with family','Save up to Rs 500 on 4+ seats','ABRA100','PUBLISHED',1,20,3380,201],['Safe journeys','Extra 10% off for women travellers','WOMEN10','SCHEDULED',2,30,0,0],['Monsoon offer','Rs 75 cashback with UPI','UPIFEST','DRAFT',0,0,0,0],['Diwali early bird','Book early and save','DIWALI20','ARCHIVED',1,-5,9800,720],['New routes','Now serving Kochi','','PUBLISHED',2,25,1900,88]].map((x,i)=>({id:'BN'+(i+1),title:x[0],sub:x[1],code:x[2],status:x[3],style:x[4],from:ago(x[3]==='SCHEDULED'?-5:10).slice(0,10),to:fut(x[5]).slice(0,10),placement:'HOME_TOP',audience:i===1?'NEW_USERS':'ALL',priority:5-i,imp:x[6],clicks:x[7],link:x[2]?'Offer '+x[2]:'Route search'}));
D.offers=[['ABRA100','Rs 100 off your first booking','FLAT',10000,30000,0,'ACTIVE','PLATFORM',1,3200,120],['WEEKEND15','15% off up to Rs 250, Friday to Sunday','PERCENT',1500,25000,50000,'ACTIVE','PLATFORM',1,5000,812],['UPIFEST','Rs 75 cashback with UPI','FLAT',7500,7500,40000,'ACTIVE','PLATFORM',2,2000,1688],['WOMEN10','10% off for women travellers','PERCENT',1000,20000,30000,'ACTIVE','PLATFORM',1,1500,210],['KAVERI50','Rs 50 off Kaveri Express buses','FLAT',5000,5000,0,'ACTIVE','OPERATOR',3,800,330],['DIWALI20','20% off up to Rs 400','PERCENT',2000,40000,100000,'EXPIRED','PLATFORM',1,1000,1000],['HYDBLR','Rs 120 off Hyderabad to Bengaluru','FLAT',12000,12000,80000,'PAUSED','PLATFORM',2,600,45],['SLEEP10','10% off on AC sleepers','PERCENT',1000,15000,60000,'DRAFT','PLATFORM',1,0,0]].map((x,i)=>({id:'OF'+(i+1),code:x[0],desc:x[1],type:x[2],value:x[3],maxDisc:x[4],minAmt:x[5],status:x[6],funder:x[7],perUser:x[8],limit:x[9],used:x[10],from:ago(20-i).slice(0,10),to:fut(x[6]==='EXPIRED'?-3:15+i*5).slice(0,10),scope:i===6?'Route: Hyderabad to Bengaluru':i===4?'Operator: Kaveri Express':i===7?'Bus type: AC Sleeper':i===3?'Women travellers':'All',newOnly:i===0,terms:['Valid on bus bookings made in the Abra Travels app.','One coupon per booking. Cannot be combined.','Maximum discount applies per booking.','Abra Travels may withdraw the offer at any time.']}));
D.announce=[['Heavy rain advisory on Hyderabad to Visakhapatnam','Trips may run late. Check live tracking.','Customers on route','SENT'],['New AC sleeper buses on Chennai routes','Book now and save.','All customers','SENT'],['App maintenance tonight 2 AM to 3 AM','Booking will be unavailable for one hour.','All customers','SCHEDULED'],['Safety tips for night travel','Share your trip with family.','All customers','DRAFT']].map((x,i)=>({id:'AN'+(i+1),title:x[0],body:x[1],audience:x[2],status:x[3],channel:i%2?'Push, WhatsApp':'Push',at:ago(i*2),reach:x[3]==='SENT'?ri(800,9000):0}));
D.popular=D.routes.slice(0,8).map((r,i)=>({id:'PO'+(i+1),route:r.name,order:i+1,active:i<6,searches:ri(300,5000),bookings:ri(40,900)}));
const sp=[[44,40],[52,58],[30,62],[66,34],[58,46],[40,70]];
D.sos=[['Divya Iyer','NEW',0,0,'Unsafe behaviour by co-passenger'],['Meera Pillai','ACKNOWLEDGED',18,1,'Bus stopped at an unknown place'],['Pooja Shah','RESOLVED',300,2,'Accidental press'],['Neha Bhat','FALSE_ALARM',1500,3,'Pressed by mistake'],['Kavya Menon','RESOLVED',4000,4,'Driver rash driving']].map((x,i)=>{const t=D.trips[i+2];return{id:'SOS-'+(2001+i),customer:x[0],phone:'+91 9'+ri(100000000,999999999),trip:t.id,route:t.route,bus:t.bus,driver:t.driver,operator:t.operator,status:x[1],at:ago(0,0,x[2]),note:x[4],x:sp[i][0],y:sp[i][1],contacts:['Mother +91 98450 00001','Husband +91 98450 00002'],log:[['SOS received',ago(0,0,x[2])],['Contacts alerted by SMS and call',ago(0,0,x[2]-1)]].concat(x[1]==='NEW'?[]:[['Acknowledged by Divya (Support)',ago(0,0,x[2]-3)]]).concat(x[1]==='RESOLVED'?[['Resolved: customer safe',ago(0,0,x[2]-40)]]:[]).concat(x[1]==='FALSE_ALARM'?[['Marked false alarm after call',ago(0,0,x[2]-20)]]:[]),assignee:x[1]==='NEW'?'':'Divya (Support)'}});
D.incidents=[['Rash driving reported','Kavya Menon','Driver','MEDIUM','CLOSED'],['Harassment complaint','Priya Nair','Co-passenger','HIGH','OPEN'],['Bus breakdown at night','Rohan Mehta','Operator','MEDIUM','CLOSED'],['Lost luggage','Isha Agarwal','Operator','LOW','OPEN'],['Overcharging by conductor','Sanjay Gupta','Conductor','MEDIUM','IN_PROGRESS']].map((x,i)=>({id:'INC-'+(3001+i),title:x[0],customer:x[1],against:x[2],severity:x[3],status:x[4],at:ago(i*2+1),trip:D.trips[i+5].id,notes:'Investigated by safety team.'}));
D.sharing=Array.from({length:10},(_,i)=>({id:'SH'+(i+1),customer:D.customers[i].name,trip:D.trips[i+3].id,link:'abra.in/s/'+ri(100000,999999),opened:ri(0,6),created:ago(0,i*2),expires:fut(0,ri(3,20)),status:i<3?'ACTIVE':'EXPIRED'}));
D.safetyCfg={ackMinutes:3,escalateMinutes:8,police:'+91 100',team:['Divya (Support)','Kiran (Support)','Ravi (Safety lead)'],smsOn:true,whatsOn:true,notifyOperator:true,sosHold:3};
const lv=[[22,30],[42,48],[60,40],[35,66],[70,62],[50,22],[26,52],[78,34]];
D.live=D.trips.filter(t=>['IN_TRANSIT','DEPARTED','DELAYED','BOARDING'].includes(t.status)).slice(0,8).map((t,i)=>({tripId:t.id,route:t.route,bus:t.bus,operator:t.operator,driver:t.driver,state:i===3?'DELAYED':'LIVE',ping:ago(0,0,ri(0,2)),speed:ri(40,78),progress:ri(15,90),eta:fut(0,ri(1,7)),x:lv[i][0],y:lv[i][1],pax:ri(12,38),checkedIn:ri(8,30),stops:['Origin','Stop 1','Stop 2','Destination']}));
while(D.live.length<4){const t=D.trips[D.live.length+10];D.live.push({tripId:t.id,route:t.route,bus:t.bus,operator:t.operator,driver:t.driver,state:'LIVE',ping:ago(0,0,1),speed:60,progress:40,eta:fut(0,4),x:30+D.live.length*14,y:40,pax:22,checkedIn:18,stops:['Origin','Stop 1','Stop 2','Destination']})}
D.staff=[['Admin Super','Super Admin','SUPER_ADMIN','ACTIVE'],['Abishek','Admin','ADMIN','ACTIVE'],['Mynampati Asha','Admin','ADMIN','ACTIVE'],['Divya Rao','Support agent','SUPPORT','ACTIVE'],['Kiran Kumar','Support agent','SUPPORT','ACTIVE'],['Ravi Teja','Accountant','ACCOUNTS','ACTIVE'],['Sunita Paul','Accountant','ACCOUNTS','DEACTIVATED'],['Naveen Babu','Support agent','SUPPORT','INVITED']].map((x,i)=>({id:'SF'+(i+1),name:x[0],title:x[1],role:x[2],status:x[3],email:x[0].toLowerCase().replace(/[^a-z]+/g,'.')+'@abratravels.in',mfa:i%4!==3,last:ago(i,i),overrides:i===3?1:0}));
D.audit=Array.from({length:60},(_,i)=>{const a=pk(['Approved KYC submission','Rejected document','Changed commission','Published banner','Suspended operator','Approved refund','Changed setting','Created coupon','Marked SOS resolved','Exported report','Approved settlement','Blocked customer','Added staff user']),s=pk(D.staff.slice(0,6));return{id:'AU'+(i+1),at:ago(0,i*3+1),who:s.name,role:s.role,action:a,target:pk(['OP'+ri(1,14),'SUB-'+ri(1001,1006),'CR-'+ri(1,7),'BN'+ri(1,6),'ST-'+ri(6001,6012),'BK-'+ri(7001,7076)]),ip:'49.37.'+ri(1,255)+'.'+ri(1,255),sensitive:/commission|setting|suspended|settlement/i.test(a)}});
D.flags=[['live_tracking','Live tracking',true,'Customers see the bus on a map'],['whatsapp_chatbot','WhatsApp chatbot',false,'Booking help on WhatsApp'],['ai_support','AI support assistant',false,'AI answers common questions'],['women_safety','Women safety',true,'SOS and trip sharing'],['partner_api','Partner API',false,'External agents'],['dynamic_pricing','Dynamic pricing',false,'Fares change with demand'],['mobile_app','Mobile app booking',true,'Booking in the customer app'],['driver_app','Driver app',true,'Driver check-in and GPS'],['advanced_analytics','Advanced analytics',false,'Extra reports']].map(x=>({key:x[0],name:x[1],on:x[2],desc:x[3]}));
D.maint={scopes:{global:false,customer:false,operator:false,partner:false,admin:false},msg:'We are improving Abra Travels. Back soon.',from:'',to:''};
D.settings={company:{name:'Abra Travels Pvt Ltd',email:'hello@abratravels.in',phone:'+91 40 4000 1234',gstin:'36AAAAA0000A1Z5',address:'Hitech City, Hyderabad'},booking:{holdSeconds:600,maxSeats:6,cutoffMinutes:30,advanceDays:90},integrations:{whatsapp:{on:true,status:'Connected',phoneId:'1098xxxx',tested:ago(1)},email:{on:true,status:'Connected',host:'smtp.example.com',tested:ago(2)},sms:{on:false,status:'Not set up',provider:'(choose provider)',tested:null},razorpay:{on:true,status:'Test mode',key:'rzp_test_xxxxxxxx',secret:'masked',webhook:'whsec_masked',tested:ago(3)},maps:{on:false,status:'Not set up',provider:'Google Maps',key:'',tested:null},firebase:{on:true,status:'Connected',project:'abra-travels',tested:ago(1)}},security:{mfaRequired:true,sessionMinutes:30,passwordDays:90}};
D.notifs=[['New KYC submission','New Horizon Travels sent company documents','shield','kyc|SUB-1001',0],['Place request','Kaveri Express wants to add Hosur Bus Stand Gate 2','pin','places',1],['SOS from Meera Pillai','Needs help on Chennai to Coimbatore','alert','sos|SOS-2002',2],['Payment failed','A card payment failed','card','payments',3],['Settlement ready','ST-6003 is ready for approval','wallet','settlements',5],['Support ticket','TKT-8003 - Bus did not arrive','help','tickets|TKT-8003',6]].map((x,i)=>({id:'N'+i,t:x[0],b:x[1],i:x[2],go:x[3],at:ago(0,x[4]),read:i>3}));
D.series={days:Array.from({length:30},(_,i)=>{const d=new Date(NOW-(29-i)*DAY);return d.getDate()+'/'+(d.getMonth()+1)}),book:Array.from({length:30},(_,i)=>ri(60,190)+i*2),rev:Array.from({length:30},(_,i)=>ri(300,900)*1000+i*9000),occ:Array.from({length:30},()=>ri(52,88))};
return D}

/* ---------- extra data the client, customer and driver apps need ---------- */
function extend(D){
SEED=99;
const firsts=['Ramesh','Sunil','Anwar','Prakash','Naveen','Mahesh','Joseph','Venkat','Ravi','Kiran','Salim','Arjun','Gopi','Manoj','Babu','Hari','Deepak','Sekhar','Irfan','Vinod','Ajay','Suresh','Lokesh','Raju','Dinesh','Murali','Satish','Prasad','Yusuf','Ganesh','Shankar','Mohan','Pavan','Naresh','Ashok','Bhaskar','Chandu','Kishore','Ramu','Shiva','Tarun','Uday'];
const lasts=['K','Y','S','M','B','R','T','P','N','D'];let fi=0;
D.opStaff=[];
D.operators.forEach(o=>{['DRIVER','DRIVER','DRIVER','CONDUCTOR','MANAGER'].forEach((role,k)=>{const name=firsts[fi%firsts.length]+' '+lasts[fi%lasts.length];fi++;
D.opStaff.push({id:'ST'+(D.opStaff.length+101),operatorId:o.id,name,role,phone:'+91 9'+ri(100000000,999999999),licence:role==='DRIVER'?'TS'+ri(10,99)+' 20'+ri(10,24)+' 00'+ri(10000,99999):'',licExp:role==='DRIVER'?fut(ri(-10,700)).slice(0,10):'',status:k===2&&o.id==='OP2'?'ON_LEAVE':'ACTIVE',joined:ago(ri(30,900)).slice(0,10),pin:'1234'})})});
/* every trip gets a driver from its own operator */
D.trips.forEach(t=>{const ds=D.opStaff.filter(s=>s.operatorId===t.operatorId&&s.role==='DRIVER'&&s.status==='ACTIVE');t.driver=ds.length?ds[(parseInt(t.id.slice(-2),10)||0)%ds.length].name:'';t.taken=[];t.checkedIn=[];t.ladies=t.ladies||0});
D.live.forEach(l=>{const t=D.trips.find(x=>x.id===l.tripId);if(t)l.driver=t.driver});
/* a full week of trips and bookings for the main demo operator, so every app has real data to show */
(function(){const o=D.operators[0],bs=D.buses.filter(b=>b.operatorId===o.id);bs.forEach(b=>b.status='ACTIVE');const drv=D.opStaff.filter(s=>s.operatorId===o.id&&s.role==='DRIVER');
const rts=[D.routes[0],D.routes[1]];let n=0;
for(let d=-4;d<=6;d++){[0,1].forEach(k=>{const r=rts[k],b=bs[k%bs.length];let dep=new Date(NOW+d*DAY);dep.setHours(k?22:20,k?15:30,0,0);if(d===0)dep=new Date(NOW+(k?2.5:-3)*36e5);
const st=dep<NOW-r.hours*36e5?'ARRIVED':dep<NOW?(d<0?'DELAYED':'IN_TRANSIT'):'SCHEDULED';
const t={id:'TRP-'+(4001+n++),routeId:r.id,route:r.name,operatorId:o.id,operator:o.name,busId:b.id,bus:b.reg,busName:b.name,type:b.type,depart:dep.toISOString(),status:st,seats:b.seats,booked:0,held:0,blocked:1,fare:k?95000:110000,driver:drv[(n+k)%drv.length].name,conductor:'Kiran',taken:[],checkedIn:[],delay:st==='DELAYED'?35:0,delayReason:st==='DELAYED'?'Heavy traffic on the highway':''};
const nb=d>2?ri(1,3):ri(4,9);for(let j=0;j<nb;j++){const c=D.customers[(n*7+j*5)%D.customers.length],sn=ri(1,3),seats=[];
for(let q=0;q<sn;q++){const i=(j*sn+q)*3%t.seats;const lb=seatLabelFor(t,i);if(!t.taken.includes(lb)){t.taken.push(lb);seats.push(lb)}}if(!seats.length)continue;
const amt=t.fare*seats.length,cm=Math.round(amt*.1),bst=t.status==='ARRIVED'?'COMPLETED':'CONFIRMED',id='BK-'+(8001+D.bookings.length);
D.bookings.push({id,pnr:'ABR'+'KMQTX'[j%5]+(5000+D.bookings.length)+'ABCDE'[j%5],customerId:c.id,customer:c.name,phone:c.phone,tripId:t.id,route:t.route,operator:o.name,operatorId:o.id,travelDate:t.depart,seatList:seats.join(', '),seatsN:seats.length,amount:amt,commission:cm,gst:Math.round(amt*.05),fee:4900,discount:0,status:bst,mode:pk(['UPI','UPI','CARD','NETBANKING']),at:new Date(dep-ri(1,6)*DAY).toISOString(),coupon:''});
D.payments.push({id:'PAY-'+(9500+D.payments.length),bookingId:id,pnr:D.bookings[D.bookings.length-1].pnr,customer:c.name,operator:o.name,amount:amt+Math.round(amt*.05)+4900,mode:'UPI',status:'SUCCESS',gw:'pay_'+ri(100000,999999)+'Ab',at:new Date(dep-2*DAY).toISOString(),reason:'',settled:d<0});
if(t.status==='ARRIVED'||(t.status!=='SCHEDULED'&&j%2===0))t.checkedIn.push(id)}
t.booked=t.taken.length;D.trips.push(t);
if(['IN_TRANSIT','DELAYED'].includes(t.status))D.live.push({tripId:t.id,route:t.route,bus:t.bus,operator:o.name,driver:t.driver,state:t.status==='DELAYED'?'DELAYED':'LIVE',ping:ago(0,0,1),speed:k?38:64,progress:k?35:58,eta:fut(0,k?7:4),x:k?62:36,y:k?36:58,pax:t.booked,checkedIn:t.checkedIn.length,stops:r.stops?r.stops.map(s=>s.name):['Origin','Destination']})})}
o.trips=D.trips.filter(t=>t.operatorId===o.id).length})();
/* route stops from the places in each city */
D.routes.forEach((r,i)=>{const a=D.places.filter(p=>p.city===r.from).slice(0,3),b=D.places.filter(p=>p.city===r.to).slice(0,2);
r.operatorId=null;r.status='ACTIVE';r.stops=a.map((p,k)=>({placeId:p.id,name:p.name,city:p.city,offset:k*25,type:'BOARDING'})).concat(b.map((p,k)=>({placeId:p.id,name:p.name,city:p.city,offset:r.hours*60-30+k*25,type:'DROPPING'})))});
/* fares per operator, route and seat type */
D.fares=[];const seen={};D.trips.forEach(t=>{const k=t.operatorId+'|'+t.routeId+'|'+t.type;if(seen[k])return;seen[k]=1;D.fares.push({id:'FR'+(D.fares.length+1),operatorId:t.operatorId,routeId:t.routeId,route:t.route,seatType:t.type,weekday:t.fare,weekend:Math.round(t.fare*1.1/100)*100,festival:Math.round(t.fare*1.25/100)*100,from:ago(20).slice(0,10),status:'ACTIVE'})});
/* recurring schedules */
D.schedules=D.trips.filter(t=>t.status==='SCHEDULED').slice(0,8).map((t,i)=>({id:'SC'+(i+1),operatorId:t.operatorId,routeId:t.routeId,route:t.route,busId:t.busId,bus:t.bus,time:new Date(t.depart).toTimeString().slice(0,5),days:i%2?['Mon','Wed','Fri']:['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],from:ago(5).slice(0,10),to:fut(60).slice(0,10),status:'ACTIVE',fare:t.fare}));
/* seat layouts stored on the bus */
D.buses.forEach(b=>{b.decks=/Sleeper/.test(b.layout)?2:1;b.ladies=b.ladies||[]});
/* inbox for the client, customer and driver apps */
D.inbox=[];
const op1=D.operators[0];
[['Booking received','2 seats booked on '+(D.trips.find(t=>t.operatorId===op1.id)||{}).id,'bookings'],['Insurance expiring','A bus insurance expires in 10 days. Upload the new copy.','buses'],['Settlement processing','Your weekly settlement is being prepared.','settlements']].forEach((x,i)=>D.inbox.push({id:'IN'+(i+1),to:'client:'+op1.id,t:x[0],b:x[1],go:x[2],at:ago(0,i*3),read:i>0}));
/* keep each operator's KYC state in line with its latest company submission */
D.operators.forEach(o=>{const s=D.submissions.filter(x=>x.operatorId===o.id&&x.type==='COMPANY')[0];
 if(s){if(s.status==='APPROVED'){o.kyc='APPROVED';if(o.status==='PENDING_APPROVAL')o.status='ACTIVE'}else{o.kyc=s.status;o.status='PENDING_APPROVAL'}}
 else if(o.kyc!=='APPROVED'){o.kyc='DRAFT';o.status='PENDING_APPROVAL'}});
/* portal users of each operator (client app staff and roles) */
D.opUsers=[];D.operators.forEach(o=>{[[o.owner,'SUPER_ADMIN'],['Manager '+o.name.split(' ')[0],'ADMIN'],['Desk '+o.name.split(' ')[0],'SUPPORT'],['Accounts '+o.name.split(' ')[0],'ACCOUNTS']].forEach((u,k)=>D.opUsers.push({id:'OU'+(D.opUsers.length+1),operatorId:o.id,name:u[0],email:u[0].toLowerCase().replace(/[^a-z]+/g,'.')+'@'+o.email.split('@')[1],role:u[1],status:'ACTIVE',last:ago(k,k*2)}))});
D.reviews=[];
/* make each trip's booked seats match real booking records: "Booked 28" means 28 seats across the bookings */
(function(){let seq=30000;const cu=D.customers;
D.trips.forEach(t=>{if(t.taken&&t.taken.length)return;
 if(['DRAFT','CANCELLED'].includes(t.status)){t.taken=[];if(t.status==='DRAFT'){t.booked=0;t.held=0}return}
 const used=new Set(),n=t.seats;let idx=0;
 const take=k=>{const out=[];let g=0;while(out.length<k&&g++<n*3){const i=(idx*7+hashN(t.id))%n;idx++;const lb=seatLabelFor(t,i);if(!used.has(lb)){used.add(lb);out.push(lb)}}return out};
 D.bookings.filter(b=>b.tripId===t.id&&b.status!=='CANCELLED').forEach(b=>{const sl=take(b.seatsN);b.seatList=sl.join(', ');b.seatsN=sl.length;b.amount=t.fare*sl.length;b.commission=Math.round(b.amount*.1);b.gst=Math.round(b.amount*.05);const py=D.payments.find(x=>x.bookingId===b.id);if(py)py.amount=b.amount+b.gst+b.fee-(b.discount||0)});
 let need=Math.max(0,(t.booked||0)-used.size);
 while(need>0){const sl=take(Math.min(need,ri(1,4)));if(!sl.length)break;need-=sl.length;const c=cu[(seq*7)%cu.length],amt=t.fare*sl.length,id='BK-'+(++seq);
  D.bookings.push({id,pnr:'ABR'+'KMQTX'[seq%5]+(1000+seq)+'ABCDE'[seq%5],customerId:c.id,customer:c.name,phone:c.phone,tripId:t.id,route:t.route,operator:t.operator,operatorId:t.operatorId,travelDate:t.depart,seatList:sl.join(', '),seatsN:sl.length,amount:amt,commission:Math.round(amt*.1),gst:Math.round(amt*.05),fee:4900,discount:0,status:t.status==='ARRIVED'?'COMPLETED':'CONFIRMED',mode:pk(['UPI','UPI','CARD','NETBANKING']),at:new Date(Math.min(NOW-6e4*ri(30,600),new Date(t.depart)-DAY)).toISOString(),coupon:''});
  D.payments.push({id:'PAY-'+(20000+seq),bookingId:id,pnr:D.bookings[D.bookings.length-1].pnr,customer:c.name,operator:t.operator,amount:amt+Math.round(amt*.05)+4900,mode:'UPI',status:'SUCCESS',gw:'pay_'+ri(100000,999999)+'Ab',at:new Date(NOW-ri(1,5)*DAY).toISOString(),reason:'',settled:false})}
 t.taken=[...used];t.booked=t.taken.length;
 const stt=seatStates(t);t.blockedSeats=stt.map((x,i)=>x==='X'?seatLabelFor(t,i):null).filter(Boolean);t.blocked=t.blockedSeats.length});
D.trips.forEach(t=>{if(!t.blockedSeats)t.blockedSeats=[]})})();
DRX.seed(D);
D._uid=90000;D._day=new Date().toDateString();D._ver=7;
return D}

/* ---------- seat helpers used by every app ---------- */
const hashN=s=>{let h=7;for(const c of String(s))h=(h*31+c.charCodeAt(0))%1000003;return h};
const seatLabel=i=>(Math.floor(i/4)+1)+'ABCD'[i%4];
/* sleepers are numbered per deck (L1.. lower, U1.. upper); seaters by row and letter (1A..) */
const isSleeper=t=>/Sleeper/.test((t&&t.type)||'')&&!/Semi/.test((t&&t.type)||'');
/* seat price categories: seaters have window (corner) and normal seats, sleepers have lower and upper berths */
const CAT_NAMES={window:'Window / corner seat',normal:'Normal seat',lower:'Lower berth',upper:'Upper berth'};
const catsFor=t=>isSleeper(t)?['lower','upper']:['window','normal'];
const catOf=(t,l)=>isSleeper(t)?(/^U/.test(l)?'upper':'lower'):(/[AD]$/.test(l)?'window':'normal');
const fareFor=(t,l)=>t&&t.fares&&l?(t.fares[catOf(t,l)]||t.fare):t.fare;
function seatLabelFor(t,i){if(!isSleeper(t))return seatLabel(i);const half=Math.ceil(t.seats/2);return i<half?'L'+(i+1):'U'+(i-half+1)}
/* A available, B booked, H held, X blocked, L ladies-only (available) */
function seatStates(t){const n=t.seats,st=new Array(n).fill('A'),taken=new Set(t.taken||[]),hs=new Set((t.heldSeats||[]).map(h=>h.seat));
const order=[...Array(n).keys()].filter(i=>!taken.has(seatLabelFor(t,i))&&!hs.has(seatLabelFor(t,i))).sort((a,b)=>(hashN(t.id+a)%997)-(hashN(t.id+b)%997));
const bsx=new Set(t.blockedSeats||[]),base=Math.max(0,(t.booked||0)-taken.size),hb=Math.max(0,(t.held||0)-hs.size),rb=Math.max(0,(t.blocked||0)-bsx.size);
order.slice(0,base).forEach(i=>st[i]='B');order.slice(base,base+hb).forEach(i=>st[i]='H');order.slice(base+hb,base+hb+rb).forEach(i=>st[i]='X');
for(let i=0;i<n;i++){const l=seatLabelFor(t,i);if(taken.has(l))st[i]='B';else if(hs.has(l))st[i]='H';else if(bsx.has(l))st[i]='X'}
if(t.ladies)order.slice(-3).forEach(i=>{if(st[i]==='A')st[i]='L'});return st}
/* held seats expire after the hold time (10 minutes by default) */
function dropExpiredHolds(d){let ch=false;const now=Date.now();(d.trips||[]).forEach(t=>{if(!t.heldSeats||!t.heldSeats.length)return;const keep=t.heldSeats.filter(h=>h.until>now);if(keep.length!==t.heldSeats.length){t.held=Math.max(0,(t.held||0)-(t.heldSeats.length-keep.length));t.heldSeats=keep;ch=true}});return ch}

/* ---------- storage, live sync and notifications ---------- */
let db=null,last='',lastBody='',subs=[];
function read(){try{return JSON.parse(localStorage.getItem(KEY)||'null')}catch(e){return null}}
const body=d=>{const m=[d._by,d._at];delete d._by;delete d._at;const s=JSON.stringify(d);d._by=m[0];d._at=m[1];return s};
/* three-way merge: when another tab saved since our last sync, keep both sets of changes
   (the real backend gets this from the database; here two tabs can save at the same moment) */
const J=x=>JSON.stringify(x);
const idArr=a=>Array.isArray(a)&&a.length>0&&a.every(x=>x&&typeof x==='object'&&'id' in x);
function mergeArr(b,m,t){b=b||[];t=t||[];m=m||[];
if(idArr(m)||idArr(t)||idArr(b)){const B=new Map(b.map(x=>[x.id,x])),Mm=new Map(m.map(x=>[x.id,x])),T=new Map(t.map(x=>[x.id,x]));
 const out=t.filter(x=>!(B.has(x.id)&&!Mm.has(x.id))).map(x=>{const mi=Mm.get(x.id),bi=B.get(x.id);if(mi&&J(mi)!==J(bi))return bi?mergeVal(bi,mi,x):mi;return x});
 const added=m.filter(x=>!B.has(x.id)&&!T.has(x.id)),front=added.filter(x=>m.indexOf(x)<m.length/2),back=added.filter(x=>m.indexOf(x)>=m.length/2);return front.concat(out,back)}
const bs=new Set(b.map(J)),ms=new Set(m.map(J)),add=m.filter(x=>!bs.has(J(x))),rem=new Set(b.filter(x=>!ms.has(J(x))).map(J));
return t.filter(x=>!rem.has(J(x))).concat(add.filter(x=>!t.some(y=>J(y)===J(x))))}
function mergeVal(b,m,t){if(J(m)===J(b))return t;if(t===undefined||J(t)===J(b))return m;if(Array.isArray(m)||Array.isArray(t))return mergeArr(Array.isArray(b)?b:[],Array.isArray(m)?m:[],Array.isArray(t)?t:[]);
if(m&&t&&typeof m==='object'&&typeof t==='object'){const o={},bo=b&&typeof b==='object'?b:{};new Set([...Object.keys(t),...Object.keys(m)]).forEach(k=>{const inB=k in bo,inM=k in m,inT=k in t;
 if(inM&&inB&&J(m[k])===J(bo[k])){if(inT)o[k]=t[k];return}if(!inM&&inB)return;if(!inM){if(inT)o[k]=t[k];return}o[k]=inT&&inB?mergeVal(bo[k],m[k],t[k]):m[k]});return o}
return m}
function rebase(prev){try{const raw=localStorage.getItem(KEY);if(!raw||raw===last||!prev)return false;const theirs=JSON.parse(raw);if(body(theirs)===lastBody)return false;
 const res=mergeVal(prev,db,theirs);Object.keys(db).forEach(k=>{if(!(k in res))delete db[k]});Object.assign(db,res);return true}catch(e){console.error('merge failed',e);return false}}
function write(src){if(!db)return false;const b=body(db);if(b===lastBody)return false;
const prev=lastBody?JSON.parse(lastBody):null;try{route(prev,db,String(src||'').split('-')[0])}catch(e){console.error(e)}
const merged=rebase(prev);if(merged)setTimeout(()=>subs.forEach(f=>{try{f(db)}catch(e){console.error(e)}}),0);
lastBody=body(db);db._by=src||db._by;db._at=Date.now();const s=JSON.stringify(db);last=s;
try{localStorage.setItem(KEY,s)}catch(e){console.warn('Could not save shared data',e)}try{bc&&bc.postMessage(s)}catch(e){}return true}
let bc=null;try{bc=new BroadcastChannel('abra_proto')}catch(e){}
function incoming(s){if(!s||s===last)return;last=s;db=JSON.parse(s);lastBody=body(db);subs.forEach(f=>{try{f(db)}catch(e){console.error(e)}})}

/* ---------- event router: a change made in one app notifies the other apps ----------
   Compares the data before and after a save and sends notifications to everyone
   affected, except the app that made the change. The real backend does this with events. */
/* ---------- WhatsApp and email messages: one copy of each is kept so the admin and the customer can read them ---------- */
const rsF=p=>'Rs '+(Math.round(p)/100).toLocaleString('en-IN');
const whenF=t=>new Date(t.depart).toLocaleString('en-IN',{weekday:'short',day:'numeric',month:'short',hour:'numeric',minute:'2-digit',hour12:true});
const paidF=b=>b.amount+(b.gst||0)+(b.fee||0)-(b.discount||0);
const phF=x=>{const d=String(x||'').replace(/\D/g,'').slice(-10);return d.length===10?'+91 '+d:String(x||'')};
function msgSend(cur,c,kind,subject,text,bid,at,ov){if(!c)return;ov=ov||{};cur.messages=cur.messages||[];const pr=c.notif||{},t=at||new Date().toISOString(),nid=()=>'MS'+Date.now()+Math.floor(Math.random()*99999);
 if(pr.booking===false)return;
 const ph0=phF(ov.phone||c.phone),em0=ov.email||c.email;
 if(ph0&&pr.whatsapp!==false)cur.messages.unshift({id:nid(),at:t,to:c.id,name:c.name,address:ph0,channel:'WHATSAPP',kind,subject,body:text,bookingId:bid||'',status:'Delivered'});
 if(em0)cur.messages.unshift({id:nid(),at:t,to:c.id,name:c.name,address:em0,channel:'EMAIL',kind,subject,body:'Hi '+String(c.name).split(' ')[0]+',\n\n'+text+'\n\nThank you for travelling with Abra Travels.\nNeed help? support@abratravels.in',bookingId:bid||'',status:'Delivered'})}
const confirmTxt=(b,t)=>'Your booking is confirmed. PNR '+b.pnr+'. '+b.route+', '+whenF(t)+'. Seats '+b.seatList+'. Paid '+rsF(paidF(b))+'. Show this PNR when you board. Ticket: https://abra.in/t/'+b.pnr;
function seedMessages(d){const C=id=>d.customers.find(c=>c.id===id),T=id=>d.trips.find(t=>t.id===id);
 d.bookings.slice().sort((a,b)=>new Date(b.at)-new Date(a.at)).filter(b=>b.status!=='CANCELLED').slice(0,7).forEach((b,i)=>{const t=T(b.tripId);if(t)msgSend(d,C(b.customerId),'Booking confirmed','Booking confirmed: '+b.pnr,confirmTxt(b,t),b.id,new Date(Math.min(+new Date(b.at),Date.now()-(i+1)*37*6e4)).toISOString())});
 d.bookings.filter(b=>b.status==='CANCELLED').slice(0,2).forEach((b,i)=>msgSend(d,C(b.customerId),'Booking cancelled','Booking cancelled: '+b.pnr,'Your booking '+b.pnr+' ('+b.route+') has been cancelled. Any refund due is started and reaches your account in 5 to 7 working days.',b.id,new Date(Math.min(+new Date(b.at),Date.now()-(i+9)*53*6e4)).toISOString()));
 d.messages.sort((a,b)=>new Date(b.at)-new Date(a.at))}
function msgRoute(prev,cur,M){const C=id=>cur.customers.find(c=>c.id===id),T=id=>cur.trips.find(t=>t.id===id);
 let P2=M(prev.bookings);cur.bookings.forEach(b=>{const o=P2[b.id],c=C(b.customerId),t=T(b.tripId);if(!c||!t)return;
  if(!o&&b.status==='CONFIRMED')msgSend(cur,c,'Booking confirmed','Booking confirmed: '+b.pnr,confirmTxt(b,t),b.id,null,{phone:b.phone,email:b.email});
  else if(o&&o.status!=='CANCELLED'&&b.status==='CANCELLED')msgSend(cur,c,'Booking cancelled','Booking cancelled: '+b.pnr,'Your booking '+b.pnr+' ('+b.route+') has been cancelled. Any refund due is started and reaches your account in 5 to 7 working days.',b.id,null,{phone:b.phone,email:b.email})});
 P2=M(prev.refunds);cur.refunds.forEach(r=>{const o=P2[r.id],b=cur.bookings.find(x=>x.id===r.bookingId),c=b&&C(b.customerId);if(o&&o.status!==r.status&&r.status==='COMPLETED')msgSend(cur,c,'Refund processed','Refund processed: '+r.pnr,'Your refund of '+rsF(r.amount)+' for booking '+r.pnr+' has been paid. Reference '+(r.utr||'-')+'.',b&&b.id,null,b&&{phone:b.phone,email:b.email})});
 P2=M(prev.payments);cur.payments.forEach(p=>{if(P2[p.id]||p.status!=='FAILED')return;const c=cur.customers.find(x=>x.name===p.customer);msgSend(cur,c,'Payment failed','Payment failed','Your payment of '+rsF(p.amount)+' did not go through'+(p.reason?' ('+p.reason+')':'')+'. Your seats are held for a short time. Please try again in the app.','')});
 P2=M(prev.trips);cur.trips.forEach(t=>{const o=P2[t.id];if(!o||o.status===t.status)return;const bks=cur.bookings.filter(b=>b.tripId===t.id&&b.status==='CONFIRMED');
  if(t.status==='DELAYED')bks.forEach(b=>msgSend(cur,C(b.customerId),'Trip delayed','Bus delayed: '+b.pnr,'Your bus for '+t.route+' is running late'+(t.delay?' by about '+t.delay+' minutes':'')+(t.delayReason?' ('+t.delayReason+')':'')+'. PNR '+b.pnr+'. Track it live in the app.',b.id,null,{phone:b.phone,email:b.email}));
  if(t.status==='BOARDING')bks.forEach(b=>msgSend(cur,C(b.customerId),'Boarding now','Boarding now: '+b.pnr,'Boarding has started for '+t.route+'. Bus '+t.bus+'. PNR '+b.pnr+'. Please reach your boarding point.',b.id,null,{phone:b.phone,email:b.email}))})}
/* ---------- driver rules, driver reports and trip checklists ----------
   Abra keeps default templates and a minimum that cannot be turned off (locked items).
   Each operator gets its own copy to edit. Drivers only see what their operator set up. */
const DRX={};
DRX.defaults=()=>{
const P=(id,label,o)=>Object.assign({id,label,type:'yesno',level:'BLOCK',photo:false,scope:'ALL',locked:false,active:true,bad:'No',opts:[],optional:false},o||{});
const pre=[
P('licence_valid','Your driving licence is valid',{type:'auto',auto:'licence',locked:true}),
P('bus_docs_valid','Bus papers are valid (RC, insurance, permit, fitness, pollution)',{type:'auto',auto:'busdocs',locked:true}),
P('location_on','Location sharing is on',{type:'auto',auto:'location',locked:true}),
P('fit','I am fit to drive and well rested'),
P('rest','At least 8 hours of rest since your last trip',{type:'auto',auto:'rest'}),
P('alcohol','Alcohol test result',{type:'choice',opts:['Negative','Positive'],bad:'Positive'}),
P('tyres','Tyres, pressure and wheel nuts checked'),
P('brakes','Brakes checked'),
P('lights','Headlights, indicators, horn and wipers work'),
P('fuel','Fuel level',{type:'choice',opts:['Full','Half','Low'],bad:'Low',level:'WARN'}),
P('first_aid','First-aid kit is on the bus',{level:'WARN'}),
P('extinguisher','Fire extinguisher is on the bus and not expired'),
P('exit','Emergency exit and hammer are in place'),
P('cctv','CCTV and GPS device work',{level:'WARN'}),
P('clean','Bus is clean',{level:'WARN'}),
P('odo','Start odometer reading (km)',{type:'number',photo:true}),
P('conductor','Conductor is present'),
P('second','A second driver is on board',{scope:'LONG',level:'WARN'}),
P('manifest','Passengers are checked in',{type:'auto',auto:'manifest',level:'WARN'})];
const end=[
P('odo_end','End odometer reading (km)',{type:'number',photo:true}),
P('damage','The bus has new damage',{bad:'Yes',level:'WARN',photo:true}),
P('lost','Passengers left something on the bus',{bad:'Yes',level:'WARN'}),
P('fuel_add','Fuel filled today (litres)',{type:'number',level:'WARN',optional:true}),
P('cash','Cash collected (Rs)',{type:'number',level:'WARN',optional:true}),
P('parked','The bus is locked and parked safely',{level:'WARN'})];
const F=(id,label,type,o)=>Object.assign({id,label,type,required:false,opts:[],auto:''},o||{});
const reports=[
{id:'daily',name:'Daily report',freq:'DAILY',dueTime:'22:00',dueDay:'',active:true,fields:[
 F('trips','Trips today','auto',{auto:'trips'}),F('km','Distance','auto',{auto:'km'}),F('pax','Passengers carried','auto',{auto:'pax'}),F('noshow','Passengers who did not turn up','auto',{auto:'noshow'}),F('delays','Delays','auto',{auto:'delays'}),F('ontime','On time','auto',{auto:'ontime'}),F('sos','SOS alerts','auto',{auto:'sos'}),F('checks','Trip checklists','auto',{auto:'checks'}),
 F('fuel_l','Fuel filled (litres)','number'),F('fuel_amt','Fuel amount (Rs)','number'),F('toll','Toll paid (Rs)','number'),F('other','Other expenses (Rs)','number'),F('receipts','Receipts (fuel, toll, other)','file'),
 F('incident','Any incident today?','yesno',{required:true}),F('incident_note','If yes, what happened','text'),F('bus_problem','Problems with the bus','text'),F('notes','Notes for the team','text')]},
{id:'weekly',name:'Weekly report',freq:'WEEKLY',dueTime:'20:00',dueDay:'Sun',active:true,fields:[
 F('summary','This week','auto',{auto:'week'}),F('ontime','On time','auto',{auto:'ontime'}),F('sos','SOS alerts','auto',{auto:'sos'}),F('checks','Trip checklists','auto',{auto:'checks'}),F('rest_days','Rest days taken','number',{required:true}),F('issues','Problems this week','text'),F('comments','Your comments','text',{required:true})]},
{id:'incident',name:'Incident report',freq:'EVENT',dueTime:'',dueDay:'',active:true,fields:[
 F('type','What kind of incident','choice',{required:true,opts:['Accident','Breakdown','Theft','Passenger dispute','Police stop','Other']}),F('what','What happened','text',{required:true}),F('injuries','Was anyone hurt?','yesno',{required:true}),F('photos','Photos','photo',{required:true}),F('informed','Who did you inform','text')]},
{id:'defect',name:'Bus problem report',freq:'EVENT',dueTime:'',dueDay:'',active:true,fields:[
 F('part','Which part','choice',{required:true,opts:['Tyres','Brakes','Engine','AC','Lights','Body','Seats','Other']}),F('severity','How serious','choice',{required:true,opts:['Can still run','Fix soon','Do not run']}),F('description','What is wrong','text',{required:true}),F('photo','Photo','photo')]},
{id:'expense',name:'Expense claim',freq:'EVENT',dueTime:'',dueDay:'',active:true,fields:[
 F('amount','Amount (Rs)','number',{required:true}),F('category','What for','choice',{required:true,opts:['Fuel','Toll','Food','Repair','Parking','Other']}),F('receipt','Receipt','file',{required:true}),F('note','Note','text')]}];
return{pre,end,reports}};
const dClone=o=>JSON.parse(JSON.stringify(o));
DRX.ymd=d=>new Date(d).toISOString().slice(0,10);
DRX.weekKey=d=>{const x=new Date(d);const k=(x.getDay()+6)%7;x.setDate(x.getDate()-k);return DRX.ymd(x)};
DRX.rulesFor=(d,opId)=>{d=d||db;let r=(d.driverRules||[]).find(x=>x.operatorId===opId);if(!r){r=Object.assign({operatorId:opId,updated:new Date().toISOString()},dClone(d.ruleDefaults||DRX.defaults()));(d.driverRules=d.driverRules||[]).push(r)}return r};
DRX.itemsFor=(rules,kind,trip,dd)=>{const L=(kind==='PRE'?rules.pre:rules.end).filter(i=>i.active),long=trip&&(((dd||db).routes.find(r=>r.id===trip.routeId)||{}).hours||0)>=8;
return L.filter(i=>i.scope==='ALL'||(i.scope==='LONG'&&long)||(i.scope==='SLEEPER'&&isSleeper(trip))||(i.scope==='SEATER'&&trip&&!isSleeper(trip)))};
/* automatic checks, done from data the system already has */
DRX.auto=(kind,trip,driverName)=>{const d=db,now=Date.now();
if(kind==='licence'){const m=d.opStaff.find(s=>s.name===driverName&&s.role==='DRIVER');if(!m||!m.licExp)return{ok:true,msg:'Licence on file'};const ex=new Date(m.licExp);return ex>now?{ok:true,msg:'Valid till '+ex.toLocaleDateString('en-IN',{day:'numeric',month:'short',year:'numeric'})}:{ok:false,msg:'Licence expired on '+ex.toLocaleDateString('en-IN')+'. Give the new copy to your company.'}}
if(kind==='busdocs'){const b=d.buses.find(x=>x.reg===trip.bus);if(!b)return{ok:true,msg:'Papers on file'};if(b.status!=='ACTIVE')return{ok:false,msg:'This bus is '+String(b.status).toLowerCase().replace('_',' ')+'.'};const ex=new Date(b.insExp);return ex>now?{ok:true,msg:'Insurance till '+ex.toLocaleDateString('en-IN',{day:'numeric',month:'short',year:'numeric'})}:{ok:false,msg:'Insurance expired on '+ex.toLocaleDateString('en-IN')+'. Upload the new copy.'}}
if(kind==='location')return{ok:true,msg:'Sharing is on'};
if(kind==='rest'){const last=d.trips.filter(t=>t.driver===driverName&&t.status==='ARRIVED'&&t.id!==trip.id&&new Date(t.depart)<new Date(trip.depart)).sort((a,b)=>new Date(b.depart)-new Date(a.depart))[0];if(!last)return{ok:true,msg:'No earlier trip'};const r=d.routes.find(x=>x.id===last.routeId)||{hours:8},end=new Date(last.depart).getTime()+(r.hours||8)*36e5,h=(now-end)/36e5;return h>=8?{ok:true,msg:Math.round(h)+' hours since the last trip'}:{ok:false,msg:'Only '+Math.max(0,Math.round(h))+' hours since the last trip'}}
if(kind==='manifest'){const bk=d.bookings.filter(b=>b.tripId===trip.id&&b.status!=='CANCELLED'),miss=bk.filter(b=>!(trip.checkedIn||[]).includes(b.id)).length;return miss?{ok:false,msg:miss+' booking(s) not checked in. They become no-shows.'}:{ok:true,msg:'Everyone is checked in'}}
return{ok:true,msg:''}};
/* what is due, by driver */
DRX.statusList=(opId,driverName,d)=>{d=d||db;const rules=DRX.rulesFor(d,opId),out=[],now=new Date(),today=DRX.ymd(now);
const trips=d.trips.filter(t=>t.driver===driverName&&t.status!=='CANCELLED'&&t.status!=='DRAFT');
const find=(typeId,period)=>(d.driverReports||[]).find(r=>r.operatorId===opId&&r.driver===driverName&&r.typeId===typeId&&r.period===period);
rules.reports.filter(r=>r.active&&r.freq==='DAILY').forEach(rt=>{for(let k=0;k<=3;k++){const day=new Date(now.getTime()-k*864e5),ds=DRX.ymd(day);const had=trips.some(t=>DRX.ymd(t.depart)===ds&&new Date(t.depart)<=now);if(!had)continue;
 const due=new Date(ds+'T'+(rt.dueTime||'22:00')+':00'),rep=find(rt.id,ds),late=now>due;
 out.push({key:rt.id+'|'+ds,type:rt,period:ds,label:day.toLocaleDateString('en-IN',{weekday:'short',day:'numeric',month:'short'}),due,report:rep,state:rep?rep.status:(late?'OVERDUE':'DUE')})}});
rules.reports.filter(r=>r.active&&r.freq==='WEEKLY').forEach(rt=>{[0,1].forEach(k=>{const wk=DRX.weekKey(new Date(now.getTime()-k*7*864e5)),ws=new Date(wk+'T00:00:00'),we=new Date(ws.getTime()+7*864e5);
 if(!trips.some(t=>new Date(t.depart)>=ws&&new Date(t.depart)<we&&new Date(t.depart)<=now))return;
 const dow={Mon:0,Tue:1,Wed:2,Thu:3,Fri:4,Sat:5,Sun:6}[rt.dueDay||'Sun'],due=new Date(ws.getTime()+dow*864e5);const hm=(rt.dueTime||'20:00').split(':');due.setHours(+hm[0],+hm[1],0,0);const rep=find(rt.id,wk),late=now>due;
 out.push({key:rt.id+'|'+wk,type:rt,period:wk,label:'Week of '+ws.toLocaleDateString('en-IN',{day:'numeric',month:'short'}),due,report:rep,state:rep?rep.status:(late?'OVERDUE':'DUE')})})});
return out.sort((a,b)=>b.due-a.due)};
DRX.missing=(opId,d)=>{d=d||db;const out=[];d.opStaff.filter(s=>s.role==='DRIVER'&&s.status==='ACTIVE'&&(!opId||s.operatorId===opId)).forEach(s=>DRX.statusList(s.operatorId,s.name,d).filter(x=>x.state==='OVERDUE'||x.state==='DUE').forEach(x=>out.push({...x,driver:s.name,operatorId:s.operatorId,operator:(d.operators.find(o=>o.id===s.operatorId)||{}).name})));return out};
/* what the system knows about a driver's day or week: built from trips, bookings, checklists and SOS (the real build does this on the server) */
DRX.summary=(opId,driver,type,period,d)=>{d=d||db;const wk=type.freq==='WEEKLY',ws=wk?new Date(period+'T00:00:00'):null,we=wk?ws.getTime()+7*864e5:0;
const inP=t=>wk?(new Date(t.depart)>=ws&&new Date(t.depart)<we):DRX.ymd(t.depart)===period;
const one=t=>{const rt=d.routes.find(r=>r.id===t.routeId)||{},pre=(d.tripChecks||[]).find(c=>c.tripId===t.id&&c.kind==='PRE'),end=(d.tripChecks||[]).find(c=>c.tripId===t.id&&c.kind==='END'),bk=d.bookings.filter(b=>b.tripId===t.id&&b.status!=='CANCELLED'),done=t.status==='ARRIVED';
 const o1=pre&&pre.odometer,o2=end&&end.odometer,byOdo=o1&&o2&&o2>=o1,km=byOdo?o2-o1:(done?(rt.km||0):0);
 return{id:t.id,route:t.route,depart:t.depart,status:t.status,done,running:t.status==='IN_TRANSIT'||t.status==='BOARDING',pax:bk.reduce((a,b)=>a+b.seatsN,0),bookings:bk.length,noshow:done?bk.filter(b=>!(t.checkedIn||[]).includes(b.id)).length:0,delay:t.delay||0,reason:t.delayReason||'',km,kmFrom:byOdo?'odometer':(done?'route':''),hours:done?(rt.hours||0):0,sos:(d.sos||[]).filter(s=>s.trip===t.id).length,warn:[pre,end].filter(c=>c&&(c.result==='WARNINGS'||c.result==='OVERRIDDEN')).length}};
const L=d.trips.filter(t=>t.driver===driver&&t.status!=='CANCELLED'&&t.status!=='DRAFT'&&inP(t)).sort((a,b)=>new Date(a.depart)-new Date(b.depart)).map(one);
const sum=f=>L.reduce((a,x)=>a+f(x),0),ran=L.filter(x=>x.done||x.running),late=ran.filter(x=>x.delay>15);
const T={trips:L.length,done:L.filter(x=>x.done).length,km:sum(x=>x.km),hours:sum(x=>x.hours),pax:sum(x=>x.pax),bookings:sum(x=>x.bookings),noshow:sum(x=>x.noshow),delays:L.filter(x=>x.delay>0).length,delayMin:sum(x=>x.delay),onTime:ran.length?Math.round(100*(ran.length-late.length)/ran.length):null,sos:sum(x=>x.sos),warn:sum(x=>x.warn)};
let days=null;if(wk){const ld=v=>{const y=new Date(v);return y.getFullYear()+'-'+String(y.getMonth()+1).padStart(2,'0')+'-'+String(y.getDate()).padStart(2,'0')};days=[];for(let i=0;i<7;i++){const ds=ld(ws.getTime()+i*864e5),x=L.filter(t=>ld(t.depart)===ds);days.push({date:ds,trips:x.length,km:x.reduce((a,t)=>a+t.km,0),pax:x.reduce((a,t)=>a+t.pax,0),delays:x.filter(t=>t.delay>0).length})}}
return{kind:wk?'WEEKLY':'DAILY',period,driver,at:new Date().toISOString(),trips:L,totals:T,days}};
DRX.tripHead=sn=>sn.kind==='WEEKLY'?['Day','Trips','Km','Passengers','Delays']:['Trip','Route','Departs','Status','Passengers','Km','Delay'];
DRX.tripRows=sn=>{const hm=t=>new Date(t).toLocaleTimeString('en-IN',{hour:'2-digit',minute:'2-digit'}),nice=s=>({ARRIVED:'Completed',IN_TRANSIT:'Running',BOARDING:'Boarding',SCHEDULED:'Not started'}[s]||s);
if(sn.kind==='WEEKLY')return sn.days.map(x=>[new Date(x.date+'T00:00:00').toLocaleDateString('en-IN',{weekday:'short',day:'numeric',month:'short'}),x.trips,x.km+' km',x.pax,x.delays||'None']);
return sn.trips.map(x=>[x.id,x.route,hm(x.depart),nice(x.status),x.pax,x.km?x.km+' km':'-',x.delay?x.delay+' min'+(x.reason?' ('+x.reason+')':''):'On time']);};
DRX.autoVal=(kind,opId,driverName,period,answers,type,snap)=>{const sn=snap||DRX.summary(opId,driverName,type,period,db),T=sn.totals;
if(kind==='trips')return T.trips?T.done+' of '+T.trips+' trips completed':'No trips';
if(kind==='km')return T.km+' km'+(T.hours?' · about '+T.hours+' hours driving':'');
if(kind==='pax')return T.pax+' passengers in '+T.bookings+' bookings';
if(kind==='noshow')return T.noshow+' bookings';
if(kind==='delays')return T.delays?T.delays+' delayed, '+T.delayMin+' min in total':'None';
if(kind==='ontime')return T.onTime==null?'No trip has run yet':T.onTime+'% of trips on time';
if(kind==='sos')return T.sos?T.sos+' SOS alert'+(T.sos>1?'s':''):'None';
if(kind==='checks')return T.warn?T.warn+' checklist'+(T.warn>1?'s':'')+' with warnings':'All checklists clear';
if(kind==='week')return T.done+' of '+T.trips+' trips, '+T.km+' km, '+T.pax+' passengers, '+T.delays+' delays';
return''};
DRX.seed=D=>{D.ruleDefaults=DRX.defaults();D.driverRules=D.operators.map(o=>Object.assign({operatorId:o.id,updated:new Date().toISOString()},dClone(D.ruleDefaults)));D.driverReports=D.driverReports||[];D.tripChecks=D.tripChecks||[];
const op=D.operators[0],drv=D.opStaff.filter(s=>s.operatorId===op.id&&s.role==='DRIVER'),ago=(dd,h)=>new Date(Date.now()-dd*864e5-(h||0)*36e5).toISOString(),ymd=DRX.ymd;
const mk=(who,tid,dd,st,answers,comment,rv)=>{const day=ymd(ago(dd,0));D.driverReports.push({id:'DRP-'+(D.driverReports.length+1),operatorId:op.id,driver:who,typeId:tid,typeName:tid==='daily'?'Daily report':'Weekly report',period:tid==='weekly'?DRX.weekKey(ago(dd,0)):day,status:st,answers,files:{},submittedAt:ago(dd,-2),dueAt:ago(dd,-1),late:false,reviewComment:comment||'',reviewedBy:rv||'',snapshot:DRX.summary(op.id,who,D.driverRules[0].reports.find(x=>x.id===tid),tid==='weekly'?DRX.weekKey(ago(dd,0)):day,D)})};
if(drv[0]){mk(drv[0].name,'daily',1,'SUBMITTED',{fuel_l:96,fuel_amt:9600,toll:640,other:0,incident:'No',bus_problem:'',notes:'Smooth trip.'});
 mk(drv[0].name,'daily',2,'APPROVED',{fuel_l:90,fuel_amt:9000,toll:600,other:150,incident:'No',notes:''},'Looks good.','Owner');
 mk(drv[0].name,'weekly',7,'RETURNED',{rest_days:1,issues:'AC was weak on Tuesday.',comments:'Busy week.'},'Please attach the fuel receipts and tell us which bus had the AC problem.','Owner')}
if(drv[1])mk(drv[1].name,'daily',2,'APPROVED',{fuel_l:70,fuel_amt:7000,toll:500,other:0,incident:'No'},'','Owner');
D.trips.filter(t=>t.operatorId===op.id&&t.status==='ARRIVED').slice(0,6).forEach((t,i)=>{const R=D.driverRules.find(r=>r.operatorId===op.id);
 ['PRE','END'].forEach(kind=>{const items=DRX.itemsFor(R,kind,t,D).map(it=>({id:it.id,label:it.label,value:it.type==='number'?String(120000+i*400+(kind==='END'?420:0)):it.type==='choice'?(it.opts.find(o=>o!==it.bad)||''):it.type==='auto'?'Pass':(it.bad==='Yes'?'No':'Yes'),state:'PASS',level:it.level,files:[]}));
  if(i===2&&kind==='PRE'){const f=items.find(x=>x.id==='fuel');if(f){f.value='Low';f.state='FAIL'}}
  D.tripChecks.push({id:'TCH-'+(D.tripChecks.length+1),operatorId:op.id,tripId:t.id,route:t.route,driver:t.driver,kind,at:new Date(new Date(t.depart).getTime()-(kind==='PRE'?36e5:-6*36e5)).toISOString(),items,odometer:Number((items.find(x=>/odo/.test(x.id))||{}).value)||0,result:i===2&&kind==='PRE'?'WARNINGS':'PASSED',warnings:i===2&&kind==='PRE'?['Fuel level: Low']:[],override:null})})});
return D};

function drRoute(prev,cur,M,send){
 let P=M(prev.driverReports);(cur.driverReports||[]).forEach(r=>{const o=P[r.id];
  if(!o&&r.status==='SUBMITTED')send('client:'+r.operatorId,'Driver report received',r.driver+' sent the '+r.typeName.toLowerCase()+(r.late?' (late)':'')+' for '+r.period,'dreports');
  else if(o&&o.status!==r.status){if(r.status==='SUBMITTED')send('client:'+r.operatorId,'Driver report sent again',r.driver+' fixed the '+r.typeName.toLowerCase(),'dreports');if(r.status==='APPROVED')send('driver:'+r.driver,'Report approved',r.typeName+' for '+r.period+' was approved.','reports');if(r.status==='RETURNED')send('driver:'+r.driver,'Report sent back',r.typeName+': '+(r.reviewComment||'Please fix and send again'),'reports')}});
 P=M(prev.tripChecks);(cur.tripChecks||[]).forEach(c=>{if(P[c.id])return;
  if(c.result==='OVERRIDDEN'){send('client:'+c.operatorId,'Trip started with a failed check',c.driver+' started '+c.tripId+' after overriding: '+(c.warnings||[]).join('; '),'dreports');send('admin','Trip started with a failed check',c.driver+' ('+c.tripId+') overrode: '+(c.warnings||[]).join('; '),'dreports','alert')}
  else if(c.result==='WARNINGS'&&c.kind==='PRE')send('client:'+c.operatorId,'Trip checklist has warnings',c.driver+' started '+c.tripId+' with: '+(c.warnings||[]).join('; '),'dreports')})}
function route(prev,cur,src){if(!prev)return;
const M=a=>{const m={};(a||[]).forEach(x=>m[x.id]=x);return m};
const send=(to,t,b,go,i)=>{if(to.split(':')[0]===src)return;notify(to,t,b,go,i)};
const custOfTrip=tid=>[...new Set(cur.bookings.filter(b=>b.tripId===tid&&b.status==='CONFIRMED').map(b=>b.customerId))];
let P=M(prev.submissions);cur.submissions.forEach(s=>{const o=P[s.id];
 if(!o){if(s.status==='PENDING')send('admin','New KYC submission',s.operator+(s.type==='BUS'?' sent documents for bus '+s.bus:' sent company documents'),'kyc|'+s.id,'shield');return}
 if(o.status===s.status)return;
 if(s.status==='APPROVED')send('client:'+s.operatorId,s.type==='BUS'?'Bus approved':'Company approved',s.type==='BUS'?s.bus+' is approved. You can schedule trips on it.':'Your company is verified. Buses, trips and staff are now open.',s.type==='BUS'?'buses':'dashboard');
 else if(s.status==='REJECTED')send('client:'+s.operatorId,'Documents need fixing',s.docs.filter(d=>d.status==='REJECTED').map(d=>d.name+': '+d.reason).join('; '),'kyc');
 else if(s.status==='PENDING')send('admin','KYC corrections sent',s.operator+' replaced the rejected documents','kyc|'+s.id,'shield')});
P=M(prev.placeReqs);cur.placeReqs.forEach(r=>{const o=P[r.id],op=cur.operators.find(x=>x.name===r.operator);
 if(!o){send('admin','Place request',r.operator+' wants to add '+r.name+', '+r.city,'places','pin');return}
 if(o.status!==r.status&&op)send('client:'+op.id,'Place request '+r.status.toLowerCase(),r.name+(r.status==='REJECTED'?': '+r.reason:' can now be used in your routes.'),'routes')});
P=M(prev.settlements);cur.settlements.forEach(s=>{const o=P[s.id];if(!o)return;
 if(o.status!==s.status)send('client:'+s.operatorId,'Settlement '+s.status.toLowerCase().replace('_',' '),s.id+' for '+s.cycle,'settlements');
 if(!o.query&&s.query)send('admin','Settlement query',s.operator+': '+s.query,'settlements|'+s.id,'wallet');
 if(o.query&&!s.query)send('client:'+s.operatorId,'Query answered','Abra replied to your query on '+s.id,'settlements')});
P=M(prev.operators);cur.operators.forEach(op=>{const o=P[op.id];
 if(!o){send('admin','New operator signed up',op.name+' accepted the invitation','operators|'+op.id,'brief');return}
 if(o.status!==op.status)send('client:'+op.id,op.status==='SUSPENDED'?'Account suspended':'Account '+op.status.toLowerCase().replace('_',' '),op.status==='SUSPENDED'?'Your trips are hidden from customers. Contact Abra support.':'Your account status changed.','dashboard')});
P=M(prev.buses);cur.buses.forEach(b=>{const o=P[b.id];if(o&&o.status!==b.status&&b.status==='MAINTENANCE')send('client:'+b.operatorId,'Bus marked for maintenance',b.reg+' cannot be used for trips until it returns to service.','buses')});
P=M(prev.trips);cur.trips.forEach(t=>{const o=P[t.id];if(!o)return;
 if(o.driver!==t.driver&&t.driver){send('driver:'+t.driver,'New trip assigned',t.id+' - '+t.route+', '+new Date(t.depart).toLocaleString('en-IN',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'}),'trip|'+t.id);if(src!=='client')send('client:'+t.operatorId,'Driver changed',t.driver+' now drives '+t.id,'trips|'+t.id)}
 if(o.status===t.status)return;const cs=custOfTrip(t.id);
 if(t.status==='CANCELLED'){cur.bookings.filter(b=>b.tripId===t.id&&b.status==='CANCELLED').map(b=>b.customerId).concat(cs).forEach(c=>send('customer:'+c,'Trip cancelled',t.route+' on '+new Date(t.depart).toLocaleDateString('en-IN')+' was cancelled. Your full refund has started.','trips'));if(t.driver)send('driver:'+t.driver,'Trip cancelled',t.id+' - '+t.route,'home');send('client:'+t.operatorId,'Trip cancelled',t.id+' - '+t.route,'trips|'+t.id);send('admin','Trip cancelled',t.id+' by the operator','trips|'+t.id,'cal')}
 else if(t.status==='DELAYED'){cs.forEach(c=>send('customer:'+c,'Bus running late',t.route+' is delayed'+(t.delay?' by about '+t.delay+' minutes':'')+'.','trips'));send('admin','Trip delayed',t.id+(t.delayReason?': '+t.delayReason:''),'tracking','nav');send('client:'+t.operatorId,'Trip delayed',t.id+(t.delayReason?': '+t.delayReason:''),'trips|'+t.id)}
 else if(t.status==='BOARDING')cs.forEach(c=>send('customer:'+c,'Boarding started','Your bus '+t.bus+' is boarding now.','trips'));
 else if(t.status==='IN_TRANSIT')cs.forEach(c=>send('customer:'+c,'Your trip has started','Track your bus live in My trips.','trips'));
 else if(t.status==='ARRIVED')cs.forEach(c=>send('customer:'+c,'You have arrived','Thanks for travelling with Abra. Rate your trip.','trips'))});
P=M(prev.bookings);cur.bookings.forEach(b=>{const o=P[b.id];
 if(!o){send('client:'+b.operatorId,'New booking',b.pnr+' - '+b.seatsN+' seat(s) on '+b.route,'bookings');return}
 if(o.status!==b.status&&b.status==='CANCELLED'){send('client:'+b.operatorId,'Booking cancelled',b.pnr+' on '+b.route,'bookings');send('customer:'+b.customerId,'Booking cancelled',b.pnr+' was cancelled. Your refund has started.','trips')}});
P=M(prev.refunds);cur.refunds.forEach(r=>{const o=P[r.id],bk=cur.bookings.find(b=>b.id===r.bookingId);if(o&&o.status!==r.status&&bk)send('customer:'+bk.customerId,'Refund '+r.status.toLowerCase(),r.pnr+': refund of Rs '+Math.round(r.amount/100)+' is '+r.status.toLowerCase()+'.','trips')});
P=M(prev.sos);cur.sos.forEach(s=>{const o=P[s.id],t=cur.trips.find(x=>x.id===s.trip);
 if(!o){send('admin','SOS from '+s.customer,(s.note||'Needs help')+' on '+s.route,'sos|'+s.id,'alert');if(t){send('client:'+t.operatorId,'SOS on your bus',s.customer+' pressed SOS on '+t.id,'live');if(t.driver&&src!=='driver')send('driver:'+t.driver,'SOS on your bus','A passenger pressed SOS. Stop safely and check. Abra safety team is calling.','trip|'+t.id)}return}
 if(o.status!==s.status&&!s.customerId&&t&&t.driver&&/^Driver /.test(s.customer))send('driver:'+t.driver,'SOS '+s.status.toLowerCase().replace('_',' '),s.status==='ACKNOWLEDGED'?'Abra safety team has your alert and is calling you.':'Your SOS is now '+s.status.toLowerCase().replace('_',' ')+'.','sos');
 if(o.status!==s.status&&s.customerId)send('customer:'+s.customerId,'SOS '+s.status.toLowerCase().replace('_',' '),s.status==='ACKNOWLEDGED'?'Our safety team has your alert and is calling you.':'Your SOS is now '+s.status.toLowerCase().replace('_',' ')+'.','sos')});
P=M(prev.tickets);cur.tickets.forEach(t=>{const o=P[t.id];
 if(!o){send('admin','New support ticket',t.id+' - '+t.subject,'tickets|'+t.id,'help');return}
 if(t.msgs.length>o.msgs.length){const m=t.msgs[t.msgs.length-1];if(m[0]==='agent'&&t.customerId)send('customer:'+t.customerId,'Support replied',t.subject,'support');if(m[0]==='customer')send('admin','Customer replied',t.id+' - '+t.subject,'tickets|'+t.id,'help')}});
P=M(prev.offers);cur.offers.forEach(f=>{const o=P[f.id];if(!o&&f.status==='DRAFT'&&f.funder==='OPERATOR')send('admin','Offer request',f.code+' from an operator needs approval','offers','tag')});
msgRoute(prev,cur,M);drRoute(prev,cur,M,send);
}
function notify(to,t,b,go,icon){if(!db)return;const at=new Date().toISOString();
if(to==='admin')db.notifs.unshift({id:'N'+Date.now()+Math.floor(Math.random()*9999),t,b,i:icon||'bell',at,read:false,go});
else db.inbox.unshift({id:'IN'+Date.now()+Math.floor(Math.random()*9999),to,t,b,go,at,read:false})}
window.addEventListener('storage',e=>{if(e.key===KEY)incoming(e.newValue)});
if(bc)bc.onmessage=e=>incoming(e.data);
function fresh(){SEED=7;UID=5000;const d=extend(seed());d.messages=[];seedMessages(d);return d}
window.AbraStore={
init(){db=read();if(!db||db._ver!==7||db._day!==new Date().toDateString()){db=fresh();lastBody='';write('seed')}else{last=JSON.stringify(db);lastBody=body(db)}if(db.messages&&db.messages.some(m=>new Date(m.at)>Date.now()+6e4)){db.messages.forEach((m,i)=>{if(new Date(m.at)>Date.now()+6e4)m.at=new Date(Date.now()-(i+1)*29*6e4).toISOString()});db.messages.sort((a,b)=>new Date(b.at)-new Date(a.at));last=JSON.stringify(db);lastBody=body(db);try{localStorage.setItem(KEY,last)}catch(e){}}
if(!db.ruleDefaults){DRX.seed(db);last=JSON.stringify(db);lastBody=body(db);try{localStorage.setItem(KEY,last)}catch(e){}}
if(!db.messages||!db.messages.length){db.messages=[];seedMessages(db);last=JSON.stringify(db);lastBody=body(db);try{localStorage.setItem(KEY,last)}catch(e){}}return db},
get:()=>db,set(d){db=d},
save:src=>write(src),
on:f=>subs.push(f),
reset(){db=fresh();last='';lastBody='';write('reset');subs.forEach(f=>f(db));return db},
uid(p){db._uid=Math.max(db._uid||0,90000)+1;return p+'-'+db._uid},
/* to: 'admin' | 'client:OP1' | 'customer:CU1' | 'driver:Ramesh K' */
notify,
inbox:to=>(db&&db.inbox||[]).filter(n=>n.to===to),
seatLabel,seatLabelFor,seatStates,DR:DRX,CAT_NAMES,catsFor,catOf,fareFor,
/* price of one seat: operator fare + Abra commission + 5% GST (the convenience fee is per booking) */
price(t,label){const op=db.operators.find(o=>o.id===t.operatorId),L=db.commissions.filter(c=>c.status==='ACTIVE');
const c=L.find(c=>c.scope==='OPERATOR'&&op&&c.target===op.name)||L.find(c=>c.scope==='ROUTE'&&c.target===t.route)||L.find(c=>c.scope==='BUS_TYPE'&&c.target===t.type)||db.commissionDefault;
const fare=fareFor(t,label),cm=c.mode==='PERCENT'?Math.round(fare*c.value/10000):c.value,gst=Math.round((fare+cm)*.05);return{fare,cm,gst,seat:fare+cm+gst,fee:db.payoutCfg.fee}},
/* refund for cancelling a booking now, from the admin's cancellation slabs */
refundQuote(b){const t=db.trips.find(x=>x.id===b.tripId),h=t?(new Date(t.depart)-Date.now())/36e5:0;const sl=[...db.cancelSlabs].sort((a,c)=>c.hours-a.hours).find(s=>h>=s.hours);const pct=sl?sl.pct:0;return{hours:h,pct,amount:Math.round(b.amount*pct/100)}},
/* trips customers can book: published, operator verified and active, departing later */
dropExpiredHolds:()=>dropExpiredHolds(db),
bookable(t){const op=db.operators.find(o=>o.id===t.operatorId);return['SCHEDULED','BOARDING','DELAYED'].includes(t.status)&&!!op&&op.status==='ACTIVE'&&op.kyc==='APPROVED'&&new Date(t.depart)>Date.now()-15*6e4},
apps:{admin:'admin_demo_model.html',client:'client_demo_model.html',customer:'customer_demo_model.html',driver:'driver_demo_model.html',website:'website_demo_model.html'}
};
})();
