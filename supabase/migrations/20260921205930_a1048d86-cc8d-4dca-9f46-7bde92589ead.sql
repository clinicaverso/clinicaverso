ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'editor';

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role TEXT)
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
REVOKE ALL ON FUNCTION public.has_role(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_role(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.can_manage_content(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.has_role(_user_id, 'admin') OR public.has_role(_user_id, 'editor')
$$;
REVOKE ALL ON FUNCTION public.can_manage_content(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_content(UUID) TO authenticated;

CREATE TYPE public.flashcard_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE public.schedule_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE public.media_type AS ENUM ('image', 'document');
CREATE TYPE public.media_placement AS ENUM ('question', 'answer', 'comment');
CREATE TYPE public.learning_state AS ENUM ('new', 'learning', 'review', 'relearning');
CREATE TYPE public.review_rating AS ENUM ('again', 'hard', 'good', 'easy');

CREATE TABLE public.sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  slug TEXT NOT NULL UNIQUE CHECK (slug = lower(slug) AND slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.sections TO authenticated;
GRANT ALL ON public.sections TO service_role;
ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users view active sections" ON public.sections FOR SELECT TO authenticated USING (is_active OR public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers create sections" ON public.sections FOR INSERT TO authenticated WITH CHECK (public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers update sections" ON public.sections FOR UPDATE TO authenticated USING (public.can_manage_content(auth.uid())) WITH CHECK (public.can_manage_content(auth.uid()));

CREATE TABLE public.areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  slug TEXT NOT NULL UNIQUE CHECK (slug = lower(slug) AND slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.areas TO authenticated;
GRANT ALL ON public.areas TO service_role;
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users view active areas" ON public.areas FOR SELECT TO authenticated USING (is_active OR public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers create areas" ON public.areas FOR INSERT TO authenticated WITH CHECK (public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers update areas" ON public.areas FOR UPDATE TO authenticated USING (public.can_manage_content(auth.uid())) WITH CHECK (public.can_manage_content(auth.uid()));

CREATE TABLE public.topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  area_id UUID NOT NULL REFERENCES public.areas(id) ON DELETE RESTRICT,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  slug TEXT NOT NULL CHECK (slug = lower(slug) AND slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (area_id, slug),
  UNIQUE (id, area_id)
);
GRANT SELECT, INSERT, UPDATE ON public.topics TO authenticated;
GRANT ALL ON public.topics TO service_role;
ALTER TABLE public.topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users view active topics" ON public.topics FOR SELECT TO authenticated USING (is_active OR public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers create topics" ON public.topics FOR INSERT TO authenticated WITH CHECK (public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers update topics" ON public.topics FOR UPDATE TO authenticated USING (public.can_manage_content(auth.uid())) WITH CHECK (public.can_manage_content(auth.uid()));

CREATE TABLE public.subtopics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id UUID NOT NULL REFERENCES public.topics(id) ON DELETE RESTRICT,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  slug TEXT NOT NULL CHECK (slug = lower(slug) AND slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  description TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (topic_id, slug),
  UNIQUE (id, topic_id)
);
GRANT SELECT, INSERT, UPDATE ON public.subtopics TO authenticated;
GRANT ALL ON public.subtopics TO service_role;
ALTER TABLE public.subtopics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users view active subtopics" ON public.subtopics FOR SELECT TO authenticated USING (is_active OR public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers create subtopics" ON public.subtopics FOR INSERT TO authenticated WITH CHECK (public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers update subtopics" ON public.subtopics FOR UPDATE TO authenticated USING (public.can_manage_content(auth.uid())) WITH CHECK (public.can_manage_content(auth.uid()));

CREATE TABLE public.flashcards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE CHECK (code ~ '^CV-[A-Z0-9+-]+-[0-9]{6,}$'),
  section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE RESTRICT,
  area_id UUID NOT NULL REFERENCES public.areas(id) ON DELETE RESTRICT,
  topic_id UUID NOT NULL,
  subtopic_id UUID,
  question TEXT NOT NULL CHECK (length(trim(question)) > 0),
  short_answer TEXT NOT NULL CHECK (length(trim(short_answer)) > 0),
  comment JSONB NOT NULL DEFAULT '{"type":"doc","content":[]}'::jsonb CHECK (jsonb_typeof(comment) = 'object' AND comment ->> 'type' = 'doc'),
  reference TEXT NOT NULL DEFAULT '',
  editorial_difficulty TEXT NOT NULL DEFAULT 'medium' CHECK (editorial_difficulty IN ('easy', 'medium', 'hard')),
  status public.flashcard_status NOT NULL DEFAULT 'draft',
  created_by UUID NOT NULL,
  updated_by UUID NOT NULL,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (topic_id, area_id) REFERENCES public.topics(id, area_id) ON DELETE RESTRICT,
  FOREIGN KEY (subtopic_id, topic_id) REFERENCES public.subtopics(id, topic_id) ON DELETE RESTRICT
);
GRANT SELECT, INSERT, UPDATE ON public.flashcards TO authenticated;
GRANT ALL ON public.flashcards TO service_role;
ALTER TABLE public.flashcards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view published flashcards" ON public.flashcards FOR SELECT TO authenticated USING (status = 'published' OR public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers create flashcards" ON public.flashcards FOR INSERT TO authenticated WITH CHECK (public.can_manage_content(auth.uid()) AND created_by = auth.uid() AND updated_by = auth.uid());
CREATE POLICY "Content managers update flashcards" ON public.flashcards FOR UPDATE TO authenticated USING (public.can_manage_content(auth.uid())) WITH CHECK (public.can_manage_content(auth.uid()) AND updated_by = auth.uid());

CREATE TABLE public.flashcard_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flashcard_id UUID NOT NULL REFERENCES public.flashcards(id) ON DELETE RESTRICT,
  version INTEGER NOT NULL CHECK (version > 0),
  code TEXT NOT NULL,
  section_id UUID NOT NULL,
  area_id UUID NOT NULL,
  topic_id UUID NOT NULL,
  subtopic_id UUID,
  question TEXT NOT NULL,
  short_answer TEXT NOT NULL,
  comment JSONB NOT NULL CHECK (jsonb_typeof(comment) = 'object'),
  reference TEXT NOT NULL DEFAULT '',
  editorial_difficulty TEXT NOT NULL,
  status public.flashcard_status NOT NULL,
  changed_by UUID NOT NULL,
  change_summary TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (flashcard_id, version)
);
GRANT SELECT ON public.flashcard_versions TO authenticated;
GRANT ALL ON public.flashcard_versions TO service_role;
ALTER TABLE public.flashcard_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view versions of published flashcards" ON public.flashcard_versions FOR SELECT TO authenticated USING (public.can_manage_content(auth.uid()) OR EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id AND f.status = 'published'));

CREATE TABLE public.flashcard_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flashcard_id UUID NOT NULL REFERENCES public.flashcards(id) ON DELETE RESTRICT,
  type public.media_type NOT NULL,
  placement public.media_placement NOT NULL,
  storage_path TEXT NOT NULL CHECK (length(trim(storage_path)) > 0 AND storage_path !~ '^https?://'),
  caption TEXT NOT NULL DEFAULT '',
  alt_text TEXT NOT NULL DEFAULT '',
  display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (flashcard_id, placement, display_order)
);
GRANT SELECT, INSERT, UPDATE ON public.flashcard_media TO authenticated;
GRANT ALL ON public.flashcard_media TO service_role;
ALTER TABLE public.flashcard_media ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view media of published flashcards" ON public.flashcard_media FOR SELECT TO authenticated USING (public.can_manage_content(auth.uid()) OR EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id AND f.status = 'published'));
CREATE POLICY "Content managers create media" ON public.flashcard_media FOR INSERT TO authenticated WITH CHECK (public.can_manage_content(auth.uid()) AND created_by = auth.uid());
CREATE POLICY "Content managers update media" ON public.flashcard_media FOR UPDATE TO authenticated USING (public.can_manage_content(auth.uid())) WITH CHECK (public.can_manage_content(auth.uid()));

CREATE TABLE public.tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  slug TEXT NOT NULL UNIQUE CHECK (slug = lower(slug) AND slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.tags TO authenticated;
GRANT ALL ON public.tags TO service_role;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users view active tags" ON public.tags FOR SELECT TO authenticated USING (is_active OR public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers create tags" ON public.tags FOR INSERT TO authenticated WITH CHECK (public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers update tags" ON public.tags FOR UPDATE TO authenticated USING (public.can_manage_content(auth.uid())) WITH CHECK (public.can_manage_content(auth.uid()));

CREATE TABLE public.flashcard_tags (
  flashcard_id UUID NOT NULL REFERENCES public.flashcards(id) ON DELETE RESTRICT,
  tag_id UUID NOT NULL REFERENCES public.tags(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (flashcard_id, tag_id)
);
GRANT SELECT, INSERT, DELETE ON public.flashcard_tags TO authenticated;
GRANT ALL ON public.flashcard_tags TO service_role;
ALTER TABLE public.flashcard_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view tags of published flashcards" ON public.flashcard_tags FOR SELECT TO authenticated USING (public.can_manage_content(auth.uid()) OR EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id AND f.status = 'published'));
CREATE POLICY "Content managers link tags" ON public.flashcard_tags FOR INSERT TO authenticated WITH CHECK (public.can_manage_content(auth.uid()));
CREATE POLICY "Content managers unlink tags" ON public.flashcard_tags FOR DELETE TO authenticated USING (public.can_manage_content(auth.uid()));

CREATE TABLE public.weekly_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE RESTRICT,
  week_start_date DATE NOT NULL CHECK (extract(isodow FROM week_start_date) = 1),
  status public.schedule_status NOT NULL DEFAULT 'draft',
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (section_id, week_start_date)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.weekly_schedules TO authenticated;
GRANT ALL ON public.weekly_schedules TO service_role;
ALTER TABLE public.weekly_schedules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view published schedules" ON public.weekly_schedules FOR SELECT TO authenticated USING (status = 'published' OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins create schedules" ON public.weekly_schedules FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin') AND created_by = auth.uid());
CREATE POLICY "Admins update schedules" ON public.weekly_schedules FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins delete schedules" ON public.weekly_schedules FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.weekly_schedule_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  weekly_schedule_id UUID NOT NULL REFERENCES public.weekly_schedules(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES public.topics(id) ON DELETE RESTRICT,
  release_weekday SMALLINT NOT NULL CHECK (release_weekday IN (1, 3, 5)),
  release_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (weekly_schedule_id, release_weekday),
  UNIQUE (weekly_schedule_id, topic_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.weekly_schedule_topics TO authenticated;
GRANT ALL ON public.weekly_schedule_topics TO service_role;
ALTER TABLE public.weekly_schedule_topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view released schedule topics" ON public.weekly_schedule_topics FOR SELECT TO authenticated USING (release_date <= current_date AND EXISTS (SELECT 1 FROM public.weekly_schedules ws WHERE ws.id = weekly_schedule_id AND ws.status = 'published') OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins create schedule topics" ON public.weekly_schedule_topics FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins update schedule topics" ON public.weekly_schedule_topics FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins delete schedule topics" ON public.weekly_schedule_topics FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.user_flashcard_states (
  user_id UUID NOT NULL,
  flashcard_id UUID NOT NULL REFERENCES public.flashcards(id) ON DELETE RESTRICT,
  learning_state public.learning_state NOT NULL DEFAULT 'new',
  first_seen_at TIMESTAMPTZ,
  last_reviewed_at TIMESTAMPTZ,
  next_review_at TIMESTAMPTZ,
  current_interval NUMERIC(12,4) NOT NULL DEFAULT 0 CHECK (current_interval >= 0),
  review_count INTEGER NOT NULL DEFAULT 0 CHECK (review_count >= 0),
  lapse_count INTEGER NOT NULL DEFAULT 0 CHECK (lapse_count >= 0),
  fsrs_stability NUMERIC(12,6) CHECK (fsrs_stability IS NULL OR fsrs_stability >= 0),
  fsrs_difficulty NUMERIC(8,6) CHECK (fsrs_difficulty IS NULL OR fsrs_difficulty BETWEEN 1 AND 10),
  fsrs_data JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(fsrs_data) = 'object'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, flashcard_id)
);
GRANT SELECT, INSERT, UPDATE ON public.user_flashcard_states TO authenticated;
GRANT ALL ON public.user_flashcard_states TO service_role;
ALTER TABLE public.user_flashcard_states ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view own card state" ON public.user_flashcard_states FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Students create own card state" ON public.user_flashcard_states FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id AND f.status = 'published'));
CREATE POLICY "Students update own card state" ON public.user_flashcard_states FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id AND f.status = 'published'));

CREATE TABLE public.review_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  flashcard_id UUID NOT NULL REFERENCES public.flashcards(id) ON DELETE RESTRICT,
  reviewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  rating public.review_rating NOT NULL,
  previous_interval NUMERIC(12,4) NOT NULL DEFAULT 0 CHECK (previous_interval >= 0),
  new_interval NUMERIC(12,4) NOT NULL CHECK (new_interval >= 0),
  scheduled_next_review TIMESTAMPTZ NOT NULL,
  card_version_seen INTEGER NOT NULL CHECK (card_version_seen > 0),
  learning_state_before public.learning_state,
  learning_state_after public.learning_state NOT NULL,
  fsrs_data JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(fsrs_data) = 'object'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.review_events TO authenticated;
GRANT ALL ON public.review_events TO service_role;
ALTER TABLE public.review_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view own review events" ON public.review_events FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Students append own review events" ON public.review_events FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = flashcard_id AND f.status = 'published' AND f.version = card_version_seen));

CREATE TABLE public.editorial_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('flashcard', 'flashcard_media', 'section', 'area', 'topic', 'subtopic', 'tag', 'weekly_schedule')),
  entity_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('create', 'update', 'archive', 'link', 'unlink')),
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.editorial_audit_log TO authenticated;
GRANT ALL ON public.editorial_audit_log TO service_role;
ALTER TABLE public.editorial_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins view editorial audit" ON public.editorial_audit_log FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_user_id_not_empty CHECK (user_id <> '00000000-0000-0000-0000-000000000000'::uuid);
GRANT INSERT, UPDATE, DELETE ON public.user_roles TO authenticated;
CREATE POLICY "Admins view all roles" ON public.user_roles FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins create roles" ON public.user_roles FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins update roles" ON public.user_roles FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins delete roles" ON public.user_roles FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins view profiles" ON public.profiles FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.prepare_flashcard_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor UUID := auth.uid();
  content_changed BOOLEAN;
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

  NEW.created_by := OLD.created_by;
  NEW.created_at := OLD.created_at;
  NEW.updated_by := COALESCE(actor, NEW.updated_by, OLD.updated_by);
  NEW.version := CASE WHEN content_changed THEN OLD.version + 1 ELSE OLD.version END;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_flashcard_version()
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

CREATE OR REPLACE FUNCTION public.prepare_media_write()
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

CREATE OR REPLACE FUNCTION public.record_media_change()
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

  INSERT INTO public.flashcard_versions (
    flashcard_id, version, code, section_id, area_id, topic_id, subtopic_id,
    question, short_answer, comment, reference, editorial_difficulty, status, changed_by, change_summary
  ) VALUES (
    card.id, card.version, card.code, card.section_id, card.area_id, card.topic_id, card.subtopic_id,
    card.question, card.short_answer, card.comment, card.reference, card.editorial_difficulty, card.status,
    card.updated_by, 'Media updated'
  ) ON CONFLICT (flashcard_id, version) DO NOTHING;

  INSERT INTO public.editorial_audit_log (actor_id, entity_type, entity_id, action, old_data, new_data)
  VALUES (auth.uid(), 'flashcard_media', NEW.id, CASE WHEN TG_OP = 'INSERT' THEN 'create' ELSE 'update' END,
    CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) END, to_jsonb(NEW));
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_schedule_topic()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  starts_on DATE;
BEGIN
  SELECT week_start_date INTO starts_on FROM public.weekly_schedules WHERE id = NEW.weekly_schedule_id;
  NEW.release_date := starts_on + (NEW.release_weekday - 1);
  RETURN NEW;
END;
$$;

CREATE TRIGGER sections_set_updated_at BEFORE UPDATE ON public.sections FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER areas_set_updated_at BEFORE UPDATE ON public.areas FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER topics_set_updated_at BEFORE UPDATE ON public.topics FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER subtopics_set_updated_at BEFORE UPDATE ON public.subtopics FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER tags_set_updated_at BEFORE UPDATE ON public.tags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER weekly_schedules_set_updated_at BEFORE UPDATE ON public.weekly_schedules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER user_flashcard_states_set_updated_at BEFORE UPDATE ON public.user_flashcard_states FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER flashcards_prepare_write BEFORE INSERT OR UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION public.prepare_flashcard_write();
CREATE TRIGGER flashcards_record_version AFTER INSERT OR UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION public.record_flashcard_version();
CREATE TRIGGER flashcard_media_prepare_write BEFORE INSERT OR UPDATE ON public.flashcard_media FOR EACH ROW EXECUTE FUNCTION public.prepare_media_write();
CREATE TRIGGER flashcard_media_record_change AFTER INSERT OR UPDATE ON public.flashcard_media FOR EACH ROW EXECUTE FUNCTION public.record_media_change();
CREATE TRIGGER weekly_schedule_topics_validate BEFORE INSERT OR UPDATE ON public.weekly_schedule_topics FOR EACH ROW EXECUTE FUNCTION public.validate_schedule_topic();

CREATE INDEX flashcards_published_browse_idx ON public.flashcards (section_id, area_id, topic_id, subtopic_id) WHERE status = 'published';
CREATE INDEX flashcards_updated_idx ON public.flashcards (updated_at DESC);
CREATE INDEX flashcard_versions_history_idx ON public.flashcard_versions (flashcard_id, version DESC);
CREATE INDEX flashcard_media_card_idx ON public.flashcard_media (flashcard_id, placement, display_order) WHERE is_active;
CREATE INDEX flashcard_tags_tag_idx ON public.flashcard_tags (tag_id, flashcard_id);
CREATE INDEX weekly_schedules_section_week_idx ON public.weekly_schedules (section_id, week_start_date DESC);
CREATE INDEX weekly_schedule_topics_release_idx ON public.weekly_schedule_topics (release_date, topic_id);
CREATE INDEX user_flashcard_states_due_idx ON public.user_flashcard_states (user_id, next_review_at) WHERE next_review_at IS NOT NULL;
CREATE INDEX review_events_user_card_idx ON public.review_events (user_id, flashcard_id, reviewed_at DESC);
CREATE INDEX review_events_card_idx ON public.review_events (flashcard_id, reviewed_at DESC);
CREATE INDEX editorial_audit_entity_idx ON public.editorial_audit_log (entity_type, entity_id, created_at DESC);

INSERT INTO public.sections (name, slug, description, is_active) VALUES
  ('R1CM', 'r1cm', 'Residência em Clínica Médica', true),
  ('R+CM', 'r-mais-cm', 'Formação avançada em Clínica Médica', false),
  ('TECM', 'tecm', 'Título de Especialista em Clínica Médica', false)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.areas (name, slug) VALUES
  ('Cardiologia', 'cardiologia'),
  ('Gastroenterologia', 'gastroenterologia'),
  ('Endocrinologia', 'endocrinologia'),
  ('Nefrologia', 'nefrologia'),
  ('Pneumologia', 'pneumologia'),
  ('Hematologia', 'hematologia'),
  ('Infectologia', 'infectologia'),
  ('Reumatologia', 'reumatologia'),
  ('Neurologia', 'neurologia'),
  ('Dermatologia', 'dermatologia'),
  ('Emergência / Medicina Intensiva', 'emergencia-medicina-intensiva'),
  ('Cuidados Paliativos', 'cuidados-paliativos')
ON CONFLICT (slug) DO NOTHING;