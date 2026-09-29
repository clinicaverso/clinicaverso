INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::public.app_role FROM auth.users
WHERE id = '313161b0-f726-45cd-8f6d-6cc0b557a13d'
AND NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = '313161b0-f726-45cd-8f6d-6cc0b557a13d' AND role = 'admin');