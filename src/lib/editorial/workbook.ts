import { unzipSync, zipSync, strFromU8, strToU8 } from 'fflate';
import { XMLParser } from 'fast-xml-parser';

export const COLUMNS = ['codigo','secao','area','tema','subtema','pergunta','resposta','comentario','referencia','dificuldade','tags','status'] as const;
export type Column = typeof COLUMNS[number];
export const MAX_BYTES = 20 * 1024 * 1024;
export const MAX_ROWS = 5000;
export type SheetRow = { line: number; cells: Record<Column, string>; issues: {column: string; message: string}[] };
const list = <T>(value: T | T[] | undefined): T[] => value === undefined ? [] : Array.isArray(value) ? value : [value];
const xml = new XMLParser({ignoreAttributes:false, attributeNamePrefix:'@_', parseTagValue:false, trimValues:false, processEntities:true});
const escape = (s: string) => s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g,'');
export const columnLetter = (n: number): string => n < 26 ? String.fromCharCode(65+n) : columnLetter(Math.floor(n/26)-1)+String.fromCharCode(65+n%26);
function text(value: any): string { if (value === undefined) return ''; if (typeof value !== 'object') return String(value); if (value.t !== undefined) return typeof value.t === 'object' ? String(value.t['#text'] ?? '') : String(value.t); return list(value.r).map(text).join(''); }
export function readWorkbook(bytes: Uint8Array, filename: string): SheetRow[] {
  if (!/\.xlsx$/i.test(filename)) throw new Error('Envie um arquivo .xlsx.');
  if (bytes.length > MAX_BYTES || bytes.length < 4 || bytes[0] !== 80 || bytes[1] !== 75) throw new Error('Arquivo inválido ou maior que 20 MB.');
  let expanded = 0; let count = 0;
  const files = unzipSync(bytes, {filter: entry => { expanded += entry.originalSize; count++; if (expanded > 80*1024*1024 || count>500 || entry.originalSize>40*1024*1024) throw new Error('Planilha excede o limite descompactado.'); return true; }});
  const parse = (path: string) => {const b = files[path]; if (!b) throw new Error(`Estrutura XLSX inválida: ${path}.`); const s = strFromU8(b); if (/<!DOCTYPE|<!ENTITY/i.test(s)) throw new Error('Declarações XML não permitidas.'); return xml.parse(s);};
  const workbook = parse('xl/workbook.xml');
  const sheets = list<any>(workbook.workbook?.sheets?.sheet);
  const sheet = sheets.find(s=>s['@_name']==='Cards');
  if (!sheet) throw new Error('A aba Cards não foi encontrada.');
  const rels = list<any>(parse('xl/_rels/workbook.xml.rels').Relationships?.Relationship);
  const rel = rels.find(r=>r['@_Id']===sheet['@_r:id']);
  if (!rel || rel['@_TargetMode']==='External') throw new Error('Aba Cards inválida.');
  const target = String(rel['@_Target']).replace(/^\//,'');
  const path = target.startsWith('xl/') ? target : 'xl/'+target;
  if (path.includes('..')) throw new Error('Caminho de aba inválido.');
  const shared = files['xl/sharedStrings.xml'] ? list<any>(parse('xl/sharedStrings.xml').sst?.si).map(text) : [];
  const rows = list<any>(parse(path).worksheet?.sheetData?.row);
  if (rows.length>MAX_ROWS+1) throw new Error('Limite de 5.000 linhas por arquivo.');
  const cellText = (c: any) => c['@_t']==='s' ? shared[Number(c.v)] ?? '' : c['@_t']==='inlineStr' ? text(c.is) : String(c.v ?? '');
  const header = rows.find(r=>Number(r['@_r'])===1);
  if (!header) throw new Error('Cabeçalhos obrigatórios na linha 1.');
  const mapping = new Map<string, Column>(); const names = new Set<string>();
  for (const c of list<any>(header.c)) { const name = cellText(c).trim().toLowerCase(); if (!COLUMNS.includes(name as Column) || names.has(name) || c.f!==undefined) throw new Error('Cabeçalhos inválidos, duplicados ou com fórmulas.'); names.add(name); mapping.set(String(c['@_r']).replace(/\d/g,''), name as Column); }
  if (COLUMNS.some(c=>!names.has(c))) throw new Error('A planilha deve conter as 12 colunas do modelo oficial.');
  const result: SheetRow[] = [];
  for (const row of rows) {
    if (list<any>(row.c).length>24) throw new Error('Número excessivo de células na linha.');
    const line = Number(row['@_r']); if (line===1) continue;
    if (!Number.isInteger(line) || line<2 || line>MAX_ROWS+1 || result.some(r=>r.line===line)) throw new Error('Numeração de linhas inválida ou limite excedido.');
    const cells = Object.fromEntries(COLUMNS.map(c=>[c,''])) as Record<Column,string>; const issues: SheetRow['issues']=[];
    for (const c of list<any>(row.c)) { const column = mapping.get(String(c['@_r']).replace(/\d/g,'')); const value = cellText(c); if (!column) {if (value || c.f!==undefined) issues.push({column:'estrutura',message:'Conteúdo fora das colunas oficiais.'}); continue;} if (c.f!==undefined) issues.push({column,message:'Fórmulas não são permitidas; use texto ou valores.'}); if (c['@_t'] && !['s','inlineStr','str'].includes(c['@_t']) || (!c['@_t'] && value)) issues.push({column,message:'Use células de texto, sem números, datas ou valores booleanos.'}); if (value.length>32767) issues.push({column,message:'Texto excede 32.767 caracteres.'}); cells[column] = value.trim(); }
    if (Object.values(cells).some(Boolean) || issues.length) result.push({line,cells,issues});
  }
  if (!result.length) throw new Error('A aba Cards está vazia.');
  return result;
}
export function writeWorkbook(rows: Record<string,string>[], instructions = true): Uint8Array {
  const sheet = (data: string[][]) => '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" state="frozen"/></sheetView></sheetViews><cols><col min="1" max="5" width="24" customWidth="1"/><col min="6" max="9" width="65" customWidth="1"/><col min="10" max="12" width="24" customWidth="1"/></cols><sheetData>'+data.map((row,i)=>`<row r="${i+1}">${row.map((v,j)=>`<c r="${columnLetter(j)}${i+1}" t="inlineStr" s="${i===0?1:0}"><is><t xml:space="preserve">${escape(v)}</t></is></c>`).join('')}</row>`).join('')+'</sheetData></worksheet>';
  const notes = [
    ['CLINICAVERSO — Modelo editorial XLSX'], ['Importe somente a aba Cards. Exemplos são fictícios; remova-os antes de importar conteúdo real.'],
    ['codigo vazio = novo card; código conhecido = atualização apenas no modo Criar e atualizar.'],
    ['secao, area, tema, pergunta, resposta e comentario obrigatórios. Seções e tags: separador ;.'],
    ['Novo card: status vazio = draft, dificuldade vazia = medium. Dificuldade: easy, medium, hard. Status: draft, published (archived somente em exportação/reimportação).'],
    ['Atualização: opcionais vazios preservam dados. [LIMPAR] limpa subtema, referencia ou tags.'],
    ['Comentario: texto simples ou JSON TipTap seguro. Exportação usa JSON, preservando formatação compatível.'],
    ['JSON aceita doc, paragraph, heading, text, listas, tabelas, imagens https e marcas básicas. HTML, scripts e fórmulas são recusados.'],
    ['Arquivos de mídia privados não são incluídos na planilha. Mídia vinculada a cards existentes permanece intacta.'],
    ['Texto sempre exportado como texto literal, nunca fórmula. Limites: 20 MB, 5.000 linhas, 32.767 caracteres por célula, 160 por nome taxonômico.'],
    ['Envio e validação não gravam dados. Duplicatas exigem decisão editorial. Confirme somente após conferir a prévia.'],
  ];
  const files: Record<string,Uint8Array> = {};
  const add=(p:string,s:string)=>{files[p]=strToU8(s);}; const n=instructions?2:1;
  add('[Content_Types].xml',`<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${Array.from({length:n},(_,i)=>`<Override PartName="/xl/worksheets/sheet${i+1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join('')}</Types>`);
  add('_rels/.rels','<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
  add('xl/workbook.xml',`<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Cards" sheetId="1" r:id="rId1"/>${instructions?'<sheet name="Instruções" sheetId="2" r:id="rId2"/>':''}</sheets></workbook>`);
  add('xl/_rels/workbook.xml.rels',`<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${Array.from({length:n},(_,i)=>`<Relationship Id="rId${i+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i+1}.xml"/>`).join('')}<Relationship Id="styles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`);
  add('xl/styles.xml','<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Arial"/></font><font><b/><sz val="11"/><name val="Arial"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="49" fontId="1" fillId="0" borderId="0" xfId="0"><alignment vertical="top" wrapText="1"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>');
  add('xl/worksheets/sheet1.xml',sheet([Array.from(COLUMNS),...rows.map(r=>COLUMNS.map(c=>r[c]??''))]));
  if (instructions) add('xl/worksheets/sheet2.xml',sheet(notes));
  return zipSync(files,{level:6});
}
export const modelRows = () => [
  {secao:'R1CM',area:'Cardiologia',tema:'Exemplo — Dor torácica',pergunta:'Exemplo fictício: qual exame inicial na suspeita de síndrome coronariana?',resposta:'Eletrocardiograma de 12 derivações.',comentario:'Exemplo didático fictício, não destinado à prática clínica.'},
  {secao:'R1CM',area:'Endocrinologia',tema:'Exemplo — Diabetes',pergunta:'Exemplo fictício: qual exame estima a glicemia média?',resposta:'Hemoglobina glicada.',comentario:'Exemplo didático fictício.'},
  {secao:'R1CM',area:'Gastroenterologia',tema:'Exemplo — Hepatologia',pergunta:'Exemplo fictício: qual órgão é acometido na cirrose?',resposta:'Fígado.',comentario:'Exemplo didático fictício.'},
];
