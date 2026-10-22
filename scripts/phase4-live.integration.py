"""Live Phase 4 tests. Uses minted editor/student session files; never prints credentials.
Run with PHASE4_EDITOR_SESSION_FILE and PHASE4_STUDENT_SESSION_FILE.
Creates identified test cards; archives fixtures in finally, never deletes history.
"""
import os,json,uuid,base64,concurrent.futures
from pathlib import Path
import requests
URL=os.environ['SUPABASE_URL'];KEY=os.environ['SUPABASE_PUBLISHABLE_KEY']
def client(file):
 m=json.loads(Path(file).read_text());s=requests.Session();s.headers.update({'apikey':KEY,'Authorization':'Bearer '+m['session']['access_token'],'Prefer':'return=representation'});return s,m['session']['user']['id']
editor,editor_id=client(os.environ['PHASE4_EDITOR_SESSION_FILE']);student,student_id=client(os.environ['PHASE4_STUDENT_SESSION_FILE'])
assert editor_id=='f008a3eb-0bc0-4725-9f80-80d9495b9db9' and student_id=='232701a6-e67f-408f-aa42-9118425773fd','Expected authorized test users'
results=[];ids=[];prefix='[Homologação Fase 4 '+uuid.uuid4().hex[:8]+']'
def request(c,method,path,data=None):return c.request(method,URL+path,json=data,timeout=30)
def data(r):
 if not r.ok:raise RuntimeError(r.status_code,r.text[:250])
 return r.json()
def read(c,table,query):return data(request(c,'GET','/rest/v1/'+table+'?'+query))
def rpc(c,name,args):return request(c,'POST','/rest/v1/rpc/'+name,args)
def ok(name,condition):
 results.append({'name':name,'passed':bool(condition)});print(('PASS ' if condition else 'FAIL ')+name)
 if not condition:raise AssertionError(name)
