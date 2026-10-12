CREATE OR REPLACE FUNCTION private.record_media_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE card public.flashcards%ROWTYPE;
BEGIN
 IF TG_OP='INSERT' AND current_setting('clinicaverso.initial_media_card',true)=NEW.flashcard_id::text THEN
  SELECT * INTO card FROM public.flashcards WHERE id=NEW.flashcard_id;
  IF card.version<>1 OR card.created_at<>transaction_timestamp() THEN RAISE EXCEPTION 'Invalid initial media context'; END IF;
  INSERT INTO public.flashcard_media_versions(flashcard_id,card_version,media_id,type,placement,storage_path,caption,alt_text,display_order,is_active) VALUES(NEW.flashcard_id,1,NEW.id,NEW.type,NEW.placement,NEW.storage_path,NEW.caption,NEW.alt_text,NEW.display_order,NEW.is_active);
 ELSE
  UPDATE public.flashcards SET version=version+1,updated_by=coalesce(auth.uid(),updated_by),updated_at=now() WHERE id=NEW.flashcard_id RETURNING * INTO card;
 END IF;
 INSERT INTO public.editorial_audit_log(actor_id,entity_type,entity_id,action,old_data,new_data) VALUES(auth.uid(),'flashcard_media',NEW.id,CASE WHEN TG_OP='INSERT' THEN 'create' ELSE 'update' END,CASE WHEN TG_OP='UPDATE' THEN to_jsonb(OLD) END,to_jsonb(NEW));
 RETURN NEW;
END; $$;
CREATE OR REPLACE FUNCTION public.duplicate_editorial_card(p_source uuid,p_new_id uuid,p_expected timestamptz,p_media jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE original public.flashcards%ROWTYPE; card public.flashcards%ROWTYPE; item jsonb; m public.flashcard_media%ROWTYPE;
BEGIN
 IF NOT private.can_manage_content(auth.uid()) THEN RAISE EXCEPTION 'Sem permissão'; END IF;
 SELECT * INTO original FROM public.flashcards WHERE id=p_source FOR UPDATE;
 IF NOT FOUND OR original.updated_at IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'Card alterado durante a duplicação. Tente novamente.'; END IF;
 IF jsonb_typeof(p_media)<>'array' OR jsonb_array_length(p_media)<>(SELECT count(*) FROM public.flashcard_media WHERE flashcard_id=p_source AND is_active) THEN RAISE EXCEPTION 'Mídia incompleta'; END IF;
 INSERT INTO public.flashcards(id,topic_id,subtopic_id,question,short_answer,comment,reference,editorial_difficulty,status,created_by,updated_by) VALUES(p_new_id,original.topic_id,original.subtopic_id,original.question,original.short_answer,original.comment,original.reference,original.editorial_difficulty,'draft',auth.uid(),auth.uid()) RETURNING * INTO card;
 INSERT INTO public.flashcard_sections(flashcard_id,section_id) SELECT card.id,section_id FROM public.flashcard_sections WHERE flashcard_id=p_source;
 INSERT INTO public.flashcard_tags(flashcard_id,tag_id) SELECT card.id,tag_id FROM public.flashcard_tags WHERE flashcard_id=p_source;
 PERFORM set_config('clinicaverso.initial_media_card',card.id::text,true);
 FOR item IN SELECT value FROM jsonb_array_elements(p_media) LOOP
  SELECT * INTO m FROM public.flashcard_media WHERE id=(item->>'source_id')::uuid AND flashcard_id=p_source AND is_active;
  IF NOT FOUND OR (item->>'path') NOT LIKE card.id::text||'/%' THEN RAISE EXCEPTION 'Mídia inválida'; END IF;
  INSERT INTO public.flashcard_media(flashcard_id,type,placement,storage_path,caption,alt_text,display_order,is_active,created_by) VALUES(card.id,m.type,m.placement,item->>'path',m.caption,m.alt_text,m.display_order,true,auth.uid());
 END LOOP;
 PERFORM set_config('clinicaverso.initial_media_card','',true);
 RETURN jsonb_build_object('id',card.id,'code',card.code,'version',1);
END; $$;
REVOKE ALL ON FUNCTION public.duplicate_editorial_card(uuid,uuid,timestamptz,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.duplicate_editorial_card(uuid,uuid,timestamptz,jsonb) TO authenticated;