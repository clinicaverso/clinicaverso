"""Isolated PostgreSQL integration of the proposed migration; never connects to app DB.
Run: python3 scripts/phase4-schema.integration.py (local cluster socket required).
"""
import subprocess,json,uuid,concurrent.futures
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=['psql','-h','/tmp/phase4-postgres/socket','-p','55439','-U','lovable','-d','phase4_test','-X','-q','-A','-t','-v','ON_ERROR_STOP=1']
def raw(sql,check=True):
 r=subprocess.run(BASE+['-c',sql],capture_output=True,text=True)
 if check and r.returncode:raise RuntimeError(r.stderr)
 return r
subprocess.run(BASE[:-10],capture_output=True) if False else None
subprocess.run(['psql','-h','/tmp/phase4-postgres/socket','-p','55439','-U','lovable','-d','postgres','-c','CREATE DATABASE phase4_test'],capture_output=True,check=True)
raw((ROOT/'scripts/fixtures/phase4-base.sql').read_text())
raw((ROOT/'docs/phase4/proposed-migration.sql').read_text())
uid=lambda:str(uuid.uuid4())
u,v,sec,sec2,inactive,area,topic,future,sched,sched2=[uid() for _ in range(10)]
actor=u
results=[]
def run(sql,as_user=None,check=True):
 who=actor if as_user is None else as_user
 return raw(f"SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','{who}',false); {sql}",check)
def val(sql,as_user=None):return run(sql,as_user).stdout.strip().splitlines()[-1]
def ok(name,condition):
 results.append({'name':name,'passed':bool(condition)})
 if not condition:raise AssertionError(name)
def rejected(name,sql,as_user=None):ok(name,run(sql,as_user,False).returncode!=0)
def scalar(sql):return raw(sql).stdout.strip().splitlines()[-1]
raw(f"""INSERT INTO sections VALUES('{sec}','R1CM',true),('{sec2}','Outra seção de teste',true),('{inactive}','Inativa',false);
INSERT INTO areas VALUES('{area}','Cardiologia',true);
INSERT INTO topics VALUES('{topic}','{area}','Tema liberado',true),('{future}','{area}','Tema futuro',true);
INSERT INTO weekly_schedules VALUES('{sched}','{sec}','published'),('{sched2}','{sec2}','published');
INSERT INTO weekly_schedule_items VALUES('{uid()}','{sched}','{topic}',now()-interval '30 days'),('{uid()}','{sched}','{future}',now()+interval '30 days'),('{uid()}','{sched2}','{topic}',now()-interval '30 days');""")
cards=[]
for n in range(8):
 c=uid();cards.append(c)
 t=future if n==6 else topic;status='archived' if n==7 else 'published'
 raw(f"""INSERT INTO flashcards VALUES('{c}','TEST-{n}','{t}','{status}',1);
 INSERT INTO flashcard_sections VALUES('{c}','{sec}'),('{c}','{sec2}');
 INSERT INTO flashcard_versions(flashcard_id,version,code,area_id,topic_id,question,short_answer,comment,reference,editorial_difficulty,status,changed_by)
 VALUES('{c}',1,'TEST-{n}','{area}','{t}','Pergunta {n}','Resposta {n}','{{"type":"doc","content":[{{"type":"table","content":[]}}]}}','Referência','medium','{status}','{u}');""")
