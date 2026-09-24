-- Normalize flashcard-to-section membership.
CREATE TABLE public.flashcard_sections (
  flashcard_id UUID NOT NULL REFERENCES public.flashcards(id) ON DELETE RESTRICT,
  section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (flashcard_id, section_id)
);
GRANT SELECT, INSERT, DELETE ON public.flashcard_sections TO authenticated;
GRANT ALL ON public.flashcard_sections TO service_role;
ALTER TABLE public.flashcard_sections ENABLE ROW LEVEL SECURITY;

CREATE INDEX flashcard_sections_section_idx
  ON public.flashcard_sections (section_id, flashcard_id);

-- Per-user study preferences. There is intentionally no interface yet.
CREATE TABLE public.user_study_preferences (
  user_id UUID PRIMARY KEY,
  daily_card_goal INTEGER NOT NULL DEFAULT 25 CHECK (daily_card_goal >= 25),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.user_study_preferences TO authenticated;
GRANT ALL ON public.user_study_preferences TO service_role;
ALTER TABLE public.user_study_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own study preferences"
ON public.user_study_preferences FOR SELECT TO authenticated
USING (user_id = auth.uid() OR private.has_role(auth.uid(), 'admin'));
CREATE POLICY "Users create own study preferences"
ON public.user_study_preferences FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users update own study preferences"
ON public.user_study_preferences FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE TRIGGER user_study_preferences_set_updated_at
BEFORE UPDATE ON public.user_study_preferences
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Replace the fixed schedule-topic shape with extensible schedule items.
DROP TRIGGER IF EXISTS weekly_schedules_validate_publish ON public.weekly_schedules;
DROP TRIGGER IF EXISTS weekly_schedule_topics_validate ON public.weekly_schedule_topics;
DROP FUNCTION IF EXISTS private.validate_weekly_schedule_publish();
DROP FUNCTION IF EXISTS public.validate_schedule_topic();
DROP POLICY IF EXISTS "Students view published flashcards" ON public.flashcards;
DROP POLICY IF EXISTS "Students view released schedule topics" ON public.weekly_schedule_topics;

ALTER TABLE public.weekly_schedule_topics RENAME TO weekly_schedule_items;
ALTER TABLE public.weekly_schedule_items RENAME COLUMN release_weekday TO release_day;
ALTER TABLE public.weekly_schedule_items RENAME COLUMN release_date TO release_at;
ALTER TABLE public.weekly_schedule_items
  ALTER COLUMN release_at TYPE TIMESTAMPTZ
  USING release_at::timestamp AT TIME ZONE 'America/Fortaleza';
ALTER TABLE public.weekly_schedule_items ADD COLUMN release_order SMALLINT;
ALTER TABLE public.weekly_schedule_items ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
UPDATE public.weekly_schedule_items
SET release_order = CASE release_day WHEN 1 THEN 1 WHEN 3 THEN 2 WHEN 5 THEN 3 ELSE release_day END
WHERE release_order IS NULL;
ALTER TABLE public.weekly_schedule_items ALTER COLUMN release_order SET NOT NULL;

ALTER TABLE public.weekly_schedule_items
  DROP CONSTRAINT IF EXISTS weekly_schedule_topics_release_weekday_check,
  DROP CONSTRAINT IF EXISTS weekly_schedule_topics_weekly_schedule_id_release_weekday_key,
  DROP CONSTRAINT IF EXISTS weekly_schedule_topics_weekly_schedule_id_topic_id_key;
ALTER TABLE public.weekly_schedule_items
  ADD CONSTRAINT weekly_schedule_items_release_day_check CHECK (release_day BETWEEN 1 AND 7),
  ADD CONSTRAINT weekly_schedule_items_release_order_check CHECK (release_order > 0),
  ADD CONSTRAINT weekly_schedule_items_schedule_topic_key UNIQUE (weekly_schedule_id, topic_id),
  ADD CONSTRAINT weekly_schedule_items_schedule_day_key UNIQUE (weekly_schedule_id, release_day),
  ADD CONSTRAINT weekly_schedule_items_schedule_order_key UNIQUE (weekly_schedule_id, release_order);

DROP INDEX IF EXISTS public.weekly_schedule_topics_release_idx;
CREATE INDEX weekly_schedule_items_release_idx
  ON public.weekly_schedule_items (release_at, topic_id);
CREATE INDEX weekly_schedule_items_order_idx
  ON public.weekly_schedule_items (weekly_schedule_id, release_order);

CREATE TRIGGER weekly_schedule_items_set_updated_at
BEFORE UPDATE ON public.weekly_schedule_items
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Remove redundant flashcard section and area columns. Topic remains because subtopic is optional.
DROP INDEX IF EXISTS public.flashcards_published_browse_idx;
ALTER TABLE public.flashcards
  DROP CONSTRAINT IF EXISTS flashcards_section_id_fkey,
  DROP CONSTRAINT IF EXISTS flashcards_area_id_fkey,
  DROP CONSTRAINT IF EXISTS flashcards_topic_id_area_id_fkey,
  DROP CONSTRAINT IF EXISTS flashcards_subtopic_id_topic_id_fkey;
ALTER TABLE public.flashcards
  ADD CONSTRAINT flashcards_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES public.topics(id) ON DELETE RESTRICT,
  ADD CONSTRAINT flashcards_subtopic_topic_fkey FOREIGN KEY (subtopic_id, topic_id) REFERENCES public.subtopics(id, topic_id) ON DELETE RESTRICT;
ALTER TABLE public.flashcards DROP COLUMN section_id;
ALTER TABLE public.flashcards DROP COLUMN area_id;

CREATE INDEX flashcards_published_browse_idx
  ON public.flashcards (topic_id, subtopic_id) WHERE status = 'published';

-- A content version snapshots taxonomy but no longer snapshots a single section.
ALTER TABLE public.flashcard_versions DROP COLUMN section_id;
ALTER TABLE public.flashcard_versions
  ADD CONSTRAINT flashcard_versions_topic_area_fkey
    FOREIGN KEY (topic_id, area_id) REFERENCES public.topics(id, area_id) ON DELETE RESTRICT,
  ADD CONSTRAINT flashcard_versions_subtopic_topic_fkey
    FOREIGN KEY (subtopic_id, topic_id) REFERENCES public.subtopics(id, topic_id) ON DELETE RESTRICT;

-- Extend audit entity vocabulary for normalized relationships.
ALTER TABLE public.editorial_audit_log
  DROP CONSTRAINT IF EXISTS editorial_audit_log_entity_type_check;
ALTER TABLE public.editorial_audit_log
  ADD CONSTRAINT editorial_audit_log_entity_type_check
  CHECK (entity_type IN (
    'flashcard', 'flashcard_media', 'flashcard_section', 'flashcard_tag',
    'section', 'area', 'topic', 'subtopic', 'tag',
    'weekly_schedule', 'weekly_schedule_item'
  ));

-- Centralized access rule: any past release permanently unlocks a published card.
CREATE OR REPLACE FUNCTION private.can_access_flashcard(_user_id UUID, _flashcard_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT private.can_manage_content(_user_id)
    OR EXISTS (
      SELECT 1
      FROM public.flashcards f
      JOIN public.flashcard_sections fs ON fs.flashcard_id = f.id
      JOIN public.weekly_schedules ws
        ON ws.section_id = fs.section_id
       AND ws.status = 'published'
      JOIN public.weekly_schedule_items wsi
        ON wsi.weekly_schedule_id = ws.id
       AND wsi.topic_id = f.topic_id
      WHERE f.id = _flashcard_id
        AND f.status = 'published'
        AND wsi.release_at <= now()
    )
$$;
REVOKE ALL ON FUNCTION private.can_access_flashcard(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.can_access_flashcard(UUID, UUID) TO authenticated, service_role;

CREATE POLICY "Users view accessible flashcard sections"
ON public.flashcard_sections FOR SELECT TO authenticated
USING (private.can_manage_content(auth.uid()) OR private.can_access_flashcard(auth.uid(), flashcard_id));
CREATE POLICY "Content managers link flashcard sections"
ON public.flashcard_sections FOR INSERT TO authenticated
WITH CHECK (private.can_manage_content(auth.uid()));
CREATE POLICY "Content managers unlink flashcard sections"
ON public.flashcard_sections FOR DELETE TO authenticated
USING (private.can_manage_content(auth.uid()));

DROP POLICY IF EXISTS "Students view published flashcards" ON public.flashcards;
CREATE POLICY "Students view permanently released flashcards"
ON public.flashcards FOR SELECT TO authenticated
USING (private.can_access_flashcard(auth.uid(), id));

ALTER POLICY "Students view versions of published flashcards"
ON public.flashcard_versions
USING (private.can_access_flashcard(auth.uid(), flashcard_id));

ALTER POLICY "Students view media of published flashcards"
ON public.flashcard_media
USING (private.can_access_flashcard(auth.uid(), flashcard_id));

ALTER POLICY "Students view accessible media version history"
ON public.flashcard_media_versions
USING (private.can_access_flashcard(auth.uid(), flashcard_id));

ALTER POLICY "Students view tags of published flashcards"
ON public.flashcard_tags
USING (private.can_access_flashcard(auth.uid(), flashcard_id));

ALTER POLICY "Students create own card state"
ON public.user_flashcard_states
WITH CHECK (user_id = auth.uid() AND private.can_access_flashcard(auth.uid(), flashcard_id));

ALTER POLICY "Students update own card state"
ON public.user_flashcard_states
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid() AND private.can_access_flashcard(auth.uid(), flashcard_id));

ALTER POLICY "Students append own review events"
ON public.review_events
WITH CHECK (
  user_id = auth.uid()
  AND private.can_access_flashcard(auth.uid(), flashcard_id)
  AND EXISTS (
    SELECT 1 FROM public.flashcard_versions fv
    WHERE fv.flashcard_id = review_events.flashcard_id
      AND fv.version = review_events.card_version_seen
  )
);

CREATE POLICY "Students view released schedule items"
ON public.weekly_schedule_items FOR SELECT TO authenticated
USING (
  private.has_role(auth.uid(), 'admin')
  OR (
    release_at <= now()
    AND EXISTS (
      SELECT 1 FROM public.weekly_schedules ws
      WHERE ws.id = weekly_schedule_id AND ws.status = 'published'
    )
  )
);

-- Keep the current policy names but enforce the renamed item table.
ALTER POLICY "Admins create schedule topics"
ON public.weekly_schedule_items
WITH CHECK (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins update schedule topics"
ON public.weekly_schedule_items
USING (private.has_role(auth.uid(), 'admin'))
WITH CHECK (private.has_role(auth.uid(), 'admin'));
ALTER POLICY "Admins delete schedule topics"
ON public.weekly_schedule_items
USING (private.has_role(auth.uid(), 'admin'));

-- Validate item timing while keeping the row shape extensible.
CREATE OR REPLACE FUNCTION private.validate_weekly_schedule_item()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  starts_on DATE;
  parent_status public.schedule_status;
  expected_date DATE;
BEGIN
  SELECT week_start_date, status
    INTO starts_on, parent_status
  FROM public.weekly_schedules
  WHERE id = NEW.weekly_schedule_id;

  IF starts_on IS NULL THEN
    RAISE EXCEPTION 'Weekly schedule does not exist';
  END IF;
  IF parent_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft schedule items may be changed';
  END IF;

  expected_date := starts_on + (NEW.release_day - 1);
  IF NEW.release_at IS NULL THEN
    NEW.release_at := expected_date::timestamp AT TIME ZONE 'America/Fortaleza';
  ELSIF (NEW.release_at AT TIME ZONE 'America/Fortaleza')::date <> expected_date THEN
    RAISE EXCEPTION 'release_at must fall on release_day within the schedule week';
  END IF;

  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.validate_weekly_schedule_item() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.validate_weekly_schedule_item() TO service_role;

CREATE OR REPLACE FUNCTION private.guard_weekly_schedule_item_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.weekly_schedules
    WHERE id = OLD.weekly_schedule_id AND status <> 'draft'
  ) THEN
    RAISE EXCEPTION 'Only draft schedule items may be deleted';
  END IF;
  RETURN OLD;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_weekly_schedule_item_delete() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.guard_weekly_schedule_item_delete() TO service_role;

CREATE OR REPLACE FUNCTION private.validate_weekly_schedule_publish()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  item_count INTEGER;
  release_days SMALLINT[];
BEGIN
  IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM NEW.status) THEN
    SELECT count(*), array_agg(release_day ORDER BY release_day)
      INTO item_count, release_days
    FROM public.weekly_schedule_items
    WHERE weekly_schedule_id = NEW.id;

    IF item_count <> 3 OR release_days <> ARRAY[1,3,5]::SMALLINT[] THEN
      RAISE EXCEPTION 'A V1 published weekly schedule must contain Monday, Wednesday and Friday items';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.validate_weekly_schedule_publish() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.validate_weekly_schedule_publish() TO service_role;

CREATE OR REPLACE FUNCTION private.guard_weekly_schedule_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft schedules may be deleted';
  END IF;
  RETURN OLD;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_weekly_schedule_delete() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.guard_weekly_schedule_delete() TO service_role;

CREATE TRIGGER weekly_schedule_items_validate
BEFORE INSERT OR UPDATE ON public.weekly_schedule_items
FOR EACH ROW EXECUTE FUNCTION private.validate_weekly_schedule_item();
CREATE TRIGGER weekly_schedule_items_guard_delete
BEFORE DELETE ON public.weekly_schedule_items
FOR EACH ROW EXECUTE FUNCTION private.guard_weekly_schedule_item_delete();
CREATE TRIGGER weekly_schedules_validate_publish
BEFORE INSERT OR UPDATE OF status ON public.weekly_schedules
FOR EACH ROW EXECUTE FUNCTION private.validate_weekly_schedule_publish();
CREATE TRIGGER weekly_schedules_guard_delete
BEFORE DELETE ON public.weekly_schedules
FOR EACH ROW EXECUTE FUNCTION private.guard_weekly_schedule_delete();

-- Content versioning excludes section links and includes pedagogical taxonomy/content.
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

  content_changed := ROW(
    NEW.topic_id, NEW.subtopic_id, NEW.question, NEW.short_answer,
    NEW.comment, NEW.reference, NEW.editorial_difficulty
  ) IS DISTINCT FROM ROW(
    OLD.topic_id, OLD.subtopic_id, OLD.question, OLD.short_answer,
    OLD.comment, OLD.reference, OLD.editorial_difficulty
  );
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
DECLARE
  snapshot_area_id UUID;
BEGIN
  IF TG_OP = 'INSERT' OR NEW.version <> OLD.version THEN
    SELECT area_id INTO snapshot_area_id
    FROM public.topics
    WHERE id = NEW.topic_id;

    INSERT INTO public.flashcard_versions (
      flashcard_id, version, code, area_id, topic_id, subtopic_id,
      question, short_answer, comment, reference, editorial_difficulty,
      status, changed_by
    ) VALUES (
      NEW.id, NEW.version, NEW.code, snapshot_area_id, NEW.topic_id, NEW.subtopic_id,
      NEW.question, NEW.short_answer, NEW.comment, NEW.reference,
      NEW.editorial_difficulty, NEW.status, NEW.updated_by
    );

    INSERT INTO public.flashcard_media_versions (
      flashcard_id, card_version, media_id, type, placement, storage_path,
      caption, alt_text, display_order, is_active
    )
    SELECT
      NEW.id, NEW.version, fm.id, fm.type, fm.placement, fm.storage_path,
      fm.caption, fm.alt_text, fm.display_order, fm.is_active
    FROM public.flashcard_media fm
    WHERE fm.flashcard_id = NEW.id;
  END IF;

  INSERT INTO public.editorial_audit_log (
    actor_id, entity_type, entity_id, action, old_data, new_data
  ) VALUES (
    auth.uid(), 'flashcard', NEW.id,
    CASE
      WHEN TG_OP = 'INSERT' THEN 'create'
      WHEN NEW.status = 'archived' AND OLD.status IS DISTINCT FROM NEW.status THEN 'archive'
      ELSE 'update'
    END,
    CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) END,
    to_jsonb(NEW)
  );
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.record_flashcard_version() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.record_flashcard_version() TO service_role;

