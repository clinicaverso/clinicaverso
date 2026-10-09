import type { SheetRow } from './workbook';
export const normalize = (s:string) => s.trim().replace(/\s+/g,' ').toLocaleLowerCase('pt-BR');
export const names = (s:string) => [...new Set(s.split(';').map(s=>s.trim().replace(/\s+/g,' ')).filter(Boolean))];
export type Taxon = {id:string;name:string;is_active:boolean;area_id?:string;topic_id?:string};
export type Taxonomy = {areas:Taxon[];topics:Taxon[];subtopics:Taxon[];sections:Taxon[];tags:Taxon[]};
export type Existing = {id:string;code:string;question:string;updated_at:string; [key:string]: any};
export type PreviewRow = SheetRow & {operation:'create'|'update'|'skip'; warnings:string[]; proposed:string[]; expected:string|null; comment:Record<string,any>|null; changed?:string[]};
const nodeTypes = new Set(['doc','paragraph','text','heading','bulletList','orderedList','listItem','blockquote','codeBlock','hardBreak','horizontalRule','table','tableRow','tableCell','tableHeader','image']);
const markTypes = new Set(['bold','italic','strike','code','underline','link']);
export function safeComment(s:string):Record<string,any> {
  if (/<\/?[a-z][^>]*>/i.test(s)) throw new Error('HTML/scripts não são permitidos; use texto ou JSON seguro.');
  if (!s.trim().startsWith('{')) return {type:'doc',content:s.split(/\r?\n/).map(t=>({type:'paragraph',...(t ? {content:[{type:'text',text:t}]} : {})}))};
  const root=JSON.parse(s); let count=0;
  const check=(n:any,depth:number):void => {if (!n || typeof n!=='object' || Array.isArray(n) || depth>20 || ++count>10000 || !nodeTypes.has(n.type)) throw new Error('Documento rico inválido ou excessivo.'); if (Object.keys(n).some(k=>!['type','text','content','attrs','marks'].includes(k))) throw new Error('Propriedade de documento não permitida.'); if (n.text!==undefined && typeof n.text!=='string') throw new Error('Texto inválido.'); if (n.attrs) {const allowed:Record<string,string[]>= {heading:['level'],orderedList:['start','type'],codeBlock:['language'],tableCell:['colspan','rowspan','colwidth'],tableHeader:['colspan','rowspan','colwidth'],image:['src','alt','title','width','height'],paragraph:['textAlign'],headingExtra:[]}; if (Object.keys(n.attrs).some(k=>!(allowed[n.type]??[]).includes(k))) throw new Error('Atributo não permitido.'); if (n.type==='image' && !/^https:\/\//i.test(n.attrs.src??'')) throw new Error('Imagens devem usar https.'); } if(n.marks!==undefined){if(!Array.isArray(n.marks))throw new Error('Marcas inválidas.');for(const m of n.marks){if(!markTypes.has(m.type)||Object.keys(m).some(k=>!['type','attrs'].includes(k)))throw new Error('Marca não permitida.');if(m.attrs && (m.type!=='link'||Object.keys(m.attrs).some(k=>!['href','target','rel','class'].includes(k))|| !/^(https?:\/\/|mailto:)/i.test(m.attrs.href??'')))throw new Error('Link inválido.');}} if(n.content!==undefined){if(!Array.isArray(n.content))throw new Error('Conteúdo inválido.');n.content.forEach((c:any)=>check(c,depth+1));} };
  if(root?.type!=='doc')throw new Error('Comentário JSON precisa ter type doc.');check(root,0);return root;
}
const find=(items:Taxon[],name:string)=>items.find(x=>normalize(x.name)===normalize(name));
const similarity=(a:string,b:string)=>{const aa=new Set(normalize(a).split(/\W+/).filter(x=>x.length>2));const bb=new Set(normalize(b).split(/\W+/).filter(x=>x.length>2));return aa.size && bb.size ? [...aa].filter(x=>bb.has(x)).length / new Set([...aa,...bb]).size : 0;};
export function validateRows(rows:SheetRow[],taxonomy:Taxonomy,existing:Existing[],mode:'create'|'update'):PreviewRow[] {
 const codes=new Map(existing.map(c=>[c.code,c]));const seenCodes=new Set<string>();const seen:SheetRow[]=[];
 return rows.map(row=>{const r:PreviewRow={...row,issues:[...row.issues],operation:row.cells.codigo?'update':'create',warnings:[],proposed:[],expected:null,comment:null};const c=r.cells;const error=(column:string,message:string)=>r.issues.push({column,message});
 for(const key of ['secao','area','tema','pergunta','resposta','comentario'] as const)if(!c[key]||c[key]==='[LIMPAR]')error(key,'Campo obrigatório.');
 for(const key of ['area','tema','subtema'] as const)if(c[key].length>160)error(key,'Nome excede 160 caracteres.');
 for(const key of ['secao','tags'] as const)if(names(c[key]).some(n=>n.length>160))error(key,'Nome excede 160 caracteres.');
 if(c.dificuldade&&!['easy','medium','hard'].includes(c.dificuldade))error('dificuldade','Use easy, medium ou hard.');
 if(c.status&&!['draft','published','archived'].includes(c.status))error('status','Status inválido.');
 if(c.status==='archived'&&!c.codigo)error('status','Novos cards não podem iniciar arquivados.');
 const old=codes.get(c.codigo);if(c.codigo){if(!old)error('codigo','Código editorial não encontrado.');else {r.expected=old.updated_at;if(mode==='create'){r.operation='skip';r.warnings.push('Código existente: ignorado no modo somente criação.');}}if(seenCodes.has(c.codigo))error('codigo','Código repetido neste arquivo.');seenCodes.add(c.codigo);}
 for(const section of names(c.secao)){const s=find(taxonomy.sections,section);if(!s||!s.is_active)error('secao',`Seção desconhecida ou inativa: ${section}.`);}
 const area=find(taxonomy.areas,c.area);if(area&&!area.is_active)error('area','Área inativa.');else if(!area&&c.area)r.proposed.push(`Área: ${c.area}`);
 const topic=find(taxonomy.topics.filter(x=>x.area_id===area?.id),c.tema);if(topic&&!topic.is_active)error('tema','Tema inativo.');else if(!topic&&c.tema)r.proposed.push(`Tema: ${c.area} → ${c.tema}`);
 if(c.subtema&&c.subtema!=='[LIMPAR]'){const sub=find(taxonomy.subtopics.filter(x=>x.topic_id===topic?.id),c.subtema);if(sub&&!sub.is_active)error('subtema','Subtema inativo.');else if(!sub)r.proposed.push(`Subtema: ${c.area} → ${c.tema} → ${c.subtema}`);}
 if(old&&!c.subtema&&old.subtopic_id&&old.topic_id!==topic?.id)error('subtema','Mudança de tema exige subtema compatível ou [LIMPAR].');
 for(const tag of names(c.tags==='[LIMPAR]'?'':c.tags)){const t=find(taxonomy.tags,tag);if(t&&!t.is_active)error('tags',`Tag inativa: ${tag}.`);else if(!t)r.proposed.push(`Tag: ${tag}`);}
 try{r.comment=safeComment(c.comentario);}catch(e){error('comentario',e instanceof Error?e.message:'Comentário inválido.');}
 const exact=[...existing.filter(x=>x.code!==c.codigo).map(x=>({question:x.question,label:x.code})),...seen.map(x=>({question:x.cells.pergunta,label:`linha ${x.line}`}))];
 const match=exact.find(x=>normalize(x.question)===normalize(c.pergunta));if(match)r.warnings.push(`Pergunta idêntica a ${match.label}. Decida importar ou ignorar.`);else {const similar=exact.find(x=>similarity(x.question,c.pergunta)>=0.8);if(similar)r.warnings.push(`Pergunta semelhante a ${similar.label}. Decida importar ou ignorar.`);}
 if(old){const diff:Record<string,boolean>={pergunta:c.pergunta!==old.question,resposta:c.resposta!==old.short_answer,comentario:JSON.stringify(r.comment)!==JSON.stringify(old.comment),tema:topic?.id!==old.topic_id,subtema:!!c.subtema&&(c.subtema==='[LIMPAR]'?old.subtopic_id!==null:find(taxonomy.subtopics.filter(x=>x.topic_id===topic?.id),c.subtema)?.id!==old.subtopic_id),referencia:!!c.referencia&&(c.referencia==='[LIMPAR]'?'':c.referencia)!==old.reference,dificuldade:!!c.dificuldade&&c.dificuldade!==old.editorial_difficulty,status:!!c.status&&c.status!==old.status,secoes:JSON.stringify(names(c.secao).map(n=>find(taxonomy.sections,n)?.id).sort())!==JSON.stringify((old.sectionIds??[]).slice().sort()),tags:!!c.tags&&JSON.stringify(names(c.tags==='[LIMPAR]'?'':c.tags).map(n=>find(taxonomy.tags,n)?.id).sort())!==JSON.stringify((old.tagIds??[]).slice().sort())};r.changed=Object.keys(diff).filter(k=>diff[k]);if(!r.changed.length&&r.operation!=='skip'){r.operation='skip';r.warnings.push('Sem alterações reais.');}}
 seen.push(row);return r;
 });
}
