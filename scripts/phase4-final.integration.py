"""Controlled LIVE Phase 4 closure tests. All fixtures have a unique run marker.
Uses existing authorized test editor/student and creates one isolated student for
cross-user media/login tests. Never logs credentials or signed URLs.
Leaves synthetic content active for browser checks; --cleanup archives only manifest IDs.
"""
import os,json,uuid,concurrent.futures,time,sys,io,secrets
from pathlib import Path
import requests
from PIL import Image,ImageDraw
ROOT=Path('/tmp/browser/phase4-final');ROOT.mkdir(parents=True,exist_ok=True)
URL=os.environ['SUPABASE_URL'];KEY=os.environ['SUPABASE_PUBLISHABLE_KEY']
def make(key,token=None):
 s=requests.Session();s.headers.update({'apikey':key,'Prefer':'return=representation'})
 if token:s.headers['Authorization']='Bearer '+token
 elif not key.startswith('sb_'):s.headers['Authorization']='Bearer '+key
 return s
def load(path):
 j=json.loads(Path(path).read_text());return make(KEY,j['session']['access_token']),j['session']['user']['id']
editor,eid=load('/tmp/browser/phase4/editor-session.json')
student,uid=load('/tmp/browser/phase4-final/student-session.json')
assert eid=='f008a3eb-0bc0-4725-9f80-80d9495b9db9' and uid=='232701a6-e67f-408f-aa42-9118425773fd'
admin=make(os.environ['SUPABASE_SERVICE_ROLE_KEY'])
def req(c,method,path,row=None):return c.request(method,URL+path,json=row,timeout=30)
def value(r):
 if not r.ok:raise RuntimeError('Request failed: '+str(r.status_code))
 return r.json()
def read(c,t,q):return value(req(c,'GET','/rest/v1/'+t+'?'+q))
def insert(c,t,row):return value(req(c,'POST','/rest/v1/'+t,row))[0]
def patch(c,t,id,row):return value(req(c,'PATCH','/rest/v1/'+t+'?id=eq.'+id,row))
def rpc(c,n,args):return req(c,'POST','/rest/v1/rpc/'+n,args)
if '--cleanup' in sys.argv:
 m=json.loads((ROOT/'manifest.json').read_text())
 for id in m['cards']:patch(editor,'flashcards',id,{'status':'archived','updated_by':eid})
 for id in m['schedules']:patch(admin,'weekly_schedules',id,{'status':'archived'})
 for id in m['topics']:patch(editor,'topics',id,{'is_active':False})
 patch(admin,'sections',m['section'],{'is_active':False})
 print('Only identified synthetic content archived; all learning/version history preserved.')
 sys.exit()
