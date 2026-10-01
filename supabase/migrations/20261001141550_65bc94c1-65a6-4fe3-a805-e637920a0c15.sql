INSERT INTO public.topics (area_id, name, slug, description, is_active)
SELECT id, 'Síndrome Coronariana Aguda', 'sindrome-coronariana-aguda', 'Diagnóstico e manejo da síndrome coronariana aguda.', true FROM public.areas WHERE slug = 'cardiologia'
ON CONFLICT (area_id, slug) DO NOTHING;
INSERT INTO public.topics (area_id, name, slug, description, is_active)
SELECT id, 'Diabetes mellitus', 'diabetes-mellitus', 'Diagnóstico e manejo do diabetes mellitus.', true FROM public.areas WHERE slug = 'endocrinologia'
ON CONFLICT (area_id, slug) DO NOTHING;
INSERT INTO public.topics (area_id, name, slug, description, is_active)
SELECT id, 'Cirrose', 'cirrose', 'Diagnóstico e manejo da cirrose.', true FROM public.areas WHERE slug = 'gastroenterologia'
ON CONFLICT (area_id, slug) DO NOTHING;
INSERT INTO public.subtopics (topic_id, name, slug, description, is_active)
SELECT id, 'Diagnóstico inicial', 'diagnostico-inicial-sca', 'Avaliação diagnóstica inicial.', true FROM public.topics WHERE slug = 'sindrome-coronariana-aguda'
ON CONFLICT (topic_id, slug) DO NOTHING;
INSERT INTO public.subtopics (topic_id, name, slug, description, is_active)
SELECT id, 'Tratamento', 'tratamento-diabetes', 'Tratamento do diabetes mellitus.', true FROM public.topics WHERE slug = 'diabetes-mellitus'
ON CONFLICT (topic_id, slug) DO NOTHING;
INSERT INTO public.subtopics (topic_id, name, slug, description, is_active)
SELECT id, 'Complicações', 'complicacoes-cirrose', 'Complicações da cirrose.', true FROM public.topics WHERE slug = 'cirrose'
ON CONFLICT (topic_id, slug) DO NOTHING;