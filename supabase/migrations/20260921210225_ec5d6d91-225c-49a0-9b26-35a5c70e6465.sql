CREATE TABLE public.flashcard_media_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flashcard_id UUID NOT NULL,
  card_version INTEGER NOT NULL,
  media_id UUID NOT NULL,
  type public.media_type NOT NULL,
  placement public.media_placement NOT NULL,
  storage_path TEXT NOT NULL,
  caption TEXT NOT NULL DEFAULT '',
  alt_text TEXT NOT NULL DEFAULT '',
  display_order INTEGER NOT NULL CHECK (display_order >= 0),
  is_active BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (flashcard_id, card_version)
    REFERENCES public.flashcard_versions(flashcard_id, version)
    ON DELETE RESTRICT,
  UNIQUE (flashcard_id, card_version, media_id)
);
GRANT SELECT ON public.flashcard_media_versions TO authenticated;
GRANT ALL ON public.flashcard_media_versions TO service_role;
ALTER TABLE public.flashcard_media_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view accessible media version history"
ON public.flashcard_media_versions
FOR SELECT
TO authenticated
USING (
  private.can_manage_content(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.flashcards f
    WHERE f.id = flashcard_id
  )
);

CREATE INDEX flashcard_media_versions_history_idx
  ON public.flashcard_media_versions (flashcard_id, card_version, placement, display_order);

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

CREATE OR REPLACE FUNCTION private.validate_weekly_schedule_publish()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  release_count INTEGER;
BEGIN
  IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM NEW.status) THEN
    SELECT count(*) INTO release_count
    FROM public.weekly_schedule_topics
    WHERE weekly_schedule_id = NEW.id;

    IF release_count <> 3 THEN
      RAISE EXCEPTION 'A published weekly schedule must contain Monday, Wednesday and Friday topics';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.validate_weekly_schedule_publish() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.validate_weekly_schedule_publish() TO service_role;

CREATE TRIGGER weekly_schedules_validate_publish
BEFORE INSERT OR UPDATE OF status ON public.weekly_schedules
FOR EACH ROW EXECUTE FUNCTION private.validate_weekly_schedule_publish();