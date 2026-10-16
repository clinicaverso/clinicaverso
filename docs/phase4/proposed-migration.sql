-- PROPOSTA REVISADA — NÃO APLICADA.
-- Nenhuma coluna/constraint histórica é removida. Eventos sem agenda ficam separados
-- de review_events porque suas datas/intervalos atuais são obrigatórios.
ALTER TABLE public.user_flashcard_states ADD COLUMN scheduling_status text
  CHECK (scheduling_status IN ('unscheduled','scheduled'));
COMMENT ON COLUMN public.user_flashcard_states.scheduling_status IS
  'NULL: estado legado não classificado; unscheduled: aprendizagem real sem FSRS; scheduled: futuro motor ativado. Não reinterpretar retroativamente o histórico.';

CREATE TABLE public.study_sessions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL,
 section_id uuid NOT NULL REFERENCES public.sections(id),
 topic_id uuid NOT NULL REFERENCES public.topics(id),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.study_sessions TO authenticated;
GRANT ALL ON public.study_sessions TO service_role;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY study_session_owner ON public.study_sessions FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE INDEX study_sessions_owner_topic ON public.study_sessions(user_id,section_id,topic_id,created_at DESC);

CREATE TABLE public.learning_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL,
 flashcard_id uuid NOT NULL REFERENCES public.flashcards(id),
 session_id uuid NOT NULL REFERENCES public.study_sessions(id), operation_id uuid NOT NULL,
 rating public.review_rating NOT NULL, reviewed_at timestamptz NOT NULL DEFAULT now(),
 card_version_seen integer NOT NULL,
 learning_state_before public.learning_state NOT NULL,
 learning_state_after public.learning_state NOT NULL DEFAULT 'learning',
 event_kind text NOT NULL DEFAULT 'unscheduled_learning' CHECK(event_kind='unscheduled_learning'),
 UNIQUE(user_id,operation_id),
 FOREIGN KEY(flashcard_id,card_version_seen) REFERENCES public.flashcard_versions(flashcard_id,version)
);
GRANT SELECT ON public.learning_events TO authenticated;
GRANT ALL ON public.learning_events TO service_role;
ALTER TABLE public.learning_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY learning_events_owner ON public.learning_events FOR SELECT TO authenticated
 USING(user_id=auth.uid() OR private.has_role(auth.uid(),'admin'));
CREATE INDEX learning_events_owner_card ON public.learning_events(user_id,flashcard_id,reviewed_at DESC);
COMMENT ON TABLE public.learning_events IS 'Append-only real learning without artificial scheduling. Preserved alongside review_events for future FSRS initialization; never converted by rewriting history.';

CREATE TABLE public.study_session_items (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), session_id uuid NOT NULL REFERENCES public.study_sessions(id),
 flashcard_id uuid NOT NULL REFERENCES public.flashcards(id), position integer NOT NULL CHECK(position>0),
 version_seen integer, revealed boolean NOT NULL DEFAULT false,
 event_id uuid REFERENCES public.learning_events(id), skipped boolean NOT NULL DEFAULT false,
 UNIQUE(session_id,flashcard_id), UNIQUE(session_id,position),
 FOREIGN KEY(flashcard_id,version_seen) REFERENCES public.flashcard_versions(flashcard_id,version)
);
GRANT SELECT ON public.study_session_items TO authenticated;
GRANT ALL ON public.study_session_items TO service_role;
ALTER TABLE public.study_session_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY study_item_owner ON public.study_session_items FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.study_sessions s WHERE s.id=session_id AND s.user_id=auth.uid()));

