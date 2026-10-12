/** Run with EDITORIAL_TEST_SESSION_FILE pointing to a locally minted auth session. Never prints credentials. */
import { readFileSync, writeFileSync } from 'node:fs';
import { createClient } from '@supabase/supabase-js';
import { readWorkbook, writeWorkbook, modelRows } from '../src/lib/editorial/workbook';
import { validateRows, canonical, type Taxonomy, type Existing } from '../src/lib/editorial/model';
const sessionPath=process.env['EDITORIAL_TEST_SESSION_FILE'];
if(!sessionPath)throw new Error('Set EDITORIAL_TEST_SESSION_FILE to a minted test session.');
const minted=JSON.parse(readFileSync(sessionPath,'utf8'));
const db=createClient(process.env['VITE_SUPABASE_URL']??'',process.env['VITE_SUPABASE_PUBLISHABLE_KEY']??'',{auth:{persistSession:false,autoRefreshToken:false},global:{headers:{Authorization:`Bearer ${minted.session.access_token}`}}});
const results:{name:string;passed:boolean;detail?:string}[]=[];
const assert=(name:string,condition:boolean,detail='')=>{results.push({name,passed:condition,detail});if(!condition)throw new Error(name+': '+detail);};
const fail=(r:any)=>{if(r.error)throw new Error(r.error.message);return r.data;};
const stamp='[Homologação XLSX '+Date.now()+']';const createdIds:string[]=[];
async function contextData(){const t={} as Taxonomy;for(const table of ['areas','topics','subtopics','sections','tags'] as const)t[table]=fail(await db.from(table).select('*'));const cards=fail(await db.from('flashcards').select('*,flashcard_sections(section_id),flashcard_tags(tag_id)'));return {taxonomy:t,existing:cards.map((c:any)=>({...c,sectionIds:c.flashcard_sections.map((s:any)=>s.section_id),tagIds:c.flashcard_tags.map((t:any)=>t.tag_id)})) as Existing[]};}
async function prepare(data:Record<string,string>[],mode:'create'|'update'='create'){const c=await contextData();return validateRows(readWorkbook(writeWorkbook(data),'test.xlsx'),c.taxonomy,c.existing,mode);}
async function confirm(rows:any[],mode='create',fingerprint?:string){return fail(await db.rpc('confirm_editorial_import',{p_filename:stamp+'.xlsx',p_fingerprint:fingerprint??crypto.randomUUID().replaceAll('-','').repeat(2),p_mode:mode,p_rows:rows.map(r=>({...r,decision:r.issues.length?'error':r.operation==='skip'?'skip':'import',reason:r.issues.map((i:any)=>i.message).join(';')}))}));}
async function process(id:string,limit=20){return fail(await db.rpc('process_editorial_import',{p_import_id:id,p_limit:limit}));}
async function detail(id:string){return fail(await db.from('editorial_import_rows').select('*').eq('import_id',id).order('line'));}
async function finish(id:string){for(let i=0;i<500;i++){const counts=await process(id);if(!counts.pending)return await detail(id);}throw new Error('Too many batches');}
const sample=(i:number):Record<string,string>=>({...modelRows()[i%3],tema:stamp+' tema '+i%3,pergunta:stamp+' pergunta '+i,comentario:'Comentário de homologação',tags:stamp+' tag',referencia:'Referência de teste',status:'draft'});
try{
 const before=fail(await db.from('flashcards').select('id',{count:'exact'})).length;
 const rows=await prepare(Array.from({length:10},(_,i)=>sample(i)));
 const after=fail(await db.from('flashcards').select('id',{count:'exact'})).length;
 assert('Prévia não grava cards',before===after);
 const id=await confirm(rows);const ten=await finish(id);createdIds.push(...ten.filter((r:any)=>r.flashcard_id).map((r:any)=>r.flashcard_id));
 assert('10 novos cards importados',ten.filter((r:any)=>r.status==='created').length===10,JSON.stringify(ten.filter((r:any)=>r.status==='error')));
 assert('Códigos automáticos globais',ten.every((r:any)=>/^CV-CARD-\d{6,}$/.test(r.code))&&new Set(ten.map((r:any)=>r.code)).size===10);
 const first=fail(await db.from('flashcards').select('*').eq('id',ten[0].flashcard_id).single());assert('Novo card versão 1 e draft',first.version===1&&first.status==='draft');
 const c=await contextData();const base={...sample(0),codigo:first.code};
 const reordered={content:first.comment.content,type:'doc'};
 let update=await prepare([{...base,comentario:JSON.stringify(reordered)}],'update');assert('Atualização idêntica ignorada com JSONB reordenado',update[0]?.operation==='skip',canonical(update[0]));
 const section=c.taxonomy.sections.find(s=>s.name==='TECM');if(!section)throw new Error('Missing TECM');
 update=await prepare([{...base,secao:'R1CM;TECM'}],'update');const sectionJob=await confirm(update,'update');await finish(sectionJob);const sectionCard=fail(await db.from('flashcards').select('*').eq('id',first.id).single());assert('Somente seção mantém versão 1, ID e código',sectionCard.version===1&&sectionCard.id===first.id&&sectionCard.code===first.code);
 const revised={...base,secao:'R1CM;TECM',resposta:'Resposta alterada',comentario:'Comentário alterado'};update=await prepare([revised],'update');await finish(await confirm(update,'update'));const edited=fail(await db.from('flashcards').select('*').eq('id',first.id).single());assert('Resposta e comentário alterados geram versão 2',edited.version===2&&edited.short_answer==='Resposta alterada');
 const versions=fail(await db.from('flashcard_versions').select('version').eq('flashcard_id',first.id));assert('Versões históricas preservadas',versions.length===2);
 update=await prepare([{...revised,referencia:'',tags:'',subtema:'',dificuldade:'',status:''}],'update');assert('Opcionais vazios preservam valores',update[0]?.operation==='skip');
 const fifty=await prepare(Array.from({length:50},(_,i)=>sample(i+20)));const fiftyId=await confirm(fifty);const firstBatch=await process(fiftyId,5);assert('Interrupção deixa 45 linhas pendentes',firstBatch.pending===45&&firstBatch.created===5);const all50=await finish(fiftyId);createdIds.push(...all50.filter((r:any)=>r.flashcard_id).map((r:any)=>r.flashcard_id));assert('Retomada conclui 50 cards',all50.filter((r:any)=>r.status==='created').length===50);
 const fingerprint='a'.repeat(64);const retryRows=await prepare([sample(100)]);const retryId=await confirm(retryRows,'create',fingerprint);const repeatId=await confirm(retryRows,'create',fingerprint);assert('Confirmação repetida retorna mesma operação',retryId===repeatId);const once=await finish(retryId);createdIds.push(...once.map((r:any)=>r.flashcard_id).filter(Boolean));await finish(retryId);assert('Reprocessar não duplica', (await detail(retryId)).length===1);
 const bad=await prepare([sample(110),{...sample(111),resposta:''},{...sample(112),secao:'Seção inexistente'}]);assert('Campos e seção inválida reportados nas linhas reais',bad[1]?.line===3&&bad[1].issues.some(i=>i.column==='resposta')&&bad[2]?.issues.some(i=>i.column==='secao'));const mixed=await finish(await confirm(bad));createdIds.push(...mixed.map((r:any)=>r.flashcard_id).filter(Boolean));assert('Mistura válidas inválidas importa só 1, reporta 2 erros',mixed.filter((r:any)=>r.status==='created').length===1&&mixed.filter((r:any)=>r.status==='error').length===2);
 const duplicates=await prepare([sample(120),sample(120)]);assert('Duplicata interna sinalizada',duplicates[1]?.warnings.some(w=>w.includes('idêntica'))??false);
 const known=await prepare([{...base,codigo:first.code}],'create');assert('Modo criação não atualiza código existente',known[0]?.operation==='skip');
 const current=fail(await db.from('flashcards').select('*').eq('id',first.id).single());const roundtrip=await prepare([{...revised,comentario:JSON.stringify(current.comment)}],'update');assert('Exportação/reimportação preserva conteúdo sem alteração',roundtrip[0]?.operation==='skip');
 const twoHundred=await prepare(Array.from({length:200},(_,i)=>sample(i+200)));const volume=await finish(await confirm(twoHundred));createdIds.push(...volume.map((r:any)=>r.flashcard_id).filter(Boolean));assert('Volume real de 200 cards no banco',volume.filter((r:any)=>r.status==='created').length===200);
 const collision=await prepare([sample(900)]);collision[0].cells.resposta='';const atomic=await finish(await confirm(collision));assert('Falha do executor é isolada e não cria card parcial',atomic[0].status==='error'&&!atomic[0].flashcard_id);
 writeFileSync('/tmp/browser/phase3/integration-results.json',JSON.stringify({stamp,results,createdIds},null,2));
 console.log(JSON.stringify({passed:results.filter(r=>r.passed).length,total:results.length,created:createdIds.length,results},null,2));
}finally{
 if(createdIds.length)fail(await db.from('flashcards').update({status:'archived',updated_by:minted.user_id}).in('id',createdIds));
}