def insert(table,row):return data(request(editor,'POST','/rest/v1/'+table,row))[0]
def patch(table,id,row):return data(request(editor,'PATCH','/rest/v1/'+table+'?id=eq.'+id,row))[0]
try:
 sec=read(editor,'sections','slug=eq.r1cm&select=id')[0]['id'];topic=read(editor,'topics','name=eq.Síndrome Coronariana Aguda&select=id')[0]['id']
 review_before=len(read(student,'review_events','select=id'))
 for n in range(4):
  c=insert('flashcards',{'topic_id':topic,'question':prefix+' questão '+str(n),'short_answer':'Resposta original','comment':{'type':'doc','content':[{'type':'paragraph','content':[{'type':'text','text':'Comentário de teste'}]}]},'reference':'Conteúdo sintético de homologação','status':'published' if n<3 else 'draft','created_by':editor_id,'updated_by':editor_id});ids.append(c['id']);insert('flashcard_sections',{'flashcard_id':c['id'],'section_id':sec})
 first=ids[0];path=first+'/historical-test.png';upload=editor.post(URL+'/storage/v1/object/flashcard-media/'+path,data=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jHgoAAAAASUVORK5CYII='),headers={'Content-Type':'image/png'},timeout=30);ok('Editor uploads private image',upload.ok)
 media=insert('flashcard_media',{'flashcard_id':first,'type':'image','placement':'question','storage_path':path,'caption':'Homologação','alt_text':'Imagem de teste','display_order':0,'created_by':editor_id})
 def start():return data(rpc(student,'start_study_session',{'p_section':sec,'p_topic':topic}))
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:sessions=list(pool.map(lambda _:start(),range(4)))
 sid=sessions[0];ok('Concurrent start resumes one session',len(set(sessions))==1)
 def session(reveal=False):return data(rpc(student,'read_study_session',{'p_session':sid,'p_reveal':reveal}))
 d=session();op=d['item_id'];card=d['card'];ok('Unrevealed response conceals answer and comment',not d['revealed'] and card['short_answer'] is None and card['comment'] is None)
 ok('Rating without reveal rejected',not rpc(student,'rate_study_item',{'p_session':sid,'p_operation':op,'p_rating':'again'}).ok)
 ok('Reading does not complete item',session()['done']==0)
 ok('Other user cannot read session',not rpc(editor,'read_study_session',{'p_session':sid}).ok)
 ok('Other user RLS cannot see items',read(editor,'study_session_items','session_id=eq.'+sid+'&select=id')==[])
 ok('Draft inaccessible to student',read(student,'flashcards','id=eq.'+ids[3]+'&select=id')==[])
 version=card['version'];original=card['short_answer'];patch('flashcards',card['id'],{'short_answer':'Resposta nova após exibição','updated_by':editor_id})
 patch('flashcard_media',media['id'],{'is_active':False})
 d=session(True);ok('Version pinned despite real editorial trigger',d['card']['version']==version and d['card']['short_answer']=='Resposta original')
 ok('Historic media preserved in pinned version',any(m['storage_path']==path for m in d['card']['media']))
 signed=rpc(student,'read_study_session',{'p_session':sid})
 sign=request(student,'POST','/storage/v1/object/sign/flashcard-media/'+path,{'expiresIn':120});ok('Historical media signing authorized for pending session',sign.ok)
 ok('Other account cannot sign historic student media',not request(editor,'GET','/rest/v1/study_sessions?id=eq.'+sid).json())
 def rate():return rpc(student,'rate_study_item',{'p_session':sid,'p_operation':op,'p_rating':'again'})
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:responses=list(pool.map(lambda _:rate(),range(8)))
 ok('Eight duplicate requests return one event',all(r.ok for r in responses) and len({data(r) for r in responses})==1)
 event=read(student,'learning_events','operation_id=eq.'+op+'&select=*');state=read(student,'user_flashcard_states','flashcard_id=eq.'+card['id']+'&select=*')[0]
 ok('One event and one counter increment',len(event)==1 and state['review_count']==1 and state['lapse_count']==1)
 ok('Seen version and initial state preserved',event[0]['card_version_seen']==version and event[0]['learning_state_before']=='new')
 ok('No artificial scheduling or FSRS',state['next_review_at'] is None and state['fsrs_stability'] is None and state['fsrs_difficulty'] is None and state['scheduling_status']=='unscheduled')
 ok('Different retry rating rejected',not rpc(student,'rate_study_item',{'p_session':sid,'p_operation':op,'p_rating':'easy'}).ok)
 ok('Historic media signing revoked after rating',not request(student,'POST','/storage/v1/object/sign/flashcard-media/'+path,{'expiresIn':120}).ok)
 d=session(True);archived=d['card']['id'];patch('flashcards',archived,{'status':'archived','updated_by':editor_id})
 ok('Archive during session prevents rating',not rpc(student,'rate_study_item',{'p_session':sid,'p_operation':d['item_id'],'p_rating':'good'}).ok)
 nextd=session();ok('Resume excludes archived card',nextd['excluded']>=1 and (nextd['card'] is None or nextd['card']['id']!=archived))
 ok('Direct counter writes denied',not request(student,'PATCH','/rest/v1/user_flashcard_states?flashcard_id=eq.'+card['id'],{'review_count':99}).ok)
 request(student,'PATCH','/rest/v1/learning_events?operation_id=eq.'+op,{'rating':'easy'})
 ok('Learning event cannot be changed by student',read(student,'learning_events','operation_id=eq.'+op+'&select=rating')[0]['rating']=='again')
 request(student,'DELETE','/rest/v1/learning_events?operation_id=eq.'+op)
 ok('Learning event cannot be deleted by student',len(read(student,'learning_events','operation_id=eq.'+op+'&select=id'))==1)
 ok('Unknown topic fails without empty session',not rpc(student,'start_study_session',{'p_section':sec,'p_topic':str(uuid.uuid4())}).ok)
 ok('Review event history unchanged',len(read(student,'review_events','select=id'))==review_before)
except Exception as e:
 print('Stopped:',str(e)[:300]);raise
finally:
 for id in ids:
  r=request(editor,'PATCH','/rest/v1/flashcards?id=eq.'+id,{'status':'archived','updated_by':editor_id})
  if not r.ok:print('Fixture archive failed:',id)
 Path('/tmp/browser/phase4').mkdir(parents=True,exist_ok=True)
 Path('/tmp/browser/phase4/live-results.json').write_text(json.dumps({'results':results,'fixtures':ids},indent=2))