-- Existing model: every authenticated user can read active sections. No course purchase,
-- subscription or enrollment entitlement exists; this does NOT introduce one implicitly.
-- Helpers never accept a supplied user ID and have no content-manager bypass.
CREATE FUNCTION private.study_section_allowed(p_section uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.sections WHERE id=p_section AND is_active)
$$;
CREATE FUNCTION private.study_eligible(p_card uuid,p_section uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT private.study_section_allowed(p_section) AND EXISTS(
 SELECT 1 FROM public.flashcards f
 JOIN public.flashcard_sections fs ON fs.flashcard_id=f.id AND fs.section_id=p_section
 JOIN public.topics t ON t.id=f.topic_id AND t.is_active
 JOIN public.areas a ON a.id=t.area_id AND a.is_active
 JOIN public.weekly_schedules ws ON ws.section_id=p_section AND ws.status='published'
 JOIN public.weekly_schedule_items wi ON wi.weekly_schedule_id=ws.id AND wi.topic_id=f.topic_id
 WHERE f.id=p_card AND f.status='published' AND wi.release_at<=now())
$$;
REVOKE ALL ON FUNCTION private.study_section_allowed(uuid),private.study_eligible(uuid,uuid) FROM PUBLIC,anon,authenticated;

-- Catalog returns only already-released metadata, consistent with existing schedule RLS.
-- Future topics are NOT exposed by this SECURITY DEFINER function.
CREATE FUNCTION public.study_catalog(p_section uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT private.study_section_allowed(p_section) THEN RAISE EXCEPTION 'Seção não autorizada'; END IF;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'release_at'),'[]'::jsonb) INTO result FROM (
 SELECT jsonb_build_object('id',t.id,'name',t.name,'area',a.name,'release_at',min(wi.release_at),
 'total',(SELECT count(*) FROM public.flashcards f WHERE f.topic_id=t.id AND private.study_eligible(f.id,p_section)),
 'studied',(SELECT count(*) FROM public.flashcards f JOIN public.user_flashcard_states st ON st.flashcard_id=f.id AND st.user_id=auth.uid() AND st.review_count>0 WHERE f.topic_id=t.id AND private.study_eligible(f.id,p_section))) x
 FROM public.weekly_schedules ws JOIN public.weekly_schedule_items wi ON wi.weekly_schedule_id=ws.id
 JOIN public.topics t ON t.id=wi.topic_id AND t.is_active JOIN public.areas a ON a.id=t.area_id AND a.is_active
 WHERE ws.section_id=p_section AND ws.status='published' AND wi.release_at<=now()
 GROUP BY t.id,t.name,a.name) q;
 RETURN result;
END $$;

CREATE FUNCTION public.start_study_session(p_section uuid,p_topic uuid) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE sid uuid; candidates uuid[];
BEGIN
 IF NOT private.study_section_allowed(p_section) THEN RAISE EXCEPTION 'Seção não autorizada'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_section::text||p_topic::text,0));
 SELECT s.id INTO sid FROM public.study_sessions s WHERE s.user_id=auth.uid() AND s.section_id=p_section AND s.topic_id=p_topic
 AND EXISTS(SELECT 1 FROM public.study_session_items i WHERE i.session_id=s.id AND i.event_id IS NULL AND NOT i.skipped AND private.study_eligible(i.flashcard_id,p_section)
 AND NOT EXISTS(SELECT 1 FROM public.user_flashcard_states st WHERE st.user_id=auth.uid() AND st.flashcard_id=i.flashcard_id AND st.review_count>0))
 ORDER BY s.created_at DESC LIMIT 1;
 IF sid IS NOT NULL THEN PERFORM public.read_study_session(sid,false); RETURN sid; END IF;
 SELECT array_agg(f.id ORDER BY f.code) INTO candidates FROM public.flashcards f WHERE f.topic_id=p_topic AND private.study_eligible(f.id,p_section)
 AND NOT EXISTS(SELECT 1 FROM public.user_flashcard_states st WHERE st.user_id=auth.uid() AND st.flashcard_id=f.id AND st.review_count>0);
 IF coalesce(cardinality(candidates),0)=0 THEN RAISE EXCEPTION 'Não há cards novos liberados neste tema'; END IF;
 INSERT INTO public.study_sessions(user_id,section_id,topic_id) VALUES(auth.uid(),p_section,p_topic) RETURNING id INTO sid;
 INSERT INTO public.study_session_items(session_id,flashcard_id,position) SELECT sid,c,ord FROM unnest(candidates) WITH ORDINALITY q(c,ord);
 RETURN sid;
END $$;

