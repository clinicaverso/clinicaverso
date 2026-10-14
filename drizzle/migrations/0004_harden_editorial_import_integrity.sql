CREATE OR REPLACE FUNCTION private.validate_editorial_import_payload() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE c jsonb; k text;
BEGIN
 IF NEW.status <> 'pending' THEN RETURN NEW; END IF;
 c:=NEW.payload->'cells';
 IF jsonb_typeof(c) IS DISTINCT FROM 'object' OR NEW.payload->>'decision' IS DISTINCT FROM 'import' OR NEW.operation NOT IN ('create','update') THEN RAISE EXCEPTION 'Payload de importação inválido'; END IF;
 FOREACH k IN ARRAY ARRAY['codigo','secao','area','tema','subtema','pergunta','resposta','comentario','referencia','dificuldade','tags','status'] LOOP
  IF jsonb_typeof(c->k) IS DISTINCT FROM 'string' OR length(c->>k)>32767 THEN RAISE EXCEPTION 'Célula inválida: %',k; END IF;
 END LOOP;
 FOREACH k IN ARRAY ARRAY['secao','area','tema','pergunta','resposta','comentario'] LOOP
  IF btrim(c->>k) IN ('','[LIMPAR]') THEN RAISE EXCEPTION 'Campo obrigatório: %',k; END IF;
 END LOOP;
 IF jsonb_typeof(NEW.payload->'comment') IS DISTINCT FROM 'object' OR NEW.payload->'comment'->>'type' IS DISTINCT FROM 'doc' THEN RAISE EXCEPTION 'Comentário obrigatório inválido'; END IF;
 IF c->>'dificuldade' NOT IN ('','easy','medium','hard') OR c->>'status' NOT IN ('','draft','published','archived') THEN RAISE EXCEPTION 'Valor editorial inválido'; END IF;
 IF NEW.operation='create' AND (c->>'codigo'<>'' OR c->>'status'='archived') THEN RAISE EXCEPTION 'Criação inválida'; END IF;
 IF NEW.operation='update' AND (c->>'codigo'='' OR nullif(NEW.payload->>'expected','') IS NULL) THEN RAISE EXCEPTION 'Atualização sem identidade ou prévia'; END IF;
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.validate_editorial_import_payload() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.validate_editorial_import_payload() TO authenticated;
CREATE TRIGGER validate_editorial_import_payload BEFORE INSERT OR UPDATE OF payload,operation,status ON public.editorial_import_rows FOR EACH ROW EXECUTE FUNCTION private.validate_editorial_import_payload();
DO $$
DECLARE definition text;
BEGIN
 SELECT pg_get_functiondef('public.process_editorial_import(uuid,integer)'::regprocedure) INTO definition;
 definition:=replace(definition,'old.updated_at::text IS DISTINCT FROM (r.payload->>''expected'')::timestamptz::text','old.updated_at IS DISTINCT FROM (r.payload->>''expected'')::timestamptz');
 definition:=replace(definition,'WHERE is_active AND public.editorial_normalize(name)=public.editorial_normalize(label)','WHERE (is_active OR (card IS NOT NULL AND EXISTS(SELECT 1 FROM public.flashcard_sections fs WHERE fs.flashcard_id=card AND fs.section_id=public.sections.id))) AND public.editorial_normalize(name)=public.editorial_normalize(label)');
 EXECUTE definition;
END; $$;