-- Section membership has independent audit history and never changes content version.
CREATE OR REPLACE FUNCTION private.audit_flashcard_section_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  affected_flashcard_id UUID := COALESCE(NEW.flashcard_id, OLD.flashcard_id);
BEGIN
  INSERT INTO public.editorial_audit_log (
    actor_id, entity_type, entity_id, action, old_data, new_data
  ) VALUES (
    auth.uid(), 'flashcard_section', affected_flashcard_id,
    CASE WHEN TG_OP = 'INSERT' THEN 'link' ELSE 'unlink' END,
    CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'INSERT' THEN to_jsonb(NEW) END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;
REVOKE ALL ON FUNCTION private.audit_flashcard_section_change() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.audit_flashcard_section_change() TO service_role;

CREATE TRIGGER flashcard_sections_record_change
AFTER INSERT OR DELETE ON public.flashcard_sections
FOR EACH ROW EXECUTE FUNCTION private.audit_flashcard_section_change();

-- Storage access follows the same permanent release rule.
DROP POLICY IF EXISTS "Students view accessible flashcard media files" ON storage.objects;
CREATE POLICY "Students view accessible flashcard media files"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'flashcard-media'
  AND (
    private.can_manage_content(auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.flashcard_media fm
      WHERE fm.storage_path = storage.objects.name
        AND fm.is_active
        AND private.can_access_flashcard(auth.uid(), fm.flashcard_id)
    )
  )
);