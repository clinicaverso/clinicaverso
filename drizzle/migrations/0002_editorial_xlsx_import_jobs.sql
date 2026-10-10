CREATE TABLE public.editorial_imports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, filename text NOT NULL CHECK(length(filename)<=255), fingerprint text NOT NULL CHECK(length(fingerprint)=64), mode text NOT NULL CHECK(mode IN ('create','update')), status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','running','completed','partial')), total_rows integer NOT NULL CHECK(total_rows BETWEEN 1 AND 5000), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(user_id,fingerprint,mode)
);
GRANT SELECT,INSERT,UPDATE ON public.editorial_imports TO authenticated;
GRANT ALL ON public.editorial_imports TO service_role;
ALTER TABLE public.editorial_imports ENABLE ROW LEVEL SECURITY;
CREATE POLICY imports_read ON public.editorial_imports FOR SELECT TO authenticated USING(private.can_manage_content(auth.uid()));
CREATE POLICY imports_insert ON public.editorial_imports FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid() AND private.can_manage_content(auth.uid()));
CREATE POLICY imports_update ON public.editorial_imports FOR UPDATE TO authenticated USING(user_id=auth.uid() AND private.can_manage_content(auth.uid())) WITH CHECK(user_id=auth.uid() AND private.can_manage_content(auth.uid()));
CREATE TABLE public.editorial_import_rows (
 import_id uuid NOT NULL REFERENCES public.editorial_imports(id) ON DELETE RESTRICT, line integer NOT NULL CHECK(line BETWEEN 2 AND 5001), payload jsonb NOT NULL, operation text NOT NULL CHECK(operation IN ('create','update','skip')), status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','created','updated','skipped','error')), flashcard_id uuid REFERENCES public.flashcards(id) ON DELETE RESTRICT, code text, message text NOT NULL DEFAULT '', updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(import_id,line)
);
GRANT SELECT,INSERT,UPDATE ON public.editorial_import_rows TO authenticated;
GRANT ALL ON public.editorial_import_rows TO service_role;
ALTER TABLE public.editorial_import_rows ENABLE ROW LEVEL SECURITY;
CREATE POLICY import_rows_read ON public.editorial_import_rows FOR SELECT TO authenticated USING(private.can_manage_content(auth.uid()));
CREATE POLICY import_rows_insert ON public.editorial_import_rows FOR INSERT TO authenticated WITH CHECK(private.can_manage_content(auth.uid()) AND EXISTS(SELECT 1 FROM public.editorial_imports i WHERE i.id=import_id AND i.user_id=auth.uid()));
CREATE POLICY import_rows_update ON public.editorial_import_rows FOR UPDATE TO authenticated USING(private.can_manage_content(auth.uid()) AND EXISTS(SELECT 1 FROM public.editorial_imports i WHERE i.id=import_id AND i.user_id=auth.uid())) WITH CHECK(private.can_manage_content(auth.uid()) AND EXISTS(SELECT 1 FROM public.editorial_imports i WHERE i.id=import_id AND i.user_id=auth.uid()));
CREATE INDEX editorial_imports_date_idx ON public.editorial_imports(created_at DESC);
CREATE INDEX editorial_import_rows_pending_idx ON public.editorial_import_rows(import_id,line) WHERE status='pending';
CREATE OR REPLACE FUNCTION public.editorial_normalize(value text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$ SELECT lower(regexp_replace(trim(value),'\s+',' ','g')); $$;
REVOKE ALL ON FUNCTION public.editorial_normalize(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.editorial_normalize(text) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.editorial_resolve_taxon(kind text, label text, parent uuid DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE result uuid; active boolean; base text; slug_value text;
BEGIN
 IF NOT private.can_manage_content(auth.uid()) THEN RAISE EXCEPTION 'Sem permissão'; END IF;
 IF kind NOT IN ('areas','topics','subtopics','tags') OR length(trim(label))=0 OR length(label)>160 THEN RAISE EXCEPTION 'Taxonomia inválida'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(kind||coalesce(parent::text,'')||public.editorial_normalize(label),0));
 IF kind='areas' THEN SELECT id,is_active INTO result,active FROM public.areas WHERE public.editorial_normalize(name)=public.editorial_normalize(label) LIMIT 1;
 ELSIF kind='topics' THEN SELECT id,is_active INTO result,active FROM public.topics WHERE area_id=parent AND public.editorial_normalize(name)=public.editorial_normalize(label) LIMIT 1;
 ELSIF kind='subtopics' THEN SELECT id,is_active INTO result,active FROM public.subtopics WHERE topic_id=parent AND public.editorial_normalize(name)=public.editorial_normalize(label) LIMIT 1;
 ELSE SELECT id,is_active INTO result,active FROM public.tags WHERE public.editorial_normalize(name)=public.editorial_normalize(label) LIMIT 1; END IF;
 IF result IS NOT NULL THEN IF NOT active THEN RAISE EXCEPTION 'Taxonomia inativa: %',label; END IF; RETURN result; END IF;
 base:=trim(both '-' FROM regexp_replace(lower(translate(label,'áàãâäéèêëíìîïóòõôöúùûüç','aaaaaeeeeiiiiooooouuuuc')),'[^a-z0-9]+','-','g'));
 IF base='' THEN base:='item'; END IF;
 slug_value:=base||'-'||substr(md5(public.editorial_normalize(label)),1,10);
 IF kind='areas' THEN INSERT INTO public.areas(name,slug) VALUES(trim(label),slug_value) RETURNING id INTO result;
 ELSIF kind='topics' THEN INSERT INTO public.topics(name,slug,area_id) VALUES(trim(label),slug_value,parent) RETURNING id INTO result;
 ELSIF kind='subtopics' THEN INSERT INTO public.subtopics(name,slug,topic_id) VALUES(trim(label),slug_value,parent) RETURNING id INTO result;
 ELSE INSERT INTO public.tags(name,slug) VALUES(trim(label),slug_value) RETURNING id INTO result; END IF;
 RETURN result;
END; $$;
REVOKE ALL ON FUNCTION public.editorial_resolve_taxon(text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.editorial_resolve_taxon(text,text,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.confirm_editorial_import(p_filename text,p_fingerprint text,p_mode text,p_rows jsonb) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE job uuid; r jsonb;
BEGIN
 IF NOT private.can_manage_content(auth.uid()) THEN RAISE EXCEPTION 'Sem permissão'; END IF;
 IF jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows) NOT BETWEEN 1 AND 5000 THEN RAISE EXCEPTION 'Número de linhas inválido'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_fingerprint||p_mode,0));
 SELECT id INTO job FROM public.editorial_imports WHERE user_id=auth.uid() AND fingerprint=p_fingerprint AND mode=p_mode;
 IF job IS NOT NULL THEN RETURN job; END IF;
 INSERT INTO public.editorial_imports(user_id,filename,fingerprint,mode,total_rows) VALUES(auth.uid(),p_filename,p_fingerprint,p_mode,jsonb_array_length(p_rows)) RETURNING id INTO job;
 FOR r IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
 INSERT INTO public.editorial_import_rows(import_id,line,payload,operation,status,message) VALUES(job,(r->>'line')::integer,r,r->>'operation',CASE WHEN coalesce(r->>'decision','') IN ('error','skip') OR r->>'operation'='skip' THEN CASE WHEN r->>'decision'='error' THEN 'error' ELSE 'skipped' END ELSE 'pending' END,coalesce(r->>'reason',''));
 END LOOP;
 RETURN job;
END; $$;
REVOKE ALL ON FUNCTION public.confirm_editorial_import(text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.confirm_editorial_import(text,text,text,jsonb) TO authenticated;
CREATE OR REPLACE FUNCTION public.process_editorial_import(p_import_id uuid,p_limit integer DEFAULT 20) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE job public.editorial_imports%ROWTYPE; r public.editorial_import_rows%ROWTYPE; c jsonb; old public.flashcards%ROWTYPE; card uuid; card_code text; area uuid; topic uuid; subtopic uuid; sections uuid[]; tags uuid[]; v uuid; label text; answer text; reference_value text; difficulty text; state public.flashcard_status; doc jsonb; changed boolean; outcome text; counters jsonb;
BEGIN
 IF NOT private.can_manage_content(auth.uid()) THEN RAISE EXCEPTION 'Sem permissão'; END IF;
 SELECT * INTO job FROM public.editorial_imports WHERE id=p_import_id AND user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Importação não encontrada ou sem acesso'; END IF;
 UPDATE public.editorial_imports SET status='running',updated_at=now() WHERE id=job.id;
 FOR r IN SELECT * FROM public.editorial_import_rows WHERE import_id=job.id AND status='pending' ORDER BY line LIMIT greatest(1,least(p_limit,25)) FOR UPDATE LOOP
 BEGIN
  c:=r.payload->'cells'; card:=NULL; old:=NULL; sections:='{}'; tags:='{}';
  IF r.operation='update' THEN
   IF job.mode<>'update' THEN RAISE EXCEPTION 'Atualização não autorizada neste modo'; END IF;
   SELECT * INTO old FROM public.flashcards WHERE code=c->>'codigo' FOR UPDATE;
   IF NOT FOUND THEN RAISE EXCEPTION 'Código não encontrado'; END IF;
   IF old.updated_at::text IS DISTINCT FROM (r.payload->>'expected')::timestamptz::text THEN RAISE EXCEPTION 'Card alterado após a prévia; valide novamente'; END IF;
   card:=old.id;
  ELSIF r.operation<>'create' OR coalesce(c->>'codigo','')<>'' THEN RAISE EXCEPTION 'Operação inválida'; END IF;
  FOREACH label IN ARRAY string_to_array(c->>'secao',';') LOOP
   SELECT id INTO v FROM public.sections WHERE is_active AND public.editorial_normalize(name)=public.editorial_normalize(label) LIMIT 1;
   IF v IS NULL THEN RAISE EXCEPTION 'Seção desconhecida ou inativa: %',label; END IF;
   IF NOT v=ANY(sections) THEN sections:=array_append(sections,v); END IF;
  END LOOP;
  IF cardinality(sections)=0 THEN RAISE EXCEPTION 'Selecione pelo menos uma seção'; END IF;
  area:=public.editorial_resolve_taxon('areas',c->>'area'); topic:=public.editorial_resolve_taxon('topics',c->>'tema',area);
  IF coalesce(c->>'subtema','')='' THEN subtopic:=old.subtopic_id;
  ELSIF c->>'subtema'='[LIMPAR]' THEN subtopic:=NULL;
  ELSE subtopic:=public.editorial_resolve_taxon('subtopics',c->>'subtema',topic); END IF;
  IF coalesce(c->>'tags','')='' AND card IS NOT NULL THEN SELECT coalesce(array_agg(tag_id),'{}') INTO tags FROM public.flashcard_tags WHERE flashcard_id=card;
  ELSIF coalesce(c->>'tags','') NOT IN ('','[LIMPAR]') THEN
   FOREACH label IN ARRAY string_to_array(c->>'tags',';') LOOP
    IF trim(label)<>'' THEN v:=public.editorial_resolve_taxon('tags',label); IF NOT v=ANY(tags) THEN tags:=array_append(tags,v); END IF; END IF;
   END LOOP;
  END IF;
  answer:=c->>'resposta'; doc:=r.payload->'comment';
  IF length(trim(coalesce(c->>'pergunta','')))=0 OR length(trim(coalesce(answer,'')))=0 OR jsonb_typeof(doc)<>'object' OR doc->>'type'<>'doc' THEN RAISE EXCEPTION 'Conteúdo obrigatório inválido'; END IF;
  reference_value:=CASE WHEN coalesce(c->>'referencia','')='' THEN coalesce(old.reference,'') WHEN c->>'referencia'='[LIMPAR]' THEN '' ELSE c->>'referencia' END;
  difficulty:=coalesce(nullif(c->>'dificuldade',''),old.editorial_difficulty,'medium');
  state:=coalesce(nullif(c->>'status',''),old.status::text,'draft')::public.flashcard_status;
  IF card IS NULL THEN
   INSERT INTO public.flashcards(topic_id,subtopic_id,question,short_answer,comment,reference,editorial_difficulty,status,created_by,updated_by) VALUES(topic,subtopic,c->>'pergunta',answer,doc,reference_value,difficulty,state,auth.uid(),auth.uid()) RETURNING id,code INTO card,card_code;
   outcome:='created';
  ELSE
   changed:=ROW(old.topic_id,old.subtopic_id,old.question,old.short_answer,old.comment,old.reference,old.editorial_difficulty,old.status) IS DISTINCT FROM ROW(topic,subtopic,c->>'pergunta',answer,doc,reference_value,difficulty,state);
   IF changed THEN UPDATE public.flashcards SET topic_id=topic,subtopic_id=subtopic,question=c->>'pergunta',short_answer=answer,comment=doc,reference=reference_value,editorial_difficulty=difficulty,status=state,updated_by=auth.uid() WHERE id=card; END IF;
   IF NOT changed THEN changed:= EXISTS(SELECT 1 FROM public.flashcard_sections WHERE flashcard_id=card AND NOT section_id=ANY(sections)) OR EXISTS(SELECT 1 FROM unnest(sections) x WHERE NOT EXISTS(SELECT 1 FROM public.flashcard_sections s WHERE s.flashcard_id=card AND s.section_id=x)) OR EXISTS(SELECT 1 FROM public.flashcard_tags WHERE flashcard_id=card AND NOT tag_id=ANY(tags)) OR EXISTS(SELECT 1 FROM unnest(tags) x WHERE NOT EXISTS(SELECT 1 FROM public.flashcard_tags t WHERE t.flashcard_id=card AND t.tag_id=x)); END IF;
   outcome:=CASE WHEN changed THEN 'updated' ELSE 'skipped' END; card_code:=old.code;
  END IF;
  DELETE FROM public.flashcard_sections WHERE flashcard_id=card AND NOT section_id=ANY(sections);
  INSERT INTO public.flashcard_sections(flashcard_id,section_id) SELECT card,x FROM unnest(sections) x WHERE NOT EXISTS(SELECT 1 FROM public.flashcard_sections s WHERE s.flashcard_id=card AND s.section_id=x);
  DELETE FROM public.flashcard_tags WHERE flashcard_id=card AND NOT tag_id=ANY(tags);
  INSERT INTO public.flashcard_tags(flashcard_id,tag_id) SELECT card,x FROM unnest(tags) x WHERE NOT EXISTS(SELECT 1 FROM public.flashcard_tags t WHERE t.flashcard_id=card AND t.tag_id=x);
  UPDATE public.editorial_import_rows SET status=outcome,flashcard_id=card,code=card_code,message=CASE WHEN outcome='skipped' THEN 'Sem alterações reais' ELSE '' END,updated_at=now() WHERE import_id=r.import_id AND line=r.line;
 EXCEPTION WHEN OTHERS THEN
  UPDATE public.editorial_import_rows SET status='error',message=left(SQLERRM,500),updated_at=now() WHERE import_id=r.import_id AND line=r.line;
 END;
 END LOOP;
 SELECT jsonb_object_agg(status,n) INTO counters FROM (SELECT status,count(*) n FROM public.editorial_import_rows WHERE import_id=job.id GROUP BY status) s;
 UPDATE public.editorial_imports SET status=CASE WHEN EXISTS(SELECT 1 FROM public.editorial_import_rows WHERE import_id=job.id AND status='pending') THEN 'running' WHEN EXISTS(SELECT 1 FROM public.editorial_import_rows WHERE import_id=job.id AND status='error') THEN 'partial' ELSE 'completed' END,updated_at=now() WHERE id=job.id;
 RETURN counters;
END; $$;
REVOKE ALL ON FUNCTION public.process_editorial_import(uuid,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.process_editorial_import(uuid,integer) TO authenticated;