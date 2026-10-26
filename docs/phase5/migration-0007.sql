-- Fase 5: FSRS e fila diária inteligente (aditiva; nenhum histórico é alterado)

-- 1. Configurações imutáveis do algoritmo
CREATE TABLE public.fsrs_configurations(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  package_name text NOT NULL,
  package_version text NOT NULL,
  algorithm_version text NOT NULL,
  request_retention numeric NOT NULL,
  maximum_interval integer NOT NULL,
  learning_steps jsonb NOT NULL,
  relearning_steps jsonb NOT NULL,
  enable_fuzz boolean NOT NULL,
  enable_short_term boolean NOT NULL,
  weights jsonb NOT NULL,
  adapter_version text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.fsrs_configurations TO authenticated;
GRANT ALL ON public.fsrs_configurations TO service_role;
ALTER TABLE public.fsrs_configurations ENABLE ROW LEVEL SECURITY;
CREATE POLICY fsrs_config_read ON public.fsrs_configurations FOR SELECT TO authenticated USING(true);
COMMENT ON TABLE public.fsrs_configurations IS 'Configurações imutáveis do motor FSRS; novas versões criam novas linhas, nunca reescrevem eventos.';

-- 2. Proveniência de inicialização FSRS (sem eventos retroativos)
CREATE TABLE public.fsrs_initializations(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  flashcard_id uuid NOT NULL REFERENCES public.flashcards(id),
  origin text NOT NULL CHECK(origin IN ('new_card','phase4_unscheduled')),
  reference_event_id uuid REFERENCES public.learning_events(id),
  config_id uuid NOT NULL REFERENCES public.fsrs_configurations(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, flashcard_id)
);
GRANT SELECT ON public.fsrs_initializations TO authenticated;
GRANT ALL ON public.fsrs_initializations TO service_role;
ALTER TABLE public.fsrs_initializations ENABLE ROW LEVEL SECURITY;
CREATE POLICY fsrs_init_owner ON public.fsrs_initializations FOR SELECT TO authenticated USING(user_id=auth.uid());
COMMENT ON TABLE public.fsrs_initializations IS 'Proveniência da inicialização FSRS; comita junto da primeira avaliação real, sem histórico fictício.';

-- 3. Fila diária
CREATE TABLE public.daily_study_queues(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  section_id uuid NOT NULL REFERENCES public.sections(id),
  day date NOT NULL,
  timezone text NOT NULL DEFAULT 'America/Fortaleza',
  policy_version text NOT NULL DEFAULT 'phase5-v1',
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, section_id, day)
);
GRANT SELECT ON public.daily_study_queues TO authenticated;
GRANT ALL ON public.daily_study_queues TO service_role;
ALTER TABLE public.daily_study_queues ENABLE ROW LEVEL SECURITY;
CREATE POLICY daily_queue_owner ON public.daily_study_queues FOR SELECT TO authenticated USING(user_id=auth.uid());

CREATE TABLE public.daily_queue_members(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_id uuid NOT NULL REFERENCES public.daily_study_queues(id),
  flashcard_id uuid NOT NULL REFERENCES public.flashcards(id),
  origin text NOT NULL CHECK(origin IN ('review_overdue','review_today','learning','relearning','phase4_unscheduled','new_card')),
  priority integer NOT NULL,
  position integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(queue_id, flashcard_id),
  UNIQUE(queue_id, position)
);
GRANT SELECT ON public.daily_queue_members TO authenticated;
GRANT ALL ON public.daily_queue_members TO service_role;
ALTER TABLE public.daily_queue_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY daily_member_owner ON public.daily_queue_members FOR SELECT TO authenticated
  USING(EXISTS(SELECT 1 FROM public.daily_study_queues q WHERE q.id=queue_id AND q.user_id=auth.uid()));
CREATE INDEX daily_members_queue ON public.daily_queue_members(queue_id, priority, position);

