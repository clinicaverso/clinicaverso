REVOKE ALL ON public.fsrs_configurations, public.fsrs_initializations, public.daily_study_queues, public.daily_queue_members, public.daily_study_attempts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fsrs_configurations TO authenticated;
GRANT SELECT ON public.fsrs_initializations, public.daily_study_queues, public.daily_queue_members, public.daily_study_attempts TO authenticated;
GRANT ALL ON public.fsrs_configurations, public.fsrs_initializations, public.daily_study_queues, public.daily_queue_members, public.daily_study_attempts TO service_role;