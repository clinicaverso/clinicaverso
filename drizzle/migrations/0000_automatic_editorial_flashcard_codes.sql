CREATE SEQUENCE public.flashcard_editorial_code_seq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
REVOKE ALL ON SEQUENCE public.flashcard_editorial_code_seq FROM PUBLIC, anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.flashcard_editorial_code_seq TO service_role;

CREATE OR REPLACE FUNCTION private.prepare_flashcard_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  actor uuid := auth.uid();
  content_changed boolean;
  internal_media_bump boolean;
  serial bigint;
BEGIN
  IF TG_OP = 'INSERT' THEN
    serial := nextval('public.flashcard_editorial_code_seq'::regclass);
    NEW.code := 'CV-CARD-' || lpad(serial::text, 6, '0');
    IF actor IS NOT NULL THEN
      NEW.created_by := actor;
      NEW.updated_by := actor;
    END IF;
    NEW.version := 1;
    NEW.created_at := now();
    NEW.updated_at := now();
    RETURN NEW;
  END IF;

  IF NEW.code IS DISTINCT FROM OLD.code THEN
    RAISE EXCEPTION 'Editorial code is permanent';
  END IF;
  NEW.code := OLD.code;
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
$function$;

COMMENT ON SEQUENCE public.flashcard_editorial_code_seq IS 'Atomic global editorial numbering for ClinicaVerso Cards; gaps are allowed after rolled-back inserts.';