CREATE FUNCTION public.read_study_session(p_session uuid,p_reveal boolean DEFAULT false) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.study_sessions%ROWTYPE; i public.study_session_items%ROWTYPE; c public.flashcard_versions%ROWTYPE; total integer; done integer; excluded integer; media jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Não autorizado'; END IF;
 SELECT * INTO s FROM public.study_sessions WHERE id=p_session AND user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND OR NOT private.study_section_allowed(s.section_id) THEN RAISE EXCEPTION 'Sessão não autorizada'; END IF;
 UPDATE public.study_session_items x SET skipped=true WHERE session_id=s.id AND event_id IS NULL AND NOT skipped AND
 (NOT private.study_eligible(x.flashcard_id,s.section_id) OR EXISTS(SELECT 1 FROM public.user_flashcard_states st WHERE st.user_id=s.user_id AND st.flashcard_id=x.flashcard_id AND st.review_count>0));
 SELECT count(*),count(*) FILTER(WHERE event_id IS NOT NULL),count(*) FILTER(WHERE skipped) INTO total,done,excluded FROM public.study_session_items WHERE session_id=s.id;
 SELECT * INTO i FROM public.study_session_items WHERE session_id=s.id AND event_id IS NULL AND NOT skipped ORDER BY position LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('id',s.id,'total',total,'done',done,'excluded',excluded,'card',NULL); END IF;
 -- Share lock prevents editorial update between current-version selection and pinning.
 PERFORM 1 FROM public.flashcards WHERE id=i.flashcard_id FOR SHARE;
 IF NOT private.study_eligible(i.flashcard_id,s.section_id) THEN RAISE EXCEPTION 'Card não autorizado'; END IF;
 IF i.version_seen IS NULL THEN UPDATE public.study_session_items SET version_seen=(SELECT version FROM public.flashcards WHERE id=i.flashcard_id) WHERE id=i.id RETURNING * INTO i; END IF;
 IF p_reveal THEN UPDATE public.study_session_items SET revealed=true WHERE id=i.id RETURNING * INTO i; END IF;
 SELECT * INTO c FROM public.flashcard_versions WHERE flashcard_id=i.flashcard_id AND version=i.version_seen;
 IF NOT FOUND THEN RAISE EXCEPTION 'Versão histórica ausente'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('type',m.type,'placement',m.placement,'storage_path',m.storage_path,'caption',m.caption,'alt_text',m.alt_text,'display_order',m.display_order) ORDER BY m.display_order),'[]'::jsonb) INTO media
 FROM public.flashcard_media_versions m WHERE m.flashcard_id=c.flashcard_id AND m.card_version=c.version AND m.is_active AND (i.revealed OR m.placement='question');
 RETURN jsonb_build_object('id',s.id,'total',total,'done',done,'excluded',excluded,'item_id',i.id,'revealed',i.revealed,'position',i.position,'card',jsonb_build_object('id',c.flashcard_id,'code',c.code,'version',c.version,'question',c.question,
 'short_answer',CASE WHEN i.revealed THEN c.short_answer END,'comment',CASE WHEN i.revealed THEN c.comment END,'reference',CASE WHEN i.revealed THEN c.reference END,
 'area',(SELECT name FROM public.areas WHERE id=c.area_id),'topic',(SELECT name FROM public.topics WHERE id=c.topic_id),'subtopic',(SELECT name FROM public.subtopics WHERE id=c.subtopic_id),'media',media));
END $$;