-- 4. Tentativas persistentes (uma apresentação; passos repetidos criam novas tentativas)
CREATE TABLE public.daily_study_attempts(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_id uuid NOT NULL REFERENCES public.daily_study_queues(id),
  flashcard_id uuid NOT NULL REFERENCES public.flashcards(id),
  card_version_seen integer,
  revealed boolean NOT NULL DEFAULT false,
  state_revision_expected integer,
  operation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  prepared_at timestamptz,
  committed_event_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(queue_id, operation_id),
  FOREIGN KEY(flashcard_id, card_version_seen) REFERENCES public.flashcard_versions(flashcard_id, version)
);
GRANT SELECT ON public.daily_study_attempts TO authenticated;
GRANT ALL ON public.daily_study_attempts TO service_role;
ALTER TABLE public.daily_study_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY daily_attempt_owner ON public.daily_study_attempts FOR SELECT TO authenticated
  USING(EXISTS(SELECT 1 FROM public.daily_study_queues q WHERE q.id=queue_id AND q.user_id=auth.uid()));
CREATE INDEX daily_attempts_pending ON public.daily_study_attempts(queue_id) WHERE committed_event_id IS NULL;

-- 5. Estado: revisão monotônica e vínculos FSRS (aditivo, nullable)
ALTER TABLE public.user_flashcard_states
  ADD COLUMN state_revision integer NOT NULL DEFAULT 0,
  ADD COLUMN fsrs_config_id uuid REFERENCES public.fsrs_configurations(id),
  ADD COLUMN fsrs_initialization_id uuid REFERENCES public.fsrs_initializations(id),
  ADD COLUMN fsrs_last_computed_at timestamptz;
COMMENT ON COLUMN public.user_flashcard_states.state_revision IS 'Revisão monotônica do estado FSRS; consumo único por avaliação (compare-and-swap).';
CREATE INDEX user_states_due ON public.user_flashcard_states(user_id, next_review_at) WHERE scheduling_status='scheduled';

-- 6. Eventos de revisão: vínculos da Fase 5 (nullable para preservar legado)
ALTER TABLE public.review_events
  ADD COLUMN operation_id uuid,
  ADD COLUMN attempt_id uuid REFERENCES public.daily_study_attempts(id),
  ADD COLUMN config_id uuid REFERENCES public.fsrs_configurations(id),
  ADD COLUMN origin text,
  ADD COLUMN state_revision_before integer,
  ADD COLUMN state_revision_after integer;
CREATE UNIQUE INDEX review_events_operation_unique ON public.review_events(user_id, operation_id) WHERE operation_id IS NOT NULL;
CREATE UNIQUE INDEX review_events_revision_unique ON public.review_events(user_id, flashcard_id, state_revision_before) WHERE state_revision_before IS NOT NULL;

-- 7. Hardening: fechar escrita direta legada e tornar review_events append-only
REVOKE INSERT, UPDATE, DELETE ON public.review_events FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.user_study_preferences FROM anon, authenticated;
CREATE OR REPLACE FUNCTION private.guard_review_event_history() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'Eventos de revisão são imutáveis'; END $$;
CREATE TRIGGER review_event_history_guard BEFORE UPDATE OR DELETE ON public.review_events
  FOR EACH ROW EXECUTE FUNCTION private.guard_review_event_history();

