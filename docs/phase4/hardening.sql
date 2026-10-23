-- Forward-only Phase 4 hardening; no history changes. Applied transactionally by migration tool.
-- Existing postgres/public default ACL grants ALL to anon/authenticated. Restrict these specific objects only.
REVOKE ALL ON public.learning_events,public.study_sessions,public.study_session_items,public.user_flashcard_states FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.learning_events,public.study_sessions,public.study_session_items,public.user_flashcard_states TO authenticated;
GRANT ALL ON public.learning_events,public.study_sessions,public.study_session_items,public.user_flashcard_states TO service_role;
CREATE OR REPLACE FUNCTION public.study_catalog(p_section uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
 IF NOT private.study_section_allowed(p_section) THEN RAISE EXCEPTION 'Seção não autorizada'; END IF;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'release_at'),'[]'::jsonb) INTO result FROM (
 SELECT jsonb_build_object('id',t.id,'name',t.name,'area',a.name,'release_at',min(wi.release_at),'locked',min(wi.release_at)>now(),
 'total',(SELECT count(*) FROM public.flashcards f WHERE f.topic_id=t.id AND private.study_eligible(f.id,p_section)),
 'studied',(SELECT count(*) FROM public.flashcards f JOIN public.user_flashcard_states st ON st.flashcard_id=f.id AND st.user_id=auth.uid() AND st.review_count>0 WHERE f.topic_id=t.id AND private.study_eligible(f.id,p_section))) x
 FROM public.weekly_schedules ws JOIN public.weekly_schedule_items wi ON wi.weekly_schedule_id=ws.id JOIN public.topics t ON t.id=wi.topic_id AND t.is_active JOIN public.areas a ON a.id=t.area_id AND a.is_active
 WHERE ws.section_id=p_section AND ws.status='published' GROUP BY t.id,t.name,a.name) q;
 RETURN result;
END $$;
-- Student media is session-bound, including active current media; content managers retain editorial access.
ALTER POLICY "Students view accessible flashcard media files" ON storage.objects USING(bucket_id='flashcard-media' AND private.can_manage_content(auth.uid()));
COMMENT ON FUNCTION public.study_catalog(uuid) IS 'Authenticated active-section curriculum metadata, including future names/dates only; future content/counts remain inaccessible.';