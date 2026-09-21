CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.has_role(_user_id UUID, _role TEXT)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role::text = _role
  )
$$;
REVOKE ALL ON FUNCTION private.has_role(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.has_role(UUID, TEXT) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.can_manage_content(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT private.has_role(_user_id, 'admin') OR private.has_role(_user_id, 'editor')
$$;
REVOKE ALL ON FUNCTION private.can_manage_content(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.can_manage_content(UUID) TO authenticated, service_role;

ALTER POLICY "Authenticated users view active sections" ON public.sections USING (is_active OR private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers create sections" ON public.sections WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers update sections" ON public.sections USING (private.can_manage_content(auth.uid())) WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Authenticated users view active areas" ON public.areas USING (is_active OR private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers create areas" ON public.areas WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers update areas" ON public.areas USING (private.can_manage_content(auth.uid())) WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Authenticated users view active topics" ON public.topics USING (is_active OR private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers create topics" ON public.topics WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers update topics" ON public.topics USING (private.can_manage_content(auth.uid())) WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Authenticated users view active subtopics" ON public.subtopics USING (is_active OR private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers create subtopics" ON public.subtopics WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers update subtopics" ON public.subtopics USING (private.can_manage_content(auth.uid())) WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Students view published flashcards" ON public.flashcards USING (
  private.can_manage_content(auth.uid()) OR (
    status = 'published' AND EXISTS (
      SELECT 1
      FROM public.weekly_schedule_topics wst
      JOIN public.weekly_schedules ws ON ws.id = wst.weekly_schedule_id
      WHERE ws.section_id = flashcards.section_id
        AND ws.status = 'published'
        AND wst.topic_id = flashcards.topic_id
        AND wst.release_date <= current_date
    )
  )
);
ALTER POLICY "Content managers create flashcards" ON public.flashcards WITH CHECK (private.can_manage_content(auth.uid()) AND created_by = auth.uid() AND updated_by = auth.uid());
ALTER POLICY "Content managers update flashcards" ON public.flashcards USING (private.can_manage_content(auth.uid())) WITH CHECK (private.can_manage_content(auth.uid()) AND updated_by = auth.uid());
ALTER POLICY "Students view versions of published flashcards" ON public.flashcard_versions USING (private.can_manage_content(auth.uid()) OR EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id));
ALTER POLICY "Students view media of published flashcards" ON public.flashcard_media USING (private.can_manage_content(auth.uid()) OR EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id));
ALTER POLICY "Content managers create media" ON public.flashcard_media WITH CHECK (private.can_manage_content(auth.uid()) AND created_by = auth.uid());
ALTER POLICY "Content managers update media" ON public.flashcard_media USING (private.can_manage_content(auth.uid())) WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Authenticated users view active tags" ON public.tags USING (is_active OR private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers create tags" ON public.tags WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers update tags" ON public.tags USING (private.can_manage_content(auth.uid())) WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Students view tags of published flashcards" ON public.flashcard_tags USING (private.can_manage_content(auth.uid()) OR EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id));
ALTER POLICY "Content managers link tags" ON public.flashcard_tags WITH CHECK (private.can_manage_content(auth.uid()));
ALTER POLICY "Content managers unlink tags" ON public.flashcard_tags USING (private.can_manage_content(auth.uid()));
ALTER POLICY "Students view published schedules" ON public.weekly_schedules USING (status = 'published' OR private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins create schedules" ON public.weekly_schedules WITH CHECK (private.has_role(auth.uid(), 'admin') AND created_by = auth.uid());
ALTER POLICY "Admins update schedules" ON public.weekly_schedules USING (private.has_role(auth.uid(), 'admin')) WITH CHECK (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins delete schedules" ON public.weekly_schedules USING (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Students view released schedule topics" ON public.weekly_schedule_topics USING ((release_date <= current_date AND EXISTS (SELECT 1 FROM public.weekly_schedules ws WHERE ws.id = weekly_schedule_id AND ws.status = 'published')) OR private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins create schedule topics" ON public.weekly_schedule_topics WITH CHECK (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins update schedule topics" ON public.weekly_schedule_topics USING (private.has_role(auth.uid(), 'admin')) WITH CHECK (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins delete schedule topics" ON public.weekly_schedule_topics USING (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Students view own card state" ON public.user_flashcard_states USING (user_id = auth.uid() OR private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Students view own review events" ON public.review_events USING (user_id = auth.uid() OR private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins view editorial audit" ON public.editorial_audit_log USING (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins view all roles" ON public.user_roles USING (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins create roles" ON public.user_roles WITH CHECK (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins update roles" ON public.user_roles USING (private.has_role(auth.uid(), 'admin')) WITH CHECK (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins delete roles" ON public.user_roles USING (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins view profiles" ON public.profiles USING (private.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION private.prepare_flashcard_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor UUID := auth.uid();
  content_changed BOOLEAN;
  internal_media_bump BOOLEAN;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF actor IS NOT NULL THEN
      NEW.created_by := actor;
      NEW.updated_by := actor;
    END IF;
    NEW.version := 1;
    NEW.created_at := now();
    NEW.updated_at := now();
    RETURN NEW;
  END IF;

  content_changed := ROW(NEW.section_id, NEW.area_id, NEW.topic_id, NEW.subtopic_id, NEW.question, NEW.short_answer, NEW.comment, NEW.reference, NEW.editorial_difficulty)
    IS DISTINCT FROM ROW(OLD.section_id, OLD.area_id, OLD.topic_id, OLD.subtopic_id, OLD.question, OLD.short_answer, OLD.comment, OLD.reference, OLD.editorial_difficulty);
  internal_media_bump := pg_trigger_depth() > 1 AND NEW.version = OLD.version + 1;

  NEW.created_by := OLD.created_by;
  NEW.created_at := OLD.created_at;
  NEW.updated_by := COALESCE(actor, NEW.updated_by, OLD.updated_by);
  NEW.version := CASE WHEN content_changed OR internal_media_bump THEN OLD.version + 1 ELSE OLD.version END;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.prepare_flashcard_write() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.prepare_flashcard_write() TO service_role;

CREATE OR REPLACE FUNCTION private.record_flashcard_version()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.version <> OLD.version THEN
    INSERT INTO public.flashcard_versions (
      flashcard_id, version, code, section_id, area_id, topic_id, subtopic_id,
      question, short_answer, comment, reference, editorial_difficulty, status, changed_by
    ) VALUES (
      NEW.id, NEW.version, NEW.code, NEW.section_id, NEW.area_id, NEW.topic_id, NEW.subtopic_id,
      NEW.question, NEW.short_answer, NEW.comment, NEW.reference, NEW.editorial_difficulty, NEW.status, NEW.updated_by
    );
  END IF;

  INSERT INTO public.editorial_audit_log (actor_id, entity_type, entity_id, action, old_data, new_data)
  VALUES (
    auth.uid(), 'flashcard', NEW.id,
    CASE WHEN TG_OP = 'INSERT' THEN 'create' WHEN NEW.status = 'archived' AND OLD.status IS DISTINCT FROM NEW.status THEN 'archive' ELSE 'update' END,
    CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) END,
    to_jsonb(NEW)
  );
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.record_flashcard_version() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.record_flashcard_version() TO service_role;

CREATE OR REPLACE FUNCTION private.prepare_media_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.created_by := COALESCE(auth.uid(), NEW.created_by);
    NEW.created_at := now();
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.prepare_media_write() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.prepare_media_write() TO service_role;

CREATE OR REPLACE FUNCTION private.record_media_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  card public.flashcards%ROWTYPE;
BEGIN
  UPDATE public.flashcards
  SET version = version + 1,
      updated_by = COALESCE(auth.uid(), updated_by),
      updated_at = now()
  WHERE id = NEW.flashcard_id
  RETURNING * INTO card;

  INSERT INTO public.editorial_audit_log (actor_id, entity_type, entity_id, action, old_data, new_data)
  VALUES (auth.uid(), 'flashcard_media', NEW.id, CASE WHEN TG_OP = 'INSERT' THEN 'create' ELSE 'update' END,
    CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) END, to_jsonb(NEW));
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.record_media_change() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.record_media_change() TO service_role;

DROP TRIGGER flashcards_prepare_write ON public.flashcards;
DROP TRIGGER flashcards_record_version ON public.flashcards;
DROP TRIGGER flashcard_media_prepare_write ON public.flashcard_media;
DROP TRIGGER flashcard_media_record_change ON public.flashcard_media;
CREATE TRIGGER flashcards_prepare_write BEFORE INSERT OR UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION private.prepare_flashcard_write();
CREATE TRIGGER flashcards_record_version AFTER INSERT OR UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION private.record_flashcard_version();
CREATE TRIGGER flashcard_media_prepare_write BEFORE INSERT OR UPDATE ON public.flashcard_media FOR EACH ROW EXECUTE FUNCTION private.prepare_media_write();
CREATE TRIGGER flashcard_media_record_change AFTER INSERT OR UPDATE ON public.flashcard_media FOR EACH ROW EXECUTE FUNCTION private.record_media_change();

ALTER TABLE public.review_events
  ADD CONSTRAINT review_events_version_fkey
  FOREIGN KEY (flashcard_id, card_version_seen)
  REFERENCES public.flashcard_versions(flashcard_id, version)
  ON DELETE RESTRICT;

DROP FUNCTION public.record_media_change();
DROP FUNCTION public.prepare_media_write();
DROP FUNCTION public.record_flashcard_version();
DROP FUNCTION public.prepare_flashcard_write();
DROP FUNCTION public.can_manage_content(UUID);
DROP FUNCTION public.has_role(UUID, TEXT);