-- 8. Resumo diário (contagens para Dashboard/Cards)
CREATE OR REPLACE FUNCTION public.daily_summary(p_section uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_day date := (now() AT TIME ZONE 'America/Fortaleza')::date;
  v_day_start timestamptz := ((now() AT TIME ZONE 'America/Fortaleza')::date)::timestamp AT TIME ZONE 'America/Fortaleza';
  v_day_end timestamptz := v_day_start + interval '1 day';
  v_goal integer;
  v_overdue integer; v_today integer; v_learning integer; v_init integer; v_new integer;
  v_answered integer; v_distinct integer;
BEGIN
  IF NOT private.study_section_allowed(p_section) THEN RAISE EXCEPTION 'Seção não autorizada'; END IF;
  SELECT coalesce(daily_card_goal,25) INTO v_goal FROM public.user_study_preferences WHERE user_id=auth.uid();
  v_goal := coalesce(v_goal,25);
  SELECT count(*) FILTER(WHERE st.next_review_at < v_day_start),
         count(*) FILTER(WHERE st.next_review_at >= v_day_start AND st.next_review_at < v_day_end),
         count(*) FILTER(WHERE st.learning_state IN ('learning','relearning') AND st.next_review_at <= now())
    INTO v_overdue, v_today, v_learning
    FROM public.user_flashcard_states st
   WHERE st.user_id=auth.uid() AND st.scheduling_status='scheduled'
     AND private.study_eligible(st.flashcard_id, p_section);
  SELECT count(*) INTO v_init FROM public.user_flashcard_states st
   WHERE st.user_id=auth.uid() AND st.scheduling_status='unscheduled' AND st.review_count>0
     AND private.study_eligible(st.flashcard_id, p_section);
  SELECT count(*) INTO v_new FROM public.flashcards f
   WHERE private.study_eligible(f.id, p_section)
     AND NOT EXISTS(SELECT 1 FROM public.user_flashcard_states st WHERE st.user_id=auth.uid() AND st.flashcard_id=f.id);
  SELECT count(*), count(DISTINCT e.flashcard_id) INTO v_answered, v_distinct
    FROM public.learning_events e
   WHERE e.user_id=auth.uid() AND e.reviewed_at >= v_day_start AND e.reviewed_at < v_day_end;
  SELECT v_answered + count(*), v_distinct + count(DISTINCT e.flashcard_id) INTO v_answered, v_distinct
    FROM public.review_events e
   WHERE e.user_id=auth.uid() AND e.reviewed_at >= v_day_start AND e.reviewed_at < v_day_end
     AND NOT EXISTS(SELECT 1 FROM public.learning_events le WHERE le.user_id=e.user_id AND le.flashcard_id=e.flashcard_id AND le.reviewed_at >= v_day_start AND le.reviewed_at < v_day_end);
  RETURN jsonb_build_object(
    'day', v_day, 'goal', v_goal,
    'review_overdue', v_overdue, 'review_today', v_today, 'learning_due', v_learning,
    'pending_init', v_init, 'new_available', v_new,
    'answered_today', v_answered, 'distinct_today', v_distinct);
END $$;
REVOKE ALL ON FUNCTION public.daily_summary(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.daily_summary(uuid) TO authenticated;

-- 9. Criar/retomar a fila do dia (idempotente por usuário/seção/dia)
CREATE OR REPLACE FUNCTION public.start_daily_queue(p_section uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_day date := (now() AT TIME ZONE 'America/Fortaleza')::date;
  v_day_start timestamptz := ((now() AT TIME ZONE 'America/Fortaleza')::date)::timestamp AT TIME ZONE 'America/Fortaleza';
  v_day_end timestamptz := v_day_start + interval '1 day';
  v_queue uuid;
  v_pos integer := 0;
BEGIN
  IF NOT private.study_section_allowed(p_section) THEN RAISE EXCEPTION 'Seção não autorizada'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_section::text||v_day::text,0));
  SELECT id INTO v_queue FROM public.daily_study_queues
   WHERE user_id=auth.uid() AND section_id=p_section AND day=v_day;
  IF v_queue IS NULL THEN
    INSERT INTO public.daily_study_queues(user_id, section_id, day) VALUES(auth.uid(), p_section, v_day) RETURNING id INTO v_queue;
  END IF;
  -- Extensão incremental: adiciona apenas cards ainda ausentes da fila
  INSERT INTO public.daily_queue_members(queue_id, flashcard_id, origin, priority, position)
  SELECT v_queue, x.flashcard_id, x.origin, x.priority,
         (SELECT coalesce(max(m.position),0) FROM public.daily_queue_members m WHERE m.queue_id=v_queue) + row_number() OVER(ORDER BY x.priority, x.sort_key)
    FROM (
      SELECT st.flashcard_id,
             CASE WHEN st.learning_state='review' AND st.next_review_at < v_day_start THEN 'review_overdue'
                  WHEN st.learning_state='review' THEN 'review_today'
                  WHEN st.learning_state='relearning' THEN 'relearning'
                  ELSE 'learning' END AS origin,
             CASE WHEN st.learning_state='review' AND st.next_review_at < v_day_start THEN 1
                  WHEN st.learning_state='review' THEN 2
                  WHEN st.learning_state='relearning' THEN 3
                  ELSE 4 END AS priority,
             st.next_review_at::text AS sort_key
        FROM public.user_flashcard_states st
       WHERE st.user_id=auth.uid() AND st.scheduling_status='scheduled'
         AND ((st.learning_state='review' AND st.next_review_at < v_day_end)
              OR (st.learning_state IN ('learning','relearning') AND st.next_review_at <= now()))
         AND private.study_eligible(st.flashcard_id, p_section)
      UNION ALL
      SELECT st.flashcard_id, 'phase4_unscheduled', 5, st.last_reviewed_at::text
        FROM public.user_flashcard_states st
       WHERE st.user_id=auth.uid() AND st.scheduling_status='unscheduled' AND st.review_count>0
         AND private.study_eligible(st.flashcard_id, p_section)
      UNION ALL
      SELECT f.id, 'new_card', 6, f.code
        FROM public.flashcards f
       WHERE private.study_eligible(f.id, p_section)
         AND NOT EXISTS(SELECT 1 FROM public.user_flashcard_states st WHERE st.user_id=auth.uid() AND st.flashcard_id=f.id)
    ) x
   WHERE NOT EXISTS(SELECT 1 FROM public.daily_queue_members m WHERE m.queue_id=v_queue AND m.flashcard_id=x.flashcard_id);
  RETURN v_queue;
END $$;

-- 10. Ler/revelar a próxima tentativa pendente da fila
CREATE OR REPLACE FUNCTION public.read_daily_attempt(p_queue uuid, p_reveal boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  q public.daily_study_queues%ROWTYPE;
  m public.daily_queue_members%ROWTYPE;
  a public.daily_study_attempts%ROWTYPE;
  c public.flashcard_versions%ROWTYPE;
  st public.user_flashcard_states%ROWTYPE;
  media jsonb; remaining integer; total integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Não autorizado'; END IF;
  SELECT * INTO q FROM public.daily_study_queues WHERE id=p_queue AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR NOT private.study_section_allowed(q.section_id) THEN RAISE EXCEPTION 'Fila não autorizada'; END IF;
  -- Reutiliza tentativa ativa (retomada) ou cria a próxima
  SELECT * INTO a FROM public.daily_study_attempts WHERE queue_id=q.id AND committed_event_id IS NULL ORDER BY created_at LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN
    SELECT * INTO m FROM public.daily_queue_members mm
     WHERE mm.queue_id=q.id
       AND private.study_eligible(mm.flashcard_id, q.section_id)
       AND NOT EXISTS(SELECT 1 FROM public.daily_study_attempts x WHERE x.queue_id=q.id AND x.flashcard_id=mm.flashcard_id)
       AND NOT EXISTS(SELECT 1 FROM public.user_flashcard_states s2
                       WHERE s2.user_id=q.user_id AND s2.flashcard_id=mm.flashcard_id
                         AND ((mm.origin IN ('review_overdue','review_today','learning','relearning') AND s2.scheduling_status<>'scheduled')
                           OR (mm.origin='phase4_unscheduled' AND s2.scheduling_status='scheduled')
                           OR (mm.origin='new_card' AND s2.review_count>0)))
     ORDER BY mm.priority, mm.position LIMIT 1;
    IF NOT FOUND THEN
      SELECT count(*), count(*) FILTER(WHERE committed_event_id IS NOT NULL) INTO total, remaining
        FROM public.daily_study_attempts WHERE queue_id=q.id;
      RETURN jsonb_build_object('id', q.id, 'mode', 'daily', 'total', total, 'done', remaining, 'card', NULL);
    END IF;
    SELECT * INTO st FROM public.user_flashcard_states WHERE user_id=q.user_id AND flashcard_id=m.flashcard_id;
    INSERT INTO public.daily_study_attempts(queue_id, flashcard_id, card_version_seen, state_revision_expected)
    VALUES(q.id, m.flashcard_id, (SELECT version FROM public.flashcards WHERE id=m.flashcard_id), coalesce(st.state_revision,0))
    RETURNING * INTO a;
  END IF;
  PERFORM 1 FROM public.flashcards WHERE id=a.flashcard_id FOR SHARE;
  IF NOT private.study_eligible(a.flashcard_id, q.section_id) THEN RAISE EXCEPTION 'Card não autorizado'; END IF;
  IF p_reveal THEN UPDATE public.daily_study_attempts SET revealed=true WHERE id=a.id RETURNING * INTO a; END IF;
  SELECT * INTO c FROM public.flashcard_versions WHERE flashcard_id=a.flashcard_id AND version=a.card_version_seen;
  IF NOT FOUND THEN RAISE EXCEPTION 'Versão histórica ausente'; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('type',mm.type,'placement',mm.placement,'storage_path',mm.storage_path,'caption',mm.caption,'alt_text',mm.alt_text,'display_order',mm.display_order) ORDER BY mm.display_order),'[]'::jsonb)
    INTO media FROM public.flashcard_media_versions mm
   WHERE mm.flashcard_id=c.flashcard_id AND mm.card_version=c.version AND mm.is_active AND (a.revealed OR mm.placement='question');
  SELECT count(*), count(*) FILTER(WHERE committed_event_id IS NOT NULL) INTO total, remaining
    FROM public.daily_study_attempts WHERE queue_id=q.id;
  RETURN jsonb_build_object('id', q.id, 'mode', 'daily', 'total', total, 'done', remaining,
    'item_id', a.id, 'operation_id', a.operation_id, 'revealed', a.revealed,
    'card', jsonb_build_object('id', c.flashcard_id, 'code', c.code, 'version', c.version,
      'question', c.question,
      'short_answer', CASE WHEN a.revealed THEN c.short_answer END,
      'comment', CASE WHEN a.revealed THEN c.comment END,
      'reference', CASE WHEN a.revealed THEN c.reference END,
      'area', (SELECT name FROM public.areas WHERE id=c.area_id),
      'topic', (SELECT name FROM public.topics WHERE id=c.topic_id),
      'subtopic', (SELECT name FROM public.subtopics WHERE id=c.subtopic_id),
      'media', media));