CREATE FUNCTION public.rate_study_item(p_session uuid,p_operation uuid,p_rating public.review_rating) RETURNS uuid
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.study_sessions%ROWTYPE; i public.study_session_items%ROWTYPE; st public.user_flashcard_states%ROWTYPE; eid uuid; old_rating public.review_rating; before_state public.learning_state;
BEGIN
 IF auth.uid() IS NULL OR p_rating IS NULL THEN RAISE EXCEPTION 'Avaliação não autorizada'; END IF;
 SELECT * INTO s FROM public.study_sessions WHERE id=p_session AND user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Sessão não autorizada'; END IF;
 SELECT * INTO i FROM public.study_session_items WHERE id=p_operation AND session_id=s.id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Operação inválida'; END IF;
 IF i.event_id IS NOT NULL THEN
 SELECT rating INTO old_rating FROM public.learning_events WHERE id=i.event_id;
 IF old_rating<>p_rating THEN RAISE EXCEPTION 'Avaliação já registrada com outra escolha'; END IF;
 RETURN i.event_id; -- Acknowledges committed history only; never returns card content.
 END IF;
 PERFORM 1 FROM public.flashcards WHERE id=i.flashcard_id FOR SHARE;
 IF i.skipped OR NOT i.revealed OR i.version_seen IS NULL OR NOT private.study_eligible(i.flashcard_id,s.section_id) THEN RAISE EXCEPTION 'Card não autorizado ou resposta não revelada'; END IF;
 IF EXISTS(SELECT 1 FROM public.study_session_items WHERE session_id=s.id AND position<i.position AND event_id IS NULL AND NOT skipped) THEN RAISE EXCEPTION 'Posição inválida'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(s.user_id::text||i.flashcard_id::text,0));
 SELECT * INTO st FROM public.user_flashcard_states WHERE user_id=s.user_id AND flashcard_id=i.flashcard_id FOR UPDATE;
 before_state:=CASE WHEN FOUND THEN st.learning_state ELSE 'new'::public.learning_state END;
 IF coalesce(st.review_count,0)>0 OR st.next_review_at IS NOT NULL OR st.fsrs_stability IS NOT NULL OR st.fsrs_difficulty IS NOT NULL OR coalesce(st.fsrs_data,'{}'::jsonb)<>'{}'::jsonb THEN RAISE EXCEPTION 'Card já estudado ou agendado'; END IF;
 INSERT INTO public.learning_events(user_id,flashcard_id,session_id,operation_id,rating,card_version_seen,learning_state_before)
 VALUES(s.user_id,i.flashcard_id,s.id,i.id,p_rating,i.version_seen,before_state) RETURNING id INTO eid;
 INSERT INTO public.user_flashcard_states(user_id,flashcard_id,learning_state,first_seen_at,last_reviewed_at,review_count,lapse_count,scheduling_status)
 VALUES(s.user_id,i.flashcard_id,'learning',now(),now(),1,CASE WHEN p_rating='again' THEN 1 ELSE 0 END,'unscheduled')
 ON CONFLICT(user_id,flashcard_id) DO UPDATE SET learning_state='learning',first_seen_at=coalesce(public.user_flashcard_states.first_seen_at,now()),last_reviewed_at=now(),
 review_count=public.user_flashcard_states.review_count+1,
 lapse_count=public.user_flashcard_states.lapse_count+CASE WHEN p_rating='again' THEN 1 ELSE 0 END,scheduling_status='unscheduled';
 UPDATE public.study_session_items SET event_id=eid WHERE id=i.id;
 UPDATE public.study_sessions SET updated_at=now() WHERE id=s.id;
 RETURN eid;
END $$;

REVOKE ALL ON FUNCTION public.study_catalog(uuid),public.start_study_session(uuid,uuid),public.read_study_session(uuid,boolean),public.rate_study_item(uuid,uuid,public.review_rating) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.study_catalog(uuid),public.start_study_session(uuid,uuid),public.read_study_session(uuid,boolean),public.rate_study_item(uuid,uuid,public.review_rating) TO authenticated;
-- No existing application writes were found in src/ or scripts/. Only the new
-- transactional endpoint may mutate student counters. Scheduled-event grants stay intact.
REVOKE INSERT,UPDATE,DELETE ON public.user_flashcard_states FROM authenticated;
-- Keep the original storage policy; add a narrow permission for historical media
-- actually pinned to the caller's current, still-authorized pending study item.
CREATE FUNCTION private.study_media_allowed(p_path text) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL AND EXISTS(
 SELECT 1 FROM public.study_sessions s JOIN public.study_session_items i ON i.session_id=s.id
 JOIN public.flashcard_media_versions m ON m.flashcard_id=i.flashcard_id AND m.card_version=i.version_seen
 WHERE s.user_id=auth.uid() AND i.event_id IS NULL AND NOT i.skipped
 AND m.storage_path=p_path AND m.is_active AND (i.revealed OR m.placement='question')
 AND private.study_eligible(i.flashcard_id,s.section_id))
$$;
REVOKE ALL ON FUNCTION private.study_media_allowed(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.study_media_allowed(text) TO authenticated;
CREATE POLICY study_pinned_media_read ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id='flashcard-media' AND private.study_media_allowed(name));