resume=(ROOT/'manifest.json').exists();m=json.loads((ROOT/'manifest.json').read_text()) if resume else {'marker':'[Homologação final F4 '+uuid.uuid4().hex[:8]+']','cards':[],'schedules':[],'topics':[]}
marker=m['marker'];results=[]
def save():(ROOT/'manifest.json').write_text(json.dumps(m,indent=2))
def ok(name,condition):
 results.append({'name':name,'passed':bool(condition)});(ROOT/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
 print(('PASS ' if condition else 'FAIL ')+name,flush=True)
 if not condition:raise AssertionError(name)
sec=read(editor,'sections','slug=eq.r1cm&select=id')[0]['id']
topics=read(editor,'topics','is_active=eq.true&select=id,name,area_id')
topic=next(t for t in topics if t['name']=='Síndrome Coronariana Aguda');area=topic['area_id']
other={'id':m['section']} if resume else insert(admin,'sections',{'name':marker,'slug':'f4-'+uuid.uuid4().hex[:8],'is_active':True});m['section']=other['id'];save()
future=m['topics'].copy()
for i in range(0 if resume else 3):
 t=insert(editor,'topics',{'area_id':area,'name':marker+' tema futuro '+str(i),'slug':'f4-'+uuid.uuid4().hex});future.append(t['id']);m['topics'].append(t['id']);save()
def schedule(section,start,ts):
 s=insert(admin,'weekly_schedules',{'section_id':section,'week_start_date':start,'created_by':eid,'status':'draft'});m['schedules'].append(s['id']);save()
 for day,t in zip([1,3,5],ts):insert(admin,'weekly_schedule_items',{'weekly_schedule_id':s['id'],'topic_id':t,'release_day':day,'release_order':day})
 patch(admin,'weekly_schedules',s['id'],{'status':'published'});return s['id']
if not resume:
 schedule(other['id'],'2020-01-06',[topic['id']]+[t['id'] for t in topics if t['id']!=topic['id']][:2])
 import datetime;hx=uuid.uuid4().hex;future_date=m.setdefault('future_date',str(datetime.date(2090,1,2)+datetime.timedelta(weeks=int(hx[:4],16)%400)));save()
 schedule(sec,future_date,future)
otherstudent,otheruid=load(ROOT/'other-session.json');m['other_student']=otheruid;save()
ok('Second ordinary test student session valid, without changing principal admin',all(r['role']=='student' for r in read(otherstudent,'user_roles','user_id=eq.'+otheruid+'&select=role')))
comment={'type':'doc','content':[{'type':'paragraph','content':[{'type':'text','text':('Comentário clínico sintético longo para homologação. '*80)+'URLsemquebra'*40}]},{'type':'table','content':[{'type':'tableRow','content':[{'type':'tableHeader','content':[{'type':'paragraph','content':[{'type':'text','text':label}]}]} for label in ['Achado','Interpretação','Conduta']]},{'type':'tableRow','content':[{'type':'tableCell','content':[{'type':'paragraph','content':[{'type':'text','text':'Texto amplo de verificação '+('semquebra'*25)}]}]} for _ in range(3)]}]}]}
for i in range(4):
 c=insert(editor,'flashcards',{'topic_id':topic['id'],'question':marker+' pergunta '+str(i),'short_answer':'Resposta sintética de homologação','comment':comment,'status':'published','created_by':eid,'updated_by':eid});m['cards'].append(c['id']);save()
 for s in [sec,other['id']]:insert(editor,'flashcard_sections',{'flashcard_id':c['id'],'section_id':s})
# A useful-resolution synthetic ECG diagram, not patient data or diagnostic reference.
im=Image.new('RGB',(1400,600),'white');d=ImageDraw.Draw(im)
for x in range(0,1400,20):d.line((x,0,x,600),fill=(235,215,215))
for y in range(0,600,20):d.line((0,y,1400,y),fill=(235,215,215))
points=[]
for x in range(40,1360,200):points += [(x,320),(x+35,320),(x+45,290),(x+55,320),(x+80,320),(x+88,350),(x+100,100),(x+110,390),(x+120,320),(x+145,320),(x+160,270),(x+185,320)]
d.line(points,fill=(20,20,20),width=4);d.text((35,35),'ECG SINTETICO - HOMOLOGACAO - SEM DADOS DE PACIENTES',fill=(20,20,20))
im.save(ROOT/'ecg.png');buf=io.BytesIO();im.save(buf,format='PNG')
path=m['cards'][3]+'/ecg-final.png';r=editor.post(URL+'/storage/v1/object/flashcard-media/'+path,data=buf.getvalue(),headers={'Content-Type':'image/png'},timeout=30);ok('Useful-resolution private synthetic medical image uploaded',r.ok)
media=insert(editor,'flashcard_media',{'flashcard_id':m['cards'][3],'storage_path':path,'type':'image','placement':'question','caption':'ECG sintético de homologação — sem dados de pacientes','alt_text':'Traçado ECG sintético','created_by':eid});m['media']=media['id'];save()
def start(c,s):return value(rpc(c,'start_study_session',{'p_section':s,'p_topic':topic['id']}))
def session(c,s,reveal=True):return value(rpc(c,'read_study_session',{'p_session':s,'p_reveal':reveal}))
sid1=start(student,sec);sid2=start(student,other['id']);a=session(student,sid1);b=session(student,sid2)
ok('Same student pins same card in two active-section sessions',a['card']['id']==b['card']['id'])
def rate(args):return rpc(student,'rate_study_item',args)
args=[{'p_session':sid1,'p_operation':a['item_id'],'p_rating':'again'},{'p_session':sid2,'p_operation':b['item_id'],'p_rating':'easy'}]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(rate,args))
state=read(student,'user_flashcard_states','flashcard_id=eq.'+a['card']['id']+'&select=*')[0];events=read(student,'learning_events','flashcard_id=eq.'+a['card']['id']+'&select=*')
ok('Distinct concurrent cross-section ratings accept exactly one',sum(r.ok for r in rs)==1 and len(events)==1)
ok('Cross-section race increments review_count once and lapses only for winner',state['review_count']==1 and state['lapse_count']==(1 if events[0]['rating']=='again' else 0))
ok('Losing section skips globally learned card on resume',session(student,sid2)['card']['id']!=a['card']['id'])
a=session(student,sid1)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rs=list(pool.map(rate,[{'p_session':sid1,'p_operation':a['item_id'],'p_rating':r} for r in ['again','hard','good','easy']]))
ok('Four distinct ratings on same operation commit one event',sum(r.ok for r in rs)==1 and len(read(student,'learning_events','operation_id=eq.'+a['item_id']+'&select=id'))==1)
a=session(student,sid1);cid=a['card']['id'];op=a['item_id']
insert(admin,'user_flashcard_states',{'user_id':uid,'flashcard_id':cid,'lapse_count':2147483647,'review_count':0})
before=read(student,'study_sessions','id=eq.'+sid1+'&select=updated_at')[0]['updated_at'];previous=read(student,'user_flashcard_states','flashcard_id=eq.'+cid+'&select=*')[0]
r=rate({'p_session':sid1,'p_operation':op,'p_rating':'again'})
ok('Controlled real failure occurs in state update after event insert',not r.ok and 'integer out of range' in r.text)
ok('Live rollback leaves no partial event or item completion',read(student,'learning_events','operation_id=eq.'+op+'&select=id')==[] and read(student,'study_session_items','id=eq.'+op+'&select=event_id')[0]['event_id'] is None)
ok('Live rollback preserves state and session timestamp exactly',read(student,'user_flashcard_states','flashcard_id=eq.'+cid+'&select=*')[0]==previous and read(student,'study_sessions','id=eq.'+sid1+'&select=updated_at')[0]['updated_at']==before)
ok('Retry after rollback commits valid rating once',rate({'p_session':sid1,'p_operation':op,'p_rating':'good'}).ok)
# Synthetic max-lapse state deliberately preserved as test-only history; never rewrite events.
a=session(student,sid1);ok('Image card reached in persisted queue',a['card']['id']==m['cards'][3])
signpath='/storage/v1/object/sign/flashcard-media/'+path
ok('Other ordinary student cannot sign media without corresponding session',not req(otherstudent,'POST',signpath,{'expiresIn':120}).ok)
ok('Current media accessible in authorized session',req(student,'POST',signpath,{'expiresIn':120}).ok)
patch(editor,'flashcard_media',media['id'],{'is_active':False})
ok('Pinned historic media remains available after editorial deactivation',any(x['storage_path']==path for x in session(student,sid1)['card']['media']))
signed=value(req(student,'POST',signpath,{'expiresIn':120}));signedurl=URL+'/storage/v1'+signed['signedURL']
ok('Signed historical image resolves at useful resolution',requests.get(signedurl,timeout=30).ok)
patch(editor,'flashcards',m['cards'][3],{'status':'archived','updated_by':eid})
ok('Eligibility loss blocks new historical media URLs',not req(student,'POST',signpath,{'expiresIn':120}).ok)
ok('Previously signed URL remains usable after revocation before expiry',requests.get(signedurl,timeout=30).ok)
ok('Revoked session cannot load content or evaluate',session(student,sid1)['card'] is None and not rate({'p_session':sid1,'p_operation':a['item_id'],'p_rating':'good'}).ok)
print('Waiting for issued 120-second signed URL expiry...',flush=True)
deadline=time.monotonic()+125
while time.monotonic()<deadline:time.sleep(min(5,deadline-time.monotonic()))
ok('Previously signed URL rejected after its 120-second expiry',not requests.get(signedurl,timeout=30).ok)
patch(editor,'flashcards',m['cards'][3],{'status':'published','updated_by':eid});patch(editor,'flashcard_media',media['id'],{'is_active':True})
cat=value(rpc(student,'study_catalog',{'p_section':sec}));ft=[t for t in cat if t['id'] in future]
ok('Future catalog returns only authorized locked metadata and zero counts',len(ft)==3 and all(t['locked'] and t['total']==0 and t['studied']==0 and set(t)=={'id','name','area','release_at','locked','total','studied'} for t in ft))
futurecard=insert(editor,'flashcards',{'topic_id':future[0],'question':marker+' SECRET FUTURE QUESTION','short_answer':'SECRET FUTURE ANSWER','comment':comment,'status':'published','created_by':eid,'updated_by':eid});m['cards'].append(futurecard['id']);save();insert(editor,'flashcard_sections',{'flashcard_id':futurecard['id'],'section_id':sec})
ok('Future card and historical versions hidden by RLS',read(student,'flashcards','id=eq.'+futurecard['id']+'&select=*')==[] and read(student,'flashcard_versions','flashcard_id=eq.'+futurecard['id']+'&select=*')==[])
ok('Future session rejected without creating empty record',not rpc(student,'start_study_session',{'p_section':sec,'p_topic':future[0]}).ok and read(student,'study_sessions','topic_id=eq.'+future[0]+'&select=id')==[])
for table,row in [('learning_events',{'user_id':uid,'flashcard_id':m['cards'][0],'session_id':sid1,'operation_id':str(uuid.uuid4()),'rating':'good','card_version_seen':1,'learning_state_before':'new'}),('user_flashcard_states',{'user_id':uid,'flashcard_id':futurecard['id'],'review_count':999})]:
 ok('Direct INSERT denied: '+table,not req(student,'POST','/rest/v1/'+table,row).ok)
 for method in ['PATCH','DELETE']:ok('Direct '+method+' denied: '+table,not req(student,method,'/rest/v1/'+table+'?user_id=eq.'+uid,{'review_count':999} if method=='PATCH' and table=='user_flashcard_states' else {'rating':'easy'} if method=='PATCH' else None).ok)
sidbrowser=start(otherstudent,sec);m['browser_session']=sidbrowser;m['browser_card']=session(otherstudent,sidbrowser,False)['card']['id'];save()
print('Live final checks:',len(results),'passed. Browser fixtures recorded without credentials.')