END $$;

-- 11. Preparar avaliação: recibo persistente com instante e revisão esperada
CREATE OR REPLACE FUNCTION public.prepare_daily_rating(p_attempt uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  a public.daily_study_attempts%ROWTYPE;
  q public.daily_study_queues%ROWTYPE;
  st public.user_flashcard_states%ROWTYPE;
  cfg public.fsrs_configurations%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Não autorizado'; END IF;
  SELECT * INTO a FROM public.daily_study_attempts WHERE id=p_attempt FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tentativa inválida'; END IF;
  SELECT * INTO q FROM public.daily_study_queues WHERE id=a.queue_id AND user_id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Fila não autorizada'; END IF;
  IF a.committed_event_id IS NOT NULL THEN
    RETURN jsonb_build_object('committed', true, 'event_id', a.committed_event_id);
  END IF;
  IF NOT a.revealed OR a.card_version_seen IS NULL OR NOT private.study_eligible(a.flashcard_id, q.section_id) THEN
    RAISE EXCEPTION 'Card não autorizado ou resposta não revelada';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(q.user_id::text||a.flashcard_id::text,0));
  SELECT * INTO st FROM public.user_flashcard_states WHERE user_id=q.user_id AND flashcard_id=a.flashcard_id FOR UPDATE;
  SELECT * INTO cfg FROM public.fsrs_configurations ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Configuração FSRS ausente'; END IF;
  UPDATE public.daily_study_attempts
     SET prepared_at=now(), state_revision_expected=coalesce(st.state_revision,0)
   WHERE id=a.id RETURNING * INTO a;
  RETURN jsonb_build_object('committed', false, 'attempt_id', a.id, 'operation_id', a.operation_id,
    'prepared_at', a.prepared_at, 'state_revision', a.state_revision_expected,
    'config_id', cfg.id, 'config', to_jsonb(cfg),
    'state', CASE WHEN st.user_id IS NULL THEN NULL ELSE to_jsonb(st) END);