media_path=cards[0]+'/historical.png'
raw(f"INSERT INTO flashcard_media_versions(flashcard_id,card_version,media_id,type,placement,storage_path,caption,alt_text,display_order,is_active) VALUES('{cards[0]}',1,'{uid()}','image','question','{media_path}','Imagem','Imagem',0,true); INSERT INTO storage.objects(bucket_id,name) VALUES('flashcard-media','{media_path}');")
try:
 ok('Migração compila no PostgreSQL isolado',True)
 rejected('Catálogo sem autenticação bloqueado',f"SELECT study_catalog('{sec}')",'')
 rejected('Seção inativa bloqueada',f"SELECT study_catalog('{inactive}')")
 cat=json.loads(val(f"SELECT study_catalog('{sec}')"))
 ok('Catálogo omite tema futuro e cards arquivados',len(cat)==1 and cat[0]['total']==6)
 before=scalar('SELECT count(*) FROM study_sessions')
 rejected('Tema futuro não cria sessão',f"SELECT start_study_session('{sec}','{future}')")
 ok('Falha não deixa sessão vazia',scalar('SELECT count(*) FROM study_sessions')==before)
 sid=val(f"SELECT start_study_session('{sec}','{topic}')")
 ok('Criação repetida retoma mesma sessão',sid==val(f"SELECT start_study_session('{sec}','{topic}')"))
 data=json.loads(val(f"SELECT read_study_session('{sid}')"));op=data['item_id'];c=data['card']['id']
 ok('Exibição não conclui card nem cria estado',data['done']==0 and scalar('SELECT count(*) FROM user_flashcard_states')=='0')
 rejected('Avaliar sem revelar falha',f"SELECT rate_study_item('{sid}','{op}','again')")
 rejected('Outro aluno não lê sessão',f"SELECT read_study_session('{sid}')",v)
 ok('RLS esconde itens de outro aluno',val('SELECT count(*) FROM study_session_items',v)=='0')
 # Version and media change while question is displayed: pinned version remains 1.
 raw(f"INSERT INTO flashcard_versions SELECT gen_random_uuid(),flashcard_id,2,code,area_id,topic_id,subtopic_id,question,'Resposta nova',comment,reference,editorial_difficulty,status,changed_by FROM flashcard_versions WHERE flashcard_id='{c}' AND version=1; UPDATE flashcards SET version=2 WHERE id='{c}';")
 data=json.loads(val(f"SELECT read_study_session('{sid}',true)"))
 ok('Resposta, comentário e referência juntos na versão vista',data['revealed'] and data['card']['version']==1 and data['card']['short_answer']=='Resposta 0' and data['card']['comment']['type']=='doc' and data['card']['reference']=='Referência')
 ok('Mídia histórica segue a versão apresentada',data['card']['media'][0]['storage_path']==media_path and val('SELECT count(*) FROM storage.objects')=='1')
 raw(f"INSERT INTO user_flashcard_states(user_id,flashcard_id,lapse_count) VALUES('{u}','{c}',7)")
 sql=f"SELECT rate_study_item('{sid}','{op}','again')"
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:ids=list(pool.map(lambda _:val(sql),range(4)))
 ok('Quatro requisições concorrentes produzem um evento',len(set(ids))==1 and scalar('SELECT count(*) FROM learning_events')=='1')
 ok('Again preserva lapse_count 7 e incrementa uma vez para 8',scalar(f"SELECT lapse_count FROM user_flashcard_states WHERE user_id='{u}' AND flashcard_id='{c}'")=='8')
 ok('Contador de estudo incrementa apenas uma vez',scalar(f"SELECT review_count FROM user_flashcard_states WHERE user_id='{u}' AND flashcard_id='{c}'")=='1')
 ok('Estado anterior válido e versão real preservada',scalar('SELECT learning_state_before||\'|\'||card_version_seen FROM learning_events')=='new|1')
 ok('Nenhuma data ou parâmetro FSRS inventado',scalar(f"SELECT next_review_at IS NULL AND fsrs_stability IS NULL AND fsrs_difficulty IS NULL AND fsrs_data='{{}}'::jsonb AND scheduling_status='unscheduled' FROM user_flashcard_states WHERE user_id='{u}' AND flashcard_id='{c}'")=='t' and scalar('SELECT count(*) FROM review_events')=='0')
 rejected('Retry com avaliação diferente rejeitado',f"SELECT rate_study_item('{sid}','{op}','easy')")
 for rating in ['hard','good','easy']:
  data=json.loads(val(f"SELECT read_study_session('{sid}',true)"));oid=data['item_id'];cid=data['card']['id']
  val(f"SELECT rate_study_item('{sid}','{oid}','{rating}')")
  ok(f'Avaliação {rating} registra estado inicial new e não aumenta lapsos',scalar(f"SELECT e.rating='{rating}' AND e.learning_state_before='new' AND st.lapse_count=0 FROM learning_events e JOIN user_flashcard_states st USING(user_id,flashcard_id) WHERE e.operation_id='{oid}'")=='t')
 ok('Retomada preserva progresso confirmado',json.loads(val(f"SELECT read_study_session('{sid}')"))['done']==4)
 # Archive the next card after presentation: resume must skip without event.
 data=json.loads(val(f"SELECT read_study_session('{sid}',true)"));oid=data['item_id'];cid=data['card']['id']
 raw(f"UPDATE flashcards SET status='archived' WHERE id='{cid}'")
 rejected('Card arquivado durante sessão não recebe avaliação',f"SELECT rate_study_item('{sid}','{oid}','good')")
 data=json.loads(val(f"SELECT read_study_session('{sid}')"))
 ok('Retomada remove arquivado e mantém eventos anteriores',data['excluded']==1 and data['done']==4 and data['card']['id']!=cid)
 sid2=val(f"SELECT start_study_session('{sec2}','{topic}')")
 d2=json.loads(val(f"SELECT read_study_session('{sid2}')"))
 ok('Segunda seção não apresenta cards já estudados como novos',d2['total']==1)
 sv=val(f"SELECT start_study_session('{sec}','{topic}')",v);dv=json.loads(val(f"SELECT read_study_session('{sv}',true)",v));val(f"SELECT rate_study_item('{sv}','{dv['item_id']}','good')",v)
 ok('Alunos diferentes têm estados independentes no mesmo card',scalar(f"SELECT count(*) FROM user_flashcard_states WHERE flashcard_id='{c}'")=='2')
 rejected('Escrita direta de contadores bloqueada',f"UPDATE user_flashcard_states SET review_count=99 WHERE user_id='{u}'")
 rejected('Inserção direta de evento bloqueada',f"INSERT INTO learning_events(user_id,flashcard_id,session_id,operation_id,rating,card_version_seen,learning_state_before) VALUES('{u}','{c}','{sid}','{uid()}','easy',1,'new')")
 ok('Histórico append-only bloqueia alteração privilegiada',raw("UPDATE learning_events SET rating='easy'",False).returncode!=0)
 ok('Histórico append-only bloqueia exclusão privilegiada',raw('DELETE FROM learning_events',False).returncode!=0)
 # No unintended permissions on helpers.
 rejected('Helper privado indisponível diretamente',f"SELECT private.study_eligible('{c}','{sec}')")
 print(json.dumps({'environment':'isolated PostgreSQL fixture, not live application','passed':len(results),'results':results},ensure_ascii=False,indent=2))
finally:
 Path('/tmp/phase4-postgres/results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