END $$;

-- 12. Commit interno restrito: grava evento + estado + tentativa + inicialização atomicamente
CREATE OR REPLACE FUNCTION public.commit_daily_rating(
  p_attempt uuid, p_operation uuid, p_rating public.review_rating, p_result jsonb
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  a public.daily_study_attempts%ROWTYPE;
  q public.daily_study_queues%ROWTYPE;
  st public.user_flashcard_states%ROWTYPE;
  eid uuid;
  old_rating public.review_rating;
  v_revision integer;
  v_origin text;
  v_init uuid;
  v_last_event uuid;
BEGIN
  SELECT * INTO a FROM public.daily_study_attempts WHERE id=p_attempt FOR UPDATE;
  IF NOT FOUND OR a.operation_id<>p_operation THEN RAISE EXCEPTION 'Operação inválida'; END IF;
  SELECT * INTO q FROM public.daily_study_queues WHERE id=a.queue_id;
  -- Idempotência: mesma operação já comitada
  IF a.committed_event_id IS NOT NULL THEN
    SELECT rating INTO old_rating FROM public.review_events WHERE id=a.committed_event_id;
    IF old_rating<>p_rating THEN RAISE EXCEPTION 'Avaliação já registrada com outra escolha'; END IF;
    RETURN a.committed_event_id;
  END IF;
  IF a.prepared_at IS NULL THEN RAISE EXCEPTION 'Avaliação não preparada'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(q.user_id::text||a.flashcard_id::text,0));
  SELECT * INTO st FROM public.user_flashcard_states WHERE user_id=q.user_id AND flashcard_id=a.flashcard_id FOR UPDATE;
  -- Compare-and-swap: a revisão do estado deve ser a mesma da preparação
  IF coalesce(st.state_revision,0) <> a.state_revision_expected THEN
    RAISE EXCEPTION 'Estado alterado por outra sessão; recarregue';
  END IF;
  v_revision := a.state_revision_expected + 1;
  v_origin := coalesce(p_result->>'origin','new_card');
  -- Inicialização FSRS prospectiva, vinculada ao histórico real quando houver
  SELECT id INTO v_init FROM public.fsrs_initializations WHERE user_id=q.user_id AND flashcard_id=a.flashcard_id;
  IF v_init IS NULL THEN
    SELECT id INTO v_last_event FROM public.learning_events
     WHERE user_id=q.user_id AND flashcard_id=a.flashcard_id ORDER BY reviewed_at DESC LIMIT 1;
    INSERT INTO public.fsrs_initializations(user_id, flashcard_id, origin, reference_event_id, config_id)
    VALUES(q.user_id, a.flashcard_id, v_origin, v_last_event, (p_result->>'config_id')::uuid)
    RETURNING id INTO v_init;
  END IF;
  INSERT INTO public.review_events(
    user_id, flashcard_id, rating, previous_interval, new_interval, scheduled_next_review,
    card_version_seen, learning_state_before, learning_state_after, fsrs_data,
    operation_id, attempt_id, config_id, origin, state_revision_before, state_revision_after, reviewed_at)
  VALUES(
    q.user_id, a.flashcard_id, p_rating,
    coalesce(st.current_interval,0), (p_result->>'scheduled_days')::numeric,
    (p_result->>'due')::timestamptz, a.card_version_seen,
    coalesce(st.learning_state,'new'::public.learning_state), (p_result->>'state')::public.learning_state,
    (p_result->'fsrs_data'), p_operation, a.id, (p_result->>'config_id')::uuid, v_origin,
    a.state_revision_expected, v_revision, a.prepared_at)
  RETURNING id INTO eid;
  INSERT INTO public.user_flashcard_states(
    user_id, flashcard_id, learning_state, first_seen_at, last_reviewed_at, next_review_at,
    current_interval, review_count, lapse_count, fsrs_stability, fsrs_difficulty, fsrs_data,
    scheduling_status, state_revision, fsrs_config_id, fsrs_initialization_id, fsrs_last_computed_at)
  VALUES(
    q.user_id, a.flashcard_id, (p_result->>'state')::public.learning_state, a.prepared_at, a.prepared_at,
    (p_result->>'due')::timestamptz, (p_result->>'scheduled_days')::numeric, 1,
    CASE WHEN p_rating='again' THEN 1 ELSE 0 END,
    (p_result->>'stability')::numeric, (p_result->>'difficulty')::numeric, (p_result->'fsrs_data'),
    'scheduled', v_revision, (p_result->>'config_id')::uuid, v_init, a.prepared_at)
  ON CONFLICT(user_id, flashcard_id) DO UPDATE SET
    learning_state=(p_result->>'state')::public.learning_state,
    first_seen_at=coalesce(public.user_flashcard_states.first_seen_at, a.prepared_at),
    last_reviewed_at=a.prepared_at,
    next_review_at=(p_result->>'due')::timestamptz,
    current_interval=(p_result->>'scheduled_days')::numeric,
    review_count=public.user_flashcard_states.review_count+1,
    lapse_count=public.user_flashcard_states.lapse_count+CASE WHEN p_rating='again' THEN 1 ELSE 0 END,
    fsrs_stability=(p_result->>'stability')::numeric,
    fsrs_difficulty=(p_result->>'difficulty')::numeric,
    fsrs_data=(p_result->'fsrs_data'),
    scheduling_status='scheduled',
    state_revision=v_revision,
    fsrs_config_id=(p_result->>'config_id')::uuid,
    fsrs_initialization_id=coalesce(public.user_flashcard_states.fsrs_initialization_id, v_init),
    fsrs_last_computed_at=a.prepared_at;
  UPDATE public.daily_study_attempts SET committed_event_id=eid WHERE id=a.id;
  UPDATE public.daily_study_queues SET updated_at=now() WHERE id=q.id;
  RETURN eid;
END $$;

REVOKE ALL ON FUNCTION public.read_daily_attempt(uuid,boolean), public.prepare_daily_rating(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.read_daily_attempt(uuid,boolean), public.prepare_daily_rating(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.start_daily_queue(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_daily_queue(uuid) TO authenticated;
-- Commit interno: somente o papel privilegiado do servidor; nunca anon/authenticated
REVOKE ALL ON FUNCTION public.commit_daily_rating(uuid,uuid,public.review_rating,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.commit_daily_rating(uuid,uuid,public.review_rating,jsonb) TO service_role;

-- 13. Mídia histórica autorizada também para tentativas diárias pendentes
CREATE OR REPLACE FUNCTION private.study_media_allowed(p_path text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS(SELECT 1 FROM public.study_sessions s
            JOIN public.study_session_items i ON i.session_id=s.id
            JOIN public.flashcard_media_versions m ON m.flashcard_id=i.flashcard_id AND m.card_version=i.version_seen
           WHERE s.user_id=auth.uid() AND i.event_id IS NULL AND NOT i.skipped
             AND m.storage_path=p_path AND m.is_active AND (i.revealed OR m.placement='question')
             AND private.study_eligible(i.flashcard_id, s.section_id))
    OR EXISTS(SELECT 1 FROM public.daily_study_queues q
            JOIN public.daily_study_attempts a ON a.queue_id=q.id
            JOIN public.flashcard_media_versions m ON m.flashcard_id=a.flashcard_id AND m.card_version=a.card_version_seen
           WHERE q.user_id=auth.uid() AND a.committed_event_id IS NULL
             AND m.storage_path=p_path AND m.is_active AND (a.revealed OR m.placement='question')
             AND private.study_eligible(a.flashcard_id, q.section_id)))
$$;
